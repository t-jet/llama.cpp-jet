# Phase 4 implementation: review fixes

Source: [../cache-handling-phase4-implementation.md](../cache-handling-phase4-implementation.md)

## Status

Fix date: May 27, 2026  
Fix state: ready for implementation re-review

This part tracks the correction loop for the independent implementation review in [Part 5](part-05-independent-implementation-review.md).

## Corrective actions

1. Make equivalent-entry refresh in `hybrid_cache_controller::save_slot()` run byte-budget enforcement after the refresh.
2. Count each protected eviction as a protected-root decision while keeping `n_protected_root_evictions` as the specific eviction count.
3. Add focused controller tests for refresh-triggered budget enforcement and multiple protected evictions.
4. Rebuild and rerun the focused cache controller test target, then record the evidence here and in the implementation evidence part.

## Progress

Started from a dirty worktree. The Phase 4 code, Phase 4 docs, document index, and self-improvement memory files already had uncommitted changes before this correction pass.

Planned code paths:

- `tools/server/server-context.cpp`: route equivalent-entry refresh through budget enforcement.
- `tools/server/server-cache-hybrid.h`: add test-accessible helpers for refresh and budget adjustment.
- `tools/server/server-cache-hybrid.cpp`: share refresh logic with `save_slot()` and count protected eviction decisions.
- `tests/test-cache-controller.cpp`: add the two review-requested regression tests.

Completed code changes:

- Added a shared `refresh_existing_entry()` path in `hybrid_cache_controller`.
- Updated `save_slot()` equivalent-entry refresh to call that shared path, which refreshes recency, updates protection, and runs `evict_until_within_budget()`.
- Counted each protected eviction as a protected-root decision before incrementing `n_protected_root_evictions`.
- Added test-only helpers for refresh and budget adjustment so controller tests can model an over-budget state after a budget change.
- Added controller regressions for refresh-triggered budget enforcement and multiple protected evictions.

## Evidence

Commands run from `d:\source\llama.cpp-jet`:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
```

Outcome: passed. Built `build\bin\Release\test-cache-controller.exe`.

```powershell
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Outcome: passed. `1/1` selected test passed in `0.03 sec`.

```powershell
cmake --build build --config Release --target llama-server -j 4
```

Outcome: passed. Built `build\bin\Release\llama-server.exe`.

```powershell
$env:LLAMA_SERVER_BIN_PATH='D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe'
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
pytest tools/server/tests/unit/test_cache_modes.py
```

Outcome: passed with existing expected xfail. Result: `2 passed, 1 xfailed in 4.17s`. Pytest emitted existing dependency and asyncio fixture-scope warnings.

## Remaining risks

- No coverage report was generated. Evidence is focused build and regression-test coverage.
- The Python cache-mode suite still has its existing expected xfail.
- The refresh budget regression uses test-only helpers because `server_slot` is private to `server-context.cpp`.

## Handoff

State: ready for implementation re-review.

Next owner: architect. Re-review should check that `save_slot()` refresh now runs budget enforcement and that protected eviction decisions are visible through JSON stats and the Prometheus counter source.
