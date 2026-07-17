# Part 2: independent implementation-plan review

Date: 2026-07-12
Verdict: REWORK REQUIRED

## Review scope

Reviewed the approved Stage 39 design, Manager design gate, implementation
entry, Part 1, and current production and test surfaces:

- `hybrid_cache_controller::tx_save`, `tx_demote_payload`,
  `mark_payload_evicted`, and `cold_budget_make_room` in
  `tools/server/server-cache-hybrid.cpp`;
- `server_cache_store_cold::write`, `read`, `remove`, and `delete_ids` in
  `tools/server/server-cache-store-cold.cpp`;
- synchronous demotion in `server-cache-io-worker.*`;
- hybrid stats export in `hybrid_cache_controller::get_stats` and Prometheus
  rendering in `server-context.cpp`;
- `tests/test-cache-controller.cpp` and
  `tools/server/tests/unit/test_cache_modes.py`.

Part 1 has the right scope, production path, fixed metric domains, rollback
intent, and TP-39 coverage target. The gaps below still require Developer to
choose transaction behavior.

## Blocking findings

### F39-IPR-01: pre-commit recovery cannot restore released hot bytes

Part 1 Step 3 says descriptor apply is followed by hot-byte release. Step 2
places the durable commit marker later. Recovery before that marker restores
descriptor pre-state and removes the incoming file. A crash after hot release
but before marker durability therefore restores a hot descriptor without its
hot bytes and deletes the only durable incoming copy. This violates I-39-04 and
I-39-08.

Correction must give one exact ordered state machine, with named manifest
states and fsync/atomic-replace boundaries. Either make commit-marker durability
precede hot release, or specify how recovery reconstructs the hot pair from the
published incoming file before removing it. Map every failure injection point
to its runtime rollback and restart-recovery result. Include descriptor,
accounting, incoming, quarantine, staging, and hot-residency postconditions.

Acceptance check: no crash boundary can produce a hot descriptor without bytes,
delete the last valid payload copy, or expose an uncommitted final file.

### F39-IPR-02: quarantine charging makes room-making math undefined

Step 3 says the fit calculation includes both post-commit descriptor-owned bytes
and quarantine bytes. Quarantined victim bytes still exist until cleanup, so
counting them while also requiring the incoming object to fit means victim
quarantine cannot create room. The plan does not state whether a bounded
transaction reserve, temporary physical overage, or pre-publish unlink is
allowed. Developer would have to invent the capacity rule.

Correction must define separate equations for logical committed cold bytes,
physical final bytes, staging bytes, and quarantine bytes at each transaction
state. State which total enforces `cold_budget_bytes`, the maximum temporary
overage, and behavior when cleanup fails. Keep checked `uint64_t` arithmetic and
exact closed-file length in each equation.

Acceptance check: provide exact-fit and one-byte-over examples for one and
multiple victims, including cleanup failure and restart recovery.

### F39-IPR-03: production API and TP mapping is not executable enough

Affected-file lists do not assign the new operations to exact APIs. The current
write path is `tx_demote_payload` -> `io_worker.execute_demotion_inline` ->
`server_cache_store_cold::write`; metrics travel through `get_stats()` JSON and
`server-context.cpp`. Part 1 does not say which existing methods are replaced,
which new method signatures own prepare/plan/commit/recover, or the exact stats
row schema consumed by the exporter. Its grouped TP lists also do not map each
TP-39 row to a production entry point, focused test function, live test, metric
tuple, log tuple, and preserved artifact.

Correction must add an API/file mapping table with signatures and call order,
including startup recovery before `reconcile_cold_store_with_per_id_map()`. Add
a TP-39-01 through TP-39-15 evidence matrix. Name rollback/recovery tests for
each mutation boundary and identify TP-39-12 as real `tx_save` pressure, not a
standalone demotion helper.

Acceptance check: an implementer can add each method and test without choosing
names, ownership, call placement, metric JSON shape, or evidence source.

## Non-blocking checks

- Closed metric label sets match the approved design: 32 decision and 27
  transaction Cartesian ceilings, with `mode="hybrid"` only.
- Plan preserves lookup entries and branch nodes under payload pressure.
- Rollback correctly forbids manual deletion of unknown transaction files.
- No descriptor or cold payload format migration is planned.

## Verdict and handoff

REWORK REQUIRED. Code remains blocked. Developer should correct Part 1 for
F39-IPR-01 through F39-IPR-03, then request a fresh Architect plan re-review.
Manager implementation-plan gate remains closed.
