# Stage 10 follow-up: C1 - add test-stage10-policy-lru to coverage script

- Date: 2026-06-04
- Owner: Developer
- Source of action: [test-report-20260603-architect-review.md](../.test_reports/test-report-20260603-architect-review.md) Finding C / Action C1

## Action

Add `test-stage10-policy-lru` to the `$focusedTests` array in
`._design_docs/cache-handling-test-scripts/run_coverage.ps1`. The test exists
and passes ctest; it was simply not tracked by the coverage script.

## File changed

`._design_docs/cache-handling-test-scripts/run_coverage.ps1`

The entry was added at line 124 of the script, immediately after
`test-stage10-cold-store-hardening` and before `test-step6-demotion-protocol`,
preserving the array's existing ordering for the other entries. The exact
line added is:

```powershell
    'test-stage10-policy-lru',
```

The array name is `$focusedTests` and its closing `)` remains at line 132 of
the script. No other script logic, parameter handling, or entry was changed.

## Verification of the ctest registration

The ctest target for `test-stage10-policy-lru` is registered in
`tests/CMakeLists.txt` lines 315-319:

```cmake
# test-stage10-policy-lru covers the Stage 10 LRU eviction policy module
llama_build(test-stage10-policy-lru.cpp)
target_link_libraries(test-stage10-policy-lru PRIVATE server-context)
target_include_directories(test-stage10-policy-lru PRIVATE ${CMAKE_SOURCE_DIR}/tools/server)
llama_test(test-stage10-policy-lru)
```

The test source file is `tests/test-stage10-policy-lru.cpp` and the
`llama_test(...)` call on line 319 registers it as a ctest target. It is the
only registration line for this test name; no other CMake file references
it.

## Expected impact

`server-cache-policy-lru.cpp` rate should reach 80%+ once the next coverage
run includes this test. The Architect review recorded the prior rate as
70.37% (20 of 27 valid lines uncovered in the LRU plan paths). The new
test exercises the three early-return branches, the three comparator
branches, the protected-budget-pressure and budget-unsatisfied record
paths, and the zero-candidates path. With those paths covered, the
per-file rate for `server-cache-policy-lru.cpp` should clear the 80%
target on the next run of `run_coverage.ps1`.

## Scope

No C++ source, header, or test code was changed. This is a
script-coverage-tracking fix only. The Architect's C2 action (hybrid
controller test functions for `server-cache-hybrid.cpp` at 63.16%) is a
separate gate and was not touched.
