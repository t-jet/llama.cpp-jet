# Part 200: Developer D39-QA-13 results review

Date: 2026-07-17
Status: REWORK REQUIRED
Owner: Developer
Related report: `../.test_reports/test-report-20260717-13.md`
Developer review: `../.test_reports/test-report-20260717-13-developer-review.md`

## Scope

This part records the D39-QA-13 test-results review only. No code, script,
fixture, workload, budget, seam, coverage policy, threshold, commit, push, PR,
or model rerun was performed.

## Findings

D39-QA-13 passed the fresh seam-ON Release build, both PowerShell parser and
pure gates, and canonical TP-39-03. Coverage opened only after the canonical
driver reached full `Assert-Tp3903` PASS.

Coverage block 1 then failed. The absolute-path rerun executed all 11 focused
tests plus the server probe under OpenCppCoverage and produced 12 `.cov` files.
The merge exited `0`, but the merged Cobertura XML contained:

```xml
<coverage line-rate="1" branch-rate="0" ... lines-covered="0" lines-valid="0">
  <sources/>
  <packages/>
</coverage>
```

The wrapper reported `Combined line rate: 0 (0 / 0 lines)` and failed the 80
percent threshold. That rejection is correct. An empty denominator is not valid
coverage evidence, even when OpenCppCoverage writes `line-rate="1"`.

## Classification

| Failure or blocker | Classification | Owner | Required retest |
| --- | --- | --- | --- |
| Initial relative `SourceRoot` coverage invocation failed before target execution | QA invocation defect, closed by absolute rerun | QA for invocation discipline; Developer may harden script preflight | Future runs use absolute `SourceRoot`; script fix should normalize or reject relative roots |
| Absolute coverage rerun produced 12 `.cov` files and merge exit `0`, but `coverage-merged.xml` had `lines-valid=0` and no packages | Coverage tooling/script defect | Developer | Fix `run_coverage.ps1`, rerun PowerShell 7 success coverage block, require nonzero denominator, nonempty packages, and >=80 percent line coverage |
| Coverage blocks 2 through 4 did not run | Execution blocker caused by block 1 failure | Developer to unblock; QA to execute | After block 1 passes, run PowerShell 7 forced merge failure, Windows PowerShell 5 success, and Windows PowerShell 5 forced merge failure |

No D39-QA-13 failure is classified as a product bug. No target/test mapping
defect is established because every listed focused executable and the server
probe executed. The defect is in the coverage wrapper/tool invocation and its
acceptance checks for OpenCppCoverage output.

## Developer decision

A bug-fix loop is required for
`._design_docs/cache-handling-test-scripts/run_coverage.ps1`.

Developer owns:

- making `SourceRoot` path handling fail closed or normalize to an absolute path
  before OpenCppCoverage starts;
- correcting the OpenCppCoverage source/module mapping so approved hybrid-cache
  files appear in the merged Cobertura XML;
- rejecting empty Cobertura denominators with a direct diagnostic before the
  wrapper can write a misleading threshold report.

Product code is not implicated by the current evidence. Canonical TP-39-03
passed and showed the expected pressure outcome. The next work should stay in
coverage tooling unless new coverage-fix evidence proves a product build flag
or debug-symbol issue outside the script.

## Handoff

Next owner: Developer for the coverage-script fix loop.

Minimum fix evidence:

1. PowerShell 7 and Windows PowerShell 5 parser checks for `run_coverage.ps1`.
2. PowerShell 7 success coverage block against the current seam-ON Release
   build with absolute paths.
3. Positive `lines-valid`, nonempty packages, and combined line coverage >=80
   percent.
4. A fail-closed negative for empty-denominator coverage output.

QA retest after fix review: run the coverage success block, then the three
remaining coverage blocks that D39-QA-13 blocked.
