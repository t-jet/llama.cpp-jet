# Part 11: live pressure testability correction

Date: 2026-07-13
Status: INDEPENDENT ARCHITECT RE-REVIEW PASS (PART 14)

## Binding Manager decision

> D39-EXEC-01 APPROVED: narrow test-only model-backed live pressure seam may admit under high positive hot budget, then lower hot/cold budgets and deterministically set/expose victim rank/ownership. Must drive normal production tx_save/pressure/demotion/decision/metrics/log/accounting; no public cache semantics, threshold, or live-tier relaxation. Coverage remediation limited to Phase3 dummy command replacement + immediate nonzero merge failure.

This correction resolves the testability gap found by QA report 20260713-01 and
Developer results review Part 38. It does not change I-39-01 through I-39-08,
the reason taxonomy, or the Stage 39 closure threshold.

Design Part 2's "no new public endpoint" rule remains binding. The route below
is compiled out of default builds and absent without explicit QA opt-in.

## Guarded interface

Add one internal POST control route named
`/debug/cache/stage39-live-pressure`. It exists only when all guards pass:

1. CMake option `LLAMA_STAGE39_LIVE_TEST_SEAM=ON` defines a dedicated compile
   guard. Its default is `OFF`. It is separate from
   `LLAMA_SERVER_CACHE_TESTS`, which the current server-context target defines.
2. Runtime environment variable `LLAMA_STAGE39_LIVE_TEST_SEAM=1` is present.
3. `LLAMA_STAGE39_LIVE_TEST_TOKEN` contains at least 32 characters. Each POST
   supplies the same value in `X-Llama-Stage39-Test-Token`.
4. Server binds only to `127.0.0.1` or `::1`, runs a single model in hybrid
   mode, has metrics enabled, and starts with positive hot and cold budgets.

When compiled out, route and controller seam symbols do not exist. When compiled
in but runtime opt-in is absent, route is not registered. If opt-in is requested
with an invalid host, mode, token, router mode, metrics state, or budget, startup
fails. The token is never logged or returned. Installed and default builds keep
their current CLI, endpoints, and cache behavior.

Each server process permits one mutation attempt. Schema, token, startup-state,
idle-state, and complete-candidate-set validation failures occur before mutation
and remain retryable. Immediately before the first rank or budget write, the
server changes seam state from `ready` to irreversible `consumed`. Success and
every later failure remain terminal. Later requests return `consumed` without
mutation. QA starts a fresh process per TP row.

## Request and response

The strict request schema is:

```json
{
  "scenario": "tp39-02",
  "hot_budget_bytes": 1,
  "cold_budget_bytes": 1,
  "hot_candidates": [
    {
      "payload_id": 1,
      "owner_entry_id": 1,
      "hot_order": 0
    }
  ],
  "cold_victims": [
    {
      "payload_id": 2,
      "owner_entry_id": 2,
      "cold_rank": 0
    }
  ]
}
```

`scenario` accepts only `tp39-02`, `tp39-03`, or `tp39-04`. Budgets must be
positive and strictly lower than their startup values. `hot_candidates` names
the complete model-backed hot exact-blob set that production hot pressure will
consider after the requested budgets apply. Every row must have
`residency == hot`. `cold_victims` names the complete set that the production
cold-residency victim selector can evict for the incoming hot candidate. Every
row must have `residency == cold`. A descriptor cannot occur in both arrays.

While holding the cache-state lock, validation independently recomputes both
sets with production predicates and compares payload IDs exactly. Each supplied
owner must match live ownership. Payload IDs and owner entry IDs are unique
within and across both arrays. `hot_order` values are unique. `cold_rank` may
tie. No eligible row may be omitted; no ineligible or extra row may be present.
Hot eligibility uses production protection, slot-reference, residency,
pair-state, and ownership predicates. Cold eligibility also requires exclusive
`cold` residency and every predicate used by the production cold selector.
Validation proves there is no further eligible cold victim outside the request.

Each hot owner is removed from and reinserted into the owner LRU index once in
`hot_order`. Cold rank writes update only the cold descriptors' deterministic
sequence field. Descriptor sequence updates occur in the same locked mutation.
Equal `cold_rank` values retain production tie order by
`(last_validated_sequence, payload_id)`. The response reports the recomputed
complete hot and cold sets separately.

The seam changes only owner entry LRU order, descriptor
`last_validated_sequence`, and the two byte budgets. It never rewrites payload
ownership, protection, pair state, sizes, IDs, files, residency, counters, or
topology.

Response contains `before` and `after` arrays. Each row exposes payload ID,
owner entry ID, payload kind, pair state, residency, protected-root state, slot
reference count, resident bytes, serialized cold bytes when known, hot order,
cold rank, and eligibility. It also reports applied budgets and whether normal
pressure completed. This response is test evidence, not a Prometheus family.
No path, token, prompt text, or payload byte content is returned.

## Lifecycle and production-path rule

Control and completion dispatch share one server-context admission latch. Normal
task dispatch acquires it immediately before launching any parent or child
completion. Control acquires it first, rejects if any slot is active, and holds
it through final snapshot or failure cleanup. No completion can become active
between idle check and mutation. Lock order is admission latch, then cache-state
lock. Control performs this order:

1. Validate the complete request and snapshot state without mutation.
2. Verify every payload-owner pair, unique ID, exact complete hot-candidate set,
   and exact complete eligible cold-victim set; compute requested ranks.
3. Change `ready` to `consumed`, then apply ranks and lower both budgets.
4. Release no payload directly. Invoke normal `tx_update()` once.
5. Let production policy call `mark_payload_kind_evicted()`,
   `tx_demote_payload()`, cold room-making, transaction commit or rollback,
   decision recording, accounting, logs, and exporter state.
6. Snapshot final state, release cache-state lock, then release admission latch.

Validation failure releases both locks with seam state `ready`. A failure after
the `consumed` transition never rearms it. Before `tx_update()` starts, restore
ranks, owner LRU membership, descriptor sequences, and budgets from the snapshot.
After `tx_update()` starts, normal transaction recovery owns payload outcome;
the wrapper performs no compensating payload action. Both paths release locks
and return a redacted terminal error. The seam cannot call demotion, victim
quarantine, eviction, decision recording, metric recording, or accounting
helpers directly.

## Exact live scenarios

TP-39-02 starts with positive hot budget smaller than the aggregate resident
bytes but larger than the incoming pair, plus a cold budget large enough for
all measured objects. QA admits two smaller victim pairs first, then admits the
larger incoming pair through normal completions. Normal `tx_save()` and hot
pressure demote both victims through `tx_demote_payload()`; the incoming pair
stays hot. QA waits for idle and verifies the two victim descriptors are
exclusively `cold`, the incoming descriptor is `hot`, and no other descriptor
is eligible for either production selector.

One control request lists the incoming descriptor in the complete
`hot_candidates` array and both resident cold descriptors in the complete
`cold_victims` array. It assigns equal `cold_rank` to the victims, gives the hot
candidate deterministic `hot_order`, and lowers both positive budgets. The
single normal `tx_update()` applies hot pressure to the incoming candidate.
Its normal demotion needs room and invokes the production cold selector, which
ranks the complete cold set and removes both victims. PASS requires victim
order by payload ID after the equal rank, at least two victim tombstones,
incoming cold ownership intact, `retained_cold/cold_room_made`, a committed
transaction, exact file/accounting reconciliation, and zero entry, branch, or
pruning delta.

TP-39-03 admits at least two distinct pairs while hot budget is high. QA lowers
hot budget below aggregate resident bytes but not below the selected pair, and
sets a positive cold budget below that pair. No cold object can be an eligible
victim before the attempt. PASS requires normal hot pressure to emit exactly one
`evicted/both_filled`, retain descriptor tombstone and owner entry, reconcile
bounded gauges, and leave entry, branch, and pruning counts unchanged.

TP-39-04 admits and measures a model-backed pair while both positive startup
budgets exceed its resident and immutable serialized sizes. Only then does QA
lower both budgets below those sizes. This replaces only the older Part 3 and
test-plan setup phrase "admit pair larger than both positive budgets"; result
taxonomy and acceptance stay unchanged. PASS requires normal hot pressure to emit exactly one
`evicted/oversized_both`, retain owner and descriptor tombstone, expose no
partial target/draft state, reconcile bounded gauges, and leave entry, branch,
and pruning counts unchanged.

For all three rows, QA preserves the control request/response, requests,
responses, before/after `/metrics`, fixed decision and transaction logs, cold
inventories, and measured sizes. Direct controller injection cannot replace
this evidence.

## Coverage correction boundary

In `run_coverage.ps1`, Phase 3 replaces only the trailing
`cmd /c exit 0` command with the absolute no-argument
`$env:SystemRoot\System32\whoami.exe`. The script verifies that executable
exists, passes it as the single token after `--`, and throws immediately when
the merge process exit code is nonzero, before parsing XML. Phase order,
captures, denominator, server probe, report format, and 80 percent threshold do
not change.

## Acceptance and handoff

Independent Architect re-review Part 14 confirms compile/runtime isolation,
dispatch serialization, terminal one-shot behavior, exact candidate-set
validation, no direct production outcome injection, exact TP-39-02 through
TP-39-04 predicates, and coverage-fix scope. Manager correction-plan gate is
next. QA reruns only the three blocked rows and canonical coverage after
implementation and review.
