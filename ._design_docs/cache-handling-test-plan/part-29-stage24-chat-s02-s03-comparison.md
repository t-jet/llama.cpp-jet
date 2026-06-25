# Test plan part 29: Stage 24 chat S02/S03 comparison

Status: Stage 24 closed; final report -06
Date: 2026-06-25
Stage: 24 (Chat-Completion S02/S03 Cache Comparison)
Branch: work-branch
Owner: QA
Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)
Scope: final execution planning for the Stage 24 S02/S03 native-vs-hybrid chat comparison. No product code changes or final live execution.

## References

Design:

- [Stage 24 design](../cache-handling-phase24-design.md)
- [Manager design gate](../cache-handling-phase24-design/part-02-manager-design-gate-20260623.md)

Implementation:

- [Stage 24 implementation](../cache-handling-phase24-implementation.md)
- [Manager implementation gate](../cache-handling-phase24-implementation/part-08-manager-implementation-gate-20260623.md)
- [Stage 24 runner](../cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1)
- [Implementation smoke report](../.test_reports/test-report-20260623-01.md)

Prior plan rules:

- [Part 7: test report quality and templates](./part-07-test-report-quality-and-templates.md)
- [Part 17: Stage 11 fix L test automation](./part-17-stage11-fix-l-test-automation.md)
- [Part 24: test output folder convention](./part-24-test-output-folder-convention.md)
- [Part 27: Stage 17 agentic cache reuse](./part-27-stage17-agentic-cache-reuse.md)

## Binding decisions

- D24-DESIGN-03: use the combined focused runner, variant names `native-legacy` and `hybrid-stage24`, `/v1/chat/completions` for both variants, S02 `--parallel 4`, the Qwen3.5 MTP fixture for S03, a 10 minute default leg cap, redacted hybrid evidence, and no Stage 23 evidence reopening.
- D24-IMPL-02: QA owns final execution planning before any closure run.
- D24-IMPL-03: carry forward the earlier S02 hybrid `FAIL-http-request` risk. The earlier S03 `FAIL-unsafe-prefix-restore` is superseded by the pre-rerun runner fix in implementation Part 10: only hybrid near-prefix nonzero `cache_n` can fail unsafe-prefix policy; native near-prefix `cache_n` is diagnostic baseline data.

## Scope and exclusions

In scope:

- Final execution plan for `S02-chat` and `S03-chat`, each with `native-legacy` and `hybrid-stage24` legs.
- Clean build, fixture checks, binary freshness, route-only gate, dry-run gate, final command shape, evidence paths, metrics, leak scan, cleanup proof, and Developer review inputs.
- Classification rules for `PASS`, `FAIL`, and `BLOCKED`.

Out of scope:

- Product code changes.
- Script changes unless test-plan review finds a runner-contract gap.
- Stage 23 evidence reopening.
- Full S01..S08, L01..L03, or benchmark matrix execution.
- Raw prompt evidence mode.

## Preflight and build gate

Before final execution, QA creates the next whitelisted durable report:

```text
._design_docs/.test_reports/test-report-YYYYMMDD-NN.md
```

The matching non-durable output root is:

```text
._test_output/stage24-chat-s02-s03-YYYYMMDD-NN/
```

Use the next chronological same-day suffix after the highest existing `test-report-YYYYMMDD-NN.md`. Do not reuse a skipped or partially created suffix.

Clean CUDA build proof is mandatory. Stale builds are invalid evidence.

```powershell
cmake --build build-cuda --config Release -j --target llama-server
```

Record these in the report:

- build command, exit code, and build log path
- `build-cuda/bin/Release/llama-server.exe` mtime and size
- `build-cuda/bin/Release/llama-server-impl.dll` mtime and size when present
- git commit and dirty working-tree status
- `cmake` generator and relevant cache flags
- CMake cache proof: `build-cuda/CMakeCache.txt` contains `GGML_CUDA:BOOL=ON`
- runtime CUDA proof from every leg's startup logs, such as `CUDA0 : NVIDIA`, `CUDA1 : NVIDIA`, `system_info: ... CUDA`, or `ggml_cuda`

Fixture and environment checks:

- model path exists: `._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf`
- `llama-server.exe` resolves to the fresh `build-cuda` binary
- ports `8900` and `8910` are free before the run, or Manager approves a new base port
- output volume has at least 30 GiB free
- cold-path volume has at least 10 GiB free
- `D:\tmp\cache-cold-stage24` is writable and starts empty for owned Stage 24 subpaths

Missing fixture, stale binary, port collision after one setup retry, disk shortage, missing `GGML_CUDA:BOOL=ON`, or missing runtime CUDA/NVIDIA proof is `BLOCKED` with preserved setup evidence. Missing CUDA proof blocks the run before S02/S03 row classification.

## Gates before final live execution

Dry-run gate:

```powershell
& ._design_docs\cache-handling-test-scripts\stage24-chat-s02-s03-comparison.ps1 `
  -RunId stage24-chat-s02-s03-YYYYMMDD-NN `
  -RowsToRun S02-chat,S03-chat `
  -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
  -RunRoot ._test_output\stage24-chat-s02-s03-YYYYMMDD-NN `
  -ReportPath ._design_docs\.test_reports\test-report-YYYYMMDD-NN.md `
  -CacheColdPath D:\tmp\cache-cold-stage24 `
  -BasePort 8900 `
  -LegDurationMin 10 `
  -ColdBudgetMiB 512 `
  -LlamaServerPath build-cuda\bin\Release\llama-server.exe `
  -DryRun
```

Dry-run must write `dry-run-plan.json` under the run root and prove row ids, variant names, route, ports, flags, model path, cold path, run root, report path, leg cap, request class counts, and no server start. It must also show `--n-gpu-layers all` and `--fit off` on all four planned legs and expose the CUDA CMake cache proof state.

Route-only gate:

- Inspect `dry-run-plan.json` and the runner source. Every live request target must be `/v1/chat/completions`.
- No `/completion` fallback, native `/completion` baseline, or route substitution is allowed.
- If route-only proof fails, classify as `BLOCKED-runner-contract`; do not run final live legs.

Optional validation: syntax-only and dry-run checks are allowed during planning or review. Do not run final live requests before Manager opens execution.

## Final execution command

After Manager opens execution, run the same command without `-DryRun`:

```powershell
& ._design_docs\cache-handling-test-scripts\stage24-chat-s02-s03-comparison.ps1 `
  -RunId stage24-chat-s02-s03-YYYYMMDD-NN `
  -RowsToRun S02-chat,S03-chat `
  -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
  -RunRoot ._test_output\stage24-chat-s02-s03-YYYYMMDD-NN `
  -ReportPath ._design_docs\.test_reports\test-report-YYYYMMDD-NN.md `
  -CacheColdPath D:\tmp\cache-cold-stage24 `
  -BasePort 8900 `
  -LegDurationMin 10 `
  -ColdBudgetMiB 512 `
  -LlamaServerPath build-cuda\bin\Release\llama-server.exe
```

Default row contract:

| Row | Variant legs | Required route | Parallel | Workload | Cap |
| --- | --- | --- | ---: | --- | --- |
| S02-chat | native-legacy, hybrid-stage24 | `/v1/chat/completions` | 4 | concurrent multi-slot chat requests | 10 min per leg |
| S03-chat | native-legacy, hybrid-stage24 | `/v1/chat/completions` | 2 | exact-repeat, near-prefix, new-branch classes, 64 prefixes, seed 42 | 10 min per leg |

Every leg must launch with `--n-gpu-layers all` and `--fit off`.

## Required artifacts

Per leg:

- `launch.log`
- `server.out.log`
- `server.err.log`
- `server-flags.txt`
- `metrics-before.txt`
- `metrics-after.txt`
- `requests.jsonl`
- `summary.json`
- CUDA runtime proof in `summary.json` from `server.err.log` or `server.out.log`

Hybrid-only:

- redacted prompt evidence JSONL under `prompt-evidence/<row>/hybrid-stage24/`
- cold-path byte evidence

Per row:

- `<row>/comparison.json`

Per run:

- `dry-run-plan.json`
- `final-leak-scan.json`
- durable report at `.test_reports/test-report-YYYYMMDD-NN.md`

Missing required artifacts are `BLOCKED-evidence-missing` unless the row already has a stricter product `FAIL`.

## Evidence checks

Each `summary.json` and `comparison.json` must include:

- request counts, success counts, status counts, and error counts per variant
- prompt, generated, and total token sums
- `cache_n` count, sum, max, nonzero count, and nonzero rate
- prompt-time and total-time count, min, median, p95, max, and sum
- metric deltas for restore misses, prefix candidates, prompt evidence records, cold bytes, cold budget bytes, cold demotion skips, cold evictions, checkpoint admissions by shape, checkpoint admissions, and checkpoint admission failures
- cold budget state with metrics when exposed and filesystem byte fallback when metrics are unavailable
- cleanup state: owned process stopped and port free
- CUDA runtime proof state
- verdict and failure classification

The durable report must summarize:

- timing deltas from native to hybrid as comparison data, not as a performance claim
- `cache_n` delta and nonzero rate
- cache hit rate from response `cache_n > 0`, and from public metrics when available
- restore miss rate with bounded reason breakdown when exposed
- checkpoint admission success and failure totals split by bounded labels when exposed
- cold bytes and cold budget after values
- `source=openai-chat` and `method=rendered-text-boundary-inference` evidence for hybrid

Do not invent missing metrics. If a metric family is absent, classify the evidence item as `BLOCKED-metric-unavailable` unless logs, JSONL, or filesystem bytes prove the same contract. Keep the metric gap visible.

## Leak scan and redaction

Leak scan must cover the durable report, `requests.jsonl`, `summary.json`,
`comparison.json`, redacted evidence JSONL, server logs, and `final-leak-scan.json`.

Allowed durable evidence: row id, variant, request id, class name, hashes, token counts, bounded labels, namespace hashes, response status, aggregate timings, and relative artifact paths.

Forbidden durable evidence: raw prompt text, raw message content, full request JSON bodies, raw namespace ids, raw descriptor ids, raw paths inside prompt evidence, and serialized payload content.

A raw prompt leak from product output is `FAIL`. A raw prompt leak from
runner-authored artifacts is `FAIL-runner-contract`. Missing leak-scan output is
`BLOCKED-evidence-missing`.

## Classification

PASS requires:

- clean build and fresh binary evidence
- `GGML_CUDA:BOOL=ON` in `build-cuda/CMakeCache.txt`
- CUDA/NVIDIA runtime proof from every leg's startup log
- both variants use `/v1/chat/completions`
- S02 and S03 request sets complete for both variants
- required artifacts exist
- hybrid emits chat-boundary metadata, redacted evidence, bounded cold budget, and clean leak scan
- no request accounting loss, cross-slot contamination, corrupt restore, unsafe prefix restore, unbounded cold growth, or cleanup failure

FAIL:

- valid-setup product crash
- repeated HTTP 500 after health is established
- reproduced S02 hybrid `FAIL-http-request`
- reproduced S03 hybrid `FAIL-unsafe-prefix-restore`
- corrupt restore, unsafe prefix restore, or cross-slot state corruption
- raw prompt leak in product redacted output
- contradictory checkpoint admission success/failure evidence
- cold write failure without bounded handling
- unbounded cold growth

BLOCKED:

- stale binary, missing fixture, missing clean build, port collision after one retry, disk shortage, server never healthy, missing required evidence, missing required metric with no substitute, host capacity limit, runner contract violation, missing CUDA configure proof, or missing runtime CUDA/NVIDIA proof

If the earlier S02 risk reproduces, or if S03 hybrid near-prefix requests show nonzero `cache_n`, the final report must preserve the raw row evidence, classify the failure with the matching specific label, and stop closure until Developer test-results review decides the handoff.

`._design_docs/.test_reports/test-report-20260623-03.md` is invalid for Stage 24 closure. It records `GGML_CUDA=OFF`, so its S02/S03 row verdicts cannot be used until QA reruns Stage 24 with the corrected CUDA setup.

## Developer test-results review inputs

After execution, Developer review needs:

- durable report path and run root
- clean build logs and binary/DLL mtimes
- CUDA CMake cache proof and per-leg runtime CUDA proof
- dry-run plan and route-only proof
- per-row `comparison.json`
- per-leg `summary.json`
- request count/status summary
- timing and `cache_n` summaries
- metric-unavailable list with substitutes
- cold budget summary
- final leak scan result
- cleanup proof for every leg
- explicit classification of S02 hybrid HTTP failures and S03 unsafe-prefix evidence if seen
- list of product bugs, runner-contract blockers, setup blockers, or no issues

## Risks

| ID | Risk | Classification if hit | Handling |
| --- | --- | --- | --- |
| R24-TP-01 | Qwen3.5 MTP fixture cannot load with S02 `--parallel 4`. | `BLOCKED-host-capacity` | Preserve startup logs; do not lower parallelism without Manager approval. |
| R24-TP-02 | S02 hybrid repeats the implementation-smoke HTTP request failure. | `FAIL-http-request` | Preserve request JSONL and server logs; route to Developer review. |
| R24-TP-03 | S03 hybrid near-prefix requests have nonzero `cache_n`. | `FAIL-unsafe-prefix-restore` | Preserve near-prefix request rows and comparison JSON; route to Developer review. Native near-prefix `cache_n` is diagnostic only. |
| R24-TP-04 | Hybrid chat metadata is absent. | `FAIL` or `BLOCKED-runner-contract` by setup evidence | Do not substitute `/completion` fallback metadata. |
| R24-TP-05 | Exact S03 hit rate remains low but all misses are bounded and near-prefix is safe. | Not alone a FAIL | Report as comparison data and bounded behavior. |
| R24-TP-06 | Metrics are missing but logs, JSONL, or filesystem bytes prove the same contract. | Visible metric gap | Use substitute evidence and keep `BLOCKED-metric-unavailable` on the missing metric item. |

## Handoff

Status: Stage 24 closed per D-CLOSURE-24-01 (2026-06-25). Final QA report is `test-report-20260624-06.md`. Per-row final classification:

- S02-chat native-legacy: PASS.
- S02-chat hybrid-stage24: PASS (was FAIL-http-request in -04; D-EXEC-24-01 verified).
- S03-chat native-legacy: PASS.
- S03-chat hybrid-stage24: BLOCKED-structural-not-infra (D-EXEC-24-03).
- S03 unsafe-prefix check: PASS across -04, -05, -06 (hybrid near-prefix cache_n=0).

Manager decisions D-EXEC-24-01, D-EXEC-24-02, D-EXEC-24-03, and D-CLOSURE-24-01 are recorded verbatim in the closure part file [part-16-manager-closure-20260625.md](../cache-handling-phase24-implementation/part-16-manager-closure-20260625.md). Two code changes in `tools/server/server-cache-hybrid.cpp` are uncommitted per AGENTS.md; user approval is required for commit.
