# Part 2: Affected code surfaces

Status: planning
Date: 2026-06-26
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Author: Developer
Scope source: [cache-handling-phase26-design](../cache-handling-phase26-design)

## Files added

| Path | Purpose | Lines (est.) |
| --- | --- | ---: |
| `tools/server/server-crash-handler.h` | SEH filter install API + Windows guard | 25 |
| `tools/server/server-crash-handler.cpp` | `SetUnhandledExceptionFilter` + `MiniDumpWriteDump` + recursive-crash `__try/__except` | 110 |

## Files modified

| Path | Step | Change scope | Lines (est.) |
| --- | --- | --- | ---: |
| `tools/server/CMakeLists.txt` | 1 | Add `server-crash-handler.cpp` under `if(WIN32)` | 4 |
| `tools/server/llama-server.cpp` | 1 | Install filter at top of `main()`; parse `--crash-dump-dir` flag | 12 |
| `tools/main.cpp` (or `llama-server.cpp` arg parser) | 1 | Add `--crash-dump-dir <path>` CLI option, default empty | 10 |
| `tools/server/server-cache-hybrid.h` | 2 | Add `cold_payload_bytes_by_id_` map and `cold_payload_files_count_` counter | 6 |
| `tools/server/server-cache-hybrid.cpp` | 2 | `handle_demotion_completion`, `cold_budget_make_room`, `mark_payload_kind_evicted`, `mark_payload_evicted`, `update()` cold cleanup, restore-init directory walk | 90 |
| `tools/server/server-cache-io-worker.cpp` | 2 | Verify `result.target_bytes.size() + result.draft_bytes.size()` available at completion; populate `cold_payload_bytes_by_id_` accurately. If `bytes_written` is not yet exposed, add it to `io_completion_result` in `tools/server/server-cache-io-worker.h` | 15 |
| `tools/server/server-cache-io-worker.h` | 2 | Add `uint64_t bytes_written = 0` to `io_completion_result` (if not present) | 4 |
| `tools/server/server-context.cpp` | 3 | 67 metric-name renames + 1 label-name rename at line 4537 + duplicate fix at line 4541 | 70 |
| `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1` | 5 | 10 metric-name updates in `$MetricNames`; 3 updates in `metric_delta_comparison`; add `metrics_format_pass` + `label_uniqueness_pass` + `cold_store_drift_ratio` to leg summary | 30 |
| `._design_docs/cache-handling-test-scripts/execute_tests.ps1` | 6 | 10 regex updates from `llamacpp_cache_.*` to `llamacpp:cache_.*` | 12 |
| `tests/test-cache-controller.cpp` | 8 + 10 | 5 new unit tests + main() count summary update | 220 |

## Production code line totals (estimate)

| Category | Lines |
| --- | ---: |
| New C++ source (crash handler) | 135 |
| Modified C++ source (hybrid controller, io-worker, context, main) | 207 |
| Modified CMake | 4 |
| **Production code total** | **~346** |

## Test code line totals (estimate)

| Category | Lines |
| --- | ---: |
| 5 new unit tests | 200 |
| Count summary update | 1 |
| **Test code total** | **~201** |

## Runner / fixture line totals (estimate)

| Category | Lines |
| --- | ---: |
| stage24-chat-s02-s03-comparison.ps1 | 30 |
| execute_tests.ps1 | 12 |
| **Runner / fixture total** | **~42** |

## Public API changes (binding)

| Surface | Change | Severity |
| --- | --- | --- |
| CLI flag `--crash-dump-dir <path>` | NEW | diagnostic; explicit operator opt-in |
| Metric NAMES `llamacpp_X` -> `llamacpp:X` | breaking rename | BREAKING for Prometheus scrapers |
| Metric NAMES `cache_X` -> `llamacpp:cache_X` | breaking rename | BREAKING for Prometheus scrapers |
| Label name `mode` -> `scope` on `cache_prompt_evidence_records_total` | breaking rename | BREAKING for label-based dashboards |
| JSON stats field names (`n_hits`, `n_misses`, etc.) | NONE | preserved |
| `/stats` or `get_cache_stats()` payload | NONE | preserved |
| Endpoint schemas | NONE | preserved |

## Dependency graph

- Step 1 (SEH) is independent of Steps 2-11. Can run first or in
  parallel with Steps 2-3.
- Step 2 (cold-store accounting) is independent of Steps 1, 3, 5-7.
- Step 3 (metric renames) must come BEFORE Steps 5-7 (which match the
  new names).
- Step 8 (new tests) requires Step 2 complete (tests reference the
  new per-id map).
- Step 9 (full build + tests) requires Steps 2, 3, 8 complete.
- Step 10 (count summary) requires Step 8 complete (knows total = 137).
- Step 11 (rerun) requires Steps 3, 5, 9 complete (binary emits new
  names, runner matches, all unit tests pass).
- Step 12 (docs) requires Step 11 complete (test report exists).

## Files NOT touched (binding)

- `tools/server/server-*.h` / `tools/server/server-*.cpp` other than
  the files listed above.
- `tests/test-*.cpp` other than `test-cache-controller.cpp`.
- `._design_docs/.test_reports/test-report-*.md` (existing reports
  stay immutable; new report goes to `test-report-20260626-01.md`).
- `._design_docs/cache-handling-stage-tracker.md` (Manager owns).
- `._design_docs/document-index.md` (Manager owns).
- Any closed stage's implementation log (`cache-handling-phase24-implementation/`,
  `cache-handling-phase25-implementation/`).

## Handoff

Part-02 is reviewable. Next: part-03 evidence plan.
