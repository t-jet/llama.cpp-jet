# Part 1: implementation plan

Date: 2026-07-12
Status: CORRECTED FOR ARCHITECT RE-REVIEW

## Scope and authority

Implement I-39-01 through I-39-08 and TP-39-01 through TP-39-15 from the
Manager-approved design. Work is hybrid-only. It does not change branch
pruning, entry lifetime, restore ranking, CLI or endpoint fields, cold payload
format, or `--cache-ram 0`. All mutations stay synchronous under
`cache_state_mutex_`. Changed hybrid-cache lines require 80% focused coverage.

## C++ contracts and placement

All signatures below are binding implementation names.

| File | API and owner |
| --- | --- |
| `server-cache-store-cold.h` | `cold_prepare_result prepare(uint64_t, const vector<uint8_t> &, const vector<uint8_t> &, const cold_descriptor_snapshot &);` |
| same | `cold_validate_result validate_prepared(const prepared_cold_object &) const;` |
| same | `cold_store_recovery_result recover_transactions();` |
| same | `bool quarantine(const cold_victim &, const cold_tx_id &);`, `bool publish(prepared_cold_object &, const cold_tx_id &);`, `bool write_manifest(const cold_tx_manifest &);`, `bool mark_committed(cold_tx_manifest &);`, `cold_cleanup_result cleanup(cold_tx_manifest &);` |
| `server-cache-io-worker.h` | Replace demotion `execute_demotion_inline(...)` with `cold_prepare_result prepare_demotion_inline(uint64_t, const cold_descriptor_snapshot &, const vector<uint8_t> &, const vector<uint8_t> &);`; promotion API stays unchanged. |
| `server-cache-hybrid.h` | Replace `cold_budget_make_room(size_t, const payload_descriptor &)` with `cold_admission_plan plan_cold_admission(const prepared_cold_object &, const payload_descriptor &) const;`. |
| same | Add `cold_tx_result commit_cold_admission(prepared_cold_object &&, cold_admission_plan &&, payload_descriptor &, hot_payload_record &);`. |
| same | Add controller-owned `cold_recovery_apply_result reconstruct_committed_transaction(const cold_recovered_commit &);` and `bool finish_recovered_cleanup(const cold_recovered_commit &);`. |
| same | Keep public `bool tx_demote_payload(uint64_t);`; it calls prepare, plan, and commit in that order. Keep `bool tx_save(server_slot &, const prepared_prompt_metadata &);`; its existing pressure path reaches `mark_payload_evicted`, which must call `tx_demote_payload` before capacity eviction. |

`server_cache_store_cold::write` is removed after callers move to `prepare` and
transaction methods. Existing `read`, `remove`, and `delete_ids` stay for
promotion and non-transactional ownership cleanup. Recovery uses fixed records:

```cpp
struct cold_recovered_owner {
    uint64_t entry_id;
    uint8_t owner_link; // payload_id or checkpoint_payload_id
};
struct cold_recovered_descriptor {
    cold_descriptor_snapshot file;
    uint8_t payload_kind; // exact_blob or checkpoint_blob
    cold_recovered_owner owner;
    uint64_t created_sequence;
    uint64_t last_validated_sequence;
    int64_t token_span_start, token_span_end;
    int64_t position_start, position_end;
    bool checkpoint_boundary_required, checkpoint_boundary_native;
    int32_t checkpoint_boundary_kind;
    uint64_t boundary_checksum;
    std::string boundary_id, workload_profile;
};
struct cold_recovered_victim {
    cold_recovered_descriptor descriptor;
    uint64_t exact_bytes;
    std::filesystem::path quarantine_path;
    bool committed_tombstone;
};
struct cold_recovered_commit {
    cold_tx_id tx_id;
    cold_recovered_descriptor incoming_descriptor;
    uint64_t incoming_exact_bytes;
    std::filesystem::path incoming_final_path;
    uint64_t logical_bytes_before;
    uint64_t victim_bytes;
    uint64_t logical_bytes_after;
    std::vector<cold_recovered_victim> victims;
};
struct cold_store_recovery_result {
    std::vector<cold_recovered_commit> committed;
    cold_cleanup_result precommit_cleanup;
    bool mutation_disabled;
};
```

Every startup field comes from the manifest. It stores incoming descriptor and
owner images, victim tombstones with their old owner links, and the checked
equation `after = before - victim_bytes + incoming_exact_bytes`. Unknown enum
values are invalid.

The hybrid constructor calls `recover_transactions()` after `configure()`.
Under `cache_state_mutex_`, `reconstruct_committed_transaction()` validates the
equation, unique payload and entry/link keys, final and quarantine files,
descriptor sizes/checksums, and absence of conflicting live state. It installs
the incoming cold descriptor, per-ID bytes, and durable entry-ID/link ownership
row; installs victim tombstones; and sets total logical bytes to `after`.
Missing owners are reconstructed from recorded entry ID and link. An equal row
is `already_applied`. An unequal row, missing file, bad enum or equation, or
owner conflict is `unappliable`: preserve all files, disable cold mutation, and
skip ordinary reconciliation. Startup does not recreate tokens, branch nodes,
or lookup entries. A later live entry may attach only after its ID/link matches
the recovered ownership row exactly.

After all records are `applied` or `already_applied`, cleanup removes
quarantine and manifest files. Only then are worker wiring and orphan
reconciliation allowed. Claimed incoming paths and victim tombstone IDs are
excluded from that scan.

## Ordered transaction and recovery

Manifest states are `prepared`, `quarantined`, `published`, and `committed`.
Each transition writes a new manifest, fsyncs it, atomically replaces the old
manifest in the cold root, then fsyncs the directory. Prepared file data is
closed and fsynced before its exact length is read. Each rename is followed by
a directory fsync. Order under the controller lock:

1. Prepare and validate staging; write `prepared` manifest.
2. Rename each victim to quarantine; persist `quarantined` after each rename.
3. Rename staging to final, validate final and the complete descriptor/accounting
   apply plan, then persist `published`.
4. Persist `committed`. This is the transaction commit point.
5. Apply the prevalidated, non-fallible incoming/victim descriptor and logical
   accounting changes. Release hot bytes only after apply.
6. Unlink quarantine files, fsync the directory, then remove the manifest.

Runtime failure before step 4 reverses published incoming and victim renames;
descriptor, accounting, and hot residency remain at pre-state. Restart recovery
for `prepared`, `quarantined`, or `published` does the same and never deletes
the last hot or cold copy. Failure or crash after step 4 completes committed
descriptor/accounting state when the controller is live, never restores victim
pre-state, keeps incoming final, and retries cleanup. A crash between commit and
hot release may leave both copies; it cannot lose both. Startup recovery marks
committed incoming files as claimed so reconciliation does not delete them.

Failure injection follows staging fsync, each manifest replace, each victim
rename/fsync, incoming rename/fsync, final validation, commit replace/fsync,
descriptor apply, hot release, and each unlink/fsync. Each test asserts staging,
final, quarantine, descriptor, logical accounting, and hot-residency post-state,
then repeats recovery to prove idempotence.

Restart tests use a real temporary cold root. Pre-commit tests stop after each
prepared, quarantined, and published boundary, destroy controller A, construct
B, and prove incoming rollback, victim restoration, no recovered descriptor or
tombstone, original logical bytes, and idempotence. Post-commit tests commit an
incoming pair with exact/checkpoint owner-link variants and multiple victims,
destroy A before apply, construct B, and prove descriptor equality, entry-ID
ownership, victim tombstones, exact per-ID/total bytes, and cleanup. Controller
C then proves replay does not double-account.

## Capacity equations

Use checked `uint64_t` values: `C` is pre-transaction descriptor-owned final
bytes, `S` is exact closed incoming bytes, `V_k` is the sum of the first `k`
renamed victims, `V_n` is all selected victim bytes, and `B` is the cold budget.
Existing quarantine debt must be zero before prepare.

| State | Final `F` | Staging `T` | Quarantine `R` | Logical `L` | Physical `P` |
| --- | ---: | ---: | ---: | ---: | ---: |
| prepared | `C` | `S` | `0` | `C` | `C + S` |
| victim step `k`, `1 <= k < n` | `C - V_k` | `S` | `V_k` | `C` | `C + S` |
| all victims quarantined | `C - V_n` | `S` | `V_n` | `C` | `C + S` |
| published | `C - V_n + S` | `0` | `V_n` | `C` | `C + S` |
| committed and applied | `C - V_n + S` | `0` | `V_n` | `C - V_n + S` | `C + S` |
| cleaned | `C - V_n + S` | `0` | `0` | `C - V_n + S` | `C - V_n + S` |

Admission fits iff checked `C - V_n + S <= B`. Every pre-cleanup row derives
`P = C + S`; incoming bytes occur once, in staging before publish and in final
after publish. Since checked `C <= B`, `P = C + S <= B + S`. One locked
transaction permits one reserve `S`; no second reserve is allowed. After commit,
logical budget enforcement remains `L <= B`. Cleanup debt blocks new mutation.

Exact fit: `C=80,V_n=30,S=50,B=100` gives `L=100`, peak `P=130`, then `P=100`.
One byte over: `S=51` gives `L=101`, so no rename occurs. Partial multi-victim
progress at `V_k=10` gives `F=70,T=50,R=10,L=80,P=130`; at `V_n=30`, it gives
`F=50,T=50,R=30,L=80,P=130`. Checked-add overflow returns `size_overflow`,
removes staging, and retains hot. Cleanup failure leaves
`F=100,R=30,L=100,P=130`; restart idempotently applies `L=100`, removes `R`,
and returns `P=100`.

## Stats and exporter schema

`get_stats()` returns arrays:

```json
{"cache_two_layer_decisions":[{"mode":"hybrid","result":"retained_cold","reason":"cold_room","value":1}],"cache_cold_transactions":[{"mode":"hybrid","result":"commit","reason":"none","value":1}]}
```

Controller stores keys as typed enum tuples and rejects invalid casts before
increment. `server-context.cpp` iterates those exact fields and emits one
HELP/TYPE block per family. No empty fallback row is emitted. Closed ceilings
remain 32 decision and 27 transaction series. Logs use Part 3's fixed tuples.

## TP-39 evidence matrix

Focused tests and their captured log sink are in `tests/test-cache-controller.cpp`.
Live tests and `server.log` are in `tools/server/tests/unit/test_cache_modes.py`.
`D(r,x)` means metric tuple `mode=hybrid,result=r,reason=x` and decision log
fields `result=r reason=x`. `T(r,x)` means the corresponding transaction metric
tuple and log fields. Logs do not add a `mode` field.
Each subcase preserves its own `metrics-before.txt`, `metrics-after.txt`,
`server.log`, `inventory.json`, and `state.json` under
`._test_output/stage39/<subcase>`.

| Subcase | Production entry | Exact test | Exact tuple | Log source |
| --- | --- | --- | --- | --- |
| 01 | `tx_demote_payload` | `test_stage39_tp_01_hot_full_cold_room` | `D(retained_cold,cold_room)` and `T(commit,none)` | live `test_stage39_tp_01_live` |
| 02 | `plan_cold_admission` | `test_stage39_tp_02_multi_victim_room` | `D(retained_cold,cold_room_made)` and `T(commit,none)` | live `test_stage39_tp_02_live` |
| 03 | `mark_payload_evicted` | `test_stage39_tp_03_both_filled` | `D(evicted,both_filled)` | live `test_stage39_tp_03_live` |
| 04 | `mark_payload_evicted` | `test_stage39_tp_04_oversized_both` | `D(evicted,oversized_both)` | live `test_stage39_tp_04_live` |
| 05a | `mark_payload_evicted` | `test_stage39_tp_05_cold_disabled` | `D(bypassed,cold_disabled)` | live `test_stage39_tp_05_live_cold_disabled` |
| 05b | constructor hot-zero path | `test_stage39_tp_05_hot_zero` | both families zero delta | live `test_stage39_tp_05_live_hot_zero` |
| 06a | `prepare` write failure | `test_stage39_tp_06_stage_write` | `D(retained_hot,io_error)` and `T(rollback,stage_write)` | focused log sink |
| 06b | `validate_prepared` | `test_stage39_tp_06_stage_validate` | `D(retained_hot,integrity_error)` and `T(rollback,stage_validate)` | focused log sink |
| 06c | `quarantine` | `test_stage39_tp_06_victim_quarantine` | `D(retained_hot,io_error)` and `T(rollback,victim_quarantine)` | focused log sink |
| 06d | `publish` | `test_stage39_tp_06_incoming_publish` | `D(retained_hot,io_error)` and `T(rollback,incoming_publish)` | focused log sink |
| 06e | `mark_committed` | `test_stage39_tp_06_commit_marker` | `D(retained_hot,io_error)` and `T(rollback,commit_marker)` | focused log sink |
| 07a | `tx_demote_payload` pair success | `test_stage39_tp_07_pair_commit` | `D(retained_cold,cold_room)` and `T(commit,none)` | focused log sink |
| 07b | `tx_demote_payload` pair validation | `test_stage39_tp_07_pair_rollback` | `D(retained_hot,integrity_error)` and `T(rollback,stage_validate)` | focused log sink |
| 08a | exact payload demotion | `test_stage39_tp_08_exact_payload` | `D(retained_cold,cold_room)` and `T(commit,none)` | focused log sink |
| 08b | checkpoint demotion | `test_stage39_tp_08_checkpoint` | `D(retained_cold,cold_room)` and `T(commit,none)` | focused log sink |
| 09 | `plan_cold_admission` | `test_stage39_tp_09_protected_descendant` | `D(retained_cold,cold_room_made)` and `T(commit,none)` | focused log sink |
| 10 | `tx_demote_payload` | `test_stage39_tp_10_concurrent_slots` | `D(retained_cold,cold_room_made)` and `T(commit,none)` | focused log sink |
| 11 | legacy `tx_save` | `test_stage39_tp_11_legacy_unchanged` | both families zero delta | live `test_stage39_tp_11_live` |
| 12 | real `tx_save` | `test_stage39_tp_12_tx_save_pressure` | `D(retained_cold,cold_room_made)` and `T(commit,none)` | live `test_stage39_tp_12_live` |
| 13a | `prepare` and plan exact fit | `test_stage39_tp_13_exact_fit` | `D(retained_cold,cold_room)` and `T(commit,none)` | focused log sink |
| 13b | plan one byte over | `test_stage39_tp_13_one_byte_over` | `D(evicted,both_filled)` | focused log sink |
| 13c | checked prepare arithmetic | `test_stage39_tp_13_overflow` | `D(retained_hot,size_overflow)` | focused log sink |
| 14a | committed cleanup retry | `test_stage39_tp_14_cleanup_failure` | `T(commit,cleanup)` | focused log sink |
| 14b | corrupt recovery manifest | `test_stage39_tp_14_manifest_recovery` | `T(recovery,manifest)` | focused log sink |
| 14c | committed startup cleanup | `test_stage39_tp_14_cleanup_recovery` | `T(recovery,cleanup)` | focused log sink |
| 14d | committed controller apply | `test_stage39_tp_14_apply_recovery` | `T(recovery,apply)` | focused log sink |
| 14e | pre-commit new controller | `test_stage39_tp_14_precommit_new_controller` | `T(recovery,rollback)` | focused log sink |
| 14f | post-commit new controller | `test_stage39_tp_14_postcommit_new_controller` | `T(recovery,apply)` | focused log sink |
| 15a | `get_stats` and exporter | `test_stage39_tp_15_enum_cardinality` | `D(retained_cold,cold_room)` and `T(commit,none)` | live `test_stage39_tp_15_live` |
| 15b | invalid enum boundary | `test_stage39_tp_15_invalid_enum` | both families zero delta | focused invariant log sink |

All log rows spell the Part 3 schema and add only `payload_id` or `tx_id`.
TP-15 exercises every enum through the exact tuples already named in 01 through
14, then counts the families. Every `state.json` records hot, logical cold,
staging, quarantine, file, descriptor, lookup, and branch counts.

## Execution and closure

Implement contracts, store transaction, controller integration, observability,
then tests. Build `test-cache-controller` and `llama-server` serially; run the
focused binary, `ctest -R cache`, focused pytest with absolute server path,
focused coverage, and live pressure workload. Update implementation evidence
after each step. No migration is required. Rollback first runs recovery, proves
no valid active manifest or quarantine remains, then reverts code and metrics
together. Code remains blocked until Architect re-review and Manager plan gate.
