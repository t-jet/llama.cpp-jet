# Stage 23 L03 focused rerun 20260622-02

Verdict: PASS
Owner: QA
Scope: L03 only, fixed Stage 23 mixed workload longrun. No other S/L rows were run.
Run window: 2026-06-22 23:30 to 2026-06-23 01:40 Europe/Sofia.

## Inputs

- Primary model: `D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- Evidence root: `._test_output/stage23-remaining-l03-20260622-02`
- Row root: `._test_output/stage23-remaining-l03-20260622-02/L03-Jnew`
- Cold path: `D:\tmp\cache-cold-stage23-stage23-remaining-l03-20260622-02`
- Prompt evidence: `._test_output/stage23-remaining-l03-20260622-02/prompt-evidence/cache-prompt-evidence.jsonl`
- Base port: 8900
- Suffix choice: `-02` was unused for report, output root, and cold root.

## Acceptance gate

Required scope was L03 only: two hour mixed workload longrun, hybrid cache, cold
budget 512 MiB, cache RAM 512 MiB, CUDA all, fit off, Jinja new, redacted
prompt evidence, before/after metrics, process and GPU evidence, clean scans,
`l03-mixed-workload.json`, root `evidence-summary.md` not `PENDING`, and cold
bytes at or below 512 MiB.

Result: PASS. The fixed runner executed all four L03 harness classes under the
7200 second row cap, wrote the required mixed-workload artifact, ended root
summary as `Result: PASS`, and stayed within the cold budget.

## Preflight

| Gate | Result | Evidence |
| --- | --- | --- |
| Branch | PASS | `preflight/01-branch.log`: `work-branch` |
| Git status | PASS with dirty tree | `preflight/02-git-status.log`; dirty tree preserved |
| CUDA configure | PASS | `preflight/03-cmake-cuda.log`: `GGML_CUDA:BOOL=ON` |
| CUDA runtime | PASS | `L03-Jnew/server.err.log` lists CUDA0/CUDA1 RTX 5060 Ti and CUDA system info |
| GPU process | PASS | `preflight/18-nvidia-smi-live-233920.log` shows `llama-server.exe` on both GPUs |
| Model fixture | PASS | `preflight/04-model-fixture.log` |
| Port range | PASS | `preflight/05-port-listeners-8900-8921.log` and `15-port-listeners-before-live.log`; no blockers |
| Cold path | PASS | `preflight/07-cold-path-before.log` and `16-cold-path-before-live.log`; empty |
| Disk | PASS | `preflight/06-disk.log`; D free space above 30 GiB |

## Clean build

| Step | Result | Evidence |
| --- | --- | --- |
| CMake clean | PASS | `preflight/09-clean.log`, exit 0 |
| Build `test-cache-controller` | PASS | `preflight/10-build-test-cache-controller.log`, exit 0 |
| Build `llama-server` | PASS | `preflight/11-build-llama-server.log`, exit 0 |
| Run `test-cache-controller` | PASS | `preflight/12-test-cache-controller.log`: 120 tests passed |
| Binary freshness | PASS | `preflight/13-binary-freshness.log`: server exe, impl DLL, and controller mtimes recorded |

## Dry-run gate

Dry-run result: PASS.

Evidence:

- Wrapper log: `preflight/14-wrapper-dry-run.log`
- Side log: `preflight/14-wrapper-dry-run.side.log`
- Exit: `preflight/14-wrapper-dry-run.exit.txt`, exit 0

Required dry-run checks passed:

- L03 only, `BatchSize 1`, port 8900.
- Stage 23 flags present: `--cache-mode hybrid`, `--cache-cold-max-mib 512`,
  wrapper `--cache-ram 512`, `--n-gpu-layers all`, `--fit off`, cold path,
  redacted prompt evidence, evidence dir, model path, and run root.
- Approved mixed-workload plan present:
  `rowCapSeconds=7200`, `exact_cache_prompt_seconds=2160`,
  `checkpoint_dependent_seconds=2160`, `near_non_exact_seconds=1440`,
  `new_uncached_seconds=1440`, `artifact=l03-mixed-workload.json`.

## Live L03

Wrapper OS exit: 0.

Side-log gates:

- `batch_gate #1 ports=8900 listeners= ... coldItems=0 runRootWritable=true`
- `launched L03 port=8900 ... hours=2 min=0`
- `L03 mixed_workload_plan rowCapSeconds=7200 exact_cache_prompt_seconds=2160 checkpoint_dependent_seconds=2160 near_non_exact_seconds=1440 new_uncached_seconds=1440 artifact=l03-mixed-workload.json`
- `row_gate L03 exitCode=0 ok=True evidenceFiles=15 present=server.out.log,server.err.log,metrics-before.txt,metrics-after.txt,l03-mixed-workload.json,evidence-summary.md missing=`
- `batch_end #1 idx=0-0`
- `kickoff-stage20-stress-longrun end; rows=1 ok=True`

Mixed workload artifact: `L03-Jnew/l03-mixed-workload.json`, status `PASS`.

| Item | Value |
| --- | ---: |
| Planned duration | 7200 s |
| Last resource sample | 7197 s |
| Requests | 120 |
| HTTP 200 | 120 |
| Liveness failures | 0 |
| Harness class counts | exact 36, checkpoint 36, near 24, new 24 |
| Prompt evidence records | 120 |
| Public evidence profiles | `checkpoint_dependent=120` |
| Public lookup outcomes | `exact_entry_absent=120` |
| Distinct token-span checksums | 50 |
| Distinct lookup paths | 50 |
| Cache misses delta | 120 |
| Cache hits delta | 0 |
| Cache entries after | 50 |
| Cache bytes after | 106896956 |
| Cold bytes metric after | 480816192 |
| Cold budget metric after | 536870912 |
| Cold files on disk | 10 |

Resource stability:

| Window | Working set delta | Handle delta |
| --- | ---: | ---: |
| Full run | 3.099% | 15.058% |
| After warmup, sample >= 1800 s | 3.064% | 0.337% |

GPU/runtime evidence:

- Startup log lists CUDA0 and CUDA1 as NVIDIA GeForce RTX 5060 Ti.
- `nvidia-smi` sample shows `llama-server.exe` PID 30240 on both GPUs.

## Scans and classification

- Redacted evidence scan: 0 matches for raw `"prompt"`, `"messages"`,
  `"content"`, `"role"`, L03 prompt anchors, or `legacy control probe`.
- Product/error scan: 0 matches for HTTP 500, fatal, STATUS_STACK, exception,
  write-failure, corrupt, error, or host allocation.
- Architect advisory A-23-L03-01 applied: public prompt evidence collapsed to
  `profile=checkpoint_dependent` and `lookup_outcome=exact_entry_absent`, but
  the full row shows all four harness classes, 120 requests, metrics deltas,
  50 token-span checksums, 50 lookup paths, and artifact status `PASS`.
- Root `evidence-summary.md` records `Variant: mixed-workload` and
  `Result: PASS`.

## Commands run

```powershell
cmake --build build-cov --config Release --target clean
cmake --build build-cov --config Release --target test-cache-controller -j 4
cmake --build build-cov --config Release --target llama-server -j 4
.\build-cov\bin\Release\test-cache-controller.exe
```

```powershell
& ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 `
  -RowsToRun @('L03') `
  -RunRoot ._test_output\stage23-remaining-l03-20260622-02 `
  -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
  -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-l03-20260622-02 `
  -CachePromptEvidenceDir ._test_output\stage23-remaining-l03-20260622-02\prompt-evidence `
  -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted `
  -JinjaVariant new -BasePort 8900 -BatchSize 1 -DryRun
```

The same wrapper command without `-DryRun` ran live L03.

## Handoff

L03 PASS. All Stage 23 S/L rows now have PASS evidence: S01/S02 from the valid
CUDA rerun, S03 rerun 10, S04, S05 rerun 02, S06 20260622-01, S07 20260622-04,
S08 20260622-01, L01 20260622-01, L02 rerun 02, and this L03 rerun.

Next owner: Manager for final Stage 23 closure/test-results review gate.
