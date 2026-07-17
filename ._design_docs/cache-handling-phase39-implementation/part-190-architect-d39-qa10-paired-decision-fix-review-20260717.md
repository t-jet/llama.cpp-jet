# Part 190: Architect D39-QA-10 paired-decision fix review

Date: 2026-07-17
Status: PASS
Input report: `../.test_reports/test-report-20260717-10.md`
Developer review: `../.test_reports/test-report-20260717-10-developer-review.md`
Fix report: `../.test_reports/test-report-20260717-10-fixes.md`
Implementation part: `part-189-d39-qa10-paired-decision-driver-fix-20260717.md`

## Scope and gate status

Reviewed F39-QA10-01 only. The fix stays in the PowerShell driver:

- `._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1`

No product cache code, C++ test target, fixture, workload, budget, threshold,
seam, route behavior, or coverage policy is changed by this fix. Existing dirty
product and test files are outside this review scope.

Gate status: PASS. Manager may open the next D39-QA-10 rerun using the Part 187
order.

## Findings and decisions

No blocking findings.

The correction matches the QA failure and Developer classification. TP-39-03 no
longer uses the one-decision `Assert-ExactOutcomeS39` path. It now calls:

- `Assert-Tp3903OutcomeS39`, which requires exactly
  `retained_cold/cold_room=1` plus `evicted/both_filled=1`;
- `Assert-Tp3903ApplyLogS39`, which requires the same paired apply-window
  decision logs and one `commit/none` transaction log.

Cold transaction validation remains strict: `commit/none=1` and no extra
transaction tuple. The metric helper checks the whole decision and transaction
families, so missing, extra, duplicate, or wrong tuples fail instead of being
masked by a matching positive row.

TP-39-02 and TP-39-04 still call `Assert-ExactOutcomeS39` and keep their strict
one-decision contracts. That preserves `retained_cold/cold_room_made` for
TP-39-02 and `evicted/oversized_both` with zero transactions for TP-39-04.

The TP-39-03 apply-window log check is equally strict: exactly two decision
lines with the exact and checkpoint payload ids, plus exactly one identified
`commit/none` transaction line.

## Evidence

Local verification passed:

```text
pwsh parser: PASS
powershell parser: PASS
pwsh -MetricValidationSelfTest: PASS
powershell -MetricValidationSelfTest: PASS
```

The pure self-test covers the expected paired TP-39-03 metrics and rejects
missing retained-cold, missing evicted, duplicate evicted, extra unrelated,
wrong retained-cold reason, and missing commit cases. Parser coverage in both
shells is sufficient for this driver-only review.

## Required corrections

None for this gate.

## Handoff

Ready for Manager rerun gate. QA should repeat the Part 187 order: clean
seam-ON Release full target build, PowerShell 7/5 parser and pure checks, one
canonical TP-39-03 node, then Parts 149 and 155 coverage blocks only after full
`Assert-Tp3903` PASS.
