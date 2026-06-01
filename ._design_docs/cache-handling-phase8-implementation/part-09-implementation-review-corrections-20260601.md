# Stage 8 implementation-review corrections - 2026-06-01

Source: [../cache-handling-phase8-implementation.md](../cache-handling-phase8-implementation.md)

## Scope

This pass fixes the blocking findings from
[Part 8](part-08-architect-implementation-review-20260601.md):

- S8-IMPL-01: production restore now handles a selected metadata-only node by
  planning re-materialization and restoring from the nearest payload-bearing
  ancestor when one is available.
- S8-IMPL-02: Stage 8 counters are now emitted by `/metrics` with the labels
  required by the approved design.
- S8-IMPL-03: branch metadata admission now rejects a new node when pruning
  cannot bring metadata back under the soft limit.

## Code changes

- `tools/server/server-context.cpp`: `try_restore_from_cache()` routes
  metadata-only matches through `branch_forest_index::plan_rematerialization()`.
  Validation mismatch falls back without slot mutation. A valid plan switches
  restore to the source payload node, so later prompt replay can materialize the
  selected metadata-only node through the normal save path.
- `tools/server/server-cache-hybrid.*`: restore source selection is shared with
  the focused test hook, so the production metadata-only decision is covered
  without instantiating the private server slot type in the test binary.
- `tools/server/server-context.cpp`: Prometheus export now includes the Stage 8
  metric names with `namespace`, `reason`, `result`, `method`, `source`, or
  `action` labels.
- `tools/server/server-cache-hybrid.*`: branch admission runs metadata-budget
  enforcement after node creation and before index publication. If pruning
  cannot satisfy the budget, it removes the new node and payload, increments
  `cache_branch_metadata_admission_rejections_total`, and reports pressure.
- `tests/test-step13-stage8.cpp`: added metadata-only restore source selection,
  protected-root-only admission rejection, and active-ref-only admission
  rejection coverage.
- `tools/server/tests/unit/test_cache_modes.py`: added Prometheus metric-shape
  assertions for all Stage 8 counters and labels.

## Evidence

Commands run from `D:\source\llama.cpp-jet`:

```powershell
cmake --build build --config Release --target test-step13-stage8 -j 4
```

Result: PASS after rerun. An earlier parallel build with `llama-server` hit a
Windows object-file permission race on `server-context.obj`; the standalone
rerun built `build\bin\Release\test-step13-stage8.exe`.

```powershell
ctest --test-dir build -C Release -R test-step13-stage8 --output-on-failure
```

Result: PASS. `1/1` test passed.

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Result: PASS. Built `build\bin\Release\test-cache-controller.exe`; `1/1`
test passed.

```powershell
cmake --build build --config Release --target llama-server -j 4
```

Result: PASS. Built `build\bin\Release\llama-server.exe`.

```powershell
$env:LLAMA_SERVER_BIN_PATH='D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe'
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
pytest tools/server/tests/unit/test_cache_modes.py
```

Result: PASS with the existing expected xfail. `3 passed, 1 xfailed`.

```powershell
git diff --check
```

Result: PASS.

## Gate state

The three blocking implementation-review findings have focused code fixes and
regression evidence. Stage 8 is ready for Architect implementation re-review.
