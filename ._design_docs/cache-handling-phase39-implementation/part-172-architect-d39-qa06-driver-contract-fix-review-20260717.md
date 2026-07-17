# Part 172: Architect D39-QA-06 driver contract fix review

Date: 2026-07-17
Status: PASS
Scope: D39-QA-06 driver-only correction in Part 171 and `stage39-two-layer-pressure.ps1`

## Verdict

PASS. The driver now accepts and verifies the three reviewed zero-valued
component fields from Part 168:

- `later_kind_work_delta=0`
- `post_abort_pressure_delta=0`
- `post_abort_diagnostic_delta=0`

The correction is limited to the PowerShell driver contract and pure terminal
fixture. I found no product-code, fixture, workload, budget, seam, cap, stage
plan, or coverage-threshold change in the reviewed scope.

## Review checks

The canonical TP-39-03 terminal proof assertion now builds an 18-field
`effectExpected` map. It includes the older forbidden-effect fields plus the
three Part 168 component counters. `Test-PropertySetS39` still requires exact
property-set equality by count and expected-name membership, so a missing field
or unexpected extra field fails before value acceptance. The value loop still
requires every expected field to equal its exact integer value, so a nonzero
component counter fails.

The pure terminal fixture uses the same 18-field `forbidden_effects` map. The
negative matrix covers each new component field set to `1`, each new component
field missing, the stale 15-field shape with all three component fields removed,
and an unexpected extra zero-valued field. Those cases preserve the exact
property-set guard requested by Part 170.

The D39-QA-06 reports are consistent with the correction:

- Report 06 failed before value comparison because production returned 18 fields
  and the driver still expected 15.
- Developer review and Part 170 correctly classify this as a driver contract
  defect, not a product defect.
- The fixes report and Part 171 keep coverage unopened until a later
  model-backed `Assert-Tp3903` pass.

## Evidence rechecked

I reran the pure matrix from the current workspace:

| Check | Result |
| --- | --- |
| PowerShell 7 parser API | PASS, exit 0 |
| Windows PowerShell 5 parser API | PASS, exit 0 |
| PowerShell 7 `-MetricValidationSelfTest` | PASS, exit 0 |
| Windows PowerShell 5 `-MetricValidationSelfTest` | PASS, exit 0 |

My first parser command used quoting that let the outer shell expand `$tokens`
and `$errors`; it failed before parsing the script. The corrected quoted parser
commands passed in both shells, matching the fixes report's explanation.

No model, build, product test, or coverage command ran during this review.

## Handoff

Architect review passes. Manager may decide whether to authorize one fresh
canonical TP-39-03 rerun. Coverage remains blocked until that rerun reaches full
`Assert-Tp3903` PASS.
