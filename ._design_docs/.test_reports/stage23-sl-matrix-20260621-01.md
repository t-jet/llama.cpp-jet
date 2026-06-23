# Stage 23 S/L matrix execution report 20260621-01

Status: FAIL-bug-handoff
Date: 2026-06-21
Owner: QA
Scope: Stage 23 S01..S08 and L01..L03 CUDA restart from S01 after D23-CUDA-01/02.

## Verdict

Overall verdict: FAIL-bug-handoff.

This report is the fresh CUDA-gated restart. Report
`stage23-sl-matrix-20260620-01.md` is not reused because Manager decision
D23-CUDA-01 invalidated it as CPU-only evidence.

Execution stopped at S03. S01 and S02 passed with CUDA proof. S03 started under
CUDA, served request traffic, then `llama-server.exe` exited before the row
could capture `metrics-after.txt` or write `evidence-summary.md`. The wrapper
row gate still exited 0 but listed only `server.out.log`, `server.err.log`, and
`metrics-before.txt`; the stricter Stage 23 evidence gate rejects the row.

## Evidence roots

- Durable report: `._design_docs/.test_reports/stage23-sl-matrix-20260621-01.md`
- Non-durable output: `._test_output/stage23-sl-matrix-20260621-01/`
- Preflight output: `._test_output/stage23-sl-matrix-20260621-01/preflight/`

## Gate log

| Gate | Verdict | Evidence |
| --- | --- | --- |
| Preflight | PASS | `preflight/preflight-summary.json`; fixture present, ports 8800..8821 clear, D: free about 1.60 TB, cold path empty. |
| Clean build and freshness | PASS | `preflight/build-summary.json`; clean, `test-cache-controller`, `llama-server`, and controller smoke all exit 0. `preflight/13-binary-freshness.txt` records `llama-server.exe`, `llama-server-impl.dll`, and `test-cache-controller.exe` mtimes. |
| CUDA CMakeCache | PASS | `preflight/15-cmake-cuda.txt`: `GGML_CUDA:BOOL=ON`. |
| Device listing | PASS | `preflight/16-list-devices.txt`: CUDA0 and CUDA1 are NVIDIA GeForce RTX 5060 Ti. |
| Wrapper dry-run | PASS | `preflight/14-wrapper-dry-run-summary.json`, `preflight/17-dry-run-gate.json`, and `batch-summary.log.side`; all 11 rows include `--n-gpu-layers all`, `--fit off`, `--cache-mode hybrid`, and Qwen3.5 MTP path. |
| Live CUDA proof | PASS | `cuda-smoke-verbose/server-startup.log` shows CUDA0/CUDA1, `offloaded 34/34 layers to GPU`, CUDA model buffers, and CUDA KV buffers. `cuda-smoke-verbose/nvidia-smi-*.txt` shows live `llama-server.exe` compute process on both GPUs. |

## Stress rows

| Row | Verdict | Wall time | Evidence path | Cold budget | Prompt evidence | Key metrics | Warnings | Retry | Next action |
| --- | --- | ---: | --- | --- | --- | --- | --- | ---: | --- |
| S01 | PASS | 30m | `._test_output/stage23-sl-matrix-20260621-01/S01-Jnew/cold-off/` | PASS: `cache_cold_bytes=0`, budget `536870912` | PASS: 1564 redacted records; JSONL tail has hashes and token counts only | hits 0, misses 1564, restore misses 1564 `exact_entry_absent`, checkpoint admission failure 1 `descriptor` | 0 warning/error matches; no corrupt/unsafe/raw/host allocation evidence | 0 | Complete. |
| S02 | PASS | 60m | `._test_output/stage23-sl-matrix-20260621-01/S02-Jnew/parallel4/`; `.../parallel8/` | PASS: both phases `cache_cold_bytes=0`, budget `536870912` | PASS: redacted records written; JSONL tail has hashes and token counts only | p4 hits 0, misses 4456; p8 hits 0, misses 7096; restore misses are bounded `exact_entry_absent` | 0 warning/error matches in both phase logs | 0 | Complete. |
| S03 | FAIL-server-exited-before-final-evidence | ~31m wrapper; server log ends at ~18s | `._test_output/stage23-sl-matrix-20260621-01/S03-Jnew/` | FAIL: no after metrics; server log shows resident payload above 512 MiB budget and repeated `eviction could not satisfy payload budget` before exit | PARTIAL: redacted JSONL records were written before exit, but row final evidence missing | row gate exit 0 but `present=server.out.log,server.err.log,metrics-before.txt`; no `metrics-after.txt`, no `evidence-summary.md`, no `cap-exit.json`; `launch.err` has connection refused on final `/metrics` | Many bounded warnings before exit: payload budget unsatisfied, demotion queue full, immediate eviction fallback; no final metrics scrape | 0 | Stop matrix; Developer owns failure triage. |
| S04 | NOT-RUN | - | - | - | - | - | - | 0 | Not run after S03 FAIL. |
| S05 | NOT-RUN | - | - | - | - | - | - | 0 | Not run after S03 FAIL. |
| S06 | NOT-RUN | - | - | - | - | - | - | 0 | Not run after S03 FAIL. |
| S07 | NOT-RUN | - | - | - | - | - | - | 0 | Not run after S03 FAIL. |
| S08 | NOT-RUN | - | - | - | - | - | - | 0 | Not run after S03 FAIL. |

## Longrun rows

| Row | Verdict | Wall time | Evidence path | Cold budget | Prompt evidence | Key metrics | Warnings | Retry | Next action |
| --- | --- | ---: | --- | --- | --- | --- | --- | ---: | --- |
| L01 | NOT-RUN | - | - | - | - | - | - | 0 | Not run after S03 FAIL. |
| L02 | NOT-RUN | - | - | - | - | - | - | 0 | Not run after S03 FAIL. |
| L03 | NOT-RUN | - | - | - | - | - | - | 0 | Not run after S03 FAIL. |

## CUDA proof

CUDA gate passed before any row acceptance:

- `preflight/15-cmake-cuda.txt`: `GGML_CUDA:BOOL=ON`.
- `preflight/16-list-devices.txt`: CUDA0 and CUDA1 are NVIDIA GeForce RTX
  5060 Ti.
- `preflight/17-dry-run-gate.json`: all 11 dry-run rows include
  `--n-gpu-layers all` and `--fit off`.
- `cuda-smoke-verbose/server-startup.log`: CUDA0/CUDA1 device lines,
  `offloaded 34/34 layers to GPU`, CUDA model buffers, and CUDA KV buffers.
- `cuda-smoke-verbose/nvidia-smi-*.txt`: live `llama-server.exe` compute
  process on both GPUs.
- Row telemetry: S01 `nvidia-smi-live.txt`, S02 `parallel4/nvidia-smi-live.txt`,
  S02 `parallel8/nvidia-smi-live.txt`, and S03 `nvidia-smi-live.txt` all show
  live `llama-server.exe` on both GPUs.

## Failure evidence

S03 failure evidence:

- Row output: `._test_output/stage23-sl-matrix-20260621-01/S03-Jnew/`.
- Wrapper row gate:
  `row_gate S03 exitCode=0 evidenceFiles=7 present=server.out.log,server.err.log,metrics-before.txt`.
- Missing required files: `metrics-after.txt`, `evidence-summary.md`, and
  `cap-exit.json`.
- `launch.err`: final `/metrics` request failed with
  `No connection could be made because the target machine actively refused it`.
- `server.err.log`: server listened on port 8800, accepted workload traffic,
  recorded restore misses, then logged repeated payload-budget warnings and cold
  demotion queue pressure before the log stopped. Final tail includes
  `eviction could not satisfy payload budget`, `demotion queue full (32/32)`,
  and `falling back to immediate eviction`.

## Blockers and next owner

Blocker: S03 does not satisfy Stage 23 row acceptance. It lost the live server
before final metrics and row summary, under CUDA, after request-phase traffic.
This is a bug handoff, not acceptable PASS evidence.

Next owner: Developer. Investigate S03 large-branch-forest behavior under the
Qwen3.5 MTP fixture with CUDA flags, 512 MiB hot and cold budgets, and Stage 17
redacted evidence enabled. Start from `S03-Jnew/server.err.log` and
`S03-Jnew/launch.err`.

QA next state: blocked on Developer fix or Manager reclassification. Do not
continue S04..S08 or L01..L03 on this binary/gate without a new handoff.
