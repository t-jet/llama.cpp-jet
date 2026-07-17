# Part 41: TP-39-03 both-kind batch-boundary correction

Date: 2026-07-13
Status: REVIEWED REWORK IN PART 42
Scope: D39-EXEC-16 only

## Manager decision

D39-EXEC-16 is binding:

> align proof with real both-kind batch boundary. After exact demotion, midpoint
> read-only validation must exclude branch aggregate; validate only facts
> production has finalized (entry accounting, descriptor/store/file, prepared
> record). Attempt checkpoint. After both-kind attempt, always reach
> existing/common accounting + branch synchronization cleanup before honoring
> guarded terminal latch. On step2 failure, cleanup may only reconcile
> accounting/branch views for already committed exact state; no further
> classification/admission/unlink/eviction. Final post-tx_update proof validates
> branches. Remove synthetic exactly-one boundary advance; record and
> authenticate actual ordered production generation advances and assert no
> extra seam-only advance. Seam-OFF unchanged.

This correction supersedes design Part 39. Part 40 and Manager Part 76 are
historical approvals of the infeasible read-only branch-aggregate boundary.
Parts 33 and 35 still govern session identity, fail-closed propagation,
post-`tx_update()` finalization, retrieval, and HMAC checks where this part does
not replace their midpoint, cleanup, or generation wording.

## Feasibility and ownership

No public or production helper signature must change. Current control flow is:

1. `mark_payload_evicted()` calls `mark_payload_kind_evicted()` for exact.
2. Successful `tx_demote_payload()` commits the exact cold object, updates its
   descriptor and cold maps, removes its hot record, and refreshes entry
   accounting. It does not synchronize the branch.
3. `mark_payload_evicted()` calls the checkpoint kind.
4. Its existing `changed` path synchronizes the branch after both kind calls.

The guarded proof must follow that ownership. It may add latch checks and
read-only observations around these calls. It must not move production branch
sync into the exact-kind boundary or add a seam-only cache mutation.

## Midpoint proof

After exact returns successfully and before checkpoint starts, validate only
state finalized by exact demotion:

- active immutable process, session, run, owner, request, role, and step-1
  bindings;
- one complete step-1 prepared record with exact payload ID, kind, pair state,
  component sizes, checksums, immutable serialized bytes, and observed
  generation;
- exact descriptor is cold, owns the expected cold ref, has no hot record, and
  matches the final `.cold` file and per-ID cold-byte map;
- global cold bytes and file count include that exact object once;
- checkpoint descriptor and hot record remain unchanged and hot; and
- entry links still name both descriptors, while entry resident bytes and
  target/draft flags project only the hot checkpoint.

Do not compare branch links, resident bytes, flags, residency, metadata-only
state, or absent reason at this boundary. They are intentionally stale until
the common both-kind cleanup. A mismatch latches a terminal step-1 boundary
error and skips checkpoint. It does not repair cache state or advance
generation.

If validation passes, bind step 2 to the current production generation and arm
checkpoint capture once. These guarded proof-state writes are not cache
mutations. Then call the normal checkpoint kind.

## Common cleanup and terminal latch

After the checkpoint kind returns, the batch completes existing cleanup before
a guarded terminal latch is honored. Exact-kind return already owns refreshed
entry accounting. Outer `changed == true` owns branch synchronization, including
when checkpoint preparation latches a step-2 fault. Do not add a second refresh,
repair call, or seam-only mutator.

On step-2 fault, `mark_payload_kind_evicted()` must inspect the latch before
capacity classification. It returns without a decision, transaction admission,
descriptor eviction, hot-record erase, owner-link clear, forest eviction, or
later payload work. Common cleanup may only refresh the entry and synchronize
the branch from the already committed exact-cold/checkpoint-hot state. After
that cleanup, `evict_entry_by_id()`, the pressure loop, and `update()` honor the
latch before counters, LRU changes, later pressure, or diagnostics.

The guarded caller handles the failed `tx_update()` result only after checking
that exact is cold, checkpoint is hot and linked, entry accounting matches the
checkpoint, both branch payload links match the entry, branch aggregate and
residency match the checkpoint-hot projection, files and byte maps reconcile,
and no forbidden step-2 side effect occurred. It returns one redacted terminal
error and no proof snapshot.

For success, checkpoint capacity handling and common cleanup finish normally.
The existing post-`tx_update()` finalizer validates descriptor, entry, branch,
LRU, decision, transaction, hot/cold bytes, and file state before freezing the
terminal proof and HMAC. Branch aggregate is authoritative only here.

## Production generation chain

Remove `phase_boundary_generation` and the explicit guarded call to
`advance_cache_generation_locked()`. Capture actual production observations:

1. `step1_prepare_generation` at exact preparation;
2. `exact_return_generation` after exact demotion's normal mutation advances;
3. `step2_expected_generation`, equal to `exact_return_generation` after the
   read-only midpoint;
4. `step2_prepare_generation`, equal to its expected value;
5. `both_kind_complete_generation` after normal checkpoint handling and common
   cleanup; and
6. `final_generation` after `tx_update()` and all update-owned mutations.

The ordered record requires step 1 before exact return, no generation change
through midpoint bind/arm, and step 2 at its expected generation. Successful
checkpoint eviction must advance production generation after step 2;
`final_generation` must not precede the both-kind value. A step-2 capture fault
may leave both-kind generation equal to exact return because cleanup can be a
projection-only write. It cannot produce a seam-only advance.

The terminal HMAC authenticates every observation, its order, both prepared
records, terminal state, and final generation. Retrieval rechecks the same
chain and current final generation. It rejects missing, reordered, duplicated,
or altered observations. No fixed delta is required because production helpers
own multiple conditional advances.

## Exact evidence

Controller tests:

- `test_stage39_live_pressure_prepared_proof_midpoint_excludes_branch_aggregate`
  gives the branch its expected pre-cleanup aggregate and proves midpoint pass,
  step-2 arm, and no repair or generation change.
- `test_stage39_live_pressure_prepared_proof_real_generation_sequence` proves
  the ordered observations above and zero seam-only advances.
- `test_stage39_live_pressure_prepared_proof_both_kind_success_coherence`
  proves common cleanup precedes success finalization and final branch state.
- `test_stage39_live_pressure_prepared_proof_step2_fault_common_cleanup`
  injects failure after checkpoint prepare and requires coherent
  exact-cold/checkpoint-hot entry, branch, files, and bytes, plus zero checkpoint
  decision, admission, unlink, eviction, LRU, later-pressure, and diagnostic
  deltas.

Route tests:

- `test_live_pressure_prepared_proof_real_generation_sequence` verifies the
  authenticated ordered observations and tamper rejection.
- `test_live_pressure_prepared_proof_step2_fault_coherent_terminal` requires
  the redacted terminal response, no snapshot, and the same no-side-effect
  matrix as the controller fault test.

Compile-OFF, runtime-OFF, step-1 abort, stale retrieval, and natural same-owner
TP-39-03 tests remain binding.

## Gate

Implementation Part 78 carries the matching plan. Part 42 records REWORK for
midpoint-fault cleanup and fault-generation ordering. Fresh independent
Architect re-review must pass before Manager acceptance or code work. No build,
test, model run, coverage, commit, or push is authorized.
