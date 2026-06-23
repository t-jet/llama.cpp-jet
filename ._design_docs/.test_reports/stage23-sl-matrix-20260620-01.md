# Stage 23 S/L matrix execution report 20260620-01

Status: BLOCKED-invalid-CPU-only
Date: 2026-06-20
Owner: QA
Scope: Stage 23 S01..S08 and L01..L03, stopped after CPU-only execution was found.

## Verdict

Overall verdict: BLOCKED-invalid-CPU-only.

The matrix is paused. The clean build used `build-cov`, whose
`CMakeCache.txt` records `GGML_CUDA:BOOL=OFF`. During live S02,
`nvidia-smi` showed 0 MiB on both RTX 5060 Ti GPUs and no compute
processes, while `llama-server.exe` PID 9792 ran with high CPU. S02
startup logs show CPU backend lines only. Stage 23 must not continue
until the build and launch are verified to use CUDA/NVIDIA execution.

## Preflight and build

| Check | Result | Evidence |
| --- | --- | --- |
| Run id | PASS | `._test_output/stage23-sl-matrix-20260620-01/` |
| Git status captured | PASS | `preflight/02-git-status.txt`; worktree was already dirty before this QA run. |
| Fixture present | PASS | `preflight/05-fixture.txt`; Qwen3.5-4B-MTP GGUF and templates present. |
| Ports 8800..8821 before run | PASS | `preflight/06-port-listeners.txt`; no listeners. |
| Disk headroom | PASS | `preflight/07-disk.txt`; D: free space about 1.60 TB. |
| Clean build | PASS | `preflight/build-summary.json`; clean, `test-cache-controller`, `llama-server`, and controller smoke all exit 0. |
| Binary freshness | PASS | `preflight/13-binary-freshness.txt`; `llama-server.exe`, `llama-server-impl.dll`, and `test-cache-controller.exe` mtimes recorded. |
| Wrapper dry-run | PASS after narrow harness fix | `preflight/14b-wrapper-dry-run-after-harness-fix.log`; all 11 rows listed with Stage 17 flags and Qwen3.5 path. |
| CUDA build verification | FAIL | `build-cov/CMakeCache.txt`: `GGML_CUDA:BOOL=OFF`. |

## Harness corrections

Two narrow wrapper fixes were made before the CPU-only stop:

- `kickoff-stage20-stress-longrun.ps1`: renamed `Convert-ArgsToBase64`
  parameter `$Args` to `$ServerArgs`; `$Args` collided with PowerShell
  automatic `$args` and blocked live launch before any row started.
- `kickoff-stage20-stress-longrun.ps1`: replaced hardcoded PowerShell
  7.6.2 path with `Get-Command pwsh` discovery; this host has PowerShell
  7.6.3, so the hardcoded path caused `LAUNCH_FAIL` for all rows.

These are harness-only changes. No production C++ code was edited by QA.

## Stop evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Active CPU-only process | CONFIRMED | `pause-20260620-2345/01-process-before-stop.txt`; `llama-server.exe` PID 9792, high CPU, port 8805 command line. |
| GPU state before stop | CONFIRMED | `pause-20260620-2345/03-nvidia-smi-before-stop.txt`; both GPUs at 0 MiB, no running processes. |
| Emergency metrics | CAPTURED | `pause-20260620-2345/04-metrics-port-8805.txt`. |
| Stop actions | PASS | `pause-20260620-2345/05-stop-actions.txt`; stopped PID 9792 and child `pwsh` PID 20128. |
| Cleanup after stop | PASS | `pause-20260620-2345/07-listeners-after-stop.txt`; no 8800..8821 listeners. |
| GPU state after stop | PASS | `pause-20260620-2345/08-nvidia-smi-after-stop.txt`; no running processes. |

## Stress rows

| Row | Verdict | State | Evidence |
| --- | --- | --- | --- |
| S01 | INVALID-CPU-only | Completed 30m, 1219 cache misses, but run is invalid for Stage 23 because build was CPU-only. | `S01-Jnew/cold-off/evidence-summary.md`, `metrics-before.txt`, `metrics-after.txt`, `server.err.log`; row gate at `batch-summary.log.side` line with `row_gate S01 exitCode=0`. |
| S02 | BLOCKED-invalid-CPU-only-stopped | Interrupted by user pause. Active CPU-only server PID 9792 stopped. No `metrics-after.txt` or row gate because row was stopped mid-run. | `S02-Jnew/parallel4/metrics-before.txt`, `server.err.log`, `resource-samples.csv`, pause artifacts. |
| S03 | NOT-RUN | Matrix stopped before row. | `batch-summary.log.side` has only earlier stale `LAUNCH_FAIL` from the pre-fix launcher attempt. |
| S04 | NOT-RUN | Matrix stopped before row. | Same as S03. |
| S05 | NOT-RUN | Matrix stopped before row. | Same as S03. |
| S06 | NOT-RUN | Matrix stopped before row. | Same as S03. |
| S07 | NOT-RUN | Matrix stopped before row. | Same as S03. |
| S08 | NOT-RUN | Matrix stopped before row. | Same as S03. |

## Longrun rows

| Row | Verdict | State | Evidence |
| --- | --- | --- | --- |
| L01 | NOT-RUN | Matrix stopped before longrun phase. | none |
| L02 | NOT-RUN | Matrix stopped before longrun phase. | none |
| L03 | NOT-RUN | Matrix stopped before longrun phase. | none |

## Current row state

S02 was active at pause time. The wrapper had launched child `pwsh` PID 20128
for `stress_s12_s02_concurrent_multi_slot.ps1`. That child started
`llama-server.exe` PID 9792. The server command line used hybrid cache flags
and Qwen3.5 model path but had no CUDA launch proof, and the build cache shows
CUDA disabled.

S02 evidence is partial and not valid for Stage 23 acceptance:

- `._test_output/stage23-sl-matrix-20260620-01/S02-Jnew/parallel4/server.err.log`
- `._test_output/stage23-sl-matrix-20260620-01/S02-Jnew/parallel4/metrics-before.txt`
- `._test_output/stage23-sl-matrix-20260620-01/S02-Jnew/parallel4/resource-samples.csv`
- `._test_output/stage23-sl-matrix-20260620-01/pause-20260620-2345/`

## Blockers and next owner

Blocker: Stage 23 execution used a CPU-only `build-cov` build. The current
build cache has `GGML_CUDA:BOOL=OFF`, and live GPU telemetry confirms no CUDA
process was active.

Next owner: Manager/Developer to provide or approve a CUDA-enabled `build-cov`
configuration and launch contract, including command evidence that CUDA is ON
and live `nvidia-smi` evidence showing `llama-server.exe` consuming GPU memory
before QA resumes any S/L row.

QA resume rule: discard S01/S02 as acceptance evidence. Re-run the full matrix
from S01 after CUDA/NVIDIA execution is verified.
