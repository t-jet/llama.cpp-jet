# Stage 16 design part 1: design review gate 01 (chat-path prompt-span boundary fix)

Status: PASS
Date: 2026-06-16
Stage: 16 (post-closure chat-path prompt-span boundary fix)
Reviewer: Architect (fresh session)
Scope: Stage 16 design correction only (Option A surgical). Not full Stage 15 re-review.

## Review scope

Reviewed 10 inputs. Correction-only. No re-review of closed Stage 15 design, B05/B06 fix, or any other closed stage.

| # | File | Purpose |
| --- | --- | --- |
| 1 | `._design_docs/cache-handling-stage-tracker.md` | Stage 16 row, status `design-only`, design/impl links |
| 2 | `._design_docs/cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md` | Primary review target: design correction (Option A) |
| 3 | `._design_docs/cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md` | Architecture-level invariant |
| 4 | `._design_docs/cache-handling-phase15-implementation/part-08-stage15-post-closure-chat-path-impl.md` | Implementation evidence (14-line insertion) |
| 5 | `._design_docs/cache-handling-phase15-implementation/part-09-stage15-post-closure-followup-summary.md` | Follow-up summary |
| 6 | `._design_docs/cache-handling-phase15-implementation/part-07-b05-b06-fix-review.md` | Predecessor fix review (third-diff extension = INFO 1) |
| 7 | `._design_docs/.test_reports/stage15-benchmark-20260613-02.md` | B05/B06 structural probe; refutes length-mismatch |
| 8 | `._design_docs/upstream-merge-guide/part-04-edge-cases.md` lines 55-70 | Post-closure follow-up rule (new design review + Manager gate) |
| 9 | `git show ae2df9657 -- tools/server/server-context.cpp` | Exact code change diff |
| 10 | `tools/server/server-context.cpp` lines 4383-4504 (`cache_metadata_from_chat_messages`) | Verify insertion point, conditional, checksum fn |

Scope rule: review only the correction. Re-reading closed Stage 15 docs is out of scope. This gate produces a verdict for the new design + new architecture invariant + new code change. Not a stage-15 retroactive review.

## Verdict

**PASS.** Design correction reviewable, complete, traceable, low-risk. Ready for Manager design gate.

Why PASS:

- Root cause: chat path emits per-message boundaries only; assistant role header at end of rendered prompt has no boundary. First end-of-prefill checkpoint `n_tokens` = full prompt size. No per-message boundary covers it. Strict validator at `server-cache-hybrid.cpp:2984` returns `fail("missing checkpoint boundary metadata")`. Confirmed by 10/10 admission_skipped warnings in model log on build 9669 (post Stage-15-fix).
- Fix: one `MESSAGE_END` boundary at `[0, n_prompt_tokens]` in `cache_metadata_from_chat_messages`. 14-line insertion. No match-loop change, no validator change, no public API/CLI/metric change.
- Invariant: mirrored fallback path shape in `cache_metadata_for_request`. Unconditional when `!messages.empty()`. Cross-stage: applies to any chat template with assistant role header at end of rendered prompt.
- Checksum fn: `cache_metadata_checksum(tokens, 0, n_prompt_tokens)`. Byte-for-byte identical to strict validator's `cache_token_span_checksum` (FNV-1a 64-bit, same init/mul constants, same loop, same clamp). New boundary checksum will match validator's recompute.
- Conditional `!messages.empty()`: correct. Function returns early at line 4392 only when `messages` is not an array. Empty array case falls through to new code; new conditional skips boundary addition, matching per-message loop's no-op behavior.

## Findings

| ID | Severity | Title | Evidence | Recommended action |
| --- | --- | --- | --- | --- |
| F-16-01 | non-blocking | Design/implementation wording imprecision on checksum fn | design part-09 (Root cause, Proposed fix sections): "The new boundary uses `cache_metadata_checksum`... the same function the strict validator uses." Strict validator at `server-cache-hybrid.cpp:2997` uses `cache_token_span_checksum`, not `cache_metadata_checksum`. Two functions are byte-for-byte identical FNV-1a 64-bit (init 1469598103934665603, mul 1099511628211); see `server-context.cpp:4359-4373` vs `server-cache-hybrid.cpp:204-217`. Behavior correct. | Optional: tighten wording in design part-09 and implementation part-08 to name both functions. No code change. |
| F-16-02 | non-blocking | Missing structural unit-test row in proposed test plan | design part-09 "Test plan rows proposed" lists TP-15-PC1..TP-15-PC7 (operational). Architecture part-09 "Verification" section 1 calls for unit test in `tests/test-cache-controller.cpp` (calls `cache_metadata_from_chat_messages` with 3-message input, asserts `MESSAGE_END` boundary at `[0, tokens.size()]` with `metadata == "prompt"`). | Add TP-15-UT1 row to test plan in test-plan follow-up. Deterministic, no model required. |
| I-16-01 | INFO | `boundaries_native` flag inheritance | `server-context.cpp:4388` sets `metadata.boundaries_native = false`. New code does not change it. Inherited `false` setting matches per-message boundaries' flag. Strict validator's `boundaries_native` check satisfied. Implementation part-08 mentions this; design part-09 could be more explicit. | None. Behavior correct. |
| I-16-02 | INFO | Span overlap with system message boundary | New boundary at `[0, n_prompt_tokens]`. System message boundary at `[0, N_system]` where `N_system < n_prompt_tokens`. Strict validator iterates all boundaries, matches on `token_end == descriptor.token_span_end`. New boundary is the only one with `token_end == n_prompt_tokens`. No false-positive match risk. | None. |
| I-16-03 | INFO | MTP draft tokens vs chat prompt | Risk: MTP draft tokens added by model loader, not by chat path. `n_prompt_tokens` reflects main model prompt only. If MTP draft extends past chat prompt, checkpoint `n_tokens` could exceed `n_prompt_tokens` and new boundary's `token_end` undershoots. Implementation part-08 lists this as risk; QA verification on MTP fixture is the final answer. | None at design level. QA verifies on MTP fixture per TP-15-PC1..PC7. |

Counts: BLOCKING 0, non-blocking 2, INFO 3.

## Traceability

| Claim | Source |
| --- | --- |
| Chat path emits per-message boundaries only | design part-09 (Root cause section); `server-context.cpp:4450` (`MESSAGE_START` + `MESSAGE_END` per message), `server-context.cpp:4472` (`MESSAGE_END` per message), `server-context.cpp:4476-4480` (tool-call boundaries) |
| Assistant role has no emitted boundary | design part-09 (Root cause): "no boundary covers the assistant role header at the end of the rendered prompt" |
| First end-of-prefill checkpoint `n_tokens` = full prompt size | design part-09 (Root cause); implementation part-08 (Background section) |
| Strict validator fails with "missing checkpoint boundary metadata" | design part-09 (Root cause): `server-cache-hybrid.cpp:2984` `return fail("missing checkpoint boundary metadata")`; verified at `server-cache-hybrid.cpp:2980-2984` |
| Model log evidence (10/10 admission_skipped, 31,498 graph hits) | design part-09 (Background); implementation part-08 (Evidence section); `d:\source\llama.cpp-jet\._analysis\model_log.txt` |
| Predecessor Stage 15 fix did not address chat path | design part-09 (Background); part-07 (B05/B06 fix review, INFO 1: "the multi-turn case is the MTP /v1/chat/completions path, which is a separate structural issue") |
| Stage 15 BLOCKED-structural-not-infra | test report `stage15-benchmark-20260613-02.md` (refutes 2026-06-13-01 length-mismatch hypothesis with b56 36=36 and rerun30 29=29) |
| Code change is in one function, one file, 14 lines | implementation part-08 (Diff summary); `git show ae2df9657` hunk header `@@ -4483,6 +4483,20 @@` (insertion at line 4483, 20 lines added including blank context) |
| New boundary at `[0, n_prompt_tokens]` with `MESSAGE_END` | implementation part-08 (Code change section, code block); `server-context.cpp:4497` |
| Conditional `!messages.empty()` correct | implementation part-08 (Risks observed during implementation, "Resolved by conditional"); verified: function returns early at `server-context.cpp:4392` only on `!messages.is_array()`; empty array falls through; conditional correctly skips |
| Checksum function equivalence | `server-context.cpp:4359-4373` (`cache_metadata_checksum`) vs `server-cache-hybrid.cpp:204-217` (`cache_token_span_checksum`); byte-for-byte identical FNV-1a 64-bit |
| Strict validator recomputes via `cache_token_span_checksum` | `server-cache-hybrid.cpp:2997`: `if (cache_token_span_checksum(entry.tokens, boundary.token_start, boundary.token_end) != boundary.checksum) return fail("checkpoint boundary checksum mismatch");` |
| Fallback path emits same shape | design part-09 (Why Option A over Option B): "same shape as the fallback path in `cache_metadata_for_request`"; `server-context.cpp:4515-4522` (fallback path adds `MESSAGE_START` + `MESSAGE_END` at `[0, tokens.size()]` with `metadata = "prompt"`) |
| Architecture-level invariant | architecture part-09 (Invariant section, Why this is an architecture-level invariant): three entry points, chat path MUST emit prompt-span boundary |
| Cross-stage applicability | architecture part-09 (Cross-stage applicability): all chat templates with assistant role header at end; all MTP chat-completion rows; tool-calling chat templates |
| Stage 15 design gate not reopened | upstream-merge-guide part-04 section 5 (line 60): "The cycle's design gate does not reopen. The post-closure follow-up opens a new design review gate and a new Manager design gate, both scoped to the follow-up correction only." |
| Follow-up pattern matches upstream-merge-guide | upstream-merge-guide part-04 section 5 (lines 58-70): new part in closed stage's design tree, Architect reviews, Manager records follow-up design-gate decision in follow-up part file |
| Manager owns tracker row update | design part-09 (Handoff section); improvement memory `Closure sweep keeps durable docs aligned without re-running the report` (cited in implementation part-08 Handoff) |
| Test plan rows proposed | design part-09 (Test plan rows proposed section): TP-15-PC1..TP-15-PC7; marked as proposals for test plan follow-up |

## Manager decision 1 impact

Manager closure decision 1 (2026-06-13) reclassified B02/B05/B06 to `NOT-IN-SCOPE` for the MTP fixture. Reasoning (per test report `stage15-benchmark-20260613-02.md`): "Three closure options... Option 1 (recommended): Reclassify B05/B06 to NOT-IN-SCOPE for the MTP fixture."

This fix targets the MTP /v1/chat/completions path, the exact path that triggered the BLOCKED-structural-not-infra classification. If QA verification of this fix confirms the structural root cause is fixed:

- TP-15-PC1 (`n_checkpoint_payload_descriptors` non-zero on chat path with MTP fixture): expected post-fix PASS
- TP-15-PC2 (`cache_checkpoint_admissions_total{mode="hybrid"}` non-zero after first chat save): expected post-fix PASS
- TP-15-PC3 (no `cache_checkpoint_admission_failures_total` increase on chat path): expected post-fix PASS
- TP-15-PC4 (29/30 or 30/30 cache_n > 0 on subsequent identical chat requests): expected post-fix PASS

If all four pass, the structural root cause is fixed on the MTP fixture. B02/B05/B06 may be reclassified back to `IN-SCOPE` for the MTP fixture and re-verified on next stage entry.

**Recommendation**: Manager should wait for QA verification of TP-15-PC1..TP-15-PC7 on the MTP fixture, then revisit decision 1. Not making the decision here. The Manager owns the tracker row update per the improvement memory rule.

If any row fails or remains BLOCKED, decision 1 stands. If MTP draft tokens extend past chat prompt (per risk I-16-03), the new boundary's `token_end` undershoots and the fix is incomplete; a follow-up design correction is needed.

## Test plan readiness

TP-15-PC1..TP-15-PC7 are adequate for QA verification of the operational fix. Confirmed:

| Row | Coverage | Adequate |
| --- | --- | --- |
| TP-15-PC1 | `n_checkpoint_payload_descriptors` increases on chat path with MTP fixture | Yes (post-fix) |
| TP-15-PC2 | `cache_checkpoint_admissions_total{mode="hybrid"}` non-zero after first chat save | Yes |
| TP-15-PC3 | `cache_checkpoint_admission_failures_total` no increase on chat path | Yes |
| TP-15-PC4 | `cache_n > 0` on 29/30 or 30/30 subsequent identical chat requests | Yes |
| TP-15-PC5 | multi-turn messages `cache_n > 0` on subsequent identical requests | Yes |
| TP-15-PC6 | `/completion` (native) regression: `cache_n > 0` with MTP fixture | Yes (regression) |
| TP-15-PC7 | 5 `n_ctx_seq (140032) < n_ctx_train (262144)` warnings unchanged | Yes (regression) |

Missing rows (non-blocking):

- **TP-15-UT1** (structural unit test, per architecture part-09 Verification section 1): call `cache_metadata_from_chat_messages` with 3-message input, assert `MESSAGE_END` boundary at `[0, tokens.size()]` with `metadata == "prompt"`. Pure metadata, no model required. Deterministic. Recommend adding to test plan in test-plan follow-up.
- **TP-15-UT2** (degenerate case): call `cache_metadata_from_chat_messages` with empty `messages` array, assert no prompt-span boundary added (conditional `!messages.empty()` guard). Pure metadata.

TP-15-UT1 and TP-15-UT2 are not required for PASS, but they lock the contract at the unit-test level. Operational rows PC1..PC7 verify the integration; unit-test rows verify the metadata shape.

## Handoff

Next owner: **Manager** (design gate decision on this correction).

Manager records follow-up design-gate decision in this part file (per upstream-merge-guide part-04 section 5 step 3). Manager also:

- Updates `cache-handling-stage-tracker.md` Stage 16 row `Manager gate decision` column after design gate passes.
- After QA verification of TP-15-PC1..TP-15-PC7, revisits decision 1 (B02/B05/B06 reclassification) per Manager decision 1 impact section above.
- Tracks test plan follow-up to add TP-15-UT1, TP-15-UT2 (optional), and integrate TP-15-PC1..TP-15-PC7.

If this gate had been REWORK, the next owner would be Architect (this reviewer) in a new fresh session. Corrections would be design-level, so the Designer/Architect re-authors, not Developer. (Developer owns the test plan follow-up rows, not the design correction.)

Architect verdict recorded here. No further design-level work required for this correction.

## Manager design gate decision

Date: 2026-06-16
Verdict: **PASS** (design gate approved)
Recorded by: Manager

Decision text (verbatim):

> Design correction approved. Stage 16 advances from `design-only` to `implementation-planning`. The 0 BLOCKING, 2 non-blocking (F-16-01 wording imprecision on checksum function name; F-16-02 missing TP-15-UT1 structural unit-test row) and 3 INFO findings do not block gate progression. F-16-02 will be addressed in the test-plan follow-up by QA. F-16-01 is a wording tightening that can be applied during implementation evidence documentation.
>
> Manager closure decision 1 (2026-06-13, B02/B05/B06 NOT-IN-SCOPE for MTP fixture) revisit is deferred until QA verification of TP-15-PC1..TP-15-PC7 confirms the structural root cause is fixed on the MTP fixture. If any row fails or remains BLOCKED, decision 1 stands.
>
> Next gate: implementation planning (Developer, fresh session). Implementation is already applied (commit `ae2df9657`); the plan is a retrospective documentation of the steps taken and the remaining test-plan integration work.

Tracker row updated to `implementation-planning` status, Manager gate decision `2026-06-16 (design gate)`.
