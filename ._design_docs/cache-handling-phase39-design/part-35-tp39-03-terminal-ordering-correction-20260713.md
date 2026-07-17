# Part 35: TP-39-03 terminal ordering correction

Date: 2026-07-13
Status: HISTORICAL REWORK; SUPERSEDED BY PART 37
Scope: F39-SGAR-01 through F39-SGAR-03 only

## Manager decision

D39-EXEC-12 is binding:

> (1) freeze terminal generation/HMAC only after tx_update completes all
> mutations including LRU removal; specify exact feasible hook and retrieval
> ordering. (2) evict_until observes abort latch and returns before any
> post-loop warning/diagnostic/classification. (3) exact demotion accounting +
> branch sync must fully complete before arming/attempting checkpoint
> prepared-size step2; specify phase boundary so step2 failure leaves coherent
> exact result and request fails closed without rollback fiction. Preserve
> accepted session, guard, tests; extend exact assertions for these orderings.

This part supersedes only the ordering in design Part 33. Its session identity,
per-step record bindings, terminal latch, default-OFF seam guard, and named test
map remain binding.

## Exact-kind phase boundary

Current production order is
`mark_payload_evicted()` -> `mark_payload_kind_evicted(exact_blob)` ->
`tx_demote_payload()`. A successful demotion commits the descriptor and cold
transaction, removes hot bytes, reconciles cold gauges, and refreshes entry
payload accounting before `mark_payload_kind_evicted()` returns `true`.

For an active prepared-proof session only, `mark_payload_evicted()` must then:

1. check the terminal latch immediately after the exact-kind call;
2. verify the exact descriptor is cold and the entry accounting matches its
   exact-cold plus checkpoint-hot descriptors;
3. call `sync_branch_node_from_entry(entry)` while holding
   `cache_state_mutex_`;
4. verify the branch links, bytes, flags, and residency view match the entry;
5. only then store step 2's expected generation and arm checkpoint capture;
6. call `mark_payload_kind_evicted(entry, checkpoint)`.

The step 2 generation is the generation after the branch sync. It must be
greater than step 1's observed generation. No checkpoint preparation may run
before this boundary completes. Ordinary sessions keep their existing final
sync behavior.

If checkpoint capture or formula validation fails, `tx_demote_payload()` cleans
its staging file and latches the failure. The checkpoint-kind call returns
`false`; `mark_payload_evicted()` returns immediately. Exact remains cold,
checkpoint remains hot and linked, and descriptor, entry, branch, hot, cold,
and file accounting already agree. No compensation, owner rollback, synthetic
decision, or post-fault repair is allowed.

## Pressure abort return

`evict_entry_by_id()` checks the guarded latch immediately after
`mark_payload_evicted()` and returns `false` before counters, LRU removal, or
entry classification. In `evict_until_within_budget()`, the false-result branch
must check the latch before `break`. A set latch causes an immediate function
return. This skips all remaining victims, the unsatisfied-budget warning, and
`record_branch_metadata_pressure()`. An ordinary false result still breaks and
keeps current behavior.

`update()` checks the latch immediately after `evict_until_within_budget()` and
returns before cold cleanup, metadata pruning, token pressure, and later
diagnostics. The latch remains set through `tx_update()` and reaches the
guarded caller unchanged.

## Terminal finalization and retrieval

The feasible finalization hook is inside
`stage39_live_pressure_control()` immediately after its synchronous
`tx_update()` call returns, while the caller still owns `cache_state_mutex_`.
Finalization is forbidden until all of these checks pass:

1. `tx_update()` returned normally;
2. the prepared-proof latch is clear;
3. exact step 1 and checkpoint step 2 records are complete and ordered;
4. the exact descriptor is cold, the checkpoint is evicted and unlinked, and
   the expected `evicted/both_filled` result exists exactly once;
5. descriptor, entry, branch, LRU, hot/cold bytes, files, transactions, and
   decision counters match the terminal contract;
6. no guarded post-transaction fault is pending.

This location is after `evict_entry_by_id()` has removed the retained entry
from the LRU and after `update()` has finished cold cleanup, metadata pressure,
and token pressure. The hook stores the current production generation as
`final_generation`, serializes the immutable terminal proof, and computes its
HMAC. It performs no cache mutation and does not advance generation. Any failed
check latches a terminal error and returns no successful proof snapshot.

The control response is assembled only after finalization. Retrieval must
validate process identity, session and run IDs, ordered step records, each
expected/observed generation pair, terminal HMAC, and
`cache_generation_ == final_generation` under the same mutex. A later mutation
makes retrieval stale. Retrieval remains read-only and never recomputes or
replaces the frozen snapshot.

## Exact evidence additions

Keep all test names from Part 33. Extend assertions as follows:

- `test_stage39_live_pressure_prepared_proof_generation_chain` checks that step
  2 is armed only after exact descriptor, entry, and branch accounting match;
  terminal generation is later than LRU removal and every update-owned mutation;
  retrieval succeeds once, then rejects a later mutation.
- `test_stage39_live_pressure_prepared_proof_abort_step1_propagation` checks the
  pressure loop emits no post-loop warning or branch-pressure diagnostic.
- `test_stage39_live_pressure_prepared_proof_abort_step2_propagation` checks
  exact remains cold with matching entry/branch links and byte gauges,
  checkpoint remains hot and linked, no rollback occurs, no post-loop
  diagnostic occurs, and the request fails terminally.
- `test_live_pressure_prepared_proof_generation_chain_and_session` checks the
  response appears only after terminal finalization and retrieval uses the
  frozen final generation.
- `test_live_pressure_prepared_proof_terminal_abort_response` checks neither
  abort step returns a proof snapshot or ordinary capacity classification.

## Gate

Implementation Part 73 carries the matching historical plan. Part 36 found
F39-TOR-01; Part 37 supersedes this handoff under D39-EXEC-13 and Part 38
records its generation-owner REWORK. Code, tests, builds, model execution,
coverage, QA, commit, and push remain blocked.
