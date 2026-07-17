# Part 74: TP-39-03 generation-boundary plan

Date: 2026-07-13
Status: REVIEWED REWORK IN DESIGN PART 38
Authority: D39-EXEC-13 and design Part 37

## Planned controller changes

All additions require `LLAMA_STAGE39_LIVE_TEST_SEAM`. The seam-OFF object code,
public signatures, and ordinary pressure behavior stay unchanged.

1. Extend guarded prepared-proof state with
   `exact_demotion_generation`, `phase_boundary_generation`,
   `phase_boundary_advanced`, and an `awaiting_exact_boundary` phase.
2. Add a private guarded helper called only by `mark_payload_evicted()` after a
   successful exact-kind call. Keep existing production helper signatures.
3. In that helper, refresh entry accounting and verify exact-cold plus
   checkpoint-hot descriptor, entry, link, residency, and byte state. Sync the
   branch node, then verify its exact and checkpoint payload views.
4. If verification succeeds and the one-shot flag is clear, capture the
   current generation, call `advance_cache_generation_locked()` once, store
   the new boundary generation, set checkpoint step 2's expected generation,
   mark the boundary complete, and arm capture in that order.
5. If the helper is called twice, the session phase is wrong, the latch is set,
   or verification fails, latch a terminal guarded error and return without an
   advance, capture, checkpoint-kind call, or ordinary capacity result.
6. Keep the checkpoint-kind call after successful arming. Keep Part 35's
   immediate abort returns and post-`tx_update()` terminal freeze.
7. Add both boundary generations and the one-shot state to terminal validation
   and canonical serialization. Compute the HMAC only after validation and
   require retrieval to validate the same ordered chain.

No new metric label, public production route, disk format, rollback path, or
production generation mutation is introduced.

## Assertions

Extend `test_stage39_live_pressure_prepared_proof_generation_chain` with exact
post-demotion, post-sync, pre-arm, and post-arm generation observations. Require
the boundary delta to equal one and checkpoint preparation to observe that
generation.

Add
`test_stage39_live_pressure_prepared_proof_phase_boundary_no_double_advance`.
It exercises a second guarded boundary attempt and requires unchanged
generation, one boundary record, one capture arm, and terminal failure for the
duplicate attempt.

Extend `test_live_pressure_prepared_proof_generation_chain_and_session` to
compare route response and retrieval records field for field. Require the same
exact-demotion and phase-boundary generations, delta one, step 2 expected
generation equality, and a valid HMAC over the complete chain. Mutation of
either boundary field must fail retrieval.

The abort tests require zero boundary advances before verification and no
second boundary advance after a successful boundary. Compile-OFF route absence
and runtime-OFF rejection remain mandatory.

## Verification after authorization

Run focused controller and route suites, PowerShell 5 and 7 self-tests, bounded
canonical MTP smoke, then the fixed four-shell coverage matrix at 80 percent or
higher. Report exact generation values from controller and route evidence.

## Gate

This is documentation only. Design Part 38 records REWORK for F39-GBR-01.
Developer documentation correction and fresh independent Architect review must
PASS before Manager acceptance or implementation. Code, tests, builds, model
execution, coverage, QA, commit, and push remain blocked.
