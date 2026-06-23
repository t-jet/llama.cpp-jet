# Stage 23 S06 focused rerun 20260622-01

Verdict: PASS
Owner: QA
Scope: S06 only after accepted S06 pressure-workload fix. S07, S08, L01, L02, and L03 were not run.
Run window: 2026-06-22 00:31 to 01:14 Europe/Sofia.

## Inputs

- Primary Stage 23 model note: `D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- S06 pressure fixture: `D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf`
- Report: `._design_docs/.test_reports/stage23-remaining-s06-20260622-01.md`
- Evidence root: `._test_output/stage23-remaining-s06-20260622-01`
- Row root: `._test_output/stage23-remaining-s06-20260622-01/S06-Jnew`
- Cold path: `D:\tmp\cache-cold-stage23-stage23-remaining-s06-20260622-01`
- Prompt evidence: `._test_output/stage23-remaining-s06-20260622-01/prompt-evidence/cache-prompt-evidence.jsonl`
- Base port: 8900. Preflight found no listeners in 8900..8921.
- Suffix choice: `stage23-remaining-s06-20260622-01` was unused for report, output root, and cold root.

## Accepted prior evidence

- S01/S02 PASS from valid CUDA rerun.
- S03 PASS: `._design_docs/.test_reports/stage23-s03-rerun-20260621-10.md`.
- S04 PASS: `._design_docs/.test_reports/stage23-remaining-s04-20260621-01.md`.
- S05 PASS: `._design_docs/.test_reports/stage23-remaining-s05-20260621-02.md`.
- S06 pressure-workload fix: `._design_docs/.test_reports/stage23-remaining-s06-20260621-02-fixes.md`.
- S06 pressure-workload review PASS: `._design_docs/.test_reports/stage23-remaining-s06-20260621-02-bugfix-review.md`.

## Preflight

| Gate | Result | Evidence |
| --- | --- | --- |
| Branch | PASS | `preflight/01-branch.txt`: `work-branch` |
| Git status | PASS with dirty tree | `preflight/02-git-status.txt`; dirty files pre-existed this QA run |
| CUDA configure | PASS | `preflight/08-cuda-cmake-cache.txt`: `GGML_CUDA:BOOL=ON` |
| CUDA runtime | PASS | `preflight/24-server-startup-key-lines.txt`: CUDA0/CUDA1 RTX 5060 Ti and CUDA system info |
| Primary fixture | PASS | `preflight/03-primary-fixture.txt` records Qwen3.5 path, size, mtime |
| Pressure fixture | PASS | `preflight/04-pressure-fixture.txt` records Qwen3-0.6B path, size, mtime |
| Port range | PASS | `preflight/05-port-listeners-8900-8921.txt`: no 8900..8921 listeners |
| Cold path | PASS | `preflight/07-cold-path-before.txt`: empty |
| Disk | PASS | `preflight/06-disk.txt`: D free 1599575871488 bytes |

## Clean build

| Step | Result | Evidence |
| --- | --- | --- |
| CMake clean | PASS | `preflight/11-clean.log` |
| Build `test-cache-controller` | PASS | `preflight/12-build-test-cache-controller.log` |
| Build `llama-server` | PASS | `preflight/13-build-llama-server.log` |
| Run `test-cache-controller` | PASS | `preflight/14-test-cache-controller.log`: 120 tests passed |
| Binary freshness | PASS | `preflight/15-binary-freshness.txt`; `llama-server.exe` and `llama-server-impl.dll` mtime 2026-06-22 00:43:29 |

## Dry-run gate

Dry-run command used S06 only with `CacheColdMaxMib 512`, wrapper
`CacheRamMib 512`, redacted prompt evidence, Jinja `new`, `BatchSize 1`,
base port 8900, and the S06 pressure fixture.

Result: PASS.

Evidence:

- `preflight/16-wrapper-dry-run.log`
- `preflight/17-wrapper-dry-run-side.log`
- `preflight/18-dry-run-checks.json`

Checks:

- S06 dry-run flags did not include wrapper `--cache-ram 512`.
- Side log has `DryRun S06 hot_budget effective_cache_ram_mib=16`.
- Side log has `DryRun S06 pressure_workload` with `pressure_model_state=available`.
- Required Stage 23 flags were present: `--cache-mode hybrid`, `--cache-cold-max-mib 512`, `--n-gpu-layers all`, `--fit off`, cold path, redacted evidence, and evidence dir.

## Live S06

Result: PASS.

Evidence:

- Wrapper stdout/stderr: `preflight/19-wrapper-live.out.log`, `preflight/20-wrapper-live.err.log`
- Wrapper exit code: `preflight/21-wrapper-live-exit-code.txt`: 0
- Side log key lines: `preflight/23-side-log-key-lines.txt`
- Row files: `S06-Jnew/evidence-summary.md`, `metrics-before.txt`, `metrics-after.txt`, `resource-samples.csv`, `server.err.log`, `server.out.log`, `launch.log`, `launch.err`
- Verification summary: `preflight/22-evidence-checks.json`

Wrapper result:

- `row_gate S06 exitCode=0 ok=True`
- `batch_end #1 idx=0-0`
- `kickoff-stage20-stress-longrun end; rows=1 ok=True`

Model and budget evidence:

- Wrapper side log: `S06 pressure_workload pressure_model=...\Qwen3-0.6B-Q8_0.gguf pressure_model_state=available`.
- Evidence summary model fixture: `Qwen3-0.6B-Q8_0.gguf`.
- Evidence summary notes: `primary model Qwen3.5-4B-Q4_K_M.gguf; pressure model Qwen3-0.6B-Q8_0.gguf`.
- Server startup: `limits: 16.000 MiB payload, 512 tokens`.
- Server flags include `--cache-ram 16` and `--cache-cold-max-mib 512`.
- Server loaded `Qwen3-0.6B-Q8_0.gguf`.

CUDA evidence:

- `server.err.log` lists CUDA0 and CUDA1 RTX 5060 Ti.
- Preflight CMake cache has `GGML_CUDA:BOOL=ON`.

## Metrics and pressure checks

| Check | Result | Evidence |
| --- | --- | --- |
| Requests | PASS | `Request count 1605`; `llamacpp_cache_misses_total{mode="hybrid"} 1605` |
| Redacted JSONL | PASS | 1605 records, 491760 bytes |
| Raw prompt leak scan | PASS | no S06 raw prompt needles in JSONL or server log |
| HTTP 500/error/corrupt/write-failure scan | PASS | counts all 0 |
| Hot budget | PASS | 16 MiB effective hot payload limit |
| Cold budget | PASS | `cache_cold_bytes 534368500` <= `cache_cold_budget_bytes 536870912` |
| Cold pressure | PASS | 1604 demotions and 1467 cold evictions |

Key after-metrics:

- `llamacpp_cache_payload_demotions_total{mode="hybrid"} 1604`
- `cache_cold_evictions_total{mode="hybrid",reason="cold_budget_pressure",payload_kind="exact_blob"} 1467`
- `llamacpp_cache_payload_cold_evictions_total{mode="hybrid"} 1467`
- `cache_cold_demotions_skipped_total{mode="hybrid"} 0`
- `llamacpp_cache_demotion_failure_write_error_total{mode="hybrid"} 0`
- `cache_prompt_evidence_records_total{mode="redacted",result="written"} 1605`
- Cold path on disk: 137 files, 534377268 bytes

S06 created cold queue pressure under the intended 16 MiB hot budget and bounded
512 MiB cold budget. The required pressure condition is satisfied by non-zero
demotions and cold evictions before any write failure.

## Handoff

Focused S06 PASS. S07, S08, L01, L02, and L03 remain not run in this session.
Next owner: Manager to open S07.
