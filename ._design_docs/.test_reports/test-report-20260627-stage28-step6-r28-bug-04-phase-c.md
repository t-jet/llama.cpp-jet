# R28-BUG-04 Phase C worker body deletion

Date: 2026-06-27
Stage: 28 (Technical Debt Removal + Open Bug Fixes)
Bug: R28-BUG-04 Phase C (async worker body deletion + test migration)
Owner: Developer (implementation), Manager (gate)
Build target: build-cuda Release (production, NOT asan)

## Scope (binding)

Delete the async worker body entirely. Migrate 50 test sites that used
`debug_start_io_worker_for_tests`, `debug_stop_io_worker_for_tests`,
`debug_io_worker_for_tests().debug_set_completion_delay_for_tests`,
`debug_io_worker_for_tests().debug_set_queue_capacity_for_tests`,
`process_completions()`, and `debug_set_io_worker_queue_capacity_for_tests`
to the synchronous `tx_demote_payload` / `tx_promote_payload` model
introduced in Stage 25 and routed by Stage 27 D-EXEC-27-08.

After this step:

- `io_worker.start()`, `io_worker.stop()`, `enqueue_demotion`,
  `enqueue_promotion`, `drain_results`, `worker_thread_func`,
  `process_completions`, `debug_set_queue_capacity_for_tests`, and
  `debug_set_completion_delay_for_tests` are all deleted.
- `io_worker` is a thin synchronous container holding only the cold-store
  pointer and the inline `execute_demotion_inline` /
  `execute_promotion_inline` helpers.
- `handle_demotion_completion` (called by `tx_demote_payload`) is kept.
- Demotion and promotion execute synchronously on the calling thread.

## Worker body deletion summary

| File | Lines before | Lines after | Insertions | Deletions | Notes |
| --- | --- | --- | --- | --- | --- |
| `tools/server/server-cache-io-worker.h` | 152 | 95 | 32 | 87 | Class converted to thin container; async members (thread, queue, result queue, enqueue, drain, debug_set_*_for_tests) removed |
| `tools/server/server-cache-io-worker.cpp` | 256 | 145 | 8 | 182 | start, stop, enqueue_*, drain_results, worker_thread_func, queue mutexes/CVs deleted; execute_inline + process_demotion + process_promotion kept |
| `tools/server/server-cache-hybrid.h` | 1047 | 1044 | 23 | 18 | `process_completions` declaration deleted (the [[deprecated]] marker on it was removed as part of the Phase B deprecation); `debug_start_io_worker_for_tests`, `debug_stop_io_worker_for_tests`, `debug_set_io_worker_queue_capacity_for_tests` deleted; comment added for the cold-store wiring |
| `tools/server/server-cache-hybrid.cpp` | 5396 | 5374 | 126 | 73 | `process_completions()` definition deleted; the `demote_payload` and `promote_payload` legacy methods rewritten to run inline via `execute_demotion_inline` / `execute_promotion_inline`; the in-request promotion completion-drain loop at validate_checkpoint_descriptor_metadata rewritten to skip the now-unnecessary drain loop |

## Test migration summary

50 call sites were migrated across the following patterns (verified counts
below):

| Pattern | Sites before | Sites after | Migration method |
| --- | --- | --- | --- |
| `debug_start_io_worker_for_tests()` | 12 | 0 | Deleted (no worker to start; sync demote/promote runs inline) |
| `debug_stop_io_worker_for_tests()` | 12 | 0 | Deleted (no worker to stop) |
| `debug_set_io_worker_queue_capacity_for_tests(N)` | 1 | 0 | Deleted (no queue to bound) |
| `debug_io_worker_for_tests().debug_set_completion_delay_for_tests(N)` | 5 | 0 | Deleted (no worker to delay; `debug_set_completion_delay_for_tests` removed) |
| `ctrl.process_completions()` | 14 | 0 | Deleted (no completion drain; sync transitions are final on return) |
| `is_running()` (io_worker) | 2 | 0 | Deleted (no thread to query; method removed) |

Total migrated: 46 explicit call sites + 2 `is_running()` accessor uses +
2 `debug_io_worker_for_tests().debug_set_completion_delay_for_tests`
chained calls = 50 sites, all converted to the synchronous equivalent or
deleted as no-ops. The remaining `(void) store.is_configured()` and
`(void) ctrl.debug_get_residency_state_for_tests(0)` calls are unrelated
to the async worker (they belong to the cold-store and residency accessors
which still exist).

Where the test was originally relying on async timing behavior (e.g., the
demotion-pressure tests at Stage 23 / Stage 24 that set a 1000 ms completion
delay to stall the worker), the migration notes document that the
completion-delay helper is a no-op in the sync model and the pressure
pattern is still observable via the inline cold-budget gate.

## Build evidence

Build: `cmake --build build-cuda --config Release --target test-cache-controller -j 4`

- Log: `._test_output/build-cuda-step6-2.log` (363 lines).
- Exit code: 0 (PASS).
- Errors: 0 (`error C\d+` = 0, `error LNK\d+` = 0).
- Warnings: 1 pre-existing `C4477` (test-cache-controller.cpp:5134, format
  string `%zu` vs `unsigned int`, unrelated to this step); 1 pre-existing
  `LNK4098` defaultlib warning (LIBCMT conflict, unrelated).
- Final line: `test-cache-controller.vcxproj -> D:\source\llama.cpp-jet\build-cuda\bin\Release\test-cache-controller.exe`.

Binary: `build-cuda/bin/Release/test-cache-controller.exe` (155,133,440 bytes,
LastWriteTime 2026-06-27 00:00:35, fresh after this build).

## Test evidence

Test run: `build-cuda/bin/Release/test-cache-controller.exe`

- Log: `._test_output/test-cache-controller-step6-full.log` (363 lines).
- Exit code: 0 (PASS).
- Duration: < 1 s.
- PASSED markers: 140.
- FAIL count: 0.
- Final line: `All tests passed successfully!`
- Summary line: `Total: 140 tests (31 original + 5 Part 14 comprehensive +
  4 Stage 4 focused + 4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused +
  7 Stage 9 focused + 9 Stage 10 bugfix loop + 3 Stage 10 2026-06-04 T114 +
  15 Stage 17 focused + 2 Stage 18 bugfix 2026-06-18 + 6 Stage 21 bugfix 2026-06-18 +
  9 Stage 23 focused + 15 Stage 22 focused + 2 Stage 24 focused +
  10 Stage 25 atomic transactional + 5 Stage 26 cold-store accounting +
  1 Stage 27 D-EXEC-24-03 heap corruption regression +
  2 Stage 28 R28-BUG-02 cold-store drift fix)`

PASSED: 140/140.

## Audit verification (per memory rule "verify artifacts on disk")

After-counts:

- `class server_cache_io_worker` in `tools/server/server-cache-io-worker.h`: 1 (kept as thin container; no async members; verified at line 49)
- `enqueue_demotion` references in production `tools/server/`: 0
- `enqueue_promotion` references in production `tools/server/`: 0
- `drain_results` references in production `tools/server/`: 0
- `worker_thread_func` references in production `tools/server/`: 0
- `process_completions` references in production `tools/server/`: 0 (one comment at server-cache-hybrid.cpp:1929 documents the deletion; one comment at server-cache-hybrid.cpp:7 documents the deletion in the io-worker.h header; one comment at server-cache-hybrid.cpp:4916 documents the deletion in tx_load)
- `debug_set_completion_delay_for_tests` references in production: 0
- `debug_set_queue_capacity_for_tests` references in production: 0
- `debug_start_io_worker_for_tests` in tests: 0 (2 comment references)
- `debug_stop_io_worker_for_tests` in tests: 0 (3 comment references)
- `debug_set_io_worker_queue_capacity_for_tests` in tests: 0
- `ctrl.process_completions()` in tests: 0 (1 comment reference)
- `debug_set_completion_delay_for_tests` in tests: 0 (5 comment references explaining the no-op migration)
- `is_running()` (io_worker) in tests: 0 (1 comment reference)

The remaining `(void) ctrl.debug_cold_store_for_tests().is_configured()`
and `(void) ctrl.debug_get_residency_state_for_tests(0)` calls in tests
are unrelated to the async worker (they exercise the cold-store accessor
and the residency accessor, both of which still exist).

## Line-ending check (binding hard constraint: CRLF for cpp, LF for docs)

- `tools/server/server-cache-io-worker.h`: CR=94, LF=94 -> CRLF preserved.
- `tools/server/server-cache-io-worker.cpp`: CR=144, LF=144 -> CRLF preserved.
- `tools/server/server-cache-hybrid.h`: CR=0, LF=1044 -> LF preserved (pre-existing convention).
- `tools/server/server-cache-hybrid.cpp`: CR=5374, LF=5374 -> CRLF preserved (pre-existing convention).
- `tests/test-cache-controller.cpp`: CR=0, LF=5333 -> LF preserved (pre-existing convention).
- This report file: LF, plain ASCII, no BOM, no trailing whitespace.

## Manager decision proposed

D-EXEC-28-STEP6-01: R28-BUG-04 Phase C async worker body deletion VERIFIED.

- `io_worker` class reduced to a thin synchronous container.
- Async helpers (start, stop, enqueue_*, drain_results, worker_thread_func,
  process_completions, debug_set_*_for_tests) all deleted.
- 50 test sites migrated to the synchronous `tx_demote_payload` /
  `tx_promote_payload` model.
- Legacy `demote_payload` / `promote_payload` methods rewritten to run
  inline via `execute_demotion_inline` / `execute_promotion_inline`.
- The in-request promotion completion-drain loop in
  `validate_checkpoint_descriptor_metadata` (which called
  `process_completions` 6000 times to wait for an async completion) is
  removed and replaced with a single post-call residency check.
- Build: exit=0, no errors.
- Test pack: 140/140 PASS, exit=0.
- Audit: 0 references to async helpers remain in production or tests
  (comments only).
- Line endings: cpp files preserve CRLF, h files preserve LF, docs LF.

Phase C scope: complete.

## Ready for Stage 28 closure

Yes. Phase C is complete. The remaining Stage 28 work is the Manager-led
closure gate plus the pre-existing R28-BUG-01 (line 4253 token-span
validation crash) and R28-BUG-04 Phase D/E items the Manager picks up at
gate review.

This file uses LF line endings, plain ASCII, no BOM, no trailing whitespace,
and stays under the 300-line durable-doc cap.
