# Stage 25 implementation plan: Part 4: risks and dependencies

Source: [../cache-handling-phase25-implementation.md](../cache-handling-phase25-implementation.md)

This part enumerates the implementation risks, the
dependency matrix, and the rollback strategy.

## Implementation risks

### R-25-IMP-01 lock contention under high concurrency

Two or more slot threads entering `tx_save` or `tx_restore`
simultaneously serialize through `cache_state_mutex_`. The
expected regression per design Part 4 is 0-5% for hot-only
workloads and 30-50% for cold-dominated workloads.

Severity: medium.

Mitigation:

- The 500 ms `transaction_wait_exceeded` diagnostic
  (Step 6) records when contention exceeds the threshold.
- TP-25-UT10 exercises N=4 contention and asserts the
  four transactions complete in serial order without
  crashing.
- The Stage 24 chat rerun in Step 11 captures p50 and p99
  latency against the -06 baseline; document the regression
  per Part 4.

### R-25-IMP-02 cold-store I/O blocks slot request latency

Inline demotion and promotion move disk-write and disk-read
latency onto the slot thread's critical path. Today the
worker thread absorbs the latency.

Severity: medium.

Mitigation:

- The cold-promotion latency histogram from Stage 6 is
  preserved; the bucket distribution shifts toward higher
  buckets because the cold read is now on the slot thread.
- The Stage 24 chat rerun captures the empirical latency
  shift.
- TP-25-UT2 and TP-25-UT3 cover the cold and hot residency
  transitions and assert the byte record state after the
  call returns.

### R-25-IMP-03 reentrancy depth limit too low

The default 4 (OQ-25-04) permits the documented inner-call
set (`tx_save -> tx_evict_entry`, `tx_restore -> tx_update`,
`tx_update -> tx_evict_entry`). A future code change that
adds a deeper call chain fails at depth 5 and emits a
diagnostic.

Severity: low.

Mitigation:

- TP-25-UT6 exercises depth 5 and asserts the rejection
  path returns false without mutating state.
- The depth limit is configurable; if a deeper call chain
  is required, the limit can be raised without code
  restructuring.

### R-25-IMP-04 Stage 16 chat-path boundary regression

The Stage 16 chat-path prompt-span boundary invariant
(architecture part 9) is preserved but the slot lifecycle
now goes through `tx_restore` + `tx_apply_restore` instead
of `try_restore_from_cache` + direct apply. The plan
preserves the boundary propagation through the slot
lifecycle.

Severity: medium.

Mitigation:

- TP-21-UT1..UT6 unchanged assertions cover the exact-repeat
  path.
- The Stage 24 chat S02 rerun in Step 11 verifies the
  hybrid near-prefix `cache_n=0` count is preserved.
- If a regression appears, classify per the existing
  test-results review gate as F-16-TR-* and escalate.

### R-25-IMP-05 Stage 24 D-EXEC-24-03 silent crash

The S03 hybrid silent crash from Stage 24 closure is a
separate investigation tracked under D-CLOSURE-24-01 (b).
The synchronous model removes async races but does not
diagnose the underlying Windows process termination.

Severity: medium.

Mitigation:

- The Stage 24 chat rerun in Step 11 reproduces the S03
  binary on the new controller. If the crash reproduces,
  classify per D-EXEC-24-03 as BLOCKED-structural-not-infra
  and leave for the future S03 crash investigation stage.
- The future-stage SEH handler from D-CLOSURE-24-01 (a)
  would have preserved a crash dump for diagnosis; that
  follow-up remains open.

### R-25-IMP-06 existing test hooks rely on worker completion

Tests that call `debug_stop_io_worker_for_tests()` and
then call `process_completions()` to drain queued
completions (e.g., TP-22-UT1, TP-22-UT2) assume the
async model. After Stage 25 there are no queued
completions because the inline implementation executes
synchronously.

Severity: low.

Mitigation:

- TP-22-UT1..UT8 keep their existing assertions because
  the inline implementation produces the same observable
  state. The helper `stage22_handle_demotion_completion`
  remains available for tests that need to inject a
  specific completion result.
- The `debug_stop_io_worker_for_tests` helper stays for
  cleanup symmetry; the `process_completions()` call
  inside it becomes a no-op.

### R-25-IMP-07 public metric shape drift if internal counters leak

The two new internal counters (`n_transaction_wait_exceeded`
and `n_transaction_depth_*`) are debug-only and not exposed
through `/metrics`. If a future change accidentally exposes
them, the public metric shape drifts.

Severity: low.

Mitigation:

- Part 2 records the public-metric policy explicitly.
- The implementation log Step 12 records the policy in the
  implementation review.

### R-25-IMP-08 worker retirement Option B confuses future readers

Replacing `io_worker` thread with a stateless inline helper
removes a long-lived thread that future readers may expect.

Severity: low.

Mitigation:

- The `server_cache_io_worker` class keeps the same
  `enqueue_demotion` and `enqueue_promotion` signatures
  for source compatibility; the methods execute
  synchronously.
- The lock-ordering documentation in Step 8 names the
  new model.

## Dependency matrix

| Dependency | Source | Used by | Required at |
| --- | --- | --- | --- |
| `std::recursive_mutex` | `<mutex>` | Step 1 | Implementation start |
| `cache_state_mutex_` member | Step 1 | Steps 3-8 | Step 1 complete |
| `tx_assert_mutex_held` helper | Step 1 | All private helpers | Step 1 complete |
| `io_worker.execute_inline` | Step 2 | Steps 3, 4 | Step 2 complete |
| `tx_demote_payload` | Step 3 | Steps 5, 9, 10 | Step 3 complete |
| `tx_promote_payload` | Step 4 | Steps 5, 9, 10 | Step 4 complete |
| `tx_evict_entry` | Step 5 | `tx_save`, `tx_update`, Step 9 | Step 5 complete |
| `tx_update` | Step 5 | `tx_restore`, Step 9 | Step 5 complete |
| `tx_save`, `tx_restore`, `tx_apply_restore`, `tx_load` | Step 5 | Step 9 | Step 5 complete |
| `transaction_wait_exceeded` | Step 6 | Step 9 (TP-25-UT9) | Step 6 complete |
| Reentrancy counter | Step 7 | Step 9 (TP-25-UT6) | Step 7 complete |
| Lock-ordering docs | Step 8 | Implementation review | Step 8 complete |
| Test pack | Step 9 | Steps 10, 11 | Step 9 complete |
| Existing TP-22 test pack | Stage 22 | Steps 10, 11 | Pre-existing |
| Stage 24 chat runner | Stage 24 | Step 11 | Pre-existing |
| `build-cuda` binary path | Stage 24 | Step 11 | Pre-existing |

## Rollback strategy

Rollback is file-scoped:

1. Revert only Stage 25 edits in
   `tools/server/server-cache-hybrid.cpp`,
   `tools/server/server-cache-hybrid.h`,
   `tools/server/server-context.cpp`, and the new
   `tests/test-cache-controller.cpp` additions.
2. Keep F-21-EXEC-01 prompt-only save behavior
   (TP-21-UT1..UT3 unchanged).
3. Keep F-21-RERUN-01 demoting-budget behavior
   (TP-21-UT4..UT6 unchanged).
4. Keep F-22-DR-01 demote-already-demoting check
   (TP-22-UT8 unchanged).
5. Keep Stage 22 idempotent completion helpers (the
   `duplicate_success` and `stale_success_evicted` branches
   return to active paths if the inline implementation is
   reverted).
6. Keep D-EXEC-24-01 over-hot-budget guard.
7. Keep D-EXEC-24-02 token-limit guaranteed-progress
   fallback.
8. Keep Stage 16 chat-path prompt-span boundary invariant.
9. Leave Stage 24 closed; S03 silent-crash investigation
   remains open as a future stage.
10. Remove the `cache_state_mutex_` member and all `tx_*`
    methods.

If rollback is needed after implementation starts,
Developer must record which Step failed and whether any
earlier invariant regressed. The rollback does NOT require
data migration; the cold-store on-disk format is unchanged
and the descriptor transition order is unchanged.

## Handoff state at end of part 4

The plan has recorded:

- 8 implementation risks with mitigations
- 12-step dependency matrix
- 10-step rollback procedure
- alignment with all preserved invariants

Part 5 records the OQ decisions and rationale. Part 6
records the open implementation questions for Architect
review.
