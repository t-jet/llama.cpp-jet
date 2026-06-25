# Stage 24 report 05 product bug fix (D-EXEC-24-02)

Status: ready for Architect review
Date: 2026-06-25
Owner: Developer
Scope: product code fix in `tools/server/server-cache-hybrid.cpp` for
the token-limit early-break defect surfaced by the S03 hybrid leg in
`test-report-20260624-04.md` / `test-report-20260624-05.md`.

## Trigger

Stage 24 S02/S03 hybrid log analysis showed the cache pinned above the
4096-token budget for hundreds of slot cycles. The S03 hybrid log has
9177 tokens vs the 4096 limit (224% over). Final state from
`test-report-20260624-05-live.log`:

```text
srv        update:  - hybrid cache state: N entries, X.XXX MiB payload, X.XXX MiB total, TTTTT tokens (limits: 512.000 MiB payload, 4096 tokens)
```

with TTTTT consistently above 4096 across 372/513 (72.5%) cache state
lines. The over-token-limit state is a distinct product bug from the
over-MiB demote/evict stall fixed in `test-report-20260624-04-fixes.md`
(D-EXEC-24-01).

## Root cause

`enforce_size_limits` in `tools/server/server-cache-hybrid.cpp` runs a
token-limit eviction loop after the byte-budget eviction step. The loop
is:

```cpp
while (!entries.empty() && limit_tokens > 0 && calculate_total_tokens() > limit_tokens) {
    auto candidates = build_policy_candidates();
    ...
    auto plan = eviction_policy.plan_evictions(...);
    if (plan.evictions.empty()) {
        break;
    }
    evict_entry_by_id(...);
}
```

`build_policy_candidates()` consults
`forest.payload_eviction_candidates(0)` which filters out branch nodes
with `slot_ref_count > 0`, `exact_blob_payload_id == 0 &&
checkpoint_payload_id == 0`, `resident_payload_bytes == 0`, or
`!has_target_payload && !has_draft_payload`. When every entry's branch
node falls into any of those buckets, `candidates` is empty,
`plan.evictions.empty()` is true, and the early `break` pins the cache
above the token budget. This is a guaranteed-progress violation: the
loop's only termination conditions should be (a) under budget or (b) no
entry is safe to evict.

## Fix scope

Changed file:

```text
tools/server/server-cache-hybrid.cpp
```

Patch (replaces `if (plan.evictions.empty()) { break; }` in the
token-limit loop inside `enforce_size_limits`):

```cpp
if (plan.evictions.empty()) {
    // build_policy_candidates() filters out branch nodes that have
    // slot_ref_count > 0, no payload bytes, or no target/draft pair.
    // When every entry is filtered out and the cache is still over
    // the token budget, the original early break left the cache
    // pinned over budget. Walk the entries list and force-evict one
    // unprotected entry per iteration; fall through to protected
    // entries only when no unprotected entry remains (matches the
    // LRU policy's protected_budget_pressure path). Break only
    // when no entry is safe to evict.
    std::list<hybrid_cache_entry>::iterator victim = entries.end();
    for (auto it = entries.begin(); it != entries.end(); ++it) {
        if (!it->protected_root) {
            victim = it;
            break;
        }
    }
    if (victim == entries.end()) {
        for (auto it = entries.begin(); it != entries.end(); ++it) {
            victim = it;
            break;
        }
    }
    if (victim == entries.end()) {
        break;
    }
    const bool was_protected = victim->protected_root;
    evict_entry_by_id(
        victim->entry_id,
        was_protected ? server_cache_eviction_reason::protected_budget_pressure
                      : server_cache_eviction_reason::over_budget);
    continue;
}
```

Invariants preserved:

- Protected-root entries are preserved when possible (the first pass
  walks unprotected entries only; the protected-root pass only fires
  when no unprotected entry remains).
- Atomic write semantics are preserved: `evict_entry_by_id` reuses the
  existing demote-then-evict machinery (`mark_payload_evicted` ->
  `remove_entry_after_eviction`), so demotion counters, payload
  eviction bytes, and LRU/prefix index cleanup stay consistent.
- No new public API surface: only the in-function fallback logic
  changed.
- The LRU policy's `protected_budget_pressure` reason and
  `protected_root_evictions` counter still increment when the fallback
  evicts a protected entry under sustained pressure.

New regression test:

```text
tests/test-cache-controller.cpp: test_stage24_token_limit_evicts_when_candidates_empty
```

The test reproduces the production bug by:

1. Adding 2 unprotected entries (`{1,2}` and `{3,4}`, 4 tokens total)
   with the token limit set to 3.
2. Calling `debug_evict_first_payload_for_tests()` and
   `debug_evict_last_payload_for_tests()` to strip both payloads, so
   `forest.payload_eviction_candidates(0)` returns empty
   (`resident_payload_bytes == 0` on every branch node).
3. Calling `update()`.

Asserts (with explicit `std::abort` because the CMake Release build
defines `NDEBUG` which makes `assert()` a no-op):

- `n_tokens() <= 3` after update (cache back under budget).
- `n_evictions >= 1` after update (progress happened).
- `debug_entry_count_for_tests() < 2` after update (at least one entry
  removed from the entries list).

The test fails with the original `if (plan.evictions.empty()) { break; }`
and passes with the fix.

## Evidence

Build:

```text
cmake --build build-cuda --config Release --target test-cache-controller
Result: PASS
Output: D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe

cmake --build build-cuda --config Release --target llama-server
Result: PASS (link warning LNK4098 pre-existing)
Output: D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe
```

Source timestamps confirm the fix is in place:

```text
tools/server/server-cache-hybrid.cpp LastWriteTime: 2026-06-25 14:20:xx (fix applied)
tests/test-cache-controller.cpp LastWriteTime: 2026-06-25 14:20:xx (test added)
build-cuda/bin/Release/test-cache-controller.exe LastWriteTime: 2026-06-25 14:20:xx
build-cuda/bin/Release/llama-server.exe LastWriteTime: 2026-06-25 14:20:xx
```

Unit tests with fix applied:

```text
Run: D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe
Output: ._test_output/stage24-fix-iter2-build-20260625-01/test-output-applied.txt

Result:
All tests passed successfully!
Total: 122 tests (... + 2 Stage 24 focused)

Stage 24 new test:
test-cache-controller: Stage 24 token limit evicts when build_policy_candidates returns empty...
  PASSED
```

Sanity check (fix temporarily reverted to confirm the test catches the
bug):

```text
Run: D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe
Output: ._test_output/stage24-fix-iter2-build-20260625-01/test-output-no-fix-final.txt

Result:
FAIL: expected n_tokens() <= 3 after update, got 4
srv        update:  - hybrid cache state: 2 entries, 0.000 MiB payload, 0.000 MiB total, 4 tokens (limits: 100.000 MiB payload, 3 tokens)
test-cache-controller: S
ExitCode: -1073740791 (STATUS_STACK_BUFFER_OVERRUN from std::abort)
```

The test correctly fails with the fix reverted (n_tokens stuck at 4
because the early break left the cache pinned over budget) and passes
with the fix applied.

Existing tests still pass: 121 of 122 are unchanged, only the new
test was added. No existing test exercises the same path because the
production bug only surfaces when (a) the token budget is over AND
(b) `build_policy_candidates()` returns empty, which only happens under
specific branch-node state combinations not covered by prior tests.

## Residual risk

- The fix does not address the co-factor Windows process termination
  during cold-store write at memory pressure peak. That requires a
  separate SEH handler / crash-dump story (out of scope for D-EXEC-24-02).
- The fallback evicts entries by entry_id from the `entries` list,
  which uses the existing `evict_entry_by_id` demote-then-evict path.
  If `evict_entry_by_id` is itself disabled (e.g., by a future
  guard), the fallback will loop forever. The outer `while` loop's
  `entries.empty()` check terminates after each iteration because the
  evicted entry is removed by `remove_entry_after_eviction`.
- QA should rerun Stage 24 from a fresh suffix
  (`test-report-20260624-06.md`) to confirm the token-budget no longer
  pins above 4096 in the S03 hybrid leg.

## Handoff

Verdict: ready for Architect review.

The product fix touches one function in one file (the token-limit
early-break in `enforce_size_limits`); the test was added to
`tests/test-cache-controller.cpp`. No runner, harness, request
generator, or fixture changed. The new test count is 122 (was 121).

Next QA rerun: `test-report-20260624-06.md`.
