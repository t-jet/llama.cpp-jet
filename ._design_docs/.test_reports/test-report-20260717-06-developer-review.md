# Developer review: Stage 39 D39-QA-06

Date: 2026-07-17
Verdict: REWORK REQUIRED
Source: `test-report-20260717-06.md`

## Classification

| Item | Classification | Owner | Next action |
| --- | --- | --- | --- |
| TP-39-03 terminal `forbidden_effects` map | Driver contract defect | Developer | Accept and assert the three reviewed zero-valued component fields. |
| Product terminal proof | No product defect established | None | Preserve current pressure, retention, accounting, and terminal proof behavior. |
| Coverage | Deliberate fail-fast deferral | QA after Manager authorization | Run four coverage blocks only after full TP-39-03 PASS. |

Report 06 is a driver contract defect, not a product defect and not an
execution blocker. Execution reached the authenticated terminal proof. The
driver then rejected production's field set before `Assert-Tp3903` value
comparison because `stage39-two-layer-pressure.ps1:431-439` still expects 15
`forbidden_effects` fields.

## Evidence reviewed

Document-index Stage 39 row 232 classifies report 06 as `FAIL-driver-contract`.
Part 168 accepts the three production-hook counters: checkpoint, pressure, and
diagnostic negatives each hit its named production helper, isolate sibling
deltas, and reject terminal proof when nonzero. Part 169 authorized one fresh
canonical TP-39-03 node and kept coverage unopened unless `Assert-Tp3903`
passed.

The QA diagnosis records:

- expected field count: 15
- actual field count: 18
- unexpected fields: `later_kind_work_delta`, `post_abort_pressure_delta`,
  `post_abort_diagnostic_delta`
- each unexpected value: `0`
- `aggregate_later_work_delta`: `0`
- all 15 expected values matched

Those three fields are not stray product output. They are the component counters
from the Part 168 correction. The live proof also has the accepted TP-39-03
outcome: exact retained cold, checkpoint evicted as `both_filled`, one
`commit/none`, zero entry/node/prune deltas, signed LRU delta `-1`, no later
work, and coherent cold/file accounting.

## Required correction and retest

Developer owns the driver contract correction in
`cache-handling-test-scripts/stage39-two-layer-pressure.ps1`: extend the exact
`effectExpected` map to include `later_kind_work_delta=0`,
`post_abort_pressure_delta=0`, and `post_abort_diagnostic_delta=0`. Keep exact
field-set validation and zero-value assertions. Do not weaken the guard into a
subset check.

Add or update pure PowerShell coverage so stale 15-field contracts fail and the
18-field terminal map passes under both PowerShell 7 and Windows PowerShell 5.
The fix must not change product code, fixture, budgets, seams, caps, stage plan,
or coverage thresholds.

Retest scope after correction:

- PowerShell 7 parser API and pure self-test
- Windows PowerShell 5 parser API and pure self-test
- focused evidence for the field-map negative and positive cases
- fresh Architect review
- Manager-authorized canonical TP-39-03 rerun from a clean Release seam-ON build
- only after full `Assert-Tp3903` PASS, the four Part 149/155 coverage blocks

No fix, build, model run, test run, or coverage command ran during this review.
