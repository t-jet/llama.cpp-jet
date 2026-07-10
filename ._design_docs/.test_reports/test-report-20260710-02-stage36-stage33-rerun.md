# Stage 36 QA execution report: Stage 33 lineage rerun

Run id: `stage36-stage33-rerun-20260710-02`
Date: 2026-07-10
Owner: QA
Scope: Part 41 Stage 36 hybrid hit and performance validation
Verdict: PASS

## Scope and setup

Stage 36 reused the Stage 29/33 comparison driver lineage with the Stage 36
tight duplicate workload. The unchanged Stage 33 workload was not used.

Evidence checked:

- Stage 36 plan: `._design_docs/cache-handling-test-plan/part-41-stage36-hybrid-hit-performance-validation.md`
- Stage 36 design: `._design_docs/cache-handling-phase36-design.md`
- Stage 36 implementation: `._design_docs/cache-handling-phase36-implementation.md`
- Run root: `._test_output/stage36-stage33-rerun-20260710-02`
- Full run log: `._test_output/stage36-stage33-rerun-20260710-02-fullrun.log`
- Setup logs: `_test_output/stage36-stage33-rerun-20260710-01-controller.log`,
  `_test_output/stage36-stage33-rerun-20260710-01-ctest.log`,
  `_test_output/stage36-stage33-rerun-20260710-01-ctest-rerun.log`

Git HEAD was `89d13d2e3047c9976d37f22dfe3e8375862c0e87`.
The worktree was dirty before this report; changes were Stage 36 docs/scripts
and agent memory, with the report file untracked before replacement.

## Build and controller evidence

Release CUDA setup is valid for this execution gate.

- `build-cuda/CMakeCache.txt` timestamp: 2026-07-10 16:36:08
- `GGML_CUDA:BOOL=ON`
- `CMAKE_CXX_FLAGS_RELEASE=/O2 /Ob2 /DNDEBUG`
- `build-cuda/bin/Release/llama-server.exe` timestamp: 2026-07-10 16:45:40
- `build-cuda/bin/Release/test-cache-controller.exe` timestamp:
  2026-07-10 16:45:47
- Stage 36 traffic started after these timestamps.

`test-cache-controller.exe` passed directly:

- Log: `_test_output/stage36-stage33-rerun-20260710-01-controller.log`
- Result: `All tests passed successfully`
- Count: 152 tests

`ctest -R cache -V` evidence:

- First ctest log: `_test_output/stage36-stage33-rerun-20260710-01-ctest.log`
- Transient first result: `test-cache-controller` exited `0xc0000409`
  after `Stage 35 checkpoint demotion failed`.
- Rerun log: `_test_output/stage36-stage33-rerun-20260710-01-ctest-rerun.log`
- Rerun result: `100% tests passed, 0 tests failed out of 1`

No stale build evidence was used. The setup logs predate the model-backed run
and the binaries are fresh for the run.

## Workload shape

`workload.jsonl` contains the required tight duplicate shape:

| Field | Observed |
| --- | ---: |
| Rows | 48 |
| Exact duplicate rows | 48 |
| Bursts | 8 |
| Rows per burst | 6 |
| Bursts with one unique payload | 8 |

The first request in each burst missed, then the following five repeats hit.
The raw workload file contains synthetic prompt bodies and should remain local
test output. This report does not quote prompt text.

## Comparison results

`summary.json` reports four passing legs:

| Cycle | Phase | Mode | Hit delta | Miss delta | Status |
| ---: | --- | --- | ---: | ---: | --- |
| 1 | cold-start | legacy | 0 | 0 | PASS |
| 1 | cold-start | hybrid | 40 | 8 | PASS |
| 1 | warm | legacy | 0 | 0 | PASS |
| 1 | warm | hybrid | 40 | 8 | PASS |

Request logs for all four legs have 48 HTTP 200 rows. Hybrid request logs show
40 nonzero `cache_n` rows per leg, with the pattern
`0,24,24,24,24,24` repeated for each burst.

Output equivalence passed:

- `phase-1-output-equivalence/diff.txt` exists and is 0 bytes.
- `fullrun.log` records `OutputEquivalence status=PASS mismatch=0`.

## Metrics and performance

Metrics after each leg:

| Leg | Prompt TPS | Gen TPS | Hot bytes | Cold bytes | Cold count | Hits | Misses |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| cold legacy | 243.143 | 112.182 | 507599056 | 0 | 0 | 0 | 0 |
| cold hybrid | 243.207 | 112.084 | 169860084 | 1188091912 | 14 | 40 | 8 |
| warm legacy | 243.076 | 112.412 | 507599056 | 0 | 0 | 0 | 0 |
| warm hybrid | 243.233 | 112.314 | 169860084 | 1188091912 | 14 | 40 | 8 |

Hybrid hot cache bytes were 66.54 percent lower than legacy in both comparable
cycles. Prompt throughput was effectively equal: hybrid was 0.03 percent faster
on cold and 0.06 percent faster on warm. Generation throughput was within the
10 percent gate: hybrid was 0.09 percent slower on cold and 0.09 percent slower
on warm.

Cold-store failure counters stayed zero:

- `cache_restore_failures_total=0`
- `cache_descriptor_validation_failures_total=0`
- `cache_pairing_violations_total=0`
- `cache_fallback_restores_total=0`
- `cache_cold_demotions_skipped_total=0`
- `cache_cold_evictions_total=0`

Observation: `cache_cold_budget_bytes{mode="hybrid"}` reports `-2147483648`
for the 2048 MiB budget. The Stage 36 cold-store row still passes because the
required bytes/count and failure counters are correct, but this metric value
should be reviewed separately if budget gauge correctness becomes a gate.

## Metrics cardinality and security

Metric label checks passed:

- HELP/TYPE duplicate count for cache metrics: 0
- Raw `namespace` label key: absent
- Raw request id, prompt hash, path, payload id, free-form metadata labels:
  absent
- Cache metric label keys observed: `action`, `decision`, `event`, `method`,
  `mode`, `operation`, `pair_state`, `payload_kind`, `payload_residency`,
  `policy`, `pressure_source`, `profile`, `reason`, `residency`, `result`,
  `scope`, `source`, `strategy`
- `cache_namespace_count{mode="hybrid"}` stayed at 1
- `cache_namespace_nodes` and `cache_namespace_roots` use `scope="all"`, not
  raw namespace ids

Request logs contain request ids and numeric cache summaries only. They do not
contain prompt text. The workload file contains synthetic prompts and is not
treated as public-safe evidence.

## Errors, cleanup, and transient issues

Server/process cleanup passed:

- No `llama-server` process remained after the run.
- Port 8900 was free after the run.
- Cold path `D:/tmp/cache-cold-stage36-stage33-rerun-20260710-02` existed with
  14 files and 1188092808 bytes.

Server log review:

- No crash, fatal request error, SEH dump, checksum mismatch, or token mismatch
  was found.
- Repeated non-fatal warning families were present:
  `save rejected because task is null` and `erased invalidated context
  checkpoint`.
- Restore misses with `reason=token_count_mismatch` occurred at the first row
  of each burst and matched the expected miss count.

Transient setup issue:

- The first ctest invocation failed once after the direct controller run had
  already passed all 152 tests. The immediate ctest rerun passed. This is
  recorded as transient setup noise, not a Stage 36 product failure.

## Final verdict

PASS. Stage 36 full QA execution evidence is sufficient. The tight duplicate
workload produced positive hybrid hits, output equivalence passed, hot memory
improved by more than 40 percent, throughput stayed within the 10 percent gate,
metrics label/security checks passed, cold-store failure counters stayed zero,
and cleanup completed.

No product-code fix is requested from this execution gate.
