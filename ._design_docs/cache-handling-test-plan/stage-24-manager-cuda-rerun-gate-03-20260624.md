# Stage 24 Manager CUDA rerun gate 03 2026-06-24

Status: PASS
Date: 2026-06-24
Owner: Manager
Stage: 24 (Chat-Completion S02/S03 Cache Comparison)
Activity: CUDA rerun gate after report 03 runner fix

## Inputs checked

- [Blocked report 03](../.test_reports/test-report-20260624-03.md)
- [Report 03 fixes](../.test_reports/test-report-20260624-03-fixes.md)
- [Report 03 fix review](../cache-handling-phase24-implementation/part-15-report03-runner-fix-review-20260624.md)
- [Stage 24 test plan part](./part-29-stage24-chat-s02-s03-comparison.md)
- [Build-path gate](./stage-24-manager-build-path-gate-20260624.md)

## Gate decision

PASS.

QA may reopen fresh Stage 24 CUDA execution with a new report suffix and run
root. `test-report-20260624-03.md` remains blocked setup evidence and is not
closure evidence.

## Required execution contract

The existing CUDA execution contract remains binding with the build-path
amendment:

- use `test-report-20260624-04.md` and `stage24-chat-s02-s03-20260624-04`
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

Current gate: test execution. Use `test-report-20260624-04.md` and
`stage24-chat-s02-s03-20260624-04`.
