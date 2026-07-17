# Developer review: Stage 39 D39-QA-05

Date: 2026-07-17
Verdict: REWORK REQUIRED
Source: `test-report-20260717-05.md`

## Classification

| Item | Classification | Owner | Next action |
| --- | --- | --- | --- |
| TP-39-03 `later_work_delta=1` | Guarded counter/assertion bug | Developer | Replace generation-span inference with an observed forbidden-work delta. |
| Production pressure result | Correct | None | Preserve current eviction, retention, accounting, and ordering. |
| Coverage | Deliberate fail-fast deferral | QA after Manager authorization | Open four blocks only after full TP-39-03 PASS. |

No product retention or pressure-ordering bug is established. Exact demotion,
checkpoint eviction, cold retention, transaction, topology, signed LRU, and
active-reference accounting all match the accepted contract.

## Root cause

The proof records `common_sync_generation=50` after the outer production sync
at `server-cache-hybrid.cpp:3997-3999`. Successful pressure then returns to
`evict_entry_by_id()`, which performs the required source hot-policy removal at
line 2813. `remove_from_lru_index()` erases the membership and calls
`STAGE39_CACHE_MUTATED()` at lines 5085-5091. This is the sole generation
advance to `final_generation=51`; no later victim, branch prune, checkpoint
diagnostic, or explicit guarded advance occurred.

Design Part 35 requires terminal freeze after LRU removal and all `update()`
work. Part 43 permits `final_generation >= common_sync_generation`. Therefore
the subtraction at `server-cache-hybrid.cpp:6231` measures all normal
post-sync mutations, not forbidden later-kind or pressure work. The driver
correctly compares the named field to zero at
`stage39-two-layer-pressure.ps1:431-443`; its input counter has the wrong
semantics. This is a guarded evidence bug, not a production behavior bug.

## Required fix and retest

Add a seam-only observed event counter at the forbidden later-kind and
post-abort pressure/diagnostic boundaries. Snapshot it before apply and emit
its terminal delta as `later_work_delta`. Do not count common reconciliation,
branch sync, successful LRU removal, or other permitted `update()` cleanup.
Keep final-generation capture after `tx_update()` and keep stale retrieval
checks unchanged.

Add controller probes that force each named forbidden boundary and require a
nonzero delta, plus negatives proving a normal successful LRU removal yields
generation span `1` but `later_work_delta=0`. Update pure route-shape checks and
retain fault-path zero assertions. Then run focused controller and PowerShell
7/5 pure tests, fresh Architect review, and one Manager-authorized canonical
TP-39-03 rerun. Only full PASS opens the four deferred coverage blocks. No fix,
build, model, test, or coverage command ran in this review.
