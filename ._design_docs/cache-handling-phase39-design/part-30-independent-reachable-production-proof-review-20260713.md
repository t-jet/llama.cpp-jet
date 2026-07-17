# Part 30: independent reachable production proof review

Date: 2026-07-13
Verdict: REWORK
Scope: design Part 29, implementation Part 70, test-plan Part 43, entry
documents, index, and current production pressure code

## Decision

The natural same-owner transition is reachable and is the smallest live change
that still proves TP-39-03. The proof contract cannot yet supply all canonical
size inputs under its own process and generation rules. New proof tests also
lack the exact evidence map required by the active test plan. Manager acceptance
and implementation remain blocked.

## Review checks

| Check | Result | Basis |
| --- | --- | --- |
| Old precursor impossibility | PASS | `mark_payload_evicted()` processes exact before checkpoint; cold enumeration excludes the incoming owner; owner reassignment rejects occupied destination kind links. Budget and rank changes cannot remove those constraints. |
| Smallest contract change | PASS | Only the model-backed fixture changes. Focused owner-reassignment, collision, rollback, security, and selector coverage stays required. Production policy is unchanged. |
| Natural transition | PASS | One selected entry is processed exact then checkpoint. Exact can commit cold; checkpoint then sees its cold exact sibling excluded by owner and can return `evicted/both_filled`. |
| Production ownership | PASS | Guarded apply changes budgets and hot order, then calls ordinary `tx_update()`. Baseline and post-setup diffs forbid seam-authored payload, file, accounting, metric, or decision changes. |
| Proof surface | PASS WITH BLOCKER | Default-OFF, loopback/auth/admission guards, cache locking, fixed fields, fail-closed reconciliation, redaction, and purity are specified. Canonical serialized provenance is not executable. |
| Size bindings | FAIL | Canonical starts in a fresh process with cold empty, while the contract rejects cross-process `S_exact` and `S_checkpoint`. Neither Part 29 nor Part 70 obtains both immutable serialized values in that canonical process before apply. |
| Evidence map and coverage | FAIL | Required proof cases are listed by behavior only. Part 43 requires named tests and assertion mapping, but adds no controller or route names for the proof operation or natural same-owner transition. The 80 percent changed-line threshold remains valid but cannot identify the new required evidence. |

## Blocking findings

### F39-RPR-01: canonical serialized provenance is self-contradictory

Measurement produces real `.cold` objects in one process. Canonical starts with
an empty cold root in another process, requires both descriptors hot, and then
applies the lowered budgets. The proof response can report immutable serialized
bytes only for cold rows. Therefore canonical has no same-process,
same-generation `S_exact` or `S_checkpoint` before apply, even though Part 29
rejects cross-process formula values.

Correct the contract to distinguish calibration from final proof. Keep measured
values as launch calibration only. Define an executable canonical path that
binds the exact prepared size used by each ordinary production demotion to the
canonical process, owner, payload kind, generation, and pressure step. The
post-state may reconcile the committed exact file. The failed checkpoint must
expose its immutable prepared size through a bounded production-owned artifact
before cleanup, or another reviewed read-only record captured during the normal
transaction. It must not come from guarded setup, estimation, copied files, or
another process. Recheck the cold inequality against those canonical values and
fail the row on size drift.

### F39-RPR-02: proof and transition tests have no exact map

Part 29 lists proof failures, and Part 70 says to add focused tests. Test-plan
Part 43 still names only the older discovery, apply, and owner-reassignment
cases. It does not name tests for proof accuracy and purity, component overflow,
header/store/byte-map/file mismatch, stale process or generation, redaction, or
the natural same-owner exact-before-checkpoint transition.

Add exact controller and route test names and map each required assertion.
State which named case proves the ordinary `tx_update()` order, same-owner
candidate exclusion, one `evicted/both_filled`, no failed-checkpoint cold
transaction, retained topology, and baseline/post-setup purity. Keep canonical
coverage at 80 percent or higher over the changed hybrid-cache files; enum or
schema injection alone is not production transition coverage.

## Handoff

Developer owns documentation correction for F39-RPR-01 and F39-RPR-02. Design
Part 31 and implementation Part 71 are the D39-EXEC-10 correction candidates.
Return them, the test plan, entries, and index for fresh independent Architect
review. No implementation or execution is authorized.
