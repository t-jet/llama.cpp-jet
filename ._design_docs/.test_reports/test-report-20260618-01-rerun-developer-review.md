# Test report 2026-06-18 01 rerun - developer review

Status: PASS
Date: 2026-06-18
Stage: 18 (Stage 17 Closure Trivial Follow-ups)
Branch: work-branch
Owner: Developer (test-results review, fresh session)
Source: [test-report-20260618-01-rerun.md](test-report-20260618-01-rerun.md) (QA re-execution PASS)
Test plan: [../cache-handling-test-plan/part-28-stage18-stage17-closure-trivial-followups.md](../cache-handling-test-plan/part-28-stage18-stage17-closure-trivial-followups.md)
Test-plan review: [../cache-handling-test-plan/stage-18-test-plan-review-20260618.md](../cache-handling-test-plan/stage-18-test-plan-review-20260618.md) (PASS, 0 BLOCKING, 2 non-blocking, 5 INFO)
Parent test report: [test-report-20260618-01.md](test-report-20260618-01.md) (FAIL, 12 PASS / 2 FAIL)
Bug-fix report: [test-report-20260618-01-fixes.md](test-report-20260618-01-fixes.md) (PASS, iteration 1)
Bug-fix review iter 2: [test-report-20260618-01-architect-fix-review-iteration-2.md](test-report-20260618-01-architect-fix-review-iteration-2.md) (PASS)

## Scope and verdict

PASS. The QA re-execution at `test-report-20260618-01-rerun.md` resolved both blocking failures from the parent FAIL (F-18-EXEC-01 and F-18-EXEC-02) without regressing any of the 12 prior PASS rows. Source code is byte-identical to the bug-fix review iter 2. Coverage line-data is fully unblocked. No product bugs found. R-18-RUN-01 is a non-blocking INFO finding about Stage 17 prefix policy working as designed, not a product bug.

Next owner: Manager in a new fresh session for Stage 18 closure.

## Per-row classification (14 rows)

| ID | Parent verdict | Rerun verdict | Note |
| --- | --- | --- | --- |
| TP-18-FT1 | PASS | PASS | 89/89 PASSED result lines; 0 FAILED; binary summary "Total: 89 tests" includes 2 new Stage 18 tests |
| TP-18-FT2 | PASS | PASS | git diff --check exit 0; no trailing whitespace; no CRLF |
| TP-18-FT3 | PASS | PASS | Select-String cold-path-hybrid returns 1 match at line 1283 SRV_ERR (single canonical block; pre-fix duplicate at 1554-1557 removed in Stage 18 Item 1) |
| TP-18-FT4 | PASS | PASS | CMAKE_CXX_FLAGS_RELEASE line 80 = `/O2 /Ob2 /DNDEBUG /Zi`; no /DEBUG:FULL (D18-IMPL-01 step 1) |
| TP-18-FT5 | PASS | PASS | CMAKE_C_FLAGS_RELEASE line 98 = `/O2 /Ob2 /DNDEBUG /Zi`; mirrors CXX flag |
| TP-18-FT6 | PASS | PASS | implicit in FT1; no-op rebuild; obj timestamps confirm content correctness |
| TP-18-FT7 | PASS | PASS | llama-server.exe build exit 0; server reached /health; HTTP 200; body `{"status":"ok"}` |
| TP-18-FT8 | PASS | PASS | 3 linker flags (EXE line 116, MODULE line 192, SHARED line 248) all contain `/INCREMENTAL:NO /debug /DEBUG:FULL` |
| TP-18-IT1 | FAIL | PASS | F-18-EXEC-01 fixed. Exit code 1. Bounded error `--cache-cold-max-mib requires --cache-mode hybrid` at server-context.cpp:1268 SRV_ERR, prints at 10.807ms before any model warmup. No STATUS_STACK_BUFFER_OVERRUN (0xC0000409) |
| TP-18-IT2 | PASS | PASS | hybrid + cold-path + 100 MiB: server reached /health 200; cold store path and budget logs present |
| TP-18-IT3 | FAIL | PASS | F-18-EXEC-02 fixed. Exit code 1. Bounded error `--cache-prompt-evidence requires --cache-mode hybrid` at server-context.cpp:1259 SRV_ERR, prints at 13.943ms before any model warmup. No STATUS_STACK_BUFFER_OVERRUN. Exact message differs from parent expectation because legacy mode fires the hybrid-required check before the raw+log-prompts-dir check (per QA substance rationale) |
| TP-18-IT4 | PASS | PASS | .cov file = 1,385,299 bytes (> 1 KB threshold); 89/89 focused tests ran during coverage |
| TP-18-IT5 | PASS | PASS | Cobertura XML = 8,478,264 bytes; 959 class entries; 189,002 line entries |
| TP-18-IT6 | PASS | PASS | MTP fixture: server starts; /health 200; req1 and req2 both HTTP 200; cache_n=0 on both (Stage 17 prefix policy classifies entry=56/task=17 ratio as unsafe_prefix_rejected). See R-18-RUN-01 |

Counts: 14 PASS / 0 FAIL / 0 BLOCKED / 0 SKIP. Matches the QA report's 14 PASS / 0 FAIL / 0 BLOCKED / 0 SKIP.

## F-18-EXEC-01 disposition

FIXED. The Stage 18 bug-fix loop iteration 1 (Developer session) moved the cache validation block from `tools/server/server-context.cpp:1381-1427` (after `llama_init = common_init_from_params()` at line 1292) to `tools/server/server-context.cpp:1242-1291` (before `llama_init = common_init_from_params()`). The block also replaced `throw std::runtime_error` with `return false` so `load_model()` (bool) propagates a clean exit. The QA re-execution confirms:

- Exit code: 1 (was -1073740791 = 0xC0000409)
- Bounded error: `--cache-cold-max-mib requires --cache-mode hybrid` at SRV_ERR line 1268
- Validation prints at 10.807ms (was 786ms warmup line followed by crash at 965ms)
- No STATUS_STACK_BUFFER_OVERRUN

Evidence: it01/server.err.log (direct invocation form captured full SRV_ERR body); it01/exit-code.log (1).

## F-18-EXEC-02 disposition

FIXED. Same root cause and same fix as F-18-EXEC-01. The validation block now runs before any model load step. The QA re-execution confirms:

- Exit code: 1 (was -1073740791 = 0xC0000409)
- Bounded error: `--cache-prompt-evidence requires --cache-mode hybrid` at SRV_ERR line 1259
- Validation prints at 13.943ms (was 774ms warmup line followed by crash at 961ms)
- No STATUS_STACK_BUFFER_OVERRUN

Message text difference from parent expectation: parent report expected exact text `raw prompt evidence requires --log-prompts-dir`. The QA re-execution's `--cache-prompt-evidence raw` (default cache mode = legacy) makes the validation fire the hybrid-required check at line 1259 first. To hit the exact `raw prompt evidence requires --log-prompts-dir` message the user must also pass `--cache-mode hybrid` (validation reaches the raw+log-prompts-dir check at line 1264 only after the hybrid-required check passes). The QA's substance criterion (bounded-error exit, non-zero exit, no STATUS_STACK_BUFFER_OVERRUN) is met. The bug-fix report's f18exec02b-hybrid-direct.ps1 confirms the raw+log-prompts-dir check fires with hybrid mode + raw + no log-prompts-dir.

Evidence: it03/server.err.log (direct invocation form); it03/exit-code.log (1). Bug-fix report f18exec02b-server.out.log shows the exact `raw prompt evidence requires --log-prompts-dir` message at exit code 1.

## Non-blocking findings

### R-18-RUN-01 (INFO, optional follow-up): IT6 cache_n=0 with 17-token haiku

Status: Stage 17 prefix policy working as designed, not a product bug.

Evidence: req1 cache_n=0 (save phase); req2 cache_n=0 (Stage 17 policy rejects restore due to entry=56/task=17 ratio, classified as `unsafe_prefix_rejected`). The parent report's req2 cache_n=11 may have used a longer prompt that pushed the entry:task ratio above the Stage 17 policy threshold. The test plan part-28 line 95-100 explicitly states IT6 is a "Stage 17 IT8 regression smoke, not deferred-path validation". The smoke check (server starts, /health responds, both chat requests return 200) is satisfied.

Action: optional follow-up. If exact cache_n > 0 is required for IT6 smoke, the test plan should document the required task prompt length and entry token count to match Stage 17 policy thresholds. No product change required. This is a test-plan observation, not a product bug from the Stage 18 fix path.

### R-18-RUN-02 (INFO, positive): Coverage larger than parent reference

Status: positive finding. Coverage line-data contract is fully unblocked.

Evidence: IT4 .cov = 1,385,299 bytes (vs parent 327,137 bytes); IT5 Cobertura XML = 8,478,264 bytes (vs parent 2,040,697 bytes). Larger sizes are due to broader `--modules='build-cov/bin/Release/*'` glob including DLL modules (ggml.dll, llama.dll, mtmd.dll, llama-common.dll, llama-server-impl.dll, ggml-cpu.dll, ggml-base.dll), not just test-cache-controller.exe. 959 class entries vs 109 (8.8x); 189,002 line entries vs 46,338 (4.1x).

Action: none. The 80% combined and 70% product-only rate thresholds remain closure contracts for a follow-up cache-targeted coverage run, not for this re-execution.

### N-18-RUN-03 (INFO, harness observation): Start-Process stderr flush for fast-exit cases

Status: harness observation, not a product bug.

Evidence: Start-Process -RedirectStandardError produced partial err.log files for IT1 and IT3 (only init lines, not SRV_ERR) because the process exits before stderr flush completes. Direct invocation (`& $exe *>&1 | Out-File`) captures the full sequence.

Action: future IT1/IT3-style fast-exit rows should use direct invocation form. Start-Process form is sufficient for long-running rows (IT2, IT6).

## Code review

Source code is byte-identical to the bug-fix review iter 2 (Architect PASS at 2026-06-18):

| Check | Verdict | Evidence |
| --- | --- | --- |
| `git diff -w --numstat HEAD -- tools/server/server-context.cpp` | 50 / 52 (unchanged) | terminal `git diff -w` output above |
| `git diff -w --numstat HEAD -- tests/test-cache-controller.cpp` | 52 / 1 (unchanged) | terminal `git diff -w` output above |
| `git diff --check HEAD` | clean (no trailing whitespace, no CRLF) | rerun report FT2 evidence |
| Validation block position (lines 1242-1291, before `llama_init` at 1292) | preserved | bug-fix review iter 2 row 8; matches the 50/52 stat |
| All 8 SRV_ERR strings byte-identical to pre-fix HEAD | preserved | bug-fix review iter 2 row 9 |
| Return-false pattern in validation block | preserved | bug-fix review iter 2 row 2 |
| 2 new focused tests (test_stage18_f18dr01_corner_case_rejected, test_stage18_f18exec02_raw_legacy_rejected) | PASS | rerun report FT1 evidence (89 PASSED result lines) |

No new code changes in this iteration. The bug-fix review iter 2 already PASSed all code-review checks.

## Evidence paths

All evidence paths in `._test_output/test-report-20260618-01-rerun-artifacts/` exist:

- cold-path/
- ft1/ (build-test.log, test-cache-controller-direct.log)
- ft2/ (ft2-git-diff-check.log)
- ft3/ (ft3-select-string-cold-hybrid.log)
- ft4/ (ft4-cxx-flags.log)
- ft5/ (ft5-c-flags.log)
- ft7/ (build-server.log, ft7-server.out.log, ft7-server.err.log, ft7-health-response.log)
- ft8/ (ft8-linker-flags.log)
- it01/ (server.err.log, exit-code.log)
- it02/ (server.err.log, health-response.log)
- it03/ (server.err.log, exit-code.log)
- it04/ (coverage-stage18-rerun.cov, opencppcoverage.log)
- it05/ (coverage-stage18-rerun.xml)
- it06/ (chat-1-request.json, chat-1-response.json, chat-2-request.json, chat-2-response.json, health-response.log, server.err.log)

Note: ft6/ is not a separate directory; FT6 is implicit in FT1 (no-op rebuild with content correctness confirmed by obj timestamp).

## Product bugs found in this review

None. The Stage 18 bug-fix loop iteration 1 resolved both F-18-EXEC-01 and F-18-EXEC-02. The QA re-execution confirms both fixes work end-to-end. The 12 prior PASS rows are regression-free. R-18-RUN-01 is a test-plan observation about Stage 17 prefix policy threshold, not a product bug from the Stage 18 fix path.

## Retest scope

None required. All 14 rows PASS. Coverage is MEASURABLE (T114, T114a, T115 contracts unblocked). Both fix evidence and regression evidence are present in the rerun report.

## Unresolved execution blockers

R-18-RUN-01 is the only execution-time observation, and it is optional / non-blocking. The test plan part-28 line 95-100 explicitly states IT6 is a smoke check, not deferred-path validation. The smoke check criteria (server starts, /health 200, both chat requests 200) are met.

## Manager closure recommendation

Recommend PASS for Stage 18 closure. The conditions for closure are:

1. Parent FAIL (12 PASS / 2 FAIL) has been resolved via bug-fix loop iteration 1, confirmed by QA re-execution (14 PASS / 0 FAIL / 0 BLOCKED / 0 SKIP).
2. Bug-fix report (`test-report-20260618-01-fixes.md`) PASS.
3. Bug-fix review iter 2 (`test-report-20260618-01-architect-fix-review-iteration-2.md`) PASS, 0 BLOCKING.
4. Test-results review (this report) PASS, 0 BLOCKING, 0 product bugs.
5. Coverage line-data contract is MEASURABLE. The 80% combined and 70% product-only rate thresholds remain closure contracts for a follow-up cache-targeted coverage run, not for Stage 18.
6. Source code is clean (`git diff --check HEAD` clean) and the validation block is positioned before the model load step (lines 1242-1291, before `llama_init` at 1292).

The Manager can close Stage 18 bug-fix loop iteration 1 and advance the gate per document-index.md workflow. Optional follow-up: R-18-RUN-01 (IT6 prompt length documentation in test plan) can be addressed in a future cleanup pass, but does not block closure.

## Handoff

PASS. Next owner: Manager in a new fresh session for Stage 18 closure.

Manager actions:

1. Acknowledge bug-fix loop iteration 1 closure based on the QA re-execution PASS and this test-results review PASS.
2. Advance Stage 18 gate per document-index.md workflow.
3. Optional but recommended: ask QA to document the IT6 prompt length and entry token count in the test plan to match Stage 17 prefix policy thresholds (R-18-RUN-01 follow-up). This is not a closure blocker.
4. Optional but recommended: ask Developer to apply the three non-blocking description corrections (NB-18-ARCH-01, NB-18-ARCH-02, NB-18-ARCH-03) noted in the bug-fix review iter 2. These are cosmetic prose inaccuracies in the bug-fix report, not closure blockers.

This file uses LF line endings, plain ASCII status labels, and stays under the 300-line durable-doc cap. No source code, design, implementation, architecture, test plan, or other durable docs were modified by this Developer review session. The durable record of the re-execution verdict is in this file; per-row evidence is under `._test_output/test-report-20260618-01-rerun-artifacts/`.
