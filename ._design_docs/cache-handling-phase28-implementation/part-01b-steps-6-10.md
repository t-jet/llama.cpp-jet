# Stage 28 implementation plan part 1B: ordered steps 6-10

Source: [../cache-handling-phase28-implementation.md](../cache-handling-phase28-implementation.md)
Companion: [part-01a-steps-1-5.md](./part-01a-steps-1-5.md)

Steps 6-10 continue the Stage 28 ordered implementation steps.
Steps 1-5 are in [part-01a](./part-01a-steps-1-5.md).

### Step 6: R28-BUG-04 Phase B (deprecate async API)

Add `[[deprecated]]` markers to all async-worker API surface so
remaining callers compile-error out. No test migration yet.

Precondition: Step 5 must complete so the 2 production callers
no longer reference the async API.

Action: in `tools/server/server-cache-io-worker.h`:

- Mark `enqueue_demotion`, `enqueue_promotion`, `start`, `stop`, `process_completions` (if present in header), `drain_results`, and the 4 debug_*_io_worker_for_tests accessors (debug_set_queue_capacity_for_tests, debug_set_completion_delay_for_tests, debug_set_cold_store_for_tests, debug_io_worker_for_tests) with `[[deprecated("async worker retired in Stage 25; use tx_* / execute_inline")]]`.

These deprecation markers will surface the 41+ test refs as
warnings first. Step 7 migrates them to the `execute_inline` /
`execute_*_inline` helpers and removes the warnings.

Stop condition:

- `cmake --build build-cuda --config Release --target test-cache-controller` exits 0 with deprecation warnings visible in the build log.
- The 2 production callers (load_slot line 4929 and stage23_admit_checkpoint_store line 1875) do NOT appear in the deprecation warning list (already migrated in Step 5).

Estimated diff: ~10 lines deprecation markers in header, 0 .cpp
changes.

### Step 7: R28-BUG-04 Phase B (migrate test refs)

Migrate the 41+ test refs from async API to `execute_inline` /
`execute_*_inline` helpers. This step is where the 41+ ref
audit (per R28-RISK-05) becomes binding.

Precondition: Step 6 deprecation markers are in place.

Action: in `tests/test-cache-controller.cpp` and any other test
file referencing `debug_*_io_worker_for_tests`:

- Replace `debug_start_io_worker_for_tests()` calls with `execute_inline()` helpers (or no-op if the test was depending on the worker being absent).
- Replace `debug_stop_io_worker_for_tests()` calls with `execute_*_inline()` invocations.
- Replace `debug_set_queue_capacity_for_tests(N)` calls with no-op or with `execute_*_inline` direct invocation.
- Replace `debug_set_completion_delay_for_tests(N)` calls with `execute_*_inline` direct invocation (the timing is now synchronous, no delay injection needed).
- Replace `debug_io_worker_for_tests()` accessors with `execute_*_inline` invocations.

If any test genuinely needs the worker thread's race timing
(e.g., queue saturation race tests per R28-RISK-05 worst case),
flag it as a new R28-TD-NN item and leave it as a build warning
for now (do not regress).

Stop condition:

- `cmake --build build-cuda --config Release --target test-cache-controller` exits 0 with zero deprecation warnings (or a documented exception list of 0-5 tests that genuinely need async timing).
- test-cache-controller.exe runs to completion (138 tests pass).
- Test count unchanged (41+ async test refs migrated, count stays at 138).

Estimated diff: ~80 lines test code, 0 production code change.

### Step 8: Iteration 1 verification (build + tests + Stage 24 -08)

Mandatory verification before iter 2 starts.

Action: per design part-04 cross-fix regression contract:

1. Clean Release build of `build-cuda/bin/Release/llama-server.exe`.
2. Clean Release build of `build-cuda/bin/Release/test-cache-controller.exe`.
3. Clean Release build of `build-cuda-asan/bin/Release/llama-server.exe`.
4. test-cache-controller.exe runs to completion (138 PASS, no abort).
5. Stage 24 -08 rerun via
   `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`
   against `build-cuda/bin/Release/llama-server.exe`, 10-min leg cap,
   `--cache-cold-max-mib 512`. Pass criteria:

- S02 hybrid filesystem bytes <= 512 MiB budget (was 5.37 GiB).
- S03 hybrid still >= 687 reqs vs 258 crash threshold.
- All 4 legs reach leg cap (was all 4 in -07).

Stop condition: V1.1..V1.5 + V2.1..V2.7 + V3.1..V3.4 of design
part-04 all PASS.

Estimated diff: 0 lines (evidence-only step).

### Iteration 1 deliverables (binding)

- build-cuda/bin/Release/llama-server.exe mtime fresh.
- build-cuda/bin/Release/test-cache-controller.exe mtime fresh.
- build-cuda-asan/bin/Release/llama-server.exe mtime fresh.
- 138 + 0 new tests pass (TP-28-UT-01 added in Step 4).
- Stage 24 -08 rerun PASS per design part-04 V2.5/V2.6/V2.7.
- Stage 24 -08 report at
  `._design_docs/.test_reports/test-report-20260627-01.md`.

---

## Iteration 2: MEDIUM severity (binding)

7 items: R28-TD-01, R28-TD-02, R28-TD-03, R28-TD-04, R28-TD-05
(conditional), R28-TD-06, R28-TD-07.
Iteration 2 estimated total: ~128 lines across 6 files.

### Step 9: MEDIUM items (R28-TD-01..07, excluding R28-TD-05)

Per design part-03 iteration 2 sequence:

9.1 R28-TD-04 + R28-TD-07 (runner fixes):

- R28-TD-04: fix `leak_scan` property error at
  `stage24-chat-s02-s03-comparison.ps1` line ~1184 by using
  `Add-Member` to add the property to the leg summary bag.
- R28-TD-07: pass `--crash-dump-dir` from runner to
  llama-server.exe in the Start-Process ArgumentList.
- Bundle as one runner commit.

9.2 R28-TD-03 (TP-28-UT-02 SEH activation smoke test):

- Add Windows-only focused test that sets up a controlled
  SIGABRT and confirms a crash dump is written to the
  configured `--crash-dump-dir`.

9.3 R28-TD-02 (TP-28-UT-03 demote queue saturation):

- Add focused controller test for the 32/32 queue saturation
  observation (R26-OBS-01) using the new synchronous
  tx_demote_payload path.

9.4 R28-TD-06 (Stage 27 doc tense update):

- 3-line doc fix at `cache-handling-phase27-design/part-04-verification-plan.md`.

9.5 R28-TD-01 (Stage 24 stale closure-link text):

- 5-line link update at
  `cache-handling-phase24-implementation/part-16-manager-closure-20260625.md`.

Stop condition per item:

- Runner exit code 0 on Stage 24 dry-run (was non-zero with `leak_scan` error).
- TP-28-UT-02 and TP-28-UT-03 PASS.
- Doc links resolve.

Estimated diff: ~93 lines across 5 files.

### Step 10: R28-TD-05 worker thread deletion (conditional)

ONLY proceed if R28-BUG-04 Phase B deprecation markers (Step 6)
are compile-clean and the test migration (Step 7) is complete
with zero deprecation warnings.

Action: in `tools/server/server-cache-io-worker.{h,cpp}`:

1. Remove the worker thread internals: `worker_thread_`, `queue_cv_`, `work_queue_`, `queue_mutex_`, `result_mutex_`, `result_queue_`, `worker_thread_func()`, `start()`, `stop()`.
2. Remove the LLAMA_SERVER_CACHE_TESTS debug accessors: `debug_set_queue_capacity_for_tests`, `debug_set_completion_delay_for_tests`, `debug_set_cold_store_for_tests`, `debug_io_worker_for_tests`.
3. Remove `set_cold_store` neighbor and the `friend class hybrid_cache_controller;` declaration if it becomes unused.
4. Keep the `execute_inline`, `execute_demotion_inline`, `execute_promotion_inline` family.

Stop condition:

- `cmake --build build-cuda --config Release --target llama-server` exits 0.
- test-cache-controller.exe runs to completion (138 + 2 = 140 tests).
- Stage 24 dry-run exits 0.

Estimated diff: ~30 lines deletion across 2 files.

### Iteration 2 deliverables (binding)

- test-cache-controller.exe runs to completion (140 PASS, 0 abort).
- Stage 24 -08 rerun PASS (R28-TD-04 + R28-TD-07 runner fixes
  improve the durable report write).
- Stage 24 -08 report at
  `._design_docs/.test_reports/test-report-20260627-02.md`.

---

## Iteration 3: LOW severity (out-of-scope)

11 items: R28-TD-08..18. Not in this stage per design part-03.

---

## Regression sweep (Step 8 + Step 10 evidence)

After iter 1 (Step 8) and iter 2 (Step 10), run:

- Clean Release build (all 3 targets).
- test-cache-controller.exe full pack.
- Stage 24 -08 rerun.
- Durable reports at
  `._design_docs/.test_reports/test-report-20260627-01.md` (iter 1)
  and
  `._design_docs/.test_reports/test-report-20260627-02.md` (iter 2).

This file uses LF line endings, plain ASCII status labels, no
BOM, no trailing whitespace, and stays under the 300-line
durable-doc cap.

This file uses LF line endings, plain ASCII status labels, no
BOM, no trailing whitespace, and stays under the 300-line
durable-doc cap.
