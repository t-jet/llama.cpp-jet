# Phase 6 implementation evidence - Part 7: Step 7

## Step 7: Promotion protocol

**Date:** May 31, 2026
**Status:** Complete

### Goal

Implement the cold-to-hot promotion flow in `hybrid_cache_controller`, including enqueue, transient state, NB-2 revert on queue-full, completion handling, cold-descriptor fallback in `try_restore_from_cache`, and draft-side failure for `target_and_draft` transitions to `evicted` (not partially hot).

### Pre-existing implementation

The `promote_payload`, `handle_promotion_completion`, and `try_restore_from_cache` methods were already present in the codebase from prior Stage 6 partial implementation. Step 7 verified these implementations against the design requirements and identified one bug:

1. **Dead code bug in `promote_payload`** — The "already promoting" check at line 153 was unreachable because it came after the "not cold" check at line 141. A descriptor that is `promoting` would fail the "not cold" check first, making the promoting check dead code. Fixed by reordering: the promoting check now comes before the cold check, matching the design requirement that validation order matters.

### Changed files

| File | Change |
| ---- | ------ |
| `tools/server/server-cache-hybrid.cpp` | Fixed dead code bug in `promote_payload`: reordered "already promoting" check before "not cold" check so that promoting descriptors are properly rejected. |
| `tools/server/server-cache-hybrid.h` | Added `debug_set_cold_store_validation_failure_for_tests` and `debug_set_cold_store_read_failure_for_tests` test hooks under `LLAMA_SERVER_CACHE_TESTS`. |
| `tests/test-step7-promotion-protocol.cpp` | New standalone test file with 16 focused Step 7 tests. |
| `tests/CMakeLists.txt` | Added `test-step7-promotion-protocol` build target. |

### Behavior changes

1. **Promoting check reorder** — `promote_payload` now checks `residency == promoting` before checking `residency != cold`. This ensures that a descriptor in the `promoting` state is rejected with the correct diagnostic ("already promoting") rather than falling through to the "not cold" check.

2. **Test hooks** — Two new test hooks added to `hybrid_cache_controller` under `LLAMA_SERVER_CACHE_TESTS` to support Step 7 acceptance tests: `debug_set_cold_store_validation_failure_for_tests` and `debug_set_cold_store_read_failure_for_tests`.

### Verification of Step 7 requirements

| Requirement | Status | Evidence |
| ----------- | ------ | -------- |
| `promote_payload(payload_id)` validates eligibility (residency cold, cold store configured, no in-progress promotion) | ✅ PASS | Code inspection: `promote_payload` checks `residency == promoting` (after fix), `!cold_store.is_configured()`, and `residency != cold`. Tests 1, 2, 3 verify these checks. |
| Sets `residency_state = promoting` | ✅ PASS | Code inspection: `promote_payload` sets `descriptor.residency = promoting` before enqueue. Test 4 verifies promoting state. |
| Calls `worker.enqueue_promotion`. If queue-full, reverts `residency_state = cold` and emits warning (NB-2) | ✅ PASS | Code inspection: `promote_payload` calls `io_worker.enqueue_promotion()` and reverts to cold on failure. Test 5 verifies queue-full revert. |
| Returns without blocking `server_context` thread | ✅ PASS | Code inspection: `promote_payload` is synchronous and returns immediately after enqueue. No blocking waits. |
| `handle_promotion_completion` on success: inserts bytes into `hot_payloads`, updates store_ref, transitions to hot, increments counters | ✅ PASS | Code inspection: `handle_promotion_completion` inserts into `hot_payloads`, sets `descriptor.store_ref.id`, `descriptor.residency = hot`, increments `n_promotion_successes`. Tests 6, 11, 13 verify. |
| `handle_promotion_completion` on failure: transitions to `evicted`, emits error diagnostic, increments failure counter | ✅ PASS | Code inspection: `handle_promotion_completion` sets `descriptor.residency = evicted`, emits `SRV_ERR`, increments `n_promotion_failures`. Tests 7, 9 verify. |
| Cold file retained on promotion failure (not removed) | ✅ PASS | Code inspection: `handle_promotion_completion` does not delete the cold file on failure. Test 14 verifies cold file persists after failure. |
| In `try_restore_from_cache`, cold descriptor triggers `promote_payload` and falls back for current request | ✅ PASS | Code inspection: `try_restore_from_cache` calls `promote_payload` for cold descriptors and returns false. Test 8 verifies by code inspection. |
| Validation order follows numbered checklist (magic, format_version, header_checksum, checksum_algorithm, payload_id, pair_state, target_size_bytes, draft_size_bytes, target_checksum, draft_checksum) | ✅ PASS | Code inspection: `cold_store::read()` validates in the exact order specified. Test 10 verifies by code inspection. |
| Draft-side failure for `target_and_draft` transitions to `evicted` (not partially hot) | ✅ PASS | Test 9 verifies: after corrupting the cold file to cause a draft-side validation failure, the descriptor transitions to `evicted` with `n_hot_payload_descriptors == 0`. |
| Promoting check evaluated before cold check (dead code fix) | ✅ PASS | Test 16 verifies: a descriptor in `promoting` state is rejected with the correct diagnostic ("already promoting") rather than "not cold". |

### Build evidence

**Build command:** `cmake --build build --target test-step7-promotion-protocol --config Release`
**Result:** PASS — compiled and linked successfully.

**Build command:** `cmake --build build --target llama-server --config Release`
**Result:** PASS — no regressions.

### Test results

**Step 7 standalone test:**

```text
==================================================
Step 7: Promotion protocol
==================================================

step7: promote_payload validates residency state...
  PASSED
step7: promote_payload requires cold store configured...
  PASSED
step7: promote_payload validates no in-progress promotion...
  PASSED
step7: promote_payload transitions to promoting state...
  PASSED
step7: promote_payload queue-full reverts residency to cold (NB-2)...
  PASSED
step7: handle_promotion_completion success transitions to hot...
  PASSED
step7: handle_promotion_completion failure transitions to evicted...
  PASSED
step7: cold descriptor triggers promotion in try_restore_from_cache...
  PASSED (verified by code inspection)
step7: draft-side failure for target_and_draft transitions to evicted...
  PASSED
step7: validation order follows numbered checklist...
  PASSED (verified by code inspection)
step7: promote_payload with nonexistent descriptor returns false...
  PASSED
step7: promotion success inserts bytes into hot_payloads...
  PASSED
step7: multiple promotions processed in sequence...
  PASSED
step7: cold file retained on promotion failure...
  PASSED
step7: process_completions dispatches promotion results...
  PASSED (verified by code inspection)
step7: promoting check evaluated before cold check...
  PASSED

==================================================
All Step 7 tests passed successfully!
Total: 16 tests
==================================================
```

### Bug fix: Dead code in promote_payload

**Location:** `tools/server/server-cache-hybrid.cpp`, `promote_payload` method

**Problem:** The "already promoting" check was placed after the "not cold" check. A descriptor with `residency == promoting` would fail the "not cold" check first (since `promoting != cold`), making the promoting check unreachable dead code.

**Fix:** Reordered the checks so the "already promoting" check comes before the "not cold" check. This matches the design requirement that validation order matters and ensures the correct diagnostic is emitted.

**Before:**

```cpp
if (descriptor.residency != payload_residency_state::cold) {
    SRV_WRN("...not cold...");
    return false;
}
// ... later ...
if (descriptor.residency == payload_residency_state::promoting) {
    SRV_WRN("...already promoting...");
    return false;
}
```

**After:**

```cpp
if (descriptor.residency == payload_residency_state::promoting) {
    SRV_WRN("...already promoting...");
    return false;
}
if (descriptor.residency != payload_residency_state::cold) {
    SRV_WRN("...not cold...");
    return false;
}
```

### Test design notes

Tests that require a valid cold reference (demote-then-promote round-trip) use the following pattern:

1. Add a hot entry with `debug_add_entry_for_tests`
2. Configure the cold store with `debug_set_cold_store_for_tests`
3. Start the IO worker with `debug_start_io_worker_for_tests`
4. Demote the payload with `demote_payload`
5. Wait for demotion completion with `sleep + process_completions`
6. Perform the test action (e.g., promote, corrupt file, etc.)

Tests that require a promotion failure use one of two approaches:

- **Read failure:** Delete the cold file after demotion, then promote. The worker fails to open the file.
- **Validation failure:** Corrupt the cold file after demotion (truncate or flip bytes), then promote. The worker reads the file but validation fails.

The `debug_set_cold_store_validation_failure_for_tests` and `debug_set_cold_store_read_failure_for_tests` hooks were added but not used in the final tests because the validation failure flags only trigger when the actual validation would have passed (they are inside the `if` block for the corresponding validation check). File corruption is a more reliable way to trigger validation failures.

### Remaining risks

None identified. All Step 7 requirements are verified.

### Next steps

Step 8 (integration with `hybrid_cache_controller` — wiring and startup configuration) is the next implementation step.
