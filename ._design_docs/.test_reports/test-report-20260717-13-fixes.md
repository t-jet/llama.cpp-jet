# Stage 39 D39-QA-13 coverage tooling fixes

Date: 2026-07-17
Status: PARTIAL - wrapper fixed; existing build lacks debug symbols
Owner: Developer
Trigger: `test-report-20260717-13-developer-review.md`

## Scope

This fix stays in `._design_docs/cache-handling-test-scripts/run_coverage.ps1`.
Product code, fixtures, workload, budgets, thresholds, seam behavior, and
coverage policy are unchanged.

## Root cause

The failed D39-QA-13 run produced 12 tiny `.cov` files, each 119-154 bytes. A
single `.cov` conversion and the merged conversion both produced Cobertura XML
with `lines-valid="0"` and no packages.

The existing `build-stage39-seam-on-qa13` tree is not a coverage build:

- `CMAKE_CXX_FLAGS_RELEASE=/O2 /Ob2 /DNDEBUG`
- `CMAKE_C_FLAGS_RELEASE=/O2 /Ob2 /DNDEBUG`
- `CMAKE_EXE_LINKER_FLAGS_RELEASE=/INCREMENTAL:NO`
- no `.pdb` files exist under `build-stage39-seam-on-qa13`

OpenCppCoverage cannot produce line rows from that build. The script also
accepted zero-denominator Cobertura too late and did not normalize all paths at
the wrapper boundary.

## Changes

- Normalize `BuildDir`, `SourceRoot`, `OutDir`, `ModelPath`, and `OcPath` to
  absolute paths before OpenCppCoverage starts.
- Fail early when required paths or debug symbols are missing.
- Add `--optimized_build` to capture and merge invocations.
- Reject merged Cobertura when `lines-valid` is zero, packages are missing, or
  no approved denominator rows are found.
- Add `-CoverageValidationSelfTest` for pure positive/negative coverage XML
  validation.

## Evidence

Parser checks:

- PowerShell 7 parser: PASS.
- Windows PowerShell 5 parser: PASS.

Fail-closed XML validation:

- PowerShell 7 `-CoverageValidationSelfTest`: PASS.
- Windows PowerShell 5 `-CoverageValidationSelfTest`: PASS.
- Negative cases reject zero denominator, missing packages, and no approved
  denominator rows with wrapper diagnostics.

Focused coverage retest:

- Command used absolute `BuildDir`, `SourceRoot`, `OutDir`, and `ModelPath`.
- Output directory: `._test_output/d39-qa13-fix/coverage-ps7-absolute-1`.
- Result: BLOCKED before OpenCppCoverage target launch.
- Error: missing
  `build-stage39-seam-on-qa13/bin/Release/test-cache-controller.pdb`.
- No server probe or model workload ran in this blocked retest.

## Remaining work

To produce the required positive `lines-valid`, nonempty packages, and combined
line rate, rerun this wrapper on a build configured with MSVC `/Zi` and linker
`/DEBUG:FULL` for the focused targets and `llama-server`. The wrapper now fails
closed instead of accepting another `0 / 0` Cobertura merge.
