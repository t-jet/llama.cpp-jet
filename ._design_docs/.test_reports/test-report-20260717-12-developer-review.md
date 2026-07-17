# Developer review: test-report-20260717-12

Date: 2026-07-17
Reviewer: Developer agent
Input report: `._design_docs/.test_reports/test-report-20260717-12.md`
Evidence root: `._test_output/test-report-20260717-12/`
Verdict: REWORK REQUIRED

## Scope reviewed

- Manager rerun gate:
  `._design_docs/cache-handling-phase39-implementation/part-195-manager-d39-qa12-rerun-gate-20260717.md`
- QA report:
  `._design_docs/.test_reports/test-report-20260717-12.md`
- Canonical TP-39-03 evidence:
  `._test_output/test-report-20260717-12/TP-39-03-node/`
- Live driver:
  `._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1`
  around `Get-ColdInventoryS39`, `Assert-ControlCommonS39`, and
  `Assert-Tp3903`
- Persistent ownership record:
  `._design_docs/cache-handling-phase39-implementation/part-17-persistent-ownership-claims-20260712.md`
- Cold-store implementation:
  `tools/server/server-cache-store-cold.cpp`

## Classification

D39-QA-12 failed on a driver assertion bug. It is not a product bug, execution
blocker, or design mismatch.

Product state matches the current TP-39-03 contract:

- guarded apply consumed the request and completed pressure;
- exact payload `1` was retained as cold;
- checkpoint payload `2` was evicted and did not publish `2.cold`;
- terminal proof reports cold inventory with one payload file, `1.cold`;
- terminal proof reports empty staging inventory;
- apply-window logs contain the expected `retained_cold/cold_room`, one
  `commit/none`, and `evicted/both_filled`;
- topology and branch pruning stayed retained.

The failure is the last conjunct in `Assert-Tp3903`:

```powershell
@($ColdAfter).Count -ne 1
```

`Get-ColdInventoryS39` intentionally captures every file under the cold root.
After the successful cold transaction, the root contains:

```text
1.cold
ownership.claims
```

`ownership.claims` is expected Stage 39 metadata. Part 17 says committed cold
transactions update `ownership.claims` with one record per live cold payload,
and `server-cache-store-cold.cpp` writes it in `apply_claims()` during
`mark_committed()`. Startup also reads it in `recover_transactions()`. Its
presence does not mean an extra cold payload exists.

The assertion should count payload files only, using the same `.cold` filter
already used by `Assert-ControlCommonS39`, while still rejecting staging,
manifest, quarantine, and checkpoint `.cold` leftovers. The full root inventory
should still be captured in CSV so metadata and forbidden work files remain
auditable.

## Findings

| ID | Finding | Classification | Owner | Required correction |
| --- | --- | --- | --- | --- |
| F39-QA12-01 | `Assert-Tp3903` counts all cold-root files and rejects expected `ownership.claims` metadata. | Driver assertion bug | Developer | Change TP-39-03 final inventory validation to count only payload `.cold` rows, require exactly `1.cold`, require no checkpoint `.cold`, and separately reject staging, manifest, quarantine, or other transient work files. Keep full cold-root CSV capture unchanged. |
| F39-QA12-02 | Coverage blocks remain unrun because full `Assert-Tp3903` did not PASS. | Blocked by driver assertion | QA after Developer fix and review | Repeat D39-QA order after the driver fix review. Run coverage only after canonical TP-39-03 reaches full `Assert-Tp3903` PASS. |

## Correction scope

Owner: Developer.

Permitted driver-only correction:

- Update `stage39-two-layer-pressure.ps1` TP-39-03 cold-inventory assertion to
  use a payload-file subset for cardinality.
- Preserve full `control-cold-files-before.csv` and
  `control-cold-files-after.csv` root capture, including `ownership.claims`.
- Add PowerShell 7 and Windows PowerShell 5 pure coverage that accepts
  `1.cold + ownership.claims`.
- Add negatives for extra payload `.cold`, checkpoint `.cold`, staging,
  manifest, and quarantine rows.
- Keep TP-39-02 and TP-39-04 assertions unchanged unless separately authorized.

Out of scope:

- Product cache code changes.
- Fixture, workload, seam, budget, threshold, route, stage-plan, or coverage
  policy changes.
- Treating `ownership.claims` as a payload file or deleting it for the test.

## Retest scope

Developer fix evidence required before QA rerun:

- PowerShell 7 parser PASS.
- Windows PowerShell 5 parser PASS.
- PowerShell 7 `-MetricValidationSelfTest` PASS.
- Windows PowerShell 5 `-MetricValidationSelfTest` PASS.
- Focused pure proof that TP-39-03 accepts one `.cold` payload plus
  `ownership.claims`, and rejects extra payload, checkpoint, staging, manifest,
  or quarantine rows.

QA retest after Developer and Architect review:

- Repeat Manager Part 195's D39-QA-12 order.
- Use a fresh clean Release seam-ON build of the full D39-QA target set.
- Run PowerShell 7 and Windows PowerShell 5 parser/pure checks.
- Run one canonical TP-39-03 node.
- Run the four Parts 149 and 155 coverage blocks only after full
  `Assert-Tp3903` PASS.

## Handoff

Next durable implementation record:
`._design_docs/cache-handling-phase39-implementation/part-196-developer-d39-qa12-results-review-20260717.md`.

No code was changed in this review session.
