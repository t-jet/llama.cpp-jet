# Part 109: D39-EXEC-27 observed forbidden-effect evidence

Date: 2026-07-14
Status: PASS; ARCHITECT REVIEW NEXT
Authority: Design Part 53, Architect Part 107, Manager Part 108

## Scope

This correction replaces seven literal-zero terminal claims with seam-only
observations. Product control flow, routes, metrics, fixture, budgets, and
default builds did not change.

## Changes

- Checkpoint cold-budget classification, publish, committed completion, and
  cold-file creation increment counters at their existing production
  boundaries.
- Checkpoint descriptor and entry-link mutation boundaries increment counters.
  The terminal proof also compares the complete pre-apply and terminal
  descriptor: payload and owner identity, kind, residency, store reference,
  target/draft sizes and checksums, resident bytes, and pair state. It compares
  the owner entry's checkpoint link and checkpoint cold-file state as well.
- Cold-file, descriptor, and link deltas use the event count or terminal
  difference, whichever is nonzero. A changed-then-restored effect therefore
  remains visible.
- Guarded explicit generation calls are counted separately from normal
  `STAGE39_CACHE_MUTATED` advances. Terminal HMAC and retrieval bind the new
  observation block.
- Controller-only probes force each of the seven observed deltas to one and
  prove the shared forbidden-effect predicate rejects it. Controller and route
  consumers require equal before/after state and zero event counts.

## Evidence

The sole incremental seam build reused `build-stage39-seam-on`:

```text
cmake --build build-stage39-seam-on --config Release \
  --target test-cache-controller llama-server --parallel 2
PASS, exit 0, 16.6 seconds
```

Both targets linked. MSVC repeated three existing C4477 warnings at controller
test lines 7644, 7657, and 7765.

Pure terminal-shape negatives ran after the build:

```text
LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1
python -m pytest tools/server/tests/unit/test_stage39_live_pressure.py -q \
  -k "terminal_shape_rejects"
104 passed, 41 deselected in 0.10s
exit 0
```

The controller binary has no filter, so the registered seven-effect probe,
midpoint fault, and step-2 fault ran inside its suite:

```text
build-stage39-seam-on/bin/Release/test-cache-controller.exe
All tests passed successfully!
exit 0, 2.6 seconds
```

The midpoint and step-2 tests retain the D39-EXEC-26 shape, fault, HMAC,
retrieval, tamper, decision, transaction, staging, topology, and common-sync
checks. Each now also proves unchanged checkpoint descriptor, link, and file
state with zero observed checkpoint or explicit-generation events.

## Verdict

D39-EXEC-27 passes. Fresh Architect review is next. Both model route faults,
default build, fixture or budget changes, canonical TP-39-03, coverage, full
QA, commit, push, PR, and reviewer responses remain blocked.
