# Part 171: TP-39-03 forbidden-effects driver contract fix

Date: 2026-07-17
Status: ACCEPTED BY PART 172
Scope: D39-QA-06 driver-only correction

## Summary

D39-QA-06 reached the authenticated TP-39-03 terminal proof and then failed in
the PowerShell driver. Production returned the three component counters accepted
by Part 168: `later_kind_work_delta`, `post_abort_pressure_delta`, and
`post_abort_diagnostic_delta`. All three were zero. The canonical driver still
expected the older 15-field `forbidden_effects` map, so it rejected the proof
before value comparison.

This part records the driver fix. Product code, fixture, workload, budgets,
seams, caps, plans, and coverage thresholds did not change.

## Changes

- `stage39-two-layer-pressure.ps1` now includes all three reviewed component
  fields in the TP-39-03 `effectExpected` map with value `0`.
- The pure terminal fixture now uses the same 18-field `forbidden_effects` map
  as the reviewed production proof.
- The pure terminal negative matrix rejects:
  - each new component field when set to `1`;
  - each new component field when missing;
  - the stale 15-field map when all three new component fields are missing;
  - one unexpected extra field with value `0`.

The exact property-set guard stays in place. The driver still fails closed for
missing fields, extra fields, and nonzero forbidden effects.

## Evidence

| Check | Result |
| --- | --- |
| PowerShell 7 parser API | PASS, exit 0 |
| Windows PowerShell 5 parser API | PASS, exit 0 |
| PowerShell 7 `-MetricValidationSelfTest` | PASS, exit 0 |
| Windows PowerShell 5 `-MetricValidationSelfTest` | PASS, exit 0 |

No model, build, or coverage command ran.

## Handoff

Architect review PASS is recorded in Part 172. A Manager gate is still required
before another canonical TP-39-03 model-backed rerun. Coverage remains blocked
until `Assert-Tp3903` passes in that rerun.
