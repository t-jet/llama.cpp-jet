# Part 121: Architect D39-EXEC-30 fix review

Date: 2026-07-14
Verdict: REWORK; ONE COMMENT-ONLY CORRECTION
Scope: Parts 114-120 and the affected controller tests

## Review result

The renamed Stage 23 test is Release-safe. Setup, both mutation calls, and all
verdict checks use `require_or_abort`. It requires two entries before iterator
access and proves payload-eviction progression `0 -> 1 -> 3`.

The first and second snapshots prove exact entry links, hot/cold/evicted
residencies, descriptor counts, hot bytes, demotion counts, and the cold
victim. Disk evidence requires one `.cold` file, no quarantine file, and exact
controller/store/file byte reconciliation. Decision and transaction arrays
are exact: one `retained_cold/cold_room`, one
`retained_cold/cold_room_made`, and two `commit/none` events. Exact arrays plus
the transition check exclude the forbidden pressure, rollback, and recovery
outcomes.

Checkpoint admission proves kind and owner linkage, target-only hot residency,
96 target bytes, no draft bytes, unchanged exact links and residencies,
hot/cold/evicted counts `1/1/1`, unchanged cold file and bytes, and unchanged
decision and transaction arrays.

Both Stage 28 rejection test bodies and invocations remain present and
Release-active. Part 120 records the incremental controller build and one full
suite run with exit zero, the renamed Stage 23 row, both Stage 28 rejection
rows, seven Stage 39 observation probes, both common-epilogue faults, and the
suite footer. The current controller executable is newer than the current test
source. The guarded server source hashes still match Part 112, and the existing
server binary remains the fresh Part 112 binary.

## Blocking finding F39-TEST-02

The Stage 28-labeled comment inside
`test_stage23_cold_room_making_keeps_checkpoint_attach_coherent` still says the
second demotion is rejected by the cold-budget gate and falls back to immediate
eviction. The test and Stage 39 policy do the opposite: production makes cold
room by evicting payload 1, then commits payload 2 as cold.

Part 118 required stale Stage 28 comments about this test to be updated. This
comment is false durable guidance beside the corrected test, so D39-EXEC-30 is
not ready to sign off.

## Exact correction

Change only that stale comment block. State that synchronous Stage 39 pressure
demotes payload 1, then makes cold room for payload 2 by evicting payload 1.
Do not change code, assertions, test names, invocations, product files, route
helper, fixture, budgets, or evidence.

Because this is comment-only in the controller test source, no rebuild or test
rerun is required. Fresh Architect verification needs only the exact diff,
current function text, and confirmation that the Stage 28 rejection bodies and
invocations remain unchanged.

## Route readiness

D39-EXEC-27 remains substantively ready. Current guarded
`server-cache-hybrid.cpp` and `.h` hashes match the fresh Part 112 inputs, and
the complete Part 107-110 terminal, authentication, consumer, and seven-effect
contracts remain unchanged. After F39-TEST-02 closes, Manager may authorize the
two isolated route faults under the unchanged Part 107 contract. Route
execution remains blocked until that review passes.
