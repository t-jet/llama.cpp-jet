# Stage 21 heavy rerun F-21-RERUN-01/02 fix evidence

Status: FIX-PLANNED
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification - Rerun payload-unavailable investigation)
Author: Developer (bug investigation, fix planning)
Source: [stage21-heavy-20260618-01-rerun.md](stage21-heavy-20260618-01-rerun.md) (rerun FAIL); [test-report-20260618-01-developer-review.md](test-report-20260618-01-developer-review.md) (F-21-EXEC-01 root cause); [test-report-stage21-fixes.md](test-report-stage21-fixes.md) (F-21-EXEC-01 fix); [test-report-20260618-01-bugfix-re-review.md](test-report-20260618-01-bugfix-re-review.md) (Architect bugfix re-review PASS); [cache-handling-phase21-design.md](../cache-handling-phase21-design.md); [cache-handling-phase21-implementation.md](../cache-handling-phase21-implementation.md)
Scope: Payload demotion bug investigation and fix planning (READ ONLY, no code changes in this session)

## Summary

Investigation complete. Root cause identified: `calculate_resident_payload_bytes()` excludes demoting payloads from the budget check, causing false "under budget" reports and triggering evictions that race with in-flight demotions. The fix requires TWO changes in `tools/server/server-cache-hybrid.cpp`: (1) in `refresh_entry_payload_accounting` (line 1573), include `demoting` state in the residency check so demoting payloads are counted as resident; (2) in `mark_payload_kind_evicted` (line 3128), remove the line that sets `descriptor.resident_payload_bytes = 0` after `demote_payload` succeeds, allowing the original resident bytes to be counted until demotion completes and hot memory is released. This preserves Stage 17 / Stage 5 invariants: demoting payloads occupy hot memory until the write completes, and budget enforcement must account for that memory.

## Root cause analysis

### Evidence from rerun log

File: `._test_output/stage21-heavy-20260618-01-rerun/20260618-170912/20260618-170912/hv1/server.err.log`

Timeline:

1. **0.39.352s**: Cache state: 1 entries, 304.817 MiB payload, 30 tokens (limits: 2048 MiB, 2048 tokens)
2. **2.55.174s**: Cache state: 6 entries, 1829.401 MiB payload, 188 tokens
3. **3.20.352s**: Cache state: 7 entries, 1829.276 MiB payload, 216 tokens (req-007 E-new saved)
4. **3.20.782s**: req-008 A-repeat lookup: "try_restore - found match: task 30 tokens, entry 30 tokens, prefix 30"
5. **3.20.782s**: "try_restore - restoring 30 tokens (namespace: 372970410063967306, use_count: 1)"
6. **3.20.782s**: **"try_restore - payload 2 is demoting, cannot restore yet"** (F-21-RERUN-01)
7. **3.20.782s**: "restore miss classified (reason=payload_unavailable, profile=checkpoint_dependent, pair_state=target_only)"
8. **3.46.353s**: **"demotion completion: descriptor not found for payload_id 1"** (F-21-RERUN-02)
9. **3.46.353s**: **"demotion completion: descriptor not found for payload_id 2"** (F-21-RERUN-02)
10. Similar pattern for req-009 (payload 4) and req-010 (payload 6)

Key observations:

- Cache is **under hot limit** (1829.276 MiB < 2048 MiB, 216 tokens < 2048 tokens)
- Yet demotion is happening on payloads 1-6 (all original saved entries)
- Exact repeat lookups find metadata matches but payloads are demoting
- Demotion completion fails with "descriptor not found" for all 6 payloads

### Evidence from JSONL

File: `._test_output/stage21-heavy-20260618-01-rerun/20260618-170912/20260618-170912/hv1/cache-prompt-evidence.jsonl`

Records 8-10 (req-008/009/010 exact repeats):

```json
{"namespace_hash":"98e8f5d7d1245ecc","token_count":30,"token_span_checksum":1456025520563686912,"lookup_outcome":"payload_unavailable","prefix_candidate":null}
{"namespace_hash":"e2d97fc6c67c5e7b","token_count":30,"token_span_checksum":12433663590788493022,"lookup_outcome":"payload_unavailable","prefix_candidate":null}
{"namespace_hash":"90f2c53e4b948948","token_count":30,"token_span_checksum":2769026330658961037,"lookup_outcome":"payload_unavailable","prefix_candidate":null}
```

Namespace hashes, token counts, and token span checksums match originals (records 1-3) exactly. Metadata lookup succeeded. Payloads are marked unavailable.

### Code path analysis

#### Function: `evict_until_within_budget` (line 2668)

```cpp
const size_t resident_bytes = calculate_resident_payload_bytes();
if (resident_bytes <= limit_size) {
    return;  // Early exit if under budget
}
```

This function checks if `resident_bytes <= limit_size` and returns early if under budget. But `calculate_resident_payload_bytes()` excludes demoting payloads.

#### Function: `calculate_resident_payload_bytes` (line 3729)

```cpp
size_t hybrid_cache_controller::calculate_resident_payload_bytes() const {
    size_t total = 0;
    for (const auto & entry : entries) {
        total += entry.resident_payload_bytes();  // Calls entry.resident_payload_bytes_cached
    }
    return total;
}
```

This sums `entry.resident_payload_bytes_cached` for all entries. That field is set by `refresh_entry_payload_accounting`.

#### Function: `refresh_entry_payload_accounting` (line 1563)

```cpp
void hybrid_cache_controller::refresh_entry_payload_accounting(hybrid_cache_entry & entry) {
    size_t resident_bytes = 0;
    // ... loop over payloads ...
        const payload_descriptor & descriptor = descriptor_it->second;
        if (descriptor.residency != payload_residency_state::hot ||  // <-- BUG: demoting != hot
            descriptor.resident_payload_bytes == 0 ||
            hot_payloads.find(descriptor.store_ref.id) == hot_payloads.end()) {
            continue;  // Skip this descriptor
        }
        resident_bytes += descriptor.resident_payload_bytes;
    // ...
    entry.resident_payload_bytes_cached = resident_bytes;
}
```

**BUG**: The check `descriptor.residency != payload_residency_state::hot` skips descriptors in `demoting` state, even though they still occupy hot memory.

#### Function: `mark_payload_kind_evicted` (line 3112)

```cpp
bool hybrid_cache_controller::mark_payload_kind_evicted(hybrid_cache_entry & entry, payload_kind kind) {
    // ...
    if (cold_store.is_configured() &&
        descriptor_it->second.residency == payload_residency_state::hot) {
        if (demote_payload(payload_id)) {
            descriptor_it->second.resident_payload_bytes = 0;  // <-- BUG: Sets to 0 prematurely
            refresh_entry_payload_accounting(entry);
            return true;
        }
        // ...
    }
    // ...
}
```

**BUG**: After `demote_payload` succeeds (demotion queued), `descriptor.resident_payload_bytes` is set to 0, then `refresh_entry_payload_accounting` is called. But the descriptor's `residency` is now `demoting` (set inside `demote_payload` at line 429), so `refresh_entry_payload_accounting` skips it. Result: `entry.resident_payload_bytes_cached` becomes 0 (or sum of other payloads, excluding this one).

#### Function: `demote_payload` (line 364)

```cpp
bool hybrid_cache_controller::demote_payload(uint64_t payload_id) {
    // ... validation ...
    // Transition to demoting state (NB-5: hot bytes are NOT released yet)
    descriptor.residency = payload_residency_state::demoting;  // <-- Residency changes to demoting
    // ... enqueue write task ...
    return true;  // Demotion queued, hot memory still occupied
}
```

Demotion enqueues the write but does NOT release hot memory. The `hot_payloads` map still contains the payload.

#### Function: `handle_demotion_completion` (line 628)

```cpp
void hybrid_cache_controller::handle_demotion_completion(io_completion_result & result) {
    auto descriptor_it = payload_descriptors.find(result.payload_id);
    if (descriptor_it == payload_descriptors.end()) {
        SRV_WRN(" - hybrid cache: demotion completion: descriptor not found for payload_id %" PRIu64 "\n",
                result.payload_id);  // <-- F-21-RERUN-02 warning
        // ...
        return;
    }
    // ...
    if (result.success) {
        // ...
        hot_payloads.erase(descriptor.payload_id);  // <-- Hot memory released HERE
        // ...
    }
}
```

Hot memory is released only when demotion completes successfully (line 656). If the descriptor is removed before completion (e.g., entry evicted), this handler logs "descriptor not found" (F-21-RERUN-02).

### Demotion sequence (step-by-step)

1. **Req-007 save completes** (3.20.352s): 7 entries in cache, 1829.276 MiB payload, 216 tokens (under 2048 MiB / 2048 token limits)
2. **Eviction triggered** (between req-007 and req-008): `evict_until_within_budget()` is called (likely in `update()` or after the save)
3. **Budget check**: `calculate_resident_payload_bytes()` sums `entry.resident_payload_bytes_cached` for all entries
4. **FALSE UNDER-BUDGET**: But `entry.resident_payload_bytes_cached` was set to 0 for entries with demoting payloads (if any prior demotion was in flight), OR the budget check passes because demoting payloads are not counted
5. **LRU eviction plan**: `eviction_policy.plan_evictions()` selects entries to evict (oldest LRU entries: payload_id 1, 2, 3, 4, 5, 6)
6. **Demotion queued**: `mark_payload_kind_evicted()` calls `demote_payload(payload_id)` for each selected entry
7. **Residency changes**: Inside `demote_payload`, `descriptor.residency = payload_residency_state::demoting` (line 429)
8. **Resident bytes zeroed**: Back in `mark_payload_kind_evicted`, `descriptor.resident_payload_bytes = 0` (line 3128)
9. **Accounting refresh**: `refresh_entry_payload_accounting(entry)` is called (line 3129)
10. **Descriptor skipped**: `refresh_entry_payload_accounting` skips the descriptor because `residency == demoting` (not `hot`), so `entry.resident_payload_bytes_cached` becomes 0
11. **Next budget check**: `calculate_resident_payload_bytes()` returns a lower value (excludes demoting payloads)
12. **False under-budget**: Cache appears under budget, no further evictions
13. **Req-008 lookup** (3.20.782s): `try_restore` finds entry for payload_id=2, but `descriptor.residency == demoting`, so "payload 2 is demoting, cannot restore yet" (F-21-RERUN-01)
14. **Demotion completion** (3.46.353s): Worker completes write for payload_id=1, calls `handle_demotion_completion`
15. **Descriptor not found** (F-21-RERUN-02): Descriptor was removed (by entry eviction or other path) before demotion completed, so `payload_descriptors.find(result.payload_id)` fails

### Why demotion fires under hot limit

`calculate_resident_payload_bytes()` excludes demoting payloads from the budget calculation. Once a payload enters the `demoting` state, `refresh_entry_payload_accounting` skips it (line 1573: `if (descriptor.residency != payload_residency_state::hot ...)`), and `entry.resident_payload_bytes_cached` is set to 0 (or sum of non-demoting payloads). The next budget check sees a lower resident byte count and may trigger more evictions, even though the hot memory is still occupied by in-flight demotions.

### Why descriptors are lost by demotion completion

Between the time demotion is queued and the time it completes, the cache controller may evict the entry for another reason (e.g., token budget, or another LRU eviction). When the entry is evicted, `remove_payload()` is called (line 3095 or 3139), which erases the descriptor from `payload_descriptors` (via `remove_payload` -> `payload_descriptors.erase(payload_id)`). When demotion completes, `handle_demotion_completion` tries to find the descriptor (line 629) but it's gone, triggering the "descriptor not found" warning (F-21-RERUN-02).

## Fix plan

### Goal

Prevent false "under budget" reports that cause evictions to race with in-flight demotions. Demoting payloads must be counted as resident until hot memory is released (at demotion completion).

### Changes required

File: `tools/server/server-cache-hybrid.cpp`

#### Change 1: Include demoting payloads in budget calculation

Function: `refresh_entry_payload_accounting` (line 1563)
Location: Line 1573 (the residency check)

Current code:

```cpp
if (descriptor.residency != payload_residency_state::hot ||
    descriptor.resident_payload_bytes == 0 ||
    hot_payloads.find(descriptor.store_ref.id) == hot_payloads.end()) {
    continue;
}
```

Fix logic:

Change the residency check to accept both `hot` and `demoting` states. Demoting payloads still occupy hot memory (the `hot_payloads` map contains them) until demotion completes and `handle_demotion_completion` erases them (line 656). The budget check must count them as resident.

Proposed check:

```cpp
if ((descriptor.residency != payload_residency_state::hot &&
     descriptor.residency != payload_residency_state::demoting) ||
    descriptor.resident_payload_bytes == 0 ||
    hot_payloads.find(descriptor.store_ref.id) == hot_payloads.end()) {
    continue;
}
```

Why this preserves invariants: Stage 17 / Stage 5 contract: hot budget enforcement counts all payloads in hot memory. Demoting payloads are in hot memory (until `hot_payloads.erase` at demotion completion), so they must be counted. This fix aligns the budget calculation with the actual memory state.

#### Change 2: Do not zero resident bytes when demotion is queued

Function: `mark_payload_kind_evicted` (line 3112)
Location: Line 3128 (the assignment after `demote_payload` succeeds)

Current code:

```cpp
if (demote_payload(payload_id)) {
    descriptor_it->second.resident_payload_bytes = 0;  // <-- REMOVE THIS LINE
    refresh_entry_payload_accounting(entry);
    return true;
}
```

Fix logic:

Remove the line `descriptor_it->second.resident_payload_bytes = 0;`. The descriptor's `resident_payload_bytes` should remain at its original value (the sum of target and draft sizes) until demotion completes. When `handle_demotion_completion` is called (line 628), the success path will transition the descriptor to `cold` state and erase from `hot_payloads` (line 656), at which point the next `refresh_entry_payload_accounting` call will skip it (because `hot_payloads.find()` fails), and the entry's cached resident bytes will drop to 0.

Why this preserves invariants: The hot memory is NOT released when demotion is queued. It's released when `hot_payloads.erase()` is called at demotion completion. Setting `resident_payload_bytes = 0` prematurely creates a false accounting state where the descriptor claims 0 resident bytes but the hot memory is still occupied.

### Edge cases to test

1. **Demotion queue full**: If `io_worker.enqueue_demotion()` returns false (line 442-451 in `demote_payload`), the descriptor reverts to `hot` state. The resident bytes should remain unchanged (not zeroed).
2. **Demotion failure**: If `handle_demotion_completion` receives `result.success == false` and `hot_payloads` still contains the payload (line 675-681), the descriptor reverts to `hot` state. The resident bytes should remain at their original value (not zeroed).
3. **Entry eviction during demotion**: If an entry is evicted (via `remove_entry_after_eviction`, line 2100) while its payload is demoting, `remove_payload` is called (line 2103), which erases the descriptor from `payload_descriptors` (line 3095: `payload_descriptors.erase(payload_id)`). When demotion completes, `handle_demotion_completion` should log "descriptor not found" (line 631-634) and return early without crashing. This is the current behavior and should continue.
4. **Multiple payloads per entry**: An entry may have both `payload_id` (exact blob) and `checkpoint_payload_id` (checkpoint). If one is demoting and the other is hot, `refresh_entry_payload_accounting` should count both according to their residency states. After Change 1, both hot and demoting payloads will be counted.
5. **Budget re-check after demotion queued**: After `mark_payload_kind_evicted` returns, `evict_until_within_budget` may check the budget again. With Change 1, demoting payloads are still counted as resident, so the budget check should see the correct memory usage and not trigger spurious evictions.

### New public metric needed

No. Existing metrics `cache_restore_misses_total{reason="payload_unavailable"}` (Stage 10) and `cache_cold_demotion_*` (Stage 8) already track the failure modes. The fix eliminates the root cause (false under-budget), so `payload_unavailable` should drop to 0 in the rerun. No new counter is needed.

### Why this fix preserves Stage 17 / Stage 5 invariants

Stage 17 / Stage 5 contract: Hot budget enforcement (`--cache-ram-mib`) limits the resident payload bytes in hot memory. The budget check (`calculate_resident_payload_bytes()`) must count all payloads that occupy hot memory.

Current bug: Demoting payloads occupy hot memory (the `hot_payloads` map contains them) until `handle_demotion_completion` erases them (line 656). But `refresh_entry_payload_accounting` skips demoting payloads (line 1573: `residency != hot`), causing `calculate_resident_payload_bytes()` to undercount and trigger false "under budget" reports.

Fix 1 (include demoting in residency check): Aligns the budget calculation with the actual memory state. Demoting payloads are counted as resident until the hot memory is released.

Fix 2 (do not zero resident bytes when demotion queued): Preserves the accurate byte count in the descriptor. The bytes are released only when `hot_payloads.erase()` is called at demotion completion.

Result: `calculate_resident_payload_bytes()` returns the true hot memory usage, including in-flight demotions. The budget check behaves correctly, and no spurious evictions are triggered.

## Test plan

### Unit tests to add

File: `tests/test-cache-controller.cpp`

#### Test 1: Budget calculation includes demoting payloads

Add a test that:

1. Creates a controller with hot budget 1000 bytes
2. Adds entry A with payload 400 bytes (hot)
3. Adds entry B with payload 400 bytes (hot)
4. Adds entry C with payload 400 bytes (hot, triggers eviction)
5. Configures a cold store
6. Calls `process_completions()` to allow eviction to queue demotion for entry A (oldest LRU)
7. Verifies that entry A's payload is in `demoting` state
8. Calls `calculate_resident_payload_bytes()` and verifies it returns 1200 (all three entries, including demoting)
9. Adds entry D with payload 100 bytes
10. Calls `evict_until_within_budget()` and verifies that NO evictions occur (budget is 1000, resident is 1300 including demoting payload A)

This test fails WITHOUT Change 1 (demoting payload A is excluded, so `calculate_resident_payload_bytes()` returns 900, and entry D is saved without triggering eviction, leaving the cache over budget).

#### Test 2: Descriptor resident_payload_bytes preserved during demotion

Add a test that:

1. Creates a controller with hot budget 1000 bytes
2. Adds entry A with payload 600 bytes (hot)
3. Adds entry B with payload 600 bytes (hot, triggers eviction)
4. Configures a cold store
5. Calls `process_completions()` to allow demotion to queue for entry A
6. Reads the descriptor for entry A's payload and verifies:
   - `residency == demoting`
   - `resident_payload_bytes == 600` (NOT 0)
7. Calls `calculate_resident_payload_bytes()` and verifies it returns 1200 (both entries)
8. Completes the demotion by calling `process_completions()` again
9. Verifies that `hot_payloads` no longer contains entry A's payload
10. Calls `calculate_resident_payload_bytes()` and verifies it returns 600 (only entry B)

This test fails WITHOUT Change 2 (`resident_payload_bytes` is set to 0 after `demote_payload`, so step 6 sees `resident_payload_bytes == 0`).

#### Test 3: Entry eviction during demotion does not crash

Add a test that:

1. Creates a controller with hot budget 1000 bytes and token budget 100
2. Adds entry A with payload 600 bytes, 50 tokens
3. Adds entry B with payload 600 bytes, 50 tokens (triggers payload eviction due to hot budget)
4. Configures a cold store
5. Calls `process_completions()` to queue demotion for entry A
6. Adds entry C with payload 100 bytes, 60 tokens (triggers TOKEN eviction, entry A should be evicted by token LRU)
7. Verifies that entry A is removed from `entries`
8. Completes the demotion by calling `process_completions()` again
9. Verifies that the handler logs "descriptor not found" (stderr/log capture) but does not crash
10. Verifies that entry B and entry C remain in cache

This test verifies that the "descriptor not found" path (line 631-634) is safe and does not leak memory or crash.

### Unit tests to modify

None. The existing Stage 5 / Stage 8 / Stage 17 budget tests should continue to pass with the fix. The fix corrects the budget calculation to match the design intent.

### Integration test (manual verification, not automated)

Rerun the TP-21-HV1 profile with the fixed binary:

1. Build with the two changes applied
2. Run `kickoff-stage21-heavy-v2.ps1` with the same parameters as the original rerun (10 requests per row, 60-minute budget, HV1 profile)
3. Check `cache-prompt-evidence.jsonl` for req-008/009/010 (exact repeats)
4. Expected: `lookup_outcome: entry_restored` (or `entry_restored_full_hit` if cache_n > 0)
5. Expected: `cache_n > 0` for at least one exact repeat (design criterion)
6. Expected: NO "payload N is demoting, cannot restore yet" warnings in `server.err.log`
7. Expected: NO "descriptor not found for payload_id N" warnings in `server.err.log`
8. Expected: Verdict `PASS`

## Risk assessment

### Compatibility

The fix changes the budget calculation to include demoting payloads. This is a conservative change: the budget check will count MORE bytes (including in-flight demotions), so evictions will trigger earlier if the cache is truly over budget. Existing deployments with cold storage enabled may see slightly higher demotion rates (more aggressive eviction), but this is the correct behavior per the Stage 17 / Stage 5 design.

### Correctness

The fix aligns the budget calculation with the actual hot memory state. Demoting payloads occupy hot memory until `hot_payloads.erase()` is called. The fix ensures they are counted. This is a bug fix, not a behavior change.

### Performance

No impact. The fix does not add new loops or allocations. The residency check in `refresh_entry_payload_accounting` gains one additional condition (`|| descriptor.residency == demoting`), which is a negligible CPU cost.

### Edge case: Demotion queue full or failure

If demotion queue is full (line 442-451 in `demote_payload`), the descriptor reverts to `hot` state, and `resident_payload_bytes` remains unchanged (because Change 2 removes the zeroing). The next `refresh_entry_payload_accounting` call will see `residency == hot` and count the bytes. This is correct.

If demotion fails (line 675-681 in `handle_demotion_completion`), the descriptor reverts to `hot`, and the bytes remain in `hot_payloads`. The next `refresh_entry_payload_accounting` call will count them. This is correct.

### Edge case: Entry eviction during demotion

If an entry is evicted while its payload is demoting, `remove_payload` erases the descriptor. When `handle_demotion_completion` is called, it logs "descriptor not found" and returns early. The hot memory is already erased from `hot_payloads` by `remove_payload` (line 3095: `hot_payloads.erase(payload_id)`), so no memory leak. This behavior is unchanged by the fix.

## Out of scope

1. **Cold budget enforcement**: Not affected by this fix. Cold budget checks are separate (line 417-423 in `demote_payload`).
2. **Promotion path**: Not affected. Promotion changes residency from `cold` to `promoting` to `hot`, and `refresh_entry_payload_accounting` already accepts `hot` payloads.
3. **Token budget enforcement**: Not affected. Token budget uses `entry.token_count()`, not payload bytes.
4. **Prefix rejection (D17-03)**: Not affected. Prefix candidate creation was fixed in F-21-EXEC-01 (prompt-only save). This fix addresses the subsequent demotion race.
5. **Metrics**: No new metrics needed. Existing `cache_restore_misses_total{reason="payload_unavailable"}` tracks the failure mode eliminated by this fix.

## Handoff

Next owner: Architect for review of this fix plan.

After Architect approval, a follow-up Developer session will apply the two code changes, add the three unit tests, rebuild, and verify that all Stage 5 / Stage 8 / Stage 17 tests pass.

Then QA will rerun TP-21-HV1 with the fixed binary and verify that req-008/009/010 (exact repeats) produce `cache_n > 0` and `lookup_outcome: entry_restored`, eliminating F-21-RERUN-01 and F-21-RERUN-02.

## Footer

Investigation mode: READ ONLY (no code changes, no commits, no pushes, no test execution, no heavy execution)
Line endings: LF
Encoding: UTF-8, no BOM
Status labels: plain ASCII (FIX-PLANNED)
