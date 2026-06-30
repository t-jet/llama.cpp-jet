# Stage 32 QA execution report 2026-06-30 01

VERDICT: FAIL

## Scope and status

Stage 32 ran the approved live legacy-vs-hybrid comparison workflow after the
Stage 31 namespace and metric-shape fixes. Product code was not edited.

Traffic stopped at the user-requested 180 minute budget. Completed traffic was
enough to classify FAIL: completed hybrid exact-repeat rows still had zero
reuse (`cache_hit=true` count 0 and `cache_n > 0` count 0), and bounded-label
scan found public cache metrics using `namespace="all"` labels under the
accepted Stage 32 regex.

Artifact root:

```text
D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01
```

Proof root:

```text
D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01\stage32-proof
```

Cold path:

```text
D:\tmp\cache-cold-stage32-20260630-01
```

## Commands

Clean configure:

```powershell
cmake -B "D:\source\llama.cpp-jet\build-cuda" -S "D:\source\llama.cpp-jet" -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON
```

Build:

```powershell
cmake --build "D:\source\llama.cpp-jet\build-cuda" --config Release --target llama-server test-cache-controller -j 4
```

Focused tests:

```powershell
& D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe
ctest --test-dir "D:\source\llama.cpp-jet\build-cuda" -C Release -R cache -V
```

Dry run and full run used
`._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1` with
`RunId=stage32-cache-modes-20260630-01`, `RequestCount=200`, `Cycles=3`,
`ContextSize=4096`, `Parallel=2`, `BasePort=8900`, and
`OutputEquivalencePrompts=5`. Command transcripts are in
`driver-dry-run.command.txt` and `driver-full.command.txt`.

## Setup evidence

| Gate | Verdict | Evidence |
| --- | --- | --- |
| Clean Release CUDA configure | PASS | `build-configure.exit.txt` = 0; `cuda-proof.txt` = `GGML_CUDA:BOOL=ON`. |
| Release build | PASS | `build-llama-server-test-cache-controller.exit.txt` = 0. Build log contains known advisory Release warnings only. |
| Direct controller | PASS | Sequential rerun `test-cache-controller-rerun.exit.txt` = 0, 142 tests passed. An earlier concurrent direct run was discarded because it overlapped `ctest`. |
| `ctest -R cache` | PASS | `ctest-cache.exit.txt` = 0, 1/1 tests passed. |
| Stale-binary proof | PASS | `stale-binary-proof.json`: server and controller binaries are newer than Stage 31 source timestamps. |
| Dry-run/preflight | PASS | `driver-dry-run.exit.txt` = 0; stdout reports fixture exists, binary exists, port free, CUDA proof PASS, status PASS. |

Git HEAD: `96398cceca0c54ffe9fa2a016fbdba8811461bf1`.

## Completed legs

| Leg | Mode | Requests | Status | Notes |
| --- | --- | ---: | --- | --- |
| cold-start-cycle-1 | legacy | 200 | PASS | `summary.json`, metrics, requests present. |
| cold-start-cycle-1 | hybrid | 200 | PASS-driver | Acceptance FAIL for reuse. |
| warm-cycle-1 | legacy | 200 | PASS | `summary.json`, metrics, requests present. |
| warm-cycle-1 | hybrid | 200 | PASS-driver | Acceptance FAIL for reuse. |
| warm-cycle-2 | legacy | 200 | PASS | Completed before budget stop. |
| warm-cycle-2 | hybrid | partial | STOPPED | `metrics-before.txt` exists; traffic stopped at 180 minute budget. |
| warm-cycle-3 | legacy | 0 | NOT-RUN | Budget reached first. |
| warm-cycle-3 | hybrid | 0 | NOT-RUN | Budget reached first. |

## Row verdicts

| Row | Verdict | Evidence |
| --- | --- | --- |
| Correctness | PASS | `phase-1-output-equivalence\diff.txt` is empty; legacy and hybrid decoded files are present. |
| Reuse | FAIL | `cache-reuse-by-class.json`: exact 156 rows, `cache_hit_true=0`, `cache_n_gt_zero=0`; near-prefix 130 rows also zero. `hybrid-hit-deltas.json`: two completed hybrid legs both `hit_delta=0`, `miss_delta=200`. |
| Namespace bounds | PASS | `namespace-metric-forms.json`: `llamacpp:cache_namespace_count{mode="hybrid"}` is 1 for both completed hybrid legs. |
| Bounded labels | FAIL | `bounded-label-scan.json`: 22 findings. Metrics still expose label name `namespace` with value `all`. No raw namespace ID was found, but the accepted Stage 32 regex forbids the label name. |
| HELP/TYPE | PASS | Per-scrape check `help-type-counts-per-file.json`: duplicate count 0 for each hybrid `metrics-after.txt`. The aggregate extractor file counts duplicates across two scrape files and is not a per-scrape product failure. |
| Hot RAM | PASS | `hot-ram-cache-bytes.json`: legacy max 444252428 bytes, hybrid max 168745336 bytes, 62.02 percent reduction. |
| Cold store | PASS | `cold-store-size-count.json`: 26 files, 2136535108 bytes; `cold-failure-counters.json` values are all zero. |
| Performance | PASS for completed comparable prompt path | `performance-by-leg.json`: cold prompt TPS estimate hybrid 238.50 vs legacy 237.89; warm-cycle-1 hybrid 238.21 vs legacy 238.46. Generation TPS was not available from `requests.jsonl`; server timing logs are preserved. |
| Errors | PASS with warnings preserved | `server-error-scan.json` is empty. `server.err.log` contains repeated `restore miss classified (reason=token_count_mismatch...)`, `save rejected because task is null`, and checkpoint invalidation warnings, which align with the reuse failure evidence. |
| Cleanup | PASS | `cleanup-proof.json`: port 8900 free, `llama_server_process_count=0`, GPU memory 0/0 MiB, cold path retained with 26 files. |
| Hygiene | PASS for durable report | This report contains no prompts, payload bytes, raw namespace IDs, or message text. Non-durable workload/request artifacts remain under `_test_output` as required evidence. |

## Key metrics

Hybrid reuse on completed legs:

```text
exact: count=156, cache_hit_true=0, cache_n_gt_zero=0, cache_n_max=0
near_prefix: count=130, cache_hit_true=0, cache_n_gt_zero=0, cache_n_max=0
new_branch: count=114, cache_hit_true=0, cache_n_gt_zero=0, cache_n_max=0
```

Completed hybrid hit deltas:

```text
cold-start-cycle-1 hybrid: hit_delta=0, miss_delta=200
warm-cycle-1 hybrid: hit_delta=0, miss_delta=200
```

Namespace and storage:

```text
namespace_count=1 on completed hybrid metrics-after snapshots
hybrid cache_bytes max=168745336
legacy cache_bytes max=444252428
cold files=26
cold bytes=2136535108
```

## Failure evidence

Primary failure:

```text
D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01\stage32-proof\cache-reuse-by-class.json
D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01\stage32-proof\hybrid-hit-deltas.json
```

The workload contained exact repeats in every completed leg
(`summary.json`: `exact=78` per leg). Completed hybrid traffic still produced
no cache hit and no restored prompt tokens. This meets the Stage 32 FAIL rule
for zero hybrid reuse on completed exact-repeat traffic.

Secondary metric-shape failure:

```text
D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01\stage32-proof\bounded-label-scan.json
```

The scan found `namespace="all"` label names on 11 cache metric lines in each
completed hybrid metrics snapshot. This is bounded in value but fails the
accepted Stage 32 label-name regex from implementation Part 02.

## Open rows

The run did not complete warm-cycle-2 hybrid, warm-cycle-3 legacy, or
warm-cycle-3 hybrid because the 180 minute budget ended. Those rows remain
not-run, but they are not needed for the verdict because completed hybrid
exact-repeat evidence already fails the acceptance gate.

## Handoff

Status: bug handoff.

Next owner: Developer/Manager correction loop. Start from the zero-reuse
failure on completed exact-repeat traffic. Useful preserved logs include
`server.err.log`, all completed `requests.jsonl`, `metrics-before.txt`,
`metrics-after.txt`, `summary.json`, and the derived JSON files under
`stage32-proof`.
