# Cache handling test scripts

Location: `._design_docs/cache-handling-test-scripts/`  
Last updated: 2026-05-27  
Status: Active reusable integration runner

## Scope

These PowerShell scripts support the integration scenarios in [cache-handling-test-plan.md](../cache-handling-test-plan.md). They cover the reusable server harness, report creation, metrics parsing, and scripted cache checks for the current cache implementation.

The Stage 4 plan now includes resident payload byte budget enforcement, deterministic LRU ordering, successful and failed restore recency behavior, equivalent-entry refresh budget enforcement, protected-root priority and fallback eviction, protected admission rejection, metrics, legacy compatibility, and reusable evidence capture.

## Scripts

### `run_cache_integration.ps1`

Helper module used by execution scripts.

Parameters:

- `-BuildDir`: build directory, default `build`
- `-Model`: GGUF model path
- `-StartPort`: first port to try, default `8120`

If `-Model` is not provided, the helper uses `LLAMA_CACHE_TEST_MODEL` when set, then falls back to the local Qwen test model path.

Main helpers:

- `Get-FreePort`
- `Start-LlamaServer`
- `Wait-ForServer`
- `Stop-LlamaServer`
- `Invoke-Test`
- `Get-LogField`
- `Get-CacheMetrics`
- `Invoke-ParallelRequests`

`Get-CacheMetrics` parses existing and Stage 4 Prometheus cache metrics, including:

- `llamacpp_cache_entries`
- `llamacpp_cache_bytes`
- `llamacpp_cache_tokens`
- `llamacpp_cache_hits_total`
- `llamacpp_cache_misses_total`
- `llamacpp_cache_evictions_total`
- `llamacpp_cache_payload_evictions_total`
- `llamacpp_cache_protected_root_decisions_total`
- `llamacpp_cache_restore_failures_total`

### `execute_tests.ps1`

Main integration runner. It starts a fresh `llama-server` for each test, writes per-test logs under `._test_output/cache-handling/<timestamp>/`, and creates the next available report:

```text
._design_docs/.test_reports/test-report-YYYYMMDD-NN.md
```

The runner refuses to start if `llama-server.exe` is missing or older than 10 minutes. A stale binary invalidates the session.

Implemented scripted categories include:

- R-series regression checks
- C-series mode, endpoint, concurrency, and metrics checks
- B-series boundary metadata checks
- H-series hybrid cache checks through existing eviction and namespace scenarios
- N-series negative checks where the harness can exercise them
- D-series draft-model placeholders where a draft model is not configured

Stage 4 H30-H39 scenarios are part of the plan. The main runner does not implement the full H30-H39 matrix. Some budget, protected-root, equivalent-refresh, and failed-restore recency branches still need focused harness support, focused C++ controller evidence, or stats-capable evidence. Do not mark them `PASS` from scripts that only prove requests completed.

### `run_stage4_h30_h37.ps1`

Focused Stage 4 H30-H37 evidence rerun. It starts a fresh server for executable public HTTP rows, records explicit `PASS`, `FAIL`, `SKIP`, or `BLOCKED` outcomes, and writes the next available report under `._design_docs/.test_reports/`. Rows that lack a public precondition use accepted focused controller evidence when available, otherwise they report `BLOCKED` without starting a server.

H31 and H32 use two evidence sources. The public HTTP sequence must prove the pre-pressure restore with `timings.cache_n > 0`. The focused controller binary then supplies entry-state evidence for the eviction order, so verification probes do not create the proof they are trying to measure.

Use it after the clean build step when closing Stage 4 evidence gaps:

```powershell
cmake --build build --config Release --target llama-server -j 4
cmake --build build --config Release --target test-cache-controller -j 4
& "._design_docs\cache-handling-test-scripts\run_stage4_h30_h37.ps1"
```

H31 and H32 only pass when the runner proves the restore precondition with `timings.cache_n > 0` before applying eviction pressure.

H33 uses focused controller evidence when `test-cache-controller.exe` includes `hybrid failed restore does not refresh recency`. Public HTTP still cannot force a cache restore deserialization failure after lookup.

H35 and H36 require trusted protected entries. Public chat requests with degraded rendered-text metadata are not enough. Use a stats-capable harness or focused C++ controller stats, or report `BLOCKED`.

H37 uses focused controller evidence when `test-cache-controller.exe` includes `hybrid protected admission rejection stats`. HTTP/parser rejection before admission is `BLOCKED`, not protected admission evidence.

### `stress_tests.ps1`

Runs long duration stress scenarios separately:

- S01 memory pressure
- S02 high concurrency
- S03 eviction churn
- S04 long-running stability

Run stress tests only when the session explicitly includes stress coverage.

## Clean build requirement

Before each execution session:

```powershell
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target llama-server -j 4
cmake --build build --config Release --target test-cache-controller -j 4

$Binary = Get-Item build\bin\Release\llama-server.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    throw "llama-server.exe is stale. Rebuild before testing."
}
```

The runner repeats the timestamp check before it starts tests.

## Usage

Run the integration suite:

```powershell
cd d:\source\llama.cpp-jet
& "._design_docs\cache-handling-test-scripts\execute_tests.ps1"
```

Use a different model:

```powershell
$env:LLAMA_CACHE_TEST_MODEL = "D:\models\test-model.gguf"
& "._design_docs\cache-handling-test-scripts\execute_tests.ps1"
```

Run stress tests:

```powershell
& "._design_docs\cache-handling-test-scripts\stress_tests.ps1" -IncludeS01
& "._design_docs\cache-handling-test-scripts\stress_tests.ps1" -All
```

## Important flags

```powershell
--cache-mode legacy    # default-compatible cache path
--cache-mode hybrid    # hybrid cache path
--cache-ram N          # integer MiB budget, -1 unlimited, 0 disabled
--metrics              # enables /metrics
--temp 0               # deterministic sampling
--seed 42              # fixed seed
--ctx-size 512         # small test context
--log-verbosity 5      # debug logging
```

`--cache-ram` uses integer MiB values. Do not write fractional values such as `0.5`; the argument parser accepts an integer.

## Evidence expectations

Every execution report must include:

- clean build evidence and binary timestamp
- git commit or dirty working-tree status
- server command line
- model path
- HTTP request and response evidence
- metrics snapshots before and after cache operations
- log excerpts for save, restore, eviction, protected-root, and failure paths
- final `PASS`, `FAIL`, `SKIP`, and `BLOCKED` counts

For Stage 4 cases, also capture:

- measured entry size
- chosen `--cache-ram` budget and why it should trigger pressure
- operation order used to prove LRU recency
- successful-restore versus failed-restore distinction
- payload eviction metrics
- protected-root decision metrics or stats-capable harness evidence
- legacy mode compatibility evidence when applicable

## Maintenance

When cache behavior changes:

1. Update the relevant test matrix rows in the plan.
2. Update the scripts only for behavior the harness can verify directly.
3. Keep report naming generic and per-session.
4. Keep clean-build checks strict.
5. Remove obsolete scenarios instead of hiding them behind exclusions.

Avoid timing-only assertions. Prefer metrics, response fields, and log evidence. Use `--log-verbosity 5` for tests that inspect diagnostics.
