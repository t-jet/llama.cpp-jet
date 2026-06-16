# Stage 15 design part 9: post-closure follow-up — chat-path prompt-span boundary

Status: design correction + bug-fix expansion, 2026-06-16 (F-16-TR-06 matching-loop relaxation appended 2026-06-16)
Stage: 15 (post-closure follow-up), F-16-TR-02 expansion
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

## Bug-fix correction (2026-06-16)

Test execution
[test-report-20260616-01.md](../.test_reports/test-report-20260616-01.md)
FAILed. All 7 operational rows (TP-15-PC1..PC7) FAILed on the MTP
fixture. Root cause F-16-TR-02: the MTP speculative-decoding
internal context checkpoint is created at position 10 with
`n_tokens = 11` (a speculative step boundary at end of the user
message, not end-of-prefill). The Option A single-boundary fix
emits a `[0, n_prompt_tokens]` boundary (= 61 in the test
prompt) which does not match the MTP internal checkpoint's
`n_tokens = 11`. The strict validator at
`server-cache-hybrid.cpp:2984` returns
`missing checkpoint boundary metadata`.

Model log evidence on a longer user workload (Qwen3.6-27B-MTP,
`._analysis/model_log.txt`) shows the MTP path creates checkpoints
at growing positions: `n_tokens = 9, 17, 70, 196, 709, 60959,
61269, 11829, 12309, 21141, 21525, 22033, 22929, 23313, 23637, ...`.
The first checkpoint position grows with prompt length and is
not at fixed `min spacing` intervals. For the failing test prompt
(61 tokens, 3 messages), the first MTP checkpoint is at
`n_tokens = 11` which is the end of the user message.

### Expanded fix: per-checkpoint prompt-span boundaries

The Option A single-boundary fix is insufficient. The fix must emit
a per-checkpoint prompt-span boundary for every position the MTP
path can create a checkpoint at, not just at end of prefill. For
the chat path, the per-message loop already iterates all messages
and computes `token_end` for each. Adding a `[0, token_end]`
boundary inside the loop emits one boundary per message end
position, which covers:

- The first MTP internal checkpoint at end of user message
  (`n_tokens = 11` in the test prompt, matches the user message
  end position).
- Any MTP internal checkpoint that happens to align with a message
  end position.
- The end-of-prefill checkpoint (`n_tokens = n_prompt_tokens`),
  covered by the last message's `[0, token_end]` boundary
  (the assistant message ends at `n_prompt_tokens` for
  standard chat templates).

The existing `[0, n_prompt_tokens]` end-of-prompt boundary at the
bottom of the function is kept as a safety net for the case where
no message ends at `n_prompt_tokens` (e.g., system + user only,
no assistant message). The matching loop at
`server-cache-hybrid.cpp:3066-3078` picks the first boundary
whose `token_end == descriptor.token_span_end`; the per-message
boundaries appear earlier in the list than the end-of-prompt
boundary, so they take precedence.

The per-message boundary emission adds 1 boundary per message to
the metadata. For typical chat-completion requests (1-5 messages),
this is 1-5 additional boundaries. For empty `messages`, the
`!messages.empty()` guard still applies (the loop is a no-op).

### Code change (F-16-TR-02 fix)

In `cache_metadata_from_chat_messages` (server-context.cpp:4383),
add a new `[0, token_end]` `MESSAGE_END` boundary inside the
per-message loop, right after the existing `MESSAGE_END`
boundary. 15-line insertion, 0 deletions. The new boundary has
`metadata = "prompt"`, `protect = false`, and a checksum
computed over `[0, token_end]` via `cache_metadata_checksum`.

### Why per-message instead of pre-computing all MTP positions

The MTP path's checkpoint positions are not predictable from the
chat structure alone. The model log shows positions that grow
with prompt length and follow a non-linear pattern (9, 17, 70,
196, 709, ...). Pre-computing these positions in the metadata
function would require duplicating the MTP speculative-decoding
internal checkpoint creation logic, which is fragile and
out-of-scope for a chat-path metadata function.

The per-message approach covers the test case (61-token prompt,
first MTP checkpoint at end of user message) and any future case
where the MTP creates a checkpoint at a message end position.
For longer prompts where the MTP creates checkpoints at
non-message-end positions, the same F-16-TR-02 issue would
recur; that is a separate Manager decision (revisit the
strict-validator matching loop per Option B in the test report).

### Updated traceability

| Source | Link (updated 2026-06-16) |
| --- | --- |
| Code change (per-message boundary) | `tools/server/server-context.cpp:cache_metadata_from_chat_messages` lines 4473-4483 (new 11-line block) |
| Code change (end-of-prompt boundary, kept) | `tools/server/server-context.cpp:cache_metadata_from_chat_messages` lines 4502-4504 (unchanged from 2026-06-16 original fix) |
| Test report (FAIL) | `._design_docs/.test_reports/test-report-20260616-01.md` |
| Test fixes file (F-16-TR-02 detail) | `._design_docs/.test_reports/test-report-20260616-01-fixes.md` |
| Implementation evidence (F-16-TR-02 fix) | `._design_docs/cache-handling-phase16-implementation/part-03-bugfix-mtp-internal-checkpoint.md` |

## Bug-fix correction iteration 2 (F-16-TR-06, 2026-06-16)

Test execution
[test-report-20260616-02.md](../.test_reports/test-report-20260616-02.md)
FAILed again after F-16-TR-02. The matching loop at
`server-cache-hybrid.cpp:3066-3081` still rejects because the
MTP checkpoint position (`n_tokens=11`) does not align with any
chat-path message boundary. The QA hypothesis that the user
message ends at token 11 is wrong: the test prompt's user
message is the ~50-token "Explain the major architectural
differences..." prompt, so the system prompt-span boundary has
`token_end` ~12 and the user prompt-span boundary has
`token_end` ~62; neither equals 11. MTP positions follow
the model's internal speculative-decoding state.

### F-16-TR-06 fix: relax the matching loop for "prompt" boundaries

Relax the matching loop in
`server-cache-hybrid.cpp:attach_checkpoint_payload` and the
strict validator in `validate_checkpoint_descriptor_metadata`
to pick the largest boundary with
`token_end <= descriptor.token_span_end`, restricted to
boundaries whose `metadata == "prompt"`. The per-message
prompt-span boundaries (F-16-TR-02) and the end-of-prompt
boundary all have `metadata = "prompt"`. For non-prompt
boundaries (e.g., test fixtures with `metadata = "msg-1"`) the
strict `token_end == descriptor.token_span_end` match is
preserved, so test_stage9 holds. The descriptor's
`boundary_checksum` is recomputed over the descriptor's span
and the strict validator's checksum recompute uses the same
span.

### Updated traceability (F-16-TR-06)

| Source | Link |
| --- | --- |
| Code change (matching-loop + strict-validator relaxation) | `tools/server/server-cache-hybrid.cpp:attach_checkpoint_payload` and `validate_checkpoint_descriptor_metadata` |
| Test report (FAIL iteration 2) | `._design_docs/.test_reports/test-report-20260616-02.md` |
| Bug-fix loop file (F-16-TR-06 detail) | `._design_docs/.test_reports/test-report-20260616-02-fixes.md` |
| Implementation evidence (F-16-TR-06 fix) | `._design_docs/cache-handling-phase16-implementation/part-05-bugfix-iteration-2-mtp-matching.md` |
