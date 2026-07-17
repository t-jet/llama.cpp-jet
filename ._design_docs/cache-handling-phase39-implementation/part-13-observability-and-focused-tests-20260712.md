# Part 13: observability and focused tests

Date: 2026-07-12
Status: PARTIAL

## Completed work

Stage 39 now keeps decision and cold-transaction counters as typed enum tuples.
The controller rejects invalid mode, result, or reason values before increment.
Rejected values create an internal invariant diagnostic and no public row.

`get_stats()` exports `cache_two_layer_decisions` and
`cache_cold_transactions` arrays. `server-context.cpp` maps those arrays to the
two approved Prometheus families without an empty fallback series. Logs use the
fixed `event`, `result`, `reason`, and ID fields from the approved design. IDs
do not enter metric labels.

The production demotion transaction records:

- retained-cold decisions for direct-fit and victim-room-making commits;
- provisional retained-hot decisions for write, validation, manifest,
  quarantine, publish, and commit-marker failures;
- commit or rollback transaction rows with bounded reasons.

Focused TP-39-15 coverage exercises all 32 decision tuples and all 27
transaction tuples. Invalid enum casts are rejected. Exported controller stats
contain only `mode="hybrid"` and named fixed values.

## Files

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`

## Evidence

Release build passed:

```text
cmake --build build --config Release --target test-cache-controller llama-server -j 4
```

Focused controller execution passed, including `Stage 39 typed metric
cardinality`:

```text
build/bin/Release/test-cache-controller.exe
All tests passed successfully!
```

Cache CTest passed:

```text
ctest --test-dir build -C Release -R cache --output-on-failure
1/1 Test #26: test-cache-controller ... Passed
```

## Remaining work

Implementation is not complete. The hot-pressure caller still falls back to
immediate eviction after a non-capacity demotion failure. That path must retain
hot bytes and must move decision emission to the final controller outcome so
one candidate cannot log `retained_hot` before eviction. TP-39-14 still needs the approved fault seams
and fresh-controller pre-commit and post-commit recovery matrix, including
multi-victim replay, exact/checkpoint owner links, idempotence, conflicting
state, missing-owner reconstruction, and claimed-path reconciliation. TP-39-13
still needs complete exact-fit, one-byte-over, format-overhead, and checked-add
overflow controller coverage. Live `/metrics` and fixed-log automation remains
open for TP-39-01 through TP-39-05, TP-39-11, TP-39-12, and TP-39-15. Focused
changed-line coverage has not been measured.

## Gate

Keep implementation gate open. Next owner: fresh Developer for TP-39-13 and
TP-39-14 coverage and QA automation, then Architect implementation review.
