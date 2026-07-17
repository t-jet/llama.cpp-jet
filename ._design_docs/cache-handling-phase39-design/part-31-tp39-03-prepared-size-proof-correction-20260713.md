# Part 31: TP-39-03 prepared-size proof correction

Date: 2026-07-13
Status: REVIEWED REWORK IN PART 32; CORRECTED BY PART 33
Scope: F39-RPR-01 and F39-RPR-02 only

## Manager decision

D39-EXEC-10 is binding:

> canonical cold-empty process may expose minimal default-OFF guarded read-only production-owned prepared serialized byte counts captured at the real serialization preparation boundary before admission/demotion. Bind each S_exact/S_checkpoint to runtime pair, workload role, owner, kind, generation, request/pressure step; immutable snapshot used by preflight formulas. No guarded ownership mutation may create decisive result. Keep accepted natural same-owner exact-first transition from Part29/30.

This correction keeps Part 29's accepted live transition. It adds no production
cache policy, public route, file-format, metric, or reason change.

## Feasible production boundary

`server_cache_store_cold::prepare()` creates and validates a
`prepared_cold_object`. Its `exact_bytes` equals the closed staging-file length.
`hybrid_cache_controller::tx_demote_payload()` receives that object before cold
budget admission, victim selection, demotion commit, or capacity eviction. This
is the only allowed capture point.

The default build contains no record or route behavior. A build with
`LLAMA_SERVER_CACHE_TESTS`, explicit runtime opt-in, loopback authorization, and
the existing admin token may copy bounded proof fields from the validated
object into controller-owned test state. Capture cannot call preparation,
admission, demotion, eviction, accounting, metrics, or log helpers.

## Prepared-size record

Before canonical pressure, guarded apply installs one immutable expectation set
from its already validated discovery snapshot. It may identify proof bindings;
it may not change payload ownership, owner links, residency, or files. Each
expected record contains:

- canonical run ID, process identity digest, discovery generation, workload
  role, literal request number, and pressure-step ordinal;
- payload ID, owner entry ID, payload kind, pair state, target/draft component
  sizes and checksums, `runtime_has_draft`, and `runtime_pair_matches`;
- expected transition position: exact step 1, checkpoint step 2.

The real preparation boundary matches every field against the current
descriptor, owner link, hot record, runtime pair, and guarded expectation. It
then copies `prepared_cold_object.exact_bytes` and the validated staging-file
length. Records are append-only, one per expected kind. Duplicate, reordered,
unknown, missing, or changed fields fail closed. No path, bytes, prompt, token,
nonce, HMAC input, or credential enters the record or response.

Each accepted record advances the guarded proof generation, not the production
cache generation. The immutable proof snapshot contains both ordered records,
the production generations observed at each boundary, and an HMAC token over
all returned fields. Once complete or failed it cannot be changed or reused.
Read-only retrieval is non-consuming and returns only the bounded snapshot.

## Canonical preflight and transition

Measurement values remain launch calibration only. They choose positive
canonical `H_low` and `C_low`, but cannot pass TP-39-03.

Before `tx_update()`, apply checks the hot discovery snapshot and the resident
formula with checked integer arithmetic:

```text
R_exact <= H_low < R_exact + R_checkpoint
```

At exact preparation, production records `S_exact` and requires
`S_exact <= C_low` before exact admission. A mismatch removes the prepared file
through its normal cleanup owner and stops the guarded run before exact
admission. On success, ordinary production code demotes exact first.

At checkpoint preparation, production records `S_checkpoint`, freezes the
two-record snapshot, and checks:

```text
max(S_exact, S_checkpoint) <= C_low
C_low < S_exact + S_checkpoint
```

Overflow, drift, missing record, or inequality failure removes the checkpoint
prepared file and stops before checkpoint admission or capacity eviction. The
already committed exact demotion remains an ordinary production result and the
row fails. When checks pass, production continues unchanged: same-owner victim
exclusion removes the cold exact sibling, and checkpoint pressure emits the
single decisive `evicted/both_filled` result.

The final driver record must use this canonical immutable snapshot, not request
values, measurement values, a copied file, or a guarded estimate. It reconciles
the committed exact file with `S_exact`; the failed checkpoint has no final cold
file and uses the production-boundary `S_checkpoint` record.

## Fail-closed rules

Malformed schema, stale discovery or process identity, wrong HMAC, wrong role,
owner, kind, pair state, runtime match, generation, request, pressure step,
component size/checksum, duplicate record, or changed hot inventory rejects the
setup before pressure. A boundary mismatch rejects that prepared object before
its admission. All failures are terminal after setup consumption. They emit a
fixed error code and bounded mismatch flags without echoing secrets or paths.

Proof retrieval rejects incomplete, stale, wrong-process, or wrong-run
snapshots. It cannot mutate budgets, rank, descriptors, files, accounting,
metrics, topology, production generation, or one-shot state.

## Natural-transition proof

Part 29's baseline and result remain binding. Baseline has one owner with hot
exact and hot checkpoint, empty cold, no owner move, and no decision delta.
Guarded setup may change only positive budgets, hot order, proof expectations,
proof generation, and terminal one-shot state. One ordinary `tx_update()` must
produce exact-first demotion followed by checkpoint pressure.

Acceptance requires ordered prepared records, exact retained cold, checkpoint
evicted, one `evicted/both_filled`, no failed-checkpoint cold transaction,
retained entry and branch, zero pruning, and reconciled resident, cold,
quarantine, descriptor, and filesystem bytes. Any guarded ownership mutation,
seam-authored residency change, extra result, or missing proof record fails.

## Verification map

Test-plan Part 43 names controller, route, and live cases. The controller cases
exercise real `tx_update()` and the real preparation boundary. Route cases test
schema, authorization, snapshot retrieval, redaction, and fail-closed parsing;
route-only injection cannot prove the production transition. Changed-line
coverage remains at least 80 percent across changed hybrid-cache files.

## Gate

Implementation Part 71 carries the original plan. Part 32 closes F39-RPR-01
and F39-RPR-02 in principle, then returns REWORK for F39-PSR-01 through
F39-PSR-03. Design Part 33 and implementation Part 72 correct those findings
under D39-EXEC-11. Fresh review is next. Code, builds, model execution,
coverage, QA, commit, and push remain blocked.
