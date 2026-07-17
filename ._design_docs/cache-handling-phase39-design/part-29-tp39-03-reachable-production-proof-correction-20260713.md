# Part 29: TP-39-03 reachable production proof correction

Date: 2026-07-13
Status: REVIEWED REWORK IN PART 30
Scope: D39-EXEC-09 proof surface and TP-39-03 live reachability only

## Manager decision

D39-EXEC-09 is binding:

> authorize minimal default-OFF guarded read-only proof surface for same-process runtime_pair_matches and locked descriptor/header/file-byte reconciliation. Every R/S value must bind workload role, payload kind, owner, generation, exact request/pressure step. Measurement serialized sizes still from normal production demotion, not guarded ownership mutation. Canonical may use guarded apply only to establish a fully observed precursor; one subsequent normal production transition must cause the decisive TP39-03 outcome. Baseline + post-state must prove seam did not manufacture asserted retention. First prove a reachable precursor/action/post-state against actual eviction order and owner exclusion; if impossible, propose smallest valid test contract change without code.

This correction closes F39-CPR-01 and F39-CPR-02 at design level. The current
live owner-reassignment precursor is impossible, so this part also proposes the
smallest test-contract change for F39-CPR-03. No production policy changes.

## Reachability finding

Current production pressure calls `mark_payload_kind_evicted()` for
`exact_blob` before `checkpoint`. Cold victim enumeration excludes every
descriptor whose owner equals the incoming descriptor owner. The guarded owner
move also rejects a destination kind link that is already occupied.

The existing live contract needs one cold source checkpoint, no cold exact
sibling, and one hot incoming exact descriptor whose checkpoint link is empty.
The fixed long MTP incoming request creates its own checkpoint. Normal pressure
cannot remove only that checkpoint: when the entry is selected, exact pressure
runs first. Guarded reassignment cannot move the source checkpoint into the
occupied incoming checkpoint link. Changing budgets, LRU order, or cold rank
does not change either invariant. The precursor is therefore unreachable under
the current schema.

## Smallest valid TP-39-03 contract change

Keep the focused owner-reassignment matrix as evidence that the guarded move is
atomic, collision-safe, and that production owner exclusion returns an empty
candidate set. Change only the model-backed TP-39-03 setup to a natural
same-owner, two-kind transition:

1. Canonical admission creates one MTP entry with a hot exact descriptor and a
   hot checkpoint descriptor under the same owner. Cold starts empty.
2. Guarded discover and the read-only proof response record that exact baseline.
3. Guarded apply may lower positive budgets and set hot order. It performs no
   owner move, descriptor-link write, residency change, file write, decision,
   demotion, or eviction.
4. Apply invokes one ordinary `tx_update()`. Production selects that entry,
   processes exact first, and demotes exact normally into cold.
5. Production then processes the same owner's checkpoint. Cold capacity fits
   either the exact object or checkpoint object, but not both. The cold exact
   descriptor is excluded because it has the checkpoint's owner. No eligible
   victim remains, so the checkpoint produces exactly one
   `evicted/both_filled` final decision.

This is the same owner-exclusion rule TP-39-03 is meant to prove. It removes
only the impossible live fixture transformation. Focused coverage retains the
complete-set reassignment contract and its rollback/security assertions.

## Reachable precursor and budgets

Measurement still uses normal production demotion only. It must obtain exact
resident and serialized values for both payload kinds of the selected role:

- `R_exact`, `S_exact`: exact descriptor resident bytes and immutable cold file
  bytes from its normal demotion;
- `R_checkpoint`, `S_checkpoint`: checkpoint descriptor resident bytes and
  immutable cold file bytes from its normal demotion.

Canonical startup budgets must admit both descriptors without pressure. The
guarded apply lowers them to positive values satisfying checked integer rules:

```text
R_exact <= H_low < R_exact + R_checkpoint
max(S_exact, S_checkpoint) <= C_low < S_exact + S_checkpoint
```

Before apply, both descriptors are hot, linked to the same owner, cold is empty,
and no decision or transaction delta exists. Hot ordering names that owner.
Cold ranks are empty. The request declares
`tp39_03_setup:"same_owner_kind_sequence"`; owner-reassignment fields are
forbidden in this live mode.

The exact-first transition leaves the exact descriptor cold. The checkpoint
transition sees occupied cold bytes `S_exact`, prepared bytes `S_checkpoint`,
and no candidate after owner exclusion. The post-state must show exact retained
cold, checkpoint tombstoned or unlinked per existing eviction behavior, one
`evicted/both_filled`, zero cold-transaction delta for the failed checkpoint,
retained entry and branch, zero pruning, and reconciled bytes/files. A different
pressure order, extra candidate, extra decision, or seam-authored residency
change fails the row.

## Guarded read-only proof surface

Extend guarded discovery with a `proof` operation or equivalent response built
under the admission latch and `cache_state_mutex_`. Compile it out by default;
require runtime opt-in, loopback, admin token, one-slot idle state, hybrid mode,
positive startup budgets, strict schema, and the existing HMAC process binding.
The operation is non-consuming and may not advance generation, mutate cache or
filesystem state, increment counters, validate by promotion, or call a
production transition.

Each requested payload row returns only bounded technical fields:

- process-local runtime identity digest, generation, payload ID, owner ID,
  payload kind, residency, pair state, and kind-specific owner link;
- `runtime_has_draft`, `runtime_pair_matches`, target/draft resident component
  sizes and checksums, checked resident total, and descriptor store ID;
- for cold rows, immutable header identity and fields, checked serialized file
  bytes, descriptor target/draft sizes and checksums, cold-byte-map value, and
  filesystem length read while the lock remains held.

The response reports fixed mismatch flags, not paths or content. It must not
return the cold root, final path, snapshot/admin token, nonce, prompt, tokens,
payload bytes, preparation secret, or HMAC input. Missing file/header,
overflow, changed generation, link drift, descriptor/header mismatch, byte-map
drift, or file-length drift fails closed.

The driver writes one evidence record for every formula value. Each record
binds pass ID, process identity, workload role, literal request number, pressure
step, payload kind, payload/owner IDs, generation, resident components, runtime
predicates, immutable serialized bytes, and the matching normal demotion tuple.
Cross-process, cross-generation, cross-kind, copied, estimated, or unbound
values are invalid.

## Required verification

Focused controller and route tests must prove proof-field accuracy, purity,
compile/runtime guards, process and generation binding, target-only matcher
success, draft mismatch, missing component, overflow, missing file/header,
descriptor/header/store/byte-map/file mismatch, strict schema, and redaction.

Live evidence must prove measurement demotions were normal production actions.
Canonical evidence must preserve pre-apply baseline, apply response, production
logs/metrics, and post-state reconciliation. Diff the baseline against the
post-setup snapshot before `tx_update()`; only budgets, hot order, generation,
and terminal one-shot state may differ. Diff the post-setup snapshot against the
final state to attribute exact demotion and checkpoint eviction to production.

## Gate

Implementation Part 70 carries the original plan. Review Part 30 returns REWORK
for canonical serialized provenance and exact named-test mapping. Design Part
31 and implementation Part 71 apply D39-EXEC-10. Fresh review must pass before
Manager accepts the live contract or opens implementation and execution.
