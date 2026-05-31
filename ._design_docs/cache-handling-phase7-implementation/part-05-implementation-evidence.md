# Stage 7 implementation evidence - Part 5

Source: [../cache-handling-phase7-implementation.md](../cache-handling-phase7-implementation.md)  
Implementation date: May 31, 2026

## Status

Implementation is in progress. This part records code and test evidence as each approved step
lands.

## Step 7.1 and 7.2: branch graph module

Changed files:

- `tools/server/server-cache-graph.h`
- `tools/server/server-cache-graph.cpp`

Behavior:

- Added `branch_node`, `namespace_key`, `validate_namespace_compatibility()`, and
  `branch_forest_index`.
- The forest tracks parent/child topology, namespace roots, token-span lookup, length-qualified
  checksum lookup, metadata RAM bytes, slot refs, active refs, peak refs, and payload eviction
  candidates.
- Payload eviction candidates are global across namespaces. Unprotected payloads sort before
  protected-root payloads, both by `use_sequence` and then `insertion_sequence`.
- `remove_node()` is limited to explicit teardown and tests. It rejects protected roots, nodes with
  slot refs, and nodes with retained children.

Evidence:

```powershell
cmake --build build --config Release --target test-step12-branch-graph -j 4
```

Result: PASS. The target built successfully.

## Step 7.3: standalone test target

Changed files:

- `tools/server/CMakeLists.txt`
- `tests/CMakeLists.txt`
- `tests/test-step12-branch-graph.cpp`

Behavior:

- Added the graph module to `server-context`.
- Added `test-step12-branch-graph` with coverage for node defaults, namespace key determinism,
  compatibility checks, lifecycle, traversal, token lookup, checksum lookup, slot refs, eviction
  ordering, protected-root ordering, and concurrent ref acquire/release.

Evidence:

```powershell
ctest --test-dir build -C Release -R test-step12-branch-graph --output-on-failure
```

Result: PASS. CTest ran 1 test and it passed in 0.02 seconds.

Coverage note:

- No line-coverage tool was run in this step. The focused test exercises all public graph APIs
  except rare invalid-construction branches.

## Steps 7.4 through 7.8: hybrid controller integration

Changed files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`

Behavior:

- Added a shared `branch_forest_index` member to `hybrid_cache_controller`.
- Saves and test admissions now create branch nodes after descriptor validation succeeds. Branch
  nodes reference existing descriptor IDs; descriptors and hot/cold payload bytes remain
  controller-owned.
- Exact lookup and best-match lookup query the forest first, then resolve back to the existing
  entry for Stage 5 descriptor validation and Stage 6 residency checks.
- Namespace validation runs before a forest-backed candidate can restore.
- Branch nodes mirror payload residency, resident bytes, target/draft presence, use sequence,
  use count, insertion sequence, and protected-root state.
- Metadata soft-limit pressure records diagnostics only. It does not remove, reparent, or prune
  graph nodes.
- Added test hooks for the internal metadata soft limit and first-node slot refs.

Evidence:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Result: PASS. CTest ran 1 test and it passed in 0.05 seconds.

## Step 7.9: metrics and diagnostics

Changed files:

- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

Behavior:

- `get_stats()` now reports branch node creation, branch token lookups, branch lookup hits,
  namespace validation pass/fail counts, metadata bytes, metadata soft max, over-limit state, and
  a `branch_forest` diagnostics object with namespace node/root/metadata counts.
- Prometheus output now includes Stage 7 branch counters and metadata gauges while keeping the
  Stage 4, Stage 5, and Stage 6 metric names.

Evidence:

```powershell
cmake --build build --config Release --target llama-server -j 4
$env:LLAMA_SERVER_BIN_PATH=(Resolve-Path build\bin\Release\llama-server.exe).Path; $env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'; pytest tools/server/tests/unit/test_cache_modes.py
```

Result: PASS. `llama-server` built successfully. Pytest reported 3 passed and 1 xfailed.

## Step 7.10: regression evidence and limitations

Cold-path regression commands:

```powershell
cmake --build build --config Release --target test-step6-demotion-protocol test-step7-promotion-protocol test-step10-metrics -j 4
ctest --test-dir build -C Release -R "test-step6-demotion-protocol|test-step7-promotion-protocol|test-step10-metrics" --output-on-failure
```

Result: PASS. CTest ran 3 tests and all passed in 6.80 seconds.

Focused Stage 7 command repeated during this session:

```powershell
ctest --test-dir build -C Release -R test-step12-branch-graph --output-on-failure
```

Result: PASS. CTest ran 1 test and it passed in 0.01 seconds.

Diff hygiene:

```powershell
git diff --check -- tests/CMakeLists.txt tests/test-cache-controller.cpp tools/server/CMakeLists.txt tools/server/server-cache-hybrid.h tools/server/server-cache-hybrid.cpp tools/server/server-context.cpp tools/server/tests/unit/test_cache_modes.py ._design_docs/cache-handling-phase7-implementation.md ._design_docs/cache-handling-phase7-implementation/part-05-implementation-evidence.md
```

Result: PASS. The scoped diff check found no whitespace errors in files changed for this session.
An unscoped `git diff --check` still reports a trailing whitespace issue in
`.github/agents/manager.agent.md`, which was already dirty and is unrelated to this task.

Coverage and sanitizer notes:

- No coverage report was generated in this environment.
- TSAN was not run. The active Windows/MSVC build tree is not configured with a ThreadSanitizer
  target. The deterministic concurrent branch-ref test ran as part of `test-step12-branch-graph`.

Implementation status:

- Stage 7 code, focused tests, server metrics shape tests, and cold-path regressions are
  implemented and passing in this workspace.
- Existing uncommitted and untracked Stage 7 docs were present before this session. This evidence
  part and the entry TOC update were added during this session.
