# Stage 39 D39-QA-14 developer review

Date: 2026-07-17
Reviewed report: `test-report-20260717-14.md`
Evidence root: `._test_output/test-report-20260717-14/`
Verdict: PASS
Owner: Manager for closure

## Scope

This is a test-results review only. No product code, script, fixture, workload,
budget, seam, coverage policy, threshold, commit, push, PR, model rerun, or
coverage rerun was performed.

Inputs reviewed:

- `._design_docs/.test_reports/test-report-20260717-14.md`
- `._design_docs/cache-handling-phase39-implementation/part-203-manager-d39-qa14-coverage-symbol-rerun-gate-20260717.md`
- `._design_docs/.test_reports/test-report-20260717-13.md`
- `._design_docs/.test_reports/test-report-20260717-13-developer-review.md`
- `._design_docs/.test_reports/test-report-20260717-13-fixes.md`
- `._design_docs/cache-handling-phase39-implementation/part-201-d39-qa13-coverage-tooling-fix-20260717.md`
- `._design_docs/cache-handling-phase39-implementation/part-202-architect-d39-qa13-coverage-tooling-fix-review-20260717.md`
- selected D39-QA-14 evidence files under `._test_output/test-report-20260717-14/`

## Result

D39-QA-14 satisfies the Part 203 coverage-symbol rerun gate.

The run used a fresh seam-ON Release coverage build at
`build-stage39-seam-on-qa14-cov`. Configure evidence records `/Zi` for C and
C++ Release flags and `/DEBUG:FULL` for executable and shared-linker Release
flags. The build target set passed, and `pdb-verification.json` records adjacent
`.pdb` files for `llama-server` plus the 11 focused coverage test executables.

Both shells passed parser and `-CoverageValidationSelfTest` gates. PowerShell 7
and Windows PowerShell 5 success coverage runs each exited `0`, retained 12
`.cov` files, wrote 11 Cobertura packages and 95 classes, and reported
`lines-valid=47837`. The wrapper approved denominator table reported
`10936 / 12887`, combined line rate `0.8486`, and `80% threshold: PASS` in both
success runs.

Both forced-failure blocks behaved as required. PowerShell 7 and Windows
PowerShell 5 forced runs exited `1`, retained 12 `.cov` files, did not write
`coverage-merged.xml` or `coverage-report.md`, and logged
`OpenCppCoverage merge failed with exit code 23`.

Cleanup evidence is clean: `summary.json` records no remaining `llama-server`
processes and ports `8297`, `8298`, `8299`, and `8300` closed.

## Classification

| Gate item | Evidence | Classification | Owner |
| --- | --- | --- | --- |
| Symbolized build | `/Zi` and `/DEBUG:FULL` configure command; build exit `0`; all required `.pdb` files present | PASS | None |
| PowerShell 7 parser and self-test | `pwsh7-parser.exit=0`, `pwsh7-coverage-selftest.exit=0` | PASS | None |
| Windows PowerShell 5 parser and self-test | `powershell5-parser.exit=0`, `powershell5-coverage-selftest.exit=0` | PASS | None |
| PowerShell 7 success coverage | exit `0`, 12 `.cov`, packages `11`, `lines-valid=47837`, approved line rate `0.8486` | PASS | None |
| PowerShell 7 forced-failure coverage | exit `1`, expected merge error present, merged XML/report absent | PASS | None |
| Windows PowerShell 5 success coverage | exit `0`, 12 `.cov`, packages `11`, `lines-valid=47837`, approved line rate `0.8486` | PASS | None |
| Windows PowerShell 5 forced-failure coverage | exit `1`, expected merge error present, merged XML/report absent | PASS | None |
| Cleanup | no `llama-server` processes; ports `8297` through `8300` closed | PASS | None |

## Developer decision

No product bug, script defect, coverage blocker, or execution blocker remains
from D39-QA-14. The D39-QA-13 empty-denominator coverage issue is closed by the
symbolized D39-QA-14 run and the accepted `run_coverage.ps1` fail-closed
behavior.

Final status: PASS.

Next owner: Manager for Stage 39 closure review.
