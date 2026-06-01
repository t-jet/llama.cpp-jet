# Stage 8 implementation evidence - 2026-06-01

Source: [../cache-handling-phase8-implementation.md](../cache-handling-phase8-implementation.md)

## Scope checked

This pass inspected the current Stage 8 worktree against approved steps 8.1
through 8.13 and corrected implementation-gate issues found during the check.

## Code changes in this pass

- `tools/server/server-cache-graph.cpp`: copied `absent_reason` with
  `branch_node`, and kept payload eviction comments concise.
- `tools/server/server-cache-hybrid.cpp`: immediate payload eviction now calls
  `forest.evict_payload()` and increments
  `cache_metadata_only_retentions_total`; cold cleanup keeps descriptors for a
  later retry if batch deletion is partial.
- `tests/test-step13-stage8.cpp`: added a focused controller assertion for
  immediate eviction retaining metadata-only state through the Stage 8 metric.

Pre-existing Stage 8 worktree changes were already present in:

- `tools/server/server-cache-graph.*`
- `tools/server/server-cache-hybrid.*`
- `tools/server/server-cache-store-cold.*`
- `tests/CMakeLists.txt`
- `tests/test-step13-stage8.cpp`

## Step coverage found

| Step | Status in current worktree |
| --- | --- |
| 8.1 | Implemented and focused-tested for forest payload eviction. |
| 8.2 | Implemented and focused-tested for safe metadata pruning. |
| 8.3 | Implemented and focused-tested for basic equivalent lookup and canonical selection. |
| 8.4 | Implemented and focused-tested for token-length ranking, payload-bearing preference, and mismatch-parent selection. |
| 8.5 | Implemented and focused-tested in the forest planner. Controller trigger coverage is still missing. |
| 8.6 | Partial. Immediate eviction records metadata-only retention, but successful controller re-materialization and atomic save are not implemented. |
| 8.7 | Not implemented in the controller. |
| 8.8 | Not implemented in the controller admission path. |
| 8.9 | Partial. The pressure pipeline calls metadata pruning, but admission rejection coverage is missing. |
| 8.10 | Partial. Cold cleanup has delete plumbing and descriptor retry safety; retained-descendant ownership tests are missing. |
| 8.11 | Partial. Metric names are present in stats; lifecycle counters and diagnostics are incomplete. |
| 8.12 | Implemented for the focused `test-step13-stage8` target. |
| 8.13 | This part records the implementation evidence and remaining gaps. |

## Evidence

Commands run from `D:\source\llama.cpp-jet`:

```powershell
cmake --build build --config Release --target test-step13-stage8 -j 4
```

Result: PASS. Built `build\bin\Release\test-step13-stage8.exe`.

```powershell
ctest --test-dir build -C Release -R test-step13-stage8 --output-on-failure
```

Result: PASS. `1/1` test passed.

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
```

Result: PASS. Built `build\bin\Release\test-cache-controller.exe`.

```powershell
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Result: PASS. `1/1` test passed.

```powershell
cmake --build build --config Release --target llama-server -j 4
```

Result: PASS. Built `build\bin\Release\llama-server.exe`.

```powershell
pytest tools/server/tests/unit/test_cache_modes.py
```

Result: FAIL before cache assertions. The Windows build lacks HTTPS support,
so preload of `ggml-org/test-model-stories260K` failed during server startup.

```powershell
$env:LLAMA_SERVER_BIN_PATH='D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe'
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
pytest tools/server/tests/unit/test_cache_modes.py
```

Result: PASS with existing expected xfail. `3 passed, 1 xfailed`.

```powershell
cmake --build build --config Release --target test-step12-branch-graph -j 4
ctest --test-dir build -C Release -R test-step12-branch-graph --output-on-failure
```

Result: PASS. `1/1` Stage 7 branch graph test passed.

## Gate state

Implementation is not ready for Architect implementation review yet. The
worktree has passing focused evidence for the forest foundation and selected
controller plumbing, but steps 8.6 through 8.8 still need controller
implementation and regression tests before the implementation gate can be
reviewed as complete.
