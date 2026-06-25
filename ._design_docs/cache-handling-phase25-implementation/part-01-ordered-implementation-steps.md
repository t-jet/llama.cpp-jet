# Stage 25 implementation plan: Part 1: ordered implementation steps

Source: [../cache-handling-phase25-implementation.md](../cache-handling-phase25-implementation.md)

This part specifies the 12 ordered implementation steps for
Stage 25. Each step compiles, keeps the existing test suite
passing, and produces auditable evidence in the implementation
log. Steps 1-2 add the lock without behavior change. Steps 3-5
inline the async paths one at a time. Steps 6-8 add diagnostics,
the reentrancy counter, and lock-ordering documentation.
Steps 9-12 add coverage and the regression pack.

The order matters: any reordering re-introduces the
async-vs-sync race window that the design removes.

## Step 1: introduce cache_state_mutex_

Add `std::recursive_mutex cache_state_mutex_;` to
`hybrid_cache_controller` as a private member. Recursive
because the slot lifecycle and the eviction helpers call each
other and each needs the same lock held for the duration of
its work.

Add the private helper:

```cpp
void tx_assert_mutex_held() const {
    assert(cache_state_mutex_.try_lock() == false);
}
```

The helper is a developer-time guard. It checks that the
caller already holds the lock by attempting a non-blocking
acquire; success means the lock was free, which fails the
assert. The helper is inlined and removes its assertion in
release builds that compile with `NDEBUG`; production code
that fails to hold the lock at the helper entry is a code
defect caught at test time, not at runtime.

No behavior change. Existing 122 tests pass.

## Step 2: refactor io_worker into a synchronous inline helper

Stop starting the `io_worker` thread in the constructor when
`cold_path` is non-empty. Keep `server_cache_io_worker` as a
value member with the same `enqueue_demotion` /
`enqueue_promotion` signatures, but the methods execute
synchronously on the caller and return the completion result
inline.

`io_worker.execute_inline(task)` runs the cold-store read or
write on the calling thread and returns an `io_completion_result`
that the caller inspects inline. The thread primitive is
removed; the queue becomes an internal data structure with no
consumer. The destructor stops the now-absent thread via an
explicit no-op branch.

This is Option B (worker retirement) from OQ-25-02.

No behavior change for callers. Existing 122 tests pass.

## Step 3: tx_demote_payload

Replace `demote_payload` body with a public `tx_demote_payload`
method that:

1. Acquires `std::lock_guard<std::recursive_mutex>` on
   `cache_state_mutex_` at entry.
2. Runs the existing eligibility checks (descriptor exists,
   residency is hot, cold store configured, hot record exists,
   pair state complete, cold budget allows).
3. Sets residency to `demoting`.
4. Calls `io_worker.execute_inline(demote_task)` on the
   calling thread, with the mutex still held.
5. On success: sets cold ref, transitions to `cold`,
   increments cold bytes/count, releases hot bytes,
   refreshes owner views.
6. On failure: reverts to `hot` if hot record present; else
   marks evicted and zeroes resident bytes.

The old async path becomes a private wrapper that asserts
the mutex is held and calls the inline implementation. The
existing Stage 22 idempotent completion handlers
(`handle_demotion_completion` and `handle_promotion_completion`)
remain as private helpers used by the inline implementation,
but their `duplicate_success` and `stale_success_evicted`
branches become no-ops because the inline implementation
executes the success path exactly once.

`tx_assert_mutex_held` is called at the top of each private
helper that mutates cache state.

Existing demotion tests pass (TP-22-UT1..UT8, TP-21-UT4..UT6).

## Step 4: tx_promote_payload

Same pattern as Step 3 for `promote_payload`. The inline
worker call performs the cold-store read and integrity check
on the calling thread under the lock. On success the bytes
are inserted into `hot_payloads`, residency transitions to
`hot`, cold bytes/count decrement, and owner views sync.
On failure the descriptor is marked evicted.

The async `handle_promotion_completion` helper remains for
compatibility with `stage22_handle_demotion_completion` test
access, but the only reachable path is the inline one.

Existing promotion tests pass (TP-22-UT7).

## Step 5: tx_evict_entry, tx_update, tx_save, tx_restore, tx_apply_restore, tx_load

Convert the slot lifecycle and eviction paths to the public
transaction API:

- `tx_evict_entry(entry_id, reason)` acquires the mutex once,
  preserves the demote-then-evict ordering from
  `evict_entry_by_id`, and preserves the over-hot-budget
  guard from D-EXEC-24-01 and the token-limit
  guaranteed-progress fallback from D-EXEC-24-02.
- `tx_update()` acquires the mutex once, runs the eviction
  loop, cold cleanup, branch-metadata prune, and token-limit
  loop as one transaction. No more completion drain.
- `tx_save(slot, metadata)` acquires the mutex once, admits
  the entry, attaches payload or checkpoint, calls
  `tx_demote_payload` inline if needed, refreshes owner
  views. If admission would exceed hot budget, calls
  `tx_evict_entry` on the plan victim first.
- `tx_restore(slot, task)` acquires the mutex once, selects
  the plan, calls `tx_promote_payload` inline if the plan
  selects a cold payload, refreshes owner views, returns
  the plan.
- `tx_apply_restore(slot, plan)` acquires the mutex once,
  finalizes owner-view sync and metrics after the slot
  thread has applied the plan outside the lock. This is the
  OQ-25-01 SPLIT decision.
- `tx_load(slot, task)` acquires the mutex once, returns
  the legacy cache plan.

The recursive mutex allows `tx_save` to call `tx_evict_entry`
and `tx_restore` to call `tx_update` when draining
background state is required before selection. The reentrancy
counter is incremented on transaction entry, decremented on
exit, and rejected at depth 5 (one over the OQ-25-04
default 4).

The slot lifecycle methods in `server-context.cpp`
(`hybrid_cache_controller::save_slot`,
`hybrid_cache_controller::try_restore_from_cache`,
`hybrid_cache_controller::load_slot`) keep the same
signatures and call the new `tx_*` methods.

Existing slot-lifecycle tests pass.

## Step 6: transaction_wait_exceeded diagnostic

Add a bounded diagnostic `cache_diag::transaction_wait_exceeded`
that records:

- thread id (or "server-context" for the background thread)
- transaction method name
- wait time in milliseconds

The diagnostic fires when a slot thread waits more than
`transaction_wait_threshold_ms` (default 500 ms; OQ-25-03).
The wait timer starts at `lock_guard` constructor entry
and stops at `lock_guard` destructor exit. The threshold
check runs on every transaction entry.

The diagnostic does not abort the wait; the design does not
permit preemption of the holder.

## Step 7: reentrancy depth limit + counter

Add a per-thread reentrancy counter. Per OQ-25-06 the counter
is a slot context member (`server_slot::cache_tx_depth`) for
slot threads and a controller member
(`hybrid_cache_controller::server_context_tx_depth_`) for
the server-context thread. The two counters cover the only
two thread types that can enter a transaction.

The counter is incremented at `lock_guard` constructor
entry and decremented at destructor exit. At increment the
counter is compared against `reentrancy_depth_limit` (default
4; OQ-25-04). At limit + 1 the increment is rejected, a
`cache_diag::internal_error` diagnostic is recorded, and
the transaction method returns `false` without mutating
state.

A private `tx_assert_not_reentrant()` helper fails a debug
assert if called from inside a transaction at depth > 0 by
a caller outside the documented inner-call set. In release
builds the helper is a no-op.

## Step 8: lock-ordering documentation + invariant references

Add a brief comment block at the top of
`hybrid_cache_controller::cache_state_mutex_` that names:

- the recursive mutex and what it guards
- the documented inner-call set
  (`tx_save -> tx_evict_entry`, `tx_restore -> tx_update`,
  `tx_update -> tx_evict_entry`)
- the reentrancy depth limit and the diagnostic
- the no-trylock and no-preemption contract

Add a one-line comment at each `tx_*` public method that
references the corresponding design part:

```cpp
// Stage 25: see cache-handling-phase25-design.md part-03
```

Add the same one-line comment at the test-only debug hooks
that the new tests exercise (`debug_get_residency_state_for_tests`,
`debug_run_save_transaction_for_tests`,
`debug_run_restore_transaction_for_tests`).

No behavior change.

## Step 9: regression tests + coverage

Add the regression pack to `tests/test-cache-controller.cpp`:

- TP-25-UT1 atomic transaction blocks concurrent writes
- TP-25-UT2 demote inline under lock
- TP-25-UT3 promote inline under lock
- TP-25-UT4 save admit evict under lock
- TP-25-UT5 restore plan apply split
- TP-25-UT6 reentrancy depth limit
- TP-25-UT7 no async completion drain
- TP-25-UT8 worker thread idle after migration
- TP-25-UT9 transaction_wait_exceeded diagnostic
- TP-25-UT10 concurrent slot requests N=4 contention

Each test registers in `main()` and the printed total
updates from 122 to 132.

## Step 10: focused test pack re-run

Run the existing Stage 17, 21, 22, 23, 24 unit test pack on
the new binary. Required PASS lines:

- TP-17-UT*, TP-21-UT*, TP-22-UT*, TP-23-UT*, TP-24-UT* all
  unchanged in their assertions.
- TP-22-UT1..UT8 cover demotion success, duplicate success,
  stale success, failure-with-hot-bytes, failure-without-hot-bytes,
  target/draft idempotence, demote-in-progress, demoting-with-hot-bytes.
- TP-24-UT1..UT2 cover over-hot-budget demote-skip and
  token-limit force-evict.

Failure of any TP-NN row blocks Stage 25 handoff.

## Step 11: full test pack + Stage 24 chat rerun

Run the full 132-test pack with `--assert` style exit codes.
Then run the Stage 24 chat S02/S03 comparison on the new
binary using the existing `stage24-chat-s02-s03-comparison.ps1`
runner and the same Qwen3.5-4B MTP fixture. Compare p50 and
p99 latency against the Stage 24 -06 baseline; document the
regression per Part 4 of the design.

## Step 12: implementation review handoff

Update this implementation log with the final state, the
changed-file list, the test count, the binary mtimes, the
exit codes, and any warnings emitted by the new tests.

Submit to Architect for implementation review (D25-EXEC-01
gate). After review PASS and Manager implementation gate
D25-IMPLEMENT-PLAN-02, QA executes the Stage 25 test plan.

## Step-to-binding mapping

| Step | Design part binding |
| --- | --- |
| 1 | Part 2 lock granularity |
| 2 | Part 2 worker retirement Option B |
| 3 | Part 3 rows 1, 3, 23 |
| 4 | Part 3 rows 2, 4, 22 |
| 5 | Part 3 rows 5-21 |
| 6 | Part 2 timeout and deadlock detection |
| 7 | Part 2 reentrancy rule |
| 8 | Part 6 new invariants I-25-01..03 |
| 9 | Part 5 step 7 |
| 10 | Part 5 step 8 |
| 11 | Part 5 step 9 |
| 12 | Implementation contract |
