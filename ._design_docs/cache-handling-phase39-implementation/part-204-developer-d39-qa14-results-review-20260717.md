# Part 204: Developer D39-QA-14 results review

Date: 2026-07-17
Status: PASS
Owner: Manager for closure
Related report: `../.test_reports/test-report-20260717-14.md`
Developer review: `../.test_reports/test-report-20260717-14-developer-review.md`

## Scope

This part records the D39-QA-14 test-results review only. No product code,
script, fixture, workload, budget, seam, coverage policy, threshold, commit,
push, PR, model rerun, or coverage rerun was performed.

## Review inputs

- Manager gate: `part-203-manager-d39-qa14-coverage-symbol-rerun-gate-20260717.md`
- QA report: `../.test_reports/test-report-20260717-14.md`
- Prior QA report: `../.test_reports/test-report-20260717-13.md`
- Prior Developer review: `../.test_reports/test-report-20260717-13-developer-review.md`
- Prior fix record: `../.test_reports/test-report-20260717-13-fixes.md`
- Fix implementation part: `part-201-d39-qa13-coverage-tooling-fix-20260717.md`
- Architect fix review: `part-202-architect-d39-qa13-coverage-tooling-fix-review-20260717.md`
- Selected evidence under `../../._test_output/test-report-20260717-14/`

## Gate check

Part 203 required a fresh seam-ON Release coverage build with MSVC `/Zi` and
linker `/DEBUG:FULL`, parser and `-CoverageValidationSelfTest` in PowerShell 7
and Windows PowerShell 5, a valid PowerShell 7 success coverage block, then the
PowerShell 7 forced-failure block, Windows PowerShell 5 success block, and
Windows PowerShell 5 forced-failure block only after block 1 passed.

D39-QA-14 satisfies that order and evidence contract:

- `setup/preflight.json` records the fresh build root as absent before configure.
- `setup/cmake-configure.command.txt` records `/Zi` and `/DEBUG:FULL`.
- `setup/cmake-build-target-set.exit` is `0`.
- `setup/pdb-verification.json` records adjacent `.pdb` files for
  `llama-server` and all 11 focused coverage tests.
- PowerShell 7 parser and coverage self-test exits are both `0`.
- Windows PowerShell 5 parser and coverage self-test exits are both `0`.
- PowerShell 7 success coverage exits `0`, retains 12 `.cov` files, writes 11
  Cobertura packages and 95 classes, reports `lines-valid=47837`, and records
  approved wrapper coverage `10936 / 12887`, line rate `0.8486`.
- Windows PowerShell 5 success coverage matches the same counts and threshold.
- Both forced-failure runs exit `1`, retain 12 `.cov` files, omit
  `coverage-merged.xml` and `coverage-report.md`, and log
  `OpenCppCoverage merge failed with exit code 23`.
- `summary.json` records no remaining `llama-server` process and closed ports
  `8297`, `8298`, `8299`, and `8300`.

## Classification

All D39-QA-14 rows are PASS. No failure row, blocker row, or owner assignment is
open.

The D39-QA-13 coverage-tooling issue is closed for this gate: the fixed wrapper
still fails closed on forced merge failure, and the symbolized build produces
nonempty Cobertura packages plus a positive approved denominator above the 80
percent threshold in both shells.

## Handoff

Final status: PASS.

No product bug, script defect, coverage blocker, or execution blocker remains
from D39-QA-14. Hand off to Manager for Stage 39 closure.
