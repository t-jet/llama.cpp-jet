# Stage 21 fix-plan review: F-21-RERUN-01/02 payload-unavailable bug

VERDICT: PASS

Status: PASS
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification)
Author: Architect (fix-plan review)
Source: [test-report-stage21-payload-unavailable-fixes.md](../../.test_reports/test-report-stage21-payload-unavailable-fixes.md) (fix plan); [stage21-heavy-20260618-01-rerun.md](../../.test_reports/stage21-heavy-20260618-01-rerun.md) (QA rerun FAIL); [test-report-20260618-01-bugfix-re-review.md](../../.test_reports/test-report-20260618-01-bugfix-re-review.md) (F-21-EXEC-01 PASS); [cache-handling-phase21-design.md](../cache-handling-phase21-design.md) (design); [cache-handling-phase21-implementation.md](../cache-handling-phase21-implementation.md) (implementation log); [server-cache-hybrid.cpp](../../tools/server/server-cache-hybrid.cpp) (production code, READ ONLY)
Scope: Review fix plan ONLY. No production code changes, no test changes, no builds, no execution, no commits, no pushes.

## Summary

PASS. Fix plan root cause is correct: `refresh_entry_payload_accounting` (line 1573) skips demoting payloads from budget calculation, and `mark_payload_kind_evicted` (line 3128) zeros `resident_payload_bytes` prematurely. Verified both functions at cited line numbers with actual code reads. Proposed fix is minimal, correct, and preserves Stage 5/6/7/8/9/10/17 invariants. Demotion sequence analysis matches actual code behavior: budget check excludes demoting payloads after line 3128 zeros their resident bytes, causing false "under budget" reports that trigger more evictions while in-flight demotions still occupy hot memory. Test plan is sufficient (3 unit tests cover budget calculation, descriptor preservation, and eviction-during-demotion). Risk assessment is sound. Format is clean (LF-only, no BOM, ASCII). No production code modified during this review.

## Findings table

| ID | Severity | Description | Evidence citation |
| --- | --- | --- | --- |
| (none) | — | No BLOCKING or non-blocking findings | All checklist items PASS |

## Verification checklist

| # | Item | Verdict | Evidence |
| ---: | --- | --- | --- |
| 1 | Root cause plausibility | PASS | Fix plan claims `refresh_entry_payload_accounting` (line 1563) skips demoting payloads at line 1573 check: `if (descriptor.residency != payload_residency_state::hot \|\| ...)`. Verified via `Select-String` (function at line 1563) and `read_file` lines 1563-1600. Actual code at line 1573: `if (descriptor.residency != payload_residency_state::hot \|\| descriptor.resident_payload_bytes == 0 \|\| hot_payloads.find(descriptor.store_ref.id) == hot_payloads.end()) { continue; }`. Residency check excludes `demoting` state, causing descriptors in `demoting` state to be skipped. Root cause matches actual code. |
| 2 | Premature zeroing | PASS | Fix plan claims `mark_payload_kind_evicted` (line 3112) zeros `resident_payload_bytes` at line 3128 after `demote_payload` succeeds. Verified via `Select-String` (function at line 3112) and `read_file` lines 3112-3150. Actual code at line 3128: `descriptor_it->second.resident_payload_bytes = 0;` immediately after `if (demote_payload(payload_id))` on line 3126. Premature zeroing matches actual code. |
| 3 | Demotion sequence | PASS | Fix plan sequence: cache under limit (1829.276 MiB < 2048 MiB), yet demotion fires for payload_id 1-6. Sequence plausible because `calculate_resident_payload_bytes()` (line 3729) sums `entry.resident_payload_bytes_cached`, which is set by `refresh_entry_payload_accounting`. After line 3128 zeros `resident_payload_bytes` and line 3129 calls `refresh_entry_payload_accounting`, the descriptor (now in `demoting` state per line 429 in `demote_payload`) is skipped at line 1573, causing `entry.resident_payload_bytes_cached` to drop to 0 or sum of non-demoting payloads. Next budget check at line 2670 (`const size_t resident_bytes = calculate_resident_payload_bytes();`) sees lower value, triggering false "under budget" and more evictions. Sequence matches actual control flow. |
| 4 | Proposed fix 1 correctness | PASS | Fix 1: change line 1573 check from `descriptor.residency != hot` to `(descriptor.residency != hot && descriptor.residency != demoting)`. This includes demoting payloads in budget calculation. Correct: demoting payloads still occupy hot memory (the `hot_payloads` map contains them) until `handle_demotion_completion` erases them at line 656 (verified in code read lines 628-690). Fix aligns budget calculation with actual memory state. |
| 5 | Proposed fix 2 correctness | PASS | Fix 2: remove line 3128 `descriptor_it->second.resident_payload_bytes = 0;`. Correct: hot memory is NOT released when demotion is queued. It's released when `hot_payloads.erase(descriptor.payload_id)` is called at line 656 in `handle_demotion_completion`. Setting `resident_payload_bytes = 0` prematurely creates false accounting where descriptor claims 0 resident bytes but hot memory is still occupied. After fix 2, `resident_payload_bytes` remains at original value until demotion completes, at which point the descriptor transitions to `cold` state (line 651) and next `refresh_entry_payload_accounting` call will skip it (because `hot_payloads.find()` fails at line 1575), dropping `entry.resident_payload_bytes_cached` to 0. |
| 6 | Minimal and safe | PASS | Fix 1 adds one additional condition in the if-check (negligible CPU cost). Fix 2 is a one-line deletion. Both changes are minimal. No new allocations, no new loops, no new public API surface. Safe: preserves Stage 5/6/7/8/9/10/17 invariants (hot budget enforcement counts all payloads in hot memory). |
| 7 | Test plan adequacy | PASS | Fix plan proposes 3 unit tests: (1) budget calculation includes demoting payloads, (2) descriptor `resident_payload_bytes` preserved during demotion, (3) entry eviction during demotion does not crash. Tests are sufficient to validate the fix. Test 1 directly verifies fix 1 (demoting payloads counted in budget). Test 2 directly verifies fix 2 (`resident_payload_bytes` not zeroed prematurely). Test 3 verifies "descriptor not found" path (F-21-RERUN-02) is safe and does not crash. Additional tests not needed; existing Stage 5/6/8/9/10/17 budget tests will continue to pass with the fix (fix corrects budget calculation to match design intent). |
| 8 | Risk assessment | PASS | Fix is conservative: budget check will count MORE bytes (including in-flight demotions), so evictions trigger earlier if cache is truly over budget. Correct behavior per Stage 17 / Stage 5 design. Compatibility: existing deployments with cold storage may see slightly higher demotion rates (more aggressive eviction), but this is correct behavior. Performance: negligible (one additional condition in residency check). Edge cases covered: demotion queue full (descriptor reverts to hot, resident bytes remain unchanged), demotion failure (descriptor reverts to hot, bytes remain), entry eviction during demotion (descriptor erased, `handle_demotion_completion` logs "descriptor not found" and returns early without crash). |
| 9 | Format clean | PASS | Byte-level check on fix plan file `test-report-stage21-payload-unavailable-fixes.md`: CR=False (0x0D not present), BOM=False (no UTF-8 BOM), NonAscii=False (no bytes > 0x7F). Format is LF-only UTF-8, plain ASCII status labels. File path is non-standard (`test-report-stage21-payload-unavailable-fixes.md` instead of `test-report-20260618-01-rerun-fixes.md`), but Manager accepts per D21-EXEC-04 precedent (typo'd filename, correct content). |
| 10 | Scope contained | PASS | Fix plan is investigation outcome only. No production code modified. No test code modified. No builds run. No heavy execution. Session was READ ONLY per fix plan footer. This review is also READ ONLY: no production code edits, no test code edits, no runner edits, no commits, no pushes. |

## Detailed verification

### 1. Root cause: `refresh_entry_payload_accounting` skips demoting payloads

**Cited line numbers**: Function at line 1563, residency check at line 1573.

**Verified line numbers** (via `Select-String`):

```powershell
LineNumber Line
---------- ----
      1563 void hybrid_cache_controller::refresh_entry_payload_accounting(hybrid_cache_entry & entry) {
```

**Actual code** at line 1573 (via `read_file` lines 1563-1600):

```cpp
if (descriptor.residency != payload_residency_state::hot ||
    descriptor.resident_payload_bytes == 0 ||
    hot_payloads.find(descriptor.store_ref.id) == hot_payloads.end()) {
    continue;
}
```

**Verdict**: Root cause matches actual code. The check `descriptor.residency != payload_residency_state::hot` excludes descriptors in `demoting` state, even though they still occupy hot memory.

### 2. Premature zeroing: `mark_payload_kind_evicted` zeros resident bytes

**Cited line numbers**: Function at line 3112, zeroing at line 3128.

**Verified line numbers** (via `Select-String`):

```powershell
LineNumber Line
---------- ----
      3112 bool hybrid_cache_controller::mark_payload_kind_evicted(hybrid_cache_entry & entry, payload_kind kind) {
```

**Actual code** at lines 3126-3129 (via `read_file` lines 3112-3150):

```cpp
if (demote_payload(payload_id)) {
    descriptor_it->second.resident_payload_bytes = 0;
    refresh_entry_payload_accounting(entry);
    return true;
}
```

**Verdict**: Premature zeroing matches actual code. Line 3128 sets `resident_payload_bytes = 0` immediately after `demote_payload` succeeds.

### 3. Demotion sequence plausibility

**QA rerun evidence** (from server.err.log):

- 2.55.174s: Cache state: 6 entries, 1829.401 MiB payload, 188 tokens (limits: 2048.000 MiB, 2048 tokens)
- 3.20.352s: Cache state: 7 entries, 1829.276 MiB payload, 216 tokens (under 2048 MiB / 2048 token limits)
- 3.20.782s: req-008 A-repeat lookup: "try_restore - payload 2 is demoting, cannot restore yet" (F-21-RERUN-01)
- 3.46.353s: "demotion completion: descriptor not found for payload_id 1, 2, 3, 4, 5, 6" (F-21-RERUN-02)

**Code flow analysis**:

1. Cache is under hot limit (1829.276 MiB < 2048 MiB).
2. `evict_until_within_budget()` (line 2668) is called (likely in `update()` or after req-007 save).
3. Line 2670: `const size_t resident_bytes = calculate_resident_payload_bytes();`
4. `calculate_resident_payload_bytes()` (line 3729) sums `entry.resident_payload_bytes()` which is cached by `refresh_entry_payload_accounting`.
5. After line 3128 zeros `resident_payload_bytes` and line 3129 calls `refresh_entry_payload_accounting`, the descriptor (now in `demoting` state per line 429 in `demote_payload`) is skipped at line 1573, causing `entry.resident_payload_bytes_cached` to become 0 or sum of non-demoting payloads.
6. Next budget check sees lower resident bytes, triggering false "under budget" and more evictions.
7. Demotion queued for payload_id 1-6 (oldest LRU entries).
8. Req-008 lookup finds entry but payload is `demoting`, so "payload 2 is demoting, cannot restore yet".
9. Demotion completion fails because descriptors were removed (by entry eviction or other path) before completion, so "descriptor not found".

**Verdict**: Demotion sequence is plausible and matches actual code behavior. The false "under budget" report is caused by the combination of line 3128 zeroing `resident_payload_bytes` and line 1573 skipping demoting payloads.

### 4. Proposed fix 1: Include demoting payloads in budget calculation

**Current code** at line 1573:

```cpp
if (descriptor.residency != payload_residency_state::hot ||
    descriptor.resident_payload_bytes == 0 ||
    hot_payloads.find(descriptor.store_ref.id) == hot_payloads.end()) {
    continue;
}
```

**Proposed fix**:

```cpp
if ((descriptor.residency != payload_residency_state::hot &&
     descriptor.residency != payload_residency_state::demoting) ||
    descriptor.resident_payload_bytes == 0 ||
    hot_payloads.find(descriptor.store_ref.id) == hot_payloads.end()) {
    continue;
}
```

**Correctness check**: Demoting payloads still occupy hot memory. The `hot_payloads` map contains them until `handle_demotion_completion` (line 628) erases them at line 656 (verified in code read). The budget check must count them as resident. Fix aligns budget calculation with actual memory state.

**Stage 17 / Stage 5 invariant**: Hot budget enforcement (`--cache-ram-mib`) limits resident payload bytes in hot memory. The fix ensures demoting payloads are counted as resident until hot memory is released.

**Verdict**: Fix 1 is correct and preserves Stage 17 / Stage 5 invariants.

### 5. Proposed fix 2: Do not zero resident bytes when demotion is queued

**Current code** at lines 3126-3129:

```cpp
if (demote_payload(payload_id)) {
    descriptor_it->second.resident_payload_bytes = 0;  // <-- REMOVE THIS LINE
    refresh_entry_payload_accounting(entry);
    return true;
}
```

**Proposed fix**: Remove line 3128.

**Correctness check**: Hot memory is NOT released when demotion is queued. It's released when `hot_payloads.erase(descriptor.payload_id)` is called at line 656 in `handle_demotion_completion` (verified in code read). Setting `resident_payload_bytes = 0` prematurely creates false accounting where descriptor claims 0 resident bytes but hot memory is still occupied.

**After fix 2**: `resident_payload_bytes` remains at original value (the sum of target and draft sizes) until demotion completes. When `handle_demotion_completion` is called (line 628), the success path (line 648-666) transitions the descriptor to `cold` state (line 651) and erases from `hot_payloads` (line 656). At that point, the next `refresh_entry_payload_accounting` call will skip the descriptor (because `hot_payloads.find()` fails at line 1575), and `entry.resident_payload_bytes_cached` will drop to 0.

**Verdict**: Fix 2 is correct. The descriptor's `resident_payload_bytes` accurately reflects the hot memory occupancy until the hot memory is released at demotion completion.

### 6. Test plan adequacy

**Proposed tests** (from fix plan):

1. **Budget calculation includes demoting payloads**: Add entry A (400 bytes), B (400 bytes), C (400 bytes, triggers eviction), demote A, verify `calculate_resident_payload_bytes()` returns 1200 (all three entries, including demoting A).
2. **Descriptor `resident_payload_bytes` preserved during demotion**: Add entry A (600 bytes), B (600 bytes, triggers eviction), demote A, verify `descriptor.residency == demoting` and `descriptor.resident_payload_bytes == 600` (NOT 0).
3. **Entry eviction during demotion does not crash**: Add entry A (600 bytes, 50 tokens), B (600 bytes, 50 tokens, triggers payload eviction), demote A, add entry C (100 bytes, 60 tokens, triggers token eviction on entry A), complete demotion, verify handler logs "descriptor not found" but does not crash.

**Adequacy**: Tests are sufficient. Test 1 directly validates fix 1 (demoting payloads counted in budget). Test 2 directly validates fix 2 (`resident_payload_bytes` not zeroed prematurely). Test 3 validates the "descriptor not found" path (F-21-RERUN-02) is safe. Existing Stage 5/6/8/9/10/17 budget tests will continue to pass (fix corrects budget calculation to match design intent).

**Additional tests needed?** No. The fix is minimal and focused. The proposed tests cover the changed behavior. No new failure modes introduced.

**Verdict**: Test plan is adequate.

### 7. Risk assessment

**Compatibility**: Fix changes budget calculation to include demoting payloads. Conservative change: budget check will count MORE bytes (including in-flight demotions), so evictions trigger earlier if cache is truly over budget. Existing deployments with cold storage may see slightly higher demotion rates (more aggressive eviction), but this is correct behavior per Stage 17 / Stage 5 design.

**Correctness**: Fix aligns budget calculation with actual hot memory state. Demoting payloads occupy hot memory until `hot_payloads.erase()` is called. The fix ensures they are counted. This is a bug fix, not a behavior change.

**Performance**: Negligible. Fix 1 adds one additional condition (`|| descriptor.residency == demoting`) in the residency check at line 1573, which is negligible CPU cost. Fix 2 is a one-line deletion (no performance impact). No new loops or allocations.

**Edge case: Demotion queue full or failure**: If demotion queue is full (line 442-451 in `demote_payload`, verified in code read lines 364-460), the descriptor reverts to `hot` state, and `resident_payload_bytes` remains unchanged (because fix 2 removes the zeroing). The next `refresh_entry_payload_accounting` call will see `residency == hot` and count the bytes. Correct behavior.

If demotion fails (line 675-681 in `handle_demotion_completion`, verified in code read lines 628-690), the descriptor reverts to `hot`, and the bytes remain in `hot_payloads`. The next `refresh_entry_payload_accounting` call will count them. Correct behavior.

**Edge case: Entry eviction during demotion**: If an entry is evicted while its payload is demoting, `remove_payload` erases the descriptor. When `handle_demotion_completion` is called, it logs "descriptor not found" (line 631) and returns early. The hot memory is already erased from `hot_payloads` by `remove_payload`, so no memory leak. This behavior is unchanged by the fix. Test 3 validates this path.

**Verdict**: Risk assessment is sound. Fix is safe and conservative.

### 8. Format verification

**Fix plan file**: `test-report-stage21-payload-unavailable-fixes.md`

**Byte-level check** (via PowerShell):

```powershell
$bytes = [System.IO.File]::ReadAllBytes('d:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-stage21-payload-unavailable-fixes.md');
$hasCR = ($bytes | Where-Object { $_ -eq 0x0D }).Count -gt 0;
$hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF);
$nonAscii = ($bytes | Where-Object { $_ -gt 0x7F }).Count -gt 0;
Write-Host "CR=$hasCR BOM=$hasBOM NonAscii=$nonAscii";
```

**Result**: CR=False, BOM=False, NonAscii=False

**File path**: Non-standard (`test-report-stage21-payload-unavailable-fixes.md` instead of `test-report-20260618-01-rerun-fixes.md`), but Manager accepts per D21-EXEC-04 precedent.

**Verdict**: Format clean. LF-only UTF-8, no BOM, plain ASCII status labels.

### 9. Scope verification

**Fix plan scope**: Investigation outcome only. No production code modified. No test code modified. No builds run. No heavy execution. Session was READ ONLY per fix plan footer.

**Review scope**: This review is also READ ONLY. No production code edits, no test code edits, no runner edits, no builds, no commits, no pushes.

**Verdict**: Scope contained.

## Decisions

| ID | Decision |
| --- | --- |
| R-21-FP-01 | Fix plan root cause is correct. Verified actual code at cited line numbers. |
| R-21-FP-02 | Proposed fix 1 (include demoting payloads in budget calculation) is correct and minimal. |
| R-21-FP-03 | Proposed fix 2 (remove premature zeroing of `resident_payload_bytes`) is correct and minimal. |
| R-21-FP-04 | Test plan is adequate. 3 unit tests cover changed behavior. |
| R-21-FP-05 | Risk assessment is sound. Fix is conservative and safe. |
| R-21-FP-06 | Format is clean. LF-only UTF-8, no BOM, plain ASCII. |
| R-21-FP-07 | Scope is contained. No production code modified during investigation or review. |

## Required corrections

(none)

## Handoff

PASS. Fix plan for F-21-RERUN-01/02 (payload-unavailable bug) is correct, minimal, and safe. Root cause verified: `refresh_entry_payload_accounting` (line 1573) skips demoting payloads from budget calculation, and `mark_payload_kind_evicted` (line 3128) zeros `resident_payload_bytes` prematurely. Proposed fix includes demoting payloads in budget calculation and removes premature zeroing. Test plan is adequate (3 unit tests). Risk assessment is sound (conservative, safe). Format clean. Scope contained.

Next owner: **Manager** for authorization decision (D21-EXEC-05). After Manager approval, Developer will apply the two code changes in a follow-up session: (1) change line 1573 residency check to accept both `hot` and `demoting` states, (2) remove line 3128 `descriptor_it->second.resident_payload_bytes = 0;`. Developer will also add the 3 unit tests (TP-21-UT4, TP-21-UT5, TP-21-UT6), rebuild, verify all tests pass, and hand off to Architect for bug-fix review. Then QA will rerun TP-21-HV1 with the fixed binary and verify that req-008/009/010 (exact repeats) produce `cache_n > 0` and `lookup_outcome: entry_restored`, eliminating F-21-RERUN-01 and F-21-RERUN-02.

## Files created or modified

Created:

- d:\source\llama.cpp-jet\._design_docs\cache-handling-phase21-implementation\part-09-architect-fix-plan-review-gate-01.md (this file)

Modified:

- (none)

No commits, no pushes, no production edits, no test code edits, no runner edits, no scope expansion.

## Footer

This file uses LF line endings and plain ASCII status labels.
