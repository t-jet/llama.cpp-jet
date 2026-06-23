# Stage 23 L03 focused run 20260622-01

Verdict: BLOCKED-runner-contract
Owner: QA
Scope: L03 only, 2h mixed workload longrun gate. No other S/L rows were run.
Run window: 2026-06-22 21:04 to 23:05 Europe/Sofia.

## Inputs

- Primary model: `D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- Evidence root: `._test_output/stage23-remaining-l03-20260622-01`
- Row root: `._test_output/stage23-remaining-l03-20260622-01/L03-Jnew`
- Cold path: `D:\tmp\cache-cold-stage23-stage23-remaining-l03-20260622-01`
- Prompt evidence: `._test_output/stage23-remaining-l03-20260622-01/prompt-evidence/cache-prompt-evidence.jsonl`
- Base port: 8900
- Suffix choice: `-01` was unused for report, output root, and cold root.

## Acceptance gate

Required scope was L03 only: two hour Stage 23 mixed workload longrun with
hybrid cache, cold budget 512 MiB, cache RAM 512 MiB, CUDA all, fit off,
Jinja new, redacted prompt evidence, before/after metrics, process and GPU
evidence, clean scans, and cold bytes at or below 512 MiB.

Result: BLOCKED-runner-contract. The live row ran for two hours with complete
basic evidence and no product failure, but the child script is still a legacy
control workload. It emits `Variant: legacy-2h`, sends one repeated
`S12-L03 legacy control probe` request each minute, and the redacted evidence
contains only `profile=checkpoint_dependent` plus `lookup_outcome=exact_entry_absent`.
No mixed workload phases, prompt mix, exact/near/new split, or profile mix were
produced. That does not satisfy the Stage 23 L03 mixed workload row contract.

## Preflight

| Gate | Result | Evidence |
| --- | --- | --- |
| Branch | PASS | `preflight/01-branch.log`: `work-branch` |
| Git status | PASS with dirty tree | `preflight/02-git-status.log`; dirty tree preserved |
| CUDA configure | PASS | `preflight/03-cmake-cuda.log`: `GGML_CUDA:BOOL=ON` |
| CUDA runtime | PASS | `L03-Jnew/server.err.log` lists CUDA0/CUDA1 RTX 5060 Ti and CUDA system info |
| GPU process | PASS | `preflight/18-nvidia-smi-live-210525.log` shows `llama-server.exe` on both GPUs |
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
| Binary freshness | PASS | `preflight/13-binary-freshness.log`: server exe and impl DLL 2026-06-22 21:03:12 |

## Dry-run gate

Dry-run result: PASS. One local command construction error happened before the
accepted dry-run; it did not start the wrapper or create row evidence.

Evidence:

- Accepted dry-run: `preflight/16-wrapper-dry-run-rerun.out.log`
- Accepted dry-run exit: `preflight/16-wrapper-dry-run-rerun.exit.txt`, exit 0
- Side log: `batch-summary.log.side`

Required dry-run checks passed:

- L03 only, `BatchSize 1`, port 8900.
- Stage 23 flags present: `--cache-mode hybrid`, `--cache-cold-max-mib 512`,
  `--cache-ram 512`, `--n-gpu-layers all`, `--fit off`, cold path,
  redacted prompt evidence, evidence dir, model path, and run root.

## Live L03

Wrapper OS exit: 0.

Side-log gates:

- `batch_gate #1 ports=8900 listeners= ... coldItems=0 runRootWritable=true`
- `launched L03 port=8900 ... hours=2 min=0`
- `row_gate L03 exitCode=0 ok=True evidenceFiles=11 present=server.out.log,server.err.log,metrics-before.txt,metrics-after.txt missing=`
- `batch_end #1 idx=0-0`
- `kickoff-stage20-stress-longrun end; rows=1 ok=True`

Row summary:

| Item | Value |
| --- | ---: |
| Planned duration | 7200 s |
| Last resource sample | 7188 s |
| Requests | 120 |
| Liveness failures | 0 |
| Prompt evidence records | 120 |
| Cache misses delta | 120 |
| Cache hits delta | 0 |
| Cache entries after | 1 |
| Cache bytes after | 53019692 |
| Cache tokens after | 9 |
| Cold bytes metric after | 0 |
| Cold budget metric after | 536870912 |
| Cold files on disk | 0 |

Resource stability:

| Window | Working set delta | Handle delta |
| --- | ---: | ---: |
| Full run | 0.039% | 14.844% |
| After warmup, sample >= 1800 s | 0.005% | 0.000% |

GPU/runtime evidence:

- Startup log lists CUDA0 and CUDA1 as NVIDIA GeForce RTX 5060 Ti.
- `nvidia-smi` sample `preflight/18-nvidia-smi-live-210525.log` shows
  `llama-server.exe` on both GPUs.

## Scans and classification

- Redacted evidence scan: 0 matches for raw `"prompt"`, `"messages"`,
  `"content"`, `"role"`, `S12-L03 legacy control probe`, or `S12-L03`.
- Product/error scan: 0 matches for HTTP 500, fatal, STATUS_STACK, exception,
  write-failure, corrupt, error, or host allocation.
- Server warnings include repeated invalidated checkpoint erasure lines. They
  are not classified as product failure because the row stayed live, requests
  completed, metrics were written, and the forbidden product patterns were absent.
- `evidence-summary.md` stays `Result: PENDING`, with notes saying QA verifies
  legacy path stability. This supports the runner-contract block.

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
  -RunRoot ._test_output\stage23-remaining-l03-20260622-01 `
  -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
  -CacheColdPath D:\tmp\cache-cold-stage23-stage23-remaining-l03-20260622-01 `
  -CachePromptEvidenceDir ._test_output\stage23-remaining-l03-20260622-01\prompt-evidence `
  -CacheColdMaxMib 512 -CacheRamMib 512 -CachePromptEvidence redacted `
  -JinjaVariant new -BasePort 8900 -BatchSize 1 -DryRun
```

The same wrapper command without `-DryRun` ran live L03.

## Handoff

L03 is BLOCKED-runner-contract. No product bug was found.

Next owner: Manager for L03 disposition. Likely follow-up is Developer runner
fix or Manager reclassification because the current L03 script proves a stable
legacy-control loop, not the Stage 23 mixed workload longrun row.
