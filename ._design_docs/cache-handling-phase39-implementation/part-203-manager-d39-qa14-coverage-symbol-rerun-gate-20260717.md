# Part 203: Manager D39-QA-14 coverage symbol rerun gate

Date: 2026-07-17
Status: PASS
Gate: D39-QA-14
Owner: QA

## Inputs

- QA report: `../.test_reports/test-report-20260717-13.md`
- Developer review: `../.test_reports/test-report-20260717-13-developer-review.md`
- Fix report: `../.test_reports/test-report-20260717-13-fixes.md`
- Fix record: `part-201-d39-qa13-coverage-tooling-fix-20260717.md`
- Architect review: `part-202-architect-d39-qa13-coverage-tooling-fix-review-20260717.md`

## Decision

Part 202 passes the `run_coverage.ps1` tooling fix. D39-QA-13 already produced
fresh PASS evidence for the seam-ON build, PowerShell parser/pure gates, and
canonical TP-39-03. The remaining blocker is coverage execution on a build with
debug symbols.

Manager authorizes D39-QA-14 as a coverage-only rerun.

## Required execution

QA must:

1. Create a fresh seam-ON Release build of the D39-QA target set and
   `llama-server` with MSVC `/Zi` and linker `/DEBUG:FULL`.
2. Run PowerShell 7 parser and `-CoverageValidationSelfTest` for
   `run_coverage.ps1`.
3. Run Windows PowerShell 5 parser and `-CoverageValidationSelfTest` for
   `run_coverage.ps1`.
4. Run coverage block 1 success with absolute `BuildDir`, `SourceRoot`,
   `OutDir`, `ModelPath`, and `OcPath`.
5. If block 1 passes with nonempty packages, positive `lines-valid`, approved
   denominator rows, and combined line coverage at or above 0.80, run the
   PowerShell 7 forced-failure block, Windows PowerShell 5 success block, and
   Windows PowerShell 5 forced-failure block.

If the symbolized build, parser/self-test, or coverage block 1 fails, stop and
record the blocker. Do not run later coverage blocks after a block 1 failure.

## Scope controls

This gate does not authorize product behavior changes, fixture changes,
workload changes, budget or threshold changes, seam changes, or coverage-policy
changes. Build flag changes are allowed only for the D39-QA-14 coverage build.

## Required output

QA must create `../.test_reports/test-report-20260717-14.md` with build-symbol
evidence, parser/self-test evidence, coverage block evidence, and final
classification. Next owner after QA: Developer for test-results review.
