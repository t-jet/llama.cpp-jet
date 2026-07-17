# Part 15: guarded discovery correction

Date: 2026-07-13
Status: READY FOR FRESH INDEPENDENT ARCHITECT RE-REVIEW
Scope: narrow correction to Part 11; production cache policy is unchanged

## Manager intent

> discovery correction provisionally accepted for design review only; code changes blocked until Manager gate after independent PASS.

This correction closes the interface gap in implementation review Part 44. It
keeps one guarded route and splits its strict body into tagged `discover` and
`apply` operations. All compile, runtime, loopback, single-model, hybrid-mode,
metrics, positive-startup-budget, token, idle, redaction, and admission guards
from Part 11 remain binding.

## Pure hot inventory

Hot enumeration has a pure core and one production wrapper:

- `enumerate_hot_policy_candidates_core()` reads entries, the LRU index,
  descriptors, and forest state under `cache_state_mutex_`. It returns the
  production candidate rows plus a count of entries blocked by active slot
  references. It changes no metric or controller state.
- Production `build_policy_candidates()` calls the pure core, adds the returned
  blocked-reference count to `n_eviction_payload_blocked_refs`, and returns the
  candidates. This wrapper is the sole owner of that metric increment.
- Discovery, apply validation, and before/after snapshot building call only the
  pure core. They discard the diagnostic count and cannot change the metric.

The pure core keeps the current production hot predicate and order. The guarded
inventory maps every returned entry to its exact-blob descriptor and reports the
same owner, residency, protection, slot-reference, pair-state, byte, and order
facts. It does not add a second eligibility rule.

## Exact cold inventory and integrity seam

Cold enumeration matches the current production room-making loop exactly. For
an incoming descriptor, a descriptor is selected only when:

```text
descriptor.residency == cold &&
descriptor.owner_entry_id != incoming_descriptor.owner_entry_id
```

No payload kind, live-entry, owner-link, byte-map, or store-reference condition
is part of selection. Production room-making, discovery, apply validation, and
snapshot building use this same pure enumeration core and the existing
`(last_validated_sequence, payload_id)` order. A successful inventory includes
every descriptor selected by that predicate, including both `exact_blob` and
`checkpoint` descriptors. It rejects omitted and extra rows.

The guarded seam runs descriptor-integrity validation after enumeration, as a
separate step. It checks recognized kind and pair state, map-key/payload/store
identity, nonzero live owner, the kind-specific entry link (`payload_id` or
`checkpoint_payload_id`), and cold-byte accounting. Any dangling, mismatched,
or malformed descriptor returns `inventory_integrity_error`. The failure is
retryable and non-consuming and changes no generation, metric, rank, budget,
file, or cache state. Integrity validation does not remove a production
candidate and does not change production room-making policy.

Discovery reports one cold set for each discovered hot candidate. Each set is
keyed by `incoming_payload_id` and `incoming_owner_entry_id`, so production's
incoming-owner exclusion is explicit. Payload IDs are unique in each set. One
owner may own one exact blob and one checkpoint.

Each inventory row contains only payload ID, owner entry ID, payload kind, pair
state, residency, protected-root state, slot-reference count, resident bytes,
serialized cold bytes when known, current hot order, current cold rank, and
eligibility. Rows sort by payload ID. No path, store reference, token, prompt,
token sequence, model data, payload bytes, or payload-derived content is
returned.

## Generation owner

One controller field, `cache_generation_`, owns snapshot freshness for the
process lifetime. It starts at 1 and never resets. A checked increment under
`cache_state_mutex_` follows every logical mutation listed below. Wraparound
fails closed; generation 0 is never valid. A state change followed by rollback
therefore advances at least twice and cannot recreate an old token.

All mutation entry points must use centralized setters or call
`advance_cache_generation_locked()` in the same locked critical section:

| Mutation family | Required generation ownership |
| --- | --- |
| Entries and indexes | Entry add/remove/replacement, owner link, namespace, protection, pair/cache flags, insertion/use sequence, LRU or prefix membership, branch-node identity, and cached sizes advance generation. |
| Descriptors and payload records | Descriptor/hot-record add, replace, erase, identity, kind, owner, pair state, store identity, sizes, checksums, metadata, or byte-map change advances generation. |
| Residency and cold rank | Every hot/demoting/cold/promoting/evicted transition and every `last_validated_sequence` change advances generation. |
| Forest state | Node add/remove/prune, payload link, protection, resident bytes, order fields, and every slot-reference acquire or release advance generation. Slot-reference APIs take `cache_state_mutex_`; no direct forest ref mutation bypasses the controller. |
| Completion dispatch | Demotion/promotion dispatch advances through its transient-residency write. Completion success, failure, or stale cleanup advances for each resulting descriptor, record, byte, or residency mutation. |
| Save and restore | Admission, dedupe replacement, checkpoint attach, eviction, restore validation rank, entry recency, promotion, and slot-reference transfer use the same owner. Read-only misses do not advance. |
| Recovery and cleanup | Startup claim reconstruction, descriptor resurrection/tombstone, orphan cleanup, committed victim application, and cold-accounting repair advance under the controller lock. |
| Rollback | Every restored entry, descriptor, forest, record, rank, residency, byte-accounting, or budget value advances again. Rollback never rewinds generation. |
| Budgets and controls | Runtime hot/cold/metadata budget changes and guarded setup order/rank/budget writes advance. One-shot `ready` to `consumed` advances even if later work fails. Test/debug setters follow the same rule. |

`tx_save()`, `tx_restore()`, `tx_update()`, demotion/promotion, completion
handlers, recovery, cleanup, and guarded control remain the public mutation
boundaries. Review must find no direct mutation of an inventory or eligibility
input outside the centralized generation owner.

## Snapshot token

Controller construction creates a 256-bit nonce with the platform
cryptographic random source. The nonce is never serialized, logged, or returned.
`snapshot_token` is HMAC-SHA-256 keyed by the process nonce over a version tag,
generation, canonical hot rows, canonical per-incoming cold sets, and current
budgets. Canonical rows have fixed field order and payload-ID order.

Every discovery recomputes the token under `cache_state_mutex_`. Stable state
returns the same generation and token. Apply recomputes the current token and
uses constant-time comparison; it does not trust a stored token. Restart creates
a new nonce, so a token from another process cannot match even if generation and
inventory happen to match.

## `discover`

Strict request:

```json
{
  "operation": "discover"
}
```

Under the completion-admission latch and then `cache_state_mutex_`, controller
verifies idle state, builds both inventories with the pure cores, validates
integrity, reads `before_generation`, and computes the token from that same
state. Response fields are `snapshot_generation`, `snapshot_token`, separate
complete `hot_candidates` and `cold_sets`, and current positive budgets.

`discover` performs no rank, LRU, budget, descriptor, counter, file, topology,
metric, decision, generation, or one-shot mutation. It never calls
`tx_update()`. Success or failure does not consume the seam. Schema, guard,
idle, integrity, and snapshot failures are retryable.

## `apply`

`apply` keeps Part 11 scenario and budget fields and adds
`snapshot_generation`, `snapshot_token`, incoming identity, expected current
orders/ranks, and exact hot and cold arrays.

Under the same admission-then-cache lock order, `apply` first rebuilds the pure
inventories, validates integrity, requires generation equality, recomputes and
compares the token, and validates the incoming row, exact sets, current facts,
orders, ranks, and positive below-startup budgets. Any mismatch before
consumption returns `stale_snapshot` or a bounded validation error. It does not
advance generation and leaves the seam ready.

The validated value becomes `before_generation`. While still holding the lock,
controller changes `ready` to `consumed` and advances generation, then applies
each setup rank, order, and budget mutation through the generation owner.
Consumption and setup cannot be observed separately. Success and every later
failure are terminal.

If setup fails before `tx_update()` starts, rollback restores every changed
value through the same setters. Each restore advances generation; the seam stays
consumed. If `tx_update()` starts, normal transaction, completion, recovery, and
rollback owners determine state and generation. The wrapper performs no payload
compensation. In both cases it rebuilds the after inventories from current pure
predicates and records `after_generation` after all synchronous work and any
required rollback. A terminal error returns both generation fields and bounded
state summaries when safe, but never echoes the request token.

Successful response contains `before_generation`, `after_generation`, scenario,
consumed state, applied budgets, pressure completion, and separate `before` and
`after` hot/cold inventories. There is no ambiguous singular `generation` field.
After eligibility is recomputed; pre-pressure rows are never reused.

## Required tests and evidence

Controller tests:

- `test_stage39_live_pressure_discover_non_mutating`
- `test_stage39_live_pressure_snapshot_stale`
- `test_stage39_live_pressure_mixed_kind_cold_exact_set`
- `test_stage39_live_pressure_apply_atomic_revalidation`
- changed-then-restored, slot-reference drift, budget drift, token redaction,
  before/after generation, and inventory-integrity failure cases
- Part 39 TP-39-02/03/04, idle-race, and pre/post-pressure failure tests

Route file `tools/server/tests/unit/test_stage39_live_pressure.py` retains the
named discover, stale, redaction, omitted-checkpoint, guard, terminal, and
success cases from the prior plan.

Driver flow remains: wait for admission idle, discover, preserve response,
choose a discovered incoming row and its complete cold set, derive measured
budgets/ranks, apply the unchanged generation/token and exact arrays, then
preserve response, metrics, logs, inventories, sizes, and topology. Stale apply
must rediscover. TP-39-02 proves mixed-kind cold inventory, TP-39-03 proves an
empty selected cold set, and TP-39-04 proves measured oversize.

Implementation Parts 45 and 46 record the corrected plan. Fresh independent
Architect re-review must PASS before Manager may authorize code changes. QA
remains blocked.
