# Stage 23 S07 focused run 20260622-01

Verdict: BLOCKED-runner-contract
Owner: QA
Scope: S07 only. S08, L01, L02, and L03 were not run.
Run window: 2026-06-22 10:12 to 10:53 Europe/Sofia.

## Inputs

- Model: `D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- Report: `._design_docs/.test_reports/stage23-remaining-s07-20260622-01.md`
- Evidence root: `._test_output/stage23-remaining-s07-20260622-01`
- Row root: `._test_output/stage23-remaining-s07-20260622-01/S07-Jnew`
- Cold path: `D:\tmp\cache-cold-stage23-stage23-remaining-s07-20260622-01`
- Prompt evidence: `._test_output/stage23-remaining-s07-20260622-01/prompt-evidence/cache-prompt-evidence.jsonl`
- Base port: 8900. Preflight found no listeners in 8900..8921.
- Suffix choice: `stage23-remaining-s07-20260622-01` was unused for report, output root, and cold root.

## Accepted prior evidence

- S01/S02 PASS from valid CUDA rerun.
- S03 PASS: `._design_docs/.test_reports/stage23-s03-rerun-20260621-10.md`.
- S04 PASS: `._design_docs/.test_reports/stage23-remaining-s04-20260621-01.md`.
- S05 PASS: `._design_docs/.test_reports/stage23-remaining-s05-20260621-02.md`.
- S06 PASS: `._design_docs/.test_reports/stage23-remaining-s06-20260622-01.md`.

## Preflight

| Gate | Result | Evidence |
| --- | --- | --- |
| Branch | PASS | `preflight/01-branch.txt`: `work-branch` |
| Git status | PASS with dirty tree | `preflight/02-git-status.txt`; dirty files pre-existed this QA run |
| CUDA configure | PASS | `preflight/03-cmake-cuda.txt`: `GGML_CUDA:BOOL=ON` |
| CUDA runtime | PASS | `S07-Jnew/server.err.log` lists CUDA0/CUDA1 RTX 5060 Ti; `preflight/21-nvidia-smi-during-live.txt` shows `llama-server.exe` on both GPUs |
| Model fixture | PASS | `preflight/05-fixture.txt` records Qwen3.5 path, size, mtime |
| Port range | PASS | `preflight/06-port-listeners-8900-8921.txt`: no 8900..8921 listeners |
| Cold path | PASS | `preflight/08-cold-path-before.txt`: empty |
| Disk | PASS | `preflight/07-disk.txt`: D free 1598378991616 bytes before live |

## Clean build and focused evidence

| Step | Result | Evidence |
| --- | --- | --- |
| CMake clean | PASS | `preflight/09-clean.log`, exit 0 |
| Build `test-cache-controller` | PASS | `preflight/10-build-test-cache-controller.log`, exit 0 |
| Build `test-step12-branch-graph` | PASS | `preflight/11-build-test-step12-branch-graph.log`, exit 0 |
| Build `llama-server` | PASS | `preflight/12-build-llama-server.log`, exit 0 |
| Run `test-cache-controller` | PASS | `preflight/13-test-cache-controller.log`: 120 tests passed |
| Run `test-step12-branch-graph` | PASS | `preflight/14-test-step12-branch-graph.log`: branch graph tests passed |
| Run `tools/server/tests/unit/test_cache_modes.py` | PASS | `preflight/15-pytest-cache-modes.log`: 3 passed, 1 xfailed |
| Binary freshness | PASS | `preflight/16-binary-freshness.txt`; `llama-server.exe` and `llama-server-impl.dll` mtime 2026-06-22 10:19:37 |

Focused evidence remains valid for graph and metric-shape claims. It is not a
substitute for live S07 protected-root pressure evidence.

## Dry-run gate

Dry-run command used S07 only with `CacheColdMaxMib 512`, `CacheRamMib 512`,
redacted prompt evidence, Jinja `new`, `BatchSize 1`, and base port 8900.

Result: PASS.

Evidence:

- `preflight/17-wrapper-dry-run.log`
- `preflight/17-wrapper-dry-run-exit.txt`: exit 0
- `preflight/18-dry-run-checks.json`

Checks passed: S07 only, model path, run root, `--cache-mode hybrid`,
`--cache-cold-max-mib 512`, `--cache-ram 512`, `--n-gpu-layers all`,
`--fit off`, redacted evidence, and evidence dir.

## Live S07

Wrapper result: PASS for process and public HTTP harness completion.

Evidence:

- Wrapper stdout/stderr: `preflight/19-wrapper-live.out.log`, `preflight/20-wrapper-live.err.log`
- Wrapper exit: `preflight/22-wrapper-live-exit.txt`: exit 0
- Side log: `batch-summary.log.side`
- Row files: `S07-Jnew/evidence-summary.md`, `metrics-before.txt`, `metrics-after.txt`, `resource-samples.csv`, `server.err.log`, `server.out.log`, `launch.log`, `launch.err`
- Verification summary: `preflight/26-evidence-checks.json`

Required side-log gates:

- `row_gate S07 exitCode=0 ok=True`
- `batch_end #1 idx=0-0`
- `kickoff-stage20-stress-longrun end; rows=1 ok=True`

Public workload evidence:

- Request count: 4077 in 1800 seconds.
- Metrics before and after were present.
- Prompt evidence records: 4077 redacted JSONL records.
- Redacted scan: 0 raw prompt/message/content/role/user/assistant/system keys and 0 S07 prompt literal matches.
- Error scan: 0 HTTP 500/error/fatal/STATUS_STACK/exception/corrupt/write-failure lines.
- Cold budget: `cache_cold_bytes 0` <= `cache_cold_budget_bytes 536870912`; cold path file count 0.
- Restore failures: `llamacpp_cache_restore_failures_total{mode="hybrid"} 0`.

## Blocker

S07 did not exercise protected-root pressure. The S07 row script adds
`--cache-ram 8`, but the Stage 23 wrapper appended `--cache-ram 512` after it.
Server logs show the effective limit was 512 MiB:

```text
hybrid cache state: 3 entries, 152.003 MiB payload ... (limits: 512.000 MiB payload, 512 tokens)
```

After metrics show no protected-root pressure path:

- `llamacpp_cache_protected_root_decisions_total{mode="hybrid"} 0`
- `cache_protected_root_payload_decisions_total{mode="hybrid",decision="all"} 0`
- `llamacpp_cache_protected_root_demotions_total{mode="hybrid"} 0`
- `llamacpp_cache_payload_evictions_total{mode="hybrid"} 0`
- `llamacpp_cache_payload_demotions_total{mode="hybrid"} 0`
- `cache_cold_evictions_total{mode="hybrid",reason="none",payload_kind="none"} 0`

This is a runner-contract gap, not a product failure. The live request harness
completed, CUDA was active, and focused graph/controller/metric-shape evidence
passed, but the live row did not prove S07 protected-root pressure.

## Handoff

S07 is BLOCKED-runner-contract. S08, L01, L02, and L03 remain not run.

Next owner: Manager for S07 disposition and likely Developer handoff to fix the
S07 effective hot-budget contract before any S08 sub-session opens.
