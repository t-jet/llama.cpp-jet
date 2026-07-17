# Part 188: Developer D39-QA-10 results review

Date: 2026-07-17
Status: REWORK REQUIRED
Input report: `../.test_reports/test-report-20260717-10.md`
Developer review: `../.test_reports/test-report-20260717-10-developer-review.md`

## Scope

Manager Part 187 authorized D39-QA-10: fresh clean Release seam-ON full target
build, PowerShell 7 and Windows PowerShell 5 parser and pure checks, one
canonical TP-39-03 node, then four coverage blocks only after full
`Assert-Tp3903` PASS.

QA completed the build and shell gates. The canonical TP-39-03 node failed in
the PowerShell driver before coverage could open. This part records Developer
classification only. No product code, driver code, fixture, workload, budget,
threshold, seam, coverage policy, commit, push, PR, or reviewer response was
changed.

## Evidence reviewed

- `._design_docs/cache-handling-phase39-implementation/part-187-manager-d39-qa10-rerun-gate-20260717.md`
- `._design_docs/.test_reports/test-report-20260717-10.md`
- `._test_output/test-report-20260717-10/setup/`
- `._test_output/test-report-20260717-10/parser-pure/`
- `._test_output/test-report-20260717-10/TP-39-03-node/`
- `._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1`
  around `Assert-ExactOutcomeS39` and `Assert-Tp3903`

## Classification

F39-QA10-01 is a driver assertion bug.

The product reached the canonical TP-39-03 state:

- guarded apply consumed the request and completed pressure;
- exact descriptor ended cold and checkpoint descriptor ended evicted;
- topology deltas for entries, nodes, and branch pruning stayed zero;
- final cold inventory contains one exact `.cold` file;
- metrics and apply-window logs recorded one `retained_cold/cold_room`, one
  `evicted/both_filled`, and one `commit/none`;
- terminal proof recorded exactly those two decision deltas and the single
  commit transaction.

`Assert-ExactOutcomeS39` is too narrow for TP-39-03. It requires the whole
`llamacpp:cache_two_layer_decisions_total` family delta to be `1` while checking
`evicted/both_filled`. Canonical TP-39-03 has two valid decision-family deltas:
the exact payload is retained cold, then the checkpoint payload is evicted as
`both_filled`.

This is not a product bug, execution blocker, or design mismatch. The same
driver's terminal proof assertion already requires the paired
`retained_cold/cold_room` plus `evicted/both_filled` outcome.

## Required correction

Owner: Developer.

Correct only the PowerShell driver assertion path:

1. Add a TP-39-03-specific metrics assertion, or extend
   `Assert-ExactOutcomeS39` with an explicit expected decision-tuple set.
2. Require exactly:
   - `retained_cold/cold_room=1`;
   - `evicted/both_filled=1`;
   - no unrelated decision tuples.
3. Keep cold transaction validation exact:
   - `commit/none=1`;
   - no extra cold transaction tuples.
4. Add PowerShell 7 and Windows PowerShell 5 pure coverage for paired
   TP-39-03 decision deltas, including negatives for missing, extra, and
   duplicate decision rows.

Product cache code, fixture, workload, seam, budget, threshold, route behavior,
and coverage policy stay out of scope.

## Retest scope

Developer fix evidence before QA rerun:

- PowerShell 7 parser PASS.
- Windows PowerShell 5 parser PASS.
- PowerShell 7 `-MetricValidationSelfTest` PASS.
- Windows PowerShell 5 `-MetricValidationSelfTest` PASS.
- Focused pure evidence that the TP-39-03 paired decision assertion accepts the
  exact expected tuple set and rejects malformed tuple sets.

QA retest after Developer fix review:

- Repeat Manager Part 187's D39-QA-10 order.
- Start from a fresh clean Release seam-ON full target build.
- Run PowerShell 7 and Windows PowerShell 5 parser/pure gates.
- Run one canonical TP-39-03 node.
- Run the four Parts 149 and 155 coverage blocks only after full
  `Assert-Tp3903` PASS.

## Handoff

Next owner: Developer for the driver-only assertion correction.

Coverage remains blocked until canonical TP-39-03 reaches full
`Assert-Tp3903` PASS under the Manager-authorized order.
