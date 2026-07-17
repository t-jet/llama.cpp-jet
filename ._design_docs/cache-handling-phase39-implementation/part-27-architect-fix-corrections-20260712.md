# Part 27: Architect fix corrections

Date: 2026-07-12
Status: READY FOR FRESH ARCHITECT BUG-FIX REVIEW

## Findings closed

- F39-FR-01: `test_stage39_tp_10_concurrent_cold_transactions_one_decision_each`
  starts four threads together and calls `tx_demote_payload` for four distinct
  candidates. It requires four committed cold descriptors, four demotion
  successes, four retained entries, and exactly four production
  `retained_cold/cold_room` decisions.
- F39-FR-02: `test_stage39_tp_07_target_draft_full_lifecycle` uses one
  target/draft pair for write-failure rollback, committed demotion, promotion
  and byte restore, then atomic payload removal. The lookup entry remains.
- F39-FR-03: `test_stage39_tp_09_protected_root_live_descendant_pressure`
  creates the root and child in one branch forest. Pressure selects the
  unprotected child first. The test restores that child, removes its payload,
  and requires the protected root, both entries, both nodes, and a zero pruning
  delta to remain.
- F39-FR-04: Step 6 now appears in `denomBasenames`. Complete Stage 39 coverage
  runs fail when the server, model, readiness probe, or server `.cov` is
  missing. `-SkipServerProbe` works only with the explicit
  `-AllowIncompleteStage39Coverage` opt-out.

## Files changed

- `tests/test-cache-controller.cpp`
- `._design_docs/cache-handling-test-scripts/run_coverage.ps1`
- `._design_docs/cache-handling-test-scripts/README.md`
- `._design_docs/cache-handling-test-plan/part-43-stage39-two-layer-retention.md`
- `._design_docs/.test_reports/test-report-20260712-02-fixes.md`
- Stage 39 implementation entry and document index

## Verification

- Release build, `test-cache-controller`: PASS.
- Release `test-cache-controller.exe`: PASS, including all three new tests.
- Release build and direct run, `test-step6-demotion-protocol`: PASS.
- PowerShell parser, `run_coverage.ps1`: PASS.
- Fail-closed static smoke: `-SkipServerProbe` without the incomplete-run opt-out
  exits nonzero before capture.
- Full coverage percentage: not claimed. QA still must run OpenCppCoverage with
  a model and required server capture.

All four Architect findings have executable corrections. Fresh Architect review
is the next gate.
