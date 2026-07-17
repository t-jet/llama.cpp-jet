# Stage 39 D39-QA-12 fix report

Date: 2026-07-17
Status: READY FOR REVIEW
Source report: `test-report-20260717-12.md`
Developer review: `test-report-20260717-12-developer-review.md`
Implementation record:
`../cache-handling-phase39-implementation/part-197-d39-qa12-cold-inventory-metadata-driver-fix-20260717.md`

## Scope

D39-QA-12 failed because the TP-39-03 final cold-root assertion counted every
root file and rejected expected `ownership.claims` metadata. The product state
matched the reviewed contract: exact payload cold, checkpoint payload evicted,
and no staging inventory in the terminal proof.

This fix changes only
`._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1`.
Product code, fixture, workload, budgets, thresholds, seam behavior, and
coverage policy were not changed.

## Correction

`Assert-Tp3903` now delegates final cold-root validation to
`Assert-Tp3903FinalColdInventoryS39`.

The helper:

- counts only root payload rows matching `^[0-9a-fA-F]+\.cold$`;
- requires exactly one payload row, the exact payload `.cold`;
- rejects the checkpoint `.cold` row and any extra payload `.cold`;
- accepts expected `ownership.claims` metadata;
- rejects staging/temp, quarantine, manifest, and other unexpected cold-root
  files.

Full cold-root CSV capture remains unchanged, so `ownership.claims` stays
auditable in `control-cold-files-after.csv`.

## Regression coverage

The existing `-MetricValidationSelfTest` path now covers:

- accept: exact payload `.cold` plus `ownership.claims`;
- reject: checkpoint `.cold`;
- reject: extra payload `.cold`;
- reject: staging and temp leftovers;
- reject: quarantine leftovers;
- reject: manifest leftovers;
- reject: unexpected cold-root files.

## Evidence

Commands run from repo root:

| Check | Result |
| --- | --- |
| `pwsh.exe -NoProfile -Command '[System.Management.Automation.Language.Parser]::ParseFile(...)'` | PASS |
| `powershell.exe -NoProfile -Command '[System.Management.Automation.Language.Parser]::ParseFile(...)'` | PASS |
| `pwsh.exe -NoProfile -File .\._design_docs\cache-handling-test-scripts\stage39-two-layer-pressure.ps1 -ModelPath .\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf -MetricValidationSelfTest` | PASS |
| `powershell.exe -NoProfile -File .\._design_docs\cache-handling-test-scripts\stage39-two-layer-pressure.ps1 -ModelPath .\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf -MetricValidationSelfTest` | PASS |

Both self-tests reported `Outcome : PASS` with TP-39-03 source/incoming roles
and lengths `{721, 723}`.

## Not run

Per the handoff, no TP-39-03 model node and no coverage block was run in this
fix session.

## Handoff

Next owner: Architect or Developer reviewer for the driver-only fix review.
After review, QA should repeat the Manager Part 195 order. Coverage remains
blocked until canonical TP-39-03 reaches full `Assert-Tp3903` PASS.
