# Stage 15 design: bug-fix loop -- Part 4

Source: [../cache-handling-phase15-design.md](../cache-handling-phase15-design.md)

## When the loop runs

The bug-fix loop runs when the QA report from part-2 has one or
more of:

- A `FAIL` row in any category.
- A `BLOCKED-time-budget` row that also carries a product-bug
  entry per part-3.
- A new product bug surfaced by the test suite that the
  per-row contract treats as a closure blocker (T114, T114a, T115,
  T121, E13-01..E13-16, S01..S08, L01..L03, B01..B08).
- A counter anomaly, a crash, a public-surface regression, or an
  unsafe restore that the per-row contract treats as a blocking
  defect.

The loop does not run when the only non-PASS rows are accepted
skips (e.g., `BLOCKED-pre-existing` for
`test-stage10-policy-lru`).

## Roles and order per iteration

Each iteration is a fixed four-step sequence. The same iteration
template applies to every product bug.

1. Developer fix: the Developer reads the QA report, identifies
   the symptom and the affected code path, writes a focused fix
   in the same commit, records the change in a
   `test-report-YYYYMMDD-NN-fixes.md` per D5, and updates the
   implementation log.
2. Architect review: the Architect reviews the Developer fix
   against the approved design and the affected prior-stage
   contract. The verdict is `PASS`, `PASS-with-observations`, or
   `REWORK`. A `REWORK` verdict restarts step 1 with the rework
   list; it does not advance to QA rerun.
3. QA rerun: the QA reruns the affected rows only, not the full
   test suite. The rerun uses the same configuration matrix and
   the same per-row evidence path. The QA report is a new file
   with the same D5 naming pattern, not an edit to the original
   report.
4. Developer test-results review: the Developer reviews the QA
   rerun, classifies the row as `PASS`, `FAIL`, or `BLOCKED`, and
   records the verdict in a
   `test-report-YYYYMMDD-NN-developer-review.md`. A `PASS` row
   closes the iteration for that bug. A `FAIL` or `BLOCKED` row
   restarts step 1 with the new symptom.

## Termination rule

The loop terminates when one of the following holds:

- A. The QA report shows zero product bugs and every closure
  contract row (T114, T114a, T115, T121, E13-01..E13-16, S01..S08,
  L01..L03, B01..B08) is `PASS` or `PASS-meets-intent`. The bug-fix
  loop closes with a clean report and the Manager closes the
  stage.
- B. The iteration count reaches the maximum of 3. The Developer
  escalates to the Manager with a clear plan-change decision:
  relax the affected closure contract, drop the affected row from
  the matrix, or open a new stage. The escalation records the
  date, the bug, the prior-stage contract it touches, the three
  iterations of evidence, and the proposed plan-change.
- C. A bug cannot be fixed without a prior-stage design change
  (e.g., a Stage 5 contract that the Stage 15 test suite
  revealed is no longer correct). The Developer escalates to the
  Manager with a rework part file in the affected stage's design
  tree, not in the Stage 15 design tree.

Closing with known bugs in scope is forbidden. The
`do not close stage with unmet or BLOCKED requirements` rule in
the manager improvement memory applies: a Manager plan-change
decision is required, and the decision is recorded in the test
plan or in the Manager's status, not in a reclassification of
the bug-fix loop output.

## Evidence per iteration

Each iteration records:

- A `test-report-YYYYMMDD-NN-fixes.md` per D5 with the change
  scope, the diff summary, the affected rows, the build evidence,
  the affected prior-stage contract (named in
  [part-07](part-07-exclusions-traceability-and-handoff.md)),
  and the regression evidence.
- An Architect review verdict in the same file, or in a paired
  `test-report-YYYYMMDD-NN-architect-review.md` if the review
  spans more than one bug.
- A QA rerun report in a new
  `test-report-YYYYMMDD-NN.md` with the affected rows only.
- A Developer test-results review in a
  `test-report-YYYYMMDD-NN-developer-review.md`.

A full iteration with all four artifacts is the unit of evidence.
The Manager reads the four artifacts together when deciding
whether to close the loop or to extend it.

## What the loop does not do

- The loop does not edit prior-stage design or implementation
  docs. A design change goes through the affected stage's rework
  part file, not through the Stage 15 design.
- The loop does not reclassify `FAIL` or `BLOCKED` rows to softer
  statuses to clear the closure checklist. Reclassification is
  not a fix.
- The loop does not skip the Architect review or the Developer
  test-results review. Each step is required for the iteration to
  count.
- The loop does not run the full test suite in QA rerun. Only
  the affected rows. The full test suite runs once per stage, in
  the original QA execution.

## Handoff to the benchmark report

The bug-fix loop runs in parallel with the benchmark report only
if the affected bug is in a benchmark row. The benchmark report
records the post-fix numbers; the pre-fix numbers are in the QA
report and in the bug-fix loop's evidence. The benchmark report
does not start until the bug-fix loop has closed the bug or the
Manager has recorded a plan-change decision.
