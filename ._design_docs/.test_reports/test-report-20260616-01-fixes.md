# Test report 2026-06-16 01 - fixes: Stage 16 chat-path prompt-span boundary (BUG-FIX LOOP)

Status: OPEN (Developer bug-fix loop)
Date: 2026-06-16
Trigger: [test-report-20260616-01.md](test-report-20260616-01.md) (FAIL, 7 operational rows)
Owner: Developer (in fresh session)
Source: [part-26-stage16-chat-path-prompt-boundary.md](../cache-handling-test-plan/part-26-stage16-chat-path-prompt-boundary.md)

## Bug-fix loop open findings (from parent test-report-20260616-01.md)

| ID | Severity | Title | Action |
| --- | --- | --- | --- |
| F-16-TR-01 | non-blocking (test plan) | TP-15-UT1, TP-15-UT2 test cases missing in tests/test-cache-controller.cpp | Add two new test functions: UT1 calls `cache_metadata_from_chat_messages` with 3-message input and asserts a `MESSAGE_END` boundary at `[0, n_prompt_tokens]` with `metadata == "prompt"`; UT2 calls it with empty `messages` array and asserts no prompt-span boundary added. |
| F-16-TR-02 | blocking (product) | Stage 16 fix is broken on the MTP fixture | See below. |
| F-16-TR-03 | blocking (coverage setup) | Coverage BLOCKED by Release build without /Zi | Add `/Zi /DEBUG` (or `/DEBUG:FULL`) to `CMAKE_CXX_FLAGS_RELEASE` so OpenCppCoverage can produce real coverage data. |
| F-16-TR-04 | none | PC5 omitted as duplicate of PC4 (3-message input already exercised in PC4) | No action. |
| F-16-TR-05 | non-blocking (test plan) | TP-15-PC7 expected count (5) does not match --ctx-size 4096 baseline (1) | Update test plan PC7 to state the actual --ctx-size and the expected count under that config, or note that 5 is the 140032 default. |

## F-16-TR-02 detailed root cause and recommended fix

The Stage 16 fix in commit `ae2df9657` adds a single
`MESSAGE_END` boundary at `[0, n_prompt_tokens]` with
`metadata = "prompt"` in
`tools/server/server-context.cpp:cache_metadata_from_chat_messages`,
after the per-message loop. The fix design assumed the first
end-of-prefill checkpoint has `n_tokens == n_prompt_tokens`, which
is true on the V2 separate-draft fixture (no speculative
decoding) but NOT on the MTP fixture.

On the MTP fixture, the speculative-decoding internal context
checkpoint is created at position 10 with
`pos_min = 10, pos_max = 10, n_tokens = 11` (a speculative step
boundary, not end-of-prefill). The fix's new boundary's
`token_end = n_prompt_tokens` (= 61 for the PC1-PC3 prompt) does
not match the checkpoint's `n_tokens = 11`. The
descriptor-build loop at
`tools/server/server-cache-hybrid.cpp:3066-3078` iterates
`source_metadata->boundaries` looking for the first one with
`boundary.token_end == descriptor.token_span_end`. No boundary
in the chat path's 9 boundaries has `token_end == 11`, so the
fallback at line 3081 sets
`checkpoint_boundary_required = true` with empty
`boundary_id`/`checkpoint_boundary_kind`. The strict validator at
`server-cache-hybrid.cpp:2984` returns
`missing checkpoint boundary metadata`.

The fix's evidence on the MTP fixture is exactly the same as
pre-fix: 0/30 successful restores, 1 admission failure on the
first save, all 29 subsequent requests are misses.

### Recommended fix (Option A expanded)

Add a per-checkpoint prompt-span boundary emission in
`cache_metadata_from_chat_messages`, in addition to the existing
end-of-prompt boundary. For each checkpoint that will be created
during prefill, emit a boundary at `[0, n_tokens]` where
`n_tokens` is the checkpoint's `n_tokens` (or fall back to
`n_prompt_tokens` for end-of-prefill checkpoints). The
descriptor-build loop at line 3066 will then match the
appropriate boundary.

The number of prefill checkpoints on the MTP fixture is bounded
by `max = 32` (per `context checkpoints enabled, max = 32, min
spacing = 256` log line). Emitting 1-32 prompt-span boundaries
per request is acceptable for metadata cost; the existing
fallback path already adds 2 boundaries (MESSAGE_START + MESSAGE_END
at `[0, tokens.size()]`).

The Developer must verify on the V2 separate-draft fixture that
the existing per-message boundaries + the new prompt-span
boundaries do not regress the 29/29 hit rate. Per Stage 15
`stage15-benchmark-20260613-03.md`, the V2 fixture's
`cache_checkpoint_admissions_total = 0` (V2 has no checkpoint
path; only regular entries), so the new boundaries must not
interfere with regular-entry admission or the matching loop.

### Alternative (Option B)

Relax the descriptor-build loop to pick any prompt-span boundary
whose `token_end >= checkpoint n_tokens` and re-checksum the
boundary span over the actual checkpoint token range. This is
the Option B scope that the Stage 16 design excluded. Easier
to implement but relaxes the strict validator invariant; the
Architect design review would need to revisit Option B.

### Alternative (Option C, not recommended)

Reclassify the MTP fixture as NOT-IN-SCOPE for
`/v1/chat/completions` exact-blob restore, per Stage 15 Manager
decision 1. This abandons the Stage 16 fix's value on the MTP
fixture and contradicts the design part-09 root cause analysis
that identified the chat-path boundary gap.

## Handoff

This bug-fix loop file is the Developer follow-up record. After
fixes, the Developer must rebuild and re-run the test plan
through a fresh QA session. The next QA session will create a
follow-up test report `test-report-20260616-02.md` (or higher
suffix) that records the re-run results.
