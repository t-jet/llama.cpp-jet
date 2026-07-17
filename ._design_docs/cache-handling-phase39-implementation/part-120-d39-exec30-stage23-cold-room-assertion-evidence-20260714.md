# Part 120: D39-EXEC-30 Stage 23 cold-room assertion evidence

Date: 2026-07-14
Status: PASS; FRESH ARCHITECT FIX REVIEW NEXT

## Scope

D39-EXEC-30 changed only
`test_stage23_cold_room_making_keeps_checkpoint_attach_coherent`, its invocation,
and one stale Stage 28 comment. The two Stage 28 rejection test bodies and
invocations are unchanged. No product, server, route, model, driver, or public
metric code changed.

## Assertion correction

The Release-active test now proves:

- payload eviction progression `0 -> 1 -> 3`;
- first-step cold/hot state and final evicted/cold state with both exact links;
- hot/cold/evicted descriptor counts `0/1/1`, zero hot bytes, demotions `2/0`,
  and one cold eviction;
- one `.cold` file, no quarantine file, and exact file/controller/store byte
  reconciliation;
- only `retained_cold/cold_room` and
  `retained_cold/cold_room_made` decisions, total 2;
- only `commit/none` transactions, total 2, with forbidden fallback, rollback,
  and recovery evidence absent;
- successful target-only checkpoint admission on payload 2's owner, with the
  checkpoint hot at 96 bytes while payloads 1 and 2 remain evicted and cold;
- post-admission hot/cold/evicted counts `1/1/1`, resident bytes 96, unchanged
  cold file/bytes, and byte-identical decision and transaction arrays.

## Evidence

Authorized incremental build:

```text
cmake --build build-stage39-seam-on --config Release --target test-cache-controller --parallel 4
exit: 0
```

MSBuild rebuilt and linked `test-cache-controller.exe`. Three existing C4477
warnings at lines 7742, 7755, and 7863 remain outside this gate.

Authorized sole full-suite run:

```text
build-stage39-seam-on/bin/Release/test-cache-controller.exe
exit: 0
footer: All tests passed successfully!
```

The renamed Stage 23 row passed. Both independent Stage 28 rejection rows, all
seven Stage 39 observed forbidden-effect probes, and the midpoint and step-2
common-epilogue fault rows also passed.

## Handoff

D39-EXEC-30 is complete. Fresh Architect fix review owns the next gate. Route
fault execution, broader QA, coverage, model runs, and product changes remain
blocked until separately authorized.
