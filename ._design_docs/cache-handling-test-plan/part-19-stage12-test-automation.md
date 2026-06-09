# Cache handling test plan - Part 19: Stage 12 test automation

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)
Matrix: [part-18](part-18-stage12-stress-benchmarks.md)
Operational details: [part-18a](part-18a-stage12-operational.md)

## 1. Scope

This part documents the Stage 12 test automation family: the
stress, benchmark, and long-run driver scripts, the shared library
helpers, the config matrix helper, and the dry-run and STUB
behaviors. The harness was authored in
[impl part-01](../cache-handling-phase12-implementation/part-01-implementation-plan.md),
[part-03](../cache-handling-phase12-implementation/part-03-implementation.md),
[part-04](../cache-handling-phase12-implementation/part-04-implementation-evidence.md),
and reviewed in
[part-06](../cache-handling-phase12-implementation/part-06-implementation-review.md).
The harness did not modify `llama-server`, the cache source, the
coverage script, the k6 benchmark script, the integration runner,
the test plan, or the document index.

## 2. Scripts inventory (25)

All paths are under `._design_docs/cache-handling-test-scripts/`.
Total: 5 lib helpers + 8 stress + 8 bench + 3 long-run + 1 root
config matrix helper.

### 2.1 Library helpers (5)

| Script | Purpose |
| --- | --- |
| `lib/Write-StressEvidence.ps1` | writes per-scenario stress `evidence-summary.md` |
| `lib/Write-BenchEvidence.ps1` | writes per-row benchmark `evidence-summary.md` |
| `lib/Write-LongrunEvidence.ps1` | writes per-run long-run `evidence-summary.md` |
| `lib/Read-BaselineJson.ps1` | reads `baseline.json` into a hashtable |
| `lib/Write-TuningReport.ps1` | writes the seven-section tuning-report skeleton |
| `lib/Read-GgufChatTemplate.ps1` | extracts `tokenizer.chat_template` from a GGUF via `gguf_dump.py --json`; also exposes `Resolve-MtpJinjaPath` and `Merge-MtpJinjaFlag` for the MTP/jinja variant contract (part-19 sec 7.1, part-21a sec 2) |

### 2.2 Stress drivers (8)

| ID | Script |
| --- | --- |
| S12-S01 | `stress/stress_s12_s01_budget_exhaustion.ps1` |
| S12-S02 | `stress/stress_s12_s02_concurrent_multi_slot.ps1` |
| S12-S03 | `stress/stress_s12_s03_large_branch_forests.ps1` |
| S12-S04 | `stress/stress_s12_s04_prompt_storms.ps1` |
| S12-S05 | `stress/stress_s12_s05_mixed_workload_profiles.ps1` |
| S12-S06 | `stress/stress_s12_s06_cold_queue_pressure.ps1` |
| S12-S07 | `stress/stress_s12_s07_protected_root_pressure.ps1` |
| S12-S08 | `stress/stress_s12_s08_integrity_failure_under_load.ps1` |

### 2.3 Benchmark drivers (8)

| ID | Script |
| --- | --- |
| S12-B01 | `bench/bench_s12_b01_exact_blob_hit_rate.ps1` |
| S12-B02 | `bench/bench_s12_b02_checkpoint_hit_rate.ps1` |
| S12-B03 | `bench/bench_s12_b03_cold_transition_frequency.ps1` |
| S12-B04 | `bench/bench_s12_b04_end_to_end_token_throughput.ps1` |
| S12-B05 | `bench/bench_s12_b05_restore_latency.ps1` |
| S12-B06 | `bench/bench_s12_b06_prompt_storm_efficiency.ps1` |
| S12-B07 | `bench/bench_s12_b07_mixed_profile_comparison.ps1` |
| S12-B08 | `bench/bench_s12_b08_large_forest_lookup_cost.ps1` |

### 2.4 Long-run drivers (3)

| ID | Script |
| --- | --- |
| S12-L01 | `longrun/longrun_s12_l01_6h_hybrid_stability.ps1` |
| S12-L02 | `longrun/longrun_s12_l02_30m_legacy_comparison.ps1` |
| S12-L03 | `longrun/longrun_s12_l03_2h_mixed_workload.ps1` |

### 2.5 Config matrix helper (1)

| Script | Purpose |
| --- | --- |
| `apply_config_matrix.ps1` (root) | reads a JSON matrix and resolves it into a run-config JSON consumed by the stress and benchmark drivers |

### 2.6 Evidence dir templates (3)

| Template path | Purpose |
| --- | --- |
| `._design_docs/.test_reports/stress-s12-template/README.md` | documents the per-row stress evidence dir layout |
| `._design_docs/.test_reports/bench-s12-template/README.md` | documents the per-row benchmark evidence dir layout |
| `._design_docs/.test_reports/longrun-s12-template/README.md` | documents the per-run long-run evidence dir layout |

## 3. Automation setup

Build prerequisites follow the cap-fix baseline in
[part-18 section 2](part-18-stage12-stress-benchmarks.md#2-clean-build-requirement).
Drivers resolve the build dir, model fixture, and port through
environment variables with safe fallbacks:

- `LLAMA_SERVER_BIN_PATH` (or default
  `d:\source\llama.cpp-jet\build-cov\bin\Release\llama-server.exe`)
- `LLAMA_CACHE_TEST_MODEL` (or default
  `._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf`)
- `LLAMA_CACHE_TEST_TARGET_MODEL` (Qwen3-8B for S05, B02, B07)
- `LLAMA_CACHE_TEST_DRAFT_MODEL` (Qwen3-0.6B for target-plus-draft)
- `LLAMA_CACHE_TEST_COLD_ROOT` (default `%TEMP%\s12-cold-<guid>`)
- `LLAMA_CACHE_TEST_K6_PATH` (default `D:\app\k6\k6.exe`)

Drivers refuse to start if the binary timestamp is older than 10
minutes. The 10-minute check is the same policy that
`execute_tests.ps1` and `run_coverage.ps1` use.

`--Port` is the first port; multi-slot drivers compute
`$portUse = $Port + $n` per sub-run to avoid collisions when
parallel runs are launched on the same host.

## 4. Dry-run mode

Every scenario driver accepts `-DryRun`. The dry-run path:

- prints planned server flags, fixture path, port, and duration
- prints the evidence dir that the live run would create
- does not start `llama-server`
- does not call k6 or the focused fault-injection binary
- does not write STUB artifacts
- does not perform the fixture existence check (stub mode only)

The 19 scenario drivers (8 stress + 8 bench + 3 long-run) all
complete `-DryRun` with exit 0 and no positional parameter errors,
per the build-impl log captured in
[part-04](../cache-handling-phase12-implementation/part-04-implementation-evidence.md).
Round 2 of the build-impl log fixed two issues:

1. `Export-ModuleMember` outside a module emitted non-terminating
   errors on every dot-source of `lib/*.ps1`. Removed from all 5
   lib helpers.
2. `bench_s12_b01_exact_blob_hit_rate.ps1` line 51 mixed a
   pipeline with `+ @(...)` which the parser bound as a
   positional argument. Rewrote `$legacyFlags` as a direct array
   literal matching `$hybridFlags`.

## 5. STUB evidence contract

When a fixture or required tool is missing, the driver writes
STUB markers to each artifact and records `Verdict: BLOCKED` in
the per-scenario evidence summary. STUB rows are not counted as
PASS for closure. STUB rows preserve planned flags, slot count,
ctx size, and duration so QA can record fixture absence rather
than skipping silently.

STUB triggers per row:

- S12-S08: focused fault-injection binary
  (`build-cov\bin\Release\test-step11-test-hooks-fault-injection.exe`)
  missing
- S12-B01, S12-B06: k6 missing
- S12-S05 (checkpoint), S12-B07 (checkpoint): server fails to
  start with Qwen3-8B at the in-scope `--ctx-size`
- S12-S06, S12-B03: cold-store path cannot be created or written
- S12-S02 (parallel 8 only): host cannot start at the requested
  slot count

## 6. Evidence helpers

`lib/Write-StressEvidence.ps1` writes `evidence-summary.md` with
the per-scenario pass/fail gate, request count, eviction count,
cold-store file count, and the `Verdict` line.

`lib/Write-BenchEvidence.ps1` writes `evidence-summary.md` with
throughput, p50/p95/p99 latency, hit rate, restore latency by
payload kind, and the `correctness_verdict` field consumed by
the QA report.

`lib/Write-LongrunEvidence.ps1` writes `evidence-summary.md` with
working set, handle count, and cold-store file count samples,
plus a `partial_snapshot_count` field that records how many
intermediate snapshots the driver wrote.

`lib/Read-BaselineJson.ps1` reads `baseline.json` (or
`legacy-baseline.json` for the legacy comparison rows) into a
hashtable keyed by the JSON shape fields in
[part-18 section 7](part-18-stage12-stress-benchmarks.md#7-evidence-format).

`lib/Write-TuningReport.ps1` writes the seven-section tuning
report skeleton under
`._design_docs/.test_reports/benchmark-run-YYYYMMDD-NN/tuning-report.md`.
QA populates the values after the first benchmark run.

## 7. Per-scenario workflow

The default workflow for each scenario script is:

1. parse parameters, resolve build, fixture, port, and evidence
   dir from env or defaults
2. if `-DryRun`, print plan and exit 0
3. probe fixture existence and required tool availability
4. if missing, write STUB markers and `Verdict: BLOCKED`, exit 0
5. start `llama-server` with the planned flags
6. wait for model readiness (use `/health` as process readiness,
   not model readiness, per Stage 12 plan)
7. capture `metrics-before.txt`
8. run the scenario's prompt loop or load tool
9. capture `metrics-during.txt` at fixed intervals
10. capture `metrics-after.txt` after the load finishes
11. write `resource-samples.csv` from the resource sampler
12. write `baseline.json` and `evidence-summary.md` from the
    evidence helpers
13. stop the server, free the port, and return the verdict

For S12-S08, the workflow inserts step 7.5: invoke
`test-step11-test-hooks-fault-injection.exe` to seed the cold
corruption precondition, then capture `precondition.log` before
the live load continues.

### 7.1 MTP and jinja variant parameters (post-closure follow-up)

All 19 base scenario drivers (8 stress + 8 bench + 3 long-run)
accept two new parameters added in part-21:

- `-MtpVariant {0|1|2|3}`: 0 is the existing no-MTP scenario;
  1, 2, 3 select V1, V2, V3. Default 0. Required to be explicit
  in every Stage 12 MTP follow-up run so the evidence dir and
  provenance files name the variant.
- `-JinjaVariant {original|marked}`: selects the jinja file per
  part-21 section 4. Required (no default) for every Stage 12
  MTP follow-up run; driver fails fast if omitted.

`jinja_path` is auto-resolved from `-MtpVariant`, `-JinjaVariant`,
and the model dir per part-21 section 4. The resolved absolute
path is written to `jinja-path.txt` in the per-scenario evidence
dir alongside `mtp-variant.txt` and `jinja-variant.txt`. The
parameter set is the same across all 19 base drivers; no
driver-specific variant logic is permitted. V2-only jinja
extraction (part-21 section 5) runs once per session before the
first V2 sub-run, not per sub-run.

## 8. Maintenance and clean-up

- All 25 scripts use CRLF line endings to match the existing
  `run_benchmark_k6.ps1` and `stress_tests.ps1` family. The
  build-impl log captured the CR-LF balance in every file; no
  script uses Unicode em-dashes or non-ASCII characters.
- The README at
  [`cache-handling-test-scripts/README.md`](../cache-handling-test-scripts/README.md)
  documents the Stage 12 driver invocation, dry-run path, and
  clean-build rule.
- A known cosmetic issue: S12-S02 dry-run prints the base port
  8210 for both sub-runs; live code computes
  `$portUse = $Port + $n` at line 83, so the two sub-runs bind
  8214 and 8218. Cosmetic print only; not a functional bug.
  Worth tightening in a follow-up.
- A known cleanup item: dry-run path creates the evidence subdir
  before the early-exit (S01 line 47 vs line 52). Empty dir
  residue remains on disk. Cleanup recommended before live run;
  not a defect.
- A known gate item: S12-S05 and S12-B07 checkpoint-dependent
  profiles may BLOCK on the first live run if Qwen3-8B does not
  admit a checkpoint at the in-scope `--ctx-size`. QA plan owns
  tuning or surfaces a Manager scope decision.

## 9. Handoff

This part opens the next gate alongside part-18 and part-18a: QA
test plan review. The review confirms that the per-scenario
workflow, dry-run, STUB contract, and evidence helpers are
consistent with the per-scenario pass criteria in
[part-18 section 3-7](part-18-stage12-stress-benchmarks.md) and
the observability and regression set in
[part-18a section 9-10](part-18a-stage12-operational.md#9-observability).
Run results are stored only in a fresh
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` after the
execution session opens.

## 10. Operational notes for future sessions

These notes collect small driver-level rules that future sessions
need when they extend or rerun the Stage 12 harness. They are
documentation only; the source-of-truth code lives in the
`stress/`, `bench/`, and `longrun/` scripts and the `lib/`
helpers.

### 10.1 LLAMA_CACHE_TEST_MODEL env hygiene

When a stage run needs a non-default model fixture, set
`LLAMA_CACHE_TEST_MODEL` to an absolute path BEFORE invoking the
driver. PowerShell does not export env vars set with `$env:X = ...`
across separate `pwsh -File` invocations unless the parent shell
re-exports them. Always pass `-ModelPath` explicitly to a driver
when chaining from a CI step or a wrapper script so the value is
not lost between calls. If the fixture path contains spaces,
quote it in both the env assignment and the `-ModelPath`
argument.

### 10.2 PowerShell splat binding and Write-Host capture

Do not write PowerShell that mixes a pipeline result with array
concatenation on the same assignment, for example
`$result = $arr | Where-Object { ... } + @('a','b')`. The parser
binds `+` as a positional argument to the last cmdlet
(typically `Where-Object`) and produces
`A positional parameter cannot be found that accepts argument '+'.`
even when the result type makes the `+` unambiguous. Split into
two statements or group the pipeline with parentheses.

`Write-Host` writes to the information stream, not stdout. A
caller that captures driver output with `& driver.ps1 ... 2>&1 | Out-String`
sees the host messages inside the captured string. If a future
session needs to parse dry-run output, redirect to a file with
`Out-File` or write to stdout via `Write-Output`. The current
harness is built around `Write-Host` for dry-run plan prints
because the plan-print is operator-facing, not parser-facing.

### 10.3 Future sessions and timeout choices

Stage 12 long-run drivers expose both `-DurationHours` (int) and
`-DurationMin` (int, default 0). When `-DurationMin` is greater
than zero the driver converts it to seconds; otherwise it falls
back to `-DurationHours * 3600`. The minute parameter exists so
short sanity runs (5 min, 10 min) can exercise the same code path
without rounding through the hour parameter. Future sessions
that need sub-hour wall-clock budgets should set
`-DurationMin` explicitly and not set `-DurationHours`. A 10 min
sanity run uses `-DurationMin 10`; an overnight 6 h run uses the
default `-DurationHours 6`.
