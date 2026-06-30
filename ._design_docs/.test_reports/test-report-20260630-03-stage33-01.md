# Stage 33 Full Legacy-vs-Hybrid A/B Comparison Report

Generated: 2026-06-30T21:37:44Z
RunId: stage33-cache-modes-20260630-01
Status: FAIL (Hybrid reuse row) / PARTIAL (incomplete warm cycle set)
Owner: QA
Source stage: Stage 32 (closed PASS)
Verdict: FAIL

## Setup evidence

### Git state

- HEAD: bf003631d77ceb9583439803eb9f13f7045d393d (Stage 32 closed, 2026-06-30 17:30:58 +0300)
- Dirty files (uncommitted) at run start: 2 .md + 1 untracked manager input
  - M ._design_docs/cache-handling-stage-tracker.md
  - M ._design_docs/document-index.md
  - ?? ._design_docs/.manager-inputs/manager-input-20260630-stage33-full-legacy-hybrid-ab-comparison.md
  - No working-tree changes to source files (tools/server/**, tests/**, common/**, src/**)

### CUDA proof from CMakeCache.txt

````
CMAKE_BUILD_TYPE:UNINITIALIZED=Release
GGML_CUDA:BOOL=ON
````

Cache file: D:\source\llama.cpp-jet\build-cuda\CMakeCache.txt (mtime 2026-06-30 16:03 local = 13:03 UTC)

### Binary state

| Binary | Path | Size (bytes) | UTC mtime |
| --- | --- | ---: | --- |
| llama-server.exe | D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe | 10240 | 2026-06-30 13:12:55 |
| llama-server-impl.dll | D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server-impl.dll | 12751872 | 2026-06-30 13:12:54 |
| llama-common.dll | D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-common.dll | 9177600 | 2026-06-30 13:12:41 |
| llama.dll | D:\source\llama.cpp-jet\build-cuda\bin\Release\llama.dll | 2080256 | 2026-06-30 13:12:24 |
| ggml-cuda.dll | D:\source\llama.cpp-jet\build-cuda\bin\Release\ggml-cuda.dll | 34838016 | 2026-06-30 13:12:09 |
| test-cache-controller.exe | D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe | 1070592 | 2026-06-30 13:13:01 |

Note: llama-server.exe is a thin launcher (10 KB) that loads llama-server-impl.dll (12 MB) plus llama.dll / llama-common.dll / ggml-cuda.dll. This is the standard llama-server layout.

### Stale-binary proof (Stage 32 corrected rules)

Binary freshness check: each binary mtime vs latest source mtime that affects it.

| Artifact | UTC mtime | Reference source | Source UTC mtime | Newer than source |
| --- | --- | --- | --- | --- |
| llama-server.exe | 2026-06-30 13:12:55 | tools/server/server-context.cpp | 2026-06-30 12:31:37 | yes |
| llama-server-impl.dll | 2026-06-30 13:12:54 | tools/server/server-context.cpp | 2026-06-30 12:31:37 | yes |
| test-cache-controller.exe | 2026-06-30 13:13:01 | tests/test-cache-controller.cpp | 2026-06-30 12:31:37 | yes |
| server-context.obj | 2026-06-30 13:12:49 | tools/server/server-context.cpp | 2026-06-30 12:31:37 | yes |
| test-cache-controller.obj | 2026-06-30 13:13:01 | tests/test-cache-controller.cpp | 2026-06-30 12:31:37 | yes |

Result: ALL artifacts newer than their source. No stale binary.
HEAD commit timestamp 14:30 UTC is later than binary timestamp 13:12-13:13 UTC, but the commit did not modify source-file content (only added .md docs, .py unit test, and a manager-input file). Working tree source matches HEAD per `git diff HEAD -- tools/server tests`. Binary is fresh relative to source content.

### Focused controller evidence

**Direct test-cache-controller run**:

- Command: `D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe`
- Exit code: 0
- Log: `_test_output\stage33-cache-modes-20260630-01-controller.log`
- Result: `All tests passed successfully!`
- Total: 142 tests (31 original + 111 across Stages 4-28 added)
- Notable Stage 31/32 cases all PASSED: `Stage 31 namespace uses runtime compatibility only`, `Stage 31 namespace cardinality bounded for prompt variants`, `Stage 31 metric shape bounded labels`, `Stage 26 cold payload files count matches disk`, `Stage 27 mark_payload_evicted releases hot memory inline`, `Stage 28 cold-store startup reconciles orphans`

**ctest -R cache**:

- Command: `ctest --test-dir D:\source\llama.cpp-jet\build-cuda -C Release -R cache -V`
- Exit code: 0
- Log: `_test_output\stage33-cache-modes-20260630-01-ctest.log`
- Output: `1/1 Test #28: test-cache-controller ... Passed  0.26 sec`
- `100% tests passed, 0 tests failed out of 1`

### Setup verdict: PASS

All required setup evidence captured. CUDA proof PASS, fresh binary proof PASS, focused tests PASS, port free, no server processes, dry-run preflight PASS.

## Dry-run verdict

Dry-run preflight output (verbatim from driver):

````
DryRun preflight: {"ps_version_ok":true,"binary_exists":true,"fixture_exists":true,"port_free":true,"cuda_proof":"PASS","git_head":"bf003631d77ceb9583439803eb9f13f7045d393d","git_dirty":4,"status":"PASS"}
````

- model exists: true
- binary exists: true (launcher + impl DLL)
- port 8900 free: true
- CUDA proof: PASS
- git head: bf003631d77ceb9583439803eb9f13f7045d393d
- git dirty: 4 (1 untracked stage33 report, 1 untracked stage33 manager input, 2 modified .md tracker/index; no source-code changes)
- overall: PASS
- No server started during preflight.
- Cold path D:\tmp\cache-cold-stage33-20260630-01 was fresh (no prior setup artifacts).

Verdict: dry-run PASS, proceed to full comparison.

## Full comparison run summary

Run start: 2026-06-30T18:28:11Z (background launcher)
Workload built: 2026-06-30T18:28:27Z (200 requests, 2058623 bytes)
Equivalence prompts built: 2026-06-30T18:28:27Z (5 prompts, 52506 bytes)

Per-leg timing:

| # | Leg | Server start UTC | Server end UTC | Duration | Summary row |
| --- | --- | --- | --- | ---: | --- |
| 1 | cold-start/legacy | 18:30:54 | 18:58:30 | 27.6 min | PASS (hit=0, miss=0) |
| 2 | cold-start/hybrid | 18:59:10 | 19:30:32 | 31.4 min | PASS (hit=0, miss=200) |
| 3 | warm-cycle-1/legacy | 19:31:12 | 19:59:06 | 27.9 min | PASS (hit=0, miss=0) |
| 4 | warm-cycle-1/hybrid | 19:59:45 | 20:34:11 | 34.4 min | PASS (hit=0, miss=200) |
| 5 | warm-cycle-2/legacy | 20:34:47 | 21:02:49 | 28.0 min | PASS (hit=0, miss=0) |
| 6 | warm-cycle-2/hybrid | 21:03:04 | 21:34:53 | 31.8 min | PASS (hit=0, miss=200) |
| 7 | warm-cycle-3/legacy | not started | not started | n/a | killed at 21:35 (budget exceeded) |
| 8 | warm-cycle-3/hybrid | not started | not started | n/a | killed at 21:35 (budget exceeded) |

Wall-clock at report time: ~187 min (start 18:28, killed 21:35). 6 of 8 legs complete; warm 2 hybrid finished at the 187 min mark, warm 3 legacy and warm 3 hybrid were killed to preserve partial artifacts (over 180 min budget).

## Output equivalence (Phase 1)

- legacy-decoded.txt: 4 bytes
- hybrid-decoded.txt: 4 bytes
- diff.txt: 0 bytes (empty)
- Driver emitted: `OutputEquivalence status=PASS mismatch=0`
- Verdict: PASS

## Per-cycle cache metrics comparison

Metrics extracted from each leg metrics-after.txt.

| Leg | cache_bytes (MiB) | cache_entries | cache_hits_total | cache_misses_total | cache_evictions_total | cache_restore_failures |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| cold-start/1/legacy | 423.7 | 2 | 0 | 0 | 0 | 0 |
| cold-start/1/hybrid | 160.9 | 2 | 0 | 200 | 397 | 0 |
| warm/1/legacy | 423.7 | 2 | 0 | 0 | 0 | 0 |
| warm/1/hybrid | 160.9 | 2 | 0 | 200 | 397 | 0 |
| warm/2/legacy | 423.7 | 2 | 0 | 0 | 0 | 0 |
| warm/2/hybrid | 160.9 | 2 | 0 | 200 | 397 | 0 |

Notes: legacy mode shows 0 cache_hits/misses because legacy uses different metric counter scheme (FIFO destructive hits, not llamacpp:cache_hits_total). Hybrid shows 0 hits in all 3 completed hybrid legs due to workload/cache-budget mismatch (see Critical finding).

## Hot RAM comparison (cache_bytes across legs)

| Leg | hybrid cache_bytes (MiB) | legacy cache_bytes (MiB) | hybrid / legacy |
| --- | ---: | ---: | ---: |
| cold-start-cycle-1 | 160.9 | 423.7 | 0.3798 |
| warm-cycle-1 | 160.9 | 423.7 | 0.3798 |
| warm-cycle-2 | 160.9 | 423.7 | 0.3798 |

Hybrid hot cache is ~62% below legacy on comparable completed legs (160.9 MiB vs 423.7 MiB). This meets the >= 40% reduction criterion.

## Performance comparison (per-leg throughput)

Per-request prompt processing time from each leg requests.jsonl.

| Leg | requests | http_200 | http_error | prompt_ms_avg | prompt_ms_p50 | prompt_ms_p95 | prompt_n_avg | cache_n_avg | cache_hit_rate |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| cold-start/1/legacy | 200 | 200 | 0 | 8178 | 8157.2 | 8341.2 | 1943 | 0.2 | 0.01 |
| cold-start/1/hybrid | 200 | 200 | 0 | 8177.2 | 8158.3 | 8351.1 | 1943 | 0 | 0 |
| warm/1/legacy | 200 | 200 | 0 | 8262.4 | 8263.9 | 8452.5 | 1943 | 0.2 | 0.01 |
| warm/1/hybrid | 200 | 200 | 0 | 8346.9 | 8348.3 | 8516.8 | 1943 | 0 | 0 |
| warm/2/legacy | 200 | 200 | 0 | 8182.8 | 8158.4 | 8348.7 | 1943 | 0.2 | 0.01 |
| warm/2/hybrid | 200 | 200 | 0 | 8204.5 | 8184.9 | 8382.1 | 1943 | 0 | 0 |

Hybrid prompt_ms p50 within 1-2% of legacy on all 3 completed legs; both modes ~8.1s average; no more than 10% regression.

## Cold-store state (D:\tmp\cache-cold-stage33-20260630-01)

- file_count: 26 .cold files
- total_bytes: 2038 MiB (within 2048 MiB budget)
- cold-store failure counters (server metrics): 0 across all 5 metrics-after snapshots

## Namespaces and labels analysis

### Distinct namespace ids in public metrics

- Distinct namespace ids across all metrics-after files: 0
- Public cache metrics use `mode=` label only; no `namespace=` label exposed; no `llamacpp:cache_namespace_count` counter emitted in public scrape. Stage 31 fix is preserved.

### Public label scan (metric format regression check)

Checking for raw prompt hashes, request ids, paths, payload ids as labels:

- Bad-label hits: 0 for `prompt_hash=`, `request_id=`, `payload_id=`, `namespace="all"`, `path=` patterns across all 6 metrics-after files.

### HELP/TYPE block uniqueness per metric name

- Files inspected: 6
- HELP duplicate metric names: 0
- TYPE duplicate metric names: 0

### Server error scan

- Forbidden log pattern hits (`token_count_mismatch`, `checksum_mismatch`, `SEH`, `fatal`, `Aborted`, `core dumped`): these appear in metrics and INFO-level server logs as `restore miss classified (reason=token_count_mismatch, ...)` lines. They are normal restore-miss classifications for the checkpoint_dependent profile with MTP model, not product errors. Per Stage 32 closure decision, these are not actual errors.
- No SEH, no fatal, no `core dumped`.
- No HTTP 5xx: all 6 completed legs returned 200/200 HTTP 200.

## Critical finding: hybrid hit_delta = 0 on all completed hybrid legs

Detailed hybrid metrics (warm-cycle-1/hybrid/metrics-after.txt):

````
llamacpp:cache_entries{mode="hybrid"} 2
llamacpp:cache_bytes{mode="hybrid"} 168745336
llamacpp:cache_tokens{mode="hybrid"} 3893
llamacpp:cache_hits_total{mode="hybrid"} 0
llamacpp:cache_misses_total{mode="hybrid"} 200
llamacpp:cache_evictions_total{mode="hybrid"} 397
llamacpp:cache_payload_evictions_total{mode="hybrid"} 198
llamacpp:cache_branch_nodes_created_total{mode="hybrid"} 200
llamacpp:cache_branch_lookup_hits_total{mode="hybrid"} 0
llamacpp:cache_branch_lookups_total{mode="hybrid",method="token_span"} 400
llamacpp:cache_branch_lookups_total{mode="hybrid",method="checksum_span"} 600
````

Cold-start cycle 1 hybrid and warm-cycle-2 hybrid had identical end-state (cache_entries=2, hit=0, miss=200, evictions=397).

Workload message analysis: 78 requests marked cache_class=exact use 41 unique message hashes; duplicates arrive 2-6 times each but spread across 200 requests at ~8-9s per request. With hot cache budget 512 MiB and entry size ~85 MiB, hot cache holds ~6 entries, so first occurrence of an anchor is evicted before its second occurrence arrives at most positions. Cold-start cycle 1 hybrid metrics-before shows cache_entries=0, indicating the cold-store is not auto-loaded into the hot cache at server start.

Stage 32 focused retest used 6 manual chat requests (5 exact repeats in tight burst) and showed hit_delta=5. The Stage 33 workload duplicates are too spaced for 6-entry hot cache to retain between occurrences. This may be a workload/cache-budget mismatch rather than a regression of the Stage 32 driver extraction fix.

## 12-row evidence classification

| Row | Verdict | Evidence path | One-line rationale |
| --- | --- | --- | --- |
| Setup | PASS | _test_output/stage33-cache-modes-20260630-01-controller.log, _test_output/stage33-cache-modes-20260630-01-ctest.log, build-cuda/CMakeCache.txt, _test_output/stage33-cache-modes-20260630-01-dryrun.log | Clean Release CUDA configure, test-cache-controller 142/142 PASS, ctest 1/1 PASS, GGML_CUDA:BOOL=ON, binary 13:12-13:13 UTC newer than source 12:31-12:39 UTC, dry-run preflight PASS. |
| Correctness | PASS | _test_output/stage33-cache-modes-20260630-01/phase-1-output-equivalence/diff.txt | diff.txt is 0 bytes; legacy and hybrid decoded text identical (4 bytes each). |
| Hybrid reuse | FAIL | _test_output/stage33-cache-modes-20260630-01/cold-start-cycle-1/hybrid/metrics-after.txt, _test_output/stage33-cache-modes-20260630-01/warm-cycle-1/hybrid/metrics-after.txt, _test_output/stage33-cache-modes-20260630-01/warm-cycle-2/hybrid/metrics-after.txt | llamacpp:cache_hits_total{mode="hybrid"} = 0 on all 3 completed hybrid legs, even though 78 of 200 requests are exact-repeat (41 unique message hashes, 2-6 duplicates each). |
| Namespace bounds | PASS | _test_output/stage33-cache-modes-20260630-01/**/metrics-after.txt | Public cache metrics use `mode=` label only; no `namespace=` label exposed; metric counter `llamacpp:cache_namespace_count` is not emitted in public scrape. |
| Public metric labels | PASS | _test_output/stage33-cache-modes-20260630-01/**/metrics-after.txt | 0 hits for `prompt_hash=`, `request_id=`, `payload_id=`, `namespace="all"`, `path=` patterns across all 6 metrics-after files. |
| HELP/TYPE shape | PASS | _test_output/stage33-cache-modes-20260630-01/**/metrics-after.txt | 0 duplicate HELP lines, 0 duplicate TYPE lines across all 6 metrics-after files. |
| Hot RAM | PASS | _test_output/stage33-cache-modes-20260630-01/**/metrics-after.txt | Hybrid cache_bytes ~161 MiB vs legacy ~424 MiB on all comparable completed legs: 62% reduction (>= 40% threshold met). |
| Cold store | PASS | D:\tmp\cache-cold-stage33-20260630-01\, _test_output/stage33-cache-modes-20260630-01/**/metrics-after.txt | 26 .cold files, 2038 MiB total (within 2048 MiB budget), 0 cold-store failure counters across all 6 metrics-after snapshots. |
| Performance | PASS | _test_output/stage33-cache-modes-20260630-01/**/requests.jsonl | Hybrid prompt_ms p50 within 1-2% of legacy on all 3 completed legs; both modes ~8.1s average; no more than 10% regression. |
| Errors | PASS | _test_output/stage33-cache-modes-20260630-01/**/server.err.log, _test_output/stage33-cache-modes-20260630-01/**/requests.jsonl | No crash, no SEH, no fatal error, no 5xx. All 6 completed legs returned 200/200 HTTP 200. token_count_mismatch and checksum_mismatch appear as INFO-level `restore miss classified` log lines (192 and 7 respectively) which are normal restore-miss classifications, not product errors. |
| Cleanup | PASS | (verification below) | No `llama-server` process remains, port 8900 free, cold-path final state recorded (26 .cold files, 2038 MiB). |
| Hygiene | PASS | _test_output/stage33-cache-modes-20260630-01/**/metrics-after.txt, _test_output/stage33-cache-modes-20260630-01/phase-1-output-equivalence/diff.txt | Metrics contain 0 prompt text, 0 raw namespace ids, 0 payload bytes; decoded diff is empty; this report contains 0 prompt excerpts. |

## Wall-clock analysis

- Run start: 2026-06-30T18:28:11Z (background launcher)
- Cold-start cycle 1 legacy: 18:30:54 -> 18:58:30 (27.6 min, includes model load + 200 requests)
- Cold-start cycle 1 hybrid: 18:59:10 -> 19:30:32 (31.4 min, includes model load + 200 requests)
- Warm cycle 1 legacy: 19:31:12 -> 19:59:06 (27.9 min, no model load)
- Warm cycle 1 hybrid: 19:59:45 -> 20:34:11 (34.4 min, no model load but heavy demotion work)
- Warm cycle 2 legacy: 20:34:47 -> 21:02:49 (28.0 min)
- Warm cycle 2 hybrid: 21:03:04 -> 21:34:53 (31.8 min)
- Run killed at 21:35:00 local to preserve partial artifacts (over 180 min budget by 7 min).
- 6 of 8 legs complete; 2 legs (warm 3 legacy, warm 3 hybrid) did not start.

## Cleanup verification

- No `llama-server` process remains: confirmed via `Get-Process | Where-Object llama-server*` (empty result).
- Port 8900 is free: confirmed via `Get-NetTCPConnection -LocalPort 8900` (empty result).
- Cold-path final state (D:\tmp\cache-cold-stage33-20260630-01): 26 .cold files, 2038.5 MiB (within 2048 MiB budget).
- All Phase 0.5 workload and equivalence prompt files preserved.
- All 6 completed legs preserved: cold-start-cycle-1/{legacy,hybrid}, warm-cycle-1/{legacy,hybrid}, warm-cycle-2/{legacy,hybrid}.
- Run was killed at 21:35 local time after 6 of 8 legs completed (187 min elapsed) to preserve partial artifacts.

## Hygiene scan results

- Public metrics: 0 prompt text, 0 raw namespace ids, 0 payload bytes, 0 paths.
- Diff files: empty.
- This report: 0 prompt excerpts; uses only structural references (test outputs, metric names, file paths, byte sizes).

## Overall verdict

**Verdict: FAIL**

Reason: The Hybrid reuse row fails. All 3 completed hybrid legs (cold-start cycle 1 hybrid, warm cycle 1 hybrid, warm cycle 2 hybrid) show `llamacpp:cache_hits_total{mode="hybrid"} = 0` and `cache_misses_total = 200`, even though 78 of 200 requests are exact-repeat traffic (41 unique message hashes, 2-6 duplicates each). The test plan PASS signal requires "exact-repeat hybrid rows show `cache_hit=true` or `cache_n > 0`, and `llamacpp:cache_hits_total{mode="hybrid"}` increases". This is not met on any completed leg.

Other 11 rows PASS: Setup, Correctness (diff.txt empty), Namespace bounds (no public namespace label), Public metric labels (no raw prompt_hash/request_id/path), HELP/TYPE shape (no duplicates), Hot RAM (hybrid 62% below legacy), Cold store (2038 MiB within 2048 MiB, 0 failures), Performance (within 1-2% on comparable legs), Errors (no crash, no SEH, no 5xx; token_count_mismatch and checksum_mismatch are INFO-level restore miss classifications, not product errors), Cleanup (no processes remain, port free), Hygiene (no prompt text or raw namespace ids in durable report or public metrics).

The run is also PARTIAL: 6 of 8 legs completed; warm 2 hybrid finished at 187 min (over 180 min budget by 7 min), warm 3 legacy and warm 3 hybrid were killed to preserve partial artifacts.

## Handoff to Developer

Next owner: Developer (test-results review).

### Workload design note (for Developer investigation)

The 0 hybrid hits may be a workload/cache-budget mismatch rather than a Stage 32 driver-extraction regression:

- Stage 32 focused retest used 6 manual chat requests with 5 exact repeats in tight burst and showed hit_delta=5.
- Stage 33 workload: 200 requests, 78 marked exact, but only 41 unique message hashes; duplicates appear 2-6 times each, spread across 200 requests at ~8-9s per request.
- With hot cache budget 512 MiB and entry size ~85 MiB, hot cache holds ~6 entries; first occurrence of an anchor is typically evicted before its second occurrence arrives.
- cold-start cycle 1 hybrid metrics-before shows cache_entries=0, so the cold-store payloads are not auto-loaded into hot cache at server start.

Developer review should determine whether the 0-hybrid-hits result is a product regression, a test-workload design issue, or a missing cold-store auto-restore feature.

### Files preserved at run root

- D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\summary.json (6 rows)
- D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\phase-1-output-equivalence\diff.txt (0 bytes; correctness PASS)
- D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\cold-start-cycle-1\{legacy,hybrid}\metrics-{before,after}.txt, requests.jsonl
- D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\warm-cycle-1\{legacy,hybrid}\metrics-{before,after}.txt, requests.jsonl
- D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\warm-cycle-2\{legacy,hybrid}\metrics-{before,after}.txt, requests.jsonl
- D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\workload.jsonl (2 MB, 200 requests)
- D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\equivalence-prompts.jsonl (52 KB, 5 prompts)
- D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01\server.out.log, server.err.log (for last completed leg)
- D:\tmp\cache-cold-stage33-20260630-01\ (26 .cold files, 2038 MiB)

### Logs

- D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01-fullrun.log (driver stdout)
- D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01-fullrun.err.log (driver stderr)
- D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01-controller.log (test-cache-controller transcript, 142/142 PASS)
- D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01-ctest.log (ctest -R cache transcript, 1/1 PASS)
- D:\source\llama.cpp-jet\_test_output\stage33-cache-modes-20260630-01-dryrun.log (dry-run preflight, status PASS)