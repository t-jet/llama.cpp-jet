# Stage 39 D39-QA-06 fixes

Date: 2026-07-17
Status: ACCEPTED BY ARCHITECT PART 172
Source report: `test-report-20260717-06.md`
Developer review: `test-report-20260717-06-developer-review.md`

## Scope

Report 06 failed in the canonical TP-39-03 PowerShell driver. Production
returned the three reviewed component counters from Part 168:
`later_kind_work_delta`, `post_abort_pressure_delta`, and
`post_abort_diagnostic_delta`. Each value was zero. The driver still expected
the older 15-field `forbidden_effects` map and rejected the proof at the exact
property-set check before value comparison.

This fix is driver-only. Product code, fixture, workload, budgets, seams, caps,
stage plan, and coverage thresholds stay unchanged.

## Plan

1. Extend the canonical TP-39-03 `effectExpected` map to include the three
   reviewed zero-valued component fields.
2. Update the pure terminal fixture so the valid 18-field map passes.
3. Add strict pure negatives for missing component fields, nonzero component
   fields, and an unexpected extra field.
4. Run PowerShell 7 and Windows PowerShell 5 parser API checks and
   `-MetricValidationSelfTest`.
5. Record evidence here and in the durable Stage 39 implementation part.

## Progress

- Started driver-only correction from Developer Part 170.
- Updated `cache-handling-test-scripts/stage39-two-layer-pressure.ps1` so the
  canonical TP-39-03 `effectExpected` map accepts and verifies these three
  zero-valued fields:
  `later_kind_work_delta`, `post_abort_pressure_delta`, and
  `post_abort_diagnostic_delta`.
- Updated the embedded valid terminal fixture to use the same 18-field
  contract as the live terminal proof.
- Added pure negatives proving that each new component field fails when
  nonzero, each fails when missing, and an unexpected extra field fails the
  exact property-set guard.
- Added an explicit stale 15-field negative by removing all three component
  fields together.

## Evidence

| Check | Result |
| --- | --- |
| PowerShell 7 parser API | PASS, exit 0 |
| Windows PowerShell 5 parser API | PASS, exit 0 |
| PowerShell 7 `-MetricValidationSelfTest` | PASS, exit 0 |
| Windows PowerShell 5 `-MetricValidationSelfTest` | PASS, exit 0 |

The first parser command attempt failed because the outer PowerShell command
expanded `$tokens` and `$errors` before invoking the inner shell. It did not
parse the script. The corrected quoted parser commands above passed in both
shells. After adding the explicit stale 15-field negative, the full parser and
pure matrix was rerun and passed again in both shells.

No model, build, or coverage command ran.

## Handoff

Architect Part 172 accepts the driver correction. The next Manager gate should
decide whether to authorize a fresh canonical TP-39-03 rerun. Coverage remains
blocked until full `Assert-Tp3903` PASS.
