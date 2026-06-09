# Stage 12 implementation plan - Part 1

Source: [../cache-handling-phase12-implementation.md](../cache-handling-phase12-implementation.md)

## Status

- Plan state: drafted for Architect implementation-plan review and Manager implementation-plan gate.
- Design gate: PASS (cache-handling-phase12-design.md and parts 01-09).
- Cap-fix closure: PASS 2026-06-07 (T114=0.9276, T114a=0.8418 per [part-29](../cache-handling-phase11-implementation/part-29-cap-fix-closure-decision.md)).
- Implementation state: not started.
- QA execution state: not opened.
- Commit state: not committed.
- Planning date: 2026-06-07.

## Accepted design baseline

Implement Stage 12 stress testing and benchmarking against the accepted
design in [cache-handling-phase12-design.md](../cache-handling-phase12-design.md),
parts 01 through 09, with Architect design re-review PASS in
[part-07](../cache-handling-phase12-design/part-07-design-re-review-gate-01.md)
and Manager design gate PASS in
[part-08](../cache-handling-phase12-design/part-08-manager-design-gate.md).

Binding constraints from the design (parts 01-04):

- Hybrid mode remains opt-in through `--cache-mode hybrid`; legacy mode is
  the default and the regression control.
- Stress and benchmark evidence uses public `/metrics` and bounded logs
  where possible. Focused test binaries support preconditions that public
  HTTP cannot create.
- Long-run checks (S12-L01, S12-L02, S12-L03) carry the production-like
  6-hour, 30-minute reproducibility, and 2-hour legacy-control rows.
- T114, T114a, T115, and T121 closure contracts stay current when code or
  tests change in Stage 12.
- The cap-fix cycle is closed per
  [part-09](../cache-handling-phase12-design/part-09-cap-fix-closure-prereq-update.md);
  no Manager narrowing is required for draft/MTP or cap-fix rows in this
  plan.

## Scope of this plan

This plan delivers the stress and benchmark infrastructure that the
execution team will run. It does not produce the test report, pass/fail
verdicts, baseline numbers, or tuning report text. Those are QA
execution artifacts.

This plan produces:

- A new stress script family under
  `._design_docs/cache-handling-test-scripts/` keyed by the S12-S01..S12-S08
  scenario IDs.
- A new benchmark script family under
  `._design_docs/cache-handling-test-scripts/` keyed by the S12-B01..S12-B08
  scenario IDs.
- A baseline recording helper that writes a structured JSON snapshot per
  benchmark row.
- A tuning-report skeleton that QA populates with run results.
- A long-run driver for S12-L01, S12-L02, S12-L03 with a fixed resource
  sampler interval and a verdict surface that QA consumes.
- A new evidence-output directory layout under
  `._design_docs/.test_reports/stress-run-YYYYMMDD-NN/` and
  `._design_docs/.test_reports/benchmark-run-YYYYMMDD-NN/`.

This plan does not change `llama-server`, `server-cache-hybrid.cpp`,
`server-cache-controller.cpp`, the focused test binaries, the coverage
script, the k6 benchmark script, the integration runner, the test plan,
or the document index. Stage 12 is operational validation; no new
behavior or public surface is added.

## Stress scenario map

Source: [part-02](../cache-handling-phase12-design/part-02-stress-scenarios-and-config-matrix.md)

| ID | Script path | Fixture | Configuration | Duration | Evidence file |
| --- | --- | --- | --- | --- | --- |
| S12-S01 Budget exhaustion | `stress-budget-exhaustion.ps1` (new) | `Qwen3-0.6B-Q8_0.gguf` | `--cache-mode hybrid --cache-ram 2 --parallel 2 --metrics`; cold on/off variants | 30 min | `stress-run-YYYYMMDD-NN/S12-S01-<variant>/{server.out.log,server.err.log,metrics-{before,during,after}.txt,resource-samples.csv,evidence-summary.md}` |
| S12-S02 Concurrent multi-slot | `stress-concurrent-multislot.ps1` (new, extends existing stress_tests.ps1 S02) | `Qwen3-0.6B-Q8_0.gguf` | `--cache-mode hybrid --parallel 4` and `--parallel 8`; `BLOCKED` for `--parallel 8` if host cannot start | 30 min per slot count | `stress-run-YYYYMMDD-NN/S12-S02-parallel{N}/{server.out.log,server.err.log,metrics-{before,during,after}.txt,resource-samples.csv,evidence-summary.md}` |
| S12-S03 Large branch forests | `stress-large-forest.ps1` (new) | `Qwen3-0.6B-Q8_0.gguf` | `--cache-mode hybrid --cache-ram 50 --parallel 2`; varied prefix generator with fixed seed | 30 min | `stress-run-YYYYMMDD-NN/S12-S03/{server.out.log,server.err.log,metrics-{before,during,after}.txt,resource-samples.csv,evidence-summary.md}` |
| S12-S04 Prompt storms | `stress-prompt-storm.ps1` (new) | `Qwen3-0.6B-Q8_0.gguf` | `--cache-mode hybrid --cache-ram 100 --parallel 4`; near-duplicate and exact-repeat prompt mix | 30 min | `stress-run-YYYYMMDD-NN/S12-S04/{server.out.log,server.err.log,metrics-{before,during,after}.txt,resource-samples.csv,evidence-summary.md}` |
| S12-S05 Mixed workload profiles | `stress-mixed-profile.ps1` (new) | Plain-transformer `Qwen3-0.6B`; target-plus-draft `Qwen3-8B` + `Qwen3-0.6B` if both fixtures load; checkpoint-dependent `BLOCKED` without fixture | per-profile `--cache-mode hybrid` flags; `--parallel 1` for plain-transformer, `--parallel 1 --model-draft <draft>` for target-plus-draft | 30 min per profile | `stress-run-YYYYMMDD-NN/S12-S05-<profile>/{server.out.log,server.err.log,metrics-{before,during,after}.txt,resource-samples.csv,evidence-summary.md}` |
| S12-S06 Cold queue pressure | `stress-cold-queue.ps1` (new) | `Qwen3-0.6B-Q8_0.gguf` | `--cache-mode hybrid --cache-ram 16 --cache-cold-path <temp_root> --parallel 2` | 30 min | `stress-run-YYYYMMDD-NN/S12-S06/{server.out.log,server.err.log,metrics-{before,during,after}.txt,resource-samples.csv,evidence-summary.md}` |
| S12-S07 Protected-root pressure | `stress-protected-root.ps1` (new) | `Qwen3-0.6B-Q8_0.gguf` | `--cache-mode hybrid --cache-ram 8 --parallel 2`; large protected roots plus budget pressure | 30 min | `stress-run-YYYYMMDD-NN/S12-S07/{server.out.log,server.err.log,metrics-{before,during,after}.txt,resource-samples.csv,evidence-summary.md}` |
| S12-S08 Integrity failure under load | `stress-integrity-failure.ps1` (new) | `Qwen3-0.6B-Q8_0.gguf` | `--cache-mode hybrid --cache-ram 50 --parallel 2`; precondition seeded by `test-step11-test-hooks-fault-injection.exe` (focused), then live load continues | 30 min | `stress-run-YYYYMMDD-NN/S12-S08/{server.out.log,server.err.log,metrics-{before,during,after}.txt,resource-samples.csv,precondition.log,evidence-summary.md}` |

## Benchmark scenario map

Source: [part-03](../cache-handling-phase12-design/part-03-benchmarks-baselines-and-legacy.md)

| ID | Script path | Fixture | Baseline recording | Tuning report step | Legacy comparison |
| --- | --- | --- | --- | --- | --- |
| S12-B01 Exact-blob hit rate | `bench-exact-hit-rate.ps1` (new, modelled on `run_benchmark_k6.ps1`) | `Qwen3-0.6B-Q8_0.gguf` | hybrid row only; legacy row captures baseline for ratio | tuning row 1 (hot budget guidance) | mandatory legacy row at same flags except `--cache-mode legacy` |
| S12-B02 Checkpoint hit rate | `bench-checkpoint-hit-rate.ps1` (new) | `Qwen3-8B` plus draft `Qwen3-0.6B` if both fixtures load; `BLOCKED` if checkpoint fixture missing | hybrid checkpoint profile row; legacy checkpoint profile row for ratio | tuning row 6 (workload profile guidance) | mandatory legacy row |
| S12-B03 Cold transition frequency | `bench-cold-transition.ps1` (new) | `Qwen3-0.6B-Q8_0.gguf` | hybrid `--cache-cold-path <temp_root>` row; legacy row for parity | tuning row 2 (cold store guidance) | mandatory legacy row (cold disabled in legacy path) |
| S12-B04 End-to-end token throughput | `bench-end-to-end-throughput.ps1` (new) | `Qwen3-0.6B-Q8_0.gguf` | hybrid and legacy rows at matched slot, ctx, prompt mix | tuning row 3 (slot count) and row 4 (context length) | mandatory legacy row; gain form is throughput or latency |
| S12-B05 Restore latency | `bench-restore-latency.ps1` (new) | `Qwen3-0.6B-Q8_0.gguf` | hybrid only; captures p50, p95, p99 by payload kind and residency | tuning row 1 (hot budget) and row 2 (cold store) | legacy row absent because legacy has no hybrid restore path; record`N/A` |
| S12-B06 Prompt-storm efficiency | `bench-prompt-storm.ps1` (new) | `Qwen3-0.6B-Q8_0.gguf` | hybrid and legacy rows under high repeat pressure | tuning row 1 and tuning row 2 | mandatory legacy row |
| S12-B07 Mixed-profile comparison | `bench-mixed-profile.ps1` (new) | plain-transformer `Qwen3-0.6B`; checkpoint-dependent fixture if present; target-plus-draft `Qwen3-8B` plus `Qwen3-0.6B` if present | profile-by-profile baseline | tuning row 6 (workload profile guidance) | profile-by-profile legacy row where fixture supports the profile |
| S12-B08 Large-forest lookup cost | `bench-large-forest-lookup.ps1` (new) | `Qwen3-0.6B-Q8_0.gguf` | hybrid row only; captures request latency as forest grows | tuning row 7 (bottlenecks) | legacy row absent; record`N/A` |

## Long-run checks

Source: [part-02 long-run section](../cache-handling-phase12-design/part-02-stress-scenarios-and-config-matrix.md)

| ID | Driver script | Duration | Resource sampler | What to assert |
| --- | --- | --- | --- | --- |
| S12-L01 Production-like hybrid long run | `longrun-hybrid-6h.ps1` (new) | 6 hours | process working set, Windows handle count, server liveness ping, `/metrics` sample, cold-store file count; interval 60 s | working-set growth < 10% after warmup; handle growth < 5%; metric counters monotonic; no crash/hang/orphan growth |
| S12-L02 Reproducibility run | `longrun-reproducibility-30m.ps1` (new) | 30 minutes | same sampler at 30 s interval | metric and latency shape repeat within recorded tolerance against the paired benchmark row |
| S12-L03 Legacy control long run | `longrun-legacy-2h.ps1` (new) | 2 hours | same sampler at 60 s interval | legacy path stays stable; no hybrid metric rows active; cold-store side effects absent |

Default resource stability thresholds from the design part 02 stand until
QA records final thresholds before the first run. The driver exposes
threshold values as parameters so QA can tune them.

## Configuration matrix

Source: [part-02 matrix](../cache-handling-phase12-design/part-02-stress-scenarios-and-config-matrix.md)

Build configuration baseline (locked by
[part-29](../cache-handling-phase11-implementation/part-29-cap-fix-closure-decision.md)):

- `build-cov` with `BUILD_SHARED_LIBS=OFF`, `/Zi /Ob1 /O2 /EHsc`,
  `/DEBUG:FULL`, `GGML_CUDA=OFF`
- Release binaries only; Debug is not used for stress or benchmark runs
- Focused ctest preflight targets: `test-cache-controller`,
  `test-step10-metrics`, `test-stage10-cold-store-hardening`,
  `test-step12-branch-graph`, `test-step13-stage8`,
  `test-step6-demotion-protocol`, `test-step7-promotion-protocol`,
  `test-step11-test-hooks-fault-injection`

Server flags per row use the matrix dimensions from design part 02:

- Cache mode: `hybrid` for in-scope rows; `legacy` for regression control
  rows
- Hot budget: small (forces eviction), medium (retains working set),
  large (avoids ordinary eviction); integer MiB only
- Cold path: off or on with safe temporary root
- Slot count: 1, 2, 4, 8 where the host allows; record `BLOCKED` for 8 if
  model or memory limit blocks startup
- Context length: short, medium, near configured limit; near-limit rows
  must not exceed server safety checks
- Draft presence: none for the in-scope rows under this plan; the cap-fix
  cycle is closed, so separate draft and MTP rows could open after a
  Manager scope decision. The plan keeps them out of scope until QA
  planning requests them
- Workload profile: plain-transformer for all in-scope rows;
  checkpoint-dependent or target-plus-draft only when the fixture is
  present
- Prompt mix: exact repeats, near duplicates, unique prompts, long
  prefixes
- Run length: stress 30 minutes; benchmarks warmup plus measurement
  window; long-run 6h, 2h, 30m

## Evidence format

Source: [part-04 evidence and report shape](../cache-handling-phase12-design/part-04-observability-testability-traceability.md)

Per-scenario stress evidence directory:

```text
._design_docs/.test_reports/stress-run-YYYYMMDD-NN/S12-S0X/<subrun>/
    server.out.log
    server.err.log
    metrics-before.txt
    metrics-during.txt
    metrics-after.txt
    resource-samples.csv
    precondition.log   (only when a focused binary sets up precondition)
    evidence-summary.md   (filled by the script)
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
    load-tool-output.txt   (non-k6 load tool rows)
    baseline.json          (per-row structured snapshot)
    legacy-baseline.json   (when a legacy row exists)
    evidence-summary.md    (filled by the script)
```

Baseline JSON shape per row: commit SHA, build type, binary timestamp,
host hardware, model fixture, slot count, context length, draft mode,
server flags, prompt generator seed, warmup window, measurement window,
request count, throughput, p50/p95/p99 latency, exact-hit rate,
checkpoint-hit rate, restore latency by payload kind, demotion and
promotion counts, eviction count, working set and handle samples, and a
`correctness_verdict` field. The QA plan decides the pass/fail verdict
from this file.

Tuning report skeleton:
`._design_docs/.test_reports/benchmark-run-YYYYMMDD-NN/tuning-report.md`
with the seven sections from design part 03 (hot budget, cold store,
slot count, context length, draft and MTP, workload profile,
bottlenecks). The script writes the skeleton; QA fills the values.

## Prerequisites

- Tools: `k6` at `D:\app\k6\k6.exe`. `OpenCppCoverage` at
  `D:\app\OpenCppCoverage\OpenCppCoverage.exe` is used only by the
  existing `run_coverage.ps1` for T114/T114a refresh and is not consumed
  by the new stress or benchmark scripts.
- Python: existing `pytest` and `tools/server/tests/unit` infrastructure
  for startup and metric-shape checks; no new Python deps.
- Model fixtures: `._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf`
  is the default plain-transformer fixture. `Qwen3-8B` is the larger
  fixture for size-matrix rows. `Qwen3-0.6B` may serve as the separate
  draft model. MTP-capable fixture for H53/H54 remains blocked; this
  plan does not require MTP rows.
- Build configuration: `build-cov` reconfigured with
  `BUILD_SHARED_LIBS=OFF` per part-29. Clean rebuild required before the
  first stress or benchmark run; binary timestamp is checked by the
  drivers.
- Disk: scratch directory for cold store with at least 5 GB free;
  evidence directory with at least 20 GB free for 6-hour long-run
  samples.
- Hosts: local Windows MSVC. The drivers do not require CUDA.

## Risks

Source: [part-04 risks](../cache-handling-phase12-design/part-04-observability-testability-traceability.md)

| Risk | Why it matters for this plan | Mitigation |
| --- | --- | --- |
| Local host cannot start `--parallel 8` | S12-S02 second slot count row and any 8-slot benchmark row depend on host memory and model headroom | Drivers probe startup before counting requests; record `BLOCKED` with host limit if startup fails |
| Six-hour long-run cannot fit in a single execution window | S12-L01 needs 6 uninterrupted hours; host may be throttled or rebooted | Driver writes a partial-snapshot marker per 30 min so QA can resume evidence collection; record any interruption in the run log |
| Qwen3-8B fixture cannot load with the in-scope `--ctx-size` | Larger-fixture rows in S12-S05 and benchmark rows may fail at startup | Drivers record `BLOCKED` with server startup log; tuning report notes fixture absent rather than skipping silently |
| Cold-store path permission or disk space fails | S12-S06, S12-B03, and S12-B05 cold rows depend on a writable, non-root, non-system path | Drivers create a temp root under `%TEMP%` and verify write/delete before counting requests; record `BLOCKED` with the failure reason |
| `test-stage10-policy-lru` pre-existing semantic bug | test plan carries this row separately and may be reported as a regression after stress runs | Drivers do not gate on `test-stage10-policy-lru`; the bug is out of Stage 12 cap-fix scope per part-29 |
| Draft and MTP rows were gated on cap-fix closure | This plan keeps draft and MTP rows out of scope under the closed cap-fix | If QA planning opens draft or MTP rows, the drivers support `--spec-type draft-simple` and `--spec-type draft-mtp`, but no row in this plan requires them |
| Multi-hour metrics and resource samples grow large | Evidence becomes hard to review | Resource sampler is fixed-interval (60 s for S12-L01, 30 s for S12-L02, 60 s for S12-L03); raw logs stay as artifacts and are not pasted into the report body |
| Public metrics cannot expose a focused precondition | Driver may be tempted to claim a precondition from a private counter | Drivers classify each row's evidence as `public Prometheus`, `structured log`, `direct stats`, or `harness-only` and the report shape records the source per row |

## Ordering

Source: [part-02 evidence rules](../cache-handling-phase12-design/part-02-stress-scenarios-and-config-matrix.md) and [part-04 long-run rules](../cache-handling-phase12-design/part-04-observability-testability-traceability.md)

Sequencing:

1. Preflight: clean build of `build-cov`, freshness check on
   `llama-server.exe`, focused ctest for the eight named targets,
   coverage tool probe, and a 5-minute public HTTP probe against
   `Qwen3-0.6B` hybrid. This step does not produce a row verdict.
2. Short stress rows first: S12-S01, S12-S02 (parallel 4), S12-S04,
   S12-S06. These exercise the simplest preconditions. They can run
   sequentially in a single QA session and reuse the same scratch cold
   root.
3. Branch and profile stress rows: S12-S03, S12-S05, S12-S07, S12-S08.
   These depend on focused preconditions or larger fixtures and can run
   after the short rows confirm the harness is stable.
4. Benchmarks: S12-B01, S12-B06 first (k6 paths), then S12-B04, S12-B03,
   S12-B05, S12-B08, S12-B07, S12-B02. The k6 paths run first because
   they share `run_benchmark_k6.ps1` infrastructure and warm up the
   cache baseline. Each benchmark row runs alongside its legacy control
   row on the same host and build.
5. Long runs: S12-L02 reproducibility (30 min) after the benchmark rows
   so the matched pair is current; S12-L03 legacy control (2 h) next;
   S12-L01 production-like hybrid (6 h) last because it is the most
   expensive run.

Parallelization:

- Independent rows may run on different ports in parallel when host
  memory allows, but resource sampler and `/metrics` are per-process, so
  parallelization does not reduce evidence fidelity. The drivers
  serialize by default.
- S12-L01 may run overnight in the background; the driver records
  intermediate snapshots so QA can stop and resume the evidence.

## Handoff to test plan

QA planning opens next. The test plan should reference:

- The stress and benchmark scenario IDs (S12-S01..S12-S08, S12-B01..S12-B08,
  S12-L01..S12-L03) by name and treat them as the QA matrix.
- The baseline JSON shape from the evidence format section above;
  pass/fail thresholds and pass/fail verdicts are QA's responsibility,
  not the Developer's.
- The resource stability thresholds from the long-run section; the QA
  plan may tune them before the first run but must record the final
  values.
- The fixture inventory and the `BLOCKED` rules from the risks section.
- The cap-fix closure status from
  [part-29](../cache-handling-phase11-implementation/part-29-cap-fix-closure-decision.md);
  no Manager narrowing is required for the in-scope rows in this plan.
- The evidence-source classification rules in design part 04 (public
  Prometheus, structured log, direct stats, harness-only) so QA can
  classify each measurement correctly.

## Implementation handoff

The next gate is Architect implementation-plan review. The plan does
not authorize code, tests, commits, PR text, or reviewer responses.
