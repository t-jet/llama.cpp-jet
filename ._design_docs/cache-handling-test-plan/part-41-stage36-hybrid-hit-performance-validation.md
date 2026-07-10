# Test plan part 41: Stage 36 hybrid hit and performance validation

Status: test-plan review PASS; Manager test-plan gate PASS
Date: 2026-07-10
Stage: 36
Owner: QA
Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Scope

Stage 36 validates positive hybrid cache hits and performance on the current
tree using the Stage 33 comparison lineage with a tight duplicate workload.

Do not use the unchanged Stage 33 workload for this stage. Stage 33 already
classified zero hits as expected behavior for long-spaced duplicates with a
512 MiB hot cache.

## Required setup

Start from a clean Release CUDA configure and build:

```powershell
cmake -B D:\source\llama.cpp-jet\build-cuda -S D:\source\llama.cpp-jet -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON
cmake --build D:\source\llama.cpp-jet\build-cuda --config Release --target llama-server test-cache-controller -j 4
```

Then run:

```powershell
& D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe
ctest --test-dir D:\source\llama.cpp-jet\build-cuda -C Release -R cache -V
```

Record git HEAD, dirty status, CUDA proof, binary timestamps, direct controller
transcript, ctest transcript, and stale-binary proof.

## Workload

The implementation plan must provide either a Stage-36 workload mode or a
prebuilt workload input consumed by the comparison driver.

Minimum workload:

| Field | Value |
| --- | --- |
| Route | `/v1/chat/completions` |
| Bursts | 8 |
| Repeats per burst | 6 |
| Exact duplicate rows | 48 |
| Max tokens | 8 |
| Temperature | 0 |
| Seed | 42 |
| Prompt class | 2k unless implementation planning records a measured reason to reduce it |

Optional filler rows may be added if the implementation plan needs extra cache
pressure. Filler rows must not separate repeats inside the same burst.

## Evidence rows

| Row | PASS signal |
| --- | --- |
| Setup | Clean Release CUDA build, direct controller run, `ctest -R cache`, CUDA proof, fresh binary proof |
| Correctness | Output-equivalence `diff.txt` is empty |
| Hybrid hits | Hybrid repeat rows have nonzero cached tokens, and `llamacpp:cache_hits_total{mode="hybrid"}` increases |
| Namespace bounds | Public metric labels remain bounded; no raw namespace id label appears |
| Public metric labels | No raw namespace ids, prompt hashes, request ids, paths, payload ids, or free-form metadata appear as labels |
| HELP/TYPE shape | Each cache metric has at most one HELP line and one TYPE line |
| Hot RAM | Hybrid hot cache bytes are at least 40 percent below legacy, or a tighter-burst exception is documented without product bug |
| Cold store | Hybrid cold bytes/count are recorded and cold-store failure counters stay zero |
| Performance | Hybrid prompt/generation throughput is no more than 10 percent below legacy unless accepted host cause is documented |
| Errors | No crash, SEH dump, fatal request error, or product-level checksum/token mismatch |
| Cleanup | No `llama-server` process remains, port is free, final cold-path size/count recorded |
| Hygiene | Durable report and public artifacts do not expose prompt text, raw namespace ids, payload bytes, or local secret material |

## Classification

PASS requires every row to pass.

PARTIAL applies only when setup, correctness, hybrid hits, metric shape, errors,
cleanup, and hygiene pass but an optional warm cycle is stopped by the approved
wall-clock budget.

FAIL applies when the tight duplicate workload has zero hybrid hits, correctness
fails, public labels are unbounded, HELP/TYPE blocks duplicate, cold-store
failures increase, server logs show product errors, or unexplained throughput
regression exceeds 10 percent.

BLOCKED applies to invalid setup, missing fixture, stale binary, occupied port
without approved replacement, missing artifacts, or unsafe cleanup.

## Handoff

Next owner: QA execution. Product-code edits remain out of scope unless a Stage
36 report fails and Manager opens a correction loop.
