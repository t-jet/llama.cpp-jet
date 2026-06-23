# Stage 23 L01 focused run 20260622-01

Verdict: PASS
Owner: QA
Scope: L01 only. L02 and L03 were not run.
Run window: 2026-06-22 16:40 to 18:42 Europe/Sofia.

## Inputs

- Primary model: `D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- Evidence root: `._test_output/stage23-remaining-l01-20260622-01`
- Row root: `._test_output/stage23-remaining-l01-20260622-01/L01-Jnew`
- Cold path: `D:\tmp\cache-cold-stage23-stage23-remaining-l01-20260622-01`
- Prompt evidence: `._test_output/stage23-remaining-l01-20260622-01/prompt-evidence/cache-prompt-evidence.jsonl`
- Base port: 8900. Preflight found no listeners in 8900..8921.
- Suffix choice: `-01` was unused for focused L01 report, output root, and cold root.

## Acceptance gate

L01 hybrid stability runs the Stage 12 six-hour script with the Stage 23 V2
cap of two hours. PASS requires clean build, CUDA runtime, L01-only dry-run,
wrapper exit 0, `row_gate`, `batch_end`, metrics before and after, redacted
evidence, stable liveness/resource samples, no crash or host allocation
failure, and cold bytes at or below 512 MiB.

Result: requirements met.

## Preflight

| Gate | Result | Evidence |
| --- | --- | --- |
| Branch | PASS | `preflight/01-branch.log`: `work-branch` |
| Git status | PASS with dirty tree | `preflight/02-git-status.log`; dirty tree preserved |
| CUDA configure | PASS | `preflight/03-cmake-cuda.log`: `GGML_CUDA:BOOL=ON` |
| CUDA runtime | PASS | `L01-Jnew/server.err.log`: CUDA0/CUDA1 RTX 5060 Ti and CUDA system info |
| GPU process | PASS | `preflight/19-nvidia-smi-live-164246.log`: `llama-server.exe` on both GPUs |
| Model fixture | PASS | `preflight/04-model-fixture.log` |
| Port range | PASS | `preflight/05-port-listeners-8900-8921.log`: no listeners |
| Cold path | PASS | `preflight/07-cold-path-before.log`: empty |
| Disk | PASS | `preflight/06-disk.log`: D free space above 30 GiB |

## Clean build

| Step | Result | Evidence |
| --- | --- | --- |
| CMake clean | PASS | `preflight/09-clean.log`, exit 0 |
| Build `test-cache-controller` | PASS | `preflight/10-build-test-cache-controller.log`, exit 0 |
| Build `llama-server` | PASS | `preflight/11-build-llama-server.log`, exit 0 |
| Run `test-cache-controller` | PASS | `preflight/12-test-cache-controller.log`, exit 0 |
| Binary freshness | PASS | `preflight/13-binary-freshness.log`: server exe and impl DLL mtime 2026-06-22 16:40:13 |

## Dry-run gate

Dry-run result: PASS.

Evidence:

- `preflight/15-wrapper-dry-run.out.log`
- `preflight/15-wrapper-dry-run.out.log.exit.txt`: exit 0
- `batch-summary.log.side`

Required dry-run checks passed:

- L01 only.
- `--cache-mode hybrid`.
- `--cache-cold-max-mib 512`.
- Wrapper `--cache-ram 512`.
- `--n-gpu-layers all`.
- `--fit off`.
- Cold path, redacted evidence, evidence dir, model path, run root, Jinja `new`, and `BatchSize 1`.

## Live L01

Wrapper result: PASS. The wrapper OS exit code was 0.

Evidence:

- Wrapper stdout/stderr: `preflight/16-wrapper-live.out.log`, `preflight/17-wrapper-live.err.log`
- Wrapper process log: `preflight/16-wrapper-live-process.log`
- Side log: `batch-summary.log.side`
- Row files: `L01-Jnew/evidence-summary.md`, `metrics-before.txt`, `metrics-after.txt`, `resource-samples.csv`, `snapshot-30m.csv`, `snapshot-60m.csv`, `snapshot-91m.csv`, `server.err.log`, `server.out.log`, `launch.log`, `launch.err`

Live gates:

- `batch_gate #1 ports=8900 listeners= ... coldItems=0 runRootWritable=true`
- `launched L01 port=8900 ... longrun_s12_l01_6h_hybrid_stability.ps1 ... hours=2 min=0 flags='--cache-mode hybrid --cache-cold-max-mib 512 --cache-ram 512 --n-gpu-layers all --fit off ...'`
- `row_gate L01 exitCode=0 ok=True evidenceFiles=11 present=server.out.log,server.err.log,metrics-before.txt,metrics-after.txt missing=`
- `batch_end #1 idx=0-0`
- `kickoff-stage20-stress-longrun end; rows=1 ok=True`

Runtime summary:

| Metric | Value |
| --- | ---: |
| Wrapper runtime | 16:40:45 to 18:42:50 |
| Row gate runtime | 16:40:46 to 18:41:39 |
| Script duration | 7200 seconds |
| Requests / samples | 120 |
| First / last sample elapsed | 0 s / 7188 s |
| Server liveness samples | 120/120 true |
| Reconnect or retry behavior | none observed |
| Process status | alive through final metrics; stopped by row script |

Resource stability:

| Window | Working set delta | Handle delta | Result |
| --- | ---: | ---: | --- |
| Full run | +0.041% | +14.902% | warmup growth only |
| After 30m warmup | +0.005% | 0.000% | PASS |
| After 60m warmup | +0.005% | 0.000% | PASS |

## Metrics and scans

| Metric | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `llamacpp_cache_misses_total{mode="hybrid"}` | 0 | 120 | +120 |
| `llamacpp_cache_hits_total{mode="hybrid"}` | 0 | 0 | 0 |
| `llamacpp_cache_entries{mode="hybrid"}` | 0 | 1 | +1 |
| `llamacpp_cache_bytes{mode="hybrid"}` | 0 | 53085275 | +53085275 |
| `cache_restore_misses_total{reason="exact_entry_absent"}` | 0 | 120 | +120 |
| `cache_prompt_evidence_records_total{mode="redacted",result="written"}` | 0 | 120 | +120 |
| `cache_cold_bytes{mode="hybrid"}` | 0 | 0 | 0 |
| `cache_cold_budget_bytes{mode="hybrid"}` | 536870912 | 536870912 | 0 |
| `cache_checkpoint_admissions_by_shape_total{policy="compat_required",result="failure",reason="descriptor"}` | 0 | 1 | +1 |

Cold path files: 0. Cold bytes on disk: 0, below 512 MiB.

Scans:

- Redacted prompt evidence: 120 JSONL records.
- Raw prompt leak scan: 0 matches for raw `"prompt"`, `"messages"`, `"content"`, `"role"`, or the L01 prompt literal.
- Error scan: 0 matches for `HTTP 500`, `STATUS_STACK`, `fatal`, `exception`, `write-failure`, `corrupt`, `descriptor validation failed`, `restore failure`, `mismatch`, `checksum`, `error`, `host allocation`, or `allocation failed`.
- `retry` and `reconnect` scan: 0 matches.

## Commands run

```powershell
cmake --build build-cov --config Release --target clean
cmake --build build-cov --config Release --target test-cache-controller -j 4
cmake --build build-cov --config Release --target llama-server -j 4
.\build-cov\bin\Release\test-cache-controller.exe
```

```powershell
& ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 `
  -RowsToRun @('L01') `
  -RunRoot ._test_output\stage23-remaining-l01-20260622-01 `
  -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
  -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-l01-20260622-01 `
  -CachePromptEvidenceDir ._test_output\stage23-remaining-l01-20260622-01\prompt-evidence `
  -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted `
  -JinjaVariant new -BasePort 8900 -BatchSize 1 -DryRun
```

The same wrapper command without `-DryRun` ran live L01 for two hours.

## Handoff

L01 is PASS. L02 and L03 remain not run.

Next owner: Manager to open L02.
