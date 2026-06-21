# Stage 23 Manager CUDA execution gate

Status: PASS
Date: 2026-06-21
Stage: 23 (Full S/L Matrix Execution)
Owner: Manager
Scope: CUDA execution gate after CPU-only Stage 23 run was invalidated.

## Decision

VERDICT: PASS.

Decision D23-CUDA-01: discard Stage 23 report 20260620-01 as acceptance
evidence because it used a CPU-only `build-cov` build. Restart the full matrix
from S01 after CUDA build and launch proof.

Decision D23-CUDA-02: require every Stage 23 execution report to prove NVIDIA
CUDA execution before accepting any row. Required evidence:

- `build-cov/CMakeCache.txt` has `GGML_CUDA:BOOL=ON`.
- `llama-server.exe --list-devices` lists CUDA0/CUDA1 NVIDIA devices.
- Wrapper dry-run includes `--n-gpu-layers all` and `--fit off`.
- Live startup log shows CUDA devices and layer offload.
- `nvidia-smi` during live launch shows `llama-server.exe` as a compute
  process or startup log shows CUDA model/KV/compute buffers.

## Evidence

- Configure: `cmake -S . -B build-cov -DGGML_CUDA=ON -DCUDAToolkit_ROOT=D:\app\cuda_13_2`
  found CUDAToolkit 13.2 and included CUDA backend.
- Build: clean build of `test-cache-controller` and `llama-server` passed.
- Unit smoke: `test-cache-controller.exe` passed 112 tests.
- Binary freshness: `ggml-cuda.dll`, `llama-server.exe`,
  `llama-server-impl.dll`, and `test-cache-controller.exe` rebuilt on
  2026-06-20 23:56-23:57.
- Device listing: `llama-server.exe --list-devices` listed CUDA0 and CUDA1,
  both NVIDIA GeForce RTX 5060 Ti.
- CUDA smoke: `._test_output/stage23-cuda-smoke-20260621-03-fitoff/server.err.log`
  showed `offloaded 34/34 layers to GPU`, CUDA0/CUDA1 model buffers, CUDA0/CUDA1
  KV buffers, and CUDA0/CUDA1 compute buffers.
- Telemetry: `._test_output/stage23-cuda-smoke-20260621-03-fitoff/compute-1.txt`
  showed `llama-server.exe` in the NVIDIA compute-app list.
- Wrapper dry-run: `._test_output/stage23-cuda-dryrun-02/batch-summary.log.side`
  showed `--n-gpu-layers all --fit off`.

## Harness change accepted

`kickoff-stage20-stress-longrun.ps1` now adds these reviewed launch flags to
every row through the existing Stage 17 encoded argument path:

- `--n-gpu-layers all`
- `--fit off`

The flags are part of the wrapper dry-run validation set. If either flag is
missing, wrapper dry-run fails and QA execution must stop.

## Handoff

Next owner: QA execution. Restart Stage 23 from S01 with a fresh durable report.
Do not reuse S01/S02 evidence from report 20260620-01.

This file uses plain ASCII text and stays under the 300-line durable-doc cap.
