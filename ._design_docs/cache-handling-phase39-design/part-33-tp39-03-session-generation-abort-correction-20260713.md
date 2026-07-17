# Part 33: TP-39-03 session, generation, and abort correction

Date: 2026-07-13
Status: ORDERING SUPERSEDED BY PART 35; PART 34 REWORK HISTORICAL
Scope: F39-PSR-01 through F39-PSR-03 only

## Manager decision

D39-EXEC-11 is binding:

> Use immutable guarded test_session_id/run_id established by apply; each
> prepared-size record binds its own observed cache generation + monotonic
> expected step. Retrieval validates same session, exact ordered step chain,
> expected per-step generations, and final generation; do not require one
> generation across mutations. Define terminal error propagation from
> capture/formula validation through tx_demote_payload ->
> mark_payload_kind_evicted -> mark_payload_evicted -> tx_update so failure
> stops marking/admission and request fails closed; inspect actual signatures
> and specify minimal compatible result plumbing/rollback. Use actual
> default-OFF LLAMA_STAGE39_LIVE_TEST_SEAM only. Preserve accepted contracts/
> test map; add exact tests for generation chain and abort propagation.

This part corrects design Part 31. Parts 29 through 31 remain binding where
this part does not replace their generation, abort, or compile-guard wording.

## Session identity

Apply accepts one strict, bounded `run_id` and creates one unpredictable
`test_session_id` after snapshot, inventory, pair, formula, and idle checks pass.
Both become immutable when apply consumes the one-shot seam. The controller
stores them with the guarded expectation set. A second apply cannot reuse or
replace either value.

Every expectation, prepared-size record, frozen snapshot, HMAC, guarded error,
and retrieval request binds both IDs plus the process identity digest. Neither
ID is an admin credential or snapshot token. Logs and public metrics omit both.
Responses return them only on the authenticated loopback route so the driver
can reject mixed artifacts.

## Generation chain

One generation value across apply and both demotions is invalid. The session
instead owns this ordered chain under `cache_state_mutex_`:

1. `discovery_generation` is the generation authenticated by the discovery
   token. Apply must revalidate it before consumption.
2. Apply performs its allowed budget and hot-order writes. After their normal
   generation advances, it stores `post_setup_generation`, sets
   `expected_step = 1`, and sets `expected_generation` to that value.
3. Exact preparation must observe `expected_step == 1` and
   `cache_generation_ == expected_generation`. Its record stores
   `observed_generation = expected_generation` and step 1.
4. Ordinary exact demotion commits. On return from `tx_demote_payload()`, before
   checkpoint processing, the guarded chain advances to `expected_step = 2`
   and stores the then-current cache generation as step 2's
   `expected_generation`. This value must be greater than step 1's observed
   generation.
5. Checkpoint preparation must observe that exact step and generation. Its
   record stores its own `observed_generation` and step 2. The two-record size
   snapshot is complete but not terminal yet.
6. Ordinary checkpoint capacity handling records the expected
   `evicted/both_filled` decision, tombstones and unlinks the checkpoint, and
   completes accounting. Only then does the controller store
   `final_generation`, require it to be at least the step 2 generation, and
   freeze the terminal HMAC snapshot.

Each record also retains the accepted Part 31 role, request, owner, payload,
kind, pair, component-size, checksum, and runtime-pair bindings. Exact order is
`1, 2`; gaps, duplicates, reversal, or a generation different from that step's
expected value are terminal errors. Production generation remains the sole
mutation counter. The proof state does not invent a second cache generation.

Retrieval requires the same process, `test_session_id`, and `run_id`; exact
steps 1 and 2; each record's expected and observed generation to match; strict
monotonic order; and current `cache_generation_ == final_generation`. The
expected checkpoint mutation is therefore accepted. Any later mutation,
including changed-then-restored state, makes retrieval stale. Retrieval never
updates the chain or consumes the snapshot.

## Minimal abort plumbing

Current signatures remain unchanged: `tx_demote_payload()` returns `bool`,
`mark_payload_kind_evicted()` returns `bool`, and `mark_payload_evicted()` plus
`tx_update()` return `void`. A guarded controller member carries one terminal
prepared-proof abort status. It exists only under
`LLAMA_STAGE39_LIVE_TEST_SEAM` and contains fixed error and mismatch codes,
failed step, both session IDs, and the generation observed at failure.

The propagation checks are mandatory:

1. After `cold_store.prepare()` succeeds, capture validates the binding and
   formula before cold-budget admission or victim enumeration. On failure,
   `tx_demote_payload()` removes that staging file through its existing cleanup
   owner, latches the terminal error, and returns `false`.
2. `mark_payload_kind_evicted()` checks the latch immediately after the false
   demotion result, before reading `last_demote_failure_was_capacity_`, emitting
   a two-layer decision, changing residency, erasing hot bytes, clearing an
   owner link, refreshing accounting, or touching the forest. It returns
   `false` without ordinary classification.
3. `mark_payload_evicted()` checks the latch after each kind. An exact-step
   abort stops checkpoint processing. A checkpoint-step abort returns without
   further marking or sync work.
4. `evict_entry_by_id()` checks the latch after `mark_payload_evicted()` and
   returns `false` before eviction counters, LRU removal, entry removal, or
   retained/demoted classification. `evict_until_within_budget()` stops its
   plan on that false result.
5. `update()` checks the latch immediately after
   `evict_until_within_budget()` and returns before cold cleanup, metadata
   pruning, token pressure, or pressure diagnostics. `tx_update()` leaves the
   latch intact. The guarded caller maps it to a terminal failed response.

This latch is not a production reason, metric, or exception. Non-seam callers
retain current behavior. No generic demotion failure becomes a proof abort.

## Failure state and rollback

Step 1 failure leaves both payloads hot. Step 2 failure keeps the already
committed exact demotion cold and leaves checkpoint hot and linked. The seam
does not compensate or roll back that production commit. For either step, the
rejected prepared object has no manifest, quarantine entry, final cold file,
decision, cold transaction, tombstone, unlink, or admission accounting.

Staging-file cleanup failure adds a fixed cleanup mismatch flag but cannot
clear the terminal abort or resume pressure. A pre-pressure apply validation
failure remains retryable and non-consuming. Any capture or formula failure
occurs after `pressure_started` and is terminal `FAIL`, not `BLOCKED`. The
session cannot retry, resume at step 2, or serve a successful proof snapshot.

## Compile boundary

Prepared-proof state, parser fields, capture, retrieval, route handling, and
abort plumbing compile only with `LLAMA_STAGE39_LIVE_TEST_SEAM`. The existing
CMake option remains OFF by default. Runtime opt-in, loopback, dispatch-idle
latch, admin token, strict schemas, and process-local HMAC checks remain
mandatory. `LLAMA_SERVER_CACHE_TESTS` may guard subordinate fault injection;
it must not expose the live prepared-proof route or controller state.

## Required evidence

Part 43's accepted prepared-proof and natural-transition tests remain binding.
Add these exact controller cases:

- `test_stage39_live_pressure_prepared_proof_generation_chain`
- `test_stage39_live_pressure_prepared_proof_abort_step1_propagation`
- `test_stage39_live_pressure_prepared_proof_abort_step2_propagation`

Add these exact route cases:

- `test_live_pressure_prepared_proof_generation_chain_and_session`
- `test_live_pressure_prepared_proof_terminal_abort_response`

Generation-chain tests assert both IDs, discovery and post-setup generations,
per-step expected and observed generations, exact step order, terminal
generation, accepted expected checkpoint mutation, and stale rejection after a
later mutation. Abort tests assert staging cleanup, stopped kind order, no
ordinary result or transaction for the rejected object, no unlink or admission,
the step-specific retained state above, and terminal request failure.

## Gate

Implementation Part 72 carries this plan. Part 34 records historical REWORK for
terminal finalization, pressure return, and exact-kind synchronization order.
Design Part 35 and implementation Part 73 supersede that ordering under
D39-EXEC-12. Fresh independent Architect review is next. Code, tests, builds,
model execution, coverage, QA, commit, and push remain blocked.
