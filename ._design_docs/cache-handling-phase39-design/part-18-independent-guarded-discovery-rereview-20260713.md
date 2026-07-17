VERDICT: PASS

# Part 18: independent guarded discovery re-review

Date: 2026-07-13
Scope: corrected test-plan Part 43 and implementation Part 47 against design
Part 17 finding F39-GDR-RR-01 and authoritative Parts 15, 45, and 46

## Gate result

F39-GDR-RR-01 is closed. Test-plan Part 43 now uses the corrected guarded
discovery contract and gives QA one contract consistent with design Part 15 and
implementation Parts 45-46.

This is a documentation gate. Planned code and tests remain unimplemented and
unexecuted. Manager may decide the correction-plan gate; Developer code work
and QA remain blocked until that decision.

## Contract verification

| Check | Result | Evidence |
| --- | --- | --- |
| Discover, snapshot, and apply | PASS | Part 43 requires strict `discover`, stable `snapshot_generation` and `snapshot_token`, then exact snapshot-bound `apply`. It preserves the discover and apply requests and responses. |
| Pure inventory | PASS | Discovery, apply validation, and before/after snapshots call pure hot and cold enumeration cores. Repeated success and retryable failure must leave metrics, decision counters, LRU/ranks, descriptors, budgets, files, topology, generation, and one-shot state unchanged. |
| Per-incoming cold sets | PASS | Part 43 returns one complete set for every incoming hot candidate. Selection is exactly cold residency plus `owner_entry_id != incoming_owner_entry_id`, ordered by `(last_validated_sequence, payload_id)`. |
| Mixed-kind ownership | PASS | Exact-blob and checkpoint descriptors may share one owner. Payload IDs remain unique inside each exact set; no global owner-uniqueness rule remains. Missing or extra rows fail validation. |
| Integrity separation | PASS | Kind, pair state, identity, live owner, kind-specific link, store identity, and cold-byte checks run after enumeration. `inventory_integrity_error` is retryable and non-consuming, so integrity does not narrow production policy. |
| Snapshot security | PASS | Token input, process nonce, HMAC-SHA-256, constant-time comparison, process binding, stale generation, changed-then-restored state, slot-reference drift, budget drift, wrong token, and redaction are explicit. |
| Generation ownership | PASS | Part 43 carries the complete mutation-family owner from Parts 15 and 46, including entries, descriptors, residency, rank, forest, slot references, completion, save/restore, recovery, cleanup, budget, control, and rollback. |
| Before and after evidence | PASS | Terminal responses use explicit `before_generation` and `after_generation` with recomputed hot and per-incoming cold snapshots. The singular `generation` field is prohibited. |

## Named evidence verification

Part 43 binds exact controller tests to:

- pure hot enumeration and non-mutating discovery;
- mixed-kind completeness and retryable integrity failure;
- atomic apply validation, stale generation, wrong HMAC, restored-state,
  slot-reference, and budget drift;
- the full generation mutation matrix and explicit before/after state;
- idle admission, terminal failure, and successful normal `tx_update()`.

It also names route tests for compile/runtime guards, startup guards, loopback,
admin authentication, strict schemas, non-consuming discovery, retryable
integrity failure, stale generation, wrong token, omitted or extra checkpoint,
process binding, redaction, idle race, terminal failure, and successful
before/after response.

TP-39-02, TP-39-03, and TP-39-04 each have a named live test and PowerShell
assertion. Their acceptance requires saved discover/apply artifacts, generation
and inventory proof, production metric and fixed-log tuples, byte and file
accounting, retained topology, zero pruning, and the row-specific transaction
outcome. Driver exit alone cannot pass a row.

## Retained gates

Part 43 retains TP-39-01 through TP-39-15, the live model-backed tiers, fixed
coverage phases and denominator, canonical server probe, PowerShell 5 and 7
success and forced-failure probes, and the 80 percent changed-line threshold.
Security, privacy, public metrics, reason taxonomy, thresholds, normal
production behavior, and normal transaction ownership remain unchanged.

## Handoff

PASS. F39-GDR-RR-01 is closed with no open design finding. Manager correction
gate is ready. Code, script, test implementation, QA execution, and Stage 39
closure remain blocked pending that gate and later required reviews.
