# Stage 24 Manager build-path gate 2026-06-24

Status: PASS
Date: 2026-06-24
Owner: Manager
Stage: 24 (Chat-Completion S02/S03 Cache Comparison)
Activity: CUDA build-path amendment before fresh execution

## Inputs checked

- [Stage 24 test plan part](./part-29-stage24-chat-s02-s03-comparison.md)
- [Prior CUDA rerun gate 02](./stage-24-manager-cuda-rerun-gate-02-20260624.md)
- [Aborted setup report](../.test_reports/test-report-20260624-02.md)
- `build-cov/CMakeCache.txt`
- `build-cuda/CMakeCache.txt`
- `._test_output/stage24-build-inspection-build-cuda-incremental-02.log`

## Gate decision

PASS.

QA must use the prior CUDA-stage `build-cuda` directory for the next Stage 24
execution instead of wiping `build-cov`. The next fresh suffix is
`test-report-20260624-03.md` with run root
`._test_output/stage24-chat-s02-s03-20260624-03`.

## Rationale

The `build-cov` command from the earlier plan removes the configured tree and
forces full `ggml-cuda` kernel compilation. That made setup much slower than
the previous CUDA-stage path.

The previous CUDA-stage build path is still present and matches the intended
CUDA runtime family:

```text
Build dir: build-cuda
Generator: Visual Studio 17 2022
Platform: x64
GGML_CUDA:BOOL=ON
GGML_NATIVE:BOOL=OFF
BUILD_SHARED_LIBS:BOOL=OFF
```

After removing an accidental uncommitted token in `server-context.cpp`, a
non-destructive `build-cuda` target build passed in 17.042 seconds and produced
a fresh `build-cuda/bin/Release/llama-server.exe`.

## Required execution contract

The CUDA execution contract remains binding with this build-path substitution:

- build `cmake --build build-cuda --config Release -j --target llama-server`
- prove `build-cuda/CMakeCache.txt` contains `GGML_CUDA:BOOL=ON`
- use `build-cuda/bin/Release/llama-server.exe` for dry-run and live execution
- dry-run must finish and write `dry-run-plan.json`
- all live legs must use `--n-gpu-layers all` and `--fit off`
- runtime CUDA/NVIDIA proof must be captured before request evidence
- S02 request-error evidence must be preserved if it reproduces
- S03 unsafe-prefix failure applies only to hybrid near-prefix nonzero `cache_n`
- fresh durable report and run root are required

## Handoff

Next owner: QA.

Current gate: test execution. Use `test-report-20260624-03.md` and
`stage24-chat-s02-s03-20260624-03`.
