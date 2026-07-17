# Developer review: Stage 39 D39-QA-04

Date: 2026-07-17
Verdict: REWORK REQUIRED
Source: `test-report-20260717-04.md`

## Classification

| Item | Classification | Owner | Next action |
| --- | --- | --- | --- |
| TP-39-03 LRU check | Driver assertion error | Developer | Match the terminal assertion to the approved post-eviction hot-LRU state. |
| LRU delta encoding | Guarded proof measurement error | Developer | Serialize a signed delta and require the expected `-1`. |
| Resident-over-budget warning | Expected active-reference pressure | Developer | Assert exact arithmetic and blocked-reference ownership; do not require the global resident total below the lowered source budget. |
| Coverage | Deliberate fail-fast deferral | QA after Manager authorization | Run the four Part 149 blocks only after TP-39-03 passes. |

No Stage 39 product retention bug is established. Production produced the exact
required `retained_cold/cold_room`, `evicted/both_filled`, and `commit/none`
tuples. The source exact descriptor stayed cold, its file and byte map matched,
the checkpoint became an evicted tombstone, both lookup entries and branch
nodes remained, and pruning stayed unchanged.

## Root cause

`evict_entry_by_id()` owns the LRU transition. After `mark_payload_evicted()`
demotes either descriptor, it keeps lookup visibility but calls
`remove_from_lru_index(it)` at `server-cache-hybrid.cpp:2813`. This is the
approved hot-policy behavior: design Part 35 places terminal success after LRU
removal, while Part 1 requires retained lookup entry, branch metadata, owner,
and restorable descriptor. None requires a cold-only metadata entry to remain
a hot eviction candidate.

The guarded baseline counted one membership. Terminal state correctly counted
zero. `stage39_finalize_prepared_locked()` subtracts two `size_t` values at
`server-cache-hybrid.cpp:6193`, so `0 - 1` serialized as
`18446744073709551615`. The driver then incorrectly required membership `1`
and delta `0` at `stage39-two-layer-pressure.ps1:363-365`.

The warning is also not stale accounting. The two-entry workload deliberately
keeps the incoming entry referenced by the active slot. Discovery excludes it;
only the released 187,834,252-byte source is eligible. After source exact
demotion and checkpoint eviction, metrics fall from 509,835,246 to 254,380,666
total cache bytes and from four to two hot descriptors. The warning's
254,351,576 resident payload bytes belong to the still-referenced incoming
entry. It cannot be evicted to meet the source-derived 187,834,252-byte budget.

## Required correction and retest

Developer owns a guarded seam/driver-only fix. Emit signed entry, node, LRU,
and pruning deltas; require terminal source LRU membership `0` and signed delta
`-1`; retain exact entry/node/pruning checks; and add pure negatives for wrong
membership, zero delta, unsigned wrap, and unexplained resident-over-budget
state. Bind the warning check to one active-reference-excluded incoming entry,
its exact resident bytes, and otherwise reconciled source bytes. Do not change
production eviction, retention, budgets, fixture, workload, caps, plan, or
thresholds.

After Architect review and Manager authorization, QA reruns cheap PowerShell
7/5 gates and one canonical TP-39-03 node. Only full `Assert-Tp3903` PASS opens
the four coverage blocks. No fix, build, model, test, or coverage command ran.
