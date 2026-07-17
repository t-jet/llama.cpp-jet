VERDICT: REWORK

# Part 28: independent complete-pair size provenance review

Date: 2026-07-13
Scope: D39-EXEC-08 design Part 27, implementation Part 69, aligned Parts 19,
25, 43, 60, 62, 68, entry documents, test plan, index, and code feasibility

## Decision

D39-EXEC-08 closes the earlier target-only classification rule and correctly
forbids guarded ownership apply during measurement. The corrected plan still
cannot produce its required canonical state. It also lacks an executable source
for two proof fields. Manager gate is not ready.

## Checks

| Check | Result | Evidence |
| --- | --- | --- |
| Target-only rule | PASS WITH BLOCKER | Part 27 requires same-process `runtime_has_draft=false` and `runtime_pair_matches(target_only,false)=true`, but Part 69 does not define how the driver obtains either value. |
| Measurement isolation | PASS | Fresh process/root, 166/2048 MiB bootstrap, no guarded apply or owner reassignment, and cleanup are explicit. |
| Serialized provenance | PASS WITH BLOCKER | Normal production demotion, final `.cold` file, header, descriptor byte value, byte map, filesystem length, and aggregate reconciliation are required. The driver has no reviewed descriptor/header proof surface. |
| Canonical formula arithmetic | PASS AS MATH | The ceil-plus-one formulas and four inequalities are sound only when each input is the same storage unit used by canonical pressure. |
| Canonical reachability | FAIL | Current production pressure handles an entry's exact blob before its checkpoint. The proposed hot budget sizes one exact descriptor, not one entry's exact-plus-checkpoint resident set. |
| Fail-closed isolation | PASS | Missing proof, drift, extra files, overflow, or reconciliation failure stops before apply and canonical cannot reuse measurement state. |

## Blocking findings

### F39-CPR-01: runtime and descriptor proof has no executable surface

The guarded discovery row currently exposes `pair_state`, `resident_bytes`, and
`serialized_cold_bytes`. It does not expose `runtime_has_draft`, the result of
`runtime_pair_matches`, descriptor target/draft components, immutable header
fields, or store identity. `stage39_build_snapshot_locked()` constructs that
limited row in `tools/server/server-cache-hybrid.cpp`; the runtime pair check
exists only later inside TP-39-03 apply.

Part 69 says the driver records and tests these fields, but it does not add a
guarded measurement response, a read-only artifact, or another exact mechanism.
Logs and inferred `pair_state` cannot prove the two D39-EXEC-08 predicates.
Filesystem parsing can verify a header, but cannot by itself bind the header to
the controller descriptor and byte map in the same locked generation.

Correction must define one default-OFF, read-only proof surface. It must bind
runtime identity, generation, payload and owner IDs, kind, pair state,
target/draft resident components, matcher result, descriptor sizes and
checksums, store ID, byte-map value, and immutable header identity. Keep paths,
tokens, payload bytes, nonce, and authorization data redacted. Add focused route
and controller tests for field accuracy, purity, missing components, mismatch,
overflow, and cross-process or stale evidence.

### F39-CPR-02: formula inputs do not name the pressured storage unit

Parts 25 and 27 call `R_s`, `R_i`, `S_s`, and `S_i` complete target/draft pair
sizes, but do not bind them to one payload kind. Part 67's resident inputs are
hot `exact_blob` descriptors. The desired canonical cold candidate is a
`checkpoint`, while the incoming object later prepared by `tx_update()` is the
incoming owner's exact blob. A normally demoted checkpoint size cannot stand in
for that exact blob's serialized size.

Correction must name the payload kind and workload role for every formula
input. Startup and lowered-apply inequalities must use the exact descriptor
that production will prepare at each pressure step. If entry-level pressure
depends on both exact and checkpoint residents, the hot preflight must also
account for their checked aggregate rather than treating the discovery exact
row as the whole entry.

### F39-CPR-03: source-then-incoming canonical state is unreachable

Each measured owner has a hot exact blob and a real checkpoint. Part 67 reports
429.079 MiB total payload for the two entries, while the two cited exact rows
alone total about 328.6 MiB. A 166 MiB hot limit therefore does not fit one
complete entry.

Current `mark_payload_evicted()` calls `mark_payload_kind_evicted()` for
`exact_blob` before `checkpoint`. With a cold budget derived to fit one exact
object but not two, normal source pressure demotes the source exact blob first.
The following source checkpoint cannot evict that same-owner cold exact blob,
because the cold selector excludes the incoming descriptor owner. The result is
a cold exact sibling or an evicted checkpoint, not exactly one cold checkpoint.
Incoming pressure repeats the same order and cannot leave the required hot
incoming exact owner with an empty checkpoint link. This contradicts Parts 25,
27, 62, and 68, which require source then incoming followed immediately by
discovery with one cold checkpoint and no cold exact sibling.

Correction must provide a reviewed, executable production-only request and
budget sequence that reaches all three facts together: one compatible source
checkpoint cold, no source exact cold sibling, and incoming exact hot with an
empty checkpoint link. It may use bounded exact repeats if normal promotion and
pressure can prove that state, but measurement/canonical roles and all formula
units must be recalculated around the actual transition sequence. Guarded apply
or owner reassignment cannot manufacture preflight state. If no such sequence
exists, Manager must change TP-39-03 fixture/setup authority rather than rerun
the current plan.

## Required rework

1. Correct Parts 19, 25, 27, 60, 62, 68, 69, and test-plan Part 43 for
   F39-CPR-01 through F39-CPR-03.
2. Add an explicit proof interface plan and focused evidence map.
3. Bind every resident and serialized input to workload role, descriptor kind,
   target/draft components, and the exact production pressure step consuming it.
4. Prove the revised canonical state transition against current exact-before-
   checkpoint pressure and incoming-owner exclusion before another model run.
5. Return corrected documents for fresh independent Architect re-review.

## Handoff

Verdict is REWORK. Developer owns documentation correction only. Code, tests,
builds, model execution, coverage, commit, and push remain blocked pending fresh
review PASS and a later Manager gate.
