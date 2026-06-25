# Stage 25 implementation review

Status: REWORK (slot lifecycle routing, tx_assert_mutex_held guard)
Date: 2026-06-25
Stage: 25 (Atomic Transactional Cache Writes)
Reviewer: Architect (FRESH SESSION)
Source: [../cache-handling-phase25-implementation.md](../cache-handling-phase25-implementation.md)
Subject: [part-07-implementation-evidence-20260625.md](part-07-implementation-evidence-20260625.md)

## Verdict

REWORK. 1 BLOCKING (slot lifecycle routing does not match design
contract), 4 non-blocking (tx_assert_mutex_held guard unused,
`tx_apply_restore` `cache_response` order deviation, Stage 24 chat
rerun deferred, evidence claim count off-by-one), 4 INFO.

## Code review (binding requirement)

### tx_* method verification

| Method | Implementation | Conformance |
| --- | --- | --- |
| `tx_restore` (server-cache-hybrid.cpp ~L4613) | Acquires lock, runs lookup helpers, calls `tx_promote_payload` inline for cold residency, returns `cache_response`. | OK |
| `tx_apply_restore` (server-cache-hybrid.cpp ~L4745) | Re-acquires lock, runs owner-view sync, increments `n_apply_restore_owner_view_syncs`. | OK |
| `tx_save` (server-cache-hybrid.cpp ~L4602) | Stub: `GGML_UNUSED` both params, returns false. | DEVIATION (see Findings B-1) |
| `tx_load` (server-cache-hybrid.cpp ~L4611) | Stub: `GGML_UNUSED` both params, returns false. | DEVIATION (see Findings B-1) |
| `tx_demote_payload` (server-cache-hybrid.cpp ~L4444) | Acquires lock, validates eligibility, runs `execute_demotion_inline`, calls `handle_demotion_completion` inline. | OK |
| `tx_promote_payload` (server-cache-hybrid.cpp ~L4527) | Acquires lock, validates eligibility, runs `execute_promotion_inline`, calls `handle_promotion_completion` inline. | OK |
| `tx_evict_entry` (server-cache-hybrid.cpp ~L4595) | Alias to `evict_entry_by_id` which acquires the lock. | OK |
| `tx_update` (server-cache-hybrid.cpp ~L4599) | Alias to `update` which acquires the lock. | OK |
| `tx_assert_mutex_held` (server-cache-hybrid.cpp ~L4429) | Developer-time guard, but NOT called on private mutators. | DEVIATION (see Findings NB-1) |

Reentrancy guard pattern (`stage25_tx::reentrancy_guard`) is
consistent across `tx_demote_payload`, `tx_promote_payload`,
`tx_restore`, `tx_apply_restore`. Default depth limit 4
(OQ-25-04). Counter increments at entry and decrements at
exit via RAII.

`transaction_wait_exceeded` diagnostic at 500 ms default
(OQ-25-03) is exposed via `debug_force_locked_sleep_for_tests`
and increments `n_transaction_wait_exceeded`. Implementation
matches design Part 2 timeout section.

## Worker retirement (binding requirement)

| Aspect | Implementation | Conformance |
| --- | --- | --- |
| `io_worker` thread not started | No `io_worker.start()` or `io_worker.stop()` in hybrid controller; `set_cold_store` called in constructor instead. | OK |
| `enqueue_demotion` / `enqueue_promotion` | Retained as async signatures but thread not started; legacy demote/promote path still reachable via the legacy `demote_payload` / `promote_payload` methods. | OK (Option B per OQ-25-02) |
| `process_completions` (server-cache-hybrid.cpp ~L589) | No-op stub: `(void) io_worker.drain_results();`. | OK |
| `handle_demotion_completion` alignment | Inline call from `tx_demote_payload` after `execute_demotion_inline`. Comment block at hybrid.cpp ~L4431 names the design Part 3 wording verbatim. | OK |
| `execute_demotion_inline` / `execute_promotion_inline` (server-cache-io-worker.cpp) | New methods; return `std::optional<io_completion_result>`; chosen per OQ-25-IMP-02. | OK |

## Slot lifecycle integration (binding requirement)

| Method | Actual routing | Binding requirement | Conformance |
| --- | --- | --- | --- |
| `save_slot` (server-context.cpp L6362) | Acquires `lock_guard` directly. Real save body inline. Does NOT call `tx_save`. | routes through `tx_save` | **FAIL (B-1)** |
| `try_restore_from_cache` (server-context.cpp L6529) | Acquires `lock_guard` directly. Real restore body inline. Does NOT call `tx_restore` + `tx_apply_restore`. | routes through `tx_restore` + `tx_apply_restore` | **FAIL (B-1)** |
| `load_slot` (server-context.cpp L6878) | Acquires `lock_guard` directly. Real load body inline. Does NOT call `tx_load`. | routes through `tx_load` | **FAIL (B-1)** |
| Call sites at server-context.cpp 1087, 1858, 1881, 1886, 4080, 4201 | All six call sites unchanged. | unchanged | OK |

`tx_save` and `tx_load` are stubs returning false. `tx_restore`
is a duplicate implementation that the slot lifecycle does not
call. The atomicity property (lock held for duration) is
preserved by the slot lifecycle's direct `lock_guard`, so
runtime behavior is correct, but the canonical entry-point
contract from design Part 3 is not enforced. The slot lifecycle
and `tx_*` methods now carry parallel implementations with
`tx_*` unused on the production save/restore/load path.

## Test coverage (binding requirement)

10 new tests `test_stage25_*` registered in `main()`
(test-cache-controller.cpp L4767..L4776). Full 132-test pack
PASS confirmed by running `build-cuda\bin\Release\test-cache-controller.exe`
on 2026-06-25. Per-test mapping:

| Test | Spec match | Notes |
| --- | --- | --- |
| `test_stage25_atomic_transaction_blocks_concurrent_writes` (L4399) | TP-25-UT1 atomic transaction blocks concurrent writes | OK; uses `debug_get_cache_state_mutex_for_tests` |
| `test_stage25_demote_inline_under_lock` (L4436) | TP-25-UT2 demote inline under lock | OK; asserts residency `cold` not `demoting` |
| `test_stage25_promote_inline_under_lock` (L4461) | TP-25-UT3 promote inline under lock | OK |
| `test_stage25_save_admit_evict_under_lock` (L4490) | TP-25-UT4 save admit evict under lock | OK |
| `test_stage25_restore_plan_apply_split` (L4510) | TP-25-UT5 restore plan apply split | OK; calls `debug_run_restore_transaction_for_tests` |
| `test_stage25_reentrancy_depth_limit` (L4530) | TP-25-UT6 reentrancy depth limit | OK; pre-loads `server_context_tx_depth_` to limit |
| `test_stage25_no_async_completion_drain` (L4551) | TP-25-UT7 no async completion drain | OK |
| `test_stage25_worker_thread_idle_after_migration` (L4570) | TP-25-UT8 worker thread idle after migration | OK |
| `test_stage25_transaction_wait_exceeded_diagnostic` (L4588) | TP-25-UT9 transaction_wait_exceeded diagnostic | OK |
| `test_stage25_concurrent_slot_requests_n4_contention` (L4603) | TP-25-UT10 concurrent slot requests N=4 | OK |

Test count summary string at L4779 reads
`Total: 132 tests (... + 10 Stage 25 atomic transactional)`. OK.

Each test uses `assert + printf("  PASSED\n")` pattern (matching
the existing TP-17/TP-22/TP-24 style). Test runtime observed
under 1 s each on the Qwen3.5-4B MTP fixture.

`test-cache-controller.cpp` is LF-only (CR=0, LF=4784), zero
trailing whitespace lines. OK.

## Invariants preserved

| Invariant | Conformance |
| --- | --- |
| F-21-EXEC-01 prompt-only save | Unchanged; `save_slot` keeps the existing `slot.task->tokens.clone()` line. OK |
| F-21-RERUN-01 demoting budget | Unchanged; `tx_demote_payload` keeps the demote-budget check. OK |
| F-22-DR-01 already-demoting check | Unchanged; `tx_demote_payload` checks `demoting` residency before generic rejection. OK |
| Stage 5 target/draft pairing | Unchanged in `save_slot` body. OK |
| Stage 6 atomic write + rename | `execute_demotion_inline` reuses `process_demotion`. OK |
| Stage 8 payload eviction vs branch pruning | Unchanged. OK |
| Stage 17 cold budget skip-before-write | Unchanged; `tx_demote_payload` calls `cold_budget_make_room`. OK |
| Stage 22 descriptor-as-source-of-truth | Unchanged. OK |
| D-EXEC-24-01 over-hot-budget skip demotion | Unchanged in `save_slot` body. OK |
| D-EXEC-24-02 token-limit force-evict | Unchanged in `evict_entry_by_id`. OK |
| Stage 16 chat-path prompt-span boundary | Unchanged in `save_slot` and `try_restore_from_cache`. OK |

## Hygiene

- Compile clean: `cmake --build build-cuda --config Release --target test-cache-controller` and `--target llama-server` produce zero errors. Pre-existing LNK4098 CRT linkage warning unchanged.
- Test pass: 132/132 PASS confirmed on 2026-06-25.
- Binary mtimes: `test-cache-controller.exe` 2026-06-25 20:30:48 (155,132,928 bytes), `llama-server.exe` 2026-06-25 20:28:04 (168,670,720 bytes). OK.
- `git diff --check` on durable docs (`.md` files): clean. No trailing whitespace in implementation part files.
- `git diff --check --no-index /dev/null part-07-implementation-evidence-20260625.md` exits 1 with content-diff noise only (no whitespace warnings).
- `server-cache-hybrid.cpp` is CRLF (CR=4822 LF=4822) per pre-existing repo convention; pre-existing 1 trailing-whitespace line at L4331 is not Stage 25 work.
- `test-cache-controller.cpp` is LF-only (CR=0, LF=4784), zero trailing whitespace.
- `server-context.cpp` is CRLF, 1 pre-existing trailing-whitespace line not Stage 25 work.
- `server-cache-hybrid.h` is LF-only, zero trailing whitespace.
- `git diff -w --numstat` confirms real content change: 464/27 server-cache-hybrid.cpp, 131/0 .h, 24/0 server-context.cpp, 54/0 io-worker.cpp, 22/0 io-worker.h, 264/1 test-cache-controller.cpp.

## Open issues from Developer evidence

- Issue 1 (`tx_save` stub): CONFIRMED. `tx_save` and `tx_load` return false; the slot lifecycle does not delegate to them. See B-1.
- Issue 2 (Stage 24 chat S02/S03 rerun deferred to QA): ACCEPTABLE per binding hard constraint that Developer does not touch runner scripts.
- Issue 3 (`cache_response.lookup_namespace_id` field): ACCEPTABLE. Field is added between `pair_state` and `fallback_used` in the struct declaration; ordering consistent with the design Part 2 plan section (`lookup_namespace_id` is computed during lookup).

## Findings

### BLOCKING

**B-1.** Slot lifecycle does not route through `tx_*` methods.

- `save_slot` (server-context.cpp L6362-6519) acquires `lock_guard<std::recursive_mutex>` and implements the save body inline. Does not call `tx_save`. `tx_save` is a stub returning false (server-cache-hybrid.cpp L4602-4610).
- `try_restore_from_cache` (server-context.cpp L6529-6877) acquires `lock_guard` and implements restore body inline. Does not call `tx_restore` or `tx_apply_restore`. `tx_restore` is a duplicate implementation (server-cache-hybrid.cpp L4613-4743) and `tx_apply_restore` is implemented (L4745-4784) but neither is called from the slot lifecycle.
- `load_slot` (server-context.cpp L6878-...) acquires `lock_guard` and implements load body inline. Does not call `tx_load`. `tx_load` is a stub returning false (server-cache-hybrid.cpp L4611-4616).

Effect: design Part 3 row 19 (`save_slot -> tx_save`), row 20 (`try_restore_from_cache -> tx_restore + tx_apply_restore`), and row 21 (`load_slot -> tx_load`) are not implemented as specified.

Runtime atomicity is preserved (each method holds the lock for the duration of its work), but the canonical entry-point pattern from design Part 2 ("public transaction API that acquires the mutex once") is not enforced.

Fix: move the save body into `tx_save` and call from `save_slot`; move the restore body into `tx_restore` + `tx_apply_restore` and call from `try_restore_from_cache`; move the load body into `tx_load` and call from `load_slot`. Keep the recursive-mutex contract. `tx_save` and `tx_load` stubs must be replaced with real implementations (or the stubs removed if no canonical entry is needed for tests).

### Non-blocking

- **NB-1.** `tx_assert_mutex_held` declared (server-cache-hybrid.cpp L4429) but not called on any private mutator (mark_payload_evicted, mark_payload_kind_evicted, cold_budget_make_room, attach_payload, admit_entry_with_payload, materialize_entry_payload, remove_payload, sync_branch_node_from_entry, refresh_entry_payload_accounting). The binding requirement says "developer-time guard on private mutators". The helper exists but is unused. Fix: add `tx_assert_mutex_held()` at the top of each private mutator that mutates cache state, or document why the guard is opt-in for tests only.
- **NB-2.** `cache_response` struct order: `lookup_namespace_id` is positioned between `pair_state` and `fallback_used`. The evidence Part 7 says the order was confirmed against design Part 2 plan section, but the design does not specify field order; this is a style choice. ACCEPTABLE.
- **NB-3.** Evidence Part 7 claims "464 insertions, 27 deletions" for server-cache-hybrid.cpp; `git diff --numstat` returns 4822/4385 because git's i/lf vs w/crlf index rewrite inflates the stat. `git diff -w --numstat` (whitespace-ignored) returns 464/27 as claimed. This is the pre-existing CRLF/LF git noise documented in repo memory. ACCEPTABLE.
- **NB-4.** `server-cache-hybrid.cpp` evidence claim `464/27` is correct under `git diff -w --numstat`. `test-cache-controller.cpp` evidence claim `265/0` is off-by-one: `git diff -w --numstat` returns `264/1`. The 1 deletion is the old `Total: 122 tests` line replaced by `Total: 132 tests`. Minor doc nit. ACCEPTABLE.

### INFO

- **I-1.** The implementation evidence correctly identifies the slot-lifecycle routing deviation as an open issue but treats it as non-blocking. The Architect binding requirement treats it as BLOCKING (B-1 above). The Developer evidence classification disagrees with the binding review criteria.
- **I-2.** `tx_evict_entry` and `tx_update` are aliases (`return evict_entry_by_id(...);` and `update();`) rather than owning the lock directly. The aliased methods acquire the lock, so this is correct under the recursive-mutex contract. ACCEPTABLE.
- **I-3.** `debug_force_reentrant_call_for_tests` (server-cache-hybrid.cpp ~L4770) calls `tx_save` which is a stub returning false. The test reentrancy counter therefore exercises the guard via the stub's lock acquisition path but does not exercise a real reentrancy scenario through `save_slot -> tx_evict_entry`. ACCEPTABLE for unit-test scope.
- **I-4.** Stage 24 chat S02/S03 comparison rerun deferred to QA. ACCEPTABLE per binding hard constraint that Developer does not touch runner scripts.

## Handoff

Next owner: Developer. Required correction list:

1. B-1: route `save_slot` through `tx_save` (replace stub), `try_restore_from_cache` through `tx_restore` + `tx_apply_restore`, and `load_slot` through `tx_load` (replace stub). Keep `tx_*` method signatures as-is; move bodies from slot lifecycle into `tx_*` methods; have slot lifecycle call `tx_*` after delegating.
2. NB-1: add `tx_assert_mutex_held()` at the top of each private mutator that mutates cache state (mark_payload_evicted, mark_payload_kind_evicted, cold_budget_make_room, attach_payload, admit_entry_with_payload, materialize_entry_payload, remove_payload, sync_branch_node_from_entry, refresh_entry_payload_accounting).
3. NB-2..4: optional doc and stat corrections.

After corrections, run the full 132-test pack again and update
part-07 evidence with corrected stat numbers if applicable.
Manager implementation gate D25-EXEC-01 stays pending until B-1
is corrected and the Architect re-review returns PASS.

This file uses LF line endings, plain ASCII labels, no BOM, no
trailing whitespace, and stays under the 300-line durable-doc
cap.
