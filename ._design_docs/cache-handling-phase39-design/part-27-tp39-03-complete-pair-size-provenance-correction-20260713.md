# Part 27: TP-39-03 complete-pair size provenance correction

Date: 2026-07-13
Status: SUPERSEDED IN PART BY D39-EXEC-09 DESIGN PART 29
Scope: D39-EXEC-08 measurement provenance and canonical budget inputs only

## Manager decision

D39-EXEC-08 is binding:

> `target_only` counts complete only after proof `runtime_has_draft=false` and `runtime_pair_matches(target_only,false)`. Measurement uses 166MiB hot bootstrap only to drive normal production demotion of one measured pair into roomy cold, producing real .cold/header and descriptor serialized bytes; no guarded ownership apply. Verify exact resident complete pair + immutable serialized size + file reconciliation. Then compute canonical H/C formulas from verified complete inputs, fresh process/root; fail closed if no demotion/files/runtime proof.

This corrects F39-MBR-01 and F39-MBR-02 from Part 26. It does not change
production selection, pair semantics, cold format, or public behavior.

## Complete-pair classification

A measured row with `pair_state:"target_only"` is a complete runtime pair only
when the same fresh-process evidence proves both of these facts:

- `runtime_has_draft == false`;
- `runtime_pair_matches("target_only", false) == true`.

The proof must bind the runtime identity, payload ID, owner ID, discovery
generation, and resident-byte row. A missing field, a true draft capability, a
pair mismatch, or evidence from another process rejects the row. The complete
resident size is then the exact target resident bytes plus zero draft bytes.
No checkpoint-state log size participates in this classification.

Part 67's 172,761,412-byte source row and 171,777,772-byte incoming row remain
candidate resident inputs. The 166 MiB result may be used only after the new
measurement records the two runtime predicates above for those exact workload
roles and reconciles their resident components.

## Measurement pass

Start a fresh process and empty cold root. Use a 166 MiB hot startup budget and
a 2048 MiB cold startup budget. The 166 MiB value is a bootstrap chosen from
Part 67's candidate resident values. It is not a canonical result and cannot be
reused if complete-pair classification or resident reconciliation changes.

Send the literal source and incoming requests from Part 62, waiting for idle
save after each. Hot pressure must call the normal production save and demotion
path and move the source pair into cold storage. Guarded owner reassignment and
guarded `apply` are forbidden in this pass. Discovery may observe state but may
not create, rank, move, publish, or evict a payload.

For every `S_s` or `S_i` later used by the formulas, that workload role must
have its own normal production demotion evidence. If source then incoming
produces only `S_s`, use only the fixed exact-repeat requests already allowed by
Part 62 to rotate the incoming pair through normal pressure. Stay within the
six-chat cap. Failure to obtain both immutable serialized sizes stops the pass;
one measured cold object cannot be copied or assumed equal to the other.

Each accepted pair record contains:

- workload role, payload ID, owner ID, kind, pair state, runtime predicates,
  target resident bytes, draft resident bytes, and checked resident total;
- final `.cold` path relative to the fresh root, immutable header identity,
  header target/draft fields, store ID, descriptor serialized-byte value, and
  exact filesystem length;
- cold-byte-map contribution, total descriptor-owned cold bytes, final cold
  file count and bytes, quarantine bytes, and absence of staging or temporary
  files after idle completion.

The descriptor serialized-byte value, immutable header length, cold-byte-map
value, and final file length must agree under the existing cold-format contract.
Aggregate cold accounting must equal accepted final files plus quarantine. Any
partial file, stale file, second unexplained object, header mismatch, descriptor
drift, or accounting difference fails closed. Cleanup removes the measurement
root after evidence preservation; its identities never authorize canonical
apply.

## Canonical derivation and isolation

Only verified records may supply `R_s`, `R_i`, `S_s`, and `S_i`. Use Part 25's
checked formulas unchanged:

```text
H_mib = ceil(max(R_s, R_i) / 1,048,576) + 1
C_mib = ceil(max(S_s, S_i) / 1,048,576) + 1
```

Recheck all four fit-one/not-two inequalities before launch. Start canonical in
a different process and empty cold root. Recreate source then incoming through
normal production admission. Do not reuse measurement generation, token,
payload IDs, owner IDs, files, inventories, or authorization state.

Canonical preflight must prove the runtime predicates again, source demotion,
required final cold file and header, descriptor serialized bytes, incoming hot
residency, compatible checkpoint set, and full byte/file reconciliation. It
must also prove the measured values still match. Missing demotion, missing or
extra files, runtime mismatch, size drift, overflow, or reconciliation failure
returns `SKIP-preflight-complete-pair-size-provenance` before guarded apply or
one-shot consumption.

## Gate

Review Part 28 records historical REWORK. Design Part 29 and implementation
Part 70 replace its missing proof surface and unreachable live precursor. No
code, tests, model run, coverage, commit, or push is authorized.
