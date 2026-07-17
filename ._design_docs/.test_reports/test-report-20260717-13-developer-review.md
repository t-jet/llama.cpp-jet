# Stage 39 D39-QA-13 developer review

Date: 2026-07-17
Reviewed report: `test-report-20260717-13.md`
Evidence root: `._test_output/test-report-20260717-13/`
Verdict: REWORK REQUIRED
Owner: Developer

## Scope

This is a test-results review only. No code, script, workload, budget, seam,
threshold, product behavior, commit, push, PR, or model rerun was performed.

Inputs reviewed:

- `._design_docs/.test_reports/test-report-20260717-13.md`
- `._design_docs/cache-handling-phase39-implementation/part-199-manager-d39-qa13-rerun-gate-20260717.md`
- `._design_docs/cache-handling-test-scripts/run_coverage.ps1`
- `._test_output/test-report-20260717-13/coverage/pwsh7-success-rerun/`

## Result

D39-QA-13 moved past the earlier TP-39-03 driver fixes. The fresh seam-ON
Release build, both PowerShell parser and pure gates, and the canonical
TP-39-03 model node passed.

Coverage then opened for the first time after a full `Assert-Tp3903` PASS.
Coverage block 1 failed because OpenCppCoverage produced 12 `.cov` files and a
merged XML with exit `0`, but the Cobertura denominator was empty:
`lines-valid="0"` and no packages. The wrapper correctly rejected `0 / 0` as
below the 80 percent threshold.

This is not a product-code defect. It is a coverage tooling/script defect in
`run_coverage.ps1`, with one earlier QA invocation defect already bypassed by
the absolute-path rerun.

## Classification

| Item | Evidence | Classification | Owner | Retest scope |
| --- | --- | --- | --- | --- |
| Fresh Release seam-ON full target build | Configure/build logs pass; required target binaries recorded | PASS | None | No fix retest needed unless Manager orders a new clean gate |
| PowerShell 7 parser and `-MetricValidationSelfTest` | Both report `Outcome : PASS` | PASS | None | No fix retest needed unless script changes touch parser-sensitive files |
| Windows PowerShell 5 parser and `-MetricValidationSelfTest` | Both report `Outcome : PASS` | PASS | None | No fix retest needed unless script changes touch parser-sensitive files |
| Canonical TP-39-03 | `summary.json` has `Outcome="PASS"`, `DecisionSeries=2`, `TransactionSeries=1`, `ColdFiles=2`; exit `0` | PASS | None | No product retest needed for this review; rerun only if Manager requires a fresh full gate after coverage repair |
| First coverage invocation using relative `-SourceRoot .` | OpenCppCoverage failed before target execution with exit `-1618178468` | QA invocation defect | QA, closed in report by absolute-path rerun | No code fix required for that run; future QA must use absolute `SourceRoot` until script preflight is fixed |
| Coverage block 1 absolute rerun | 11 focused tests plus server probe ran; 12 tiny `.cov` files existed; merge exit `0`; XML has `lines-valid=0`, empty packages | Coverage tooling/script defect | Developer | Fix `run_coverage.ps1`, then rerun PowerShell 7 success coverage block with absolute paths and require nonzero denominator plus >=80 percent line coverage |
| Coverage blocks 2 through 4 | `coverage-stop.json` blocked them after block 1 failure | Execution blocker caused by coverage block 1 | Developer to unblock, QA to execute after fix | After block 1 has valid nonzero coverage, run PowerShell 7 forced merge failure, Windows PowerShell 5 success, and Windows PowerShell 5 forced merge failure |

## Developer decision

A bug-fix loop is required, but it is a coverage-script/tooling loop, not a
product loop.

Developer owns `._design_docs/cache-handling-test-scripts/run_coverage.ps1`.
The next fix must make the coverage wrapper fail closed before it can report an
empty denominator as useful evidence. It must also correct the OpenCppCoverage
source/module mapping so the merged Cobertura XML contains packages and a
positive `lines-valid` denominator for the approved hybrid cache source set.

The script should also normalize or reject a relative `SourceRoot` before
starting OpenCppCoverage. QA's absolute rerun proved that the relative-path
failure is avoidable, but the wrapper should not let a relative source root
reach the tool in a form that crashes before target execution.

Product code is not implicated by D39-QA-13. The passed TP-39-03 evidence
exercised the Stage 39 pressure behavior and reached the expected same-owner
exact-cold/checkpoint-evicted state.

## Required retest after fix

Developer fix evidence:

1. PowerShell 7 parser check for `run_coverage.ps1`.
2. Windows PowerShell 5 parser check for `run_coverage.ps1`.
3. Focused PowerShell 7 success coverage run against the existing seam-ON
   Release build, with absolute `BuildDir`, `SourceRoot`, `OutDir`, and
   `ModelPath`.
4. Evidence that `coverage-merged.xml` has positive `lines-valid`, nonempty
   packages, and combined line rate >= 0.80.
5. Evidence that empty or missing denominator cases fail with a clear wrapper
   error before acceptance.

QA retest scope after Developer fix review:

1. Run the D39-QA coverage block 1 success path.
2. If block 1 passes with nonzero denominator and >=80 percent line coverage,
   run coverage blocks 2 through 4 exactly as the Manager gate requires.
3. A full clean build and TP-39-03 rerun are Manager decisions. They are not
   required by this review because D39-QA-13 already produced fresh PASS
   evidence for build, parser/pure gates, and canonical TP-39-03.

## Handoff

Status: REWORK REQUIRED.

Next action: Developer coverage-script fix loop. Do not change product code
unless the coverage fix produces new evidence that directly implicates product
build flags, debug symbols, or target/source mapping outside the script.
