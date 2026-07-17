# Part 185: D39-QA-09 empty cold inventory fix

Date: 2026-07-17
Status: FIX APPLIED, READY FOR REVIEW
Related QA report: `../.test_reports/test-report-20260717-09.md`
Developer review: `../.test_reports/test-report-20260717-09-developer-review.md`
Fix report: `../.test_reports/test-report-20260717-09-fixes.md`

## Scope

Part 184 classified D39-QA-09 as a driver assertion bug in
`stage39-two-layer-pressure.ps1`. The fix is limited to cold inventory
normalization and pure regression coverage. Product code, fixture, workload,
budgets, thresholds, seam behavior, and coverage policy are unchanged.

## Changes

- Added `Normalize-ColdInventoryS39` to convert `$null` and typed null
  placeholders into a real empty object array.
- Changed `Get-ColdInventoryS39` to preserve an empty array result across the
  function return boundary.
- Normalized cold inventories before CSV writing, control captures, summary
  accounting, and TP-39-02/03/04 assertion use.
- Changed the TP-39-03 cold-empty setup check to count actual `.cold` inventory
  rows.
- Added pure regression coverage for header-only `Import-Csv`, explicit `$null`
  `ColdBefore`, and `ColdAfter` with a typed null placeholder through
  `Assert-Tp3903`.

## Evidence

Commands and results:

| Command | Result |
| --- | --- |
| `pwsh -NoProfile -Command ... Parser.ParseFile(...)` | PASS |
| `powershell -NoProfile -Command ... Parser.ParseFile(...)` | PASS |
| `pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1 -ModelPath ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf -MetricValidationSelfTest` | PASS |
| `powershell -NoProfile -File ._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1 -ModelPath ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf -MetricValidationSelfTest` | PASS |

Notes:

- The self-test now passes `Assert-Tp3903` with a header-only imported
  `ColdBefore`, then with explicit `$null` `ColdBefore`.
- The same path passes `ColdAfter` as an array containing a null placeholder and
  the expected exact `.cold` row.
- A separate common assertion check proves header-only `ColdAfter` normalizes to
  an empty inventory when metrics also describe zero cold bytes.
- TP-39-03 model execution and coverage were deliberately not run.

## Handoff

Developer correction is ready for Architect review. QA should rerun only the
Part 183 gate order after review approval; coverage remains blocked until
canonical TP-39-03 reaches full `Assert-Tp3903` PASS.
