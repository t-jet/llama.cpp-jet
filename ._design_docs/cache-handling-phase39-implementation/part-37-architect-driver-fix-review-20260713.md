# Stage 39 Architect driver fix review

Date: 2026-07-13
Verdict: PASS
Finding: F39-QA4-01 CLOSED

## Scope

Reviewed only the canonical Stage 39 driver correction recorded in Part 36 and
`test-report-20260712-04-fixes.md`. Product code, test-plan policy, QA results,
coverage, and live workload calibration were outside this review.

## Review result

The correction is safe and narrow. `Assert-Stage39MetricRowsS39` now applies the
zero-row rule before parsing metric rows. `hot-zero` and `legacy` return only
when both Stage 39 families are absent, and they reject any emitted row.

Other scenarios still validate each non-null row. The helper rejects malformed
rows, malformed labels, and duplicate label names. Valid nonempty decision and
transaction rows pass.

The live path extracts both metric families, calls the helper, then applies the
existing scenario checks. The `standard` checks still require a positive cold
restore, promotion, accepted retention reason, committed transaction, zero
payload-eviction delta, and zero pruning delta. The `both-filled`,
`oversized-both`, and `cold-disabled` tuple guards are unchanged.

`-MetricValidationSelfTest` is handled before model-path and server-path
preflight. It therefore needs neither a model nor a server. The script keeps
`#requires -Version 5` syntax and runs under Windows PowerShell 5 and
PowerShell 7.

## Verification

| Check | Result |
| --- | --- |
| PowerShell AST parse | PASS |
| Built-in self-test, Windows PowerShell 5 | PASS, exit 0 |
| Built-in self-test, PowerShell 7 | PASS, exit 0 |
| Reviewer rejection probes, Windows PowerShell 5 | PASS |
| Reviewer rejection probes, PowerShell 7 | PASS |
| Valid nonempty decision and transaction rows | PASS |
| Emitted row in `hot-zero` | Rejected |
| Malformed row | Rejected |
| Malformed label | Rejected |
| Duplicate label name | Rejected |
| Standard and named scenario guards | Preserved |
| Product or test-plan drift | None |

The reviewer probes dot-sourced the canonical driver in self-test mode, then
called its validation helper with the listed positive and negative cases. No
model-backed QA row was run.

## Gate

F39-QA4-01 is closed. QA may rerun `hot-zero` and `legacy` through the corrected
driver. QA still owns the canonical coverage run and TP-39-02 through TP-39-04
calibration. This PASS does not change those open blockers or authorize Stage 39
closure.
