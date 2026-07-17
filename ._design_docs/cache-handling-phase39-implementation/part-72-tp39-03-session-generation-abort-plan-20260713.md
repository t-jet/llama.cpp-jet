# Part 72: TP-39-03 session, generation, and abort plan

Date: 2026-07-13
Status: ORDERING SUPERSEDED BY DESIGN PART 35 AND IMPLEMENTATION PART 73
Authority: D39-EXEC-11 and design Part 33

## Planned controller work

All live proof code uses `LLAMA_STAGE39_LIVE_TEST_SEAM`. Keep the existing
function signatures and default build behavior.

1. Extend strict apply parsing with one bounded `run_id`. After all retryable
   checks pass, create a CSPRNG `test_session_id`, consume setup, and store both
   IDs in one immutable controller session.
2. Store discovery generation, post-setup generation, expected step,
   per-step expected generation, and final generation. Use the existing
   production `cache_generation_`; do not add a shadow mutation counter.
3. At validated exact preparation, require session, step 1, and current expected
   generation. Record exact bytes and all Part 31 bindings. After normal exact
   demotion succeeds, set step 2's expected generation to current generation.
4. At validated checkpoint preparation, require session, step 2, and its own
   expected generation. Record checkpoint bytes and validate the two-size
   formula. After normal checkpoint eviction completes, store final generation
   and freeze the HMAC snapshot.
5. Retrieval checks process, both session IDs, exact ordered steps, expected and
   observed generation equality per step, monotonic order, terminal generation,
   HMAC, and current generation. It accepts the expected checkpoint mutation
   and rejects any later mutation.

## Planned abort work

Add one guarded terminal latch with fixed codes and failed-step metadata.

1. Capture or formula failure removes the prepared staging file, latches the
   error, and makes `tx_demote_payload()` return `false` before admission.
2. In `mark_payload_kind_evicted()`, check the latch immediately after that
   false return and before capacity classification, decisions, residency,
   bytes, owner links, accounting, or forest writes.
3. In `mark_payload_evicted()`, check after exact and checkpoint calls so no
   later kind runs after abort.
4. In `evict_entry_by_id()`, return before counters, LRU, or entry handling.
   Let `evict_until_within_budget()` stop on the existing false result.
5. In `update()`, return immediately after pressure if the latch is set. Leave
   it intact through `tx_update()` so guarded control returns terminal `FAIL`.

Step 1 failure retains exact and checkpoint hot. Step 2 failure retains exact
cold and checkpoint hot. Do not undo a committed exact demotion. Require no
manifest, quarantine, final file, decision, transaction, tombstone, unlink, or
admission accounting for the rejected object. Cleanup failure stays terminal
and adds a bounded mismatch flag.

## Route and driver work

The authenticated loopback response may return `test_session_id`, `run_id`,
fixed status, generations, steps, sizes, and mismatch flags. Redact credentials,
nonce, paths, content, prompts, tokens, and HMAC inputs. Logs and metrics omit
both session IDs.

`Assert-Tp3903` must require one session across apply, pressure, proof, and final
artifacts. It validates the exact generation chain and only then recomputes
resident and serialized formulas. A later generation, mixed run, missing step,
or abort cannot pass. Step 1 or step 2 abort after pressure starts is `FAIL`.

## Exact tests

Preserve every controller and route name in Part 71 and test-plan Part 43. Add:

- `test_stage39_live_pressure_prepared_proof_generation_chain`
- `test_stage39_live_pressure_prepared_proof_abort_step1_propagation`
- `test_stage39_live_pressure_prepared_proof_abort_step2_propagation`
- `test_live_pressure_prepared_proof_generation_chain_and_session`
- `test_live_pressure_prepared_proof_terminal_abort_response`

The generation test covers expected checkpoint mutation plus later-mutation
staleness. Step tests inject binding and formula failure at the real preparation
boundary, verify staging cleanup and exact stop points, and prove no ordinary
classification, admission, unlink, or remaining-kind processing occurs.

Compile-off evidence must use CMake option and macro
`LLAMA_STAGE39_LIVE_TEST_SEAM`. `LLAMA_SERVER_CACHE_TESTS` is allowed only for
focused fault injection. Run focused controller and route suites, PowerShell
self-tests, one bounded canonical MTP smoke, then the fixed four-shell coverage
matrix at 80 percent or higher after implementation authorization.

## Gate

Design Part 33 and this plan are documentation corrections only. Design Part 34
records historical ordering REWORK. Design Part 35 and implementation Part 73
apply D39-EXEC-12. Fresh independent Architect review is next. Manager
acceptance, implementation, model execution, coverage, QA, commit, and push
remain blocked.
