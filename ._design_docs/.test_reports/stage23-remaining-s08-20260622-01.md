# Stage 23 S08 focused run 20260622-01

Verdict: PASS
Owner: QA
Scope: S08 only. L01, L02, and L03 were not run.
Run window: 2026-06-22 15:29 to 16:22 Europe/Sofia.

## Inputs

- Primary model: `D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- Evidence root: `._test_output/stage23-remaining-s08-20260622-01`
- Row root: `._test_output/stage23-remaining-s08-20260622-01/S08-Jnew`
- Cold path: `D:\tmp\cache-cold-stage23-stage23-remaining-s08-20260622-01`
- Prompt evidence: `._test_output/stage23-remaining-s08-20260622-01/prompt-evidence/cache-prompt-evidence.jsonl`
- Base port: 8900. Preflight found no listeners in 8900..8921.
- Suffix choice: `-01` was unused for focused S08 report, output root, and cold root.

## Acceptance gate

S08 integrity behavior uses focused fault-injection evidence for internal
corruption paths that public HTTP cannot create, then runs a 30 minute live
load. PASS requires same-clean-build fault evidence, live row completion,
bounded diagnostics, no product crash, clean redacted evidence, and cold bytes
at or under 512 MiB.

Result: requirements met.

## Preflight

| Gate | Result | Evidence |
| --- | --- | --- |
| Branch | PASS | `preflight/01-branch.log`: `work-branch` |
| Git status | PASS with dirty tree | `preflight/02-git-status.log`; dirty tree preserved |
| CUDA configure | PASS | `preflight/03-cmake-cuda.log`: `GGML_CUDA:BOOL=ON` |
| CUDA runtime | PASS | `S08-Jnew/server.err.log`: CUDA0/CUDA1 RTX 5060 Ti and CUDA system info |
| GPU process | PASS | `preflight/22-nvidia-smi-live-155232.log`: `llama-server.exe` on both GPUs |
| Model fixture | PASS | `preflight/04-model-fixture.log` |
| Port range | PASS | `preflight/05-port-listeners-8900-8921.log`: no listeners |
| Cold path | PASS | `preflight/07-cold-path-before.log`: empty |
| Disk | PASS | `preflight/06-disk.log`: D free 1591393976320 bytes before live |

## Clean build and focused checks

| Step | Result | Evidence |
| --- | --- | --- |
| CMake clean | PASS | `preflight/09-clean.log`, exit 0 |
| Build `test-cache-controller` | PASS | `preflight/10-build-test-cache-controller.log`, exit 0 |
| Build `test-step11-test-hooks-fault-injection` | PASS | `preflight/11-build-test-step11-fault-injection.log`, exit 0 |
| Build `llama-server` | PASS | `preflight/12-build-llama-server.log`, exit 0 |
| Run `test-cache-controller` | PASS | `preflight/16-ctest-cache-controller-rerun.log`: 1/1 passed |
| Run fault-injection binary | PASS | `preflight/17-test-step11-fault-injection-rerun.log`: 17/17 passed |
| Binary freshness | PASS | `preflight/18-binary-freshness.log`: server exe and impl DLL mtime 2026-06-22 15:38:10 |

Note: the first direct `test-cache-controller.exe` process hung after the
controller log reached Stage 17 cold-store setup. It was stopped, preserved in
`preflight/13-test-cache-controller.log` and `13-test-cache-controller.hung.txt`,
then rerun through bounded `ctest`, which passed in 3.18 seconds.

Focused integrity evidence used for S08:

- `step11: fault injection - checksum corruption before promotion... PASSED`
- `step11: fault injection - header truncation (short write)... PASSED`
- `step11: fault injection - payload_id mismatch... PASSED`
- `step11: fault injection - pair_state mismatch... PASSED`
- `step11: fault injection - format_version unknown... PASSED`
- `step11: fault injection - demotion write failure... PASSED`
- `step11: fault injection - queue full at demotion... PASSED`
- `step11: fault injection - queue full at promotion... PASSED`
- `step11: fault injection - worker thread shutdown race... PASSED`
- `step11: fault injection - draft-side promotion failure for target_and_draft... PASSED`
- `step11: fault injection - magic mismatch... PASSED`
- `step11: fault injection - header checksum mismatch... PASSED`

## Dry-run gate

Dry-run result: PASS.

Evidence:

- `preflight/19-wrapper-dry-run.out.log`
- `preflight/19-wrapper-dry-run.out.log.exit.txt`: exit 0
- `batch-summary.log.side`

Required dry-run checks passed:

- S08 only.
- `--cache-mode hybrid`.
- `--cache-cold-max-mib 512`.
- Wrapper `--cache-ram 512`.
- `--n-gpu-layers all`.
- `--fit off`.
- Cold path, redacted evidence, evidence dir, model path, run root, Jinja `new`, and `BatchSize 1`.

## Live S08

Wrapper result: PASS. The wrapper side log reached `kickoff-stage20-stress-longrun end; rows=1 ok=True`; by wrapper contract that is the exit-0 path. The background launcher did not preserve a separate OS exit-code file.

Evidence:

- Wrapper stdout/stderr: `preflight/20-wrapper-live.out.log`, `preflight/21-wrapper-live.err.log`
- Side log: `batch-summary.log.side`
- Row files: `S08-Jnew/evidence-summary.md`, `metrics-before.txt`, `metrics-after.txt`, `resource-samples.csv`, `precondition.log`, `precondition.log.out`, `precondition.log.err`, `server.err.log`, `server.out.log`, `launch.log`, `launch.err`

Live gates:

- `batch_gate #1 ports=8900 listeners= ... coldItems=0 runRootWritable=true`
- `launched S08 port=8900 ... stress_s12_s08_integrity_failure_under_load.ps1 ... flags='--cache-mode hybrid --cache-cold-max-mib 512 --cache-ram 512 --n-gpu-layers all --fit off ...'`
- `row_gate S08 exitCode=0 ok=True evidenceFiles=11 present=server.out.log,server.err.log,metrics-before.txt,metrics-after.txt missing=`
- `batch_end #1 idx=0-0`
- `precondition.log`: `Stub: False`, `fault exit code: 0`
- `launch.log`: `S12-S08 integrity failure under load; stub=False faultStub=False`

Live metrics:

| Metric | Value |
| --- | ---: |
| Requests | 1592 |
| `llamacpp_cache_misses_total{mode="hybrid"}` | 1592 |
| `llamacpp_cache_hits_total{mode="hybrid"}` | 0 |
| `llamacpp_cache_entries{mode="hybrid"}` | 1 |
| `llamacpp_cache_bytes{mode="hybrid"}` | 53052484 |
| `llamacpp_cache_restore_failures_total{mode="hybrid"}` | 0 |
| `llamacpp_cache_descriptor_validation_failures_total{mode="hybrid"}` | 0 |
| `llamacpp_cache_fallback_restores_total{mode="hybrid"}` | 0 |
| `cache_cold_bytes{mode="hybrid"}` | 0 |
| `cache_cold_budget_bytes{mode="hybrid"}` | 536870912 |

The 1592 `fallback` log matches came from expected cache-miss lookup fallback
under this repeated short prompt workload. No restore failure, descriptor
validation failure, crash, HTTP 500, exception, corrupt, write-failure, or
STATUS_STACK pattern was present.

## Scans

- Redacted prompt evidence: 1592 JSONL records.
- Raw prompt leak scan: 0 matches for raw `"prompt"`, `"messages"`, `"content"`, `"role"`, or the S08 prompt literal.
- Error scan: 0 matches for `HTTP 500`, `STATUS_STACK`, `fatal`, `exception`, `write-failure`, `corrupt`, `descriptor validation failed`, `restore failure`, `mismatch`, `checksum`, or `error` in live row logs.
- Expected focused fault terms are confined to the Step 11 focused evidence and are not product failures.
- Cold path files: 0; cold bytes 0, below 512 MiB.

## Commands run

```powershell
cmake --build build-cov --config Release --target clean
cmake --build build-cov --config Release --target test-cache-controller -j 4
cmake --build build-cov --config Release --target test-step11-test-hooks-fault-injection -j 4
cmake --build build-cov --config Release --target llama-server -j 4
ctest --test-dir build-cov -C Release -R '^test-cache-controller$' --output-on-failure --timeout 300
.\build-cov\bin\Release\test-step11-test-hooks-fault-injection.exe
```

```powershell
& ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 `
  -RowsToRun @('S08') `
  -RunRoot ._test_output\stage23-remaining-s08-20260622-01 `
  -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
  -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-s08-20260622-01 `
  -CachePromptEvidenceDir ._test_output\stage23-remaining-s08-20260622-01\prompt-evidence `
  -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted `
  -JinjaVariant new -BasePort 8900 -BatchSize 1 -DryRun
```

The same wrapper command without `-DryRun` ran live S08 for 30 minutes.

## Handoff

S08 is PASS. Stress rows S01..S08 are now PASS for Stage 23. L01, L02, and L03 remain not run.

Next owner: Manager to open L01.
