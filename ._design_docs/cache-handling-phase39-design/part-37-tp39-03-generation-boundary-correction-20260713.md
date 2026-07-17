# Part 37: TP-39-03 generation-boundary correction

Date: 2026-07-13
Status: REVIEWED REWORK IN PART 38
Scope: F39-TOR-01 only

## Manager decision

D39-EXEC-13 is binding:

> add exactly one default-OFF guarded generation advance after exact demotion
> accounting and both branch views have synchronized+verified, before storing
> checkpoint step2 expected generation or arming capture. Bind HMAC/record chain
> to this compound boundary. No advance in production seam-OFF behavior. Add
> exact controller/route generation-chain assertion and no-double-advance case.

This correction supplements Parts 33 and 35. Their session, abort, terminal
ordering, post-`tx_update()` freeze, and retrieval rules remain binding.

## Feasible hook

`mark_payload_evicted()` holds `cache_state_mutex_` and calls the exact kind
before the checkpoint kind. This is the only hook needed. For an active
prepared-proof session, the controller performs this sequence after the exact
kind returns successfully:

1. Reject a set abort latch or any session not awaiting the exact boundary.
2. Record the current generation as `exact_demotion_generation`.
3. Refresh entry payload accounting. Verify the exact descriptor is cold and
   the checkpoint descriptor is hot, with both links and byte totals intact.
4. Call `sync_branch_node_from_entry(entry)`.
5. Verify the branch node's exact link/residency and checkpoint link/residency
   projections against the descriptors and entry. These are the two branch
   payload views covered by this boundary.
6. Call `advance_cache_generation_locked()` exactly once.
7. Store the new value as `phase_boundary_generation` and checkpoint step 2's
   expected generation. Only then mark the boundary complete and arm capture.
8. Call the checkpoint kind.

The helper is compiled only with `LLAMA_STAGE39_LIVE_TEST_SEAM`. It requires an
active session, an `awaiting_exact_boundary` state, and a false
`phase_boundary_advanced` flag. A repeated call fails closed without another
advance or checkpoint preparation. Verification failure also latches the
guarded terminal error before the advance.

The existing demotion generations remain unchanged. The added generation owns
only the verified compound accounting-and-branch boundary. It does not run for
ordinary pressure, a seam-disabled runtime, an abort, failed verification,
read-only discovery or retrieval, or any session outside TP-39-03 prepared
proof. Builds without `LLAMA_STAGE39_LIVE_TEST_SEAM` contain no state, branch,
or call for this advance, so production seam-OFF behavior is unchanged.

## Record and HMAC chain

The immutable step 1 record stores `exact_demotion_generation` and
`phase_boundary_generation`. The latter must equal step 2's expected
generation and must be exactly one greater than the former. Step 2 stores its
observed preparation generation as before. Terminal serialization includes,
in order, session and run IDs, step 1 identity and size fields, both boundary
generations, step 2 identity and size fields, each expected/observed
generation, terminal state, and `final_generation`.

The terminal HMAC covers that serialized record once, after `tx_update()` and
all terminal checks. Retrieval verifies the same ordered fields and HMAC under
the mutex. It rejects a missing boundary generation, unequal step 2 expected
generation, a delta other than one, a duplicate-boundary marker, or a current
generation different from `final_generation`.

## Exact evidence

- `test_stage39_live_pressure_prepared_proof_generation_chain` captures the
  generation after exact demotion, proves both branch payload views match,
  requires one boundary advance, requires step 2 expected generation to equal
  it, and proves capture was not armed earlier.
- `test_stage39_live_pressure_prepared_proof_phase_boundary_no_double_advance`
  calls the guarded boundary twice. The first call advances once and arms step
  2; the second fails closed with unchanged generation and no second capture.
- `test_live_pressure_prepared_proof_generation_chain_and_session` requires the
  route record and retrieval HMAC to carry the same ordered boundary values,
  with `phase_boundary_generation == exact_demotion_generation + 1` and step 2
  expected generation equal to the boundary value.
- Existing step 1 and step 2 abort tests require no boundary advance when the
  boundary was not verified, and no extra advance after a verified boundary.

## Gate

Implementation Part 74 carries the matching plan. Part 38 records REWORK for
F39-GBR-01 because the planned refresh and sync already advance generation.
Developer documentation correction is next. Code, tests, builds, model
execution, coverage, QA, commit, and push remain blocked.
