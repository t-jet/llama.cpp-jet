# Part 25: TP-39-03 measured startup-budget correction

Date: 2026-07-13
Status: SUPERSEDED IN PART BY D39-EXEC-09 DESIGN PART 29
Scope: TP-39-03 measurement and canonical startup budgets only

## Manager decision

D39-EXEC-07 is binding:

> Measurement validates token coexistence, complete pair serialized/resident sizes, RSS, real checkpoint capability only; does NOT require cold_set. Canonical fresh startup hot budget derived to fit one measured complete pair with safety margin but be < sum of two, so admitting incoming demotes source to cold; cold startup retains it. Canonical preflight must then prove compatible cold checkpoint set before apply.

Part 67 retained two hot exact owners at 172,761,412 and 171,777,772 resident
bytes. Runtime created real 50.251 MiB checkpoints, peak RSS was 5,397,516,288
bytes, and the 2048 MiB hot budget caused no demotion. The cold root stayed
empty. Part 26 accepts capability but rejects complete-pair and serialized-size
provenance. D39-EXEC-08 and Part 27 supply the correction.

## Exact integer MiB formulas

Let `U = 1,048,576` bytes and `M = U`. Use checked unsigned arithmetic.
Measurement records source and incoming complete target/draft pair sizes. A
`target_only` row qualifies only after same-process proof that
`runtime_has_draft=false` and
`runtime_pair_matches(target_only,false)=true`:

- `R_s`, `R_i`: resident bytes;
- `S_s`, `S_i`: immutable serialized cold-object bytes.

The 50.251 MiB checkpoint-state log proves checkpoint capability. It is not
`S_s` or `S_i`. Each serialized input must come from that role's normal
production demotion into the fresh measurement cold root and must reconcile its
final `.cold` file, immutable header, descriptor serialized bytes, byte map,
and filesystem length. Missing, zero, partial, copied, estimated, log-state, or
cross-process sizes fail closed.

Derive canonical startup budgets only from measurement:

```text
H_mib = ceil(max(R_s, R_i) / U) + 1
H     = H_mib * U
C_mib = ceil(max(S_s, S_i) / U) + 1
C     = C_mib * U
```

The added integer MiB is the fixed safety margin. Before launch require:

```text
H >= max(R_s, R_i) + M
H <  R_s + R_i
C >= max(S_s, S_i) + M
C <  S_s + S_i
```

Overflow or failure yields `SKIP-preflight-startup-budget-inequalities`; do not
launch canonical. Part 67 illustrates the hot result: `H_mib = 166`,
`H = 174,063,616`, and `174,063,616 < 344,539,184`. D39-EXEC-08 uses 166 MiB as
measurement bootstrap only after runtime pair proof. Canonical recalculates
from the approved reconciled measurement artifact.

## Pass order and preflight

Measurement uses a fresh process and root, 166 MiB hot bootstrap, 2048 MiB
roomy cold budget, and Part 62's literal source, incoming, source filler, and
incoming filler order. It sends no apply or owner reassignment. Normal
production pressure must demote every role whose serialized size feeds the
formulas. It proves 3,631 plus 3,632 token coexistence, runtime pair
classification, resident components, immutable file/header/descriptor sizes,
file reconciliation, RSS under 16 GiB, cold-root bytes under 4 GiB, and real
MTP checkpoint creation. Empty `cold_sets` remains valid, but absence of normal
demotion and final cold files is not.

Canonical starts a different process and empty cold root with measured `H_mib`
and `C_mib`. Send the same literal source request, wait for idle save, then send
the same literal incoming request and wait again. Discover before any filler or
apply. Discovery must prove normal admission demoted the source, incoming exact
pair remains hot, and the source provides exactly one Part 19-compatible cold
checkpoint set. Reject a cold exact sibling, second checkpoint, link collision,
size drift, identity drift, or any compatibility failure.

Canonical must repeat the runtime pair proof and reconcile the normal source
demotion's file, header, descriptor, and accounting before guarded apply. Only
then derive existing lowered apply budgets from that canonical snapshot.
Keep the four apply inequalities: lowered hot fits incoming resident bytes but
is below aggregate hot bytes; lowered cold fits incoming serialized bytes but
is below checked occupied-cold plus incoming serialized bytes. Apply uses the
same generation, token, identities, inventory, and sizes. Any mismatch fails
before seam consumption.

Context 8192, one slot, batch/ubatch 512, checkpoint max 32, spacing 0,
20-minute pass cap, 16 GiB RSS cap, 4 GiB cold-root cap, and six-chat cap remain.
Security, rollback, selector, reason taxonomy, metrics, and public behavior do
not change.

Design Part 27 and implementation Part 69 carry D39-EXEC-08. Fresh independent
Architect review is next. No code, tests, model run, coverage, commit, or push
is authorized.
