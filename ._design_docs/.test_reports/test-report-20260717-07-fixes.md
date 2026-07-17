# Stage 39 D39-QA-07 fix loop

Date: 2026-07-17
Status: READY FOR ARCHITECT RE-REVIEW
Owner: Developer
Source report: `test-report-20260717-07.md`
Developer review: `test-report-20260717-07-developer-review.md`

## Scope

D39-QA-07 failed in the clean Release seam-ON build because
`tests/test-step7-promotion-protocol.cpp` still called retired async
`hybrid_cache_controller` APIs:

- `debug_start_io_worker_for_tests`
- `debug_stop_io_worker_for_tests`
- `debug_set_io_worker_queue_capacity_for_tests`
- `process_completions`

This fix loop is test-only. No product code, fixture, workload, seam,
budget, threshold, TP-39-03 model run, coverage run, commit, push, PR, or
reviewer response was in scope.

## Correction

`tests/test-step7-promotion-protocol.cpp` now uses the current synchronous
promotion behavior:

- removed worker start, stop, capacity, drain, and sleep calls;
- changed the successful-promotion transient-state test to assert final
  inline hot residency after `promote_payload` returns;
- changed failure cases to assert `promote_payload` returns `false` and leaves
  the descriptor evicted after inline completion handling;
- kept success, failure, target/draft, cold-file-retention, multiple-promotion,
  nonexistent descriptor, and promoting-state checks;
- retired the async queue-full assertion with an explicit test-local rationale:
  Stage 25/28 removed the worker queue, so NB-2 queue-full revert has no
  current public equivalent;
- replaced the `process_completions` inspection test with a synchronous
  inline-dispatch regression that demotes, promotes, and checks final hot
  residency plus promotion success counters.

## Evidence

Fresh clean seam-ON Release configure:

```powershell
cmake -S . -B build-stage39-step7-fix-20260717-01 -DCMAKE_BUILD_TYPE=Release -DLLAMA_STAGE39_LIVE_TEST_SEAM=ON -DLLAMA_BUILD_TESTS=ON -DGGML_CUDA=OFF
```

Result: PASS, exit `0`.

Focused build target:

```powershell
cmake --build build-stage39-step7-fix-20260717-01 --config Release --target test-step7-promotion-protocol -j 4
```

Result: PASS, exit `0`.

Repaired executable:

```powershell
.\build-stage39-step7-fix-20260717-01\bin\Release\test-step7-promotion-protocol.exe
```

Result: PASS, exit `0`.

The executable reported all 16 Step 7 tests passed. Expected server diagnostics
appeared for negative cases such as not-cold promotion, missing cold file,
checksum mismatch, and already-promoting residency.

Not run by request:

- TP-39-03 model run
- coverage
- broader D39-QA-07 parser, pure, model, or coverage rows

## Handoff

The stale Step 7 promotion target now builds and runs in a fresh seam-ON
Release tree. QA can rerun the authorized D39-QA-07 sequence under a new
Manager gate, starting from the full clean build target set.

## F176-01 controller terminal matrix correction

Architect Part 176 found one remaining controller-test gap after the Step 7
fix: the shared C++ terminal predicate did not reject the three component
forbidden-effect fields already enforced by the route driver.

Code changed:

- `tests/test-cache-controller.cpp`

Change:

- added `later_kind_work_delta`, `post_abort_pressure_delta`, and
  `post_abort_diagnostic_delta` to
  `stage39_terminal_forbidden_effects_clear()`;
- extended the observed forbidden-effect probe matrix with focused negatives
  for the three component fields;
- each component negative now verifies selected component `1`, sibling
  components `0`, aggregate `later_work_delta` `1`, common predicate rejection,
  hot checkpoint residency, zero topology deltas, and empty diagnostic deltas.

No product code changed.

Evidence:

```powershell
cmake -S . -B build-stage39-f176-fix-20260717-01 -DCMAKE_BUILD_TYPE=Release -DLLAMA_STAGE39_LIVE_TEST_SEAM=ON -DLLAMA_BUILD_TESTS=ON -DGGML_CUDA=OFF
```

Result: PASS, exit `0`.

```powershell
cmake --build build-stage39-f176-fix-20260717-01 --config Release --target test-cache-controller -j 4
```

Result: PASS, exit `0`.

```powershell
.\build-stage39-f176-fix-20260717-01\bin\Release\test-cache-controller.exe
```

Result: PASS, exit `0`; footer reported `All tests passed successfully!`.

Not run by request:

- TP-39-03 model run
- coverage

Durable implementation evidence:
`../cache-handling-phase39-implementation/part-177-f176-01-controller-terminal-matrix-fix-20260717.md`

Current handoff: F176-01 is ready for Architect re-review. Manager should not
authorize another canonical TP-39-03 rerun until that review passes.
