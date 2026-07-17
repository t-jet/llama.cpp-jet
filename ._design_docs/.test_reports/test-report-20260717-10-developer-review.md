# Developer review: test-report-20260717-10

Date: 2026-07-17
Reviewer: Developer agent
Input report: `._design_docs/.test_reports/test-report-20260717-10.md`
Evidence root: `._test_output/test-report-20260717-10/`
Verdict: REWORK REQUIRED

## Scope reviewed

- Manager rerun gate:
  `._design_docs/cache-handling-phase39-implementation/part-187-manager-d39-qa10-rerun-gate-20260717.md`
- QA report:
  `._design_docs/.test_reports/test-report-20260717-10.md`
- Live driver:
  `._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1`
- Canonical TP-39-03 evidence:
  `._test_output/test-report-20260717-10/TP-39-03-node/`
- Parser, build, and setup evidence:
  `._test_output/test-report-20260717-10/parser-pure/`
  and `._test_output/test-report-20260717-10/setup/`

## Classification

The canonical TP-39-03 failure is a driver assertion bug. It is not a product
bug, execution blocker, or design mismatch.

The product reached the expected natural same-owner TP-39-03 transition:

- `control-apply-response.json` has `consumed=true` and
  `pressure_completed=true`.
- `control-apply-response.json` records exact descriptor `cold`, checkpoint
  descriptor `evicted`, entry count delta `0`, node count delta `0`, and
  branch prune delta `0`.
- `control-metrics-after.txt` records one `retained_cold/cold_room`, one
  `evicted/both_filled`, and one `commit/none`.
- `control-apply-window.log` records the same production sequence:
  retained-cold exact payload, commit, then evicted checkpoint payload.
- `control-prepared-proof-retrieval.json` records terminal
  `decision_deltas` with exactly two rows:
  `retained_cold/cold_room=1` and `evicted/both_filled=1`.

The failing assertion is `Assert-ExactOutcomeS39` at
`stage39-two-layer-pressure.ps1:968-975`, called by `Assert-Tp3903` at line
`1105`. The helper checks the full
`llamacpp:cache_two_layer_decisions_total` family delta and requires it to be
exactly `1`. That is valid for rows where one decision is the whole scenario,
but it is too strict for canonical TP-39-03. TP-39-03 intentionally has two
decision-family deltas in one apply window: the exact payload is retained cold,
then the checkpoint payload is evicted as `both_filled`.

This conflicts with the TP-39-03 terminal validator already present in the same
driver. `Assert-Tp3903TerminalProofS39` requires exactly two decision deltas:
one `retained_cold/cold_room` and one `evicted/both_filled`.

## Findings

| ID | Finding | Classification | Owner | Required correction |
| --- | --- | --- | --- | --- |
| F39-QA10-01 | `Assert-Tp3903` calls `Assert-ExactOutcomeS39`, whose family-wide decision count rejects the valid paired TP-39-03 outcome `retained_cold/cold_room=1` plus `evicted/both_filled=1`. | Driver assertion bug | Developer | Add a TP-39-03-specific metrics assertion, or extend the helper with an explicit expected decision-tuple set, so TP-39-03 requires exactly those two decision rows while still requiring zero unrelated decision tuples. Keep transaction checks strict: exactly one `commit/none` for the exact cold demotion and no checkpoint cold transaction. |
| F39-QA10-02 | D39-QA-10 stopped before full `Assert-Tp3903` PASS, so the four Parts 149 and 155 coverage blocks still have no authorized evidence. | Blocked by driver assertion | QA after Developer fix and review | Rerun the D39-QA-10 order after the driver fix is reviewed: clean seam-ON Release full target build, PowerShell 7/5 parser and pure tests, one canonical TP-39-03 node, then coverage only after full `Assert-Tp3903` PASS. |

## Correction scope

Owner: Developer.

Permitted driver-only correction:

- Update `stage39-two-layer-pressure.ps1` so TP-39-03 metrics validation accepts
  exactly the natural two-decision sequence already required by terminal proof:
  `retained_cold/cold_room=1` and `evicted/both_filled=1`.
- Keep rejection for missing, duplicate, or unrelated decision tuples.
- Keep transaction validation exact: one `commit/none` cold transaction for the
  exact retained-cold payload and no checkpoint cold transaction.
- Add PowerShell 7 and Windows PowerShell 5 pure regression coverage for the
  paired TP-39-03 decision-family delta.

Out of scope for this handoff:

- Product cache code changes.
- Fixture, workload, seam, budget, threshold, route, or coverage policy changes.
- Reclassifying the expected retained-cold plus checkpoint-evicted tuple.

## Retest scope

Developer fix evidence required before QA rerun:

- PowerShell 7 parser PASS.
- Windows PowerShell 5 parser PASS.
- PowerShell 7 `-MetricValidationSelfTest` PASS.
- Windows PowerShell 5 `-MetricValidationSelfTest` PASS.
- Focused pure proof that TP-39-03 accepts exactly the two expected decision
  tuples and rejects missing, extra, or duplicate decision rows.

QA retest after Developer and Architect review:

- Repeat Manager Part 187's D39-QA-10 order without widening it.
- Use a fresh clean Release seam-ON build of the full D39-QA target set.
- Run PowerShell 7 and Windows PowerShell 5 parser/pure checks.
- Run one canonical TP-39-03 node.
- Run the four Parts 149 and 155 coverage blocks only after full
  `Assert-Tp3903` PASS.

## Handoff

Owner: Developer.

Next durable implementation record:
`._design_docs/cache-handling-phase39-implementation/part-188-developer-d39-qa10-results-review-20260717.md`.

No code was changed in this review session.
