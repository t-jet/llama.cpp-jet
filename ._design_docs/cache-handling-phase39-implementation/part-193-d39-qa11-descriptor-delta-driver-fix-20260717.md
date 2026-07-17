# Part 193: D39-QA-11 descriptor delta driver fix

Date: 2026-07-17
Status: READY FOR REVIEW
Fix report: `../.test_reports/test-report-20260717-11-fixes.md`

## Scope

This part implements the D39-QA-11 Developer-review correction for F39-QA11-01.
The change is driver-only: TP-39-03 now expects descriptor/residency metric
deltas that match the current same-owner exact-cold/checkpoint-evicted contract.

No product code, fixture, workload, budgets, thresholds, seam, or coverage
policy changes are in scope.

## Implementation plan

1. Change `Assert-Tp3903` to require evicted descriptor `+1`, payload eviction
   `+1`, hot descriptors `-2`, and cold payload count `+1`.
2. Update the pure self-test fixture to model the corrected TP-39-03 metric
   deltas.
3. Add pure negatives for stale `+1/+1/-1/0` expectations and malformed
   descriptor/residency deltas.
4. Validate PowerShell 7 and Windows PowerShell 5 parser checks plus
   `-MetricValidationSelfTest`.

## Progress

- 2026-07-17: Created this implementation part and paired fix report before
  editing the driver.
- 2026-07-17: Changed `Assert-Tp3903` so the accepted TP-39-03 metric deltas are
  evicted descriptors `+1`, payload evictions `+1`, hot descriptors `-2`, and
  cold payload count `+1`.
- 2026-07-17: Updated the pure TP-39-03 metric fixture from stale
  `+1/+1/-1/0` to `+1/+1/-2/+1`.
- 2026-07-17: Added pure negative coverage that rejects stale
  `+1/+1/-1/0` and malformed descriptor/residency deltas.

## Evidence

| Check | Result |
| --- | --- |
| PowerShell 7 parser | PASS |
| Windows PowerShell 5 parser | PASS |
| PowerShell 7 `-MetricValidationSelfTest` | PASS |
| Windows PowerShell 5 `-MetricValidationSelfTest` | PASS |

Commands run:

```powershell
pwsh -NoProfile -Command '$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile(''.\._design_docs\cache-handling-test-scripts\stage39-two-layer-pressure.ps1'', [ref]$tokens, [ref]$errors) > $null; if ($errors.Count) { $errors | ForEach-Object { $_.ToString() }; exit 1 }'
powershell -NoProfile -Command '$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile(''.\._design_docs\cache-handling-test-scripts\stage39-two-layer-pressure.ps1'', [ref]$tokens, [ref]$errors) > $null; if ($errors.Count) { $errors | ForEach-Object { $_.ToString() }; exit 1 }'
pwsh -NoProfile -File .\._design_docs\cache-handling-test-scripts\stage39-two-layer-pressure.ps1 -ModelPath .\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf -MetricValidationSelfTest
powershell -NoProfile -File .\._design_docs\cache-handling-test-scripts\stage39-two-layer-pressure.ps1 -ModelPath .\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf -MetricValidationSelfTest
```

Both self-test runs returned `Outcome : PASS`.

No product code changed. TP-39-03 model execution and coverage were not run,
per the D39-QA-11 fix-loop scope.
