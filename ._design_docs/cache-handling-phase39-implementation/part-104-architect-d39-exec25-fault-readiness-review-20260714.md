# Part 104: Architect D39-EXEC-25 fault-readiness review

Date: 2026-07-14
Verdict: REWORK; DESIGN PART 52 REQUIRED
Scope: D39-EXEC-25 proof evidence and D39-EXEC-18 route readiness

## Proof-only verdict

D39-EXEC-25 passes its authorized gate. The sole node reports one PASS in
166.57 seconds. Source and incoming admissions returned HTTP 200. Nodes moved
from one to two, the source became the sole eligible hot exact row with zero
slot references, and its cold-set key copied payload 1 and owner 1.

Read-only proof returned hot `exact_blob` payload 1 and hot `checkpoint`
payload 2, both owned by entry 1 with distinct store IDs. Exact component bytes
are 172,761,412 target plus 15,072,840 draft, totaling 187,834,252. Checkpoint
component bytes are 52,691,548 plus 14,928,780, totaling 67,620,328. Runtime
draft and pair checks pass for both rows.

Discovery, proof, and post-incoming metrics were stable across repeated reads.
Decision and transaction totals stayed zero, cold storage stayed empty, and
`preflight-result.json` says PASS. Request hashes match Parts 50 and 51. The
manifest names all 20 required files, reports zero secret matches, and every
forbidden apply, prepared, terminal, final-metric, final-inventory, and fault
artifact is absent on disk.

## Apply reachability

The current helper now reaches exact natural apply inputs. It binds generation
36, the live snapshot and proof tokens, payloads 1 and 2, owner 1, ordered
exact/checkpoint bindings, pair state, component sizes, and checksums. Hot
budget is 187,834,252 bytes. Cold budget is 187,834,316 bytes: the 64-byte cold
header plus the larger resident pair. This fits the exact serialized object and
is smaller than the two-object sum. Production preparation rechecks actual
staging-file bytes before classification.

No product build is needed to establish this reachability. D39-EXEC-25 used
the existing guarded binary and changed only helper workload and assertions.

## Blocking fault-readiness finding

The route fault assertions remain narrower than design Part 43. They prove
failure, preparation flags, strict generation order, one cold commit, and a
nonempty forest. They do not prove exact-cold/checkpoint-hot terminal
descriptor state, entry/branch byte coherence, checkpoint staging cleanup,
decision deltas, absence of checkpoint classification or diagnostics, later
victim suppression, unchanged LRU and pruning state, or exactly one common
sync. Midpoint also omits an explicit `checkpoint_prepared == false` check.

Controller tests check more state, but still use aggregate topology and commit
counts instead of the complete forbidden-effect matrix. The terminal HMAC has
no state block from which the HTTP tests could make the missing assertions.
Running the model now would not satisfy D39-EXEC-18 even if both nodes passed.

Design Part 52 is the coupled correction. It adds guarded terminal state and
delta evidence to the existing HMAC and requires matching controller, pure
shape, and route assertions. It does not change the common epilogue, fixture,
budgets, public product behavior, or accepted proof-only evidence.

## Handoff

Next owner: Manager for one correction gate under Part 52. That gate needs one
fresh seam-enabled controller/server build because guarded C++ proof fields
change; it needs no default product build. After focused tests, fresh Architect
review must verify the terminal proof and both fault assertions before two
fresh sequential fault nodes. No route rerun, model calibration, canonical
TP-39-03, coverage, full QA, commit, or push is authorized now.
