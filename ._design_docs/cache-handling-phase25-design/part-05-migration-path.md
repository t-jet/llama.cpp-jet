# Stage 25 design: Part 5: migration path

Source: [../cache-handling-phase25-design.md](../cache-handling-phase25-design.md)

This part specifies the migration ordering, backward-compatibility
contract, rollback strategy, and the relationship to existing Stage
15-24 evidence.

## Step-by-step code transition

The migration is sequenced so that each step compiles, the existing
test suite continues to pass, and the new transaction layer is
introduced incrementally:

1. Introduce the recursive mutex and the `tx_assert_mutex_held`
   helper. No behavior change. Existing 97+ test-cache-controller
   tests pass.
2. Wrap the existing `update`, `evict_entry_by_id`,
   `mark_payload_evicted`, `mark_payload_kind_evicted`,
   `cold_budget_make_room`, `attach_payload`,
   `admit_entry_with_payload`, `materialize_entry_payload`, and
   `remove_payload` helpers in a single `std::lock_guard` at the
   top of each public function. Helpers that today call each other
   become private and assert the mutex is held by the caller. The
   public functions acquire the mutex on entry and release on exit.
   The existing tests pass; behavior unchanged.
3. Inline `process_completions` and `handle_demotion_completion`
   into a synchronous `tx_demote_payload` helper. The async path
   becomes a no-op alias that calls the synchronous helper. The
   worker thread stays alive but is never fed. The
   `debug_stop_io_worker_for_tests` helper stays as a cleanup hook.
   Existing demotion tests pass.
4. Inline `handle_promotion_completion` into a synchronous
   `tx_promote_payload` helper. Same pattern as step 3. Existing
   promotion tests pass.
5. Convert `save_slot`, `try_restore_from_cache`, and `load_slot`
   to `tx_save`, `tx_restore` + `tx_apply_restore`, and `tx_load`.
   The slot lifecycle calls the new transaction methods. The
   recursive mutex allows `tx_save` to call `tx_evict_entry` and
   `tx_restore` to call `tx_promote_payload`. Existing slot-lifecycle
   tests pass.
6. Add the `transaction_wait_exceeded` diagnostic and the
   `tx_debug_read` helper for tests. Existing tests pass with the
   new diagnostic appearing in verbose logs.
7. Add new test coverage:
   - `test_stage25_atomic_transaction_blocks_concurrent_writes`
   - `test_stage25_demote_inline_under_lock`
   - `test_stage25_promote_inline_under_lock`
   - `test_stage25_save_admit_evict_under_lock`
   - `test_stage25_restore_plan_apply_split`
   - `test_stage25_reentrancy_depth_limit`
   - `test_stage25_no_async_completion_drain`
   - `test_stage25_worker_thread_idle_after_migration`
8. Run the existing Stage 17, 21, 22 unit test pack
   (TP-17-UT*, TP-21-UT*, TP-22-UT*, the new TP-24 over-budget and
   token-limit tests). All must pass.
9. Run the existing Stage 24 chat S02/S03 fixture on the new
   binary. Compare p50 and p99 latency and throughput against the
   Stage 24 -06 baseline. Estimate the regression against Part 4.

The order is important: step 1-2 add the lock without behavior
change. Step 3-5 inline the async paths one at a time so each
intermediate state is testable. Step 6-7 add new diagnostics and
tests. Step 8-9 verify regression and add evidence.

## Backward compatibility

The migration is backward compatible with the public API. Existing
slot lifecycle callers see the same behavior, the same return
values, and the same metrics. The recursive mutex is an internal
implementation detail.

Existing tests must continue to pass without modification. The
migration does not modify any test in `tests/test-cache-controller.cpp`.
If a test asserts on a specific thread id or completion order that
the synchronous model changes, the test is updated to assert on the
new observable behavior (residency after `tx_*` returns) instead of
the old behavior (residency after worker completes).

Public metric names and shapes remain unchanged. Internal counters
gain a few new fields:

- `n_transaction_wait_exceeded` (slot threads that waited over the
  threshold)
- `n_transaction_depth_*` (per-depth transaction entry counts)

Internal counters are debug-only and not exposed through the public
Prometheus endpoint.

## Rollback strategy

Rollback is file-scoped:

- Revert only Stage 25 edits in `tools/server/server-cache-hybrid.cpp`,
  `tools/server/server-cache-hybrid.h`, and the new
  `tests/test-cache-controller.cpp` additions.
- Keep F-21-EXEC-01 prompt-only save behavior.
- Keep F-21-RERUN-01 demoting-budget behavior.
- Keep Stage 22 idempotent completion helpers (they are no-ops under
  the synchronous model and remain in place after rollback).
- Keep D-EXEC-24-01 over-budget guard.
- Keep D-EXEC-24-02 token-limit guaranteed-progress fallback.
- Leave Stage 24 closed and the S03 silent-crash investigation
  (D-CLOSURE-24-01 b) open as a future stage.

If rollback is needed after implementation starts, Developer must
record which Stage 25 test failed and whether any earlier invariant
regressed.

## Stages 15-24 evidence applicability

| Stage | Test scope | Re-runnable on Stage 25 binary |
| --- | --- | --- |
| 15 | full test suite, benchmark report | yes; p50/p99 latency expected to rise per Part 4 |
| 17 | TP-17-UT* unit tests, restore-miss, prompt-evidence | yes; cold-budget and restore-miss metrics still apply |
| 21 | TP-21-UT*, heavy tier chat-feasible | yes; exact-repeat behavior preserved |
| 22 | TP-22-UT*, demotion coordination | yes; idempotent completion is folded into inline |
| 23 | full S/L matrix | yes; S02/S03 expected to pass with regression per Part 4 |
| 24 | chat S02/S03 native-vs-hybrid | yes; S02 expected PASS, S03 expected PASS or BLOCKED-structural (D-EXEC-24-03) |

Stages 15-24 evidence is preserved as historical record. New
evidence is captured in `cache-handling-phase25-implementation.md`
and the QA test reports for Stage 25. The Stage 24 chat S02/S03
runner script is unchanged; only the binary under test changes.

## Manager-gate questions

Implementation planning must decide:

- Worker retirement: Option A (keep thread, call inline) or Option B
  (replace thread with stateless helper).
- Diagnostic threshold default for `transaction_wait_exceeded`
  (suggested 500 ms).
- Reentrancy depth limit (suggested 4).

The design is implementable under either worker retirement option
and either default. Stage 25 implementation planning records the
final choice.
