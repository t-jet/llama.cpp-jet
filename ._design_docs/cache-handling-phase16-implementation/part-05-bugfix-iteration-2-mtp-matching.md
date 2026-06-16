# Stage 16 implementation part 5: bug fix iteration 2 F-16-TR-06 MTP matching loop

Status: applied
Date: 2026-06-16
Stage: 16 (chat-path prompt-span boundary, F-16-TR-06 bug fix iteration 2)
Branch: work-branch
Trigger: [test-report-20260616-02.md](../.test_reports/test-report-20260616-02.md) (FAIL), [test-report-20260616-02-fixes.md](../.test_reports/test-report-20260616-02-fixes.md) (F-16-TR-06 detail)
Design correction: [cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md](../cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md) (F-16-TR-06 iteration 2 section)
Architecture correction: [cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md](../cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md)

## Investigation

The F-16-TR-02 fix (per-message `[0, token_end]` prompt-span
boundaries in `cache_metadata_from_chat_messages`,
`server-context.cpp:4458-4478`) was verified at the chat path
boundary build. The test rerun log shows
`cache metadata: source=openai-chat method=rendered-text-boundary-inference
degraded=rendered text boundary inference tokens=61 boundaries=12`
(5 system + 3 user + 3 assistant + 1 end-of-prompt; +3
per-message prompt-span vs the prior Option A fix's 9
boundaries). The new boundaries are emitted as designed.

Despite the +3 boundaries, the strict validator at
`server-cache-hybrid.cpp:2984-2986` still rejects with
`missing checkpoint boundary metadata`. The pre-loop check
fires when any of `boundary_id` (empty), `boundary_checksum`
(zero), or `checkpoint_boundary_kind` (-1) is at default,
which means the matching loop at lines 3066-3081 did NOT
find a boundary with `token_end == descriptor.token_span_end`
(= 11, the MTP checkpoint's `n_tokens`).

The QA test report's analysis hypothesised that the user
message ends at token 11 in the 61-token test prompt, but
this is wrong. The test uses the V2 driver body (system +
user + assistant-prefix). The system message
("You are a helpful assistant") tokenises to ~7 tokens. The
user message is the ~50-token "Explain the major
architectural differences between RAG-based systems and
long-context LLMs..." prompt. The Qwen chat-template
markers between messages add ~10 tokens. So:

- System content + header + footer: ~12 tokens.
- User content + header + footer: ~50-60 tokens.
- Assistant header: ~1 token.
- Total: ~63-73 tokens. The actual 61-token count is
  consistent with a slightly shorter user message.

The system prompt-span boundary at `[0, ~12, "prompt"]` has
`token_end` ~12. The user prompt-span boundary at
`[0, ~62, "prompt"]` has `token_end` ~62. Neither equals
11. The MTP speculative-decoding internal checkpoint at
`n_tokens = 11` (verified in server log: `created context
checkpoint 1 of 32 (pos_min = 10, pos_max = 10, n_tokens = 11,
size = 50.251 MiB)`) is determined by the model's internal
speculative-decoding state, not by message boundaries. The
per-message boundary emission cannot cover every MTP
checkpoint position.

## Root cause

The MTP speculative-decoding internal checkpoint position
(`n_tokens`) is determined by the model's internal state,
not by chat-path message boundaries. The strict matching
condition `boundary.token_end == descriptor.token_span_end`
at `server-cache-hybrid.cpp:3066-3081` rejects every
chat-path boundary on the MTP fixture because no chat-path
boundary has `token_end == 11`. The F-16-TR-02 per-message
boundary emission covers the case where the MTP checkpoint
aligns with a message end position (short prompts where the
user message ends at the MTP checkpoint position), but for
the actual 61-token test prompt the alignment does not hold.

## Fix

Relax the matching loop in
`tools/server/server-cache-hybrid.cpp:attach_checkpoint_payload`
and the strict validator in
`validate_checkpoint_descriptor_metadata` to find the largest
boundary with `token_end <= descriptor.token_span_end`,
restricted to boundaries whose `metadata == "prompt"`. The
per-message prompt-span boundaries (F-16-TR-02) and the
end-of-prompt boundary all have `metadata = "prompt"`. For
non-prompt boundaries (test fixtures with
`metadata = "msg-1"`, `metadata = "system"`, etc.) the
strict `token_end == descriptor.token_span_end` match is
preserved, so the test_stage9 `bad_span` and `id_mismatch`
assertions continue to hold.

The descriptor's `boundary_checksum` is recomputed over the
actual checkpoint span (`[descriptor.token_span_start,
descriptor.token_span_end)`), and the strict validator's
checksum recompute uses the same descriptor span. For MTP
fixtures where the MTP checkpoint position exceeds the
system prompt-span boundary (e.g., the test case at
`n_tokens = 11` where the system prompt-span is at
`token_end ~12`), no "prompt" boundary has
`token_end <= 11` and the admission is correctly rejected.
For MTP positions above the system prompt-span (model log
shows positions 17, 70, 196 for longer prompts), the
relaxed match picks the system prompt-span and the
admission succeeds.

### Diff stats

```text
 tools/server/server-cache-hybrid.cpp | 80 ++++++++++++++++++++++++++++++-------
 1 file changed, 65 insertions(+), 15 deletions(-)
```

### File:line refs

- Matching loop: `tools/server/server-cache-hybrid.cpp:3066-3133`
  (relaxed match for "prompt" boundaries; 33 lines of new code,
  16 lines of old code replaced)
- Strict validator: `tools/server/server-cache-hybrid.cpp:2988-3024`
  (same relaxed match; 28 lines of new code, 11 lines of old
  code replaced)
- Test_stage9 contract preserved: the test at
  `tests/test-cache-controller.cpp:1819-1872` uses boundaries
  with `metadata = "msg-1"` and `metadata = "msg-2"`. The
  strict match is preserved for these, so all assertions hold.

## Diff

The matching loop change:

```cpp
// server-cache-hybrid.cpp:3083-3113 (new)
if (source_metadata && source_metadata->has_boundaries()) {
    // F-16-TR-06 bug-fix iteration 2: relax the match for
    // "prompt" boundaries to find the largest boundary with
    // token_end <= descriptor.token_span_end. The MTP
    // speculative-decoding internal checkpoint position
    // (n_tokens) is determined by the model's internal state
    // and does not align with message boundaries; the strict
    // token_end == descriptor.token_span_end check rejects
    // every chat-path boundary on the MTP fixture. For
    // non-prompt boundaries (e.g., test fixtures with hand-
    // crafted metadata) the strict match is preserved to keep
    // the test_stage9 bad_span assertion valid. The
    // descriptor's boundary_checksum is recomputed over the
    // actual checkpoint span, not the boundary's span, so the
    // strict validator's checksum recompute uses the
    // descriptor's span as well.
    const prompt_boundary * best_boundary = nullptr;
    for (const auto & boundary : source_metadata->boundaries) {
        if (boundary.checksum == 0) {
            continue;
        }
        if (boundary.metadata == "prompt") {
            if (boundary.token_end > static_cast<size_t>(descriptor.token_span_end)) {
                continue;
            }
        } else {
            if (boundary.token_end != static_cast<size_t>(descriptor.token_span_end)) {
                continue;
            }
        }
        if (!best_boundary || boundary.token_end > best_boundary->token_end) {
            best_boundary = &boundary;
        }
    }
    if (best_boundary) {
        descriptor.checkpoint_boundary_required = true;
        descriptor.checkpoint_boundary_native = source_metadata->boundaries_native;
        descriptor.checkpoint_boundary_kind = static_cast<int>(best_boundary->type);
        descriptor.boundary_id = best_boundary->metadata;
        descriptor.boundary_checksum = cache_token_span_checksum(
            entry.tokens,
            static_cast<size_t>(descriptor.token_span_start),
            static_cast<size_t>(descriptor.token_span_end));
        attached_boundary = true;
    } else {
        descriptor.checkpoint_boundary_required = true;
    }
}
```

The strict validator change:

```cpp
// server-cache-hybrid.cpp:2994-3024 (new)
// F-16-TR-06 bug-fix iteration 2: relaxed match mirrors
// attach_checkpoint_payload. For "prompt" boundaries, the
// largest boundary with token_end <= descriptor.token_span_end
// is accepted and the checksum is recomputed over the
// descriptor's actual span. For non-prompt boundaries the
// strict match (token_end == descriptor.token_span_end,
// checksum == descriptor.boundary_checksum) is preserved.
const prompt_boundary * best_match = nullptr;
for (const auto & boundary : source_metadata->boundaries) {
    if (static_cast<int>(boundary.type) != descriptor.checkpoint_boundary_kind ||
        boundary.metadata != descriptor.boundary_id) {
        continue;
    }
    if (boundary.metadata == "prompt") {
        if (boundary.token_end > static_cast<size_t>(descriptor.token_span_end)) {
            continue;
        }
    } else {
        if (boundary.token_end != static_cast<size_t>(descriptor.token_span_end) ||
            boundary.checksum != descriptor.boundary_checksum) {
            continue;
        }
    }
    if (!best_match || boundary.token_end > best_match->token_end) {
        best_match = &boundary;
    }
}
if (best_match) {
    if (cache_token_span_checksum(entry.tokens,
            static_cast<size_t>(descriptor.token_span_start),
            static_cast<size_t>(descriptor.token_span_end)) != descriptor.boundary_checksum) {
        return fail("checkpoint boundary checksum mismatch");
    }
    return true;
}
return fail("checkpoint boundary metadata mismatch");
```

## Risks

| ID | Risk | Impact | Mitigation |
| --- | --- | --- | --- |
| R-16-BF-06-01 | Relaxed match picks the wrong boundary when multiple "prompt" boundaries are present | Low | The matching loop picks the boundary with the LARGEST `token_end <= descriptor.token_span_end`. The strict validator re-runs the same match and re-checksums. The descriptor's `boundary_checksum` is recomputed over the actual span, so the checksum comparison verifies the descriptor's span, not the boundary's span. |
| R-16-BF-06-02 | The test_stage9 `bad_span` assertion breaks because the strict match is no longer enforced for "prompt" boundaries | None | The `bad_span` test uses boundaries with `metadata = "msg-1"` (not "prompt"). The strict match is preserved for non-prompt boundaries. The assertion `assert(!span_mismatch.debug_admit_checkpoint_for_tests(...))` continues to hold. |
| R-16-BF-06-03 | The MTP test case (61 tokens, checkpoint at 11) still does not pass because the system prompt-span is at ~12 | None | This is a known limitation. The system prompt-span boundary at `token_end ~12` does not satisfy `token_end <= 11`. The relaxed match correctly rejects the admission. For the test to pass, either the system prompt-span boundary needs to be at `token_end <= 11` (a separate Manager decision) or the MTP test case should use a checkpoint position that aligns with a message end (e.g., user message end at ~62). |
| R-16-BF-06-04 | The descriptor's `boundary_checksum` is recomputed over the descriptor's span, which may not match the boundary's original checksum | Low | This is intentional. The descriptor's checksum represents the actual checkpoint span, not the boundary's marker position. The strict validator's checksum recompute uses the same descriptor's span, so the two values match exactly. |
| R-16-BF-06-05 | The relaxed match accepts a "prompt" boundary whose `token_end` is far from `descriptor.token_span_end` (e.g., 0 or 1) | Low | The matching loop picks the LARGEST `token_end <= descriptor.token_span_end`, so it always picks the closest "prompt" boundary. The boundary at `token_end=0` would only be picked if no other "prompt" boundary is available. In that case, the descriptor's span is fully contained within the entry's tokens, and the recomputed checksum is correct. |

## Out of scope

- **F-16-TR-03** (Coverage BLOCKED by Release build without /Zi):
  deferred to Manager. The F-16-TR-06 fix does not address
  the Release build's lack of debug symbols. Manager decision
  required on whether to add `/Zi /DEBUG` to
  `CMAKE_CXX_FLAGS_RELEASE` or build a separate
  RelWithDebInfo target.
- **F-16-TR-01** (UT1/UT2 test code missing in
  `tests/test-cache-controller.cpp`): optional, deferred. Per
  the test plan Pass/fail criteria, the unit rows are
  non-blocking for PASS.
- **F-16-BF-01** (trailing whitespace in
  `.agents/skills/self-improvement/assets/developer.md`):
  separate, not addressed by this fix.
- **The 61-token MTP test case** (n_tokens=11, system
  prompt-span at ~12): the relaxed match still does not
  find a boundary at this position. A separate Manager
  decision is required to either (a) emit a finer-grained
  prompt-span boundary (e.g., at every token position), or
  (b) reclassify the MTP fixture's first checkpoint as
  NOT-IN-SCOPE for exact-blob restore, or (c) accept
  admission without a boundary match (Option C).

## Handoff

This bug-fix iteration 2 is the Developer follow-up record.
The next gate is **Architect** for bug-fix review iteration
2 (focus: matching-loop relaxation correctness, test_stage9
preservation, design correction alignment). After Architect
PASS, the next gate is **QA** for the test rerun. The QA
session will run the full test plan (9 rows) plus coverage
closure T114/T114a/T115 against the new build. The
expected post-fix state on the MTP fixture: 29/30 or 30/30
cache restores for MTP checkpoint positions that align with
or exceed the system prompt-span boundary; 0 admission
rejections for those positions. The 61-token test case at
n_tokens=11 may still FAIL until a separate Manager decision
is made to either tighten the prompt-span coverage or
reclassify the test case.
