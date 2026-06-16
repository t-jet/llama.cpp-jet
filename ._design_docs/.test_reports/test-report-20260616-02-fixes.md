# Test report 2026-06-16 02 - fixes: Stage 16 chat-path prompt-span boundary (BUG-FIX LOOP iteration 2)

Status: OPEN (Developer bug-fix loop iteration 2)
Date: 2026-06-16
Trigger: [test-report-20260616-02.md](test-report-20260616-02.md) (FAIL, 7 operational rows)
Owner: Developer (in fresh session)
Source: [part-26-stage16-chat-path-prompt-boundary.md](../cache-handling-test-plan/part-26-stage16-chat-path-prompt-boundary.md)

## Bug-fix loop open findings (from parent test-report-20260616-02.md)

| ID | Severity | Title | Action |
| --- | --- | --- | --- |
| F-16-TR-06 | blocking (product) | Bug fix does not resolve checkpoint admission on MTP fixture | See below. |
| F-16-TR-03 | blocking (coverage setup) | Coverage BLOCKED by Release build without /Zi | Add `/Zi /DEBUG` (or `/DEBUG:FULL`) to `CMAKE_CXX_FLAGS_RELEASE` so OpenCppCoverage can produce real coverage data. |
| F-16-TR-01 | non-blocking (test plan) | TP-15-UT1, TP-15-UT2 test cases missing in tests/test-cache-controller.cpp | Add two new test functions: UT1 calls `cache_metadata_from_chat_messages` with 3-message input and asserts a `MESSAGE_END` boundary at `[0, n_prompt_tokens]` with `metadata == "prompt"`; UT2 calls it with empty `messages` array and asserts no prompt-span boundary added. |
| F-16-TR-05 | non-blocking (test plan) | TP-15-PC7 expected count (5) does not match --ctx-size 4096 baseline (1) | Update test plan PC7 to state the actual --ctx-size and the expected count under that config. |

## F-16-TR-06 detailed root cause and recommended fix

The F-16-TR-02 fix (commit `ae2df9657` + uncommitted
`tools/server/server-context.cpp` +15 lines at lines 4458-4478)
adds per-message `[0, token_end]` prompt-span boundaries inside
the per-message loop. The fix is verified at the chat path
boundary build: `cache metadata: source=openai-chat
method=rendered-text-boundary-inference degraded=rendered text
boundary inference tokens=61 boundaries=12` (5 system + 3 user +
3 assistant + 1 end-of-prompt; +3 per-message prompt-span vs
prior Option A fix's 9 boundaries).

The MTP fixture's speculative-decoding internal context
checkpoint is at `n_tokens=11` (end of user message). The fix
adds a per-message `[0, 11]` boundary for the user message. The
matching loop at
`tools/server/server-cache-hybrid.cpp:3066-3081` iterates
`source_metadata->boundaries` looking for the first boundary with
`boundary.checksum != 0` AND `boundary.token_end == descriptor.token_span_end`
(= 11). The user MESSAGE_END at `[2, 11]` is the first match
(token_end=11, non-zero checksum). The matching loop sets
`descriptor.boundary_id = "user"`,
`descriptor.checkpoint_boundary_kind = MESSAGE_END`,
`descriptor.boundary_checksum = checksum(2, 11)`,
`descriptor.checkpoint_boundary_required = true`. The strict
validator at `server-cache-hybrid.cpp:2988-3001` re-iterates
boundaries looking for type=MESSAGE_END, metadata="user",
token_end=11, checksum=checksum(2, 11). The user MESSAGE_END
boundary matches all four fields. The checksum recompute
`cache_token_span_checksum(entry.tokens, 2, 11)` should equal
the boundary.checksum.

Despite this expected match, the strict validator returns
`missing checkpoint boundary metadata` from the pre-loop check at
line 2984:

```cpp
if (!descriptor.checkpoint_boundary_required || descriptor.boundary_id.empty() ||
    descriptor.boundary_checksum == 0 || descriptor.checkpoint_boundary_kind < 0) {
    return fail("missing checkpoint boundary metadata");
}
```

This pre-loop check rejects when any of the four descriptor
fields are at their default (boundary_id="", boundary_checksum=0,
checkpoint_boundary_kind=-1, checkpoint_boundary_required=false).
The matching loop only sets these fields when a boundary is
found. If no boundary is found, the matching loop sets only
`checkpoint_boundary_required = true` (line 3081 fallback),
leaving the other three fields at default.

### Root cause hypothesis

The matching loop does not find a boundary with
`token_end == 11` and `checksum != 0`, despite the chat path
emitting 12 boundaries (5 system + 3 user + 3 assistant +
1 end-of-prompt). Possible causes (in priority order):

1. **`boundary.checksum == 0` for the user MESSAGE_END
   boundary**: if the user message has token_start > 0 (e.g.,
   system message tokens precede user content), the per-message
   `cache_metadata_checksum(tokens, 2, 11)` might return 0 for
   this token range. The FNV-1a 64-bit hash with init
   `1469598103934665603ull` and mul `1099511628211ull` produces 0
   only for the empty input (no tokens). For 9 tokens (indices
   2-10 inclusive), the checksum is non-zero. Unlikely.

2. **`entry.metadata.boundaries` is empty at the time of
   admit_latest_checkpoint**: the entry.metadata is set in
   `admit_entry_with_payload` from the chat metadata. If the
   `entry.metadata` is cleared or replaced between
   `admit_entry_with_payload` and `admit_latest_checkpoint`, the
   matching loop would see an empty boundary list. The `save_slot`
   code at `server-context.cpp:6334-6352` sets `entry.metadata`
   in `admit_entry_with_payload` and immediately calls
   `admit_latest_checkpoint(*it_new, ...)` without intermediate
   `entry.metadata` mutation. The `entry.metadata` should
   contain 12 boundaries.

3. **The matching loop's `source_metadata` is not the
   `entry.metadata`**: the call site at
   `admit_latest_checkpoint` passes `&entry.metadata` as the
   `metadata` parameter. In `attach_checkpoint_payload`,
   `source_metadata = metadata ? metadata : &entry.metadata`.
   Since `metadata` is non-null, `source_metadata = metadata =
   &entry.metadata`. The entry.metadata should have 12
   boundaries.

4. **The descriptor's `token_span_end` is not 11**: the
   descriptor's `token_span_end` is set to
   `checkpoint->n_tokens` at line 3060. The MTP checkpoint's
   `n_tokens` is 11 (verified from server log: `pos_min = 10,
   pos_max = 10, n_tokens = 11`). The descriptor's
   `token_span_end` should be 11.

### Recommended fix (iteration 2)

The Developer must add debug logging to the matching loop in
`server-cache-hybrid.cpp:3066-3081` to confirm which boundaries
are iterated, their `token_end` and `checksum` values, and why
none match `token_end=11`. The debug log should be guarded by a
test-only flag (e.g., `LLAMA_SERVER_CACHE_TESTS`) or a
verbosity level.

After confirming the root cause, the fix depends on which
hypothesis is correct:

- **Hypothesis 1 (checksum=0)**: fix the per-message checksum
  computation in `cache_metadata_from_chat_messages` at
  `server-context.cpp:4458-4459`. The checksum should be
  non-zero for any non-empty token range.
- **Hypothesis 2 (empty entry.metadata)**: fix the
  `admit_entry_with_payload` or `save_slot` to preserve the
  chat metadata on the entry. The current code does
  `entry.metadata = metadata` which should preserve 12
  boundaries.
- **Hypothesis 3 (wrong source_metadata)**: fix the call site at
  `admit_latest_checkpoint` to pass the chat metadata instead
  of `&entry.metadata`. The current code passes `&entry.metadata`
  which should be the same as the chat metadata.
- **Hypothesis 4 (wrong token_span_end)**: fix the
  `attach_checkpoint_payload` to set the descriptor's
  `token_span_end` from the chat metadata's prompt-span boundary
  instead of `checkpoint->n_tokens`.

### Alternative (Option B, expanded)

Relax the matching loop to pick any prompt-span boundary whose
`token_end >= checkpoint n_tokens` and re-checksum the boundary
span over the actual checkpoint token range. This is the
Option B scope that the Stage 16 design excluded. The matching
loop at `server-cache-hybrid.cpp:3066-3081` would change from
`boundary.token_end != descriptor.token_span_end` to
`boundary.token_end < descriptor.token_span_end`. The strict
validator at `server-cache-hybrid.cpp:2997-2999` would re-checksum
over `[descriptor.token_span_start, descriptor.token_span_end]`
instead of `[boundary.token_start, boundary.token_end]`. This is
architecturally cleaner but requires Architect design review.

### Alternative (Option C, not recommended)

Reclassify the MTP fixture as NOT-IN-SCOPE for
`/v1/chat/completions` exact-blob restore, per Stage 15 Manager
decision 1. This abandons the Stage 16 fix's value on the MTP
fixture and contradicts the design part-09 root cause analysis.

## Handoff

This bug-fix loop file is the Developer follow-up record. After
fixes, the Developer must rebuild and re-run the test plan
through a fresh QA session. The next QA session will create a
follow-up test report `test-report-20260616-03.md` (or higher
suffix) that records the re-run results.
