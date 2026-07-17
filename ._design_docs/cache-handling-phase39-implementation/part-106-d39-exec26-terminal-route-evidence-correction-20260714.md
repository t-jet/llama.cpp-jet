# Part 106: D39-EXEC-26 terminal route evidence correction

Date: 2026-07-14
Status: PASS; ARCHITECT REVIEW NEXT
Authority: Design Part 52, Architect Part 104, Manager Part 105

## Scope

This gate changed only guarded terminal proof state and the pure, controller,
and route assertions that consume it. It did not change fault control flow,
fixtures, budgets, default builds, or production metrics.

## Changes

- `tools/server/server-cache-hybrid.h` stores one guarded pre-apply baseline,
  terminal sync count, and the authenticated terminal state.
- `tools/server/server-cache-hybrid.cpp` captures entry, branch, descriptor,
  cold-file, byte-map, inventory, topology, decision, transaction, diagnostic,
  generation, and later-work evidence after `tx_update()`. Existing terminal
  HMAC and retrieval now bind and return that block byte-equivalent.
- `tests/test-cache-controller.cpp` checks the complete midpoint and step-2
  terminal matrix, exact-only commit and decision tuples, staging cleanup,
  unchanged topology, one sync, failed apply, consumed retry, HMAC retrieval,
  and tamper rejection.
- `tools/server/tests/unit/test_stage39_live_pressure.py` uses the same terminal
  matrix for route assertions. Pure negatives remove every required field and
  change every required zero delta.
- This part, the implementation entry, `document-index.md`, and the stage
  tracker record the focused PASS and Architect handoff.

## Evidence

Pure shape gate ran before the build:

```text
LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1
python -m pytest tools/server/tests/unit/test_stage39_live_pressure.py -q \
  -k "terminal_shape_rejects"
70 passed, 41 deselected in 0.08s
exit 0
```

The sole authorized seam-enabled build compiled both targets together:

```text
cmake --build build-stage39-seam-on --config Release \
  --target test-cache-controller llama-server --parallel 2
PASS, exit 0, 24.6 seconds
```

MSVC repeated three existing C4477 warnings at controller-test lines outside
this gate. Both requested targets linked.

The controller binary has no test filter, so the focused cases ran inside its
registered suite:

```text
build-stage39-seam-on/bin/Release/test-cache-controller.exe
midpoint common-epilogue: PASSED (log lines 796-801)
step-2 common-epilogue: PASSED (log lines 802-807)
All tests passed successfully!
exit 0, 2.9 seconds
```

Both faults reported one `retained_cold/cold_room` decision and one
`commit/none` transaction for exact payload 1. Assertions also proved a hot,
linked checkpoint, no staging file, zero other tuple or forbidden-effect
deltas, one common sync, unchanged entry/node/LRU topology, authenticated
byte-equivalent retrieval, tamper rejection, and consumed retry.

## Verdict

D39-EXEC-26 passes. Fresh Architect implementation review is next. Both model
route faults remain blocked until that review passes. No model route, default
build, fixture or budget change, canonical TP-39-03, coverage, full QA, commit,
push, PR, or reviewer response occurred.
