# Part 196: Developer D39-QA-12 results review

Date: 2026-07-17
Status: REWORK REQUIRED
Input report: `../.test_reports/test-report-20260717-12.md`
Developer review: `../.test_reports/test-report-20260717-12-developer-review.md`

## Scope

Manager Part 195 authorized D39-QA-12: fresh clean Release seam-ON full target
build, PowerShell 7 and Windows PowerShell 5 parser and pure checks, one
canonical TP-39-03 node, then four coverage blocks only after full
`Assert-Tp3903` PASS.

QA completed the build and shell gates. The canonical TP-39-03 node failed at
the final cold-root inventory assertion in `Assert-Tp3903`. Coverage did not
run. This part records Developer classification only. No product code, driver
code, fixture, workload, budget, threshold, seam, coverage policy, commit, push,
PR, or reviewer response was changed.

## Evidence reviewed

- `._design_docs/cache-handling-phase39-implementation/part-195-manager-d39-qa12-rerun-gate-20260717.md`
- `._design_docs/.test_reports/test-report-20260717-12.md`
- `._test_output/test-report-20260717-12/setup/`
- `._test_output/test-report-20260717-12/parser-pure/`
- `._test_output/test-report-20260717-12/TP-39-03-node/`
- `._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1`
  around `Get-ColdInventoryS39`, `Assert-ControlCommonS39`, and
  `Assert-Tp3903`
- `._design_docs/cache-handling-phase39-implementation/part-17-persistent-ownership-claims-20260712.md`
- `tools/server/server-cache-store-cold.cpp`

## Classification

F39-QA12-01 is a driver assertion bug.

The product reached the canonical TP-39-03 state:

- guarded apply consumed the request and completed pressure;
- exact descriptor `1` ended cold;
- checkpoint descriptor `2` ended evicted;
- terminal proof recorded one payload cold file, `1.cold`;
- terminal proof recorded no staging inventory;
- apply-window logs recorded one `retained_cold/cold_room`, one `commit/none`,
  and one `evicted/both_filled`;
- descriptor and residency metric deltas matched Part 194.

The failing assertion is `stage39-two-layer-pressure.ps1:1188-1191`. It
requires the total normalized cold-root inventory count to equal one:

```powershell
@($ColdAfter).Count -ne 1
```

The captured root inventory has two files:

```text
1.cold
ownership.claims
```

`ownership.claims` is expected metadata, not a cold payload. Part 17 introduced
the journal so committed cold transactions persist ownership for each live cold
payload. `server_cache_store_cold::mark_committed()` calls `apply_claims()`,
which writes `ownership.claims`; `recover_transactions()` reads it on startup.
The metadata file should remain visible in the CSV capture but should not count
as an additional payload file.

This is not a product bug because product proof and metrics agree. It is not an
execution blocker because the server built, ran, applied the request, emitted
the expected logs, and cleaned up. It is not a design mismatch because the
current Stage 39 design includes persistent ownership claims and the TP-39-03
contract requires one exact cold payload plus checkpoint eviction, not a
metadata-free cold root.

## Required correction

Owner: Developer.

Correct only the PowerShell driver assertion path:

1. In `Assert-Tp3903`, count only rows whose `Path` matches
   `^[0-9a-fA-F]+\.cold$` when checking final payload cardinality.
2. Require exactly one payload cold row: `1.cold`.
3. Require zero checkpoint payload rows: `2.cold`.
4. Separately reject transient or forbidden cold-root work files, including
   staging, quarantine, manifest, and extra payload `.cold` rows.
5. Keep full cold-root inventory capture in `control-cold-files-after.csv`, so
   `ownership.claims` remains auditable.

Product cache code, fixture, workload, seam, budget, threshold, route behavior,
stage plan, and coverage policy stay out of scope.

## Retest scope

Developer fix evidence before QA rerun:

- PowerShell 7 parser PASS.
- Windows PowerShell 5 parser PASS.
- PowerShell 7 `-MetricValidationSelfTest` PASS.
- Windows PowerShell 5 `-MetricValidationSelfTest` PASS.
- Focused pure evidence that TP-39-03 accepts final inventory
  `1.cold + ownership.claims`.
- Focused pure negatives for extra payload `.cold`, checkpoint `.cold`,
  staging, manifest, and quarantine rows.

QA retest after Developer fix review:

- Repeat Manager Part 195's D39-QA-12 order.
- Start from a fresh clean Release seam-ON full target build.
- Run PowerShell 7 and Windows PowerShell 5 parser/pure gates.
- Run one canonical TP-39-03 node.
- Run the four Parts 149 and 155 coverage blocks only after full
  `Assert-Tp3903` PASS.

## Handoff

Next owner: Developer for the driver-only cold-inventory assertion correction.

Coverage remains blocked until canonical TP-39-03 reaches full
`Assert-Tp3903` PASS under the Manager-authorized order.
