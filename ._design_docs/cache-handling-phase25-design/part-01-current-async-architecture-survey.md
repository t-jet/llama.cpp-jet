# Stage 25 design: Part 1: current async architecture survey

Source: [../cache-handling-phase25-design.md](../cache-handling-phase25-design.md)

This part catalogs every background, async, or interleaved
cache-mutating operation in the current
`tools/server/server-cache-hybrid.cpp` and `server-cache-hybrid.h`.
Each row names the trigger, target state, atomicity boundary, and
current serialization mechanism. Rows that already run synchronously
are listed because they participate in the same critical section once
the new lock is introduced.

## Background-mutating operations

| # | Function | File / location | Trigger source | Target state | Atomicity boundary today | Current serialization |
| - | --- | --- | --- | --- | --- | --- |
| 1 | `demote_payload` | server-cache-hybrid.cpp ~line 365 | `mark_payload_evicted` from `evict_entry_by_id`, `update` token-limit loop, `evict_until_within_budget`, `cold_budget_make_room`; also external callers | hot -> demoting -> cold (success), demoting -> hot (queue full) | partial: enqueue is sync; bytes release is async | sets residency to `demoting` then hands off to `io_worker`; no global mutex |
| 2 | `promote_payload` | server-cache-hybrid.cpp ~line 472 | `try_restore_from_cache` after restore plan selects a cold payload | cold -> promoting -> hot (success), promoting -> cold (queue full) | partial: enqueue sync, materialize async | sets residency to `promoting` then hands off to `io_worker`; no global mutex |
| 3 | `handle_demotion_completion` | server-cache-hybrid.cpp ~line 660 | `io_worker.drain_results()` from `process_completions` | demoting -> cold (success) and demoting -> hot or evicted (failure); idempotent paths for already-cold and evicted | split across slot thread and worker thread | runs on server-context thread, no slot-state serialization |
| 4 | `handle_promotion_completion` | server-cache-hybrid.cpp ~line 780 | same as #3 | promoting -> hot (success) or evicted (failure); idempotent paths | split | runs on server-context thread |
| 5 | `process_completions` | server-cache-hybrid.cpp ~line 542 | `update()` per scheduler tick | drain worker results, dispatch to handlers | runs on server-context thread; called from tests via `debug_stop_io_worker_for_tests` | none for result handlers |
| 6 | `update` | server-cache-hybrid.cpp ~line 914 | `server_context` main loop tick | drain completions, run `evict_until_within_budget`, cold cleanup, branch-metadata prune, token-limit loop | full function runs on server-context thread | none |
| 7 | `evict_until_within_budget` | server-cache-hybrid.cpp (private) | `update` | evict entries until hot budget satisfied | per-iteration | none |
| 8 | `evict_entry_by_id` | server-cache-hybrid.cpp ~line 2186 | `update` token-limit loop, callers | demote-or-evict an entry, then maybe remove entry | per-entry | none |
| 9 | `mark_payload_kind_evicted` | server-cache-hybrid.cpp ~line 3283 | `mark_payload_evicted`, eviction paths | demote if cold store configured, else immediate evict | per-payload | partial via #1 |
| 10 | `mark_payload_evicted` | server-cache-hybrid.cpp (private) | `evict_entry_by_id`, debug hooks | demote-first then evict-fallback | per-entry | partial via #1 |
| 11 | `cold_budget_make_room` | server-cache-hybrid.cpp ~line 600 | `demote_payload` | evict cold payloads until cold budget satisfied | per-payload iteration | none |
| 12 | `cold_budget_allows_write` | server-cache-hybrid.cpp ~line 570 | `demote_payload`, `update` cold cleanup | boolean check | atomic | none (read-only) |
| 13 | `attach_payload` (two overloads) | server-cache-hybrid.cpp ~line 3446 | `admit_entry_with_payload`, `materialize_entry_payload` | attach descriptor, allocate `hot_payloads`, refresh entry accounting | per-attach | none |
| 14 | `admit_entry_with_payload` | server-cache-hybrid.cpp ~line 3028 | `attach_payload` chain | push entry, sync branch node | per-entry | none |
| 15 | `materialize_entry_payload` | server-cache-hybrid.cpp (private) | restore path, debug hook | reattach payload to a metadata-only node | per-entry | none |
| 16 | `remove_payload` | server-cache-hybrid.cpp (private) | `mark_payload_kind_evicted` immediate-evict branch | zero descriptor bytes, drop descriptor | per-payload | none |
| 17 | `sync_branch_node_from_entry` | server-cache-hybrid.cpp (private) | every helper that mutates an entry's payload fields | sync forest node from entry | per-entry | none |
| 18 | `refresh_entry_payload_accounting` | server-cache-hybrid.cpp (private) | every helper that mutates an entry's payload fields | update cached byte counts | per-entry | none |
| 19 | `save_slot` | server-cache-hybrid.h declared, base or impl elsewhere | slot lifecycle end-of-request | admit entry with checkpoint, demote if needed | full slot lifecycle | none |
| 20 | `try_restore_from_cache` | server-cache-hybrid.h declared, base or impl elsewhere | slot lifecycle entry to slot | select restore plan, call `promote_payload` if cold, apply payload to live slot | split between slot thread and worker | none |
| 21 | `load_slot` | server-cache-hybrid.h declared, base or impl elsewhere | slot lifecycle entry to slot (legacy path) | legacy cache apply | full slot lifecycle | none |
| 22 | cold-store read on restore | `server_cache_store_cold` (called via promote) | #2 | materialize cold bytes into `hot_payloads` | split | worker thread only |
| 23 | cold-store write on demotion | `server_cache_store_cold` (called via demote) | #1 | atomic write + rename cold file | split | worker thread only |
| 24 | cold-store delete on eviction | `cold_store.remove`, `cold_store.delete_ids` | #11, #6 cold cleanup | delete cold file by id | per-file | none |

## Inter-thread crossings

The current code has exactly one long-lived thread besides the slot
threads and the server-context thread: the `io_worker` thread. The
slot thread and the server-context thread communicate through
`process_completions` and through `enqueue_demotion` /
`enqueue_promotion`. Three race windows follow:

- A slot thread reads a descriptor that is `hot`, calls `demote_payload`,
  the residency flips to `demoting`, the slot returns to user code, and
  the worker eventually flips to `cold`. Any reader between the
  enqueue and the completion sees `demoting` and must handle the
  transient state. Stage 22 made completion idempotent for the
  duplicate-success case but the `demoting` window remains open.
- A slot thread calls `try_restore_from_cache`, the plan selects a
  cold payload, `promote_payload` flips residency to `promoting` and
  returns, and the worker eventually inserts bytes into `hot_payloads`.
  Other slot threads that look up the same payload id during the
  `promoting` window see a descriptor with no `hot_payloads` entry.
- The server-context thread calls `update` while one or more slot
  threads are mid-`save_slot` or mid-`try_restore_from_cache`.
  `update` runs `evict_until_within_budget`, cold cleanup, and the
  token-limit loop. None of these synchronize with slot threads.

## Atomicity gaps

For each row, the atomicity boundary is narrower than the operation.
Rows 1-4 split between slot/server-context thread and worker thread.
Rows 7-18 split between slot thread and server-context thread with no
mutex. Rows 19-21 read and mutate controller state without a mutex.

This survey is the input to Part 2 (lock granularity) and Part 3
(per-operation migration).
