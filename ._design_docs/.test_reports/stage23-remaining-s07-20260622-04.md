# Stage 23 S07 focused rerun 20260622-04

Verdict: PASS
Owner: QA
Scope: S07 only. S08, L01, L02, and L03 were not run.
Run window: 2026-06-22 13:03 to 13:44 Europe/Sofia.

## Inputs

- Primary model: `D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- Pressure fixture: `D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf`
- Evidence root: `._test_output/stage23-remaining-s07-20260622-04`
- Row root: `._test_output/stage23-remaining-s07-20260622-04/S07-Jnew`
- Cold path: `D:\tmp\cache-cold-stage23-stage23-remaining-s07-20260622-04`
- Prompt evidence: `._test_output/stage23-remaining-s07-20260622-04/prompt-evidence/cache-prompt-evidence.jsonl`
- Base port: 8900. Preflight found no listeners in 8900..8921.
- Suffix choice: `-04` was chosen because `-03` was the highest existing same-day focused S07 report and `-04` report/output/cold roots were unused.

## Acceptance gate

Architect required both live payload pressure under 8 MiB and focused trusted
protected-root evidence from the same clean-build gate. Public degraded
protected-root counters at 0 are not rework by themselves.

Result: both requirements were met.

## Preflight

| Gate | Result | Evidence |
| --- | --- | --- |
| Branch | PASS | `preflight/01-branch.log`: `work-branch` |
| Git status | PASS with dirty tree | `preflight/02-git-status.log`; dirty tree preserved |
| CUDA configure | PASS | `preflight/03-cmake-cuda.log`: `GGML_CUDA:BOOL=ON` |
| CUDA runtime | PASS | `S07-Jnew/server.err.log`: CUDA0/CUDA1 RTX 5060 Ti and CUDA system info |
| Primary model | PASS | `preflight/04-primary-fixture.log` |
| Pressure fixture | PASS | `preflight/05-pressure-fixture.log` |
| Port range | PASS | `preflight/06-port-listeners-8900-8921.log`: no listeners |
| Cold path | PASS | `preflight/08-cold-path-before.log`: empty |
| Disk | PASS | `preflight/07-disk.log`: D free 1596361093120 bytes before live |

## Clean build and focused checks

| Step | Result | Evidence |
| --- | --- | --- |
| CMake clean | PASS | `preflight/09-clean.log`, exit 0 |
| Build `test-cache-controller` | PASS | `preflight/10-build-test-cache-controller.log`, exit 0 |
| Build `test-step12-branch-graph` | PASS | `preflight/11-build-test-step12-branch-graph.log`, exit 0 |
| Build `llama-server` | PASS | `preflight/12-build-llama-server.log`, exit 0 |
| Run `test-cache-controller` | PASS | `preflight/13-test-cache-controller.log`: 120 tests passed |
| Run `test-step12-branch-graph` | PASS | `preflight/14-test-step12-branch-graph.log`: PASS |
| Run `tools/server/tests/unit/test_cache_modes.py` | PASS | `preflight/15-pytest-cache-modes.log`: 3 passed, 1 xfailed |
| Binary freshness | PASS | `preflight/16-binary-freshness.log`: `llama-server.exe` and `llama-server-impl.dll` mtime 2026-06-22 13:12:59 |

Trusted protected-root evidence used for S07:

- `test-cache-controller: hybrid payload budget eviction...`
- `test-cache-controller: hybrid multiple protected evictions count decisions...`
- `test-cache-controller: hybrid protected admission rejection stats...`
- `All tests passed successfully!`

## Dry-run gate

Dry-run result: PASS.

Evidence:

- `preflight/17-wrapper-dry-run.out.log`
- `preflight/17-wrapper-dry-run.exit.txt`: exit 0
- `preflight/18-dry-run-side-excerpts.txt`
- `batch-summary.log.side`

Required dry-run checks passed:

- S07 only.
- `effective_cache_ram_mib=8`.
- `S07 pressure_workload` present.
- Pressure fixture state `available`.
- Primary Qwen3.5 model recorded.
- No S07 wrapper `--cache-ram 512` override.
- Cold max 512 MiB, CUDA all, fit off, redacted evidence, Jinja `new`, and `BatchSize 1` recorded.

## Live S07

Wrapper result: PASS, exit 0.

Evidence:

- Wrapper stdout/stderr: `preflight/19-wrapper-live.out.log`, `preflight/20-wrapper-live.err.log`
- Wrapper exit: `preflight/22-wrapper-live-exit.txt`
- Side log: `batch-summary.log.side`
- Row files: `S07-Jnew/evidence-summary.md`, `metrics-before.txt`, `metrics-during.txt`, `metrics-after.txt`, `resource-samples.csv`, `server.err.log`, `server.out.log`, `launch.log`, `launch.err`

Live gates:

- `S07 hot_budget effective_cache_ram_mib=8`
- `S07 pressure_workload pressure_model=...\Qwen3-0.6B-Q8_0.gguf pressure_model_state=available ... primary_model=...\Qwen3.5-4B-Q4_K_M.gguf`
- `row_gate S07 exitCode=0 ok=True`
- `batch_end #1 idx=0-0`
- Server startup: `prompt cache is enabled, size limit: 8 MiB`
- Server state: `limits: 8.000 MiB payload, 512 tokens`
- Evidence summary model fixture: `Qwen3-0.6B-Q8_0.gguf`
- Evidence summary notes: primary model `Qwen3.5-4B-Q4_K_M.gguf`; pressure model `Qwen3-0.6B-Q8_0.gguf`

Live pressure metrics:

| Metric | Value |
| --- | ---: |
| Requests | 4521 |
| `llamacpp_cache_entries{mode="hybrid"}` | 1487 |
| `llamacpp_cache_bytes{mode="hybrid"}` | 3641413 |
| `llamacpp_cache_payload_demotions_total{mode="hybrid"}` | 4479 |
| `llamacpp_cache_payload_evictions_total{mode="hybrid"}` | 22 |
| `llamacpp_cache_payload_cold_evictions_total{mode="hybrid"}` | 1685 |
| `cache_payload_evictions_by_shape_total{reason="hot_budget"}` | 22 |
| Oversize payload rejects | 0 |
| `llamacpp_cache_restore_failures_total{mode="hybrid"}` | 0 |
| `cache_cold_bytes{mode="hybrid"}` | 536791200 |
| `cache_cold_budget_bytes{mode="hybrid"}` | 536870912 |

Public protected-root counters stayed 0:

- `llamacpp_cache_protected_root_decisions_total{mode="hybrid"} 0`
- `cache_protected_root_payload_decisions_total{mode="hybrid",decision="all"} 0`
- `llamacpp_cache_protected_root_demotions_total{mode="hybrid"} 0`

Per Architect, this is not rework because public prompt metadata is degraded.
The trusted protected-root controller tests above are the acceptance evidence.

## Scans

- Redacted prompt evidence: 4521 JSONL records.
- Raw prompt leak scan: 0 matches for raw `"prompt"`, `"messages"`, `"content"`, `"role"`, protected-root literals, or S07 prompt literals.
- Error scan: 0 matches for `HTTP 500`, `STATUS_STACK`, `fatal`, `corrupt`, `write-failure`, or `exception`.
- Non-blocking save rejects: 3013 `save rejected because task is null`; these are not oversize rejects and did not block admission, demotion, or eviction evidence.
- Cold bytes stayed below 512 MiB by 79712 bytes.

## Commands run

```powershell
cmake --build build-cov --config Release --target clean
cmake --build build-cov --config Release --target test-cache-controller -j 4
cmake --build build-cov --config Release --target test-step12-branch-graph -j 4
cmake --build build-cov --config Release --target llama-server -j 4
.\build-cov\bin\Release\test-cache-controller.exe
.\build-cov\bin\Release\test-step12-branch-graph.exe
pytest tools/server/tests/unit/test_cache_modes.py
```

```powershell
& ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 `
  -RowsToRun @('S07') `
  -RunRoot ._test_output\stage23-remaining-s07-20260622-04 `
  -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
  -S07PressureModelPath ._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf `
  -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-s07-20260622-04 `
  -CachePromptEvidenceDir ._test_output\stage23-remaining-s07-20260622-04\prompt-evidence `
  -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted `
  -JinjaVariant new -BasePort 8900 -BatchSize 1 -DryRun
```

The same wrapper command without `-DryRun` ran live S07 for 30 minutes.

## Handoff

S07 is PASS. S08, L01, L02, and L03 remain not run.

Next owner: Manager to open S08.
