# Part 198: D39-QA-12 cold inventory driver fix review

Date: 2026-07-17
Reviewer: Architect agent
Verdict: PASS

## Scope and gate status

Reviewed the D39-QA-12 driver-only fix for F39-QA12-01:

- source failure: `../.test_reports/test-report-20260717-12.md`
- Developer review: `../.test_reports/test-report-20260717-12-developer-review.md`
- fix report: `../.test_reports/test-report-20260717-12-fixes.md`
- implementation record: `part-197-d39-qa12-cold-inventory-metadata-driver-fix-20260717.md`
- driver: `../cache-handling-test-scripts/stage39-two-layer-pressure.ps1`
- index: `../document-index.md`

No model run or coverage run was performed for this review.

Gate result: PASS for the driver fix. Manager may open the next D39-QA rerun
using the Part 195 order: fresh clean seam-ON Release build, PowerShell 7 and
Windows PowerShell 5 parser and pure gates, one canonical TP-39-03 node, then
coverage only after full `Assert-Tp3903` PASS.

## Decisions

1. TP-39-03 final cold inventory now matches the Stage 39 contract.

   `Assert-Tp3903FinalColdInventoryS39` builds payload cardinality only from
   root rows matching `^[0-9a-fA-F]+\.cold$`. It requires exactly the exact
   payload file, rejects the checkpoint payload file, and rejects any extra
   payload `.cold` row. `ownership.claims` is accepted as expected cold-root
   metadata, not counted as payload inventory.

2. Forbidden cold-root artifacts are still rejected.

   The helper scans every final cold-root row after payload validation. It
   accepts only payload `.cold` files and `ownership.claims`. It rejects
   staging/temp paths, quarantine leftovers, manifest files, and any other
   unexpected root file. The full CSV capture remains unchanged, so metadata and
   forbidden files stay visible in artifacts.

3. The correction stayed driver-only.

   Reviewed changes are confined to the PowerShell driver contract and its pure
   self-test coverage. Part 197 and the fix report record no fixture, workload,
   seam, budget, threshold, coverage policy, or product behavior change. The
   current worktree has unrelated dirty product files, so this review treats
   product diffs as outside the D39-QA-12 fix scope and does not approve them.

4. Parser and pure self-test evidence is enough for the rerun gate.

   This fix changes assertion semantics only. PowerShell 7 and Windows
   PowerShell 5 parser checks plus `-MetricValidationSelfTest` cover the new
   accepting case and the required rejecting cases. A model rerun is still
   required for QA, but not for this driver-fix review.

5. Documentation and index are aligned.

   Part 197 records the correction. This Part 198 records the Architect PASS.
   The Stage 39 implementation entry and document index now point to the PASS
   handoff.

## Verification

Local verification run during this review:

| Check | Result |
| --- | --- |
| PowerShell 7 parser | PASS |
| Windows PowerShell 5 parser | PASS |
| PowerShell 7 `-MetricValidationSelfTest` | PASS |
| Windows PowerShell 5 `-MetricValidationSelfTest` | PASS |

Both self-tests reported `Outcome : PASS`, `Tp3903Roles : {source, incoming}`,
and `Tp3903Lengths : {721, 723}`.

## Findings

No blocking architectural or review findings.

## Required corrections

None for D39-QA-12 driver-fix review.

## Handoff

State: ready for Manager rerun gate.

Next owner: Manager for the next D39-QA rerun authorization. QA should rerun the
Part 195 sequence after that gate. Coverage remains blocked until canonical
TP-39-03 reaches full `Assert-Tp3903` PASS.
