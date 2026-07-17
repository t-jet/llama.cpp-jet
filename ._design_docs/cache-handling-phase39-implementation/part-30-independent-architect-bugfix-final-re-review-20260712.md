# Part 30: independent Architect bug-fix final re-review

Date: 2026-07-12
Status: PASS

## Scope

This fresh review covers F39-FR-01 after the Part 29 correction. It inspects
the TP-39-10 test, production pressure path, transaction locking, and final
state assertions. F39-FR-02 through F39-FR-04 remain closed by Part 28.

## Findings

No blocking finding remains.

`test_stage39_tp_10_concurrent_cold_transactions_one_decision_each` admits four
hot candidates before lowering the hot budget. Four synchronized workers then
call `tx_update`. That call reaches `update`, `evict_until_within_budget`,
`evict_entry_by_id`, and `mark_payload_kind_evicted` before entering the inline
cold transaction. The test no longer invokes the demotion helper directly.

The controller's recursive cache-state mutex covers each complete `tx_update`.
File commit, descriptor residency, hot-byte release, accounting, and the final
decision therefore complete before another worker enters the pressure path.
After all workers join, the test requires:

- four cold descriptors and cold residency for every original payload ID;
- four retained lookup entries and zero resident hot bytes;
- exact serialized cold bytes and four successful demotions; and
- exactly four final decisions across every result/reason tuple, all
  `retained_cold/cold_room`.

These checks prove one committed decision per pressure candidate and reject a
partial final state. Mutex serialization prevents partial controller state from
becoming visible between concurrent pressure transactions. Worker joins make a
deadlock incapable of passing.

## Verification

- Release `test-cache-controller.exe`: PASS in 20 consecutive runs.
- Production-path inspection: PASS.
- Decision and candidate reconciliation: PASS, four candidates and four final
  decisions with no other tuple.
- Descriptor, entry, hot-byte, and cold-byte reconciliation: PASS.

## Verdict

PASS. F39-FR-01 is closed. F39-FR-01 through F39-FR-04 now pass the paired
Architect bug-fix review. Fresh QA execution is the next gate. This review does
not supply live TP-39-02 evidence or a changed-line coverage percentage.
