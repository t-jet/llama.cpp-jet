# Part 43: Stage 39 two-layer payload retention

Status: D39-QA-01 FULL CLEAN-BUILD EXECUTION AUTHORIZED
Stage: 39
Scope: hybrid payload retention until both enabled layers are filled

## Authority and gate

Read design Parts 1-3, 11, 15, and 17; implementation Parts 20-22, 39, 45-47;
and this plan together.
Manager implementation gate Part 22 is PASS. Design Part 14 passes independent
Architect review of the D39-EXEC-01 correction. Architect evidence review Part
138 is PASS. Manager Part 139 authorizes fresh full execution under D39-QA-01.
Prior QA and Manager test-plan gates stay historically valid.

Parts 33 and 35 plus implementation Parts 72 and 73 remain binding; Parts 34, 36, and 38 are historical REWORK.
Design Parts 39-40, implementation Part 75, and Manager Part 76 are historical.
Parts 41 and 78 are corrected by design Part 43 and implementation Part 79 under
D39-EXEC-17. Part 42 remains historical REWORK; design Part 44 records PASS.

Stage 39 changes payload residency and eviction. Payload pressure must not remove
lookup entries, branch nodes, or protected topology. A cold I/O, integrity,
transaction, or arithmetic failure is not evidence that cold capacity is filled.

## Session rules

1. Create a fresh `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`.
2. Record pre-edit dirty state, commit identity, tool versions, fixture paths,
   GPU/backend, server arguments, and all exclusions.
3. Remove `build`, configure Release, build `llama-server` and all focused cache
   targets, then prove binary timestamps are younger than ten minutes.
4. Prove runtime completeness, normal demotion, and reconciled sizes; use Parts 25 and 27's formulas.
5. Put Markdown only in `.test_reports`. Put logs, metrics, JSON, file inventories,
   coverage, and cold roots in `._test_output/<report-id>/`.
6. Record each row as `PASS`, `FAIL`, `SKIP`, or `BLOCKED`. Missing fixture or
   fault seam is `BLOCKED`, never synthetic `PASS`.

Run focused cache tests and `ctest -R cache` from the clean build. Run
`run_coverage.ps1` against changed hybrid-cache files. Changed-line focused
coverage must be at least 80%; lower or unavailable coverage blocks closure.

## Required evidence

Each applicable row needs before/after snapshots of both Stage 39 metric families,
hot bytes, descriptor-owned cold bytes, quarantine bytes, cold file count,
payload eviction totals, entry count, branch count, and pruning totals. Preserve
matching fixed-field log rows, requests, responses, command lines, and cold-root
inventories. Decision rows use only `mode="hybrid"`. TP-39-11 requires zero delta.

For every capacity eviction, show the positive hot budget, resident pair size,
exact immutable prepared-file size, cold budget, eligible-victim calculation, and
post-decision accounting. Aggregate eviction totals alone are insufficient.

Suggested per-row paths under `._test_output/<report-id>/TP-39-NN/`:

- `command.txt`, `requests.jsonl`, `responses.jsonl`, `server.log`
- `metrics-before.txt`, `metrics-after.txt`, `metric-delta.txt`
- `cold-files-before.csv`, `cold-files-after.csv`, `state.json`
- `focused-test.log`, `restart.log`, or `coverage-report.md` when applicable

## Test matrix

| ID | Tier | Procedure and acceptance |
| --- | --- | --- |
| TP-39-01 | Live | Fill hot while cold has room. Require `retained_cold`, successful cold restore, no payload eviction, no entry/branch/pruning delta, and reconciled bytes. |
| TP-39-02 | Focused + live | Use equal-rank cold victims with payload-ID tie-break. Require deterministic multi-victim room-making, committed incoming object, victim tombstones, and `retained_cold/cold_room_made`. |
| TP-39-03 | Focused + live | Focused evidence keeps guarded complete-set owner reassignment. Live evidence uses one same-owner hot exact/checkpoint entry: normal exact-first demotion fills cold, then checkpoint pressure sees no eligible victim because owner exclusion removes the cold exact sibling. Require one `evicted/both_filled`, bounded accounting, retained metadata, and proof both layers lacked room. |
| TP-39-04 | Focused + live | Admit and measure the pair while both positive startup budgets exceed it, then lower both below its measured resident and immutable serialized sizes. Require `evicted/oversized_both`, no partial pair, and bounded gauges. A pair that exceeds cold only must not use this reason. This replaces only the older Part 3 setup wording; result and acceptance stay unchanged. |
| TP-39-05 | Live negative | With cold absent or budget zero, require `bypassed/cold_disabled` before hot-only eviction. With `--cache-ram 0`, require prompt cache disabled and both Stage 39 families absent even when cold is configured. |
| TP-39-06 | Fault | Inject stage-write, stage-validate, and cleanup failures. Require byte-identical hot restore, rollback/error reason distinct from capacity, and no topology loss. |
| TP-39-07 | Focused fault | Exercise target-plus-draft pairs through commit, restore, rollback, and eviction. Require pair-atomic residency, files, descriptors, and accounting. |
| TP-39-08 | Focused | Place exact blob and checkpoint on one entry. Pressure each independently; require ranking by descriptor, retained entry/branch owners, and zero pruning delta. |
| TP-39-09 | Focused | Pressure protected root with live descendant. Require protection ordering, ownership-safe cold cleanup, valid descendants, and no entry removal. |
| TP-39-10 | Focused concurrency | Run concurrent slot transactions. Require deterministic totals, no partial visibility, no deadlock, and one decision row per hot-pressure candidate. |
| TP-39-11 | Live regression | Run equivalent legacy workload. Require unchanged responses/cache behavior and zero delta or absent Stage 39 families. |
| TP-39-12 | Live | Drive real `tx_save` pressure with measured budgets. Require demotion before eviction and production log/metric tuples; debug injection alone cannot pass. |
| TP-39-13 | Focused | Use prepared file exact-fit, one-byte-over, format-overhead, and checked-add overflow cases. Exact-fit commits; one-byte-over is capacity exhausted; overflow retains hot with `retained_hot/size_overflow`. |
| TP-39-14 | Fault + restart | Fail after staging, every victim rename position, incoming rename, final validation, apply, commit marker, and every unlink. Crash before and after marker. Restart must produce exact pre-state or committed state, remain idempotent, and expose no partial object. |
| TP-39-15 | Focused + live | Exercise all accepted enum tuples and invalid cast. Scrape only fixed labels; invalid input adds no series; decision family has at most 32 series and transaction family at most 27. IDs and paths must not appear in labels. |

## Automation map

`stage39-two-layer-pressure.ps1` supplies model-backed scaffolding for standard,
oversized-both, cold-disabled, and hot-zero pressure. It captures requests,
responses, metrics, logs, command arguments, and cold inventory. QA must choose
budgets from measured sizes and inspect exact deltas; script completion alone does
not pass TP-39-01, TP-39-03, TP-39-04, TP-39-05, TP-39-12, or TP-39-15.

After design Part 15 and implementation Parts 45-46 pass Manager gate, the same
driver uses the guarded route for TP-39-02 through TP-39-04. Each row admits
model-backed pairs through normal completions, waits for idle admission, sends
strict `{"operation":"discover"}`, and preserves its request and response. It
chooses a discovered incoming row and that row's complete cold set, derives
measured budgets and ranks, then sends `apply` with unchanged
`snapshot_generation`, `snapshot_token`, incoming identity, expected current
orders and ranks, exact `hot_candidates`, and exact per-incoming `cold_sets`.

Discovery and apply take the completion-admission latch before
`cache_state_mutex_`. Discovery calls only pure hot and cold enumeration cores.
It returns positive budgets, complete hot candidates, and one complete cold set
keyed by `incoming_payload_id` and `incoming_owner_entry_id` for every hot
candidate. Cold selection is exactly `residency == cold` plus
`owner_entry_id != incoming_owner_entry_id`, ordered by
`(last_validated_sequence, payload_id)`. Payload IDs are unique within each
exact set. One owner may own one exact blob and one checkpoint. There is no
global cross-array owner-uniqueness rule. Missing or extra exact or checkpoint
rows fail validation.

Descriptor integrity is checked after selection. Wrong kind or pair state,
identity mismatch, zero or dangling owner, wrong kind-specific owner link,
store mismatch, or cold-byte mismatch returns `inventory_integrity_error`.
That error and all schema, guard, idle, snapshot, and pre-consumption validation
errors are retryable and non-consuming. They leave metrics, decision counters,
LRU and ranks, descriptors, budgets, files, topology, generation, and one-shot
state unchanged.

Stable discovery returns stable `snapshot_generation` and HMAC-SHA-256
`snapshot_token`. The token binds a process-local 256-bit nonce, generation,
canonical inventories, and budgets. Apply recomputes it under lock, compares in
constant time, and rejects stale generation, changed-then-restored state,
slot-reference drift, budget drift, another-process token, or wrong HMAC before
consumption. Neither nonce nor token may enter logs, metrics, terminal errors,
or an apply response.

After exact revalidation, apply creates immutable `test_session_id` and `run_id` bindings. After exact-kind production return,
midpoint proof validates only the prepared record, descriptor/store/file facts, cold accounting, hot checkpoint, and entry accounting.
Branch aggregate is excluded until both kind calls finish. Step 2 binds to current generation without an advance. A step-2 fault
returns before checkpoint classification or unlink, but common entry/branch cleanup still reconciles committed exact state.
Final post-`tx_update()` proof validates branches and authenticates actual ordered production generation observations.

- TP-39-02 admits two smaller victims before a larger incoming pair. Positive
  startup hot budget is below their aggregate but above the incoming pair;
  cold budget holds all objects. Normal `tx_save()` pressure demotes both
  victims and leaves incoming hot. Discovery must show both victims in the
  incoming row's complete cold set, including exact and checkpoint descriptors
  when production selects both, while the incoming pair remains hot. Apply
  assigns equal victim ranks and lowers budgets. Its one normal
  `tx_update()` pressures incoming; production cold room-making must select both
  victims by payload-ID tie-break. Require `cold_room_made` plus exact tombstone,
  file, and accounting proof.
- TP-39-03 follows design Part 29. Focused tests retain Part 19's complete-set
  owner reassignment, collision, rollback, and selector proof. Live canonical
  uses `tp39_03_setup:"same_owner_kind_sequence"`; owner moves are forbidden.
  Baseline has one owner with hot exact plus hot checkpoint and empty cold.
  Apply changes only positive budgets and hot order, then one normal
  `tx_update()` demotes exact first. Checkpoint pressure must exclude that cold
  exact sibling by owner and emit exactly one `evicted/both_filled` with no
  failed-checkpoint cold transaction. Require exact retained cold, checkpoint
  eviction, retained entry/branch, zero pruning, and full byte/file proof.
  Production-boundary proof binds both prepared sizes to process, session,
  role, request, pressure step, kind, owner, payload, and that step's generation.
  Canonical formulas use its terminal HMAC snapshot; measurement is launch
  calibration only. Each
  pass keeps the 20-minute, 16-GiB RSS, 4-GiB cold-root, and six-chat caps.
- TP-39-04 admits first, then lowers both positive budgets below measured
  resident and serialized pair sizes, and requires exactly one
  `evicted/oversized_both` with no partial pair.

Compile-out under `LLAMA_STAGE39_LIVE_TEST_SEAM`, route absence, runtime OFF,
startup guards, loopback, admin token, strict schema, snapshot security,
validation retry, idle race, terminal failure, and successful normal
`tx_update()` evidence are mandatory. Pre-consumption rejection cannot mutate
state. Prepared-proof abort must clean staging and stop admission, ordinary
classification, unlink, later-kind work, and post-loop pressure diagnostics. A
step 2 abort retains coherent exact-cold/checkpoint-hot entry and branch state
without rollback. Coverage denominator, probes, and 80 percent threshold stay fixed.

Focused `test-cache-controller` evidence may cover internal state for TP-39-02,
TP-39-06 through TP-39-10, and TP-39-13 through TP-39-15. Map every plan assertion
to a named test and assertion; one binary PASS does not pass unmapped rows.
TP-39-14 also requires restart artifacts for every mutation position.

Focused row map after Developer correction:

| Row | Named executable evidence |
| --- | --- |
| TP-39-02 | `test_stage39_multi_victim_fault_position_matrix` covers atomic multi-victim room-making and replay. QA still combines it with the live equal-rank tuple and cold inventories. |
| TP-39-07 | `test_stage39_tp_07_target_draft_full_lifecycle` drives one target/draft pair through failed demotion rollback, committed cold demotion, promotion and byte restore, and atomic payload removal while retaining the lookup entry. |
| TP-39-08 | `test_stage39_tp_08_same_entry_independent_descriptor_pressure` places both descriptors on one entry, pressures each independently, verifies ranking and retained owner/topology state, and requires zero eviction and pruning delta. |
| TP-39-09 | `test_stage39_tp_09_protected_root_live_descendant_pressure` creates a protected root and live child in one forest, pressures the pair, restores the cold child, cleans up its payload, and verifies root ownership, two retained nodes, and zero pruning. |
| TP-39-10 | `test_stage39_tp_10_concurrent_cold_transactions_one_decision_each` admits four hot candidates, lowers the hot budget, and releases four threads into `tx_update`. The production pressure path reaches `mark_payload_kind_evicted`; assertions require four cold descriptors, exact cold bytes, zero hot bytes, retained entries, four demotion successes, and exactly four decisions across all result/reason tuples, all `retained_cold/cold_room`. |

These mappings identify assertion-level evidence. They do not turn a missing live
precondition into a pass.

### Guarded controller evidence

Run `test-cache-controller`. Each function must expose its own PASS line:

| Contract | Exact controller test |
| --- | --- |
| Pure hot enumeration and no metric delta | `test_stage39_live_pressure_hot_enumeration_pure` |
| Stable non-mutating, non-consuming discovery | `test_stage39_live_pressure_discover_non_mutating` |
| Mixed exact/checkpoint completeness and same-owner allowance | `test_stage39_live_pressure_mixed_kind_cold_exact_set` |
| Retryable descriptor-integrity failure | `test_stage39_live_pressure_inventory_integrity_retryable` |
| Atomic exact-set and current-fact revalidation | `test_stage39_live_pressure_apply_atomic_revalidation` |
| Stale generation and wrong HMAC | `test_stage39_live_pressure_snapshot_stale`, `test_stage39_live_pressure_snapshot_wrong_token` |
| Restored-state, slot-reference, and budget drift | `test_stage39_live_pressure_snapshot_changed_restored`, `test_stage39_live_pressure_snapshot_slot_ref_drift`, `test_stage39_live_pressure_snapshot_budget_drift` |
| All mutation-family generation ownership | `test_stage39_live_pressure_generation_mutation_matrix` |
| Explicit before/after generation and snapshots | `test_stage39_live_pressure_before_after_generation` |
| Idle admission race | `test_stage39_live_pressure_idle_dispatch_race` |
| Terminal setup and post-transaction failure | `test_stage39_live_pressure_terminal_after_mutation_failure` |
| Successful normal pressure transaction | `test_stage39_live_pressure_normal_tx_update_success` |
| Prepared fields, HMAC, and read-only purity | `test_stage39_live_pressure_prepared_proof_fields_and_purity` |
| Malformed, duplicate, reordered, missing, and overflow fail closed | `test_stage39_live_pressure_prepared_proof_malformed_fail_closed` |
| Stale generation, run, and process rejection | `test_stage39_live_pressure_prepared_proof_stale_generation` |
| Role, owner, kind, pair, request, step, component, and size mismatch | `test_stage39_live_pressure_prepared_proof_binding_mismatch` |
| Midpoint scope, real generation order, common cleanup, post-update freeze, and abort return | `test_stage39_live_pressure_prepared_proof_midpoint_excludes_branch_aggregate`, `test_stage39_live_pressure_prepared_proof_real_generation_sequence`, `test_stage39_live_pressure_prepared_proof_both_kind_success_coherence`, `test_stage39_live_pressure_prepared_proof_midpoint_fault_common_epilogue`, `test_stage39_live_pressure_prepared_proof_step2_fault_common_epilogue`, `test_stage39_live_pressure_prepared_proof_abort_step1_propagation` |
| Real exact-first preparation, same-owner exclusion, and one final result | `test_stage39_live_pressure_tp39_03_same_owner_exact_first_transition` |

Purity and discovery tests snapshot metrics, decision counters, LRU and ranks,
descriptors, budgets, files, topology, generation, and one-shot state before and
after repeated success and retryable failure. A binary PASS without these named
cases is insufficient.

### Guarded route evidence

Run `python -m pytest -q tools/server/tests/unit/test_stage39_live_pressure.py`.
The two fault nodes use only design Part 45's isolated Part 62 MTP source fixture; their gate requires exact capability preflight, fixed caps, and `2 passed` with no skip. Required exact tests are:

- `test_live_pressure_route_absent_when_compiled_off`
- `test_live_pressure_rejects_runtime_off_and_startup_guards`
- `test_live_pressure_rejects_non_loopback_and_wrong_admin_token`
- `test_live_pressure_rejects_strict_schema_errors`
- `test_live_pressure_discover_non_consuming`
- `test_live_pressure_discover_integrity_error_retryable`
- `test_live_pressure_apply_rejects_stale_generation`
- `test_live_pressure_apply_rejects_wrong_snapshot_token`
- `test_live_pressure_apply_rejects_omitted_or_extra_checkpoint`
- `test_live_pressure_snapshot_token_process_binding_and_redaction`
- `test_live_pressure_idle_dispatch_race`
- `test_live_pressure_terminal_after_mutation_failure`
- `test_live_pressure_success_returns_before_after_state`
- `test_live_pressure_prepared_proof_fields_and_redaction`
- `test_live_pressure_prepared_proof_rejects_malformed_schema`
- `test_live_pressure_prepared_proof_rejects_stale_or_wrong_process`
- `test_live_pressure_prepared_proof_rejects_binding_mismatch`
- `test_live_pressure_prepared_proof_real_generation_sequence`
- `test_live_pressure_prepared_proof_midpoint_fault_coherent_terminal`, `test_live_pressure_prepared_proof_step2_fault_coherent_terminal`
- `test_live_pressure_prepared_proof_terminal_abort_response`
- `test_live_pressure_tp39_03_same_owner_request_contract`

Process binding starts two servers and proves a token from one fails on the
other without token echo. Guard tests cover explicit runtime OFF, loopback,
single-model hybrid mode, positive startup budgets, admin token, and strict
tagged schemas.

### Live TP-39-02 through TP-39-04 evidence

TP-39-02 maps to `test_stage39_live_pressure_tp39_02_multi_victim` and
`Assert-Tp3902`; TP-39-03 maps to
`test_stage39_live_pressure_tp39_03_both_filled` and `Assert-Tp3903`; TP-39-04
maps to `test_stage39_live_pressure_tp39_04_oversized_both` and
`Assert-Tp3904`. Each assertion consumes saved discover/apply requests and
responses; proves before/after generation and recomputed inventories; and
checks exact decision and transaction metric deltas, fixed-field production log
tuples, resident/cold/quarantine/file accounting, retained entry and branch
counts, zero pruning, and the row-specific tombstone or no-partial-pair result.
A driver exit without these named assertions does not pass a row.

For TP-39-03, focused controller and route evidence also covers strict tag isolation,
complete nonempty set validation, exact/checkpoint link collision, duplicate
kind, active-reference and forest-link rejection, successful compatible owner
reassignment, failure after every setup write, exact reverse rollback,
generation advance, terminal one-shot behavior, and response/log leak scans.
Compatibility negatives cover namespace, target/draft pair shape, descriptor
and cold-object checksums/sizes, token and position spans, metadata preparation
identity, boundary metadata, and workload profile. Every rejection is before
consumption and leaves generation and all cache state unchanged.
Live evidence instead proves the natural same-owner sequence in design Part 29.
The seam may change only budgets and hot order before one normal `tx_update()`;
a seam-produced residency, decision, demotion, or eviction cannot pass.

Canonical coverage uses the literal fixture and exact four command blocks in
implementation Part 39: success and forced merge failure under `pwsh.exe`
(PowerShell 7), then under `powershell.exe` (Windows PowerShell 5). Each run has
a distinct fresh output directory. Real OpenCppCoverage success must exit 0,
write `coverage-merged.xml` and `coverage-report.md`, and meet 80 percent.
Disposable `OpenCppCoverage-force-merge-fail.cmd` must delegate capture calls,
return 23 on `--input_coverage`, and be preserved verbatim. Each forced run must
exit 1, retain capture `.cov` files, emit
`OpenCppCoverage merge failed with exit code 23`, and write neither
`coverage-merged.xml` nor `coverage-report.md`. Preserve commands, logs, exits,
fixture, and all four output trees. Phase order, denominator, captures, server
probe, and `whoami.exe` tail remain binding.

## Classification and closure

- `FAIL`: observed behavior violates invariant, reason taxonomy, accounting,
  topology, transaction recovery, or cardinality contract.
- `BLOCKED`: required fixture, seam, clean build, restart proof, or 80% coverage
  evidence is unavailable.
- `SKIP`: row is explicitly outside selected session scope, with reason recorded.
- `PASS`: all row-specific evidence exists and reconciles.

Stage 39 closes only when TP-39-01 through TP-39-15 pass, I-39-01 through
I-39-08 are traced to those results, changed-line coverage is at least 80%, all
capacity evictions prove both enabled layers lacked room, non-capacity failures
retain hot data, payload pressure produces zero pruning/entry removal, and bytes
reconcile with resident buffers plus final and quarantined files.
