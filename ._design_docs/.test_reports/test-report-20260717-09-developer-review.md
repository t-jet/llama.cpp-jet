# Developer review: test-report-20260717-09

Date: 2026-07-17
Reviewer: Developer agent
Input report: `._design_docs/.test_reports/test-report-20260717-09.md`
Evidence root: `._test_output/test-report-20260717-09/`
Verdict: REWORK REQUIRED

## Scope reviewed

- Manager rerun gate:
  `._design_docs/cache-handling-phase39-implementation/part-183-manager-d39-qa09-rerun-gate-20260717.md`
- QA report:
  `._design_docs/.test_reports/test-report-20260717-09.md`
- Live driver:
  `._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1`
- Canonical TP-39-03 evidence:
  `._test_output/test-report-20260717-09/TP-39-03-node/`
- Parser, build, and setup evidence:
  `._test_output/test-report-20260717-09/parser-pure/`
  and `._test_output/test-report-20260717-09/setup/`

## Classification

The canonical TP-39-03 failure is a driver assertion bug. It is not a product
bug, execution blocker, or design mismatch.

The product reached the expected Stage 39 two-layer tuple before the driver
assertion failed:

- `control-apply-response.json` has `consumed=true` and
  `pressure_completed=true`.
- `canonical-budgets.json` records `hot_bytes=187834252`, matching the exact
  prepared binding's target plus draft bytes.
- `control-metrics-after.txt` records one `retained_cold/cold_room`, one
  `evicted/both_filled`, and one `commit/none`.
- `control-apply-response.json` records entry count delta `0`, node count
  delta `0`, branch prune delta `0`, exact descriptor `cold`, and checkpoint
  descriptor `evicted`.
- `control-apply-window.log` records the expected retained-cold, commit, and
  evicted rows.

The failing assertion is at `stage39-two-layer-pressure.ps1:1031`:

```powershell
@($ColdBefore).Count -ne 0
```

`control-cold-files-before.csv` is header-only. `Import-Csv` over that file
returns `$null`. A PowerShell 7 probe against the same typed function shape
shows the defect:

```text
top isnull=True count=0
isnull=True count=1 type=<null>
```

So the top-level value is a valid empty inventory, but binding it into a
`[object[]]` parameter makes `@($ColdBefore).Count` equal `1` in PowerShell 7.
That turns the intended cold-empty proof into a false mismatch. Windows
PowerShell 5 does not reproduce that count in the same probe, which explains
why parser/pure compatibility alone did not expose this exact live assertion
path.

The first `TP-39-03` run-root failure is not product evidence. QA pre-created
that root and the driver correctly returned `SKIP-preflight-fresh-root`.

## Findings

| ID | Finding | Classification | Owner | Required correction |
| --- | --- | --- | --- | --- |
| F39-QA09-01 | `Assert-Tp3903` treats a PowerShell 7 `$null` zero-row cold inventory as one element after `[object[]]` parameter binding, so a header-only cold inventory fails the cold-empty check. | Driver assertion bug | Developer | Normalize cold inventory captures and assertions so an empty CSV/inventory remains zero rows in PowerShell 7 and Windows PowerShell 5. The TP-39-03 cold-empty assertion should count real cold file rows, not the typed null placeholder. |
| F39-QA09-02 | D39-QA-09 stopped before full `Assert-Tp3903` PASS, so coverage blocks still have no authorized evidence. | Blocked by driver assertion | QA after Developer fix and review | Rerun the D39-QA-09 order after the driver fix is reviewed: clean seam-ON Release full target build, PowerShell 7/5 parser and pure tests, one canonical TP-39-03 node, then coverage only after full `Assert-Tp3903` PASS. |

## Correction scope

Owner: Developer.

Permitted driver-only correction:

- Update `stage39-two-layer-pressure.ps1` cold inventory handling so
  `Get-ColdInventoryS39` results captured before and after guarded apply are
  stable empty arrays when no files exist.
- Update `Assert-Tp3903` to prove pre-apply cold emptiness by counting actual
  cold inventory rows, preferably `.cold` paths, instead of counting a raw
  `[object[]]` parameter that may contain a bound null placeholder.
- Add PowerShell 7 and Windows PowerShell 5 pure regression coverage for the
  header-only CSV or null cold-inventory path through the same typed assertion
  boundary.

Out of scope for this handoff:

- Product cache code changes.
- Fixture, workload, seam, budget, threshold, route, or coverage-script policy
  changes.
- Reclassifying the expected retained-cold plus checkpoint-evicted tuple.

## Retest scope

Developer fix evidence required before QA rerun:

- PowerShell 7 `-MetricValidationSelfTest` PASS.
- Windows PowerShell 5 `-MetricValidationSelfTest` PASS.
- A focused proof that the header-only cold inventory path binds as zero rows
  through the typed TP-39-03 assertion path.
- No model-backed run is required for the driver fix itself unless the reviewer
  requests one.

QA retest after Developer and Architect review:

- Repeat Manager Part 183's D39-QA-09 order without widening it.
- Use a fresh clean Release seam-ON build of the full D39-QA target set.
- Run PowerShell 7 and Windows PowerShell 5 parser/pure checks.
- Run one canonical TP-39-03 node.
- Run the four Parts 149 and 155 coverage blocks only after full
  `Assert-Tp3903` PASS.

## Handoff

Owner: Developer.

Next durable implementation record:
`._design_docs/cache-handling-phase39-implementation/part-184-developer-d39-qa09-results-review-20260717.md`.

No code was changed in this review session.
