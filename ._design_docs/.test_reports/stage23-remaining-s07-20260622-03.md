# Stage 23 S07 focused rerun 20260622-03

Verdict: BLOCKED-runner-contract
Owner: QA
Scope: S07 only. S08, L01, L02, and L03 were not run.
Run window: 2026-06-22 11:10 to 12:35 Europe/Sofia.

## Inputs

- Model: `D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- Report: `._design_docs/.test_reports/stage23-remaining-s07-20260622-03.md`
- Evidence root: `._test_output/stage23-remaining-s07-20260622-03`
- Row root: `._test_output/stage23-remaining-s07-20260622-03/S07-Jnew`
- Cold path: `D:\tmp\cache-cold-stage23-stage23-remaining-s07-20260622-03`
- Prompt evidence: `._test_output/stage23-remaining-s07-20260622-03/prompt-evidence/cache-prompt-evidence.jsonl`
- Base port: 8900. Preflight found no listeners in 8900..8921.
- Suffix choice: `stage23-remaining-s07-20260622-02` was preferred but got partial empty output/cold roots from a failed orchestration bootstrap before preflight files were written. `-03` was the next unused focused S07 suffix.

## Accepted prior evidence

- S01/S02 PASS from valid CUDA rerun.
- S03 PASS: `._design_docs/.test_reports/stage23-s03-rerun-20260621-10.md`.
- S04 PASS: `._design_docs/.test_reports/stage23-remaining-s04-20260621-01.md`.
- S05 PASS: `._design_docs/.test_reports/stage23-remaining-s05-20260621-02.md`.
- S06 PASS: `._design_docs/.test_reports/stage23-remaining-s06-20260622-01.md`.
- S07 runner-contract fix review PASS: `._design_docs/.test_reports/stage23-remaining-s07-20260622-01-bugfix-review.md`.

## Preflight

| Gate | Result | Evidence |
| --- | --- | --- |
| Branch | PASS | `preflight/01-branch.txt`: `work-branch` |
| Git status | PASS with dirty tree | `preflight/02-git-status.txt`; dirty files pre-existed this QA run |
| CUDA configure | PASS | `preflight/03-cmake-cuda.txt`: `GGML_CUDA:BOOL=ON` |
| CUDA runtime | PASS | `S07-Jnew/server.err.log` lists CUDA0/CUDA1 RTX 5060 Ti; `preflight/21-nvidia-smi-during-live.txt` shows `llama-server.exe` on both GPUs |
| Model fixture | PASS | `preflight/05-fixture.txt` records Qwen3.5 path, size, mtime |
| Port range | PASS | `preflight/06-port-listeners-8900-8921.txt`: no listeners |
| Cold path | PASS | `preflight/08-cold-path-before.txt`: empty |
| Disk | PASS | `preflight/07-disk.txt`: D free 1598365945856 bytes before live |

## Clean build and focused checks

| Step | Result | Evidence |
| --- | --- | --- |
| CMake clean | PASS | `preflight/09-clean.log`, exit 0 |
| Build `test-cache-controller` | PASS | `preflight/10-build-test-cache-controller.log`, exit 0 |
| Build `test-step12-branch-graph` | PASS | `preflight/11-build-test-step12-branch-graph.log`, exit 0 |
| Build `llama-server` | PASS | `preflight/12-build-llama-server.log`, exit 0 |
| Run `test-cache-controller` | PASS | `preflight/13-test-cache-controller.log`: 120 tests passed |
| Run `test-step12-branch-graph` | PASS | `preflight/14-test-step12-branch-graph.log`: branch graph tests passed |
| Run `tools/server/tests/unit/test_cache_modes.py` | PASS | `preflight/15-pytest-cache-modes.log`: 3 passed, 1 xfailed |
| Binary freshness | PASS | `preflight/16-binary-freshness.txt`; `llama-server.exe` and `llama-server-impl.dll` mtime 2026-06-22 11:50:24 |

Focused checks remain valid for graph/controller/metric-shape evidence. They do
not replace live protected-root pressure evidence.

## Dry-run gate

Dry-run used S07 only with `CacheColdMaxMib 512`, wrapper input
`CacheRamMib 512`, redacted prompt evidence, Jinja `new`, `BatchSize 1`, and
base port 8900.

Result: PASS.

Evidence:

- `preflight/17-wrapper-dry-run.log`
- `preflight/17-wrapper-dry-run-exit.txt`: exit 0
- `preflight/18-dry-run-checks.json`
- `batch-summary.log.side`

Required dry-run checks passed:

- S07 only.
- `effective_cache_ram_mib=8`.
- S07 flags did not include wrapper `--cache-ram 512`.
- S07 flags included `--cache-cold-max-mib 512`, `--n-gpu-layers all`,
  `--fit off`, `--cache-prompt-evidence redacted`, and evidence dir.

## Live S07

Wrapper result: process and public HTTP harness completed.

Evidence:

- Wrapper stdout/stderr: `preflight/19-wrapper-live.out.log`, `preflight/20-wrapper-live.err.log`
- Wrapper exit: `preflight/22-wrapper-live-exit.txt`: exit 0
- Side log: `batch-summary.log.side`
- Row files: `S07-Jnew/evidence-summary.md`, `metrics-before.txt`,
  `metrics-after.txt`, `resource-samples.csv`, `server.err.log`,
  `server.out.log`, `launch.log`, `launch.err`

Required live gates:

- `S07 hot_budget effective_cache_ram_mib=8`
- `row_gate S07 exitCode=0 ok=True`
- `batch_end #1 idx=0-0`
- Metrics before and after present.
- `evidence-summary.md` records effective `--cache-ram 8`; no S07
  wrapper `--cache-ram 512` override.
- Server startup records: `prompt cache is enabled, size limit: 8 MiB`.
- Server state records: `limits: 8.000 MiB payload, 512 tokens`.

Public workload evidence:

- Request count: 4077 in 1800 seconds.
- Prompt evidence records: 4077 redacted JSONL records.
- Redacted scan: 0 raw `"prompt"`, `"messages"`, `"content"`, `"role"`,
  `protected-root-1`, `protected-root-2`, or S07 prompt literal matches.
- Error scan: 0 HTTP 500/error/fatal/STATUS_STACK/exception/corrupt/write-failure lines.
- Cold budget: `cache_cold_bytes 0` <= `cache_cold_budget_bytes 536870912`.
- Restore failures: `llamacpp_cache_restore_failures_total{mode="hybrid"} 0`.

## Blocker

The accepted S07 runner-contract fix worked: dry-run and live side logs show
`effective_cache_ram_mib=8`, and server startup used an 8 MiB hot cache limit.

The row still did not exercise protected-root pressure. The Qwen3.5 payload is
about 50 MiB per entry, so every save was rejected before protected-root policy
could run:

```text
save rejected because payload bytes exceed hot budget ... payload bytes: 53150792, budget bytes: 8388608, protected: 0
```

This warning appeared 6794 times. After metrics show the pressure path stayed
zero:

- `llamacpp_cache_protected_root_decisions_total{mode="hybrid"} 0`
- `cache_protected_root_payload_decisions_total{mode="hybrid",decision="all"} 0`
- `llamacpp_cache_protected_root_demotions_total{mode="hybrid"} 0`
- `llamacpp_cache_payload_evictions_total{mode="hybrid"} 0`
- `llamacpp_cache_payload_demotions_total{mode="hybrid"} 0`
- `cache_cold_evictions_total{mode="hybrid",reason="none",payload_kind="none"} 0`

Per the active gate, S07 cannot pass from public requests alone when all
protected-root pressure signals stay zero. This is a runner/workload evidence
gap, not a product failure.

## Handoff

S07 remains BLOCKED-runner-contract. S08, L01, L02, and L03 remain not run.

Next owner: Manager for S07 disposition. Likely Developer follow-up is to make
S07 use a pressure-capable fixture or budget that admits at least one entry and
then forces protected-root pressure.
