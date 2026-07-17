# Part 202: Architect D39-QA-13 coverage tooling fix review

Date: 2026-07-17
Status: PASS - script fix accepted; positive coverage build still blocked
Owner: Architect
Reviewed inputs:
- `../.test_reports/test-report-20260717-13.md`
- `../.test_reports/test-report-20260717-13-developer-review.md`
- `../.test_reports/test-report-20260717-13-fixes.md`
- `part-201-d39-qa13-coverage-tooling-fix-20260717.md`
- `../cache-handling-test-scripts/run_coverage.ps1`

## Scope

This is a bug-fix review for coverage tooling only. It does not approve any
product-code, fixture, workload, budget, seam, threshold, or coverage-policy
change.

## Verdict

PASS.

`run_coverage.ps1` now fails closed for the D39-QA-13 defect class. The absence
of positive coverage is acceptable as a build-symbol blocker for this review,
but it is not acceptable as Stage 39 coverage evidence. A coverage-capable
build and a positive run are still required before QA can close the coverage
gate.

## Review decisions

1. Path handling is acceptable. `BuildDir`, `SourceRoot`, `OutDir`, `ModelPath`,
   and `OcPath` are normalized at the wrapper boundary. Bad existing paths fail
   before OpenCppCoverage runs. Relative paths are not passed through as
   relative paths; they resolve to absolute paths first.
2. Missing target artifacts fail closed. Each focused test executable is checked
   before capture. `llama-server.exe` is checked when the server probe is
   enabled.
3. Missing debug symbols fail closed. The wrapper requires the adjacent `.pdb`
   for every focused test executable and for `llama-server.exe`; the current
   `build-stage39-seam-on-qa13` tree stops at
   `test-cache-controller.pdb` before any target or model run.
4. `--optimized_build` is appropriate. Installed OpenCppCoverage 0.9.9.0
   documents the option as optimized-build heuristics, and D39-QA-13 uses
   optimized Release binaries with PDBs once rebuilt.
5. Cobertura validation is now fail-closed. The wrapper rejects
   `lines-valid=0`, missing `<package>` rows, and no approved denominator rows
   before threshold acceptance.
6. The debug-symbol preflight is specific enough for the approved focused tests
   and server probe. It does not try to infer symbol quality from empty XML
   after the fact; it requires the concrete `.pdb` artifact beside each target.

## Validation performed

- PowerShell parser check for `run_coverage.ps1`: PASS.
- `pwsh.exe -File run_coverage.ps1 -CoverageValidationSelfTest`: PASS.
- `powershell.exe -File run_coverage.ps1 -CoverageValidationSelfTest`: PASS.
- OpenCppCoverage local help confirms `--optimized_build` support.

No model run, server probe, target coverage run, or product build was executed
for this review.

## Required corrections

No Developer script correction is required before the next gate.

The remaining blocker is execution/build setup: QA or Developer must rebuild the
same seam-ON Release target set with MSVC `/Zi` and linker `/DEBUG:FULL`, then
rerun the fixed coverage wrapper. The success block must produce nonempty
packages, positive `lines-valid`, approved denominator rows, and an actual
80 percent threshold verdict before the forced-failure blocks run.

## Next gate

Manager should open a coverage-capable rebuild and coverage-rerun gate:

1. Create a fresh seam-ON Release build of the D39-QA target set with `/Zi` and
   `/DEBUG:FULL` for the focused tests and `llama-server`.
2. Run PowerShell 7 parser and `-CoverageValidationSelfTest` for
   `run_coverage.ps1`.
3. Run Windows PowerShell 5 parser and `-CoverageValidationSelfTest` for
   `run_coverage.ps1`.
4. Run coverage block 1 success with absolute `BuildDir`, `SourceRoot`,
   `OutDir`, and `ModelPath`.
5. If block 1 passes with a nonzero denominator and line rate at or above 0.80,
   run the PowerShell 7 forced-failure block, Windows PowerShell 5 success
   block, and Windows PowerShell 5 forced-failure block.

Handoff state: ready for Manager rerun gate; coverage evidence remains blocked
until that gate produces a positive coverage run.
