# Part 73: TP-39-03 terminal ordering plan

Date: 2026-07-13
Status: HISTORICAL REWORK; SUPERSEDED BY PART 74
Authority: D39-EXEC-12 and design Part 35

## Planned controller changes

All additions compile only with `LLAMA_STAGE39_LIVE_TEST_SEAM`. Public function
signatures and non-seam behavior stay unchanged.

1. Add guarded helpers to query the prepared-proof latch, finish exact step 1,
   verify the terminal TP-39-03 result, and freeze the terminal proof.
2. In `mark_payload_evicted()`, retain the result of the exact-kind call. Check
   the latch immediately. For an active proof session, require exact demotion
   success, reconcile entry accounting, sync its branch, verify both views, and
   store step 2's expected generation. Arm step 2 only after those writes and
   checks. Then invoke the checkpoint-kind call.
3. On a checkpoint abort, return from `mark_payload_evicted()` immediately.
   Do not sync, compensate, roll back, classify, unlink, or process another
   kind. The already synchronized exact result is the coherent final state.
4. In `evict_entry_by_id()`, check the latch immediately after
   `mark_payload_evicted()` and return before demoted/evicted classification,
   counters, and `remove_from_lru_index()`.
5. In `evict_until_within_budget()`, check the latch inside the false-result
   branch and return before the loop break. This suppresses the post-loop
   unsatisfied-budget warning and `record_branch_metadata_pressure()` only for
   a guarded proof abort.
6. Keep the second latch check in `update()` immediately after pressure. Return
   before cleanup, pruning, token pressure, or later diagnostics.
7. In `stage39_live_pressure_control()`, after synchronous `tx_update()` returns,
   check the latch and any guarded post-transaction fault. Then verify exact
   and checkpoint records, final residency and links, one expected decision,
   transactions, LRU state, byte/file accounting, and branch topology. Store
   current `cache_generation_` as `final_generation` and compute the HMAC only
   after all checks pass. Build the response afterward.
8. Retrieval takes `cache_state_mutex_`, verifies the immutable process,
   session, run, step, generation, and HMAC chain plus current-final generation
   equality, then returns the frozen snapshot without mutation.

Prepared capture remains directly after `cold_store.prepare()` and before cold
admission. Existing staging cleanup owns capture failures. No new result enum,
metric label, public route, production exception, or rollback path is added.

## Tests and assertions

Preserve Part 72's five exact test names. Add assertion points, not replacement
tests:

- generation-chain controller case observes exact accounting and branch sync
  before step 2 arm, LRU/update mutations before final freeze, one valid
  retrieval, and later-mutation staleness;
- step 1 abort observes immediate pressure return with no warning or branch
  pressure diagnostic;
- step 2 abort observes exact cold plus checkpoint hot in matching descriptor,
  entry, branch, file, and byte state, with no rollback or post-loop diagnostic;
- route generation case rejects any response or retrieval assembled before
  final freeze;
- route abort case returns terminal failure with no proof body, ordinary
  capacity result, or credential-bearing field.

Focused fault injection may use `LLAMA_SERVER_CACHE_TESTS`, but session state,
capture, abort propagation, finalization, retrieval, and route fields must also
require `LLAMA_STAGE39_LIVE_TEST_SEAM`.

## Verification after authorization

Run focused controller and route suites, PowerShell 5 and 7 self-tests, the
bounded canonical MTP smoke, then the fixed four-shell coverage matrix at 80
percent or higher. Preserve compile-OFF route absence and runtime-OFF rejection.

## Gate

This is documentation only. Design Part 36 found F39-TOR-01; implementation
Part 74 supersedes this handoff under D39-EXEC-13 and design Part 38 records its
generation-owner REWORK. Code, tests, builds, model execution, coverage, QA,
commit, and push remain blocked.
