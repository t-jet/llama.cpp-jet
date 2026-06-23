# Stage 23 L02 focused run 20260622-01

Verdict: BLOCKED-runner-contract
Owner: QA
Scope: L02 only. L03 was not run.
Run window: 2026-06-22 18:56 to 19:28 Europe/Sofia.

## Inputs

- Primary model: `D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- Evidence root: `._test_output/stage23-remaining-l02-20260622-01`
- Row root: `._test_output/stage23-remaining-l02-20260622-01/L02-Jnew`
- Cold path: `D:\tmp\cache-cold-stage23-stage23-remaining-l02-20260622-01`
- Prompt evidence: `._test_output/stage23-remaining-l02-20260622-01/prompt-evidence/cache-prompt-evidence.jsonl`
- Base port: 8900. Preflight found no listeners in 8900..8921.
- Suffix choice: `-01` was unused for focused L02 report, output root, and cold root.

## Acceptance gate

L02 is the Stage 23 30 minute legacy-comparison row. The user gate required
L02-only dry-run/live execution, clean build, CUDA runtime, wrapper exit 0,
`row_gate`, `batch_end`, metrics before and after, redacted evidence, request
count, timings, cache mode evidence, row-specific comparison evidence, clean
redaction scan, clean error scan, and cold bytes at or below 512 MiB when the
cold path is active.

Result: setup and live product behavior were clean, but the row runner did not
produce legacy comparison evidence. The L02 child script ran one hybrid-mode
reproducibility leg and left `evidence-summary.md` at `PENDING` with the note
`QA compares shape to paired benchmark row`. No legacy leg, paired baseline, or
comparison artifact was produced. This is a runner contract block, not a
product failure.

## Preflight

| Gate | Result | Evidence |
| --- | --- | --- |
| Branch | PASS | `preflight/01-branch.log`: `work-branch` |
| Git status | PASS with dirty tree | `preflight/02-git-status.log`; dirty tree preserved |
| CUDA configure | PASS | `preflight/03-cmake-cuda.log`: `GGML_CUDA:BOOL=ON` |
| CUDA runtime | PASS | `L02-Jnew/server.err.log`: CUDA0/CUDA1 RTX 5060 Ti and CUDA system info |
| GPU process | PASS | `preflight/19-nvidia-smi-live-185640.log`: `llama-server.exe` on both GPUs |
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
| Binary freshness | PASS | `preflight/13-binary-freshness.log`: server exe and impl DLL mtimes recorded |

## Dry-run gate

Dry-run result: PASS.

Evidence:

- `preflight/15-wrapper-dry-run.out.log`
- `preflight/15-wrapper-dry-run.exit.txt`: exit 0
- `batch-summary.log.side`

Required dry-run checks passed:

- L02 only.
- Wrapper flags included `--cache-mode hybrid`, `--cache-cold-max-mib 512`,
  `--cache-ram 512`, `--n-gpu-layers all`, `--fit off`, cold path, redacted
  evidence, evidence dir, model path, run root, Jinja `new`, and `BatchSize 1`.

Mode finding:

- The wrapper and child script ran hybrid mode only.
- The child script's base flags also include `--cache-mode hybrid --parallel 1 --cache-ram 100`.
- Stage 17 wrapper flags append another `--cache-mode hybrid --cache-ram 512`.
- No legacy-mode dry-run leg is present.

## Live L02

Wrapper result: PASS as process execution. The wrapper OS exit code was 0.

Evidence:

- Wrapper stdout/stderr: `preflight/16-wrapper-live.out.log`, `preflight/17-wrapper-live.err.log`
- Wrapper exit: `preflight/16-wrapper-live.exit.txt`
- Side log: `batch-summary.log.side`
- Row files: `L02-Jnew/evidence-summary.md`, `metrics-before.txt`,
  `metrics-after.txt`, `resource-samples.csv`, `snapshot-10m.csv`,
  `snapshot-20m.csv`, `server.err.log`, `server.out.log`, `launch.log`,
  `launch.err`

Live gates:

- `batch_gate #1 ports=8900 listeners= ... coldItems=0 runRootWritable=true`
- `launched L02 port=8900 ... longrun_s12_l02_30m_legacy_comparison.ps1 ... hours=0 min=30 flags='--cache-mode hybrid ...'`
- `row_gate L02 exitCode=0 ok=True evidenceFiles=10 present=server.out.log,server.err.log,metrics-before.txt,metrics-after.txt missing=`
- `batch_end #1 idx=0-0`
- `kickoff-stage20-stress-longrun end; rows=1 ok=True`

Runtime summary:

| Metric | Value |
| --- | ---: |
| Wrapper runtime | 18:56:36 to 19:28:42 |
| Row gate runtime | 18:56:37 to 19:27:05 |
| Script duration | 1800 seconds |
| Requests / samples | 60 |
| First / last sample elapsed | 0 s / 1794 s |
| Server liveness samples | 60/60 true |
| Process status | alive through final metrics; stopped by row script |

Timing evidence from `server.err.log`:

| Timing | Count | Median | p95 | Max |
| --- | ---: | ---: | ---: | ---: |
| prompt eval ms | 60 | 373.97 | 391.86 | 395.16 |
| eval ms | 60 | 11.32 | 11.59 | 11.92 |
| total ms | 60 | 385.30 | 403.15 | 406.34 |

Resource stability:

| Window | Working set delta | Handle delta | Result |
| --- | ---: | ---: | --- |
| Full run | +0.0351% | +14.9020% | warmup growth only |
| After 10m warmup | +0.0001% | 0.0000% | PASS |

## Metrics and scans

| Metric | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `llamacpp_cache_misses_total` | 0 | 60 | +60 |
| `llamacpp_cache_hits_total` | 0 | 0 | 0 |
| `llamacpp_cache_entries` | 0 | 1 | +1 |
| `llamacpp_cache_bytes` | 0 | 53019691 | +53019691 |
| `cache_restore_misses_total` | 0 | 60 | +60 |
| `cache_prompt_evidence_records_total` | 0 | 60 | +60 |
| `cache_cold_bytes` | 0 | 0 | 0 |
| `cache_cold_budget_bytes` | 536870912 | 536870912 | 0 |
| `cache_checkpoint_admissions_by_shape_total` | 0 | 1 | +1 |
| `cache_cold_evictions_total` | 0 | 0 | 0 |
| `cache_cold_demotions_skipped_total` | 0 | 0 | 0 |

Cold path files: 0. Cold bytes on disk: 0, below 512 MiB.

Scans:

- Redacted prompt evidence: 60 JSONL records.
- Raw prompt leak scan: 0 matches for raw `"prompt"`, `"messages"`,
  `"content"`, `"role"`, or the L02 prompt literal.
- Error scan: 28 generic matches, all metric help/name lines or zero-valued
  failure/mismatch metrics. No HTTP 500, crash, exception, corrupt restore,
  write failure, host allocation failure, or product error evidence.

## Runner contract blocker

The row script `longrun_s12_l02_30m_legacy_comparison.ps1` did not satisfy the
Stage 23 L02 legacy-comparison evidence contract:

- It ran one hybrid server leg only.
- It did not start a legacy-mode control leg.
- It did not write a paired baseline or comparison file.
- `evidence-summary.md` ended with `Result: PENDING`.
- Timing stats were recoverable from server logs, but no row-owned comparison
  artifact tied those timings to a legacy baseline.

## Commands run

```powershell
cmake --build build-cov --config Release --target clean
cmake --build build-cov --config Release --target test-cache-controller -j 4
cmake --build build-cov --config Release --target llama-server -j 4
.\build-cov\bin\Release\test-cache-controller.exe
```

```powershell
& ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 `
  -RowsToRun @('L02') `
  -RunRoot ._test_output\stage23-remaining-l02-20260622-01 `
  -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
  -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-l02-20260622-01 `
  -CachePromptEvidenceDir ._test_output\stage23-remaining-l02-20260622-01\prompt-evidence `
  -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted `
  -JinjaVariant new -BasePort 8900 -BatchSize 1 -DryRun
```

The same wrapper command without `-DryRun` ran live L02 for 30 minutes.

## Handoff

L02 is BLOCKED-runner-contract. L03 remains not run.

Next owner: Manager to decide whether to send a Developer runner-fix task for
true legacy comparison evidence or accept a revised L02 contract. Do not open
L03 until L02 disposition is resolved.
