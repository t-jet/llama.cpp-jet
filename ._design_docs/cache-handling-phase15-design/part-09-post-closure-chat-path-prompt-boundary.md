# Stage 15 design part 9: post-closure follow-up — chat-path prompt-span boundary

Status: design correction, 2026-06-16
Stage: 15 (post-closure follow-up)
Date: 2026-06-16
Source issue: model log analysis on 2026-06-16
  (`d:\source\llama.cpp-jet\._analysis\model_log.txt`,
  38 MiB, 319,204 lines, 2h 25m 14s wall clock, MTP fixture)

## Background

The 2026-06-16 model log analysis surfaced that every one of the 10
hybrid cache save events for the MTP chat-completion fixture produced
the warning `hybrid cache: checkpoint admission skipped (missing
checkpoint boundary metadata)`. The exact-blob payload was admitted on
every save (10/10 `successfully saved slot` lines) and 31,498
KV-cache graph hits were served via the exact-blob restore path, so
the cache itself was functional. The optimization layer — admitting
the checkpoint payload for fast prefix restore — was silently
disabled.

The Stage 15 closure (2026-06-13) recorded a "two-diff checkpoint
boundary search relaxed" fix in `tools/server/server-cache-hybrid.cpp`
([stage15-benchmark-20260613-03.md](../.test_reports/stage15-benchmark-20260613-03.md),
[part-07 fix review](../cache-handling-phase15-implementation/part-07-b05-b06-fix-review.md))
that relaxed the `token_start` filter in the matching loop. The 2026-06-13
verification confirmed the fix on the V2 separate-draft fixture (29/29
restores) and recorded the MTP /v1/chat/completions path as a separate
third-diff extension, classified as `BLOCKED-structural-not-infra` for
the MTP fixture per Manager decision 1 (2026-06-13).

The 2026-06-16 model log is from build 9669 (commit 13d3cd863), which
already contains the Stage 15 fix. The fact that the MTP /v1/chat/completions
path still produces 10/10 admission_skipped warnings on the user's
workload confirms the Stage 15 fix did not address the chat-path
boundary coverage issue; the third-diff extension was never written.

## Root cause

Hybrid cache checkpoint admission in
`tools/server/server-cache-hybrid.cpp` requires the descriptor to bind
to a `prepared_prompt_metadata` boundary whose `token_end` equals the
checkpoint's `n_tokens` and whose `checksum` matches the entry's
`cache_token_span_checksum` over that span. The chat-completion path
in `tools/server/server-context.cpp:cache_metadata_from_chat_messages`
emits per-message boundaries (`MESSAGE_START` and `MESSAGE_END`) at
the rendered span of each message, but no boundary covers the
assistant role header at the end of the rendered prompt. The first
checkpoint at end of prefill has `n_tokens` equal to the full prompt
size, which no per-message boundary covers. The matching loop skips
all boundaries, then sets `descriptor.checkpoint_boundary_required =
true` with empty `boundary_id` and zero `boundary_checksum`, and the
strict validator at line 2984 returns `fail("missing checkpoint
boundary metadata")` and rolls back the checkpoint payload.

The exact-blob path is unaffected. The cache works, but the
checkpoint optimization is unavailable on every chat-completion
prompt, and the 15 `erased invalidated context checkpoint` warnings
confirm that even checkpoints that were admitted (in pre-fix runs)
were invalidated downstream by `update_slots`.

The unit test `test_stage9_checkpoint_boundary_metadata` passes
because the test entry has only 4 tokens and the
`debug_admit_checkpoint_for_tests` helper clamps `token_span_end` to
the entry's `n_tokens()`, creating an artificial boundary-span match
that production never produces.

## Proposed fix (Option A)

Add a single `MESSAGE_END` boundary at `[0, n_prompt_tokens]` after
the per-message loop in
`cache_metadata_from_chat_messages`, with `metadata = "prompt"` and
`protect = false`, and a checksum computed over the full prompt
range. This is the same shape as the fallback path in
`cache_metadata_for_request` and provides a boundary whose
`token_end` equals the full chat prompt size, allowing the first
end-of-prefill checkpoint to attach.

Affected file: `tools/server/server-context.cpp`,
`cache_metadata_from_chat_messages`. One insertion after the
per-message loop.

```cpp
// Stage 15 post-closure follow-up: emit a prompt-span boundary
// whose token_end equals the full prompt size so the first
// end-of-prefill checkpoint can attach. Per-message boundaries
// cover message spans only; the assistant role header at the end
// of the rendered prompt has no boundary without this.
if (!messages.empty()) {
    const uint64_t prompt_checksum = cache_metadata_checksum(
        tokens, 0, n_prompt_tokens);
    metadata.add_span(
        prompt_boundary::MESSAGE_END,
        0, n_prompt_tokens,
        prompt_checksum,
        false,
        "prompt");
}
```

This change does not modify the matching loop, the strict
validator, the exact-blob path, the public API, the CLI flags, the
metrics, or the warmup tests. It only adds one boundary to the
chat path metadata when the chat path produced per-message
boundaries. The fallback path in `cache_metadata_for_request`
already adds the same boundary when `has_boundaries()` is false,
so the post-fix shape is uniform across all entry points.

## Why Option A over Option B

Option B (relax the matching loop to find the smallest boundary
that contains the checkpoint span) was the architecturally cleanest
fix. Option A is the surgical change that aligns with the
"boundaries mark logical units" design intent: a prompt is a
logical unit, so a prompt-span boundary belongs in the metadata.
The change is ~8 lines, fully contained in the chat path, and
requires no new invariant or test for the strict validator.

## Affected files

| File | Change |
| --- | --- |
| `tools/server/server-context.cpp` | Insert one `MESSAGE_END` boundary at `[0, n_prompt_tokens]` after the per-message loop in `cache_metadata_from_chat_messages` |
| `._design_docs/cache-handling-phase15-implementation/part-08-stage15-post-closure-chat-path-impl.md` | New implementation part recording the code change |
| `._design_docs/cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md` | New architecture part recording the cross-stage invariant |
| `._design_docs/document-index.md` | New rows for the design, implementation, and architecture parts |

## Exclusions

- No change to the matching loop, the strict validator, the
  exact-blob path, the public API, the CLI flags, or the metrics.
- No change to the per-message boundary emission (system, user,
  assistant, tool calls) in the chat path.
- No change to the fallback path in `cache_metadata_for_request`,
  which already emits a prompt-span boundary when
  `has_boundaries()` is false.
- No change to `test_stage9_checkpoint_boundary_metadata`; the
  test uses hand-crafted metadata and is unaffected by the chat
  path.
- No change to the Stage 9 design, the Stage 15 design, or any
  other closed stage. This is a post-closure follow-up recorded
  in a new part file.
- No change to the `boundaries_native` flag. The chat path
  continues to mark metadata as `boundaries_native = false`
  because the boundaries are inferred from rendered-text search.
- No change to the public Prometheus metrics. The
  `cache_checkpoint_admissions_total` counter will increase
  naturally when the MTP /v1/chat/completions path successfully
  admits checkpoints, which is the operator-visible evidence.

## Test plan rows proposed (test plan is separate durable doc)

The test plan is a separate durable doc; this design proposes new
rows for the test plan follow-up to consider.

| ID | Row | Source |
| --- | --- | --- |
| TP-15-PC1 | Verify `n_checkpoint_payload_descriptors` increases on `/v1/chat/completions` with the MTP fixture after first save; was 0 before the fix | this design part-09 |
| TP-15-PC2 | Verify `cache_checkpoint_admissions_total{mode="hybrid"}` is non-zero after the first chat-completion save; was 0 before the fix | this design part-09 |
| TP-15-PC3 | Verify `cache_checkpoint_admission_failures_total{mode="hybrid"}` does not increase on chat-completion save (post-fix baseline; was 1 per save pre-fix) | this design part-09 |
| TP-15-PC4 | Verify hybrid-mode /v1/chat/completions on the MTP fixture produces `cache_n > 0` on subsequent identical requests (29/29 expected) | this design part-09 |
| TP-15-PC5 | Verify hybrid-mode /v1/chat/completions with multi-turn messages produces `cache_n > 0` on subsequent identical requests | this design part-09 |
| TP-15-PC6 | Verify hybrid-mode /completion (native) with the MTP fixture still produces `cache_n > 0` on subsequent identical requests (regression check) | this design part-09 |
| TP-15-PC7 | Verify the 5 `n_ctx_seq (140032) < n_ctx_train (262144)` informational warnings per server start are unchanged (regression check) | this design part-09 |

## Traceability

| Source | Link |
| --- | --- |
| Root cause (matching loop vs chat path boundary) | `tools/server/server-context.cpp:cache_metadata_from_chat_messages` lines 4383-4489 (chat path boundary generation) |
| Root cause (strict validator) | `tools/server/server-cache-hybrid.cpp:validate_checkpoint_descriptor_metadata` lines 2973-3003 |
| Stage 15 two-diff fix (predecessor) | `tools/server/server-cache-hybrid.cpp:attach_checkpoint_payload` lines 3065-3085 + `validate_checkpoint_descriptor_metadata` lines 2983-3002 |
| Documented limitation (predecessor) | `._design_docs/cache-handling-phase10-implementation.md:100` |
| Known-blocked metric (predecessor) | `assets/qa.md:476` BLOCKED-structural-not-infra classification |
| B05/B06 third-diff extension (predecessor) | `._design_docs/cache-handling-phase15-implementation/part-07-b05-b06-fix-review.md` INFO 1 + Manager decision 1 (2026-06-13) |
| Model log evidence | `d:\source\llama.cpp-jet\._analysis\model_log.txt` lines: 10× `checkpoint admission skipped` warnings, 10× `successfully saved slot`, 31,498 graph hits, 15 `erased invalidated context checkpoint` warnings |
| Architecture (new invariant) | `._design_docs/cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md` |
| Implementation (code change) | `._design_docs/cache-handling-phase15-implementation/part-08-stage15-post-closure-chat-path-impl.md` |

## Risks

| Risk | Impact | Mitigation |
| --- | --- | --- |
| The new prompt-span boundary changes the `preparation_id` shape (no — it only adds one boundary record) | None | The `preparation_id` is set once in `cache_metadata_from_chat_messages` and not changed by `add_span` |
| The new boundary may interfere with prefix-restore matching that uses `boundaries[0]` (e.g., `try_restore_from_cache`) | Low | The existing matching loop iterates all boundaries; the new boundary is just one more candidate. No code change to `try_restore_from_cache` |
| The new boundary conflicts with the assistant role's `MESSAGE_END` (none emitted today) | None | The chat path does not emit a boundary for the assistant role because the assistant has no content; the new boundary at `[0, N]` is the only one that covers the assistant header |
| The MTP path adds extra draft tokens beyond the chat prompt, making the new boundary's `token_end` larger than the checkpoint's `n_tokens` | Low to medium | The chat path's `n_prompt_tokens` reflects the main model prompt size (the MTP draft tokens are added by the model loader, not the prompt). The model log shows prompt counts 13 / 35 / 90 / 213 / 727 / 61,273 for the timed tasks, matching the chat path. Verification on the MTP fixture in QA is the final answer |
| The fallback path in `cache_metadata_for_request` already adds the same boundary | None (redundancy) | When the chat path sets `has_boundaries() = true`, the fallback does not run. The new boundary is added in the chat path, not the fallback |

## Excluded from this design

- The Stage 15 B05/B06 fix (already merged).
- The Stage 9 / Stage 10 / Stage 13 designs and implementations.
- The matching loop in `attach_checkpoint_payload` (left as-is per
  Option A — surgical change, not architectural).
- The strict validator in
  `validate_checkpoint_descriptor_metadata` (left as-is per
  Option A).
- The `boundaries_native` flag handling (left as-is).
- Any change to `try_restore_from_cache` or the public metrics.

## Handoff

This is a design correction, not a new stage. The next owner is
the Architect for a focused re-review of the new code change
in `cache_metadata_from_chat_messages` (recorded in
`cache-handling-phase15-implementation/part-08`).

The next stage after this follow-up is the next architecture work,
which is out of scope. The Manager closure decision 1 (2026-06-13)
reclassified B02/B05/B06 to NOT-IN-SCOPE for the MTP fixture; that
reclassification should be revisited after the QA verification of
this fix on the MTP fixture. The Manager owns the row update in
`._design_docs/cache-handling-stage-tracker.md` if the reclassification
needs to be reversed.

The test plan follow-up picks up the proposed test plan rows
TP-15-PC1..TP-15-PC7.
