# Part 75: TP-39-03 read-only generation-boundary plan

Date: 2026-07-13
Status: HISTORICAL PASS; SUPERSEDED BY PART 78
Authority: D39-EXEC-14 and design Part 39

## Planned controller changes

All additions require `LLAMA_STAGE39_LIVE_TEST_SEAM`. Default and runtime-OFF
behavior remain unchanged.

1. Replace Part 74's post-exact refresh/sync sequence with one private guarded
   read-only validator after successful exact-kind return and before checkpoint.
2. Read exact/checkpoint descriptors, hot/cold maps, entry cached accounting,
   branch links and aggregate projection, file/accounting facts, and topology
   totals under `cache_state_mutex_`.
3. Require design Part 39's field matrix. Do not call
   `refresh_entry_payload_accounting()`, `sync_branch_node_from_entry()`, or any
   other mutator from validation.
4. Capture generation at exact-kind return and require it unchanged after reads.
   On mismatch, latch terminal error and return before arm, checkpoint work,
   ordinary classification, or generation call.
5. On success only, call `advance_cache_generation_locked()` once. Store phase
   boundary, require delta one, bind step 2 expected generation, set one-shot
   state, and arm capture in that order.
6. Reject duplicate entry, wrong phase, prior abort, generation drift, and
   overflow before another advance. Preserve Parts 33 and 35 abort returns and
   terminal freeze after full `tx_update()`.
7. Serialize exact-return, phase-boundary, and step 2 expected/observed
   generations once. Validate them before HMAC creation and during retrieval.

No public production route, metric label, cold format, rollback contract,
helper signature, or seam-OFF generation mutation changes.

## Tests and assertions

Add `test_stage39_live_pressure_prepared_proof_read_only_boundary_validation`.
Mismatch each Part 39 field class. Assert unchanged exact-return generation,
terminal abort, exact-cold/checkpoint-hot coherence, and zero arm, checkpoint
call, decision, unlink, and pruning deltas.

Extend `test_stage39_live_pressure_prepared_proof_generation_chain` with
exact-return, validation-entry/exit, boundary, and arm observations. Require
pre-advance equality, delta one, and arm expected generation equal to boundary.
Extend the no-double-advance test to require one advance and one arm after a
rejected duplicate call.

Add `test_live_pressure_prepared_proof_boundary_mismatch_terminal`. Require
redacted terminal error, no proof snapshot, ordinary decision, or boundary
field. Extend the route generation-chain test to require delta one, expected
equality, one ordered boundary, valid HMAC, and tamper rejection. Compile-OFF,
runtime-OFF, and current abort tests remain mandatory.

## Verification after authorization

Run focused controller and route suites, PowerShell 5 and 7 self-tests, bounded
canonical MTP smoke, then fixed four-shell coverage at 80 percent or higher.
Preserve exact generation observations and mismatch-class results.

## Gate

Documentation only. Fresh independent Architect review of design Part 39, this
plan, QA Part 43, entries, index, and current code must pass before Manager
acceptance or implementation. Code, tests, builds, model execution, coverage,
QA, commit, and push remain blocked.
