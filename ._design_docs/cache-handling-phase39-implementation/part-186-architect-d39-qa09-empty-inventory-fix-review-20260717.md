# Part 186: Architect D39-QA-09 empty inventory fix review

Date: 2026-07-17
Verdict: PASS
Related QA report: `../.test_reports/test-report-20260717-09.md`
Developer review: `part-184-developer-d39-qa09-results-review-20260717.md`
Fix record: `part-185-d39-qa09-empty-cold-inventory-fix-20260717.md`
Script reviewed: `../cache-handling-test-scripts/stage39-two-layer-pressure.ps1`

## Scope

This review covers the D39-QA-09 driver-only fix for the TP-39-03 cold-empty
assertion failure. Product code, fixture choice, workload content, budgets,
thresholds, seam behavior, and coverage policy were not changed in this review.

## Decision

The correction is acceptable. D39-QA-09 failed after the product reached the
expected retained-cold plus checkpoint-evicted tuple, and the failing condition
was the driver counting a typed null cold-inventory placeholder as one row.
The current driver normalizes empty inventories at the producer, writer, common
assertion, and TP-39-02/03/04 assertion boundaries.

Key checks:

- `Get-ColdInventoryS39` returns an empty object array when no files exist.
- `Normalize-ColdInventoryS39` maps `$null` and typed null placeholders to zero
  rows.
- `Write-ColdInventoryS39` writes a header-only CSV for zero rows and normalizes
  before deciding whether rows exist.
- `Assert-Tp3903` now proves cold-empty setup by counting real
  `^[0-9a-fA-F]+\.cold$` rows, not raw `[object[]]` elements.
- `Assert-Tp3903` still keeps the final exact state strict: one exact `.cold`
  row must exist, the checkpoint `.cold` row must not exist, and the normalized
  final inventory must contain exactly one row.
- `Assert-ControlCommonS39`, `Assert-Tp3902`, and `Assert-Tp3904` normalize
  their cold inventories before file-count, byte-accounting, and retained-file
  checks, so the same typed-null bug is not left in neighboring cold-inventory
  assertions.

The pure regression path is sufficient for this driver-only fix. The self-test
writes and imports a header-only cold inventory, passes that value through
`Assert-Tp3903`, repeats with explicit `$null` `ColdBefore`, and passes a
`ColdAfter` value that contains a null placeholder plus the expected exact
`.cold` row. It also checks the common zero-cold assertion path with a
header-only `ColdAfter`.

## Evidence checked

I reran the local parser and pure gates:

| Command | Result |
| --- | --- |
| PowerShell 7 parser `Parser.ParseFile(...)` | PASS |
| Windows PowerShell 5 parser `Parser.ParseFile(...)` | PASS |
| PowerShell 7 `-MetricValidationSelfTest` | PASS |
| Windows PowerShell 5 `-MetricValidationSelfTest` | PASS |

No model node, product build, or coverage block is required for this review
because the correction is limited to the PowerShell driver and pure assertion
coverage. QA still must rerun the D39-QA-09 order before coverage can open.

## Findings

No blocking findings.

## Handoff

D39-QA-09 empty cold-inventory driver fix is approved. QA may rerun the Part
183 gate order: fresh clean Release seam-ON full target build, PowerShell 7 and
Windows PowerShell 5 parser/pure checks, one canonical TP-39-03 node, then the
four coverage blocks only after full `Assert-Tp3903` PASS.
