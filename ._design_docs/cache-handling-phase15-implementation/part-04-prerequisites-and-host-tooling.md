# Stage 15 implementation plan: prerequisites, host tooling, and fixtures

Source: [../cache-handling-phase15-implementation.md](../cache-handling-phase15-implementation.md)

## Branch and worktree state

The local working tree is on the `work-branch` branch per
[cache-handling-stage-tracker.md](../cache-handling-stage-tracker.md)
"Workflow rule". The Manager will not merge to `master` without
explicit user request. All artifacts in Stage 15 are versioned in the
worktree.

The implementation plan does not authorize a commit. The Developer
records the commit SHA at each step. If the worktree is dirty at the
start of a step, the Developer records the dirty state in the
implementation log before proceeding.

## Clean-build rule

Step 1 of the implementation plan requires a clean build. The
build command is:

```powershell
Remove-Item -Recurse -Force build-cov -ErrorAction SilentlyContinue
cmake -S . -B build-cov
cmake --build build-cov --config Release --target llama-server -j 4
```

The binary path is `build-cov\bin\Release\llama-server.exe`. The
freshness check rejects a binary older than 10 minutes. The QA report
records the build command, the binary timestamp, the git commit SHA,
and the dirty worktree state.

The clean-build rule applies at the start of each test session. The
QA report records the binary timestamp at the start of the session;
if the next session starts more than 10 minutes after the recorded
timestamp, Step 1 reruns.

## Host tools

- PowerShell: `C:\Program Files\WindowsApps\Microsoft.PowerShell_7.6.2.0_x64__8wekyb3d8bbwe\pwsh.exe`
  per the kickoff driver convention.
- CMake: from the existing developer setup.
- MSVC: from the existing developer setup.
- `k6`: `D:\app\k6\k6.exe` per Stage 12 implementation log part-01.
- `OpenCppCoverage`: `D:\app\OpenCppCoverage\OpenCppCoverage.exe` per
  Stage 12 implementation log part-01; used by the existing
  `run_coverage.ps1` for T114/T114a refresh and the T115 per-file
  table.
- Python: existing `pytest` and `tools/server/tests/unit`
  infrastructure for startup and metric-shape checks; no new Python
  deps.

The QA owner does not install new tooling. The implementation log
records the tool versions at the start of each step.

## V2 driver and per-row scripts

The Stage 15 plan re-uses the existing V2 driver. The kickoff driver
is `._design_docs/cache-handling-test-scripts/kickoff-v2-stress-longrun.ps1`.
The driver runs the L01..L03 long-run rows sequentially and writes
the side log. No v3 driver exists; the plan does not invent one.

Per-row scripts:

- Stress rows: `._design_docs/cache-handling-test-scripts/stress/stress_s12_sXX_*.ps1`.
- Long-run rows: `._design_docs/cache-handling-test-scripts/longrun/longrun_s12_lXX_*.ps1`.
- Benchmark rows: `._design_docs/cache-handling-test-scripts/bench/bench_s12_bXX_*.ps1`.

The driver and the per-row scripts are versioned in the worktree. The
QA owner records the script path and the script SHA at the start of
each row.

## Side log location

The kickoff driver writes the side log at:

```text
._design_docs/.test_reports/longrun-stage15-YYYYMMDD/batch-summary.log.side
```

The side log records driver start, kill, sleep, launch, and stop
events with timestamps. Per-row evidence directories live under the
same parent:

```text
._design_docs/.test_reports/longrun-stage15-YYYYMMDD/<row>/<subrun>/
```

Stress row evidence lives under:

```text
._design_docs/.test_reports/stress-stage15-YYYYMMDD/S12-S0X/<subrun>/
```

Benchmark row evidence lives under:

```text
._design_docs/.test_reports/bench-stage15-YYYYMMDD/S12-B0X/<row>/
```

## Coverage tool entry path

T114 and T114a use the existing coverage tool at
`._design_docs/cache-handling-test-scripts/run_coverage.ps1`. The
script runs OpenCppCoverage on the focused test binaries and writes
the union coverage report. The script's `--working_dir` resolves
relative paths under the build directory; the
`--export_type binary:<path>` flag writes the `.cov` files under
`<BuildDir>/bin/<Config>/<OutDir>/cov-binary/` even when `<path>`
starts with a Windows drive letter (per
`.agents/skills/self-improvement/assets/developer.md` note on the
OpenCppCoverage working-dir path resolution).

T115 inspects the per-file table from the same coverage report and
deduplicates by lowercased full path. T121 records the four
`cache_checkpoint_*` rows from the public HTTP `/metrics` endpoint on
the MTP-capable fixture; the server must be started with `--metrics`.

## Fixtures

The plan re-uses the local fixture inventory from prior stages:

- Plain-transformer: `._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf`
  (default).
- Larger transformer: Qwen3-8B fixture for size-matrix rows.
- Separate draft: Qwen3-0.6B as the normal separate draft model for
  draft-capable rows.
- MTP-capable: Qwen3.5-MTP or Qwen3.6-MTP fixture for the MTP rows.
  T121 requires the MTP-capable fixture; if absent, T121 ends in
  `BLOCKED-fixture`.

The QA owner records the fixture identity (file size, quantization,
modification time) at the start of each row. The fixture identity is
not copied into public summaries; only the SHA or the file size is
recorded.

## Build configuration

The build configuration baseline is locked by the Stage 11 cap-fix
closure:

- `build-cov` with `BUILD_SHARED_LIBS=OFF`, `/Zi /Ob1 /O2 /EHsc`,
  `/DEBUG:FULL`, `GGML_CUDA=OFF`.
- Release binaries only. Debug is not used for stress, long-run, or
  benchmark runs.
- Focused ctest preflight targets: `test-cache-controller`,
  `test-step10-metrics`, `test-stage10-cold-store-hardening`,
  `test-step12-branch-graph`, `test-step13-stage8`,
  `test-step6-demotion-protocol`, `test-step7-promotion-protocol`,
  `test-step11-test-hooks-fault-injection`.

The QA report records the build configuration, the compiler version,
and the focused ctest preflight result.

## Disk and host requirements

- Scratch directory for cold store with at least 5 GB free.
- Evidence directory with at least 20 GB free for the 6-hour long-run
  samples and the per-row evidence directories.
- Local Windows MSVC host. CUDA is not used.
- The 6-hour L01 row needs 6 uninterrupted hours of CPU and memory
  budget. Host reboots or operator stops during L01 are recorded as
  cap-exit with reason `host-reboot` or `operator-stop` per design
  part-03.

## MTP model readiness check

The QA owner records the MTP fixture presence in the Step 2 preflight
section. If the MTP fixture is absent, the QA report records
`BLOCKED-fixture` for T121 and the closure decision waits for the
Manager's plan-change decision. The Stage 12 V2 bench precedent
allows B02 to be `BLOCKED-fixture`; T121 follows the same precedent.

## Handoff to execution

The Developer uses this part to set up the test environment. The
QA owner uses this part to verify the environment is ready before
Step 2 starts. The Architect uses this part to confirm the
prerequisites are met before the implementation-plan review closes.
