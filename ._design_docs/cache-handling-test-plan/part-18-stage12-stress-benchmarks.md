# Cache handling test plan - Part 18: Stage 12 stress and benchmarks

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## 1. Scope

Stage 12 validates hybrid mode under sustained load and measures
end-to-end performance against the legacy path. Cap-fix closure PASS
2026-06-07 per
[part-29](../cache-handling-phase11-implementation/part-29-cap-fix-closure-decision.md).
This part covers 8 stress rows, 8 benchmark rows, 3 long-run rows, the
configuration matrix that joins them, evidence format, observability,
regression coverage, fixture gating, and out-of-scope decisions. No
new behavior, public endpoint, metric, or CLI flag is in scope.

Design and implementation references:

- [cache-handling-phase12-design.md](../cache-handling-phase12-design.md)
- [part-01 scope](../cache-handling-phase12-design/part-01-scope-prerequisites-interfaces.md)
- [part-02 stress and config matrix](../cache-handling-phase12-design/part-02-stress-scenarios-and-config-matrix.md)
- [part-03 benchmarks and legacy](../cache-handling-phase12-design/part-03-benchmarks-baselines-and-legacy.md)
- [part-04 observability and evidence](../cache-handling-phase12-design/part-04-observability-testability-traceability.md)
- [impl part-01 implementation plan](../cache-handling-phase12-implementation/part-01-implementation-plan.md)
- [impl part-03 implementation log](../cache-handling-phase12-implementation/part-03-implementation.md)
- [impl part-05 fixture requirements](../cache-handling-phase12-implementation/part-05-fixture-requirements.md)
- [impl part-06 implementation review](../cache-handling-phase12-implementation/part-06-implementation-review.md)

## 2. Clean build requirement

Reference cap-fix baseline (locked by part-29):
`build-cov` with `BUILD_SHARED_LIBS=OFF`, `/Zi /Ob1 /O2 /EHsc`,
`/DEBUG:FULL`, `GGML_CUDA=OFF`. Release binaries only; Debug is not
used for stress or benchmark runs. VS18 2026 generator per
build-cov cache (matching toolset; the user-supplied VS17 2022
reconfigure would have wiped the cache).

```powershell
Remove-Item -Recurse -Force build-cov -ErrorAction SilentlyContinue
cmake -B build-cov -S . -G "Visual Studio 18 2026" -A x64 `
  -DCMAKE_BUILD_TYPE=Release `
  -DBUILD_SHARED_LIBS=OFF `
  -DGGML_CUDA=OFF `
  -DCMAKE_CXX_FLAGS_RELEASE="/Zi /Ob1 /O2 /EHsc" `
  -DCMAKE_EXE_LINKER_FLAGS_RELEASE="/DEBUG:FULL"
cmake --build build-cov --config Release -j --target `
  llama-server `
  test-cache-controller `
  test-step10-metrics `
  test-stage10-cold-store-hardening `
  test-step6-demotion-protocol `
  test-step7-promotion-protocol `
  test-step11-test-hooks-fault-injection `
  test-step12-branch-graph `
  test-step13-stage8

$Binary = Get-Item build-cov\bin\Release\llama-server.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    throw "llama-server.exe is stale. Run the clean build again."
}
```

`build-cov\bin\Release` must be a real directory, not a Windows
reparse point, for OpenCppCoverage module resolution. If a future
reconfigure recreates the junction, remove it with
`cmd /c rmdir build-cov\bin\Release` and re-link.

## 3. Stress rows (8)

All rows start from the cap-fix build, use the evidence dir template
under `._design_docs/.test_reports/stress-s12-template/`, and write
`server.out.log`, `server.err.log`,
`metrics-{before,during,after}.txt`, `resource-samples.csv`, and
`evidence-summary.md`. S12-S08 also writes `precondition.log`.

| ID | Script | Fixture | Required config | Pass criterion | Evidence dir | BLOCKED rule |
| --- | --- | --- | --- | --- | --- | --- |
| S12-S01 | `stress/stress_s12_s01_budget_exhaustion.ps1` | Qwen3-0.6B-Q8_0 | hybrid, `--cache-ram 2 --parallel 2 --metrics`, cold on/off variants | requests complete, payload bytes bounded after legal evictions, eviction counters increase, no crash, no corrupt restore | `stress-run-YYYYMMDD-NN/S12-S01/<variant>/` | none (fixture present) |
| S12-S02 | `stress/stress_s12_s02_concurrent_multi_slot.ps1` | Qwen3-0.6B-Q8_0 | hybrid, `--parallel 4` and `--parallel 8` | no deadlock, hit/miss totals match request totals, no cross-slot state corruption | `stress-run-YYYYMMDD-NN/S12-S02-parallel{N}/` | `--parallel 8` BLOCKED if host cannot start (memory or model headroom) |
| S12-S03 | `stress/stress_s12_s03_large_branch_forests.ps1` | Qwen3-0.6B-Q8_0 | hybrid, `--cache-ram 50 --parallel 2`, fixed-seed prefix generator | branch metadata bounded, pruning and metadata-only retention counters move, no invalid cross-namespace restore | `stress-run-YYYYMMDD-NN/S12-S03/` | none (fixture present) |
| S12-S04 | `stress/stress_s12_s04_prompt_storms.ps1` | Qwen3-0.6B-Q8_0 | hybrid, `--cache-ram 100 --parallel 4`, near-duplicate and exact-repeat mix | server responsive, diagnostics bounded, hit rate reflects repeat mix, no unbounded log or label growth | `stress-run-YYYYMMDD-NN/S12-S04/` | none (fixture present) |
| S12-S05 | `stress/stress_s12_s05_mixed_workload_profiles.ps1` | plain Qwen3-0.6B; target-plus-draft Qwen3-8B plus Qwen3-0.6B | per-profile hybrid flags; `--parallel 1` plain, `--parallel 1 --model-draft <draft>` target-plus-draft | namespace separation holds, profile strategy follows Stage 9 rules, unsupported shapes fail explicitly or fall back safely | `stress-run-YYYYMMDD-NN/S12-S05-<profile>/` | checkpoint-dependent profile BLOCKED if Qwen3-8B fails checkpoint admission at in-scope `--ctx-size` |
| S12-S06 | `stress/stress_s12_s06_cold_queue_pressure.ps1` | Qwen3-0.6B-Q8_0 | hybrid, `--cache-ram 16 --cache-cold-path <temp_root> --parallel 2` | demotion and promotion fall back safely on queue pressure, async miss visible, no partial paired transition | `stress-run-YYYYMMDD-NN/S12-S06/` | BLOCKED if cold-store path cannot be created or written under `%TEMP%` |
| S12-S07 | `stress/stress_s12_s07_protected_root_pressure.ps1` | Qwen3-0.6B-Q8_0 | hybrid, `--cache-ram 8 --parallel 2`, large protected roots plus budget pressure | protected roots get higher retention but do not bypass byte accounting, oversize protected entries fail explicitly | `stress-run-YYYYMMDD-NN/S12-S07/` | none (fixture present) |
| S12-S08 | `stress/stress_s12_s08_integrity_failure_under_load.ps1` | Qwen3-0.6B-Q8_0 | hybrid, `--cache-ram 50 --parallel 2`, precondition seeded by `test-step11-test-hooks-fault-injection.exe` then live load | descriptor and cold-store failures reject before live mutation, bounded diagnostics record failure, load continues safely | `stress-run-YYYYMMDD-NN/S12-S08/` | BLOCKED if focused fault-injection binary missing; driver falls back to STUB |

## 4. Benchmark rows (8)

All rows use the evidence dir template under
`._design_docs/.test_reports/bench-s12-template/` and write
`server.out.log`, `server.err.log`, `metrics-{before,during,after}.txt`,
`baseline.json`, and `evidence-summary.md`. B01 and B06 also write
`k6-results.json` and `k6-stdout.txt`. Rows with a mandatory legacy
comparison also write `legacy-baseline.json`. B05 and B08 have no
hybrid-equivalent legacy path; see section 13 for the
S12-PLAN-01 nearest-legacy rows.

| ID | Script | Fixture | Required config | Pass criterion | Evidence dir | Legacy comparison |
| --- | --- | --- | --- | --- | --- | --- |
| S12-B01 | `bench/bench_s12_b01_exact_blob_hit_rate.ps1` | Qwen3-0.6B-Q8_0 | hybrid k6; legacy k6 at same flags minus `--cache-mode hybrid` | hybrid records measurable exact hits and no correctness regression | `benchmark-run-YYYYMMDD-NN/S12-B01/<row>/` | mandatory legacy row |
| S12-B02 | `bench/bench_s12_b02_checkpoint_hit_rate.ps1` | Qwen3-8B + draft Qwen3-0.6B | hybrid checkpoint profile; legacy checkpoint profile | hybrid records checkpoint activity for capable profiles | `benchmark-run-YYYYMMDD-NN/S12-B02/<row>/` | mandatory legacy row |
| S12-B03 | `bench/bench_s12_b03_cold_transition_frequency.ps1` | Qwen3-0.6B-Q8_0 | hybrid with `--cache-cold-path`; legacy without | transitions bounded, paired, explained by hot-budget pressure | `benchmark-run-YYYYMMDD-NN/S12-B03/<row>/` | mandatory legacy row (cold disabled in legacy) |
| S12-B04 | `bench/bench_s12_b04_end_to_end_token_throughput.ps1` | Qwen3-0.6B-Q8_0 | hybrid and legacy at matched slot, ctx, prompt mix | hybrid shows measurable gain on at least one target workload, no unexplained legacy regression | `benchmark-run-YYYYMMDD-NN/S12-B04/<row>/` | mandatory legacy row; gain form is throughput or latency |
| S12-B05 | `bench/bench_s12_b05_restore_latency.ps1` | Qwen3-0.6B-Q8_0 | hybrid only, captures p50/p95/p99 by payload kind and residency | restore latency recorded with correctness evidence, no unbounded tail growth | `benchmark-run-YYYYMMDD-NN/S12-B05/<row>/` | legacy N/A (no hybrid restore path); add nearest legacy throughput/latency per section 13 |
| S12-B06 | `bench/bench_s12_b06_prompt_storm_efficiency.ps1` | Qwen3-0.6B-Q8_0 | hybrid k6; legacy k6 under high repeat pressure | hybrid improves repeat-heavy workload or records bottleneck cause | `benchmark-run-YYYYMMDD-NN/S12-B06/<row>/` | mandatory legacy row |
| S12-B07 | `bench/bench_s12_b07_mixed_profile_comparison.ps1` | plain Qwen3-0.6B; target-plus-draft Qwen3-8B + Qwen3-0.6B; checkpoint Qwen3-8B | profile-by-profile hybrid and legacy | plain-transformer and checkpoint-dependent rows follow Stage 9 strategy | `benchmark-run-YYYYMMDD-NN/S12-B07/<profile>/` | profile-by-profile legacy where fixture supports |
| S12-B08 | `bench/bench_s12_b08_large_forest_lookup_cost.ps1` | Qwen3-0.6B-Q8_0 | hybrid only, captures request latency as forest grows | lookup cost bounded enough for operator use, or bottleneck documented | `benchmark-run-YYYYMMDD-NN/S12-B08/<row>/` | legacy N/A (no forest lookup path); add nearest legacy throughput/latency per section 13 |

## 5. Long-run rows (3)

| ID | Script | Duration | Sampler interval | Snapshot marker | Evidence dir |
| --- | --- | --- | --- | --- | --- |
| S12-L01 | `longrun/longrun_s12_l01_6h_hybrid_stability.ps1` | 6 h | 60 s | 30 min partial-snapshot copy | `longrun-run-YYYYMMDD-NN/S12-L01/` |
| S12-L02 | `longrun/longrun_s12_l02_30m_legacy_comparison.ps1` | 30 min | 30 s | 10 min partial-snapshot copy | `longrun-run-YYYYMMDD-NN/S12-L02/` |
| S12-L03 | `longrun/longrun_s12_l03_2h_mixed_workload.ps1` | 2 h | 60 s | 30 min partial-snapshot copy | `longrun-run-YYYYMMDD-NN/S12-L03/` |

## 6. Configuration matrix

Ten dimensions from design part 02. Each required value must appear
in at least one stress or benchmark row; omitted values need a
Manager-approved reason before execution opens.

| Dim | Required values | Notes |
| --- | --- | --- |
| Cache mode | legacy, hybrid | legacy is the control for comparison and regression |
| Hot budget | small, medium, large | integer MiB only; small forces eviction, medium retains working set, large avoids ordinary eviction |
| Cold path | off, on | cold-on rows use a safe temporary root with enough disk space |
| Slot count | 1, 2, 4, 8 | `--parallel 8` BLOCKED if host cannot start |
| Model size | small (Qwen3-0.6B), larger (Qwen3-8B) when fixture available | record quantization and context support |
| Context length | short, medium, near configured limit | near-limit rows must not exceed server safety checks |
| Draft presence | none (in-scope rows); separate draft and MTP only after Manager narrowing | draft/MTP held out per cap-fix closure |
| Workload profile | plain-transformer, checkpoint-dependent, target-plus-draft | profile must be confirmed by fixture capability or focused preflight |
| Prompt mix | exact repeats, near duplicates, unique prompts, long prefixes | store generator seed and class, not prompt text |
| Run length | 30 min, 2 h, 6 h | 6 h is the production-like long-run check |

## 7. Evidence format

Per-scenario stress evidence directory (from impl part-01):

```text
._design_docs/.test_reports/stress-run-YYYYMMDD-NN/S12-S0X/<subrun>/
    server.out.log
    server.err.log
    metrics-before.txt
    metrics-during.txt
    metrics-after.txt
    resource-samples.csv
    precondition.log   (S12-S08 only)
    evidence-summary.md
```

Per-benchmark evidence directory:

```text
._design_docs/.test_reports/benchmark-run-YYYYMMDD-NN/S12-B0X/<row>/
    server.out.log
    server.err.log
    metrics-before.txt
    metrics-during.txt
    metrics-after.txt
    k6-results.json        (B01 and B06)
    k6-stdout.txt          (B01 and B06)
    load-tool-output.txt   (non-k6 rows)
    baseline.json
    legacy-baseline.json   (rows with mandatory legacy comparison)
    evidence-summary.md
```

Baseline JSON shape per row: commit SHA, build type, binary
timestamp, host hardware, model fixture, slot count, context length,
draft mode, server flags, prompt generator seed, warmup window,
measurement window, request count, throughput, p50/p95/p99 latency,
exact-hit rate, checkpoint-hit rate, restore latency by payload kind,
demotion and promotion counts, eviction count, working set and handle
samples, evidence-source classification per measurement, and a
`correctness_verdict` field.

Tuning report skeleton:
`._design_docs/.test_reports/benchmark-run-YYYYMMDD-NN/tuning-report.md`
with the seven sections from design part 03 (hot budget, cold store,
slot count, context length, draft and MTP, workload profile,
bottlenecks). Driver writes the skeleton; QA populates values.



## 8. Cross-reference

Sections 8 through 14 (long-run details, observability, regression,
out of scope, fixture status, S12-PLAN-01 observation, handoff)
live in [part-18a](part-18a-stage12-operational.md). The matrix
in sections 1-7 of this part is the QA scope; part-18a records
the operational rules that the execution session consumes.
Test automation scripts inventory: see
[part-19](part-19-stage12-test-automation.md).