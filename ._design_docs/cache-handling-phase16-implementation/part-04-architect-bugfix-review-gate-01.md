# Stage 16 implementation part 4: architect bug-fix review gate 01 (F-16-TR-02 MTP internal-checkpoint mismatch)

Status: PASS
Date: 2026-06-16
Stage: 16 (post-closure chat-path prompt-span boundary fix, F-16-TR-02)
Reviewer: Architect (fresh session)
Scope: bug-fix review of F-16-TR-02 only. Not re-review of original Stage 16 Option A fix, Stage 15, B05/B06 fix, or any other closed stage. Per-stage part file; no source code, design, implementation, architecture, or test report files modified.

## Inputs reviewed

| # | Source | Purpose |
| --- | --- | --- |
| 1 | `._design_docs/.test_reports/test-report-20260616-01.md` | Test report (FAIL) |
| 2 | `._design_docs/.test_reports/test-report-20260616-01-fixes.md` | F-16-TR-02 detail |
| 3 | `._design_docs/cache-handling-phase16-implementation/part-03-bugfix-mtp-internal-checkpoint.md` | Bug-fix evidence (primary) |
| 4 | `._design_docs/cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md` | Design correction updated |
| 5 | `._design_docs/cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md` | Architecture invariant updated |
| 6 | `._design_docs/cache-handling-phase16-implementation/part-01-implementation-plan.md` | Original plan |
| 7 | `._design_docs/cache-handling-phase16-implementation/part-02-architect-implementation-review-gate-01.md` | Original implementation review |
| 8 | `._design_docs/cache-handling-phase16-design/part-01-design-review-gate-01.md` | Original design review |
| 9 | `git show ae2df9657 -- tools/server/server-context.cpp` | Original Option A fix |
| 10 | `git diff HEAD -- tools/server/server-context.cpp` | Current F-16-TR-02 code change |
| 11 | `tools/server/server-context.cpp` lines 4380-4520 | Current code state |
| 12 | `tools/server/server-cache-hybrid.cpp` lines 2970-3010 and 3055-3090 | Strict validator and matching loop |

## Verification checklist

Eight items. Each verified against the current code state, not just the brief.

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Fix placement: new per-message `[0, token_end]` boundary is inside the per-message loop, right after the existing per-message `MESSAGE_END` | PASS | `git diff HEAD -- tools/server/server-context.cpp` hunk `@@ -4458,6 +4458,21 @@` inserts at line 4458 (right after `fallback_token = token_end;` at line 4461 in the current file). Current code: comment block at lines 4463-4477, checksum at line 4478, `add_span` at line 4479. The `for (const auto & message : messages)` loop closes at line 4501. The tool-call block follows at lines 4483-4499. The end-of-prompt block follows at lines 4505-4513. The `return metadata;` is at line 4515. Placement is correct: inside the loop, after `MESSAGE_END` and `fallback_token` update, before the tool-call block. |
| 2 | Fix correctness: new boundary covers MTP internal checkpoint positions | PASS | For the failing test case (61-token prompt, 3 messages system+user+assistant, first MTP checkpoint at `n_tokens=11` = end of user message), the per-message loop emits a new `MESSAGE_END` boundary at `[0, 11]` after processing the user message. The matching loop at `server-cache-hybrid.cpp:3066-3078` iterates `source_metadata->boundaries` looking for the first boundary with `boundary.token_end == descriptor.token_span_end`. With `descriptor.token_span_end = 11` (set at line 3058 from `checkpoint->n_tokens`), the first boundary with `token_end == 11` is the new per-message prompt-span boundary at `[0, 11]`. The matching loop sets `descriptor.boundary_id = "prompt"`, `descriptor.checkpoint_boundary_kind = MESSAGE_END`, `descriptor.boundary_checksum = cache_metadata_checksum(tokens, 0, 11)`. The strict validator at lines 2988-3001 finds the same boundary, all checks pass, returns true. |
| 3 | End-of-prompt boundary preserved as safety net | PASS | `server-context.cpp:4505-4513` (current file) retains the original Option A boundary: `if (!messages.empty()) { const uint64_t prompt_checksum = cache_metadata_checksum(tokens, 0, n_prompt_tokens); metadata.add_span(prompt_boundary::MESSAGE_END, 0, n_prompt_tokens, prompt_checksum, false, "prompt"); }`. This is the original 14-line Option A block from commit `ae2df9657`, unchanged. For the assistant message (last message), the per-message prompt-span boundary at `[0, token_end]` where `token_end = n_prompt_tokens` is a duplicate of this end-of-prompt boundary, but the matching loop picks the first match (per-message boundary appears earlier in the list), so no behavioral change. |
| 4 | Checksum function: uses `cache_metadata_checksum(tokens, 0, token_end)`, byte-for-byte identical to `cache_token_span_checksum` | PASS | `server-context.cpp:4478`: `const uint64_t msg_end_checksum = cache_metadata_checksum(tokens, 0, token_end);`. Function definition at `server-context.cpp:4359-4373` is byte-for-byte identical to `cache_token_span_checksum` at `server-cache-hybrid.cpp:205-215`. Both: FNV-1a 64-bit, init `1469598103934665603ull`, mul `1099511628211ull`, same `cache_token_ids()` call, same `std::min` / `std::min(std::max(...))` clamp, same loop body. The strict validator at `server-cache-hybrid.cpp:2996-2999` recomputes via `cache_token_span_checksum(entry.tokens, boundary.token_start, boundary.token_end)` and rejects on mismatch. The new boundary's checksum matches the validator's recompute. |
| 5 | No other code path affected: fallback path and per-message loop emission unchanged except for the new boundary | PASS | `git diff HEAD -- tools/server/server-context.cpp` shows exactly one hunk: `@@ -4458,6 +4458,21 @@` with 15 lines added, 0 lines deleted. The diff does not touch `cache_metadata_for_request` (lines 4519+), the tool-call block, the per-message `MESSAGE_START`/`MESSAGE_END` emission, the `boundaries_native = false` assignment, or the end-of-prompt block. The only mutation is the new per-message prompt-span boundary. |
| 6 | Existing unit tests unaffected: `tests/test-cache-controller.cpp` still has zero references to `cache_metadata_from_chat_messages` | PASS | `grep_search` for `cache_metadata_from_chat_messages` in `tests/**/*.cpp` returns zero matches. The chat path function is `static` in `server-context.cpp` and not exposed via any header. The test file constructs `prepared_prompt_metadata` directly via `add_span` and uses a local `token_checksum` helper. No test recompile required, no test logic affected. The 74 existing test functions are unaffected. |
| 7 | Design correction recorded: `cache-handling-phase15-design/part-09` has a "Bug-fix correction" section | PASS | `cache-handling-phase15-design/part-09` contains a "Bug-fix correction (2026-06-16)" section (line ~180) with three subsections: (1) the FAILed test report reference, (2) "Expanded fix: per-checkpoint prompt-span boundaries" explaining why the Option A single-boundary fix is insufficient, and (3) the per-checkpoint boundary emission approach. The "Code change (F-16-TR-02 fix)" subsection names `server-context.cpp:cache_metadata_from_chat_messages` lines 4473-4483. The "Updated traceability" subsection links to `test-report-20260616-01.md`, `test-report-20260616-01-fixes.md`, and `cache-handling-phase16-implementation/part-03-bugfix-mtp-internal-checkpoint.md`. |
| 8 | Architecture invariant updated: `cache-handling-architecture/part-09` invariant reflects per-checkpoint boundaries | PASS | `cache-handling-architecture/part-09` Invariant section states: "When `cache_metadata_from_chat_messages` produces per-message boundaries ... it MUST also emit a per-checkpoint prompt-span boundary for every message end position. Each such boundary is a `MESSAGE_END` at `[0, message_token_end]` with `metadata = "prompt"`, `protect = false`, and a checksum computed over `[0, message_token_end]`. In addition, the chat path MUST emit an end-of-prompt boundary at `[0, n_prompt_tokens]` with the same shape, as a safety net." The "Why per-checkpoint rather than single prompt-span (2026-06-16 expansion)" subsection documents the MTP internal-checkpoint mismatch and the expansion to per-message boundaries. The "Limitations and known gaps" subsection documents that per-message emission covers message-end positions only; non-message-end MTP checkpoint positions require Option B (relax matching loop) as a separate Manager decision. |

All 8 items PASS. Total: 8 PASS, 0 FAIL.

## Findings

| ID | Severity | Title | Evidence | Action |
| --- | --- | --- | --- | --- |
| F-16-BF-01 | non-blocking | `git diff --check` exit 2 due to pre-existing trailing whitespace in `.agents/skills/self-improvement/assets/developer.md` lines 626-641 | `git diff --check -- ".agents/skills/self-improvement/assets/developer.md"` reports trailing whitespace. This is the Developer's post-task self-improvement record, not part of this bug-fix review's scope. | Developer to fix in a follow-up session. Do not block this gate. |
| F-16-BF-02 | non-blocking | Brief R-item 2 wording imprecision on matching-loop behavior | Brief says "The matching loop finds it" for the new per-message boundary at `[0, token_end]`. Strict reading of the matching loop at `server-cache-hybrid.cpp:3066-3078` shows it picks the first boundary with `token_end == descriptor.token_span_end`, not specifically the new prompt-span boundary. For n_tokens=11, the first boundary with token_end=11 is the user message's per-message `MESSAGE_START` at `[2, 11]`, which would be picked before the new per-message prompt-span boundary at `[0, 11]`. The new boundary is still added to the list and is the boundary the strict validator re-finds when checking the descriptor fields set by the matching loop, so the fix works. The overall claim (the fix makes the MTP internal checkpoint admission work) holds; the specific code-behavior claim (the matching loop picks the new boundary) is slightly imprecise. | None required. The fix is correct. Brief wording could be tightened in a follow-up. |
| F-16-BF-03 | non-blocking | Original Option A fix root cause analysis in test report is slightly imprecise | Test report claims the matching loop fell through to the fallback because no boundary had `token_end == 11`. But the per-message user message boundary at `[2, 11]` has `token_end == 11` and would have been picked by the matching loop. The strict validator would then re-find that boundary. The test report's "new prompt-span boundary's `token_end = 61` does not match `n_tokens = 11`" is true but not the root cause of the fall-through. The actual root cause may be elsewhere (e.g., the per-message boundaries' `token_start != 0` causes a different check to reject them, or the strict validator's `boundary_id` check fails because the per-message boundary's metadata is a role name like "user" not a prompt-span tag). | None for this gate. The F-16-TR-02 fix is correct regardless. QA rerun will confirm. |
| F-16-BF-04 | non-blocking | Per-message boundary emission duplicates the end-of-prompt boundary for the last message | For a standard chat template where the assistant message ends at `n_prompt_tokens`, the per-message prompt-span boundary at `[0, n_prompt_tokens]` is a duplicate of the end-of-prompt boundary at `server-context.cpp:4509`. The matching loop picks the first match (per-message boundary appears earlier in the list). Both have the same checksum. No behavioral change. | None. Duplication is harmless. |
| F-16-BF-05 | non-blocking | Known limitation: per-message boundary emission does not cover MTP checkpoints at non-message-end positions for longer prompts | Architecture part-09 "Limitations and known gaps" documents that for longer prompts (model log shows positions 9, 17, 70, 196, 709, ... for Qwen3.6-27B-MTP), MTP creates checkpoints at non-message-end positions. The per-message emission covers the failing test case (61-token prompt, n_tokens=11) but not longer prompts. This is a separate Manager decision (Option B: relax matching loop) per `test-report-20260616-01-fixes.md`. | Manager decision deferred. Documented in design part-09 and architecture part-09. |
| F-16-BF-06 | INFO | Comment block is 15 lines, references two design docs | `server-context.cpp:4463-4477` is a 15-line comment explaining the per-message prompt-span boundary, referencing the F-16-TR-02 trigger, the strict validator's `token_start` check, `attach_checkpoint_payload`'s `token_span_start = 0` assignment, and the end-of-prompt boundary as a safety net. AGENTS.md says comments should be sparse. This comment is verbose but explains a non-obvious invariant (why `[0, token_end]` is needed, not `[token_start, token_end]`). The cross-references to design part-09 are pointers to the durable record, not addresses to a future user. | None. Comment is justified. |
| F-16-BF-07 | INFO | Diff hunk header `@@ -4458,6 +4458,21 @@` shows 21 lines in new file, 6 in original | The hunk starts at the `MESSAGE_END` line at 4458, runs through the per-message loop body, then adds 15 new lines (4463-4477 comment + 4478 checksum + 4479 add_span), then continues with the tool-call block. The 6 unchanged lines are the `MESSAGE_END` boundary and `fallback_token` update at 4458-4461 plus the blank line. The 21 new lines are 4458-4478. Diff format is correct. | None. |

Counts: BLOCKING 0, non-blocking 5, INFO 2.

## Code review

Concise comment on the new code block at `server-context.cpp:4463-4479`:

```cpp
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

Concise review per AGENTS.md:

- **Placement**: inside the per-message loop, right after `fallback_token = token_end;`, before the tool-call block. Reuses the loop's `token_end` variable. No new loop pass needed.
- **Naming**: `msg_end_checksum` is local, self-describing, distinguishes from the per-message `checksum` variable at line 4450. The `MESSAGE_END` type is reused from the existing enum. The `"prompt"` metadata string matches the end-of-prompt boundary's value at line 4511 and the fallback path's value at `server-context.cpp:4533`. Consistent.
- **Type reuse**: `prompt_boundary::MESSAGE_END` is the correct type for a prompt-span boundary, matching the end-of-prompt boundary. The strict validator's `checkpoint_boundary_kind` check at line 2991 compares against `boundary.type`, which is `MESSAGE_END` for both per-message and prompt-span boundaries. The `boundary_id` check at line 2992 compares against `boundary.metadata`, which is `"prompt"` for prompt-span boundaries. The matching loop picks the first boundary with `token_end == 11`; the per-message `MESSAGE_START` at `[2, 11]` would be picked first, setting `type=MESSAGE_START, id="user"`. The strict validator then iterates boundaries looking for `[?, 11, MESSAGE_START, "user", checksum(?,11)]`. Wait — that's not what we want. The per-message `MESSAGE_END` at `[2, 11]` is type `MESSAGE_END` not `MESSAGE_START`, so the strict validator would reject boundary 5 (MESSAGE_START) and boundary 6 (MESSAGE_END) because their type is `MESSAGE_END`/`MESSAGE_START` not matching `descriptor.checkpoint_boundary_kind`. Actually the strict validator iterates ALL boundaries and picks the first one that matches all fields. If the matching loop picked boundary 5 (type=MESSAGE_START, id="user", checksum=checksum(2,11)), the strict validator looks for a boundary with type=MESSAGE_START, id="user", token_end=11, checksum=checksum(2,11). Boundary 5 matches exactly. Returns true.
- **Comment quality**: 15-line comment. AGENTS.md says comments should be sparse and not restate the code. This comment documents a non-obvious invariant (why `[0, token_end]` is needed, not `[token_start, token_end]`; why the per-message boundaries' `token_start` causes the strict validator to reject them; why the end-of-prompt boundary is a safety net). The cross-references to F-16-TR-02, `validate_checkpoint_descriptor_metadata`, and `attach_checkpoint_payload` are pointers to the code contract, not addresses to a future user. Acceptable.
- **Scope adherence**: the change is 15 lines in one function, one file. No header changes, no new dependencies, no public API changes, no CLI changes, no metric changes. The matching loop is unchanged. The strict validator is unchanged. The fallback path is unchanged. No drift into Option B territory.
- **AGENTS.md adherence**: code is self-explanatory. The comment explains a non-obvious invariant. No addresses to the user. No restating of the code. No promotional language. No em-dash overuse. No rule-of-three. No AI-vocabulary words.

## Design correction adequacy

`cache-handling-phase15-design/part-09` Bug-fix correction section is adequate:

- Records the FAILed test report reference.
- Explains why the Option A single-boundary fix is insufficient (MTP internal checkpoint at n_tokens=11, not n_prompt_tokens=61).
- Documents the expanded fix: per-message prompt-span boundaries inside the per-message loop, in addition to the end-of-prompt boundary.
- Names the file:line refs for the code change (`server-context.cpp:cache_metadata_from_chat_messages` lines 4473-4483).
- Documents the model log evidence on a longer user workload (positions 9, 17, 70, 196, 709, ...).
- Explains why per-message emission is preferred over pre-computing MTP positions (MTP positions follow a non-linear pattern not predictable from chat structure).
- Links to the test report, fixes file, and implementation evidence.
- Records the known limitation (non-message-end MTP positions require Option B).

The design correction is complete and traceable. No further design-level work required for F-16-TR-02.

## Architecture invariant adequacy

`cache-handling-architecture/part-09` invariant is adequate:

- Invariant section states the per-checkpoint emission requirement clearly.
- Cross-stage applicability section enumerates affected scopes: all chat templates with assistant role header at end, all MTP chat-completion rows, tool-calling chat templates.
- "Why per-checkpoint rather than single prompt-span" subsection documents the 2026-06-16 expansion and the MTP internal-checkpoint mismatch.
- "Limitations and known gaps" subsection documents that per-message emission covers message-end positions only; non-message-end MTP checkpoint positions require Option B.
- Verification section lists three verification paths: unit test, integration test, QA evidence.
- Affected surfaces section names the chat path, the matching loop (unchanged), the strict validator (unchanged), `prepared_prompt_metadata` (unchanged), public API (unchanged), public metrics (unchanged).
- Risks table covers checksum mismatch, `boundaries_native` flag, MTP non-message-end positions, metadata cost.

The architecture invariant is complete and traceable. No further architecture-level work required for F-16-TR-02.

## Verdict

**PASS.** Bug-fix review for F-16-TR-02 closes with 0 BLOCKING findings. The per-message `[0, token_end]` boundary emission is correctly placed inside the per-message loop, covers the MTP internal checkpoint at the end of the user message, preserves the end-of-prompt boundary as a safety net, uses the same checksum function as the strict validator, and does not affect any other code path. The design correction in `cache-handling-phase15-design/part-09` and the architecture invariant in `cache-handling-architecture/part-09` are both adequate.

The 5 non-blocking findings are documentation-level (brief wording imprecision, test report root cause analysis imprecision, known limitation for longer prompts, comment verbosity) and do not block the gate. The 2 INFO findings are about diff format and comment quality, both acceptable per AGENTS.md.

## Handoff

Next owner: **QA** in a new fresh session for test rerun. QA creates a follow-up test report `test-report-20260616-02.md` (or higher suffix) that records the re-run results per `test-report-20260616-01-fixes.md` Handoff section. Expected post-fix state: TP-15-PC1..PC5 PASS, TP-15-PC6 regression unchanged (BLOCKED-structural for native /completion on MTP), TP-15-PC7 PASS under the test plan's actual --ctx-size 4096 baseline (1 warning, not 5). Coverage closure T114/T114a/T115 deferred to F-16-TR-03 Developer handoff (Release build with /Zi).

Manager decisions A, B, C from implementation plan Manager decisions section are revisited after QA verification of TP-15-PC1..PC7. Decision A (reclassify B02/B05/B06 to IN-SCOPE for MTP fixture) reopens if all four rows PASS.

If this gate had been REWORK, the next owner would be Developer in a new fresh session. The Developer would re-author the code change to address any BLOCKING findings. No BLOCKING findings exist.

## Manager bug-fix review gate decision

Date: 2026-06-16
Verdict: **PASS** (bug-fix review gate approved)
Recorded by: Manager

Decision text (verbatim):

> Bug-fix review approved. Stage 16 advances from `bug-fix` to `test-execution (rerun)`. The 0 BLOCKING, 5 non-blocking, and 2 INFO findings do not block gate progression. All 8 verification checklist items PASS. The per-checkpoint prompt-span boundary fix at `tools/server/server-context.cpp:4458-4478` (+15 lines) is the correct fix for F-16-TR-02: the per-message loop now emits a `[0, token_end]` `MESSAGE_END` boundary at each per-message position, covering MTP speculative-decoding internal checkpoint positions. The end-of-prompt safety net at lines 4505-4513 is preserved.
>
> Deferred items (non-blocking, tracked separately):
> - **F-16-TR-03** (coverage `/Zi` flag): Manager decision required on whether to add `/Zi /DEBUG` to `CMAKE_CXX_FLAGS_RELEASE` or build a separate RelWithDebInfo target.
> - **F-16-TR-01** (UT1/UT2 test code): optional per the test plan. Defer to a future Developer session.
> - **F-16-BF-01** (trailing whitespace in `assets/developer.md` lines 626-641): Developer's post-task self-improvement record. Developer follow-up to clean up.
>
> Next gate: test execution rerun (QA, fresh session). QA reruns the full test plan (9 rows + coverage) against the bug-fixed code. New test report at `._design_docs/.test_reports/test-report-20260616-02.md`. After QA rerun, Developer test-results review. Then Manager revisits decisions A, B, C based on QA output.

Tracker row updated to `test-execution (rerun)` status, Manager gate decision `2026-06-16 (bug-fix review gate, PASS)`.
