# Part 3: observability, tests, and acceptance

## Observability

Keep existing gauges and counters. Add these public Prometheus families:

| Family | Labels | Fixed values |
| --- | --- | --- |
| `llamacpp:cache_two_layer_decisions_total` | `mode`, `result`, `reason` | mode: `hybrid`; result: `retained_cold`, `evicted`, `bypassed`, `retained_hot`; reason: `cold_room`, `cold_room_made`, `both_filled`, `oversized_both`, `cold_disabled`, `io_error`, `integrity_error`, `size_overflow` |
| `llamacpp:cache_cold_transactions_total` | `mode`, `result`, `reason` | mode: `hybrid`; result: `commit`, `rollback`, `recovery`; reason: `none`, `stage_write`, `stage_validate`, `victim_quarantine`, `incoming_publish`, `apply`, `commit_marker`, `cleanup`, `manifest` |

Emit exactly one decision row per hot-pressure candidate. Transaction rows may
also increment for its commit, rollback, or recovery. Logs use fixed
`event=cache_two_layer_decision result=<value> reason=<value> payload_id=<id>`
and `event=cache_cold_transaction result=<value> reason=<value> tx_id=<id>`
fields. IDs appear only in logs, never labels. Existing branch-pruning metrics
must have zero delta for payload pressure.

Capacity events and I/O errors must not share a reason. Branch-pruning metrics
must remain unchanged for payload-pressure operations.

The hybrid-cache controller owns label selection. It passes typed `mode`,
`result`, and `reason` values to the metrics exporter; callers must not pass
free-form label strings. The exporter maps the only accepted mode enum to
`hybrid`. Unknown enum values are contract violations: reject the increment,
emit no public series, and trigger the existing internal invariant diagnostic.
Do not normalize an unknown value to `hybrid`, `unknown`, or an empty label.

## Required tests

| ID | Scenario | Proof |
| --- | --- | --- |
| TP-39-01 | Hot filled, cold has room | Demotion succeeds; no payload eviction; restore from cold works. |
| TP-39-02 | Cold pressure with eligible victims | Deterministic multi-victim room-making, then demotion; selected descriptors remain as evicted tombstones. |
| TP-39-03 | Both filled, no eligible cold victim | Payload eviction allowed with both-filled reason; metadata remains. |
| TP-39-04 | Payload exceeds both budgets | Oversized reason; accounting remains bounded. |
| TP-39-05 | Cold disabled; hot zero | Cold-disabled hot pressure emits `bypassed/cold_disabled`; `--cache-ram 0` starts with prompt cache disabled and emits no Stage 39 row even with cold configured. |
| TP-39-06 | Cold write, validation, cleanup failures | Hot payload remains byte-identical and restorable; no capacity reason. |
| TP-39-07 | Target plus draft pair | Pair demotes, restores, rolls back, or evicts atomically. |
| TP-39-08 | Exact blob plus checkpoint on one entry | Independent ranking; no entry or branch deletion. |
| TP-39-09 | Protected root and live descendant | Ordering respected; ownership-safe cleanup; topology valid. |
| TP-39-10 | Concurrent slot transactions | Deterministic totals; no partial visibility or deadlock. |
| TP-39-11 | Legacy mode | Behavior and metrics unchanged. |
| TP-39-12 | Production save pressure path | Real `tx_save` path proves demotion before eviction; debug helpers alone do not satisfy this row. |
| TP-39-13 | Exact serialized-size boundaries | Prepared file exact-fit commits; one-byte-over is capacity exhausted; format overhead is counted; checked-add overflow retains hot and emits `retained_hot/size_overflow`. |
| TP-39-14 | Reversible multi-victim transaction | Failure after every mutation and crash before/after commit marker recovers exact pre-state or committed state; no partial visibility. |
| TP-39-15 | Public label enum and cardinality | Exercise every accepted enum value and an invalid cast at the controller/exporter boundary; scrape contains only the fixed values above, invalid input creates no series, decision series never exceed 32, and transaction series never exceed 27. |

## Evidence map

| Rows | Required evidence |
| --- | --- |
| TP-39-01, TP-39-02, TP-39-03, TP-39-04, TP-39-05, TP-39-11, TP-39-12 | Live `/metrics` deltas for both new families, existing byte/eviction/pruning metrics, and matching bounded server log row. |
| TP-39-06, TP-39-07, TP-39-09, TP-39-10, TP-39-13, TP-39-14 | Focused C++ state assertions, staged/final/quarantine file inventory, stats-export rows for new families, and exact log row. |
| TP-39-08 | Focused C++ descriptor, lookup-entry, and branch-topology assertions plus zero pruning delta. |
| TP-39-15 | Focused enum mapping assertions plus a live scrape that enumerates all label values and counts complete family series. |

Every row records before/after metric samples, expected label tuple, observed log
tuple, hot bytes, descriptor-owned cold bytes, quarantine bytes, file count, and
lookup/branch counts. QA evidence must quote the exact row, not infer outcomes
from aggregate eviction totals.

Every expected tuple for TP-39-01 through TP-39-10 and TP-39-12 through
TP-39-15 uses `mode="hybrid"` for either public family. TP-39-11 expects zero
delta in both families. No test may accept any other `mode` value. The 32 and
27 limits are closed Cartesian upper bounds; valid result/reason pairing rules
may yield fewer series, never more.

Focused C++ coverage must remain at least 80% for changed hybrid-cache lines.
Run controller tests, `ctest -R cache`, and a live server workload with budgets
small enough to reach hot pressure and cold room-making deterministically.

## Acceptance

Stage 39 passes only when:

- I-39-01 through I-39-08 pass;
- every capacity-driven payload eviction proves both enabled layers lacked room;
- every non-capacity cold failure preserves the hot payload;
- payload pressure produces zero branch-pruning or entry-removal events;
- byte gauges reconcile with stored files and resident buffers;
- focused coverage reaches 80%;
- documentation, tests, and production behavior use the same reason taxonomy.
