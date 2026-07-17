# Part 71: TP-39-03 prepared-size proof plan

Date: 2026-07-13
Status: REVIEWED REWORK IN DESIGN PART 32; CORRECTED BY PART 72
Authority: D39-EXEC-10 and design Part 31

## Planned interfaces

All new source is inside `LLAMA_SERVER_CACHE_TESTS` and remains runtime OFF by
default.

1. Add bounded prepared-proof expectation, record, and immutable snapshot types
   beside existing Stage 39 guarded control types. Use fixed workload roles,
   payload kinds, step ordinals, result codes, and mismatch flags.
2. Extend strict guarded apply parsing for
   `tp39_03_setup:"same_owner_kind_sequence"` with exactly two proof bindings:
   same owner, exact step 1, checkpoint step 2. Reject owner-reassignment fields,
   duplicate kinds, arbitrary strings, extras, and missing fields.
3. Install expectations only after current discovery, HMAC, inventory, owner
   link, runtime-pair, generation, positive-budget, and resident-formula checks.
   Consumption stays terminal before any setup mutation.
4. In `tx_demote_payload()`, immediately after successful validated
   `cold_store.prepare()` and before cold-budget admission, call one guarded
   capture helper. The helper compares current descriptor, hot record, runtime
   pair, generation, role, request, and step with the immutable expectation.
5. Copy `prepared_cold_object.exact_bytes` and staging-file length into the
   append-only record. Do not expose paths or content. Reject size disagreement,
   overflow, duplicates, reordering, drift, or mismatch before admitting that
   prepared object.
6. At exact step, require `S_exact <= C_low`. At checkpoint step, freeze the
   ordered two-record HMAC snapshot and check
   `max(S_exact,S_checkpoint) <= C_low < S_exact + S_checkpoint`. Use checked
   arithmetic. On failure, use normal prepared-file cleanup and return a fixed
   terminal guarded error before the affected admission or eviction.
7. Add strict non-consuming `prepared_proof` retrieval under admission then
   cache lock. Require run, process, generation, and HMAC binding. Return only
   proof fields, exact sizes, observed production generations, fixed status,
   and mismatch flags. Do not advance production generation or counters.
8. Keep Part 29's ordinary `tx_update()` flow. No helper may call demotion,
   victim selection, eviction, decision, transaction, metric, log, accounting,
   owner-link, or residency mutation.

## Driver work

Use measurement values only to choose launch budgets. Canonical apply binds
literal workload roles, request numbers, payload/owner identities, kinds,
runtime pair, discovery generation, and step ordinals. Preserve discovery,
apply, proof, metrics, logs, and file inventories.

`Assert-Tp3903` must recompute both formulas from canonical resident rows and
the immutable prepared-proof snapshot. Require exact-first boundary order,
`S_exact` reconciliation with the committed final cold file, no final checkpoint
file, one `evicted/both_filled`, zero failed-checkpoint cold transaction, no
owner mutation, retained topology, zero pruning, and exact byte accounting.
Missing or stale proof, calibration reuse, or size drift is `BLOCKED` before a
decision and `FAIL` after production pressure starts.

## Exact tests

Controller:

- `test_stage39_live_pressure_prepared_proof_fields_and_purity`
- `test_stage39_live_pressure_prepared_proof_malformed_fail_closed`
- `test_stage39_live_pressure_prepared_proof_stale_generation`
- `test_stage39_live_pressure_prepared_proof_binding_mismatch`
- `test_stage39_live_pressure_tp39_03_same_owner_exact_first_transition`

Route:

- `test_live_pressure_prepared_proof_fields_and_redaction`
- `test_live_pressure_prepared_proof_rejects_malformed_schema`
- `test_live_pressure_prepared_proof_rejects_stale_or_wrong_process`
- `test_live_pressure_prepared_proof_rejects_binding_mismatch`
- `test_live_pressure_tp39_03_same_owner_request_contract`

The test-plan assertion map is binding. Tests must cover exact fields and HMAC,
read-only purity, duplicate/reordered/missing records, incomplete retrieval,
stale generation/run/process, every role/owner/kind/pair/request/step mismatch,
component and size drift, overflow, cleanup, and redaction. The transition test
must enter ordinary `tx_update()` and prove exact-first order, same-owner cold
exclusion, one final decision, no checkpoint transaction commit, retained
topology, and baseline-to-setup purity.

## Evidence and gate

Run focused controller and route suites, PowerShell self-tests, one bounded MTP
canonical smoke, then the fixed four-shell coverage matrix at 80 percent or
higher. Preserve raw artifacts. An enum, schema, direct helper, or synthetic
record test does not replace real preparation-boundary and production-pressure
coverage.

Design Part 32 returns REWORK for proof-generation lifecycle, boundary-abort
propagation, and the default-OFF compile guard. Design Part 33 and implementation
Part 72 correct those findings under D39-EXEC-11. Fresh review is required. No
code, tests, builds, model execution, coverage, commit, or push is authorized.
