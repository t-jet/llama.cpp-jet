# Part 189: D39-QA-10 paired-decision driver fix

Date: 2026-07-17
Status: FIX REVIEW PASS
Input report: `../.test_reports/test-report-20260717-10.md`
Fix report: `../.test_reports/test-report-20260717-10-fixes.md`
Developer review: `../.test_reports/test-report-20260717-10-developer-review.md`

## Scope

F39-QA10-01 is a PowerShell driver assertion defect. This part records the
driver-only correction.

Changed:

- `._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1`

Unchanged:

- product code;
- fixture, workload, budgets, thresholds, route behavior, seam behavior, and
  coverage policy;
- TP-39-02 and TP-39-04 exact one-decision metric expectations.

## Implementation

`Assert-ExactOutcomeS39` remains unchanged for rows where one decision tuple is
the complete scenario result.

TP-39-03 now uses dedicated validators:

- `Assert-Tp3903OutcomeS39` requires exactly two decision-family deltas:
  `retained_cold/cold_room=1` and `evicted/both_filled=1`.
- The same helper requires exactly one cold transaction delta:
  `commit/none=1`.
- `Assert-Tp3903ApplyLogS39` requires matching paired apply-window decision logs
  and one `commit/none` transaction log.

`Assert-Tp3903` calls the TP-39-03-specific helpers. That aligns the metrics
assertion with the terminal proof validator already requiring the same paired
decision set.

## Regression coverage

`Invoke-Stage39MetricValidationSelfTestS39` now proves:

- the paired TP-39-03 decision set passes;
- missing retained-cold, missing evicted, duplicate evicted, extra unrelated,
  wrong retained-cold reason, and missing commit tuples fail;
- the TP-39-03 apply-window log validator accepts only the paired decision logs
  plus the single transaction log.

The existing TP-39-02 and TP-39-04 pure checks still call
`Assert-ExactOutcomeS39`.

## Evidence

Commands run:

```text
pwsh -NoProfile -Command '$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile(''._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1'', [ref]$tokens, [ref]$errors) > $null; if ($errors.Count) { $errors | Format-List *; exit 1 }'
powershell -NoProfile -Command '$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile(''._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1'', [ref]$tokens, [ref]$errors) > $null; if ($errors.Count) { $errors | Format-List *; exit 1 }'
pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1 -ModelPath ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf -MetricValidationSelfTest
powershell -NoProfile -File ._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1 -ModelPath ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf -MetricValidationSelfTest
```

Results:

| Check | Result |
| --- | --- |
| PowerShell 7 parser | PASS |
| Windows PowerShell 5 parser | PASS |
| PowerShell 7 `-MetricValidationSelfTest` | PASS |
| Windows PowerShell 5 `-MetricValidationSelfTest` | PASS |

The pure self-test returns `Outcome : PASS` in both shells.

## Deferred work

Per the requested scope, no TP-39-03 model run and no coverage block ran in this
session. Part 190 records Architect PASS; Manager rerun gate is next.
