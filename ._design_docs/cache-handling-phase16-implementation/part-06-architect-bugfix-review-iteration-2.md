VERDICT: REWORK

# Stage 16 implementation part 6: architect bug-fix review iteration 2 (F-16-TR-06 MTP matching loop relaxation)

Status: REWORK
Date: 2026-06-16
Stage: 16 (chat-path prompt-span boundary, F-16-TR-06 bug fix iteration 2)
Reviewer: Architect (fresh session)
Branch: work-branch
Scope: bug-fix review of F-16-TR-06 only. No re-review of iteration 1, original Option A, Stage 15, B05/B06, or any other closed stage. Per-stage part file. No source code, design, implementation, architecture, or test report files modified.

## Inputs reviewed

| # | Source | Purpose |
| --- | --- | --- |
| 1 | test-report-20260616-02.md | Test report (FAIL iteration 2) |
| 2 | test-report-20260616-02-fixes.md | F-16-TR-06 detail |
| 3 | test-report-20260616-01.md | First test FAIL |
| 4 | part-05-bugfix-iteration-2-mtp-matching.md | Bug fix iteration 2 (PRIMARY) |
| 5 | part-03-bugfix-mtp-internal-checkpoint.md | Bug fix iteration 1 |
| 6 | part-04-architect-bugfix-review-gate-01.md | Bug fix iteration 1 review |
| 7 | part-09-post-closure-chat-path-prompt-boundary.md | Design correction (F-16-TR-06 section appended) |
| 8 | part-09-chat-path-prompt-boundary-invariant.md | Architecture invariant |
| 9 | git diff HEAD tools/server/server-cache-hybrid.cpp | Current uncommitted code change |
| 10 | server-cache-hybrid.cpp lines 2960-3140 | Matching loop and strict validator |
| 11 | test-cache-controller.cpp lines 1819-1862 and grep | test_stage9 verification |

## Verification checklist

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Matching loop relaxation correct: prompt boundaries pick largest with token_end not greater than descriptor.token_span_end; non-prompt preserved | PASS correctness, FAIL compile | Lines 3102-3119 declare best_boundary and iterate boundaries. For metadata prompt, the loop accepts token_end not greater than descriptor.token_span_end. For non-prompt, the loop requires token_end equal to descriptor.token_span_end. The loop keeps the boundary with the largest token_end. Logic is correct. However see item 2 and finding F-16-BF-08: the assignment at line 3129 references attached_boundary which is undeclared. |
| 2 | Strict validator re-checksums: validator re-runs same match, recomputes checksum over descriptor span, matches descriptor boundary_checksum | PASS | Lines 2994-3024 declare best_match locally (no undeclared-variable issue in the validator). The recompute cache_token_span_checksum over descriptor span is the same expression used in the matching loop at lines 3125-3128. Both use cache_token_span_checksum defined at server-cache-hybrid.cpp:204-215 (FNV-1a 64-bit, init 1469598103934665603, mul 1099511628211, same cache_token_ids call). The two values match exactly. |
| 3 | test_stage9 preservation: existing test uses metadata msg-1, must still pass under strict-match branch | PASS | test-cache-controller.cpp:1826 adds a span with metadata msg-1. The strict-match branch requires token_end equal to descriptor.token_span_end and checksum equal to descriptor.boundary_checksum. Normal case (token_end=4, checksum matches) passes strict-match. bad_span case (token_end=3) skips the boundary, no best_match, returns fail, the negation assertion passes. bad_id case (metadata msg-2) is rejected by the type/metadata filter at line 2990, no best_match, returns fail, the descriptor-field assertion still passes. All test_stage9 assertions hold. |
| 4 | test_stage10-policy-lru pre-existing semantic bug, BLOCKED, not affected by this fix | N/A out of scope | Per test plan Pass/fail criteria, test_stage10-policy-lru is BLOCKED on a pre-existing semantic bug. The F-16-TR-06 change does not touch the LRU policy. Out of scope for this review. |
| 5 | No regression on non-MTP paths: V2 separate-draft fixture (29/29 restores on Stage 15) must still work | PASS | The V2 fixture boundaries use non-prompt metadata (test code at lines 247, 328, 2564, 2580 use test and c2-span; production V2 path uses fallback cache_metadata_for_request which emits boundaries with non-prompt metadata per the architecture part-09 entry-points classification). The strict-match branch for non-prompt boundaries is byte-for-byte identical to the pre-fix code path. No regression. |
| 6 | Design correction alignment: part-09 coherent with code change, under 300-line cap | PARTIAL | The F-16-TR-06 section (lines ~316-354) is coherent with the code change. It records the matching-loop relaxation, names the affected functions, and links the test report, fixes file, and part-05 implementation evidence. However, the file is at 354 lines (verified via Get-Content Count), exceeding the 300-line cap from document-index.md. The brief states now at 300 lines (cap) but the file is 354 lines. This violates the mandatory split rule. See finding F-16-BF-09. |
| 7 | Architecture invariant alignment: part-09 invariant reflects the matching-loop relaxation | PASS | Affected surfaces section explicitly documents: attach_checkpoint_payload and validate_checkpoint_descriptor_metadata were relaxed for F-16-TR-06; for prompt boundaries, the matching loop picks the largest with token_end not greater than descriptor.token_span_end and the descriptor boundary_checksum is recomputed over the actual checkpoint span; for non-prompt boundaries the strict match is preserved. Architecture invariant is accurate. |
| 8 | Caveat for n_tokens=11 test case: Developer analysis is correct (system prompt-span at ~12, requires token_end not greater than 11, 12 greater than 11, no match, admission rejected) | PASS | The chat path emits 12 boundaries (test report 2026-06-16 02 confirms). All have metadata prompt. The system prompt-span boundary has token_end ~12. The MTP internal checkpoint at n_tokens=11 requires token_end not greater than 11. Since 12 greater than 11, the system prompt-span boundary is skipped. No other prompt boundary has token_end not greater than 11 (user prompt-span ~62, assistant ~62, end-of-prompt 61). No best_boundary is found, admission is correctly rejected. The test case at n_tokens=11 will FAIL under the current fix. |

Counts: 6 PASS, 0 FAIL (correctness), 1 PARTIAL (cap), 1 N/A (out of scope).

## Findings

| ID | Severity | Title | Evidence | Action |
| --- | --- | --- | --- | --- |
| F-16-BF-08 | BLOCKING compile | Undeclared variable attached_boundary at server-cache-hybrid.cpp:3129 | git diff HEAD removes the original bool attached_boundary=false declaration at the start of the matching-loop block and replaces it with const prompt_boundary* best_boundary=nullptr. The new code at line 3129 attached_boundary=true is the only use of attached_boundary in the entire file (verified by Select-String returning one match). The variable is not declared as a class member, function parameter, or local. The function attach_checkpoint_payload starts at line 3039 and has no attached_boundary declaration. The new code will not compile. The Developer claimed Status: applied in part-05 but did not rebuild. The build at the top of this conversation was for the F-16-TR-02 fix, not the F-16-TR-06 change (the change is uncommitted per git status). | Developer must either remove the attached_boundary=true line (the variable serves no purpose in the new code: the matching result is captured by best_boundary and the if-else branches handle success/failure) or reintroduce the bool attached_boundary=false declaration if the variable is needed downstream. The simplest fix is to delete line 3129. |
| F-16-BF-09 | non-blocking | part-09-post-closure-chat-path-prompt-boundary.md is 354 lines, exceeds 300-line cap | Get-Content Count returns 354. The mandatory split rule in document-index.md states: IF document exceeds 300 lines THEN split it into smaller logically consistent part files. The F-16-TR-06 section was appended on top of the F-16-TR-02 expansion, pushing the file from 300 to 354 lines. | Developer or Architect follow-up to split part-09 into a continuation part (e.g. part-10-f-16-tr-06-matching-loop-relaxation.md) and update the design entry doc table of contents. Not blocking for the F-16-TR-06 gate; the design correction is coherent regardless of file length. |
| F-16-BF-10 | non-blocking | Part-05 brief R-16-BF-06-04 wording imprecision on checksum re-computation | Brief says the descriptor boundary_checksum is recomputed over the descriptor span, which may not match the boundary original checksum. The strict validator comparison uses the descriptor span, not the boundary span. The wording may not match reads as a concern but is intentional. | None. Wording is accurate; the may not match clause documents the intentional design. |
| F-16-BF-11 | non-blocking | test_stage9 bad_id case relies on the type/metadata filter, not the strict-match branch | Test at test-cache-controller.cpp:1848-1853 uses metadata msg-2. The strict validator first filter at line 2990 rejects all msg-1 boundaries because the descriptor boundary_id is msg-2. No best_match is found, returns fail. The assertion checks the descriptor stored fields, which are set by the matching loop to msg-2 and the correct checksum. The test passes. | None. The fix does not affect this test path. |
| F-16-BF-12 | non-blocking | Comment block at server-cache-hybrid.cpp:3087-3101 is 15 lines | The comment explains the matching-loop relaxation: MTP internal checkpoint position, strict-match rejection, prompt vs non-prompt split, checksum recomputation rationale, and test_stage9 preservation. AGENTS.md says comments should be sparse. The comment is verbose but documents a non-obvious invariant. | None. Comment is justified for a non-obvious invariant. |
| F-16-BF-13 | non-blocking | Brief R-16-BF-06-05 boundary at token_end=0 edge case not present in current fix | Brief hypothesizes that a boundary at token_end=0 could be picked. The chat path per-message prompt-span boundaries are added at token_end greater than 0. No chat path boundary has token_end=0. The risk is theoretical for the chat path; test fixtures that hand-craft a token_end=0 prompt boundary would have it picked, but no current test does so. | None. Risk is theoretical and not present in production paths. |
| F-16-BF-14 | non-blocking | Architecture part-09 does not document the n_tokens=11 test case limitation explicitly | The Limitations and known gaps section covers non-message-end MTP checkpoint positions but does not explicitly mention the n_tokens=11 case (system prompt-span at ~12, MTP checkpoint at 11). | Architect follow-up: add a one-line note to the Limitations and known gaps section of architecture part-09 documenting that for short prompts where the MTP internal checkpoint fires below the system prompt-span boundary, the relaxation still rejects admission. Not blocking for the F-16-TR-06 gate. |

Counts: BLOCKING 1, non-blocking 6, INFO 0.

## Code review

Concise comment on the new code blocks at server-cache-hybrid.cpp:3086-3132 and 2994-3024.

**Matching loop** (lines 3086-3132):

- best_boundary is declared locally, no scope leak. The for loop iterates source_metadata boundaries and picks the boundary with the largest token_end that satisfies the prompt vs non-prompt split. Correctness is sound.
- The if (best_boundary) else structure replaces the original attached_boundary flag pattern. The new structure is cleaner: the success branch populates the descriptor, the failure branch sets only checkpoint_boundary_required=true (which the strict validator then rejects via the pre-loop check at line 2984).
- Bug: line 3129 attached_boundary=true is dead code from the original implementation. The variable serves no purpose in the new structure (the if best_boundary branch is the success indicator). The Developer forgot to delete this line when restructuring. The original bool attached_boundary=false declaration was removed, so the assignment is now to an undeclared variable. Delete line 3129 to fix.
- Comment at lines 3087-3101 is 15 lines. AGENTS.md says comments should be sparse, but this comment explains a non-obvious invariant (the prompt vs non-prompt split, the MTP checkpoint position rationale, the checksum recomputation, the test_stage9 preservation). Acceptable per AGENTS.md explains a non-obvious invariant guidance.
- descriptor.boundary_checksum is recomputed over the descriptor span (line 3125-3128), not copied from the boundary checksum. This is intentional: the descriptor checksum represents the actual checkpoint span, which the strict validator re-verifies. Consistent with the strict validator recompute at line 3014-3017.

**Strict validator** (lines 2994-3024):

- best_match is declared locally. No scope leak. The for loop mirrors the matching loop logic. Correctness is sound.
- The if (best_match) return fail structure replaces the original early-return pattern. Cleaner.
- Checksum recompute at line 3014-3017 uses the same expression as the matching loop at line 3125-3128. Both compute cache_token_span_checksum over the descriptor span. The two values are guaranteed to match (the matching loop sets descriptor.boundary_checksum to the same expression). Consistent.
- No undeclared variables, no dead code, no AGENTS.md violations.

**AGENTS.md adherence**: code is self-explanatory, comments explain non-obvious invariants (prompt vs non-prompt split, MTP checkpoint rationale), no addresses to the user, no restating of the code, no promotional language, no em-dash overuse, no rule-of-three, no AI-vocabulary words. The single bug is a missed cleanup of dead code from the original implementation.

## Caveat analysis

The Developer caveat for the 61-token MTP test case at n_tokens=11 is correct.

**Chat path boundary emission** (per test report 2026-06-16 02 run evidence): 12 boundaries = 5 system + 3 user + 3 assistant + 1 end-of-prompt. All have metadata prompt. The system prompt-span boundary has token_end ~12 (the system message tokenizes to ~12 tokens including role header and footer).

**MTP internal checkpoint** (per model log): n_tokens=11, pos_min=10, pos_max=10. This is a speculative step boundary at position 10, not end-of-prefill.

**Relaxed match analysis** for descriptor.token_span_end=11:

- System prompt-span at token_end=12: 12 greater than 11, skipped.
- User prompt-span at token_end=62: 62 greater than 11, skipped.
- Assistant prompt-spans at token_end greater than 11: skipped.
- End-of-prompt at token_end=61: skipped.

No prompt boundary satisfies token_end not greater than 11. No best_boundary is found. The else branch sets only checkpoint_boundary_required=true. The strict validator pre-loop check at line 2984 rejects: descriptor.boundary_id empty, descriptor.boundary_checksum zero, descriptor.checkpoint_boundary_kind less than 0 (all three are at default). Returns fail with message missing checkpoint boundary metadata. Admission is correctly rejected.

**Verdict**: the 61-token MTP test case at n_tokens=11 will FAIL under the current fix. The fix is correct (no boundary at this position means reject), but the test case requires either tighter prompt-span coverage or test reclassification.

**Why the fix is still correct for the broader case**: the matching-loop relaxation covers MTP checkpoints at or beyond the system prompt-span boundary. For the 61-token prompt, MTP positions 12, 62 (end of user), and 61 (end of prefill) are all covered. For longer prompts, the per-message prompt-span boundaries cover message-end positions. The n_tokens=11 case is a specific edge case where the MTP fires below the system message end.

## Manager decision required

The 61-token MTP test case at n_tokens=11 will FAIL under the current fix. The fix is architecturally correct (the matching-loop relaxation covers MTP checkpoints at or beyond message-end positions), but the specific n_tokens=11 test case is a degenerate edge case where the MTP internal checkpoint fires below the system prompt-span boundary.

Three options for the Manager:

(a) Tighten prompt-span coverage: emit an additional system prompt-span boundary at a smaller span (e.g. right after the system role header, before the system content). This would add one extra boundary per chat-completion request. The new boundary at [0, ~2, prompt] would satisfy token_end not greater than 11 and the matching loop would pick it. Cost: one additional boundary per request, minimal metadata overhead. The change is local to cache_metadata_from_chat_messages and would be a follow-up bug-fix iteration 3.

(b) Reclassify the test case: reclassify the 61-token MTP test case n_tokens=11 checkpoint as expected-Fail or NOT-IN-SCOPE, per Stage 15 Manager decision 1 precedent (B02/B05/B06 NOT-IN-SCOPE for the MTP fixture). The test case is a known limitation: the MTP internal checkpoint fires below the system message end, which is a model-internal state not predictable from chat structure. The test plan should be updated to reflect that the n_tokens=11 checkpoint is a known gap, and post-fix state should be evaluated for MTP positions 12, 62, and 61 only.

(c) Accept current state and close: the fix is architecturally correct, the matching-loop relaxation covers the common case (MTP at or beyond message-end positions), the n_tokens=11 case is a documented limitation in the architecture part-09 Limitations and known gaps section (after the F-16-BF-14 follow-up note is added). The QA rerun records the n_tokens=11 FAIL as a known limitation, and the stage closes with the fix accepted for the common case.

Recommendation: option (b) reclassify. The fix is architecturally correct; the n_tokens=11 test case is a specific edge case that requires either invasive code changes (option a) or accepting the limitation (option c). Reclassification is the most pragmatic and consistent with the Stage 15 Manager decision 1 precedent. The test case should be reclassified to expected FAIL for n_tokens=11 checkpoint; PASS for MTP positions 12, 62, 61. The QA rerun evaluates post-fix state for the reclassified rows.

## Verdict

REWORK. The matching-loop relaxation is correct (item 1 logic, item 2 validator, item 3 test_stage9, item 5 V2 regression, item 7 architecture invariant, item 8 n_tokens=11 caveat all PASS). The design correction is coherent (item 6 PARTIAL due to cap violation). However, finding F-16-BF-08 is BLOCKING: server-cache-hybrid.cpp:3129 assigns to attached_boundary which is not declared in scope. The code will not compile. The Developer must delete the dead-code line at line 3129 (or reintroduce the bool attached_boundary=false declaration if the variable is needed downstream) before the fix can be tested.

The 6 non-blocking findings (F-16-BF-09 through F-16-BF-14) are documentation-level and do not block the gate after the compile fix.

## Handoff

Next owner: Developer in a new fresh session. The Developer must:

1. Fix F-16-BF-08: delete line 3129 (attached_boundary=true) in server-cache-hybrid.cpp. The variable is dead code from the original implementation; the new if (best_boundary) else structure is the success indicator. After deletion, the matching-loop block is self-contained.
2. Rebuild llama-server and test-cache-controller against the fix. Verify test-cache-controller still passes 75/75 (test_stage9 assertions preserved).
3. Optionally address F-16-BF-09 (split part-09 into part-09 + part-10 to satisfy the 300-line cap) and F-16-BF-14 (add n_tokens=11 limitation note to architecture part-09). These are non-blocking and can be deferred.

After Developer REWORK fix, the next gate is Architect in a new fresh session for bug-fix re-review (focus: F-16-BF-08 fix verified, code compiles, test_stage9 still passes, matching-loop relaxation unchanged). After Architect PASS, the next gate is QA in a new fresh session for test rerun.

The Manager decision (option a, b, or c) is required before QA rerun. The Developer handoff to the Manager should include the F-16-BF-08 fix and the n_tokens=11 caveat analysis. The Manager decides on test reclassification or further code changes.
