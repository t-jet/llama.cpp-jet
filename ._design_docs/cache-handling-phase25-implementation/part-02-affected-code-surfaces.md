# Stage 25 implementation plan: Part 2: affected code surfaces

Source: [../cache-handling-phase25-implementation.md](../cache-handling-phase25-implementation.md)

This part inventories the code surfaces that Stage 25 changes
and the public API surface that Stage 25 preserves.

## Production code surfaces

### tools/server/server-cache-hybrid.h

- Add `#include <mutex>` for `std::recursive_mutex`.
- Add private member `std::recursive_mutex cache_state_mutex_;`
  declared near the existing private members around
  `cold_store` and `io_worker` (line ~565).
- Add private member
  `size_t server_context_tx_depth_ = 0;` near the
  reentrancy state.
- Add public method declarations for the transaction API in
  the existing public block:
  - `bool tx_save(server_slot & slot, const prepared_prompt_metadata & metadata);`
  - `cache_response tx_restore(server_slot & slot, const server_task & task);`
  - `void tx_apply_restore(server_slot & slot, const cache_response & plan);`
  - `bool tx_load(server_slot & slot, const server_task & task);`
  - `bool tx_evict_entry(uint64_t entry_id, server_cache_eviction_reason reason);`
  - `void tx_update();`
  - `bool tx_demote_payload(uint64_t payload_id);`
  - `bool tx_promote_payload(uint64_t payload_id);`
  - `bool tx_cold_budget_make_room(size_t bytes, const payload_descriptor & descriptor);`
- Add private helper declarations:
  - `void tx_assert_mutex_held() const;`
  - `void tx_assert_not_reentrant() const;`
- Add test-only debug hook for transaction results:
  - `json debug_run_save_transaction_for_tests(server_slot & slot, const prepared_prompt_metadata & metadata);`
  - `cache_response debug_run_restore_transaction_for_tests(server_slot & slot, const server_task & task);`
- Bump the inner reentrancy limit field declaration from
  absent to `size_t reentrancy_depth_limit_ = 4;` and the
  wait threshold field to
  `std::chrono::milliseconds transaction_wait_threshold_{500};`.

Total estimated delta: +12 declarations, +1 include.

### tools/server/server-cache-hybrid.cpp

- Constructor (`hybrid_cache_controller(...)` line 310):
  remove `io_worker.set_cold_store(&cold_store)` and
  `io_worker.start()` (Step 2). Replace the call with a
  one-line note that cold-store access happens inline
  through `io_worker.execute_inline(...)`.
- Destructor (`hybrid_cache_controller(...)` line 358):
  remove `if (io_worker.is_running()) io_worker.stop();`.
  Replace with a one-line note that the worker thread no
  longer exists.
- `demote_payload` (line 365) -> renamed body to
  `tx_demote_payload` with a `lock_guard` at the top; the
  old `demote_payload` becomes a thin wrapper that asserts
  the lock and forwards. ~110 lines touched (est. ~80%).
- `promote_payload` (line 472) -> renamed body to
  `tx_promote_payload` with a `lock_guard` at the top;
  the old `promote_payload` becomes a thin wrapper.
  ~70 lines touched (est. ~80%).
- `process_completions` (line 542) -> removed; the function
  body becomes a no-op stub that returns immediately and
  is kept only to satisfy the existing `debug_stop_io_worker_for_tests`
  test helper. The helper is updated to no longer call
  `process_completions()`. ~10 lines touched.
- `handle_demotion_completion` (line 652) -> kept as a
  private helper used by `tx_demote_payload`; the
  `duplicate_success` and `stale_success_evicted` branches
  become unreachable because the inline implementation
  executes the success path exactly once. ~120 lines
  touched; net logic reduction ~30 lines.
- `handle_promotion_completion` (line 774) -> same pattern
  as `handle_demotion_completion`. ~110 lines touched; net
  logic reduction ~25 lines.
- `update` (line 914) -> renamed body to `tx_update` with a
  `lock_guard` at the top. The `process_completions()` call
  is removed. The eviction loop, cold cleanup,
  branch-metadata prune, and token-limit loop stay in
  place inside the same critical section. ~85 lines
  touched; net logic reduction ~5 lines (the
  process_completions call).
- `evict_entry_by_id` (line 2186) -> renamed body to
  `tx_evict_entry` with a `lock_guard` at the top. ~65
  lines touched (est. ~70%).
- `mark_payload_evicted` (line 3331),
  `mark_payload_kind_evicted` (private helper), and
  `cold_budget_make_room` (line 579) -> wrapped in
  `lock_guard` at the top of each. `cold_budget_make_room`
  is renamed to `tx_cold_budget_make_room`. ~60 lines
  touched across the three (est. ~70%).
- `attach_payload` (two overloads, line ~3446) and
  `admit_entry_with_payload` (line ~3028) -> wrapped in
  `lock_guard` at the top of each. ~80 lines touched
  (est. ~60%).
- `materialize_entry_payload` (private) -> wrapped in
  `lock_guard`. ~50 lines touched (est. ~60%).
- `remove_payload` (line 3235) -> wrapped in `lock_guard`.
  ~25 lines touched (est. ~80%).
- `refresh_entry_payload_accounting` and
  `sync_branch_node_from_entry` -> add
  `tx_assert_mutex_held()` call at the top of each. ~5
  lines added.
- `update()` public override -> thin wrapper that calls
  `tx_update()`. 4 lines added.

Total estimated delta: ~800 lines touched, ~60 lines net
additions, ~5 lines net deletions.

### tools/server/server-context.cpp

The slot lifecycle methods for the hybrid controller live
in `server-context.cpp`. They keep the same signatures and
call the new `tx_*` methods:

- `hybrid_cache_controller::save_slot` (line 6362) ->
  body unchanged except the eligibility check now calls
  `tx_demote_payload` instead of `demote_payload`, and
  the admit path calls `tx_evict_entry` instead of
  `evict_entry_by_id`. ~3 call sites updated.
- `hybrid_cache_controller::try_restore_from_cache`
  (line 6516) -> body refactored to call `tx_restore`
  for plan selection and `tx_apply_restore` after the
  slot thread applies the plan. The inline promotion
  replaces the old `promote_payload` call. ~6 call
  sites updated; ~10 lines added for the
  `tx_apply_restore` invocation.
- `hybrid_cache_controller::load_slot` (line 6859) ->
  body unchanged except it calls `tx_load` instead of
  `load_slot` internally. ~2 call sites updated.

Call sites in `server-context.cpp` at lines 1087, 1858,
1881, 1886, 4080, 4201 keep the same signatures and
dispatch unchanged.

Total estimated delta: ~20 lines touched.

### tests/test-cache-controller.cpp

- Add 10 new unit tests near the existing
  `test_stage24_*` block (line ~3300).
- Register each in `main()` after the Stage 22 tests
  (line ~4500).
- Update the printed total from 122 to 132.
- Add test helpers as needed:
  - `stage25_wait_for_lock_diagnostic_for_tests(ctrl)`
    to capture the diagnostic counter
  - `stage25_force_reentrant_call_for_tests(ctrl)` to
    drive the reentrancy counter to depth 5

Total estimated delta: ~350 lines added.

## Public API surface (UNCHANGED)

Stage 25 does NOT change any of the following:

- The CLI flags (`--cache-mode`, `--cache-ram`,
  `--cache-cold-path`, `--cache-cold-max-mib`,
  `--cache-prompt-evidence`).
- The public endpoint schemas (`/completion`,
  `/v1/chat/completions`, `/v1/embeddings`).
- The public Prometheus metric names (no new public
  counters; all new internal counters are debug-only).
- The cache-controller abstract interface signatures
  (`save_slot`, `load_slot`, `update`, `get_stats`).
- The hybrid cache controller public method signatures
  (`save_slot`, `try_restore_from_cache`, `load_slot`,
  `update`, `get_stats`, `size`, `n_tokens`,
  `release_branch_node_ref`).
- The `demote_payload` and `promote_payload` public
  method signatures (the bodies route to `tx_*`).
- The cold-store on-disk format.
- The runner scripts.
- The CMake build files.

## Public metric shape (UNCHANGED)

No new public metric names. The two new internal counters
(`n_transaction_wait_exceeded` and
`n_transaction_depth_*`) are debug-only and not exposed
through `/metrics`. This is the documented Part 5
backward-compatibility contract.

## Test-only debug hooks (ADDED)

Three new test-only hooks under
`#ifdef LLAMA_SERVER_CACHE_TESTS`:

- `json debug_run_save_transaction_for_tests(...)` -
  exposes the `tx_save` return value as JSON for assertions.
- `cache_response debug_run_restore_transaction_for_tests(...)` -
  exposes the `tx_restore` plan for assertions.
- `size_t debug_get_transaction_depth_for_tests() const` -
  exposes the reentrancy counter value for assertions.

These hooks match the existing pattern in
`debug_get_residency_state_for_tests` and
`debug_stop_io_worker_for_tests`.

## Affected line counts summary

| File | Lines today | Lines touched (est.) | Lines added (est.) | Lines removed (est.) |
| --- | --- | --- | --- | --- |
| `tools/server/server-cache-hybrid.h` | 894 | ~25 | ~20 | ~5 |
| `tools/server/server-cache-hybrid.cpp` | 4385 | ~800 | ~70 | ~10 |
| `tools/server/server-context.cpp` | ~7700 | ~25 | ~15 | ~5 |
| `tests/test-cache-controller.cpp` | 4521 | ~350 | ~350 | 0 |

Production code total: ~850 lines touched,
~105 lines added, ~20 lines removed. Net production-code
additions ~85 lines.

New tests: 10 unit tests (TP-25-UT1..UT10).

Test infrastructure: no (no new fixtures, no new helpers
beyond what Step 9 specifies; the existing
`stage22_handle_demotion_completion` test access pattern is
reused).
