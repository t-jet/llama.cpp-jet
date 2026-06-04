# Fixes for test report 20260603-01

Source report: [test-report-20260603-01.md](test-report-20260603-01.md)
Stage: 10 tooling-unblock rework
Date: 2026-06-03
Status: rework report; not a single bug-fix; FAIL on T114/T115, BLOCKED on
T116/T117/T121.

## Context

Pointer to [test-report-20260602-02.md](test-report-20260602-02.md), which
ended BLOCKED for Stage 10 closure on coverage (T114/T115), benchmark
(T116/T117), and model-backed checkpoint `/metrics` (T121).

Rework rationale:

- The prior session ended with five BLOCKED rows: T114, T115, T116, T117,
  T121. The coverage blockers were a missing LLVM coverage toolchain
  and a missing GCOV fallback. The benchmark blockers were a missing
  `k6` binary and a missing Python `matplotlib` module. The
  checkpoint-row blocker was the local Qwen3 0.6B fixture not producing
  any checkpoint admission.
- The rework goal was to install the missing tools and rerun the
  coverage and benchmark rows, then reclassify the previously BLOCKED
  rows from the new evidence. The artifacts under
  `test-report-20260603-01-artifacts/` capture the install attempts,
  the new builds, the OpenCppCoverage per-test runs, the public probe,
  the k6 run, and the coverage summary.

## Environment

- devcmd invocation (from `vsdevcmd-env.bat`):
  `call "C:\Program Files\Microsoft Visual Studio\18\Community\Common7\Tools\vsdevcmd.bat" -arch=x64 -host_arch=x64`
  with LLVM bin on PATH first:
  `C:\Program Files\Microsoft Visual Studio\18\Community\VC\Tools\Llvm\x64\bin`.
- Tool versions (from `setup-env.json`):
  - cl 19.51, clang/clang-cl 20.1.8, llvm-cov/llvm-profdata present.
  - k6 2.0.0-rc1 (`D:\app\k6\k6.exe`).
  - Python 3.11.9, matplotlib 3.10.9.
  - OpenCppCoverage installed at `D:\app\OpenCppCoverage\OpenCppCoverage.exe`.

## Run plan

Reclassify the five previously BLOCKED rows:

- T114 (Hybrid path coverage) - try LLVM source-based coverage on
  `build-cov`. If that fails, fall back to OpenCppCoverage on the MSVC
  tree's focused test binaries, aggregate to a combined line rate, and
  report against the 80% threshold.
- T115 (Coverage denominator and exclusions) - report tool, command
  family, included files, excluded files, combined percentage, fallback
  reason. Branch totals stay absent (OpenCppCoverage limitation).
- T116 (Benchmark evidence) - install `k6` and `matplotlib`, run a k6
  connectivity probe against the public server, and confirm the bench
  toolchain is unblocked. The exact-hit/checkpoint-hit/cold-transition/
  end-to-end savings bench scenarios are not run.
- T117 (Benchmark correctness gate) - inherit from T116. With the bench
  scenarios not run, the gate cannot be evaluated.
- T121 (Stage 9 model-backed checkpoint `/metrics`) - rerun the public
  probe on the local Qwen3 0.6B fixture and inspect
  `cache_checkpoint_*` rows.

## Execution log

| Time (2026-06-03) | Action |
| --- | --- |
| 13:14 | `setup-env.ps1` captured devcmd env, tool paths, and versions. |
| 13:16 | `cmake -B build -S . -DCMAKE_BUILD_TYPE=Release` reconfigured cleanly. |
| 13:17 | MSBuild build of the original tree; one transient C1083 permission error on `unicode-data.obj`; build recovered. |
| 13:19 | 8 focused test binaries present in `build\bin\Release`. |
| 13:23 | Public HTTP probe (`public-probe.ps1`) ran; `/health` ready; two `/completion` calls; `cache_n=0` then `cache_n=4`; Stage 10 rows visible; checkpoint rows at 0. |
| 13:38-13:48 | Three coverage-tree rebuild attempts: clang-cl, debug, debug2. All blocked at link by `__profc_` symbols or by MSVC `error C2668: debug_admit_checkpoint_for_tests` on the test source. |
| 13:54-14:05 | MSBuild-style rebuild of the separate `build-cov` tree with `/DEBUG:FULL`; succeeded for all 8 focused exes. |
| 14:05-14:08 | OpenCppCoverage ran the 8 focused tests on `build-cov`; 8 Cobertura XMLs produced. |
| 14:09 | `coverage-aggregate.ps1` produced `coverage-summary.md`. |
| 14:12 | k6 run completed; 20 iterations of `/health` and `/metrics`; 0% failures; `p(95)` 1.07 ms. |
| 14:12 | Final k6 `/metrics` excerpt (`k6-stage10-excerpt.txt`) captured; same zero-valued bounded-shape Stage 10 rows as the public probe. |

## Evidence

- `configure.log` - configure of the original Release tree succeeded; ggml
  commit `d4ac73a3b`; OpenSSL missing noted.
- `build.log` - MSBuild build of the original tree; one transient C1083;
  builds all 8 focused test exes.
- `setup-env.ps1`, `setup-env.json`, `vsdevcmd-env.bat` - devcmd invocation
  and tool versions.
- `coverage-configure-and-build.ps1`, `cov-configure.log`, `cov-build.log`,
  `cov-debug-build.log`, `cov-debug-configure.log`,
  `cov-debug2-configure.log`, `cov-link-debug.ps1`,
  `cov-link-flags.cmake`, `patch-ninja-libs.ps1`, `cov-build.bat`,
  `cov-debug-build.bat`, `cov-debug-configure.bat`,
  `cov-debug2-configure.bat` - all the coverage-tree attempts and the
  link-time failures that drove the OpenCppCoverage fallback.
- `cov-pdb-build.log`, `cov-pdb-configure.bat`, `cov-msbuild-build.bat`,
  `cov-msbuild-build.log`, `cov-msbuild-configure.bat`,
  `cov-configure.bat` - the working MSBuild `build-cov` tree.
- `coverage-opencppcoverage.ps1`, `coverage-opencppcoverage2.ps1` - the
  per-test OpenCppCoverage runs.
- `coverage\run-01..08-*.log` - per-test exit codes (all 0) and Cobertura
  sizes.
- `coverage-aggregate.ps1`, `coverage-summary.md` - aggregated line rates
  and combined 0.2127.
- `public-probe.ps1`, `public-command.txt`, `public-server.pid`,
  `public-server.health`, `public-server.probe-complete`,
  `public-server.err.log`, `health.json`, `metrics-before.txt`,
  `completion-1.json`, `completion-2.json`, `metrics-after-2.txt`,
  `metrics-stage10-excerpt.txt`, `metrics-checkpoint-excerpt.txt` - the
  public HTTP `/health` and `/metrics` probe.
- `k6-run.ps1`, `k6-metrics-probe.js`, `k6-metrics-before.txt`,
  `k6-metrics-after.txt`, `k6-stage10-excerpt.txt`, `k6-results.json`,
  `k6-stdout.log`, `k6-exit.txt`, `k6-run-complete`, `k6-server.pid`,
  `k6-server.health`, `k6-server.out.log`, `k6-server.err.log` - the k6
  connectivity probe.

## Reclassification summary

| ID | 20260602-02 | 20260603-01 | Evidence pointer |
| --- | --- | --- | --- |
| T114 | BLOCKED | FAIL | `coverage-summary.md` combined line rate 0.2127; LLVM source-based path blocked at link (`cov-build.log`); OpenCppCoverage used on MSVC tree. |
| T115 | BLOCKED | FAIL | `coverage-summary.md` first paragraph (tool, command family, fallback reason); `coverage-aggregate.ps1` (denominator, inclusions, exclusions); branch totals absent because OpenCppCoverage does not produce them. |
| T116 | BLOCKED | BLOCKED | `k6-run.ps1`, `k6-results.json`, `k6-stdout.log` show k6 ran a connectivity probe only; no exact-hit/checkpoint-hit/cold-transition/end-to-end savings measurements; `bench.py` not run. |
| T117 | BLOCKED | BLOCKED | No bench rows produced. T116 carries the same blocker. |
| T121 | BLOCKED | BLOCKED | `metrics-checkpoint-excerpt.txt` shows the four `cache_checkpoint_*` rows at zero-valued bounded-shape placeholders; the local Qwen3 0.6B fixture is plain-transformer and cannot admit a checkpoint descriptor. |

## Open issues

- Coverage threshold not met. The OpenCppCoverage fallback reports
  21.27% combined line rate. The plan's 80% hybrid-path threshold is
  the contract. The block-rate-low source files (e.g.
  `server-cache-hybrid.cpp`, `server-cache-store-cold.cpp`,
  `server-context.cpp`) are the natural targets for new focused
  coverage.
- Branch totals not produced. OpenCppCoverage is line-only. The plan
  allows "when available"; a future rework could revisit LLVM
  source-based coverage or a different tool to gain branch totals.
- Benchmark scenarios not run. `k6` and `matplotlib` are now installed.
  A future QA session can run `tools/server/bench/bench.py` and
  `tools/server/bench/script.js` (or a custom k6 SSE script) to
  produce the exact-hit, checkpoint-hit, cold-transition, and
  end-to-end savings evidence.
- Model-backed checkpoint `/metrics` requires a checkpoint-capable
  fixture. The local Qwen3 0.6B GGUF is plain-transformer and cannot
  produce the precondition. The fixture catalog should add a
  checkpoint-capable model, or the row should be re-scoped to a
  focused harness that bypasses the public path.
- The clang-cl `error C2668` at `tests/test-cache-controller.cpp(1804)`
  is a test-source issue under clang-cl, not a product bug. It blocks
  the LLVM source-based coverage path on this host. The MSVC build of
  the same test compiles cleanly; the opencppcoverage runs use the
  MSVC-built `test-cache-controller.exe`.

## Handoff

Status: FAIL on T114 and T115; BLOCKED on T116, T117, T121. Rework
report, not a single bug-fix report.

Next gate: Developer test-results review. Report to review:
[test-report-20260603-01.md](test-report-20260603-01.md) plus this file.
