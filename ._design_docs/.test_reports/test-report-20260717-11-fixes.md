# D39-QA-11 fix report

Date: 2026-07-17
Status: READY FOR REVIEW
Input report: `test-report-20260717-11.md`
Developer review: `test-report-20260717-11-developer-review.md`
Implementation part: `../cache-handling-phase39-implementation/part-193-d39-qa11-descriptor-delta-driver-fix-20260717.md`

## Scope

F39-QA11-01 is a driver-only correction in
`../cache-handling-test-scripts/stage39-two-layer-pressure.ps1`.

The TP-39-03 descriptor and residency metric deltas must be:

| Metric | Required delta |
| --- | ---: |
| `llamacpp:cache_evicted_payload_descriptors{mode="hybrid"}` | `+1` |
| `llamacpp:cache_payload_evictions_total{mode="hybrid"}` | `+1` |
| `llamacpp:cache_hot_payload_descriptors{mode="hybrid"}` | `-2` |
| `llamacpp:cache_cold_payload_count{mode="hybrid"}` | `+1` |

Out of scope: product code, fixture, workload, budgets, thresholds, seam,
coverage policy, and model-backed TP-39-03 execution.

## Plan

1. Update `Assert-Tp3903` descriptor/residency deltas to `+1/+1/-2/+1`.
2. Update the pure TP-39-03 metric fixture so `-MetricValidationSelfTest`
   accepts the corrected tuple.
3. Add pure negatives that reject stale `+1/+1/-1/0` expectations and malformed
   descriptor/residency deltas.
4. Run PowerShell 7 and Windows PowerShell 5 parser checks.
5. Run PowerShell 7 and Windows PowerShell 5 `-MetricValidationSelfTest`.

## Progress

- 2026-07-17: Planned the driver-only correction from QA report -11 and the
  Developer review. Code changes are limited to TP-39-03 metric validation in
  `stage39-two-layer-pressure.ps1`.
- 2026-07-17: Updated `Assert-Tp3903` to require descriptor/residency deltas
  `+1/+1/-2/+1`.
- 2026-07-17: Updated the pure TP-39-03 metric fixture and added negatives for
  stale `+1/+1/-1/0`, wrong evicted descriptor count, wrong payload eviction
  count, malformed hot descriptor delta, and malformed cold payload count.

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

Both self-test runs returned `Outcome : PASS`. No TP-39-03 model execution or
coverage run was performed in this fix session.
