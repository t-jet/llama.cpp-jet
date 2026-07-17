# Part 29: TP-39-10 production-pressure correction

Date: 2026-07-12
Status: READY FOR FRESH ARCHITECT BUG-FIX REVIEW

## Finding

F39-FR-01 remained open because TP-39-10 called `tx_demote_payload` directly.
That covered concurrent cold transactions but bypassed production hot-pressure
selection and `mark_payload_kind_evicted`.

## Correction

`test_stage39_tp_10_concurrent_cold_transactions_one_decision_each` now:

- admits four slot-equivalent hot candidates while the hot budget has room;
- lowers the hot budget, synchronizes four worker starts, and calls `tx_update`
  concurrently;
- reaches `evict_until_within_budget`, `evict_entry_by_id`,
  `mark_payload_kind_evicted`, and the inline cold transaction path;
- requires four cold descriptors, four retained entries, zero resident hot
  bytes, and the exact serialized cold-byte total;
- sums every final-decision result/reason tuple and requires exactly four total
  decisions, all `retained_cold/cold_room`; and
- requires four demotion successes and cold residency for every candidate.

Worker joins are part of the test, so a lock-order deadlock cannot produce a
PASS. State assertions run only after all workers join and reject partial
visibility.

## Evidence

- Release build, `test-cache-controller`: PASS.
- Direct `build/bin/Release/test-cache-controller.exe`: PASS.
- `ctest --test-dir build -C Release --output-on-failure -R
  '^test-cache-controller$'`: PASS, 1/1, 1.17 seconds.

F39-FR-01 is corrected. Fresh Architect bug-fix review is next. QA execution
remains closed until that review passes.
