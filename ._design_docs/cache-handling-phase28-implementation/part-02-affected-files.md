# Stage 28 implementation plan part 2: affected files

Source: [../cache-handling-phase28-implementation.md](../cache-handling-phase28-implementation.md)

This part lists, per implementation step, the files modified, the
estimated line-count change, and the test impact. Line counts are
estimates from design part-01 + part-03; final counts come from
the implementation log.

## Step 1: R28-BUG-01 (TP-26-UT6 test artifact)

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `tests/test-cache-controller.cpp` | replace assert() with explicit abort-on-fail at lines 3707, 3716-3729, 3736-3751, 3758-3765 | +30 / -10 net | TP-26-UT6 PASS post-fix (was abort); 138/138 unchanged |

No production file touched. No build file touched. No runner touched.

## Step 2: R28-BUG-03 (ASan LNK2038 mismatch)

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| side-channel `build-cuda-asan` CMakeLists.txt | add `target_compile_options(ggml-cuda PRIVATE /fsanitize=address)` with `$<COMPILE_LANGUAGE:CXX>` generator | +10 / -0 | future TP-26-UT6 + ASan rerun now possible; no current test impact |

No production file touched. No test file touched.

## Step 3: R28-BUG-02 (cold-store drift diagnosis)

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `tools/server/server-cache-hybrid.cpp` | add temporary SRV_DBG diagnostic logging at cold_budget_make_room, complete_demoted_payload, remove_payload | +30 / -0 (reverted after Step 4) | none; logs only; no test changes |

No permanent change to any file. Step 3 output is a single empirical
evidence path: `._test_output/stage24-r28-bug02-diag.log`.

## Step 4: R28-BUG-02 fix design + apply

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `tools/server/server-cache-hybrid.cpp` | apply fix at diagnosed line (Candidate A/B/C per Step 3 result); revert Step 3 logging | +5..30 / -5..10 net | none directly; S02 hybrid filesystem drift closes |
| `tests/test-cache-controller.cpp` | add TP-28-UT-01 unit test asserting n_cold_payload_bytes == sum(cold_payload_bytes_by_id_) == filesystem_bytes | +50 / -0 | test count 138 -> 139 |

## Step 5: R28-BUG-04 Phase A (fix prod callers)

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `tools/server/server-cache-hybrid.cpp` | load_slot line 4929: promote_payload -> tx_promote_payload; stage23_admit_checkpoint_store line 1875-1899: replace 6000-iter wait loop + process_completions() with single tx_promote_payload | +10 / -25 net | none directly; 30 s hang path closes on S03 hybrid cold checkpoint restore |

## Step 6: R28-BUG-04 Phase B (deprecate async API)

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `tools/server/server-cache-io-worker.h` | add `[[deprecated]]` markers to enqueue_demotion, enqueue_promotion, start, stop, drain_results, debug\_set\_queue\_capacity\_for\_tests, debug\_set\_completion\_delay\_for\_tests, debug\_set\_cold\_store\_for\_tests, debug\_io\_worker\_for\_tests | +10 / -0 | 41+ test refs surface as deprecation warnings; tests still pass |

## Step 7: R28-BUG-04 Phase B (migrate test refs)

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `tests/test-cache-controller.cpp` | migrate 41+ test refs from debug\*_io_worker_for_tests to execute_inline / execute\*_inline; remove debug queue/delay settings | +30 / -50 net | 138/138 unchanged; deprecation warnings -> 0 |

## Step 8: Iteration 1 verification

No files modified. Evidence-only step.

| Evidence path | Content |
| --- | --- |
| `._test_output/build-r28-bug01.log` | Step 1 build evidence |
| `._test_output/build-r28-bug02.log` | Step 4 build evidence |
| `._test_output/build-r28-bug03-asan.log` | Step 2 build evidence |
| `._test_output/build-r28-bug04-phase-a.log` | Step 5 build evidence |
| `._test_output/test-r28-bug01.log` | Step 1 unit test evidence |
| `._test_output/test-r28-bug02-unit.log` | Step 4 unit test evidence |
| `._test_output/stage24-r28-bug02-diag.log` | Step 3 diagnostic evidence |
| `._design_docs/.test_reports/test-report-20260627-01.md` | Stage 24 -08 iter 1 rerun |

## Step 9: MEDIUM items

| Path | Item | Lines | Test impact |
| --- | --- | ---: | --- |
| `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1` | R28-TD-04 (leak_scan Add-Member) + R28-TD-07 (--crash-dump-dir pass-through) | +5 / -0 | runner exit code 0 post-fix |
| `tests/test-cache-controller.cpp` | R28-TD-02 TP-28-UT-03 (demote queue saturation) | +40 / -0 | 139 -> 140 |
| `tests/test-cache-controller.cpp` | R28-TD-03 TP-28-UT-02 (SEH activation smoke, Windows-only) | +30 / -0 | 140 -> 141 |
| `._design_docs/cache-handling-phase24-implementation/part-16-manager-closure-20260625.md` | R28-TD-01 stale closure-link text | +5 / -0 | none |
| `._design_docs/cache-handling-phase27-design/part-04-verification-plan.md` | R28-TD-06 tense update | +3 / -0 | none |

## Step 10: R28-TD-05 worker thread deletion (conditional)

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `tools/server/server-cache-io-worker.h` | remove worker thread internals + LLAMA_SERVER_CACHE_TESTS debug accessors | -25 / +0 | test count unchanged |
| `tools/server/server-cache-io-worker.cpp` | remove worker thread internals + debug accessor bodies | -10 / +0 | none |
| `tools/server/server-cache-hybrid.h` | remove debug_*_io_worker_for_tests forward declarations | -5 / +0 | none |

## Total estimated diff by category

| Category | Lines |
| --- | ---: |
| Production code (server-cache-hybrid.cpp, server-cache-io-worker.{h,cpp}, server-cache-hybrid.h) | ~95 |
| Test code (test-cache-controller.cpp) | ~190 |
| Build files (side-channel CMakeLists.txt) | ~10 |
| Runner (stage24-chat-s02-s03-comparison.ps1) | ~5 |
| Docs (durable planning files) | ~8 |
| Total | ~308 across ~7 files |

## Total estimated diff by step

| Step | Category | Lines |
| --- | --- | ---: |
| Step 1 | test | +20 net |
| Step 2 | build | +10 |
| Step 3 | production (temporary diagnostic, reverted) | +30 transient |
| Step 4 | production + test | +55 net |
| Step 5 | production | -15 net |
| Step 6 | production | +10 |
| Step 7 | test | -20 net |
| Step 8 | evidence | 0 |
| Step 9 | test + runner + docs | +83 net |
| Step 10 | production + test | -40 net |
| Total net | | +135 net across files |

Iteration 1 net diff: +95 lines (+30 Step 1, +10 Step 2, +55 Step 4,
+10 Step 6, -10 Step 5 average, +0 Step 7, +0 Step 8).

Iteration 2 net diff: +43 lines (+83 Step 9, -40 Step 10).

## Test impact summary

| Step | New tests | Tests passing post-step |
| --- | ---: | ---: |
| Step 1 | 0 | 138 (TP-26-UT6 no longer aborts) |
| Step 4 | TP-28-UT-01 | 139 |
| Step 7 | 0 | 139 |
| Step 9.2 | TP-28-UT-02 | 140 |
| Step 9.3 | TP-28-UT-03 | 141 |
| Step 10 | 0 | 141 |

Final test count post-Stage 28: 141 (was 138 pre-Stage 28).

This file uses LF line endings, plain ASCII status labels, no
BOM, no trailing whitespace, and stays under the 300-line
durable-doc cap.
