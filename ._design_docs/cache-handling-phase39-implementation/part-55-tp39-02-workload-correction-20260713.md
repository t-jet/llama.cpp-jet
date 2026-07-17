# Part 55: TP-39-02 workload correction

Date: 2026-07-13
Status: PASS - READY FOR ARCHITECT REVIEW
Scope: F39-GDIR-04 TP-39-02 workload and guarded driver evidence

## Correction

Part 54 used six near-equal requests. Discovery exposed three hot candidates,
so apply pressured two candidates and correctly failed the exact delta check.

The canonical `multi-victim` workload now submits exactly three completions:

1. a 40-fill-token cold victim;
2. a 41-fill-token cold victim; and
3. a 72-fill-token hot incoming object.

The startup budgets are 13 MiB hot and 22 MiB cold for the accepted 7 MiB hot
and 11 MiB cold apply command. Normal `tx_save()` demotes both smaller objects
and leaves the larger incoming object hot. The driver then erases the idle slot
KV state through `/slots/0?action=erase`; this releases the incoming slot
reference without admitting another cache object. Its isolated
`--slot-save-path` directory is removed when empty.

Discovery remains authoritative. Apply sends the complete returned hot and cold
sets unchanged, assigns equal victim ranks, and keeps the exact one-decision and
one-commit checks. TP-39-02 now also fails unless discovery contains exactly one
hot incoming object, exactly two smaller cold victims, and measured startup and
apply budgets that force both-victim room-making.

No product code changed.

## Final smoke

Command used Qwen3-0.6B Q8_0, the seam-ON Release server, port 8296, 7 MiB hot,
11 MiB cold, and context size 2048. Artifacts are under
`._test_output/stage39-dev-part55/driver-multi-victim-slot-final/`.

| Item | Before | After or result |
| --- | ---: | ---: |
| Hot incoming ID 3 resident bytes | 8,947,296 | cold file 8,947,360 |
| Cold victim ID 1 serialized bytes | 5,506,360 | file absent |
| Cold victim ID 2 serialized bytes | 5,621,060 | file absent |
| `retained_cold/cold_room_made` | 0 | 1 |
| `commit/none` | 2 | 3 |
| Entries | 3 | 3 |
| Branch nodes | 3 | 3 |
| Pruning | 0 | 0 |
| Descriptor/payload cold bytes | 11,127,420 | 8,947,360 |

Victims were ordered by tied rank and payload ID: 1, then 2. Before apply,
`1.cold` and `2.cold` existed. After apply, both were absent and `3.cold`
existed. Quarantine bytes stayed zero. The apply response changed generation 50
to 65 and returned no hot candidate, which proves atomic movement of the
target-only incoming pair. Fixed logs contain one apply-time
`retained_cold/cold_room_made payload_id=3` row and one `commit/none tx_id=3`
row. Setup rows remain outside the before/after apply snapshots.

## Verification

| Check | Exit/result | Artifact |
| --- | --- | --- |
| Windows PowerShell 5 parse | 0 | `ps5-parse-final.log` |
| Windows PowerShell 5 self-test | 0 | `ps5-selftest-final.log` |
| PowerShell 7 parse | 0 | `ps7-parse-final.log` |
| PowerShell 7 self-test | 0 | `ps7-selftest-final.log` |
| Bounded model-backed TP-39-02 smoke | 0, PASS | `driver-smoke-slot-final.log` |

The self-test records the exact request roles and fill counts. The smoke saved
discover/apply requests and responses, metrics, logs, cold inventories,
workload profile, slot erase evidence, state, and summary. The summary reports
three requests and PASS.

## Handoff

F39-GDIR-04 TP-39-02 workload correction is ready for fresh Architect review.
Parts 53-55 provide current implementation and executable evidence. QA still
owns canonical coverage and the remaining Stage 39 execution gate.
