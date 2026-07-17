# Part 39: TP-39-03 read-only generation-boundary correction

Date: 2026-07-13
Status: HISTORICAL PASS; SUPERSEDED BY PART 41
Scope: F39-GBR-01 only

## Manager decision

D39-EXEC-14 is binding:

> after exact-kind production call returns, do not call
> `refresh_entry_payload_accounting` or `sync_branch_node_from_entry`. Under
> existing mutex, read-only validate entry accounting and both branch views are
> already synchronized by production path; on mismatch latch terminal abort
> before step2. Then exactly one explicit default-OFF guarded generation
> advance, bind/arm step2. Seam-OFF unchanged. Specify exact fields/invariants
> and controller/route assertions for mismatch + delta-one/no-double-advance.

This correction supersedes Part 37's mutating sequence. Parts 33 and 35 still
govern session identity, abort propagation, terminal ordering, post-`tx_update()`
freeze, retrieval, and HMAC validation.

## Feasible read-only hook

`mark_payload_evicted()` runs under `cache_state_mutex_` and processes exact
before checkpoint. Successful `tx_demote_payload()` completion refreshes its
owner entry and calls `sync_branch_node_from_entry()`. The kind wrapper refreshes
the entry again before returning. The guarded hook therefore runs immediately
after successful exact-kind return and before checkpoint, without either mutator.

The hook records current `cache_generation_` as
`exact_demotion_generation`, then validates these fields without changing it:

- Session is active, consumed once, awaiting exact boundary, not aborted, and
  not already advanced or armed.
- Entry owner matches the bound owner. Its exact/checkpoint IDs match bound,
  nonzero, distinct IDs.
- Both descriptors exist. IDs, kinds, owner IDs, pair states, component sizes,
  checksums, and bound session identities match immutable expectations.
- Exact is cold, has a nonzero cold ref, has no hot record, and its cold byte-map
  value equals checked target plus draft bytes.
- Checkpoint is hot. Its hot record exists at its store ref. Resident bytes,
  components, pair state, and checksums match the record and step 2 expectation.
- Entry cached resident bytes equal checkpoint resident bytes; cold exact adds
  zero hot bytes. Cached target/draft flags equal those derived from the hot
  checkpoint descriptor.
- Branch exists at entry branch ID. Exact/checkpoint link IDs, resident bytes,
  and target/draft flags equal entry fields. Since checkpoint remains hot,
  branch residency is hot, metadata-only is false, and absent reason is none.
- Global cold bytes/count, exact file presence, entry/branch counts, and pruning
  totals match the production demotion result captured at exact-kind return.

The exact and checkpoint link fields are the two branch payload views; their
shared residency and byte projection must also match. Validation reads completed
production state. It does not reconstruct or repair it, write metrics/counters,
or call any cache, branch, descriptor, store, LRU, rank, budget, or log mutator.

Any mismatch latches one bounded guarded terminal error before checkpoint
preparation. It does not advance cache generation, arm step 2, emit an ordinary
capacity decision, run checkpoint, or expose IDs, paths, tokens, or HMAC data.
Exact remains cold and checkpoint remains hot.

## Single generation owner

After validation, require generation still equals `exact_demotion_generation`.
Call `advance_cache_generation_locked()` exactly once. Store the new value as
`phase_boundary_generation`, require checked delta one, bind step 2 expected
generation to it, set one-shot boundary state, then arm step 2. Those guarded
session writes do not advance cache generation.

Repeated hook, wrong phase, prior abort, generation drift, or overflow fails
before advance. After success, later attempts fail before any mutator. Checkpoint
starts only after bind and arm. Builds without `LLAMA_STAGE39_LIVE_TEST_SEAM`
contain no hook or advance; runtime seam-OFF behavior is unchanged.

## Exact evidence

- `test_stage39_live_pressure_prepared_proof_read_only_boundary_validation`
  corrupts each descriptor, entry, branch, store, and accounting class. Every
  mismatch keeps exact-return generation, aborts, leaves exact cold/checkpoint
  hot, and records no arm, checkpoint call, decision, unlink, or pruning.
- `test_stage39_live_pressure_prepared_proof_generation_chain` records
  exact-return, validation-entry/exit, boundary, and arm generations. Values
  before advance are equal; boundary is exact-return plus one; expected equals it.
- `test_stage39_live_pressure_prepared_proof_phase_boundary_no_double_advance`
  repeats the hook after success and requires one advance, one arm, unchanged
  boundary generation, and no second checkpoint preparation.
- `test_live_pressure_prepared_proof_boundary_mismatch_terminal` requires a
  redacted terminal response, no proof retrieval or ordinary decision, and no
  boundary generation after mismatch.
- `test_live_pressure_prepared_proof_generation_chain_and_session` requires
  delta one, step 2 expected equality, one boundary in the ordered HMAC record,
  and rejection when either generation is altered.

## Gate

Implementation Part 75 carries the plan. Fresh independent Architect review
must pass before Manager acceptance or code work. Tests, builds, model execution,
coverage, QA, commit, and push remain blocked.
