# Stage 25 design: Part 2: atomic transaction protocol

Source: [../cache-handling-phase25-design.md](../cache-handling-phase25-design.md)

This part defines the transaction protocol that Part 3 implements.

## Lock granularity

The protocol uses one lock: `cache_state_mutex_`, a
`std::recursive_mutex` on the controller instance. Recursive because
the slot lifecycle (Part 3 row 19-21) and the eviction paths (rows
7-10) call multiple operations that each need the same lock held for
the duration of their work. The lock guards the controller's mutable
state:

- `entries`, `forest`, `lru_index`, `prefix_index`
- `payload_descriptors`, `hot_payloads`
- `cold_store` (writes and deletes; reads through `promote_payload`
  must also hold the lock because cold files back descriptors that
  can be evicted under the lock)
- cold and hot accounting counters
- `n_cold_payload_bytes`, `n_cold_payload_count`, `resident_payload_bytes`,
  per-shape counters, and the latency histogram

The lock does not guard:

- the `io_worker` thread primitive itself (the worker is repurposed
  to a synchronous helper invoked under lock; see "Worker retirement"
  below)
- the `llama_context` (slot thread and `try_restore_from_cache` own
  the live slot's context for the duration of apply; this lock only
  orders cache-state mutations, not inference)
- the `server_slot` (the slot thread owns its own slot)

Per-entry and per-payload locks were considered and rejected:

- A single slot request can touch multiple entries (e.g., a save that
  promotes cold bytes and demotes a different hot entry). Per-entry
  locks acquire-and-release across helpers and reintroduce the same
  race windows.
- A per-payload lock cannot order entry-level operations such as
  branch-node sync that spans multiple entries owned by the same
  payload.

Per-slot locking is rejected for the same reason: the cache state
owns the truth, not the slot.

## Acquisition and release ordering vs slot lifecycle

The slot lifecycle has four external touch points. Each acquires
`cache_state_mutex_` once at entry and releases once at exit:

1. `try_restore_from_cache(slot, task)`: acquires at entry. The
   transaction selects the restore plan, performs cold promotion
   inline, refreshes owner views, and returns a `RestorePlan`. The
   apply step that mutates the live slot is NOT inside this
   transaction; the slot thread owns the live context for apply and
   the cache apply path uses a separate second-pass critical section
   after apply (see Part 3 row 20).
2. `save_slot(slot, metadata)`: acquires at entry. The transaction
   admits the entry, attaches or reuses a descriptor, schedules
   demotion if needed, refreshes owner views, and returns. No live
   slot mutation.
3. `load_slot(slot, task)` legacy: acquires at entry. Returns a
   legacy cache plan without touching cold store.
4. `update`: acquires at entry. The transaction drains any
   in-flight state, runs the eviction loop, the cold-budget loop, and
   the token-limit loop. Returns.

The lock is non-trylock. The slot thread blocks until the lock is
free. The lock is not interruptible by signal because Windows SEH is
out of scope and the controller does not own signal handlers.

## What "transaction" means

A transaction is one critical section during which the cache state
mutates as if all operations inside the section happened at one
instant. The public transaction methods are:

| Method | Operations inside the section |
| --- | --- |
| `tx_restore(slot, task)` | select plan, validate namespace and pair, find match, promote cold if needed, compute restore plan |
| `tx_save(slot, metadata)` | admit entry, attach payload or checkpoint, schedule demotion, refresh owner views |
| `tx_load(slot, task)` | legacy restore plan |
| `tx_evict_entry(entry_id, reason)` | demote-or-evict per `mark_payload_evicted`, remove entry if safe, sync branch node |
| `tx_update()` | drain worker state inline, run eviction loop, cold cleanup, token-limit loop |

Each public method begins with `std::lock_guard<std::recursive_mutex>`
on `cache_state_mutex_` and ends with the guard going out of scope.
Helper methods that mutate cache state are private and assume the
lock is already held; they assert via `cache_state_mutex_.try_lock()`
and immediately unlock on entry as a developer-time guard.

## Reentrancy rule

A transaction method may call another transaction method on the same
controller instance. The recursive mutex allows this. A reentrant
call from inside a transaction must be one of the documented inner
operations:

- `tx_save` may call `tx_evict_entry` when the budget would be
  exceeded by admission.
- `tx_restore` may call `tx_update` to drain background state before
  selection.
- `tx_update` may call `tx_evict_entry` repeatedly until the budget
  is satisfied.

Any other reentrant call is rejected by `tx_assert_not_reentrant()`
helper that fails an internal assert in debug builds and returns
`false` in release builds with a bounded `cache_diag::internal_error`
diagnostic. Slot code paths do not call transaction methods directly;
they go through the public entry points.

A reentrancy depth counter is maintained as a per-thread counter on
the slot thread or the server-context thread. The depth limit is 4.
Cross-thread reentrancy is impossible because the worker thread no
longer mutates controller state.

## Timeout and deadlock detection

The controller does not implement a per-transaction timeout. The slot
thread blocks on the mutex for as long as the holder needs. A bounded
diagnostic `cache_diag::transaction_wait_exceeded` is recorded when a
slot thread waits more than `transaction_wait_threshold_ms` (default
500 ms). The diagnostic does not abort the wait; the design does not
permit preemption of the holder because doing so would re-introduce
the partial-state problem this stage is designed to remove.

Deadlock detection relies on the reentrancy depth counter and the
documented inner-call set. The transaction methods never call each
other transitively beyond depth 4. The `try_lock` assert at the top
of each private helper is a developer-time guard against future code
that calls a helper from outside a transaction.

A future stage may add a timeout with a forced-rollback path. That is
explicitly out of scope for Stage 25 because it requires a way to
abort a transaction mid-flight (see "Failure mode" below) which is a
new capability not introduced here.

## Failure mode

If a transaction aborts mid-flight, partial state recovery follows
this order:

1. The transaction method returns `false` to the caller with a
   diagnostic.
2. The lock is released by guard destruction.
3. The controller's `tx_abort_cleanup()` runs at the top of the next
   transaction: it scans `payload_descriptors` for any descriptor
   whose residency is `demoting` or `promoting` and reverts it to the
   pre-transaction residency recorded in a per-descriptor shadow
   field `pre_tx_residency_`. It scans `hot_payloads` for any record
   whose `payload_id` matches a reverted descriptor and re-inserts
   the bytes from a shadow copy `pre_tx_bytes_`. It scans `entries`
   for any entry whose `payload_id` matches a reverted descriptor
   and refreshes accounting from the shadow.

The shadow fields are only populated inside a transaction. Outside a
transaction they are empty. The cleanup runs synchronously inside the
next transaction's critical section so it cannot race with a
concurrent operation.

Stage 25 does not implement transaction abort. The transaction
methods either complete or return false before mutating any field.
Pre-validation (eligibility checks) runs first; mutation only begins
after all eligibility is confirmed. This is the simpler alternative
and matches the user's stated intent: every operation that needs to
mutate cache state does so under one lock with the entire operation
in the section.

If the implementation later needs to abort mid-flight, the failure
mode contract above is the migration path.

## Worker retirement

The `io_worker` thread is repurposed. The implementation has two
options:

- Option A: keep `io_worker` as a `std::thread` that drains a queue,
  but the queue is no longer fed from slot threads. The slot threads
  call `io_worker.execute_inline(task)` which runs the task on the
  caller's thread under the cache-state lock. The thread stays
  asleep forever; tests and metrics continue to work.
- Option B: replace `io_worker` with a stateless helper module that
  exposes the same `enqueue_demotion` and `enqueue_promotion` API
  but executes synchronously on the caller. Remove the thread and
  the queue. Tests and metrics must be updated.

The Manager design gate must pick one. Part 3 is written so both
options are implementable. Stage 25 implementation planning records
the final choice.
