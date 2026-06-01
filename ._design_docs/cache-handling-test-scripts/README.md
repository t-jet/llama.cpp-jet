# Cache handling test scripts

Location: `._design_docs/cache-handling-test-scripts/`
Last updated: 2026-06-01
Status: Active reusable integration runner

## Scope

These PowerShell scripts support the integration scenarios in [cache-handling-test-plan.md](../cache-handling-test-plan.md). They cover the reusable server harness, report creation, metrics parsing, and scripted cache checks for the current cache implementation.

The Stage 4 plan includes resident payload byte budget enforcement, deterministic LRU ordering, successful and failed restore recency behavior, equivalent-entry refresh budget enforcement, protected-root priority and fallback eviction, protected admission rejection, metrics, legacy compatibility, and reusable evidence capture.

The Stage 5 plan adds descriptor separation, hot payload ownership, descriptor validation, target/draft pair-state checks, draft runtime mode isolation, paired eviction and byte accounting, transactional rollback, empty-preimage rollback, unsupported clear preflight, Stage 5 metrics, legacy compatibility, and Stage 4 regression coverage. Most descriptor-corruption and restore-failure branches need focused controller or fault-injection evidence; public HTTP alone cannot create those preconditions.

The Stage 6 plan adds cold payload storage and asynchronous I/O. Public HTTP can cover startup validation, opt-in behavior, metrics shape, and some demotion or promotion counter changes. Cold residency transitions, queue-full paths, file corruption, and draft-side promotion failure need focused controller, cold-store, or fault-injection evidence.

The Stage 7 plan adds the branch graph foundation. Public HTTP can cover model-backed save/load regression, missing `/cache/stats`, and metric shape. Branch node lifecycle, traversal, slot refs, metadata soft-limit diagnostics, checksum candidate selection, and global cross-namespace eviction ordering rely on focused C++ evidence unless the session provides a stats-capable integration harness.

The Stage 8 plan adds metadata-only retention and re-materialization. Public HTTP can cover public surface, model-backed regression, and metrics output. Metadata-only topology, re-materialization validation, mismatch-parent selection, equivalent deduplication, cold cleanup ownership, and metadata admission rejection rely on focused Stage 8, focused controller, stats-capable, or fault-injection evidence unless a later script creates those preconditions directly.

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

`Get-CacheMetrics` parses `llamacpp_cache_*` Prometheus metrics, including:

- `llamacpp_cache_entries`
- `llamacpp_cache_bytes`
- `llamacpp_cache_tokens`
- `llamacpp_cache_hits_total`
- `llamacpp_cache_misses_total`
- `llamacpp_cache_evictions_total`
- `llamacpp_cache_payload_evictions_total`
- `llamacpp_cache_protected_root_decisions_total`
- `llamacpp_cache_restore_failures_total`
- `llamacpp_cache_descriptor_validation_failures_total`
- `llamacpp_cache_pairing_violations_total`
- `llamacpp_cache_fallback_restores_total`
- `llamacpp_cache_hot_payload_descriptors`
- `llamacpp_cache_evicted_payload_descriptors`

Stage 8 metric rows should capture the raw `/metrics` response or use the Python metric-shape test until the PowerShell parser is extended for the `cache_*` Stage 8 metric family listed in the Stage 8 plan.

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
- D-series draft-model probes when the local target and draft fixtures exist, with `BLOCKED` rows for draft scenarios that public HTTP cannot prove

Stage 4 H30-H39 scenarios are part of the plan. The main runner does not implement the full H30-H39 matrix. Some budget, protected-root, equivalent-refresh, and failed-restore recency branches still need focused harness support, focused C++ controller evidence, or stats-capable evidence. Do not mark them `PASS` from scripts that only prove requests completed.

Stage 5 H40-H58 scenarios are part of the plan. The main runner does not implement the full Stage 5 descriptor, draft runtime mode, and transactional restore matrix. Normal target-only HTTP save/restore, metrics shape, legacy compatibility, and public surface checks are script-friendly. Descriptor version or kind corruption, checksum or size mismatch, owner/store-ref mismatch, non-hot or cold residency, pair-state/runtime mismatch, cross-mode draft namespace isolation, target/draft apply failures, empty-preimage rollback, and unsupported clear preflight require focused controller tests, cross-run cache persistence, or another fault-injection harness.

Stage 7 G70-G89 scenarios are part of the plan. The main runner does not implement a dedicated Stage 7 matrix. Use it for public HTTP regression and metrics evidence, then cite `test-step12-branch-graph`, `test-cache-controller`, and `tools/server/tests/unit/test_cache_modes.py` for focused graph and metric-shape evidence. Do not mark graph-internal rows `PASS` from public requests alone.

Stage 8 S80-S99 scenarios are part of the plan. The main runner does not implement a dedicated Stage 8 matrix. Use it for public HTTP regression and metrics evidence, then cite `test-step13-stage8`, `test-cache-controller`, and `tools/server/tests/unit/test_cache_modes.py` for focused graph, controller, and metric-shape evidence. Do not mark metadata-only or re-materialization rows `PASS` from metric presence alone.

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
cmake --build build --config Release --target test-step12-branch-graph -j 4
cmake --build build --config Release --target test-step13-stage8 -j 4

$Binary = Get-Item build\bin\Release\llama-server.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    throw "llama-server.exe is stale. Rebuild before testing."
}
```

The runner repeats the timestamp check before it starts tests.

For Stage 7 planning or execution sessions, focused checks use:

```powershell
ctest --test-dir build -C Release -R "test-step12-branch-graph|test-cache-controller" --output-on-failure
$env:LLAMA_SERVER_BIN_PATH=(Resolve-Path build\bin\Release\llama-server.exe).Path
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
pytest tools/server/tests/unit/test_cache_modes.py
```

For Stage 8 planning or execution sessions, focused checks use:

```powershell
ctest --test-dir build -C Release -R "test-step13-stage8|test-cache-controller" --output-on-failure
$env:LLAMA_SERVER_BIN_PATH=(Resolve-Path build\bin\Release\llama-server.exe).Path
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
pytest tools/server/tests/unit/test_cache_modes.py
```

`LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` is a Windows workaround for Python startup and metric-shape checks. Do not use it as evidence for model-backed save, restore, hit, miss, eviction, or re-materialization behavior.

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

Local Qwen3 draft-mode fixture paths used by `execute_tests.ps1` when present:

```powershell
$TargetModel = "D:\source\llama.cpp-jet\._test_models\Qwen3-8B-GGUF\Qwen3-8B-Q6_K.gguf"
$DraftModel  = "D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf"
```

The main runner uses Qwen3-8B as the D-series target, Qwen3-0.6B as the separate draft model, and `--spec-type draft-simple` unless `LLAMA_CACHE_TEST_TARGET_MODEL` or `LLAMA_CACHE_TEST_DRAFT_MODEL` overrides those paths. Rows that need partial-save fault injection or cross-draft namespace introspection report `BLOCKED` instead of `SKIP` when the public harness cannot prove them.

For manual model-backed probes, use Qwen3-8B as `--model` and Qwen3-0.6B as the separate draft model:

```powershell
& ".\build\bin\Release\llama-server.exe" `
  --model $TargetModel `
  --model-draft $DraftModel `
  --spec-type draft-simple `
  --cache-mode hybrid `
  --ctx-size 512 `
  --parallel 2 `
  --cont-batching `
  --kv-unified `
  --cache-ram 100 `
  --temp 0 `
  --seed 42 `
  --metrics `
  --log-verbosity 5
```

Repeat the same normal separate draft coverage with `--spec-draft-model $DraftModel`; the alias spelling should not change the cache namespace. For MTP probes, add `--spec-type draft-mtp` only after the selected model or model pair is known to support that runtime. If an in-scope public MTP row cannot create an MTP draft context, report it as `BLOCKED` with the startup log.

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
--model-draft FNAME    # alias of --spec-draft-model for separate draft model
--spec-type draft-mtp  # MTP draft context when supported by the model/runtime
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

For Stage 5 cases, also capture:

- descriptor validation and fallback metrics before and after the operation
- pair-state and runtime shape used by the test
- target and draft payload byte accounting when a draft model or focused harness is used
- hot and evicted descriptor counts
- whether evidence came from public HTTP, focused controller tests, or fault injection
- proof that failed restore did not report a hit or refresh recency
- empty-preimage rollback or unsupported clear preflight evidence when those rows are in scope

For Stage 7 cases, also capture:

- evidence source for each row: public HTTP, focused graph test, focused controller test, Python metric-shape test, or stats-capable harness
- branch namespace IDs or fixture names used for same-namespace and cross-namespace assertions
- slot-ref acquire/release sequence and whether active refs blocked eviction candidates
- branch metadata bytes, metadata soft max, and over-limit state for soft-limit rows
- lookup method evidence for token-span and checksum-span candidate selection
- payload budget, measured payload size, and global candidate ordering for cross-namespace LRU rows
- Stage 7 metric names and labels from `/metrics` when public observability is in scope

For Stage 8 cases, also capture evidence source, selected metadata-only node, restore source, validation result, fallback reason, token sequences, namespace IDs, candidate order, mismatch-parent choice, canonical node identity, descriptor ownership, cold references, and Stage 8 metric names and labels when public observability is in scope.

## Maintenance

When cache behavior changes:

1. Update the relevant test matrix rows in the plan.
2. Update the scripts only for behavior the harness can verify directly.
3. Keep report naming generic and per-session.
4. Keep clean-build checks strict.
5. Remove obsolete scenarios instead of hiding them behind exclusions.

Avoid timing-only assertions. Prefer metrics, response fields, and log evidence. Use `--log-verbosity 5` for tests that inspect diagnostics.
