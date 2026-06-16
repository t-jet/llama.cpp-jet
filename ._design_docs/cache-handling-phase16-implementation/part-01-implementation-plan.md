# Stage 16 implementation part 1: implementation plan (chat-path prompt-span boundary fix)

Status: PASS
Date: 2026-06-16
Stage: 16 (post-closure chat-path prompt-span boundary fix)

## Approved design baseline

| Doc | Role | Status |
| --- | --- | --- |
| `._design_docs/cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md` | Design correction (Option A, surgical, 14-line insertion) | Approved |
| `._design_docs/cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md` | Architecture invariant (chat path MUST emit prompt-span boundary when per-message boundaries present) | Approved |
| `._design_docs/cache-handling-phase16-design/part-01-design-review-gate-01.md` | Architect design review | PASS (0 BLOCKING, 2 non-blocking, 3 INFO) |
| `._design_docs/cache-handling-phase15-implementation/part-08-stage15-post-closure-chat-path-impl.md` | Implementation evidence (code change record) | Applied, pending QA verification |
| `._design_docs/cache-handling-phase15-implementation/part-09-stage15-post-closure-followup-summary.md` | Follow-up summary | Applied |

Code change is already applied at commit `ae2df9657` on `tools/server/server-context.cpp`. Plan is retrospective: documents steps taken, evidence plan, known risks, and Manager decisions still pending.

## Ordered steps (retrospective)

Steps taken in chronological order. No further code changes authorized by this plan.

| # | Date | Step | Output |
| --- | --- | --- | --- |
| 1 | 2026-06-16 | Model log analysis: read `._analysis/model_log.txt` (319,204 lines, MTP fixture). Counted 10/10 `hybrid cache: checkpoint admission skipped (missing checkpoint boundary metadata)` warnings on `/v1/chat/completions` save events. Confirmed 10/10 `successfully saved slot` lines (exact-blob path unaffected) and the cache itself worked. Strict validator at `server-cache-hybrid.cpp:2984` rejects each save for missing boundary metadata. | design part-09 Background section |
| 2 | 2026-06-16 | Root cause analysis: traced the chat-completion path in `cache_metadata_from_chat_messages` (server-context.cpp:4383-4504). Confirmed per-message boundaries (`MESSAGE_START`, `MESSAGE_END`) cover rendered message spans only. Assistant role header at end of rendered prompt has no boundary because the assistant role has no content to search for. First end-of-prefill checkpoint `n_tokens` = full prompt size = no per-message boundary covers it. | design part-09 Root cause section |
| 3 | 2026-06-16 | Design correction (Option A, surgical): single `MESSAGE_END` boundary at `[0, n_prompt_tokens]` after per-message loop, with `metadata = "prompt"`, `protect = false`, and `cache_metadata_checksum(tokens, 0, n_prompt_tokens)`. Mirrors fallback path in `cache_metadata_for_request`. Excluded Option B (relax matching loop) as over-architected for the gap. | design part-09 Proposed fix |
| 4 | 2026-06-16 | Code change applied in commit `ae2df9657`. Hunk `@@ -4483,6 +4483,20 @@`. 14-line insertion, 0 deletions, 0 header changes, 0 metric changes. Conditional `!messages.empty()` guards the empty-messages case. | implementation part-08 Code change section; git commit `ae2df9657` |
| 5 | 2026-06-16 | Documentation: implementation part-08 (code change record, diff summary, risks observed, evidence plan), implementation part-09 (follow-up summary, cross-references), architecture part-09 (cross-stage invariant, three-entry-point model, verification paths), design part-09 (design correction). | four durable docs |
| 6 | 2026-06-16 | Tracker row added: Stage 16 status `implementation-planning`, Manager gate decision `2026-06-16 (design gate)`. Document-index rows updated for the four new durable docs and the design review. | tracker row; document-index rows |
| 7 | 2026-06-16 | Architect design review (fresh session): PASS, 0 BLOCKING, 2 non-blocking (F-16-01 wording imprecision on checksum function name; F-16-02 missing TP-15-UT1 structural unit-test row), 3 INFO (I-16-01 boundaries_native flag inheritance, I-16-02 span overlap, I-16-03 MTP draft tokens vs chat prompt). | `cache-handling-phase16-design/part-01-design-review-gate-01.md` |

## Affected code

| File | Function | Lines | Diff size | Public API impact | CLI impact | Metric impact |
| --- | --- | --- | --- | --- | --- | --- |
| `tools/server/server-context.cpp` | `cache_metadata_from_chat_messages` | 4483-4500 (insertion after per-message loop, before `return metadata`) | +14 lines, -0 lines | None (internal to `prepared_prompt_metadata`) | None (no CLI flag changes) | None (no metric label changes; `cache_checkpoint_admissions_total` will increase naturally when chat path checkpoints admit) |

No header changes. No interface changes. No new dependencies. The change is contained to one function in one file.

## Tests

The test plan is a separate durable doc. This plan proposes the rows below for the test-plan follow-up to add (Test Plan row count: 7 operational + 2 unit = 9 rows).

| ID | Row | Required for PASS? | Source |
| --- | --- | --- | --- |
| TP-15-PC1 | Verify `n_checkpoint_payload_descriptors` increases on `/v1/chat/completions` with MTP fixture after first save; was 0 before fix | Required | design part-09 |
| TP-15-PC2 | Verify `cache_checkpoint_admissions_total{mode="hybrid"}` non-zero after first chat-completion save; was 0 before fix | Required | design part-09 |
| TP-15-PC3 | Verify `cache_checkpoint_admission_failures_total{mode="hybrid"}` does not increase on chat-completion save (post-fix baseline; was 1 per save pre-fix) | Required | design part-09 |
| TP-15-PC4 | Verify hybrid-mode `/v1/chat/completions` on MTP fixture produces `cache_n > 0` on subsequent identical requests (29/30 or 30/30 expected, mirroring V2 separate-draft 29/29) | Required | design part-09 |
| TP-15-PC5 | Verify hybrid-mode `/v1/chat/completions` with multi-turn messages produces `cache_n > 0` on subsequent identical requests | Required | design part-09 |
| TP-15-PC6 | Verify hybrid-mode `/completion` (native) with MTP fixture still produces `cache_n > 0` on subsequent identical requests (regression check) | Required | design part-09 |
| TP-15-PC7 | Verify the 5 `n_ctx_seq (140032) < n_ctx_train (262144)` informational warnings per server start are unchanged (regression check) | Required | design part-09 |
| TP-15-UT1 | Structural unit test: call `cache_metadata_from_chat_messages` with 3-message input (system, user, assistant-prefix), assert metadata has at least one `MESSAGE_END` boundary at `[0, n_prompt_tokens]` with `metadata == "prompt"`. Pure metadata, no model required. Deterministic. | Optional (F-16-02) | architecture part-09 Verification section 1 |
| TP-15-UT2 | Degenerate unit test: call `cache_metadata_from_chat_messages` with empty `messages` array, assert no prompt-span boundary added (conditional `!messages.empty()` guard). | Optional (F-16-02) | Architect design review (degeneracy test) |

TP-15-PC1..PC7 are operational and run against the MTP fixture. TP-15-UT1 and TP-15-UT2 are pure metadata unit tests in `tests/test-cache-controller.cpp`. Operational rows verify the integration; unit-test rows lock the contract at the metadata level.

## Docs

Durable docs created or updated for Stage 16:

| Doc | Action | Status |
| --- | --- | --- |
| `._design_docs/cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md` | Created (design correction) | Applied |
| `._design_docs/cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md` | Created (architecture invariant) | Applied |
| `._design_docs/cache-handling-phase15-implementation/part-08-stage15-post-closure-chat-path-impl.md` | Created (code change record) | Applied |
| `._design_docs/cache-handling-phase15-implementation/part-09-stage15-post-closure-followup-summary.md` | Created (follow-up summary) | Applied |
| `._design_docs/cache-handling-phase16-design/part-01-design-review-gate-01.md` | Created (Architect design review, PASS) | Applied |
| `._design_docs/cache-handling-stage-tracker.md` | Stage 16 row added, status `implementation-planning` | Applied |
| `._design_docs/document-index.md` | Rows added for the five new durable docs | Applied |
| `._design_docs/cache-handling-phase16-implementation/part-01-implementation-plan.md` | This file | New |

## Evidence plan

QA owner runs verification. The Developer does not run builds, tests, coverage, k6, or benchmarks per the scope rules in this brief. Verification steps mirror implementation part-08 "Test-side (pending QA)" section exactly:

1. **Build verification**: `cmake --build build-cov --config Release --target llama-server`. Exit 0 required. Recompiles `server-context.cpp` only.
2. **Unit test (TP-15-UT1, TP-15-UT2)**: new test cases in `tests/test-cache-controller.cpp`. Run with `ctest -R test-cache-controller --output-on-failure`. Exit 0 required.
3. **Integration test (TP-15-PC1..PC3)**: launch llama-server with MTP fixture, exercise `/v1/chat/completions` once, scrape `/metrics`, assert `n_checkpoint_payload_descriptors > 0`, `cache_checkpoint_admissions_total{mode="hybrid"} > 0`, `cache_checkpoint_admission_failures_total{mode="hybrid"}` did not increment on the chat path.
4. **Benchmark rerun (TP-15-PC4..PC7)**: rerun the Stage 15 B05/B06 benchmark on the MTP fixture (`stage15-benchmark-20260613-03.md` driver, swap native `/completion` for `/v1/chat/completions`). Expect 29/30 or 30/30 restores, mirroring V2 separate-draft 29/29. Confirm `cache_n > 0` on subsequent identical requests; confirm `/completion` regression unchanged; confirm 5 `n_ctx_seq` warnings unchanged.

Pre-fix state for the MTP `/v1/chat/completions` path (baseline):

- 0/30 successful restores (`stage15-benchmark-20260613-02.md`, BLOCKED-structural-not-infra).
- 10/10 `hybrid cache: checkpoint admission skipped (missing checkpoint boundary metadata)` warnings (`_analysis/model_log.txt`).
- 0 `n_checkpoint_payload_descriptors` in cache stats.

Expected post-fix state on the same MTP fixture: 29/30 or 30/30 successful restores; 0 admission_skipped warnings on chat-completion paths; non-zero `n_checkpoint_payload_descriptors` and `cache_checkpoint_admissions_total` after first save.

## Known risks

| ID | Risk | Impact | Mitigation |
| --- | --- | --- | --- |
| F-16-01 | Checksum function wording imprecision: implementation part-08 says "same function the strict validator uses" but strict validator uses `cache_token_span_checksum` at `server-cache-hybrid.cpp:2997`, not `cache_metadata_checksum`. Two functions are byte-for-byte identical FNV-1a 64-bit (init 1469598103934665603, mul 1099511628211); see `server-context.cpp:4359-4373` vs `server-cache-hybrid.cpp:204-217`. Behavior correct. | Documentation clarity only (cosmetic) | During evidence documentation step, tighten wording in implementation part-08 and design part-09 to name both functions. No code change. Resolution path: implementation evidence doc (next phase16-implementation part file). |
| F-16-02 | Missing TP-15-UT1 structural unit-test row in proposed test plan. Architecture part-09 Verification section 1 calls for a unit test in `tests/test-cache-controller.cpp`. The proposed test plan has only operational rows (TP-15-PC1..PC7). | Test-plan coverage gap | Add TP-15-UT1 and TP-15-UT2 to the test plan integration list (this plan's Tests section). Test code itself is Developer's job in a later session, after test plan approval. Not required for PASS, but locks the contract at unit-test level. |
| I-16-01 | `boundaries_native` flag inheritance: `server-context.cpp:4388` sets `metadata.boundaries_native = false` for the chat path. New code does not change it. Inherited `false` setting matches per-message boundaries' flag. Strict validator's `boundaries_native` check satisfied. | None (behavior correct) | Implementation part-08 already documents this; design part-09 could be more explicit. Optional wording tightening. |
| I-16-02 | Span overlap with system message boundary: new boundary at `[0, n_prompt_tokens]`; system message boundary at `[0, N_system]` where `N_system < n_prompt_tokens`. Strict validator iterates all boundaries, matches on `token_end == descriptor.token_span_end`. New boundary is the only one with `token_end == n_prompt_tokens`. | None (no false-positive match risk) | None. |
| I-16-03 | MTP draft tokens extending past chat prompt: chat path's `n_prompt_tokens` reflects main model prompt only. MTP draft tokens are added by the model loader, not by the chat path. If MTP draft extends past chat prompt, checkpoint `n_tokens` could exceed `n_prompt_tokens` and the new boundary's `token_end` undershoots. Model log shows prompt counts 13 / 35 / 90 / 213 / 727 / 61,273 for the timed tasks, matching the chat path. | Low to medium (only if MTP draft extends past prompt) | QA verification on MTP fixture (TP-15-PC1..PC4) is the final answer. If undershoot occurs, fix scope expands to a follow-up design correction. |

## Manager decisions

Three decisions pending Manager input after QA verification:

| ID | Decision | Trigger | Recommendation |
| --- | --- | --- | --- |
| A | Revisit Manager closure decision 1 (2026-06-13, B02/B05/B06 NOT-IN-SCOPE for MTP fixture). Reasoning per `stage15-benchmark-20260613-02.md`: "Three closure options... Option 1 (recommended): Reclassify B05/B06 to NOT-IN-SCOPE for the MTP fixture." This fix targets the MTP `/v1/chat/completions` path, the exact path that triggered the BLOCKED-structural-not-infra classification. | After QA verification of TP-15-PC1..PC7 confirms structural root cause is fixed on MTP fixture. | If TP-15-PC1, PC2, PC3, PC4 all PASS on the MTP fixture, Manager may reclassify B02/B05/B06 back to IN-SCOPE for MTP fixture and re-verify on next stage entry. If any row fails or remains BLOCKED, decision 1 stands. Manager owns tracker row update per improvement memory rule `Closure sweep keeps durable docs aligned without re-running the report`. |
| B | Confirm test plan integration scope: which rows to add to test plan part-25 (existing test plan file) or open a new part-26 for the post-closure follow-up test plan? | After Manager confirms QA verification plan. | Recommend opening a new part-26 (`cache-handling-test-plan-part26-stage16-chat-path.md`) for clarity. Operational rows TP-15-PC1..PC7 required for PASS. Unit-test rows TP-15-UT1, TP-15-UT2 optional but recommended. Developer (in a later session, after test plan approval) writes the unit-test code. |
| C | Confirm whether Stage 16 closure requires a new benchmark report file (`stage16-benchmark-YYYYMMDD-NN.md`) or reuses `stage15-benchmark-20260613-03.md` with an addendum. | After QA verification completes the MTP chat-completion benchmark rerun. | Recommend a new benchmark report file scoped to the chat-completion path, mirroring `stage15-benchmark-20260613-03.md` structure. The Stage 15 report is V2 separate-draft; the Stage 16 report would be MTP `/v1/chat/completions` (the actual code path affected by the fix). Keeps the two fixtures separated and the stage rows in the tracker unambiguous. |

## Handoff

PASS verdict at this gate. Next owner: **Architect** for implementation review in a fresh session, per the Architect design review's Handoff section. The implementation review verifies:

1. Boundary added at correct point in `cache_metadata_from_chat_messages` (after per-message loop, before `return metadata`).
2. Conditional `!messages.empty()` correct (function returns early on `!messages.is_array()`, not on empty array; conditional correctly skips the empty-array case).
3. Checksum function call uses same parameters the strict validator uses (`cache_metadata_checksum(tokens, 0, n_prompt_tokens)` at `server-context.cpp:4359-4373`, byte-for-byte identical to validator's `cache_token_span_checksum` at `server-cache-hybrid.cpp:204-217`).
4. No other code path in chat path or fallback path affected.
5. Existing unit tests in `tests/test-cache-controller.cpp` unaffected (they use hand-crafted metadata, not chat path).

If REWORK, next owner is Developer (this session's owner) in a new fresh session. REWORK triggers: code change does not match design, conditional incorrect, checksum mismatch, or unit-test row additions required before evidence step.

After Architect implementation review passes, QA runs verification per the Evidence plan. Manager revisits decisions A, B, C based on QA output.
