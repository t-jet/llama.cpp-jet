# Part 69: TP-39-03 complete-pair size provenance plan

Date: 2026-07-13
Status: SUPERSEDED IN PART BY D39-EXEC-09 IMPLEMENTATION PART 70
Authority: D39-EXEC-08 and design Part 27

## Correction

Correct TP-39-03 driver measurement and canonical preflight only.

1. Treat `target_only` as complete only when same-process evidence records
   `runtime_has_draft=false` and
   `runtime_pair_matches(target_only,false)=true`. Bind both facts to runtime,
   workload role, payload, owner, generation, and resident components.
2. Start measurement with hot 166 MiB, cold 2048 MiB, a fresh process, and an
   empty root. The hot value is bootstrap only. Reject it if Part 67's resident
   inputs do not pass the runtime and component proof.
3. Send source then incoming and wait for idle saves. Require normal production
   pressure to demote the source. Do not send guarded apply or owner
   reassignment. Use only the fixed repeats and six-chat cap if a second normal
   demotion is needed to obtain the incoming serialized size.
4. For each formula input, save exact resident components, final `.cold` file,
   immutable header, descriptor serialized bytes, cold-byte-map value, final
   file length, cold totals, quarantine totals, and staging inventory. Reject
   missing, partial, estimated, copied, or cross-process values.
5. Require descriptor, header, byte-map, and filesystem size agreement. Reconcile
   descriptor-owned cold bytes with final and quarantined files after idle.
   Preserve evidence, remove the measurement root, and retain no authorization
   state.
6. Compute `H_mib` and `C_mib` only after `R_s`, `R_i`, `S_s`, and `S_i` pass
   Part 27. Use the existing checked ceil-plus-one formulas and all four
   fit-one/not-two inequalities.
7. Launch canonical in a new process and empty root. Recreate source then
   incoming through normal production admission. Discover before fillers or
   guarded apply.
8. Fail with `SKIP-preflight-complete-pair-size-provenance` unless canonical
   proves runtime classification, normal source demotion, immutable file/header
   identity, descriptor size, incoming hot residency, measured-size stability,
   compatible checkpoint inventory, and exact file/accounting reconciliation.

## Evidence and tests for later implementation

Driver self-tests must reject a missing runtime predicate, `runtime_has_draft`
true, pair mismatch, missing draft component, overflow, null serialized bytes,
header or descriptor drift, partial/staging files, extra final files, copied
sizes, and accounting mismatch. Positive fixtures must prove target-only
completion with zero draft bytes and exact descriptor/header/file agreement.

Model-backed evidence must show a production demotion log and transaction tuple,
not a seam-produced move. It must show no guarded apply request in measurement.
Canonical evidence comes from a new process/root and must include both startup
formula inputs, four inequalities, discovery, file inventory, and reconciliation.

## Gate

Design review Part 28 records historical REWORK. Design Part 29 and
implementation Part 70 replace the missing proof surface and unreachable live
precursor. Code, tests, execution, coverage, commit, and push remain blocked.
