# Part 79: TP-39-03 fault common-epilogue plan

Date: 2026-07-13
Status: READY FOR INDEPENDENT ARCHITECT REVIEW
Authority: D39-EXEC-17 and design Part 43

## Controller plan

Keep additions under `LLAMA_STAGE39_LIVE_TEST_SEAM`. Preserve public and
production helper signatures.

1. In `mark_payload_evicted()`, retain exact-kind `changed`. Run the guarded
   midpoint observer before the checkpoint call.
2. On midpoint mismatch, latch terminal failure and mark checkpoint skipped.
   Do not call `mark_payload_kind_evicted(... checkpoint)`.
3. On midpoint success, call checkpoint normally. In the prepared-record hook,
   make a step-2 fault return before budget classification, victim enumeration,
   manifest admission, publish, commit, descriptor mutation, hot erase, unlink,
   forest eviction, or ordinary decision/diagnostic recording.
4. Do not return from `mark_payload_evicted()` for either fault. Preserve exact
   `changed`, run its outer common epilogue, reconcile entry accounting from the
   committed descriptors, and invoke existing branch sync once.
5. After the epilogue, validate exact-cold/checkpoint-hot entry, branch, files,
   byte maps, global bytes, links, flags, and residency. Freeze coherent
   terminal fault proof only after validation.
6. Let existing guarded checks in `evict_entry_by_id()`, pressure, and `update()`
   propagate failure before counters, LRU removal, later victims, cleanup, or
   diagnostics. Return one redacted failed control response and no success
   snapshot.

The entry reconciliation must be a no-op for generation because exact demotion
already refreshed accounting. The branch sync is the only required post-exact
epilogue mutation. Do not add a repair helper, explicit generation call, or
second sync.

## Proof and generation plan

Replace the fault-path equality allowance in Parts 41 and 78 with three ordered
observations:

- `exact_return_generation` after exact kind returns;
- `common_sync_generation` after outer branch sync; and
- `final_generation` after `tx_update()` and all update-owned work.

For each fixture where exact commit leaves the branch stale, require
`common_sync_generation > exact_return_generation` and
`final_generation >= common_sync_generation`. Use observed production values;
do not assert a fixed delta. HMAC serialization and retrieval bind and validate
the ordered observations, fault class, optional checkpoint prepared record,
terminal state, and forbidden-effect matrix.

Midpoint fault has no checkpoint prepared record and proves no checkpoint call.
Step-2 fault has one authenticated checkpoint prepared record but proves no
classification, admission, publish, commit, final cold file, or descriptor and
link mutation. Both terminal proofs require coherent entry and branch state
before abort reaches the control response.

## Tests

Add these exact controller tests:

- `test_stage39_live_pressure_prepared_proof_midpoint_fault_common_epilogue`
- `test_stage39_live_pressure_prepared_proof_step2_fault_common_epilogue`

Add these exact route tests:

- `test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal`
- `test_live_pressure_prepared_proof_step2_fault_coherent_terminal`

The midpoint pair proves checkpoint was not attempted. The step-2 pair proves
prepare occurred but checkpoint was not classified, admitted, published, or
committed. All four prove one outer sync, strict production generation order,
coherent exact-cold/checkpoint-hot entry and branch state, request failure, no
success snapshot, no checkpoint or later capacity decision beyond the committed
exact result, no later work, and no explicit or duplicate seam-only generation
advance.

Retain and update success, HMAC tamper, stale retrieval, step-1 abort,
compile-OFF, runtime-OFF, and natural same-owner tests so they use
`common_sync_generation` and reject equality for stale-branch exact commits.

## Handoff

Design Part 43 supersedes the fault-path gaps in Part 41. This plan supersedes
the matching sections of Part 78. Part 42 remains historical REWORK evidence.
Fresh independent Architect review is required before Manager approval or code
work. No code, tests, build, model run, coverage, commit, or push occurred.
