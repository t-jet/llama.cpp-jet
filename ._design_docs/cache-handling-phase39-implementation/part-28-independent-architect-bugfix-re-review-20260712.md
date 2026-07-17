# Part 28: independent Architect bug-fix re-review

Date: 2026-07-12
Status: REWORK REQUIRED

## Verdict

F39-FR-02 through F39-FR-04 pass fresh code and test inspection. F39-FR-01
remains open.

`test_stage39_tp_10_concurrent_cold_transactions_one_decision_each` runs four
concurrent direct `tx_demote_payload` calls. It does not run concurrent slot
transactions and does not create hot pressure. TP-39-10 requires one final
decision per hot-pressure candidate, so this test does not exercise the
production decision path named by the row.

## Required correction

Add deterministic concurrent evidence through production hot pressure. Require
one and only one final decision per candidate across all result/reason tuples,
committed cold descriptors, retained entries, no partial visibility, and no
deadlock.

## Checks

- Release `test-cache-controller.exe`: PASS.
- `run_coverage.ps1` parser: PASS.
- `-SkipServerProbe` without `-AllowIncompleteStage39Coverage`: nonzero exit.

QA execution remains closed. Developer correction and fresh Architect re-review
are next.
