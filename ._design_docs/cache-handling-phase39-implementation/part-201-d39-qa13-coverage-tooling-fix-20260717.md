# Part 201: D39-QA-13 coverage tooling fix

Date: 2026-07-17
Status: PARTIAL - wrapper fixed; coverage build symbols missing
Owner: Developer
Report: `../.test_reports/test-report-20260717-13-fixes.md`

## Scope

This part records the D39-QA-13 coverage-script fix loop. Product code,
fixtures, workload, budgets, thresholds, seam behavior, and coverage policy are
unchanged.

## Implementation

`run_coverage.ps1` now resolves or creates the wrapper-owned paths before it can
start OpenCppCoverage:

- `BuildDir`, `SourceRoot`, and `OcPath` must exist.
- `OutDir` is normalized to an absolute directory.
- `ModelPath` must exist when the server probe is enabled.
- missing target debug symbols fail before a misleading `.cov` capture.

The wrapper also adds `--optimized_build` to capture and merge calls and checks
the merged Cobertura XML before threshold reporting. It rejects:

- `lines-valid=0`;
- missing `<package>` rows;
- no rows for the approved denominator files.

`-CoverageValidationSelfTest` covers those fail-closed checks without launching
OpenCppCoverage or a model.

## Evidence

Parser and pure validation:

- `pwsh` parser for `run_coverage.ps1`: PASS.
- Windows PowerShell 5 parser for `run_coverage.ps1`: PASS.
- `pwsh -File run_coverage.ps1 -CoverageValidationSelfTest`: PASS.
- `powershell -File run_coverage.ps1 -CoverageValidationSelfTest`: PASS.

Focused coverage attempt:

- Command used absolute `BuildDir`, `SourceRoot`, `OutDir`, and `ModelPath`.
- Build: `build-stage39-seam-on-qa13`.
- Result: BLOCKED before OpenCppCoverage target execution.
- Blocking error: missing
  `build-stage39-seam-on-qa13/bin/Release/test-cache-controller.pdb`.
- The build cache confirms Release flags lack `/Zi` and `/DEBUG:FULL`.
- No server probe or model workload ran after the preflight failure.

## Handoff

The script-side D39-QA-13 defect is corrected. Positive coverage evidence still
requires a coverage-capable build of the same target set. QA or Developer must
rerun the fixed wrapper after rebuilding with MSVC `/Zi` and linker
`/DEBUG:FULL`; only then can `coverage-merged.xml` produce nonempty packages,
positive `lines-valid`, and a real 80 percent threshold verdict.
