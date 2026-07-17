# Part 197: D39-QA-12 cold inventory metadata driver fix

Date: 2026-07-17
Status: READY FOR REVIEW
Fix report: `../.test_reports/test-report-20260717-12-fixes.md`
Source review: `../.test_reports/test-report-20260717-12-developer-review.md`

## Scope

This part records the driver-only correction for F39-QA12-01. D39-QA-12 failed
after canonical TP-39-03 reached the reviewed product state but
`Assert-Tp3903` counted expected `ownership.claims` metadata as a second cold
inventory row.

No product code, fixture, workload, budget, threshold, seam, route behavior, or
coverage policy changed.

## Implementation

Changed
`._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1`.

`Assert-Tp3903FinalColdInventoryS39` now separates payload files from metadata:

- payload cardinality comes from rows matching `^[0-9a-fA-F]+\.cold$`;
- the exact payload `.cold` must be present exactly once;
- the checkpoint `.cold` and any extra payload `.cold` must be absent;
- `ownership.claims` is accepted as expected metadata;
- staging/temp, quarantine, manifest, and other unexpected cold-root files are
  rejected.

`Assert-Tp3903` still rejects owner hot candidates after apply, then calls the
new final inventory helper. The full cold-root CSV artifact remains unchanged.

## Regression coverage

`Invoke-Stage39MetricValidationSelfTestS39` now proves:

- exact payload `.cold` plus `ownership.claims` passes;
- checkpoint `.cold`, extra payload `.cold`, staging/temp, quarantine,
  manifest, and unexpected root files fail.

These are pure PowerShell tests and do not start the model.

## Evidence

| Check | Result |
| --- | --- |
| PowerShell 7 parser | PASS |
| Windows PowerShell 5 parser | PASS |
| PowerShell 7 `-MetricValidationSelfTest` | PASS |
| Windows PowerShell 5 `-MetricValidationSelfTest` | PASS |

The self-test output in both shells reported `Outcome : PASS`,
`Tp3903Roles : {source, incoming}`, and `Tp3903Lengths : {721, 723}`.

## Not run

The TP-39-03 model node and coverage blocks were not run. This matches the
fix-loop instruction and leaves QA rerun order unchanged.

## Handoff

Ready for driver-fix review. If accepted, Manager can open the next QA rerun
using the D39-QA-12 order: fresh clean seam-ON Release build, PowerShell 7/5
parser and pure gates, one canonical TP-39-03 node, then coverage only after
full `Assert-Tp3903` PASS.
