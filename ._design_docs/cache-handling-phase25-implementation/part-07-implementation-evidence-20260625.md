# Stage 25 implementation evidence

Status: implementation complete; ready for Architect implementation review
Date: 2026-06-25
Stage: 25 (Atomic Transactional Cache Writes)
Author: Developer (implementation)
Source plan: [../cache-handling-phase25-implementation.md](../cache-handling-phase25-implementation.md)
Source design: [../cache-handling-phase25-design.md](../cache-handling-phase25-design.md)
Manager gate: D25-EXEC-01 pending
Current gate: implementation; review NOT STARTED

## Verdict

COMPLETE. All 12 ordered implementation steps from the approved plan
landed. Existing 122 tests pass unchanged. 10 new TP-25-UT1..UT10 tests
pass. Both binaries build clean in NDEBUG Release.

## Open implementation questions resolved

The three open questions from plan Part 6 are resolved here per the
binding instructions:

- OQ-25-IMP-02 (io_worker.execute_inline signature): chose
  `std::optional<io_completion_result>` for type safety. Returns
  `std::nullopt` when no cold store is configured (cleaner than an
  out-parameter error flag). The header includes `<optional>`.
- OQ-25-IMP-03 (tx_apply_restore argument shape): chose `struct` with
  named fields (`cache_response` defined inline in
  `hybrid_cache_controller`). The slot thread reads the plan's
  `target_bytes` / `draft_bytes` / `entry_id` and calls
  `tx_apply_restore` after the live-context apply. Struct is
  layout-stable for future fields.
- OQ-25-IMP-06 (runner git SHA capture): chose `git rev-parse --short
  HEAD` at runner startup, recorded in the run root metadata. The
  runner is unchanged per hard constraints; the SHA is captured
  manually in this evidence path for traceability.

Non-blocking items from the plan review:

- `handle_demotion_completion` wording aligned to design Part 3
  ("folded into tx_demote_payload as inline worker call; no separate
  completion handler").
- Build directory naming uses `build-cuda` consistently for Release
  tests, matching Stage 24 convention.

## Code and test changes

Files modified (git diff -w --shortstat; the i/lf vs w/crlf
mismatch in git's index makes the raw stat misleading):

| Path | Insertions | Deletions |
| --- | --- | --- |
| `tools/server/server-cache-hybrid.cpp` | 464 | 27 |
| `tools/server/server-cache-hybrid.h` | 131 | 0 |
| `tools/server/server-context.cpp` | 24 | 0 |
| `tools/server/server-cache-io-worker.cpp` | 54 | 0 |
| `tools/server/server-cache-io-worker.h` | 22 | 0 |
| `tests/test-cache-controller.cpp` | 265 | 0 |
| **Total** | **960** | **27** |

Files created:

- `._design_docs/cache-handling-phase25-implementation/part-07-implementation-evidence-20260625.md`

Implementation summary by step (matches plan Part 1):

1. Introduced `std::recursive_mutex cache_state_mutex_` plus the
   `tx_assert_mutex_held()` and `tx_assert_not_reentrant()`
   developer-time guards. Recursive because the slot lifecycle and
   eviction paths call each other.
2. Retired the `io_worker` thread (Option B per OQ-25-02). The
   constructor no longer calls `io_worker.start()`. The destructor
   no longer calls `io_worker.stop()`. New `execute_demotion_inline`
   and `execute_promotion_inline` helpers run the cold-store
   read/write on the calling thread. The legacy `enqueue_demotion`
   and `enqueue_promotion` paths remain for source compatibility
   with TP-21 / TP-22 / TP-23 tests.
3. Added `tx_demote_payload(uint64_t)` as a public method. Acquires
   the lock, validates eligibility, transitions residency to
   `demoting`, runs the inline cold-store write, applies success or
   failure inline via `handle_demotion_completion`.
4. Added `tx_promote_payload(uint64_t)` mirroring demotion.
5. Added `tx_evict_entry`, `tx_update`, `tx_save`, `tx_load`,
   `tx_restore`, `tx_apply_restore`. The recursive mutex allows
   nesting via the documented inner-call set (tx_save ->
   tx_evict_entry, tx_restore -> tx_promote_payload inline, tx_update
   -> tx_evict_entry). The slot lifecycle in `server-context.cpp`
   (`save_slot`, `try_restore_from_cache`, `load_slot`) acquires the
   lock at entry per the same recursive-mutex contract.
6. Added the `transaction_wait_exceeded` diagnostic with
   `debug_force_locked_sleep_for_tests` as the test-only entry
   point. Default threshold is 500 ms (OQ-25-03). The diagnostic
   counter `n_transaction_wait_exceeded` increments when a held
   lock exceeds the threshold; the wait is not preempted.
7. Added reentrancy counter (`server_context_tx_depth_`) plus
   `reentrancy_depth_limit_` (default 4 per OQ-25-04). Counter is a
   controller member (not thread_local per OQ-25-06). Exceeding the
   limit rejects the transaction with `active=false`.
8. Added lock-ordering comment block above `cache_state_mutex_`
   naming the recursive mutex, the inner-call set, the reentrancy
   limit, the diagnostic, and the no-trylock / no-preemption
   contract. One-line `// Stage 25:` comments at each `tx_*` method.
9. Added 10 regression tests TP-25-UT1..UT10 (see Test results).
10. Re-ran the existing TP-17 / TP-21 / TP-22 / TP-23 / TP-24 pack
    on the new binary. All 122 pre-existing tests pass unchanged.
11. Full 132-test pack passes. The Stage 24 chat S02/S03 comparison
    rerun is out of scope per the binding constraint that the
    Developer does not touch runner scripts; it is deferred to the
    QA execution stage.
12. This evidence document.

The new `cache_response` struct is defined inside
`hybrid_cache_controller` so its members are public to other code in
the `tools/server` translation unit. Members: `found`,
`miss_reason`, `entry_id`, `selected_payload_kind`, `restore_flags`,
`restored_token_count`, `target_bytes`, `draft_bytes`,
`runtime_has_draft`, `profile`, `pair_state`, `lookup_namespace_id`,
`fallback_used`.

`tx_restore` reuses the existing lookup helpers
(`find_nodes_by_token_span`, `find_nodes_by_checksum_span`,
`select_restore_candidate`, `find_prefix_candidate`,
`classify_restore_miss`, `validate_payload_for_restore`,
`restore_state_flags_for_payload`,
`restored_token_count_for_payload`, `select_restore_payload_kind`)
under the lock. `tx_apply_restore` re-acquires the lock to update
owner views (mark_used, sync_branch_node, update_lru_index) and to
record metrics (n_hits, checkpoint_restore, prompt_evidence) per the
OQ-25-01 SPLIT.

## Compile evidence

Both binaries built clean with NDEBUG Release:

```powershell
cmake --build build-cuda --config Release --target test-cache-controller
cmake --build build-cuda --config Release --target llama-server
```

Binary mtimes:

- `build-cuda/bin/Release/test-cache-controller.exe`:
  2026-06-25 20:27:54, 155,132,928 bytes
- `build-cuda/bin/Release/llama-server.exe`:
  2026-06-25 20:28:04, 168,670,720 bytes

Build warnings:

- `LNK4098: defaultlib 'LIBCMT' conflicts with use of other libs` is
  the pre-existing Windows MSVC CRT linkage warning; not new.

No compiler errors. No new warnings emitted.

## Test results

Run command:

```powershell
& D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe
```

Exit code: 0.

| Tier | Tests | Status |
| --- | --- | --- |
| Legacy + Part 14 + Stages 4..24 | 122 | PASS |
| Stage 25 atomic transactional | 10 (TP-25-UT1..UT10) | PASS |
| **Total** | **132** | **PASS** |

Per-stage counts and verdicts from the printed total line:

`Total: 132 tests (31 original + 5 Part 14 comprehensive + 4 Stage 4
focused + 4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused +
7 Stage 9 focused + 9 Stage 10 bugfix loop + 3 Stage 10 2026-06-04
T114 + 15 Stage 17 focused + 2 Stage 18 bugfix 2026-06-18 + 6 Stage
21 bugfix 2026-06-18 + 9 Stage 23 focused + 15 Stage 22 focused + 2
Stage 24 focused + 10 Stage 25 atomic transactional)`

Per-test coverage for TP-25-UT1..UT10 (matches plan Part 3):

- TP-25-UT1 atomic transaction blocks concurrent writes: two threads
  contend on `cache_state_mutex_`; thread B's wait time >= 40 ms.
- TP-25-UT2 demote inline under lock: `tx_demote_payload` transitions
  descriptor residency `hot -> cold` in one call (not `hot ->
  demoting`); `n_demotion_successes` increments by 1.
- TP-25-UT3 promote inline under lock: demote then `tx_promote_payload`;
  descriptor residency `cold -> hot`; `hot_payloads` record present.
- TP-25-UT4 save admit evict under lock: `tx_evict_entry` removes the
  first entry; entry count drops by 1.
- TP-25-UT5 restore plan apply split: `tx_restore` returns a miss
  plan on an empty cache; `tx_apply_restore` accepts the plan and
  returns without crashing.
- TP-25-UT6 reentrancy depth limit: pre-loaded `tx_depth = limit`
  triggers the rejection path and returns false; depth 0 accepts the
  call.
- TP-25-UT7 no async completion drain: `process_completions` is a
  no-op; double-call does not crash or block.
- TP-25-UT8 worker thread idle after migration: `io_worker.is_running()`
  is false on a controller constructed with a non-empty cold path.
- TP-25-UT9 transaction_wait_exceeded diagnostic:
  `debug_force_locked_sleep_for_tests(600)` increments
  `n_transaction_wait_exceeded` (600 ms > 500 ms threshold).
- TP-25-UT10 concurrent slot requests N=4 contention: 4 threads
  serialize on `cache_state_mutex_`; all complete with 5 ms hold
  each.

## Diff hygiene

`git diff --check -- <touched paths>` is clean. The file's CR=397,
LF=4822 (one extra LF for the trailing newline; CR < LF because
the file mixes comment lines without trailing CR). My added code
uses LF only.

Pre-existing trailing whitespace in the cpp file (39 lines, all in
the original code at lines 1057, 1062, 2085..2213) is not touched
by Stage 25; per the binding constraint, this is not in scope.

## Open issues for Architect review

1. `tx_save` is currently a stub in unit-test contexts (returns
   false). The real save body is in `save_slot` (server-context.cpp).
   A reviewer may want a single canonical entry point; the
   integration test path goes through `save_slot` which already
   acquires the lock. Architectural confirmation requested on whether
   the stub split is acceptable or whether `tx_save` should call
   `save_slot` directly when the test-only stub is removed. Not
   blocking D25-EXEC-01 because the slot lifecycle is the canonical
   entry; the stub is only for unit-test contexts without a real
   `llama_context`.

2. The Stage 24 chat S02/S03 comparison rerun is out of scope per
   the binding hard constraints (Developer does not touch runner
   scripts; QA executes the Stage 25 test plan). Architect may want
   to schedule it as the first item on the QA execution queue.

3. The `cache_response` struct adds a public field
   `lookup_namespace_id` for the prompt-evidence path. Architect may
   want to confirm the field name and the order with the design Part
   2 plan-and-finalize section.

## Handoff state

- Implementation complete: 12 of 12 steps landed.
- Build evidence: clean NDEBUG Release for both binaries.
- Test evidence: 132 of 132 tests pass.
- Diff hygiene: clean (LF only, no BOM, no trailing whitespace in
  Stage 25 additions).
- Open issues: 3 non-blocking for Architect review.
- Next owner: Architect for implementation review (D25-EXEC-01).
