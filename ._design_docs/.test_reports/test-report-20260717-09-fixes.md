# Fix report: test-report-20260717-09

Date: 2026-07-17
Owner: Developer agent
Source report: `test-report-20260717-09.md`
Developer review: `test-report-20260717-09-developer-review.md`
Implementation part: `../cache-handling-phase39-implementation/part-185-d39-qa09-empty-cold-inventory-fix-20260717.md`
Status: FIX APPLIED, READY FOR REVIEW

## Scope

D39-QA-09 failed in the TP-39-03 PowerShell driver after product evidence
reached the expected retained-cold plus checkpoint-evicted tuple. This fix is
driver-only. It changes no product code, fixture, workload, budget, threshold,
seam, or coverage policy.

## Root cause

`control-cold-files-before.csv` was header-only. `Import-Csv` returns `$null`
for that file. In PowerShell 7, binding that value into a typed `[object[]]`
parameter can make `@($ColdBefore).Count` equal `1` inside `Assert-Tp3903`.
The assertion treated that typed null placeholder as a real cold inventory row.

## Changes

- `Get-ColdInventoryS39` now returns a stable empty object array when no cold
  files exist.
- `Normalize-ColdInventoryS39` removes typed null placeholders at producer,
  writer, and assertion boundaries.
- `Assert-Tp3903` now checks real `.cold` rows for the pre-apply empty
  inventory requirement instead of counting raw typed parameter elements.
- Pure self-test coverage now exercises header-only `Import-Csv`, explicit
  `$null`, and a typed `ColdAfter` value containing a null placeholder through
  `Assert-Tp3903`.

## Evidence

Commands run:

```powershell
pwsh -NoProfile -Command '$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile("._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1", [ref]$tokens, [ref]$errors) | Out-Null; if ($errors.Count) { $errors | ForEach-Object { $_.ToString() }; exit 1 }; "parser ok"'

powershell -NoProfile -Command '$tokens=$null; $errors=$null; [System.Management.Automation.Language.Parser]::ParseFile("._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1", [ref]$tokens, [ref]$errors) | Out-Null; if ($errors.Count) { $errors | ForEach-Object { $_.ToString() }; exit 1 }; "parser ok"'

pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1 `
  -ModelPath ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf `
  -MetricValidationSelfTest

powershell -NoProfile -File ._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1 `
  -ModelPath ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf `
  -MetricValidationSelfTest
```

Results:

- PowerShell 7 parser: PASS
- Windows PowerShell 5 parser: PASS
- PowerShell 7 `-MetricValidationSelfTest`: PASS
- Windows PowerShell 5 `-MetricValidationSelfTest`: PASS

Not run:

- TP-39-03 model node
- coverage blocks
- product build or product tests

## Handoff

Developer correction is ready for review. QA retest should keep the Part 183
order: clean seam-ON Release full target build, PowerShell 7/5 parser and pure
checks, one canonical TP-39-03 node, then coverage only after full
`Assert-Tp3903` PASS.
