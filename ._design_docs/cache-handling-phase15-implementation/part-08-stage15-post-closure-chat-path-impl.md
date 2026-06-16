# Stage 15 implementation part 8: post-closure follow-up — chat-path prompt-span boundary

Status: implementation applied, verification pending QA
Stage: 15 (post-closure follow-up, third-diff extension)
Date: 2026-06-16
Source design: [../cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md](../cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md)
Source architecture: [../cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md](../cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md)
Predecessor: Stage 15 B05/B06 two-diff fix (2026-06-13, "checkpoint
boundary search relaxed"), which removed the `token_start` filter
in the matching loop but did not address the chat-path boundary
coverage gap.

## Code change

Single insertion in `cache_metadata_from_chat_messages` at the end
of the per-message loop, before `return metadata`. The new
boundary is a `MESSAGE_END` at `[0, n_prompt_tokens]` with
`metadata = "prompt"`, `protect = false`, and a checksum
computed over the full prompt range via
`cache_metadata_checksum`. The insertion is conditional on
`!messages.empty()` to avoid emitting a boundary for an empty
`messages` array (the function returns early in that case before
the per-message loop).

File: `tools/server/server-context.cpp`

```cpp
// Stage 15 post-closure follow-up: emit a prompt-span boundary whose
// token_end equals the full prompt size so the first end-of-prefill
// hybrid cache checkpoint can attach. Per-message boundaries above
// cover message spans only; the assistant role header at the end of
// the rendered prompt has no boundary without this. The fallback path
// in cache_metadata_for_request emits the same shape when
// has_boundaries() is false; this normalizes the chat path. See
// ._design_docs/cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md
// and ._design_docs/cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md.
if (!messages.empty()) {
    const uint64_t prompt_checksum = cache_metadata_checksum(tokens, 0, n_prompt_tokens);
    metadata.add_span(prompt_boundary::MESSAGE_END, 0, n_prompt_tokens, prompt_checksum, false, "prompt");
}
```

## Diff summary

| File | Insertion | Deletion | Net |
| --- | --- | --- | --- |
| `tools/server/server-context.cpp` | 14 lines (1 conditional block + 10-line comment) | 0 | +14 |

The change is contained to one function in one file. No header
changes, no interface changes, no metric label changes, no public
API changes.

## Evidence

### Code-side

- The new boundary is added after the per-message loop
  unconditionally when `!messages.empty()`.
- The new boundary is added with the same `MESSAGE_END` type as
  the per-message boundaries and with `metadata = "prompt"`,
  matching the fallback path's shape in
  `cache_metadata_for_request`.
- The checksum is `cache_metadata_checksum(tokens, 0, n_prompt_tokens)`,
  which is the same function and the same range the strict
  validator at `server-cache-hybrid.cpp:validate_checkpoint_descriptor_metadata`
  uses to verify the descriptor's `boundary_checksum`.
- The `boundaries_native` flag is inherited from the chat
  path's existing `false` setting; the new boundary does not
  change it.

### Test-side (pending QA)

The test plan is a separate durable doc; this part proposes new
rows (TP-15-PC1..TP-15-PC7 in
[part-09](../cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md))
for the test plan follow-up to consider.

Direct verification of this implementation requires:

1. **Build verification**: `cmake --build build-cov --config
   Release --target llama-server` exit 0. The file touched is
   `server-context.cpp`; the change is contained to one function
   and does not require other recompiles.
2. **Unit test**: a new unit test in `tests/test-cache-controller.cpp`
   that calls `cache_metadata_from_chat_messages` with a
   representative chat input (3-message: system, user,
   assistant-prefix) and asserts the metadata has at least one
   `MESSAGE_END` boundary at `[0, n_prompt_tokens]` with
   `metadata == "prompt"`. This is a pure-metadata test, no
   model required.
3. **Integration test**: a new integration test that exercises
   hybrid cache save on the chat-completion path with the MTP
   fixture and asserts `n_checkpoint_payload_descriptors`
   increases after the first save (was 0 before the fix).
4. **QA benchmark rerun**: rerun the Stage 15 B05/B06 benchmark
   on the MTP fixture
   ([stage15-benchmark-20260613-03.md](../../.test_reports/stage15-benchmark-20260613-03.md))
   and assert the chat-completion variant now produces non-zero
   `cache_checkpoint_admissions_total` and `cache_n > 0` on
   subsequent identical requests.

The pre-fix state for the MTP /v1/chat/completions path had:

- 0/30 successful restores (per
  [stage15-benchmark-20260613-02.md](../../.test_reports/stage15-benchmark-20260613-02.md)
  BLOCKED-structural-not-infra).
- 10/10 `hybrid cache: checkpoint admission skipped (missing
  checkpoint boundary metadata)` warnings per
  [model log](../../../../llama.cpp-jet/._analysis/model_log.txt).
- 0 `n_checkpoint_payload_descriptors` in the cache stats.

The expected post-fix state on the same MTP fixture:

- 29/30 or 30/30 successful restores (mirroring the V2 separate-draft
  fix at 29/29).
- 0 `hybrid cache: checkpoint admission skipped` warnings on
  chat-completion paths.
- Non-zero `n_checkpoint_payload_descriptors` and
  `cache_checkpoint_admissions_total` after the first save.

## Risks observed during implementation

| Risk | Status | Resolution |
| --- | --- | --- |
| The new boundary is added even when per-message boundaries were not added (e.g., empty `messages` array) | Resolved by conditional | The conditional `!messages.empty()` skips the new boundary when the per-message loop also skipped. The function returns early in the empty-messages case before reaching the new code. |
| The new boundary's checksum does not match the entry's `cache_token_span_checksum` | Resolved by function selection | The new boundary uses `cache_metadata_checksum`, the same function the strict validator uses. Same range, same hash function. |
| The new boundary conflicts with the assistant role's `MESSAGE_END` | No conflict | The chat path does not emit a boundary for the assistant role (no content to search for in rendered text). The new boundary is the only one covering the assistant header. |
| The new boundary changes the `preparation_id` shape | No change | The `preparation_id` is set once in `cache_metadata_from_chat_messages` (line 4392) and is not modified by `add_span`. The shape is preserved. |
| The new boundary is added for the `messages.empty()` case (no per-message boundaries) | Resolved by conditional | The conditional guards against the empty case. The fallback path in `cache_metadata_for_request` already handles the `has_boundaries() == false` case by emitting the same boundary, so behavior is consistent. |
| The change requires recompiling the whole tree | No | The change is in one function in `server-context.cpp`. `cmake --build` recompiles only the affected translation unit. |

## Out of scope for this implementation

- The matching loop in `attach_checkpoint_payload` (unchanged).
- The strict validator in `validate_checkpoint_descriptor_metadata`
  (unchanged).
- The `boundaries_native` flag handling (unchanged).
- The public API, CLI flags, or metrics (unchanged).
- The test plan rows proposed in part-09 (the test plan is a
  separate durable doc).
- The cache stage tracker row update (the Manager owns that row
  per the improvement memory `Closure sweep keeps durable docs
  aligned without re-running the report`).

## Handoff

The next owner is the Architect for a focused re-review of the
new code change. The review should verify:

1. The boundary is added at the correct point in
   `cache_metadata_from_chat_messages` (after the per-message
   loop, before `return metadata`).
2. The conditional `!messages.empty()` is correct.
3. The checksum function call uses the same parameters the
   strict validator uses.
4. No other code path in the chat path or the fallback path is
   affected.
5. The existing unit tests in `tests/test-cache-controller.cpp`
   are unaffected (they use hand-crafted metadata, not the
   chat path).

The QA owner picks up the test plan rows proposed in
[part-09](../cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md)
(TP-15-PC1..TP-15-PC7) and adds them to the test plan. The
existing `cache-handling-test-plan.md` part files may need a new
row for the chat-completion hybrid cache save verification.

The Manager owner may need to update the cache stage tracker row
for Stage 15 to reflect the post-closure follow-up and the new
boundary in the chat path. The decision 1 reclassification
(B02/B05/B06 NOT-IN-SCOPE for the MTP fixture, 2026-06-13)
should be revisited after the QA verification confirms the fix
on the MTP fixture.

The user (or a future Architect session) is the next owner if
the QA verification surfaces a regression or a different
boundary-span mismatch (e.g., MTP draft tokens extending the
chat prompt beyond the main model prompt, making the new
boundary's `token_end` larger than the checkpoint's
`n_tokens`). In that case, the fix scope expands to a follow-up
design correction.
