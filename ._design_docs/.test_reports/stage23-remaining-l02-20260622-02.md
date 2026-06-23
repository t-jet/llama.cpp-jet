# Stage 23 L02 focused rerun 20260622-02

Verdict: PASS
Owner: QA
Scope: L02 only after Architect-approved runner fix. L03 was not run.
Run window: 2026-06-22 20:18 to 20:49 Europe/Sofia.

## Inputs

- Primary model: `D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- Evidence root: `._test_output/stage23-remaining-l02-20260622-02`
- Row root: `._test_output/stage23-remaining-l02-20260622-02/L02-Jnew`
- Cold path: `D:\tmp\cache-cold-stage23-stage23-remaining-l02-20260622-02`
- Prompt evidence: `._test_output/stage23-remaining-l02-20260622-02/prompt-evidence/cache-prompt-evidence.jsonl`
- Base port: 8900. L02 used 8900 for `legacy-control` and 8901 for `hybrid-stage23`.
- Suffix choice: `-02` was the next chronological focused L02 suffix and was unused for report, output root, and cold root.

## Acceptance gate

Required scope was L02 only, with the fixed legacy comparison runner and the
30 minute row cap split into a 900 second legacy leg and a 900 second hybrid
leg. Required evidence: clean build, CUDA, fixture, ports, cold path, disk,
dry-run comparison plan, live wrapper exit 0, `row_gate`, `batch_end`, before
and after metrics, non-PENDING root summary, `l02-comparison.json`, redacted
hybrid evidence, clean scans, and hybrid cold bytes at or below 512 MiB.

Result: PASS. The fixed runner produced both legs and the comparison artifact.
L03 was not selected in dry-run or live execution.

## Preflight

| Gate | Result | Evidence |
| --- | --- | --- |
| Branch | PASS | `preflight/01-branch.log`: `work-branch` |
| Git status | PASS with dirty tree | `preflight/02-git-status.log`; dirty tree preserved |
| CUDA configure | PASS | `preflight/03-cmake-cuda.log`: `GGML_CUDA:BOOL=ON` |
| CUDA runtime | PASS | both leg `server.err.log` files show CUDA0/CUDA1 RTX 5060 Ti and CUDA system info |
| GPU process | PASS | `preflight/18-nvidia-smi-live-201831.log` captured during live row |
| Model fixture | PASS | `preflight/04-model-fixture.log` |
| Port range | PASS | `preflight/05-port-listeners-8900-8921.log`; no blockers before run |
| Cold path | PASS | `preflight/07-cold-path-before.log`; empty |
| Disk | PASS | `preflight/06-disk.log`; D free space above 30 GiB |

## Clean build

| Step | Result | Evidence |
| --- | --- | --- |
| CMake clean | PASS | `preflight/09-clean.log`, exit 0 |
| Build `test-cache-controller` | PASS | `preflight/10-build-test-cache-controller.log`, exit 0 |
| Build `llama-server` | PASS | `preflight/11-build-llama-server.log`, exit 0 |
| Run `test-cache-controller` | PASS | `preflight/12-test-cache-controller.log`: 120 tests passed |
| Binary freshness | PASS | `preflight/13-binary-freshness.log`: server exe 20:17:43, impl DLL 20:17:42 |

## Dry-run gate

Dry-run result: PASS.

Evidence:

- `preflight/15-wrapper-dry-run.out.log`
- `preflight/15-wrapper-dry-run.exit.txt`: exit 0
- `batch-summary.log.side`

Required dry-run checks passed:

- L02 only, `BatchSize 1`.
- Comparison plan printed:
  `rowCapSeconds=1800 legacy_control_seconds=900 hybrid_stage23_seconds=900 legacy_mode=legacy hybrid_mode=hybrid comparison_artifact=l02-comparison.json`.
- Legacy filter list printed:
  `cache-cold-max-mib,cache-cold-path,cache-prompt-evidence,cache-prompt-evidence-dir`.
- Hybrid Stage 23 flags printed: `--cache-mode hybrid`,
  `--cache-cold-max-mib 512`, `--cache-ram 512`, `--n-gpu-layers all`,
  `--fit off`, cold path, redacted evidence, evidence dir, model path, and
  run root.

## Live L02

Wrapper OS exit: 0.

Side-log gates:

- `batch_gate #1 ports=8900 listeners= ... coldItems=0 runRootWritable=true`
- `launched L02 port=8900 ... hours=0 min=30`
- `L02 comparison_plan rowCapSeconds=1800 legacy_control_seconds=900 hybrid_stage23_seconds=900`
- `row_gate L02 exitCode=0 ok=True evidenceFiles=30 present=server.out.log,server.err.log,metrics-before.txt,metrics-after.txt,l02-comparison.json,evidence-summary.md missing=`
- `batch_end #1 idx=0-0`
- `kickoff-stage20-stress-longrun end; rows=1 ok=True`

Comparison artifact:

- Path: `L02-Jnew/l02-comparison.json`
- Status: `PASS`
- Root summary: `L02-Jnew/evidence-summary.md`, `Result: PASS`

## Legacy comparison

| Item | Legacy control | Hybrid Stage 23 |
| --- | ---: | ---: |
| Mode | legacy | hybrid |
| Port | 8900 | 8901 |
| Planned seconds | 900 | 900 |
| Requests | 30 | 30 |
| Live samples | 30 | 30 |
| `cache_n` sum | 145 | 0 |
| `llamacpp_cache_misses_total` delta | 0 | 30 |
| `cache_prompt_evidence_records_total` delta | 0 | 30 |
| `cache_checkpoint_admissions_by_shape_total` delta | 0 | 1 |
| `cache_cold_bytes` after | 0 | 0 |
| `cache_cold_budget_bytes` after | -1 | 536870912 |

Legacy flag filter result:

- Removed from legacy leg: `--cache-mode hybrid`,
  `--cache-cold-max-mib 512`, `--cache-cold-path <cold path>`,
  `--cache-prompt-evidence redacted`, and
  `--cache-prompt-evidence-dir <prompt evidence dir>`.
- Kept on legacy leg: CUDA, fit off, model template, metrics, context, seed,
  temperature, and `--cache-ram 512`.
- Hybrid leg kept cold budget, cold path, redacted prompt evidence, CUDA all,
  fit off, model, and run root.

Timing evidence from server stderr:

| Leg | Count | Prompt median / p95 / max ms | Total median / p95 / max ms |
| --- | ---: | --- | --- |
| legacy-control | 30 | 337.69 / 342.18 / 364.08 | 348.86 / 353.63 / 375.67 |
| hybrid-stage23 | 30 | 372.39 / 390.66 / 399.01 | 383.75 / 402.09 / 410.14 |

## Scans and budget

- Hybrid redacted evidence: 30 JSONL records.
- Raw prompt leak scan: 0 matches for raw `"prompt"`, `"messages"`,
  `"content"`, `"role"`, or `S12-L02 legacy comparison probe`.
- Unexpected HTTP 500/fatal/STATUS_STACK/exception/write-failure/corrupt/error
  scan: only Prometheus HELP/TYPE and zero-valued
  `llamacpp_cache_demotion_failure_write_error_total` lines matched the word
  `error`; no product error evidence found.
- Cold path files: 0.
- Cold bytes on disk: 0, below 512 MiB.
- Hybrid `cache_cold_bytes`: 0 with `cache_cold_budget_bytes` 536870912.

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
  -RunRoot ._test_output\stage23-remaining-l02-20260622-02 `
  -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
  -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-l02-20260622-02 `
  -CachePromptEvidenceDir ._test_output\stage23-remaining-l02-20260622-02\prompt-evidence `
  -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted `
  -JinjaVariant new -BasePort 8900 -BatchSize 1 -DryRun
```

The same wrapper command without `-DryRun` ran live L02.

## Handoff

L02 is PASS. L03 remains not run.

Next owner: Manager to open L03.
