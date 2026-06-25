# Stage 25 design: Part 3: per-operation migration

Source: [../cache-handling-phase25-design.md](../cache-handling-phase25-design.md)

This part maps each row of Part 1 to its synchronous transactional
replacement. Each row gives: the new transaction method, the lock
semantics, the owner of the operation, and the changes to test hooks
or metrics.

## Migration table

| # | Current op | New synchronous transaction | Lock semantics | Owner | Test hook change |
| - | --- | --- | --- | --- | --- |
| 1 | `demote_payload` | `tx_demote_payload(payload_id)` called from inside `tx_evict_entry` or `tx_save` | recursive mutex held by caller; helper asserts mutex held | controller | existing test-only demote hooks continue; new helper exposes residency-before / residency-after |
| 2 | `promote_payload` | `tx_promote_payload(payload_id)` called from inside `tx_restore` | recursive mutex held by caller; helper asserts mutex held | controller | existing test-only promote hooks continue |
| 3 | `handle_demotion_completion` | folded into `tx_demote_payload` as inline worker call; no separate completion handler | same lock as caller | controller | demote test path asserts residency after `tx_demote_payload` returns |
| 4 | `handle_promotion_completion` | folded into `tx_promote_payload` as inline worker call | same lock as caller | controller | promote test path asserts residency after `tx_promote_payload` returns |
| 5 | `process_completions` | removed; results are drained inline inside the caller transaction | n/a | controller | `debug_stop_io_worker_for_tests` no longer drains results because there are none |
| 6 | `update` | `tx_update()` | recursive mutex acquired at entry | controller | existing update-driven tests assert state after `tx_update` returns |
| 7 | `evict_until_within_budget` | inlined into `tx_update` and `tx_evict_entry` | recursive mutex held by caller | controller | existing budget-pressure tests pass unchanged |
| 8 | `evict_entry_by_id` | `tx_evict_entry(entry_id, reason)` | recursive mutex acquired at entry | controller | existing eviction tests pass unchanged |
| 9 | `mark_payload_kind_evicted` | inlined into `tx_evict_entry` and `tx_demote_payload` | recursive mutex held by caller | controller | `mark_payload_kind_evicted` becomes a private helper that asserts mutex held |
| 10 | `mark_payload_evicted` | inlined into `tx_evict_entry` | recursive mutex held by caller | controller | same as row 9 |
| 11 | `cold_budget_make_room` | `tx_cold_budget_make_room(bytes, descriptor)` called from `tx_demote_payload` | recursive mutex held by caller | controller | existing cold-budget tests pass unchanged |
| 12 | `cold_budget_allows_write` | read-only; called inside transactions and from outside (no mutation) | none when called outside | controller | unchanged |
| 13 | `attach_payload` (two overloads) | inlined into `tx_save`, `tx_restore`, `tx_update` cold cleanup | recursive mutex held by caller | controller | attach-path tests pass unchanged |
| 14 | `admit_entry_with_payload` | inlined into `tx_save` | recursive mutex held by caller | controller | admit tests pass unchanged |
| 15 | `materialize_entry_payload` | inlined into `tx_restore` and `tx_save` | recursive mutex held by caller | controller | rematerialize tests pass unchanged |
| 16 | `remove_payload` | inlined into `tx_evict_entry` | recursive mutex held by caller | controller | unchanged |
| 17 | `sync_branch_node_from_entry` | helper inside transactions | recursive mutex held | controller | unchanged |
| 18 | `refresh_entry_payload_accounting` | helper inside transactions | recursive mutex held | controller | unchanged |
| 19 | `save_slot` | `tx_save(slot, metadata)` | recursive mutex acquired at entry | controller | existing save tests continue; new `debug_run_save_transaction` test helper exposes the transaction result |
| 20 | `try_restore_from_cache` | `tx_restore(slot, task)` for plan + promote; second-pass `tx_apply_restore(slot, plan)` after live-slot apply | recursive mutex acquired at entry for both passes | controller | existing restore tests continue; new helper exposes the plan returned by `tx_restore` |
| 21 | `load_slot` legacy | `tx_load(slot, task)` | recursive mutex acquired at entry | controller | legacy tests pass unchanged |
| 22 | cold-store read on restore | inlined into `tx_promote_payload` | recursive mutex held | controller | existing cold-store read tests pass unchanged |
| 23 | cold-store write on demotion | inlined into `tx_demote_payload` | recursive mutex held | controller | existing cold-store write tests pass unchanged |
| 24 | cold-store delete on eviction | inlined into `tx_cold_budget_make_room` and `tx_update` cold cleanup | recursive mutex held | controller | unchanged |

## Detailed mapping for the critical paths

### `demote_payload`

Today: sets residency to `demoting`, enqueues to worker, returns.
Worker eventually calls `handle_demotion_completion` which sets
residency to `cold`, releases hot bytes, and refreshes owner views.

New: `tx_demote_payload(payload_id)` is a public helper that callers
inside a transaction invoke. The helper:

1. Asserts `cache_state_mutex_` is held by the calling thread.
2. Validates eligibility: descriptor exists, residency is `hot`,
   cold store configured, hot record exists, pair state complete,
   cold budget allows.
3. Sets residency to `demoting`.
4. Invokes the worker task inline on the calling thread, with the
   mutex still held. The worker writes the cold file via atomic
   write + rename.
5. On worker success: sets cold ref, sets residency to `cold`,
   increments cold bytes/count, releases hot bytes, refreshes owner
   views.
6. On worker failure: reverts residency to `hot` if hot record
   present; otherwise marks evicted and zeroes resident bytes.

Steps 4 and 5 are atomic with respect to other transactions because
the mutex is held the entire time. The worker call is the only
"long" operation; it is bounded by disk write latency.

The existing Stage 22 idempotent completion handler becomes a no-op
because the helper executes the success path exactly once. The
duplicate-success branch is removed. The stale-success branch is
removed. Only the worker-failure path remains, and it is the
inline revert.

### `promote_payload`

Today: sets residency to `promoting`, enqueues to worker, returns.
Worker eventually calls `handle_promotion_completion` which inserts
bytes into `hot_payloads`, sets residency to `hot`, and refreshes
owner views.

New: `tx_promote_payload(payload_id)` is a public helper that callers
inside a transaction invoke. The helper:

1. Asserts mutex held.
2. Validates eligibility: descriptor exists, residency is `cold`,
   cold store configured.
3. Sets residency to `promoting`.
4. Invokes the worker task inline. The worker reads the cold file
   and verifies descriptor integrity.
5. On success: inserts bytes into `hot_payloads`, sets residency to
   `hot`, decrements cold bytes/count, refreshes owner views.
6. On failure: marks evicted, decrements cold count, refreshes owner
   views.

The duplicate-success and stale-success branches in
`handle_promotion_completion` are removed.

### `evict_entry_by_id`

Today: synchronous but interleaved with worker completions from
`update`.

New: `tx_evict_entry(entry_id, reason)` acquires the mutex once and
holds it for the duration. The implementation keeps the same demote-
then-evict ordering. The over-hot-budget guard from D-EXEC-24-01 is
preserved. The token-limit guaranteed-progress fallback from
D-EXEC-24-02 is preserved inside `tx_update`.

### `save_slot`

Today: synchronously admits an entry and schedules demotion
asynchronously.

New: `tx_save(slot, metadata)` acquires the mutex once. The
transaction admits the entry, attaches payload or checkpoint,
schedules demotion via `tx_demote_payload` (now inline), and
refreshes owner views. If admission would exceed hot budget, the
transaction calls `tx_evict_entry` on the eviction plan victim,
then re-attempts admission.

### `try_restore_from_cache`

Today: synchronous plan selection + async cold promotion. Apply step
mutates the live slot without holding any cache-state lock.

New: `tx_restore(slot, task)` acquires the mutex once. The
transaction selects the plan, performs cold promotion inline via
`tx_promote_payload`, refreshes owner views, and returns the plan.
The caller (slot thread) applies the plan to the live slot without
holding the cache-state lock. After apply, the slot thread calls
`tx_apply_restore(slot, plan)` which acquires the mutex once and
finalizes owner-view sync and metrics.

The split between `tx_restore` (under lock) and `tx_apply_restore`
(under lock) is necessary because the slot thread owns the live
`llama_context` for apply and the apply step can take non-trivial
time. Holding the cache-state lock during apply would block every
other transaction for the duration of inference apply.

### `update`

Today: called per scheduler tick from `server_context`. Drains
completions, runs eviction loop, cold cleanup, branch-metadata prune,
token-limit loop.

New: `tx_update()` acquires the mutex once. No more completion
drain. Runs the same eviction loop, cold cleanup, branch-metadata
prune, and token-limit loop as a single transaction. Returns.

The `update()` public override from the base `cache_controller`
becomes a thin wrapper that calls `tx_update()`. The
`process_completions` public method is removed; existing test code
that calls `process_completions` after `debug_stop_io_worker_for_tests`
is updated to call `tx_update` instead. The
`debug_stop_io_worker_for_tests` helper remains so tests still stop
the worker thread cleanly.

## Lock-acquisition pattern in tests

Test-only debug hooks that read controller state outside a
transaction (for assertions in unit tests) are wrapped in a
`tx_debug_read` helper that acquires the mutex, captures the read,
and releases. The existing
`debug_get_residency_state_for_tests` is updated to use this helper.
The pattern is consistent with the new transaction model and keeps
tests readable.
