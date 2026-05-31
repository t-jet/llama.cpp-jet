# Stage 7 metrics correction - Part 9

Source: [../cache-handling-phase7-implementation.md](../cache-handling-phase7-implementation.md)  
Correction date: May 31, 2026  
Trigger: [Part 8 implementation re-review](part-08-implementation-re-review.md), R4

## Scope

This correction is limited to the Stage 7 Prometheus metrics contract. R1, R2, R3, and R5 were
already resolved in Part 8. QA is not open.

## Code changes

Changed files:

- `tools/server/server-cache-graph.h`
- `tools/server/server-cache-graph.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tests/test-step12-branch-graph.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

Behavior:

- `cache_branch_lookups_total` now exports the accepted `namespace` and `method` labels.
- Hybrid lookup counters are tracked per namespace for `token_span` and `checksum_span`.
- Legacy mode, and hybrid startup before any branch namespace exists, emit
  `namespace="none"` with zero or aggregate startup values. Once the hybrid controller has real
  namespace data, the metric uses those namespace IDs.
- `cache_branch_traversals_total` now exports the accepted `operation` label for
  `path_to_root`, `descendants`, and `children`.
- Branch graph traversal accessors record minimal counters without changing traversal behavior.
- Existing Stage 4, Stage 5, Stage 6, and Part 7 Stage 7 metric names remain exported.
- The Python metrics shape test now checks the accepted lookup labels and traversal metric labels.
- The branch graph test now checks traversal counters after calling the traversal accessors.

## Evidence

Server build:

```powershell
cmake --build build --config Release --target llama-server -j 4
```

Result: PASS. Built `build\bin\Release\llama-server.exe`.

Focused graph build:

```powershell
cmake --build build --config Release --target test-step12-branch-graph -j 4
```

Result: PASS. Built `build\bin\Release\test-step12-branch-graph.exe`.

Focused controller build:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
```

Result: PASS. Built `build\bin\Release\test-cache-controller.exe`.

Focused graph test:

```powershell
ctest --test-dir build -C Release -R test-step12-branch-graph --output-on-failure
```

Result: PASS. CTest ran 1 test and it passed in 0.03 seconds.

Focused controller test:

```powershell
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Result: PASS. CTest ran 1 test and it passed in 0.06 seconds.

Metrics shape:

```powershell
$env:LLAMA_SERVER_BIN_PATH=(Resolve-Path build\bin\Release\llama-server.exe).Path; $env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'; pytest tools/server/tests/unit/test_cache_modes.py
```

Result: PASS. Pytest reported 3 passed and 1 xfailed. The xfail is the existing explicit `id_slot`
restore-path limitation.

Execution note:

- An initial parallel build of `llama-server` and `test-step12-branch-graph` hit an MSBuild
  object-file write conflict. Rerunning the graph target by itself passed.

## Handoff

Correction status: complete.

R4 is ready for implementation re-review. QA remains unopened.
