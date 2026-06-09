# Cache handling test scripts

Location: `._design_docs/cache-handling-test-scripts/`
Last updated: 2026-06-07
Status: Active reusable integration runner

## Scope

These PowerShell scripts support the integration scenarios in [cache-handling-test-plan.md](../cache-handling-test-plan.md). They cover the reusable server harness, report creation, metrics parsing, and scripted cache checks for the current cache implementation.

The Stage 4 plan includes resident payload byte budget enforcement, deterministic LRU ordering, successful and failed restore recency behavior, equivalent-entry refresh budget enforcement, protected-root priority and fallback eviction, protected admission rejection, metrics, legacy compatibility, and reusable evidence capture.

The Stage 5 plan adds descriptor separation, hot payload ownership, descriptor validation, target/draft pair-state checks, draft runtime mode isolation, paired eviction and byte accounting, transactional rollback, empty-preimage rollback, unsupported clear preflight, Stage 5 metrics, legacy compatibility, and Stage 4 regression coverage. Most descriptor-corruption and restore-failure branches need focused controller or fault-injection evidence; public HTTP alone cannot create those preconditions.

The Stage 6 plan adds cold payload storage and asynchronous I/O. Public HTTP can cover startup validation, opt-in behavior, metrics shape, and some demotion or promotion counter changes. Cold residency transitions, queue-full paths, file corruption, and draft-side promotion failure need focused controller, cold-store, or fault-injection evidence.

The Stage 7 plan adds the branch graph foundation. Public HTTP can cover model-backed save/load regression, missing `/cache/stats`, and metric shape. Branch node lifecycle, traversal, slot refs, metadata soft-limit diagnostics, checksum candidate selection, and global cross-namespace eviction ordering rely on focused C++ evidence unless the session provides a stats-capable integration harness.

The Stage 8 plan adds metadata-only retention and re-materialization. Public HTTP can cover public surface, model-backed regression, and metrics output. Metadata-only topology, re-materialization validation, mismatch-parent selection, equivalent deduplication, cold cleanup ownership, and metadata admission rejection rely on focused Stage 8, focused controller, stats-capable, or fault-injection evidence unless a later script creates those preconditions directly.

The Stage 9 plan adds checkpoint payloads and workload profiles. Public HTTP can cover task-flow boundary propagation, model-backed checkpoint-dependent restore when a suitable SWA, recurrent, hybrid, or MTP fixture exists, and public `/metrics` shape. Workload profile namespace isolation, descriptor admission rollback, exact-first and checkpoint-first ranking, target/draft checkpoint pair validation, cold checkpoint promotion, budget eviction, cleanup ownership, and leak checks rely on focused controller, metrics, branch graph, or Stage 8 evidence unless a later script creates those preconditions directly.

The Stage 10 plan adds observability metric shapes and escaping, bounded diagnostics, cold-store hardening, startup validation, pressure and abuse checks, deterministic stress, coverage evidence, benchmark evidence, operator documentation checks, security evidence, and Stage 4-9 regression. Public HTTP can cover startup validation and live `/metrics` shape when the server can create the rows. Cold-store path hardening, queue pressure, repeated integrity failures, branch pressure, deterministic stress, and exporter escaping rely on focused C++ tests, Python startup or metric checks, coverage reports, benchmark runners, and documented fixture evidence.

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

Stage 9 Q90-Q112 scenarios are part of the plan. The main runner does not implement a dedicated Stage 9 matrix. Use it for public HTTP boundary and `/metrics` evidence when possible, then cite `test-cache-controller`, `test-step10-metrics`, `test-step12-branch-graph`, `test-step13-stage8`, and `tools/server/tests/unit/test_cache_modes.py` for focused checkpoint, metrics, graph, regression, and metric-shape evidence. Do not mark Q103 `PASS` unless the run used a checkpoint-dependent model fixture.

Stage 10 T100-T121 scenarios are part of the plan. The main runner does not implement a dedicated Stage 10 matrix. Use it for public startup, HTTP, log, and `/metrics` evidence, then cite `test-step10-metrics`, `test-stage10-cold-store-hardening`, `test-cache-controller`, demotion, promotion, fault-injection, branch graph, Stage 8, Python startup or metric tests, coverage reports, and benchmark outputs for rows that public HTTP cannot create directly. Do not mark coverage or benchmark rows `PASS` without the required tool output.

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

### `run_coverage.ps1`

OpenCppCoverage union coverage runner for the hybrid-mode denominator (T114 and T115).

Runs all 8 focused cache tests individually under OpenCppCoverage with binary
`.cov` export, then optionally runs `llama-server` with a short HTTP probe under
the same tool to cover the server integration paths in `server-cache-hybrid.cpp`.
Merges all `.cov` files with `--input_coverage` to produce a single union Cobertura
XML, then reports combined line rate against the 80% threshold.

Denominator: `server-cache-hybrid.cpp/h`, `server-cache-store-cold.cpp/h`,
`server-cache-controller.cpp/h`, `server-cache-graph.cpp/h`,
`server-cache-io-worker.cpp`, `server-cache-policy-lru.cpp`,
`server-cache-legacy.h`, and the 8 focused test `.cpp` files.
`server-context.cpp` and `server-context.h` are excluded (general dispatcher,
not hybrid-cache paths).

LLVM source-based coverage is blocked on this host: `lld-link` rejects
`-fprofile-instr-generate` as a linker flag. OpenCppCoverage is the fallback.
Branch coverage is unavailable (OpenCppCoverage reports `branch-rate=0`).

Parameters:

- `-BuildDir`: release bin parent, default `.\build`
- `-SourceRoot`: repo root, default auto-detected from script location
- `-OutDir`: output directory for `.cov` files, XML, HTML, and report
- `-ModelPath`: GGUF model for the HTTP probe (or `LLAMA_CACHE_TEST_MODEL`)
- `-OcPath`: path to `OpenCppCoverage.exe`, default `D:\app\OpenCppCoverage\OpenCppCoverage.exe`
- `-Port`: HTTP probe server port, default 8144
- `-SkipServerProbe`: omit the `llama-server` HTTP probe phase

Output files in `$OutDir`:

- `cov-binary/NN-<test>.cov` — per-test binary coverage data
- `cov-binary/server-http-probe.cov` — server integration coverage data
- `coverage-merged.xml` — merged Cobertura XML (union coverage)
- `html/` — HTML coverage report
- `coverage-report.md` — per-file line rates and 80% gate result

Run after the clean build:

```powershell
cmake --build build --config Release --target llama-server test-cache-controller test-step10-metrics test-stage10-cold-store-hardening test-step6-demotion-protocol test-step7-promotion-protocol test-step11-test-hooks-fault-injection test-step12-branch-graph test-step13-stage8 -j 4
& "._design_docs\cache-handling-test-scripts\run_coverage.ps1" -OutDir "._design_docs\.test_reports\<session-report>-artifacts"
```

The script exits 1 if the combined line rate is below 80%.

### `run_benchmark_k6.ps1`

Stage 10 k6 cache correctness benchmark runner for T116 and T117.

Uses `tools/server/tests/bench-cache-correctness.js` (standard k6, no SSE
extension required) to drive repeated `/completion` requests against a hybrid
cache server and validates that `timings.cache_n > 0` for hit iterations.

The script starts `llama-server`, sends one warmup request to seed the cache
entry, captures `/metrics` before and after, runs k6, stops the server, and
writes an evidence-summary file with T116 evidence classification.

Parameters:

- `-BuildDir`: release bin parent, default `.\build`
- `-ModelPath`: GGUF model (or `LLAMA_CACHE_TEST_MODEL`)
- `-K6Path`: path to `k6.exe`, default `D:\app\k6\k6.exe`
- `-Port`: server port, default 8142
- `-OutDir`: output directory for evidence files
- `-Iterations`: total probe iterations for k6, default 12

Evidence classes produced:

| Evidence type | Source class |
| --- | --- |
| `timings.cache_n` per response | direct stats |
| `llamacpp_cache_hits_total` delta | public Prometheus |
| `llamacpp_cache_misses_total` delta | public Prometheus |
| `cache_hit_rate` k6 Rate threshold | harness-only |
| `cache_miss_prompt_ms` vs `cache_hit_prompt_ms` | direct stats |

The k6 threshold requires at least 60% of probe iterations to report
`timings.cache_n > 0`. The script exits 1 (T117 FAIL) if this gate is not met.

Run after the clean build:

```powershell
cmake --build build --config Release --target llama-server -j 4
& "._design_docs\cache-handling-test-scripts\run_benchmark_k6.ps1" -OutDir "._design_docs\.test_reports\<session-report>-artifacts"
```

### `stress_tests.ps1`

Runs long duration stress scenarios separately:

- S01 memory pressure
- S02 high concurrency
- S03 eviction churn
- S04 long-running stability

Run stress tests only when the session explicitly includes stress coverage.

## Stage 12 stress and benchmark scripts

Stage 12 stress, benchmark, and long-run drivers live in
`stress/`, `bench/`, and `longrun/` subdirectories under this test
scripts directory. The drivers write per-run evidence into
`._design_docs/.test_reports/stress-s12-<id>-<timestamp>/`,
`bench-s12-<id>-<timestamp>/`, or `longrun-s12-<id>-<timestamp>/`.
Each evidence dir has a template README that documents its layout.

Evidence helpers live in `lib/`:

- `Write-StressEvidence.ps1` writes per-scenario stress summary
- `Write-BenchEvidence.ps1` writes per-row benchmark summary
- `Write-LongrunEvidence.ps1` writes per-run long-run summary
- `Read-BaselineJson.ps1` reads baseline.json into a hashtable
- `Write-TuningReport.ps1` writes the seven-section tuning skeleton

`apply_config_matrix.ps1` reads a JSON matrix file and resolves it
into a run-config JSON that benchmark and stress drivers can consume.
The matrix dimensions are the ten from design part-02: cache mode,
hot budget, cold path, slot count, model size, context length, draft
presence, workload profile, prompt mix, and run length.

Stage 12 stress drivers (`stress/stress_s12_s01..s08_*.ps1`):

- S12-S01 budget exhaustion
- S12-S02 concurrent multi-slot (supersedes stress_tests.ps1 S02 for Stage 12)
- S12-S03 large branch forests
- S12-S04 prompt storms
- S12-S05 mixed workload profiles
- S12-S06 cold queue pressure
- S12-S07 protected-root pressure
- S12-S08 integrity failure under load

Stage 12 benchmark drivers (`bench/bench_s12_b01..b08_*.ps1`):

- S12-B01 exact-blob hit rate (k6 path)
- S12-B02 checkpoint hit rate (chat-completions path; marked Jinja enables `emit_cache_boundaries`)
- S12-B03 cold transition frequency
- S12-B04 end-to-end token throughput
- S12-B05 restore latency
- S12-B06 prompt-storm efficiency (k6 path)
- S12-B07 mixed-profile comparison
- S12-B08 large-forest lookup cost

Stage 12 long-run drivers (`longrun/longrun_s12_l01..l03_*.ps1`):

- S12-L01 production-like hybrid 6 hour (60 s sampler, 30 min snapshot)
- S12-L02 reproducibility 30 minute (30 s sampler, 10 min snapshot)
- S12-L03 legacy control 2 hour (60 s sampler, 30 min snapshot)

All drivers use `--DryRun` to print the planned flags, ports, and
fixture list without starting a server. They emit STUB evidence and
record `Verdict: BLOCKED` when a model fixture or required tool
(k6, focused fault-injection binary) is missing. STUB rows are not
counted as PASS for closure. Per design part-04, draft and MTP rows
are out of required scope (cap-fix closure PASS 2026-06-07;
Manager plan keeps draft and MTP rows out of scope).

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

For Stage 9 planning or execution sessions, use the focused `ctest` and Python commands in Part 11. Do not use `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` for rows that claim model-backed checkpoint save, restore, hit, miss, promotion, demotion, eviction, or boundary propagation.

For Stage 10 planning or execution sessions, use the focused `ctest`, Python, coverage, and benchmark commands in Part 12. Do not use `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` for rows that claim model-backed cache save, restore, hit, miss, promotion, demotion, eviction, boundary propagation, checkpoint behavior, coverage, or benchmark acceptance.

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

For Stage 9 cases, also capture evidence source, workload profile, namespace or fixture identity, selected payload kind, descriptor validation result, pair state, boundary source or degraded fallback reason, cold residency transition, metrics labels, public `/metrics` scrape when available, and explicit fixture search result for checkpoint-dependent model-backed rows.

For Stage 10 cases, also capture evidence source, metric label names and values, escaping proof, bounded diagnostic fields, cold-store root setup without leaking local paths in public summaries, startup validation reason, pressure inputs, deterministic seams, OWASP classification, coverage tool output, benchmark evidence source, operator documentation files checked, and Stage 4-9 regression evidence.
## Maintenance

When cache behavior changes:
1. Update the relevant test matrix rows in the plan.
2. Update the scripts only for behavior the harness can verify directly.
3. Keep report naming generic and per-session.
4. Keep clean-build checks strict.
5. Remove obsolete scenarios instead of hiding them behind exclusions.
6. Avoid timing-only assertions. Prefer metrics, response fields, and log evidence. Use `--log-verbosity 5` for tests that inspect diagnostics.
