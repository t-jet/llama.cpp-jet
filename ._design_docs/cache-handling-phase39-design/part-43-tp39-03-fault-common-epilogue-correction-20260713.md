# Part 43: TP-39-03 fault common-epilogue correction

Date: 2026-07-13
Status: READY FOR INDEPENDENT ARCHITECT REVIEW
Scope: D39-EXEC-17 only

## Manager decision

D39-EXEC-17 is binding:

> both post-exact midpoint mismatch and checkpoint step2 fault must skip
> further kind work/classification/admission/unlink but MUST flow through outer
> mark_payload_evicted common accounting/branch sync, then record coherent
> terminal fault proof before latch abort propagates. Generation chain must
> require observed production sync generation strictly greater than
> exact-return generation for stale-branch exact commit; no fixed delta, no
> synthetic/seam-only advance. Define exact controller+route tests for midpoint
> fault and step2 fault: checkpoint not attempted/committed as applicable, sync
> occurs, entry/branch coherent, request fails.

This correction supersedes the fault-path and generation wording in design
Part 41 and implementation Part 78. Part 42 remains the historical review that
opened F39-BBR-01 and F39-BBR-02. Earlier session, prepared-record, HMAC,
terminal-finalization, compile-OFF, runtime-OFF, and natural same-owner
contracts remain binding.

## Feasible control flow

Current code can keep its public and production helper signatures. A successful
exact call returns `true` after `tx_demote_payload()` commits the cold object,
refreshes all entry accounting, erases the hot record, and advances production
generation. `mark_payload_evicted()` carries that `true` in `changed` across the
checkpoint call and invokes `sync_branch_node_from_entry()` in its outer
epilogue. That sync advances production generation.

The guarded implementation adds one skip flag between the two kind calls. A
post-exact midpoint mismatch sets the terminal latch and skip flag. A checkpoint
step-2 capture fault sets the same skip flag before capacity classification.
Neither path returns from `mark_payload_evicted()`. Both preserve exact
`changed`, reach the outer accounting-and-branch epilogue, then expose the latch
to `evict_entry_by_id()`.

The epilogue may call `refresh_entry_payload_accounting(entry)` before branch
sync. This is a read-derived reconciliation of the already committed exact
state; current exact demotion already made it coherent, so the call must not
advance generation in these fixtures. It then calls the existing production
branch sync exactly once. No guarded repair, explicit generation advance, or
second sync is allowed.

## Fault sequence

For a post-exact midpoint mismatch:

1. Keep the exact cold commit and its `changed == true` result.
2. Latch the midpoint fault and skip the checkpoint kind call entirely.
3. Run the outer entry-accounting reconciliation and branch sync.
4. Validate exact-cold/checkpoint-hot entry, branch, descriptor, store, file,
   byte-map, and aggregate state.
5. Record the coherent terminal fault proof, then let latch checks abort
   `evict_entry_by_id()`, the pressure loop, and `update()`.

Checkpoint preparation, classification, admission, transaction commit, hot
erase, descriptor eviction, unlink, forest eviction, later-kind work, later
victims, LRU removal, checkpoint decision metrics, and checkpoint diagnostics
are forbidden. The committed exact decision and cold transaction remain.

For a checkpoint step-2 capture fault, checkpoint preparation has occurred and
its immutable prepared record exists. The fault check removes staging and
returns before cold-budget classification, victim enumeration, manifest
admission, publish, commit, descriptor mutation, hot erase, unlink, or forest
eviction. The outer epilogue then follows steps 3-5 above. No checkpoint cold
file or committed transaction may exist.

The terminal fault proof is available only after the common epilogue validates
coherence. It records the redacted fault class, immutable session and run
bindings, exact prepared record, optional checkpoint prepared record,
generation observations, state reconciliation, and forbidden-effect deltas.
The route returns failure and no success snapshot.

## Production generation chain

Record `exact_return_generation` immediately after exact kind returns. Record
`common_sync_generation` immediately after the outer production branch sync.
When exact committed cold state left its branch stale, require:

`common_sync_generation > exact_return_generation`

This relation applies to midpoint fault, checkpoint step-2 fault, and stale-
branch success. It proves the required production sync happened. It does not
require a numeric delta. Midpoint observation, latch writes, skip state,
prepared-proof capture, terminal-proof serialization, and HMAC creation must
not advance cache generation.

Record `final_generation` after `tx_update()` returns and update-owned work is
finished. Require it not to precede `common_sync_generation`. Authenticate all
three observations in canonical order. Retrieval rechecks their order, the
strict stale-branch relation, current final generation, and HMAC. Reject
equality, reordering, omission, tampering, any explicit guarded advance, and any
duplicate sync.

## Exact tests

Controller tests:

- `test_stage39_live_pressure_prepared_proof_midpoint_fault_common_epilogue`
  corrupts one post-exact midpoint field. It proves exact committed, checkpoint
  prepare/transaction never started, outer accounting and one branch sync ran,
  sync generation is greater than exact return, terminal entry and branch are
  exact-cold/checkpoint-hot and coherent, forbidden deltas are zero, and update
  fails.
- `test_stage39_live_pressure_prepared_proof_step2_fault_common_epilogue`
  faults after checkpoint prepare. It proves staging cleanup, no checkpoint
  classification/admission/publish/commit/cold file/unlink, one outer sync,
  strict generation order, coherent exact-cold/checkpoint-hot state, zero
  forbidden deltas, and failed update.

Route tests:

- `test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal` sends
  the midpoint-fault fixture and requires a redacted failure, no success
  snapshot, no checkpoint attempt, authenticated strict generation order, and
  coherent terminal entry/branch proof.
- `test_live_pressure_prepared_proof_step2_fault_coherent_terminal` sends the
  step-2 fixture and requires a redacted failure, no success snapshot, prepared
  but uncommitted checkpoint proof, authenticated strict generation order, and
  coherent terminal entry/branch proof.

Each test also proves one request failure, no checkpoint or later capacity
result beyond the committed exact decision, no later pressure, and no seam-only
generation advance.

## Gate

Implementation Part 79 carries the matching plan. Fresh independent Architect
review must pass before Manager acceptance or code work. Builds, tests, model
execution, coverage, commits, and pushes remain blocked.
