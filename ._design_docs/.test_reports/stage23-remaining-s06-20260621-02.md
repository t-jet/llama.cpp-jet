# Stage 23 S06 focused rerun 20260621-02

Verdict: BLOCKED-runner-contract
Owner: QA
Scope: S06 only. S07..S08 and L01..L03 were not run.
Run window: 2026-06-21 23:31 to 2026-06-22 00:01 Europe/Sofia.

## Inputs

- Model: `D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- Report: `._design_docs/.test_reports/stage23-remaining-s06-20260621-02.md`
- Evidence root: `._test_output/stage23-remaining-s06-20260621-02`
- Row root: `._test_output/stage23-remaining-s06-20260621-02/S06-Jnew`
- Cold path: `D:\tmp\cache-cold-stage23-stage23-remaining-s06-20260621-02`
- Prompt evidence: `._test_output/stage23-remaining-s06-20260621-02/prompt-evidence/cache-prompt-evidence.jsonl`
- Base port: 8900. Preflight found no listeners in 8900..8921.
- Suffix choice: `02` was unused for report, output root, and cold root. Prior `01` artifacts already existed.

## Accepted prior evidence

- S01/S02 PASS from valid CUDA rerun.
- S03 PASS: `._design_docs/.test_reports/stage23-s03-rerun-20260621-10.md`.
- S04 PASS: `._design_docs/.test_reports/stage23-remaining-s04-20260621-01.md`.
- S05 PASS: `._design_docs/.test_reports/stage23-remaining-s05-20260621-02.md`.
- S06 prior block: `._design_docs/.test_reports/stage23-remaining-s06-20260621-01.md`.
- S06 runner fix review PASS: `._design_docs/.test_reports/stage23-remaining-s06-20260621-01-bugfix-review.md`.

## Preflight

| Gate | Result | Evidence |
| --- | --- | --- |
| Branch | PASS | `preflight/01-branch.txt`: `work-branch` |
| Git status | PASS with dirty tree | `preflight/02-git-status.txt`; dirty files pre-existed this QA run |
| CUDA configure | PASS | `preflight/07-cuda-cmake-cache.txt`: `GGML_CUDA:BOOL=ON` |
| CUDA runtime | PASS | live `server.err.log` lists CUDA0/CUDA1 RTX 5060 Ti |
| Fixture | PASS | `preflight/03-fixture.txt` records model path, size, mtime |
| Port range | PASS | `preflight/04-port-listeners.txt`: no 8900..8921 listeners |
| Cold path | PASS | `preflight/06-cold-path-before.txt`: empty |
| Disk | PASS | `preflight/05-disk.txt`: D free 1599884673024 bytes |

## Clean build

| Step | Result | Evidence |
| --- | --- | --- |
| CMake clean | PASS | `preflight/10-clean.log` |
| Build `test-cache-controller` | PASS | `preflight/11-build-test-cache-controller.log` |
| Build `llama-server` | PASS | `preflight/12-build-llama-server.log` |
| Run `test-cache-controller` | PASS | `preflight/13-test-cache-controller.log`: 120 tests passed |
| Binary freshness | PASS | `preflight/14-binary-freshness.txt`; `llama-server-impl.dll` mtime 2026-06-21 23:30:44 |

## Dry-run gate

Dry-run command used S06 only with `CacheColdMaxMib 512`, wrapper
`CacheRamMib 512`, redacted prompt evidence, Jinja `new`, `BatchSize 1`,
and base port 8900.

Result: PASS.

Evidence:

- `preflight/16-wrapper-dry-run.log`
- `preflight/17-wrapper-dry-run-side.log`
- `preflight/18-dry-run-checks.json`

Checks:

- S06 dry-run flags did not include wrapper `--cache-ram 512`.
- Side log has `DryRun S06 hot_budget effective_cache_ram_mib=16`.
- Required Stage 23 flags were present: `--cache-mode hybrid`, `--cache-cold-max-mib 512`, `--n-gpu-layers all`, `--fit off`, cold path, redacted evidence, and evidence dir.

## Live S06

Result: BLOCKED-runner-contract.

Evidence:

- Wrapper stdout/stderr: `preflight/19-wrapper-live.out.log`, `preflight/20-wrapper-live.err.log`
- Side log: `batch-summary.log.side`
- Row files: `S06-Jnew/evidence-summary.md`, `metrics-before.txt`, `metrics-after.txt`, `resource-samples.csv`, `server.err.log`, `server.out.log`, `launch.log`, `launch.err`
- Verification summary: `preflight/21-evidence-checks.json`

Wrapper result:

- `row_gate S06 exitCode=0 ok=True`
- `batch_end #1 idx=0-0`
- `kickoff-stage20-stress-longrun end; rows=1 ok=True`

Hot-budget evidence:

- Wrapper side log: `S06 hot_budget effective_cache_ram_mib=16 source=S06-HotBudgetMiB wrapper_cache_ram_mib=512 stage17_cache_ram_appended=false`.
- Server startup/state log: `limits: 16.000 MiB payload, 512 tokens`.
- Evidence summary server flags show one effective `--cache-ram 16`; wrapper did not append `--cache-ram 512` for S06.

CUDA evidence:

- `server.err.log` lists CUDA devices and CUDA system info.
- Preflight CMake cache has `GGML_CUDA:BOOL=ON`.

## Metrics and pressure checks

| Check | Result | Evidence |
| --- | --- | --- |
| Requests | PASS | `Request count 1593`; resource sample rows 1593 |
| Redacted JSONL | PASS | 1593 records, 492237 bytes |
| Raw prompt leak scan | PASS | no `S12-S06 cold queue probe` in JSONL or server log |
| HTTP 500/error/corrupt/write-failure scan | PASS | counts all 0 |
| Cold budget | PASS | `cache_cold_budget_bytes 536870912`, `cache_cold_bytes 0` |
| Cold pressure | BLOCKED | 0 demotions, 0 skipped demotions, 0 cold evictions, 0 cold files |

Key after-metrics:

- `llamacpp_cache_misses_total{mode="hybrid"} 1593`
- `cache_restore_misses_total{reason="exact_entry_absent",profile="checkpoint_dependent",pair_state="target_only"} 1593`
- `cache_prompt_evidence_records_total{mode="redacted",result="written"} 1593`
- `llamacpp_cache_payload_demotions_total{mode="hybrid"} 0`
- `cache_cold_demotions_skipped_total{mode="hybrid"} 0`
- `cache_cold_evictions_total{reason="none",payload_kind="none"} 0`
- `cache_cold_bytes{mode="hybrid"} 0`

The runner fix cleared the previous effective-hot-budget defect. The live row
still did not exercise S06 cold queue pressure. With no demotion, skip, cold
eviction, or cold file, the row cannot prove the S06 contract "cold demotions
skip or evict before write failure." This is a setup/runner evidence gap, not
a product failure.

One non-blocking startup warning remains: duplicate `--cache-cold-path` appears
because the S06 script sets a local temp cold path and the Stage 23 wrapper
appends the real run cold path. The server used the last value, the required
Stage 23 cold path.

## Handoff

S06 remains stopped at BLOCKED-runner-contract. S07 must not open from this
evidence. Next owner: Manager for S06 disposition. If Manager keeps S06
in-scope, next implementation owner should adjust the runner workload so S06
creates actual cold pressure under the 16 MiB hot budget, then QA can rerun
S06 with a fresh suffix.
