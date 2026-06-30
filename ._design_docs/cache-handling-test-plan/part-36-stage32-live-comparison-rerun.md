# Test plan part 36: Stage 32 live comparison rerun

Status: authored; pending Manager test-plan gate
Date: 2026-06-30
Stage: 32 (post-Stage-31 live comparison rerun)
Owner: QA
Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)
Scope: test planning for the Stage 32 model-backed comparison. Do not treat
this as live-run evidence.

## References

Design:

- [Stage 32 design](../cache-handling-phase32-design.md)
- [Stage 32 design review PASS](../cache-handling-phase32-design/part-01-design-review-20260630.md)

Implementation and execution handoff:

- [Stage 32 implementation plan](../cache-handling-phase32-implementation.md)
- [Stage 32 plan corrections](../cache-handling-phase32-implementation/part-02-plan-corrections-20260630.md)
- [Stage 32 implementation-plan re-review PASS](../cache-handling-phase32-implementation/part-03-implementation-plan-re-review-20260630.md)
- [Stage 31 focused QA report](../.test_reports/test-report-20260629-13-stage31-01.md)
- [Stage 30 comparison baseline](../.test_reports/test-report-20260629-12-stage30-01.md)

Prior plan rules:

- [Part 24: test output folder convention](./part-24-test-output-folder-convention.md)
- [Part 29: Stage 24 chat comparison](./part-29-stage24-chat-s02-s03-comparison.md)
- [Part 35: Stage 31 hybrid cache misbehavior](./part-35-stage31-hybrid-cache-misbehavior.md)

## Scope

Stage 32 reruns the Stage 29/30 legacy-vs-hybrid comparison on the current
tree after Stage 31 fixed namespace compatibility and Prometheus metric shape.
This is an execution plan gate only. Do not run the full comparison during the
planning gate.

In scope:

- Clean Release CUDA configure and build of `llama-server` and
  `test-cache-controller`.
- Focused controller evidence: direct `test-cache-controller` run and
  `ctest -R cache`.
- Stale-binary proof from the corrected implementation plan.
- Driver dry-run/preflight before live traffic.
- Full comparison run shape and 150 to 180 minute wall-clock budget.
- Evidence rows for correctness, reuse, namespace bounds, bounded labels,
  HELP/TYPE, hot RAM, cold store, performance, errors, cleanup, and hygiene.
- PASS, PARTIAL, FAIL, and BLOCKED classification for live execution.

Out of scope:

- Product-code edits before live evidence fails and Manager opens a correction
  loop.
- Debug-only build repair for the known const-mutex issue.
- Cleaning pre-existing Release warnings unless they become errors or affect
  Stage 32 evidence extraction.
- Rewriting the comparison driver except for Manager-approved evidence-only
  extraction.

## Output locations

Durable report:

```text
._design_docs/.test_reports/test-report-20260630-01-stage32-01.md
```

Non-durable run root:

```text
_test_output/stage32-cache-modes-20260630-01/
```

Hybrid cold path:

```text
D:\tmp\cache-cold-stage32-20260630-01
```

If the execution date or suffix changes, use the next chronological suffix and
keep the durable report, run root, and cold path aligned. Do not reuse a suffix
after any setup artifact has been created.

## Build and focused evidence gate

Stale builds are invalid evidence. Start from a clean Release CUDA configure
and build:

```powershell
cmake -B D:\source\llama.cpp-jet\build-cuda -S D:\source\llama.cpp-jet -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON
cmake --build D:\source\llama.cpp-jet\build-cuda --config Release --target llama-server test-cache-controller -j 4
```

Then run focused controller evidence:

```powershell
& D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe
ctest --test-dir D:\source\llama.cpp-jet\build-cuda -C Release -R cache -V
```

Record build logs, controller transcript, ctest transcript, git HEAD, dirty
status, `GGML_CUDA:BOOL=ON`, and binary path, size, and UTC timestamp for both
executables.

Run the stale-binary proof from implementation Part 02. The proof must compare
`llama-server.exe` against the newest Stage 31 production source and
`test-cache-controller.exe` against `tests/test-cache-controller.cpp`. Accepted
proof is `status=PASS` with both newer-than-source booleans true. Otherwise
classify setup as `BLOCKED-stale-binary`.

## Dry-run/preflight

Before live traffic, run the corrected dry-run command from the implementation
plan:

```powershell
pwsh -NoProfile -File D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1 `
    -DryRun `
    -RunId stage32-cache-modes-20260630-01 `
    -ModelPath D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
    -RunRoot D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01 `
    -ReportPath D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-01-stage32-01.md `
    -CacheColdPath D:\tmp\cache-cold-stage32-20260630-01 `
    -LlamaServerPath D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe `
    -BasePort 8900 -ColdBudgetMiB 2048 -HotBudgetMiB 512 `
    -ContextSize 4096 -Parallel 2 -Seed 42 -RequestCount 200 `
    -Cycles 3 -OutputEquivalencePrompts 5
```

Dry-run/preflight must prove the model path exists, the fresh binary path is
used, port 8900 is available or Manager approved an alternate base port, the
run root and report path match this plan, the cold path is unique for this run,
and no server starts during dry-run.

## Full comparison command

After Manager opens execution, run the same command without `-DryRun`:

```powershell
Remove-Item -LiteralPath D:\tmp\cache-cold-stage32-20260630-01 -Recurse -Force -ErrorAction SilentlyContinue
pwsh -NoProfile -File D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1 `
    -RunId stage32-cache-modes-20260630-01 `
    -ModelPath D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
    -RunRoot D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01 `
    -ReportPath D:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260630-01-stage32-01.md `
    -CacheColdPath D:\tmp\cache-cold-stage32-20260630-01 `
    -LlamaServerPath D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe `
    -BasePort 8900 -ColdBudgetMiB 2048 -HotBudgetMiB 512 `
    -ContextSize 4096 -Parallel 2 -Seed 42 -RequestCount 200 `
    -Cycles 3 -OutputEquivalencePrompts 5
```

Run shape:

| Setting | Value |
| --- | --- |
| Route | `/v1/chat/completions` |
| Modes | `legacy`, then `hybrid` |
| Concurrency | Sequential servers only |
| Context and parallelism | `ContextSize=4096`, `Parallel=2` |
| Workload | `RequestCount=200`, `Seed=42`, `SizeClass=2k` from the driver |
| Equivalence | `OutputEquivalencePrompts=5` |
| Cycles | cold cycle plus 3 warm cycles |
| Wall clock | reserve 150 min; allow 180 min if progress continues |

Do not kill a leg before the budget expires unless the server stops making
progress, cleanup becomes unsafe, or Manager changes the run scope. Preserve
partial artifacts.

## Evidence rows

| Row | Evidence | PASS signal |
| --- | --- | --- |
| Correctness | decoded output files and `diff.txt` | output equivalence passes with empty diff |
| Reuse | hybrid `requests.jsonl`, `cache-reuse-by-class.json`, hit deltas | exact-repeat hybrid rows show `cache_hit=true` or `cache_n > 0`; at least one hit delta is positive |
| Namespace bounds | `namespace-metric-forms.json`, hybrid `metrics-after.txt` | namespace count is <= 4 or every split has a documented compatibility cause |
| Bounded labels | `bounded-label-scan.json` | empty array or only accepted bounded labels |
| HELP/TYPE | `help-type-counts.json` | no cache metric has duplicate HELP or TYPE |
| Hot RAM | `hot-ram-cache-bytes.json` | hybrid hot cache bytes at least 40 percent below legacy on comparable completed legs |
| Cold store | `cold-store-size-count.json`, failure counters, cold-path listing | non-zero cold bytes/count when demotion occurs; failure counters stay zero |
| Performance | summary rows, request timing extraction | prompt and generation throughput no more than 10 percent below legacy; p50/p99 recorded if available |
| Errors | `server-error-scan.json`, server stderr/stdout, driver logs | no crash, SEH dump, fatal error, repeated request error, or driver failure |
| Cleanup | `cleanup-proof.json` | port free, no `llama-server` process remains, final cold-path size/count recorded |
| Hygiene | durable report and run-root leak scan or grep evidence | no raw prompt text, message content, raw namespace ids, paths, or payload bytes in public/durable evidence |

Use the evidence-only extractor from implementation Part 02 after the driver
exits or is stopped at the approved budget. It may write derived JSON under
`stage32-proof`; it must not change traffic or product behavior.

## Classification

PASS requires all evidence rows to pass, clean focused controller evidence,
fresh CUDA binary proof, output equivalence, non-zero live hybrid reuse,
bounded namespace and metric shape, lower hybrid hot RAM, zero cold-store
failures, acceptable performance, clean errors, cleanup proof, and hygiene.

PARTIAL applies when correctness and bounded-memory checks pass but the full
warm-cycle set does not finish inside the 150 to 180 minute budget. The report
must list completed legs, open rows, and preserved artifacts.

FAIL applies when output equivalence fails, hybrid reuse remains zero on
completed exact-repeat traffic, namespace cardinality is high without a real
compatibility split, public labels are unbounded, HELP/TYPE blocks duplicate,
cold-store failures increase, stderr shows crashes or repeated request errors,
or throughput regresses by more than 10 percent without an accepted host cause.

BLOCKED applies to missing fixture, failed clean configure/build, missing CUDA
proof, stale binary, occupied port after allowed setup retry, server health
failure before request traffic, missing required artifacts, unsafe cleanup, or
host capacity limits that prevent valid row evidence.

## Handoff

Next owner: Manager test-plan gate, then QA execution after gate PASS. Product
edits remain out of scope unless live evidence fails and Manager opens a
correction loop.
