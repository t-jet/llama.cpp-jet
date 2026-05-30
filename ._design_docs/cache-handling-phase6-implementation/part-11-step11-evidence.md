# Phase 6 implementation evidence - Part 11: Step 11 test hooks and fault injection

Source: [../cache-handling-phase6-implementation.md](../cache-handling-phase6-implementation.md)

## Step 11: Test hooks and fault injection

**Status: COMPLETE**

### Summary

Step 11 added `LLAMA_SERVER_CACHE_TESTS` guarded test hooks for the cold store and worker, and
created fault injection test cases covering all ten fault injection points from design Part 6.

Test hooks added:

- `debug_get_residency_state_for_tests(payload_id)` — reads current residency state
- `debug_inject_promotion_failure_for_tests(payload_id)` — injects promotion failure for a specific payload_id
- `debug_clear_promotion_failures_for_tests()` — clears all injected promotion failures
- `debug_set_cold_store_backend_for_tests()` — replaces real cold store with fake (already existed from Step 5)
- `debug_set_worker_completion_delay_for_tests(ms)` — injects latency (already existed from Step 5)
- `debug_set_worker_queue_capacity_for_tests(n)` — overrides queue depth (already existed from Step 5)

Fault injection test cases (17 total):

1. `debug_get_residency_state_for_tests` reads current residency
2. `debug_inject_promotion_failure_for_tests` causes promotion failure
3. `debug_set_cold_store_backend_for_tests` replaces real cold store
4. `debug_set_worker_completion_delay_for_tests` injects latency
5. `debug_set_worker_queue_capacity_for_tests` overrides queue depth
6. Fault injection: checksum corruption before promotion
7. Fault injection: header truncation (short write)
8. Fault injection: payload_id mismatch
9. Fault injection: pair_state mismatch
10. Fault injection: format_version unknown
11. Fault injection: demotion write failure
12. Fault injection: queue full at demotion
13. Fault injection: queue full at promotion
14. Fault injection: worker thread shutdown race
15. Fault injection: draft-side promotion failure for target_and_draft
16. Fault injection: magic mismatch
17. Fault injection: header checksum mismatch

### Changed files

- `tools/server/server-cache-hybrid.h` — Added `debug_get_residency_state_for_tests()`,
  `debug_inject_promotion_failure_for_tests()`, `debug_clear_promotion_failures_for_tests()`,
  and `debug_promotion_failure_payload_ids_` unordered_set under `LLAMA_SERVER_CACHE_TESTS` guard.
- `tools/server/server-cache-hybrid.cpp` — Added `#ifdef LLAMA_SERVER_CACHE_TESTS` check in
  `handle_promotion_completion()` for injected promotion failures.
- `tests/test-step11-test-hooks-fault-injection.cpp` — 17 test cases covering all Step 11
  requirements.
- `tests/CMakeLists.txt` — Added `test-step11-test-hooks-fault-injection` target.

### Build evidence

```text
cmake --build . --target test-step11-test-hooks-fault-injection --config Release
```

Build succeeded with no errors.

### Test evidence

```text
.\test-step11-test-hooks-fault-injection.exe

==================================================
Step 11: Test hooks and fault injection
==================================================

step11: debug_get_residency_state_for_tests reads current residency...
  PASSED
step11: debug_inject_promotion_failure_for_tests causes promotion failure...
  PASSED
step11: debug_set_cold_store_backend_for_tests replaces real cold store...
  PASSED
step11: debug_set_worker_completion_delay_for_tests injects latency...
  PASSED
step11: debug_set_worker_queue_capacity_for_tests overrides queue depth...
  PASSED
step11: fault injection - checksum corruption before promotion...
  PASSED
step11: fault injection - header truncation (short write)...
  PASSED
step11: fault injection - payload_id mismatch...
  PASSED
step11: fault injection - pair_state mismatch...
  PASSED
step11: fault injection - format_version unknown...
  PASSED
step11: fault injection - demotion write failure...
  PASSED
step11: fault injection - queue full at demotion...
  PASSED
step11: fault injection - queue full at promotion...
  PASSED
step11: fault injection - worker thread shutdown race...
  PASSED
step11: fault injection - draft-side promotion failure for target_and_draft...
  PASSED
step11: fault injection - magic mismatch...
  PASSED
step11: fault injection - header checksum mismatch...
  PASSED

==================================================
Step 11: All tests PASSED
==================================================
```

All 17 tests passed.

### Deviations from plan

None. All test hooks and fault injection points specified in the design are implemented and tested.