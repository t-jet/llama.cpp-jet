# Stage 40 Manager retest routing

Date: 2026-08-26
Stage: 40 (Upstream merge cycle)
Trigger: Developer test-results review REWORK (0 product bugs; evidence gaps)
Review: test-report-20260826-02-developer-review.md
Manager: self (autonomous session, user unreviewable)

## Classification

0 product bugs. The rework findings are evidence/harness gaps, not product
defects. This routes to a QA retest (step 6 reopen), not to the product
bug-fix loop.

## Retest scope (from Developer review)

| ID | Finding | Required retest | Owner |
|----|---------|-----------------|-------|
| RM-01 | TP-40-MET-01/03 cited `{mode="legacy"}` only; plan signal requires `{mode="hybrid"}` | Hybrid run: Qwen3-0.6B, `--metrics --cache-mode hybrid --cache-cold-max-mib 2048`; assert `cache_cold_budget_bytes{mode="hybrid"} = 2147483648` and `cache_hits_total{mode="hybrid"}` present | QA |
| RM-02 | TP-40-RT-02 SKIP invalid; merged `test_stream.py` has 3 stream-resume tests | Run `tools/server/tests/unit/test_stream.py` against built server; if unrunnable, keep SKIP with exact harness limitation cited | QA |
| RM-03 | TP-40-COV-01 BLOCKED on wrong toolchain | Close via OpenCppCoverage (present at `D:\app\OpenCppCoverage\OpenCppCoverage.exe`) + `run_coverage.ps1` + `build-cov` reconfigure RelWithDebInfo (Stage 18 D-IMPL-01 flags). GCC only if A blocks | QA (Dev/Arch support for build-cov reconfigure) |
| RM-04 | F-40-C-01 cold_budget=-1 | Non-issue in legacy (documented Stage 17 sentinel). Closed by RM-01 hybrid positive. | QA via RM-01 |

## Manager decisions

| ID | Decision |
|----|----------|
| D40-RET-01 | Reopen test execution gate for the retest scope above. New report file required: `test-report-20260826-03.md`. |
| D40-RET-02 | Coverage must close via OpenCppCoverage + build-cov (the repo standard), not GCC. |
| D40-RET-03 | No product bug fix authorized. This is evidence completion, not defect fixing. |

## Next handoff

- Next owner: QA
- Next gate: Test execution (retest, fresh report -03)
- After retest: Developer re-reviews the new report; then stage closure.
