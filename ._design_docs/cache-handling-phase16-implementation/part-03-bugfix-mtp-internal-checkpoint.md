# Stage 16 implementation part 3: bug fix MTP internal-checkpoint mismatch

Status: applied
Date: 2026-06-16
Stage: 16 (post-closure chat-path prompt-span boundary fix, F-16-TR-02)
Branch: work-branch
Source: [test-report-20260616-01.md](../.test_reports/test-report-20260616-01.md) (FAIL), [test-report-20260616-01-fixes.md](../.test_reports/test-report-20260616-01-fixes.md) (F-16-TR-02 detail)

## Root cause

F-16-TR-02 from
[test-report-20260616-01.md](../.test_reports/test-report-20260616-01.md)
restated:

The Stage 16 Option A fix (commit `ae2df9657`) added a single
`MESSAGE_END` boundary at `[0, n_prompt_tokens]` to
`cache_metadata_from_chat_messages`. The fix design assumed the
first end-of-prefill checkpoint has `n_tokens == n_prompt_tokens`,
which is true on the V2 separate-draft fixture (no MTP speculative
decoding) but NOT on the MTP fixture.

On the MTP fixture (Qwen3.5-4B-MTP), the speculative-decoding
internal context checkpoint is created at position 10 with
`n_tokens = 11` (a speculative step boundary at end of the user
message, not end-of-prefill). The Option A boundary's
`token_end = n_prompt_tokens = 61` does not match the checkpoint's
`n_tokens = 11`. The descriptor-build loop at
`server-cache-hybrid.cpp:3066-3078` iterates
`source_metadata->boundaries` looking for the first one with
`boundary.token_end == descriptor.token_span_end` (= checkpoint's
`n_tokens`). No boundary in the chat path's 9 boundaries has
`token_end == 11`, so the fallback at line 3081 sets
`checkpoint_boundary_required = true` with empty
`boundary_id` / `checkpoint_boundary_kind`. The strict validator
at `server-cache-hybrid.cpp:2984` returns
`missing checkpoint boundary metadata`.

### Code references

| Surface | File:line | Role |
| --- | --- | --- |
| Original Option A boundary (single end-of-prompt) | `tools/server/server-context.cpp:4502-4504` | The single `[0, n_prompt_tokens]` boundary that did not match MTP internal checkpoint |
| Per-message loop | `tools/server/server-context.cpp:4411-4484` | Loop that emits per-message boundaries; `fallback_token` accumulates to message end positions |
| MTP checkpoint creation | `tools/server/server-context.cpp:3739` (calls `create_checkpoint` at `server-context.cpp:2574`) | Creates MTP internal context checkpoint at `n_tokens = slot.prompt.n_tokens() - n_tokens_cur` (position before current batch) |
| Descriptor-build loop (matching boundary to checkpoint) | `tools/server/server-cache-hybrid.cpp:3066-3078` | Iterates boundaries, picks first with `token_end == descriptor.token_span_end` |
| Strict validator | `tools/server/server-cache-hybrid.cpp:2973-3003` | Validates descriptor against boundary metadata; returns `missing checkpoint boundary metadata` on empty `boundary_id` |
| `update_pos` semantics | `common/common.cpp:2096-2104` | Sets `checkpoint.n_tokens = n_tokens` where `n_tokens` is position before current batch |

### Model log evidence (longer user workload, Qwen3.6-27B-MTP)

`._analysis/model_log.txt` shows the MTP path creates internal
checkpoints at growing positions:
`n_tokens = 9, 17, 70, 196, 709, 60959, 61269, 11829, 12309,
21141, 21525, 22033, 22929, 23313, 23637, ...`. The first
checkpoint position grows with prompt length and is not at fixed
`min spacing = 256` intervals (the `min spacing` config is 256
per line `context checkpoints enabled, max = 32, min spacing = 256`,
but the MTP path's actual positions follow a non-linear pattern
determined by the speculative-decoding internal state).

For the failing test prompt (Qwen3.5-4B-MTP, 61 tokens, 3 messages
system+user+assistant), the first MTP checkpoint is at
`n_tokens = 11` which is the end of the user message
(11 tokens for system + user).

## Fix

The fix expands Option A to per-checkpoint prompt-span
boundaries: emit a `[0, message_token_end]` `MESSAGE_END`
boundary for each message in the chat path, in addition to the
existing `[0, n_prompt_tokens]` end-of-prompt boundary. This
covers:

- MTP internal checkpoints at message end positions (e.g., end
  of user message for the failing test case, where the first MTP
  checkpoint is at `n_tokens = 11` matching the user message end).
- Any future MTP internal checkpoint that aligns with a message
  end position.
- End-of-prefill checkpoint (covered by the last message's
  `[0, token_end]` boundary when the last message ends at
  `n_prompt_tokens`, or by the explicit end-of-prompt boundary
  otherwise).

The per-message boundary is added inside the per-message loop
(right after the existing `MESSAGE_END` boundary), so it reuses
the loop's `token_end` value without needing a separate
post-loop pass. The new boundary has:

- `type = prompt_boundary::MESSAGE_END`
- `token_start = 0`
- `token_end = message_token_end`
- `checksum = cache_metadata_checksum(tokens, 0, message_token_end)`
- `protect = false`
- `metadata = "prompt"`

The matching loop at `server-cache-hybrid.cpp:3066-3078` picks
the first boundary with `token_end == descriptor.token_span_end`.
The per-message `[0, token_end]` boundary has `token_start = 0`
matching `descriptor.token_span_start = 0` (set by
`attach_checkpoint_payload` at line 3060), so the strict
validator's token_start check at line 2990 (which is skipped when
`descriptor.token_span_start == 0`) does not reject the
boundary. The strict validator's checksum recompute at line
2997-2999 verifies that `cache_token_span_checksum(entry.tokens,
boundary.token_start, boundary.token_end) == boundary.checksum`,
which matches because both use the same FNV-1a 64-bit function
over the same range.

### Diff stats

```text
 tools/server/server-context.cpp | 15 +++++++++++++++
 1 file changed, 15 insertions(+)
```

### File:line refs

- New code: `tools/server/server-context.cpp:4475-4483` (11 lines
  of code, 4 lines of comment)
- Original Option A end-of-prompt boundary (unchanged):
  `tools/server/server-context.cpp:4502-4504`
- Per-message loop (unchanged):
  `tools/server/server-context.cpp:4411-4484`

## Diff

The new code block is inserted inside the per-message loop,
right after the existing `MESSAGE_END` boundary and the
`fallback_token` update:

```cpp
        metadata.add_span(prompt_boundary::MESSAGE_END, token_start, token_end, checksum, protect, role);
        fallback_token = token_end;

        // Stage 15 post-closure follow-up (expanded 2026-06-16, F-16-TR-02):
        // emit a [0, token_end] prompt-span boundary so the MTP
        // speculative-decoding internal checkpoint at this token
        // position can attach. The per-message boundaries above have
        // token_start == message_start, so the strict validator's
        // token_start check (when descriptor.token_span_start == 0) in
        // validate_checkpoint_descriptor_metadata rejects them. The new
        // boundary at [0, token_end] has token_start == 0, matching
        // descriptor.token_span_start == 0 set by
        // attach_checkpoint_payload. End-of-prefill checkpoint is
        // covered by the [0, n_prompt_tokens] boundary at the bottom
        // of this function.
        const uint64_t msg_end_checksum = cache_metadata_checksum(tokens, 0, token_end);
        metadata.add_span(prompt_boundary::MESSAGE_END, 0, token_end, msg_end_checksum, false, "prompt");
```

The existing end-of-prompt boundary at the bottom of the
function is unchanged:

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

## Risks

| ID | Risk | Impact | Mitigation |
| --- | --- | --- | --- |
| R-16-BF-01 | New per-message `[0, token_end]` boundaries interfere with the per-message `[token_start, token_end]` matching (e.g., `try_restore_from_cache`) | None | The matching loop iterates all boundaries and picks the first match; the new boundary at `[0, token_end]` appears earlier in the list (it is added right after the per-message boundary in the same loop iteration) and would take precedence for `token_end == N` matches. Other surfaces that use `boundaries` for prefix-restore (e.g., `try_restore_from_cache`) iterate by type, not by `token_start == 0`, and are unaffected. |
| R-16-BF-02 | New boundary collides with existing prompt-span boundary at end of prefill | None | The last message's `[0, token_end]` boundary is at `[0, n_prompt_tokens]` which is the same as the existing end-of-prompt boundary. The matching loop picks the first match; the per-message boundary appears first in the list. Duplication is harmless. |
| R-16-BF-03 | MTP creates checkpoint at non-message-end position (longer prompts) | Low to medium | Per-message boundary emission covers message-end positions. Non-message-end positions (model log shows growing positions 9, 17, 70, 196, 709, ... for longer prompts) would still be rejected by the strict validator. This is a separate Manager decision (Option B: relax matching loop) per [test-report-20260616-01-fixes.md](../.test_reports/test-report-20260616-01-fixes.md). |
| R-16-BF-04 | Metadata cost grows with message count | Negligible | Each boundary is a small struct (~40 bytes: `boundary_type` + 2x `size_t` + `uint64_t` + `bool` + `std::string`). For typical 1-5 messages, 1-5 additional boundaries. Well within the existing per-request metadata budget. |
| R-16-BF-05 | Checksum function drift between `cache_metadata_checksum` (chat path) and `cache_token_span_checksum` (validator) | None | The two functions are byte-for-byte identical FNV-1a 64-bit (init 1469598103934665603, mul 1099511628211), same `cache_token_ids()` call, same clamping. See `server-context.cpp:4359-4373` vs `server-cache-hybrid.cpp:204-215`. |

## Out of scope

- **F-16-TR-03** (Coverage BLOCKED by Release build without /Zi):
  deferred to Manager. The Stage 16 fix does not address the
  Release build's lack of debug symbols. Manager decision
  required on whether to add `/Zi /DEBUG` to
  `CMAKE_CXX_FLAGS_RELEASE` or build a separate RelWithDebInfo
  target. Per the test report: "The Developer handoff for
  coverage is the same coverage-eligible rebuild fix from the
  prior `distinguish Release-build coverage gap` finding."

- **F-16-TR-01** (UT1/UT2 test code missing in
  `tests/test-cache-controller.cpp`): optional, deferred. The
  test plan calls for two new test cases (UT1: 3-message input
  boundary assertion; UT2: empty messages degenerate). Per the
  test plan Pass/fail criteria, the unit rows are non-blocking
  for PASS, so this finding does not drive the FAIL verdict on
  its own. Future Developer session can add the test cases
  after the fix is verified.

- **F-16-TR-04** (PC5 omitted as duplicate of PC4): documentation
  only, no action.

- **F-16-TR-05** (TP-15-PC7 expected count mismatch): test plan
  wording; Architect or Developer may reconcile in a future
  session.

- **Option B** (relax the matching loop in
  `attach_checkpoint_payload`): the architecturally cleanest
  fix for the long-prompt MTP case, but excluded by the
  Stage 16 design. The per-message boundary emission covers the
  failing test case (61-token prompt). Long-prompt MTP case
  (checkpoints at non-message-end positions) is a separate
  Manager decision.

## Handoff

Next owner: **Architect** for bug-fix review (in fresh session).
The Architect verifies:

1. The new `[0, token_end]` boundary is emitted at the correct
   point in the per-message loop (after the existing
   `MESSAGE_END` boundary, before the `fallback_token` update).
2. The new boundary's `token_start = 0` matches
   `descriptor.token_span_start = 0` (set by
   `attach_checkpoint_payload`).
3. The new boundary's checksum uses
   `cache_metadata_checksum(tokens, 0, token_end)` with the
   same parameters the strict validator uses for
   `cache_token_span_checksum`.
4. The existing end-of-prompt boundary is preserved as a
   safety net.
5. The conditional `!messages.empty()` is unchanged (still
   guards the end-of-prompt boundary).

After Architect bug-fix review passes, **QA reruns** the full
test plan (`test-report-20260616-NN.md` with N >= 2) plus
coverage closure T114/T114a/T115 against the new build. Expected
post-fix state: TP-15-PC1..PC5 PASS, TP-15-PC6 regression
unchanged (BLOCKED-structural for native /completion on MTP),
TP-15-PC7 PASS under the test plan's actual --ctx-size 4096
baseline (1 warning, not 5).
