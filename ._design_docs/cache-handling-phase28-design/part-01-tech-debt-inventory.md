# Stage 28 design part 01: Technical debt inventory across Stages 24-27

Status: design; Manager gate decision D28-DESIGN-01 2026-06-26
Date: 2026-06-26
Stage: 28 (Technical Debt Removal + Open Bug Fixes)
Owner: Architect (catalog); Developer (fix per part-03)

## Scope

Catalog every known technical debt item and open bug across Stages 24-27.
Each item gets: severity (HIGH/MEDIUM/LOW), category, location, fix
estimate, and binding disposition (in-scope / deferred / out-of-scope).

Severity rules:

- HIGH: user-impacting (correctness, crash, data loss, runtime invariant
  broken), or breaks an existing test in Release build, or blocks an
  existing evidence path.
- MEDIUM: maintainability hazard (stale doc references, missing
  regression tests, dead code paths), or breaks a non-Release evidence
  path.
- LOW: cosmetic (prose, comment style, redundant table rows), or
  process-only fix that does not affect behavior.

## Summary

| Severity | Count | In-scope | Deferred | Out-of-scope |
| --- | ---: | ---: | ---: | ---: |
| HIGH | 4 | 4 | 0 | 0 |
| MEDIUM | 7 | 5 | 2 | 0 |
| LOW | 11 | 0 | 0 | 11 |
| TOTAL | 22 | 9 | 2 | 11 |

Added 2026-06-26 per user direction: R28-BUG-04 (async worker code
retention after Stage 25 retirement). Inventory surfaced two live
production paths that still call the legacy async API and silently
hang because the worker thread is never started. See part-01 HIGH
section for the full inventory and recommended action.

## HIGH severity (4 items, all in-scope, all binding)

### R28-BUG-01: TP-26-UT6 test artifact (D-EXEC-27-09)

- Category: tests (test code).
- Location: `tests/test-cache-controller.cpp:3707`
  `assert(stage23_admit_checkpoint_store(ctrl, entry, checkpoints, false, &failure, true))`.
- Symptom: test exits with -1073740791 / 0xC0000409 from
  `__fastfail(FAST_FAIL_FATAL_APP_EXIT)` after explicit `std::abort()` at
  line 3767 (deferred path) or at the prior assert. Per Stage 27 closure
  diagnosis, root cause is the test file undefines NDEBUG at line 22 so
  asserts are active in this TU; the abort pattern is internally
  inconsistent with the test's prior 132-test pack.
- Fix estimate: ~30 lines. Replace `assert(condition); ... std::abort();`
  pattern in the new TP-26-UT6 test (and any other assertion that is
  expected to fire in Release build) with explicit
  `if (!(condition)) { fprintf(stderr, "FAIL: ..."); std::abort(); }`.
- Disposition: IN-SCOPE iteration 1 (HIGH).

### R28-BUG-02: S02 hybrid cold-store metric vs filesystem drift (D-EXEC-24-03-c)

- Category: metrics (cold-store accounting).
- Location: `tools/server/server-cache-hybrid.cpp` decrement/insert sites
  (lines 641, 711, 904-916, 986-995, 3328-3333) and orphan-file path
  investigation.
- Symptom: Stage 24 -07 S02 hybrid leg shows 5.37 GiB on disk (102 files
  at 50.25 MiB each) vs 502 MiB in `n_cold_payload_bytes` metric and
  `cold_payload_bytes_by_id_` map sum (10 entries).
- Root cause hypothesis (NEEDS FOCUSED DIAGNOSIS): orphan-file path.
  When `cold_store.remove()` returns false, `cold_budget_make_room`
  early-`continue`s without erasing the per-id entry, but the file
  remains. More likely: per-id map is populated only at
  `complete_demoted_payload` (line 705-712), and there are paths that
  write to disk without going through that lambda. Candidates:
  (a) `cold_store.delete_ids` in cleanup loop (line 982) does not write,
  only deletes, so not a write source; (b) the test-only
  `attach_payload_for_tests` direct hot insert may not sync to disk;
  (c) the `materialize_entry_payload` path may write via a different
  code path. Diagnosis step required before fix shape is final.
- Fix estimate: ~60 lines (diagnosis + fix + regression test).
- Disposition: IN-SCOPE iteration 1 (HIGH) with mandatory diagnosis step.

### R28-BUG-03: AddressSanitizer LNK2038 SAL annotation mismatch (D-EXEC-27-09 carry)

- Category: build (ASan infrastructure).
- Location: side-channel build `build-cuda-asan` CMakeLists.txt
  configuration that adds `/fsanitize=address` to llama-server target
  but not to the ggml-cuda static library target.
- Symptom: 274 LNK2038 errors: `ggml-cuda.lib(...).obj : error LNK2038:
  mismatch detected for 'annotate_vector': value '0' doesn't match
  value '1' in llama-server-impl.lib(server.obj)`. Also `LIBCMT`
  conflict warning.
- Root cause: MSVC `/fsanitize` adds SAL annotation metadata that is
  per-translation-unit; static libs built without the flag expose a
  different `annotate_vector` value than the executable that uses them.
- Fix estimate: ~10 lines CMake change OR build the executable with
  `--whole-archive` for ggml-cuda OR rebuild ggml-cuda with same
  `/fsanitize` flags. Investigate which is cleanest.
- Disposition: IN-SCOPE iteration 1 (HIGH).

### R28-BUG-04: Async worker code retention after Stage 25 retirement

- Category: code (async-worker API drift from Stage 25 design intent).
- Location:
  `tools/server/server-cache-io-worker.{h,cpp}`,
  `tools/server/server-cache-hybrid.{h,cpp}:337/571/678`,
  `tools/server/server-cache-hybrid.cpp:1875-1899` (stage23 wait loop),
  `tools/server/server-cache-hybrid.cpp:4929` (`load_slot` cold payload).
- Symptom (two production paths still broken):
  1. `load_slot` line 4929 calls `promote_payload(selected_payload_id)`
     (legacy async API) when a restore target's payload is cold. The
     method enqueues to `io_worker.work_queue_`, but the worker thread
     is never started (per D25-DESIGN-01 Option B), so the task sits in
     the queue forever. The descriptor stays in
     `payload_residency_state::promoting` indefinitely and the cache
     leaks a 50 MiB hot slot reservation per affected payload. On
     subsequent restores the descriptor is read as `promoting` and the
     request is rejected with
     `cache_restore_miss_reason::payload_unavailable` until the cold
     payload is evicted. The leak persists until process exit.
  2. `stage23_admit_checkpoint_store` line 1875-1899 calls
     `self->promote_payload(payload_id)` then loops 6000 times calling
     `self->process_completions()` with a 5 ms sleep, expecting the
     worker to complete the promotion and flip residency to `hot`.
     Because the worker thread is never started, `process_completions()`
     is a no-op stub (drains an empty result queue). The loop burns up
     to 30 seconds per cold-checkpoint restore, then returns false with
     `failure_reason = "checkpoint promotion incomplete"`. Restore fails
     after a 30 s hang.

- Inventory (added 2026-06-26 per user direction):

  | Component | Status | Callers (prod vs test) | Disposition |
  | --- | --- | --- | --- |
  | `server_cache_io_worker` class | mixed | always instantiated; thread never started in prod; 41+ test refs | keep header; delete thread internals (R28-TD-05 iter 2) |
  | `io_worker.start()` | test-only | 12 test refs via `debug_start_io_worker_for_tests` | delete with worker thread (R28-TD-05 iter 2) |
  | `io_worker.stop()` | test-only | 12 test refs via `debug_stop_io_worker_for_tests` | delete with worker thread (R28-TD-05 iter 2) |
  | `io_worker.worker_thread_func()` | dead in prod | only invoked from `start()` (above) | delete with worker thread (R28-TD-05 iter 2) |
  | `enqueue_demotion` | dead in prod | 1 prod caller (`demote_payload` which has no prod callers); TEST-only via `debug_demote_first_checkpoint_for_tests` | mark `[[deprecated]]` iter 1; delete iter 2 |
  | `enqueue_promotion` | dead in prod | 3 callers: 1 prod (`stage23` line 1875), 1 prod (`load_slot` line 4929), 1 TEST (`debug_request_stage9_checkpoint_promotion_for_tests`); the 2 prod callers are broken (hang) | mark `[[deprecated]]` iter 1; delete iter 2 |
  | `process_completions` | no-op stub | 1 prod caller (stage23 wait loop, line 1882); TEST-only via `debug_stop_io_worker_for_tests` | remove call site iter 1; delete method iter 2 |
  | `drain_results` | no-op stub | 1 prod caller (`process_completions`); tests call it indirectly | delete with `process_completions` (iter 2) |
  | `handle_demotion_completion` | ACTIVE | 1 prod caller (`tx_demote_payload` line 4619) | keep |
  | `execute_inline`, `execute_demotion_inline`, `execute_promotion_inline` | ACTIVE | 2 prod callers (`tx_demote_payload`, `tx_promote_payload`); test-only | keep |
  | `worker_thread_`, `queue_cv_`, `work_queue_`, `result_queue_`, `queue_mutex_`, `result_mutex_` | dead in prod | only accessed from worker thread | delete with worker thread (iter 2) |
  | `debug_start_io_worker_for_tests`, `debug_stop_io_worker_for_tests`, `debug_io_worker_for_tests`, `debug_set_io_worker_queue_capacity_for_tests` | TEST-only | 41 test refs | migrate tests to `execute_inline` helpers (iter 2) |

- Recommended action (phased):
  1. Phase A (this item, iter 1): Replace the 2 broken prod callers
     with the existing inline `tx_*` helpers.
     - `load_slot` line 4929: replace `promote_payload(...)` with
       `tx_promote_payload(...)`. The `tx_` variant runs the cold
       read inline under the cache-state mutex and updates residency
       before returning, so the caller can detect success synchronously
       and avoid the leak. The caller still returns false from
       `load_slot` because it cannot wait for I/O without blocking, but
       the descriptor will be `hot` on the next restore instead of
       stuck in `promoting`.
     - `stage23_admit_checkpoint_store` line 1875-1899: replace
       `self->promote_payload(...)` + 6000-iteration wait loop +
       5 ms sleeps with a single `self->tx_promote_payload(...)` call.
       The cold read completes synchronously. The 30 s hang path
       disappears.
  2. Phase B (this item, iter 1): Mark `enqueue_demotion`,
     `enqueue_promotion`, `process_completions`, `drain_results`,
     `start`, `stop`, and the `debug_*_io_worker_for_tests` accessors
     with `[[deprecated("async worker retired in Stage 25; use tx_* / execute_inline")]]`
     and route the test pack through `execute_inline` / `execute_*_inline`
     helpers. This surfaces every remaining async caller as a compile
     error and lets Developer mechanically migrate the 41+ test refs.
  3. Phase C (R28-TD-05, iter 2): After the test pack is migrated and
     all builds are clean, delete the deprecated methods, the worker
     thread, the queue/result mutexes, and the `LLAMA_SERVER_CACHE_TESTS`
     debug accessors. Keep the `execute_inline` family.

- Fix estimate: ~150 lines (Phase A ~30 lines; Phase B ~10 lines deprecation
  markers; Phase C test migration ~80 lines; deletion of async path ~30 lines).
- Disposition: IN-SCOPE iteration 1 (HIGH, Phase A + B); follow-on
  deletion is R28-TD-05 in iteration 2.

## MEDIUM severity (7 items)

### R28-TD-01: Stale closure-link text in Stage 24 implementation log

- Category: docs (durable).
- Location: `cache-handling-phase24-implementation/part-16-manager-closure-20260625.md`
  refers to "S02 hybrid cold-store drift observation persists from -05"
  without linking to the new Stage 28 row. Stale after D-CLOSURE-27-01.
- Fix estimate: ~5 lines (link update).
- Disposition: IN-SCOPE iteration 2.

### R28-TD-02: Missing regression test for R26-OBS-01 demote queue saturation

- Category: tests.
- Location: `tests/test-cache-controller.cpp` has no regression test for
  demote queue saturation (32/32) observed in Stage 26 -01 hybrid logs.
- Fix estimate: ~40 lines (focused controller test).
- Disposition: IN-SCOPE iteration 2.

### R28-TD-03: Missing regression test for D-EXEC-26-01 SEH activation smoke

- Category: tests.
- Location: `tests/` has no automated test for the SEH handler; the
  Stage 26 -01 evidence used a manual smoke trigger.
- Fix estimate: ~30 lines (focused SEH-handler test on Windows-only).
- Disposition: IN-SCOPE iteration 2.

### R28-TD-04: Stage 24 runner `leak_scan` property error

- Category: runner (PowerShell).
- Location:
  `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`
  raises `InvalidOperation` exception "The property 'leak_scan' cannot
  be found on this object" at line 1184 (final-leak-scan aggregation).
- Symptom: script exits non-zero AFTER all four legs complete; per-leg
  `summary.json` files are written correctly but the durable report at
  the configured path is not.
- Fix estimate: ~3 lines (use Add-Member or property bag).
- Disposition: IN-SCOPE iteration 2.

### R28-TD-05: Worker thread infrastructure deletion after R28-BUG-04 Phase B

- Category: code (post-deprecation cleanup).
- Location: `tools/server/server-cache-io-worker.{h,cpp}` worker thread,
  `tools/server/server-cache-hybrid.h` test accessors
  (`debug_start_io_worker_for_tests`, `debug_stop_io_worker_for_tests`,
  `debug_io_worker_for_tests`, `debug_set_io_worker_queue_capacity_for_tests`).
- Symptom: After R28-BUG-04 Phase B migrates all callers, the worker
  thread (worker_thread_, queue_cv_, work_queue_, result_queue_,
  queue_mutex_, result_mutex_), start(), stop(), and the
  LLAMA_SERVER_CACHE_TESTS-gated debug accessors become unused. Stage
  25 design intent (D25-DESIGN-01 Option B) was "replace with
  stateless helper"; the worker is now vestigial.
- Fix estimate: ~30 lines (delete worker internals, queue/result
  fields, LLAMA_SERVER_CACHE_TESTS debug accessors; remove `start` and
  `stop` from `set_cold_store` neighbor; remove the
  `LLAMA_SERVER_CACHE_TESTS`-gated debug queue/delay fields from
  io_worker).
- Disposition: IN-SCOPE iteration 2 (MEDIUM), conditional on
  R28-BUG-04 Phase B compile-clean. Original Stage 28 design deferred
  this to Stage 29; promotion to iteration 2 is contingent on the
  async deprecation markers (Phase B) landing first so deletion is
  safe.

### R28-TD-06: Stale doc reference in Stage 27 design part-04

- Category: docs.
- Location:
  `cache-handling-phase27-design/part-04-verification-plan.md` still
  references "ASan-not-available constraint" in present tense after
  Stage 27 used a side-channel `build-cuda-asan` to do CPU-only ASan.
- Fix estimate: ~3 lines (tense update + cross-link).
- Disposition: IN-SCOPE iteration 2.

### R28-TD-07: `--crash-dump-dir` not passed by runner

- Category: runner.
- Location:
  `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`
  lines 933-934 (or current equivalent) do not pass `--crash-dump-dir`
  to llama-server.exe, per D-EXEC-26-01 follow-up. Stage 26 -03 added
  the flag manually.
- Fix estimate: ~2 lines (runner flag pass-through).
- Disposition: IN-SCOPE iteration 2 (combines with R28-TD-04 runner work).

## LOW severity (11 items, all out-of-scope)

| ID | Category | Location | Note |
| --- | --- | --- | --- |
| R28-TD-08 | docs prose | `cache-handling-phase27-implementation/part-10-manager-closure-20260626.md` | "11 test rows" prose typo (actual 12 rows) |
| R28-TD-09 | docs prose | `cache-handling-phase26-implementation/part-08-manager-closure-20260626.md` | "11 test rows" same typo |
| R28-TD-10 | code comments | `tools/server/server-cache-hybrid.cpp` ~line 3390 | "fix root cause (Stage 27)" comment could be terser |
| R28-TD-11 | docs table | `cache-handling-stage-tracker.md` Stage 26 row Notes column | "11 test rows" same typo |
| R28-TD-12 | code style | `tools/server/server-cache-hybrid.cpp` | redundant `SRV_DBG` lines in debug path |
| R28-TD-13 | docs alignment | `document-index.md` | "Stage 24..27" rows could use shorter cells |
| R28-TD-14 | metric names | `tests/test-cache-controller.cpp` | test references to `n_demotion_successes` could use constants |
| R28-TD-15 | runner | `stage24-chat-s02-s03-comparison.ps1` | verbose error logging on failed health check |
| R28-TD-16 | runner | `stage24-chat-s02-s03-comparison.ps1` | per-leg `summary.json` written twice (initial + final) |
| R28-TD-17 | docs | `cache-handling-architecture.md` part-09 | cross-link to Stage 27 could be shorter |
| R28-TD-18 | runner | `stage24-chat-s02-s03-comparison.ps1` | duplicated port-free check before launch |

## Disposition summary

- Iteration 1 (HIGH only, user-impacting): R28-BUG-01, R28-BUG-02,
  R28-BUG-03, R28-BUG-04 (Phase A fix broken prod callers; Phase B
  deprecate async API).
- Iteration 2 (MEDIUM, maintainability): R28-TD-01, R28-TD-02,
  R28-TD-03, R28-TD-04, R28-TD-05 (worker thread deletion, conditional
  on R28-BUG-04 Phase B), R28-TD-06, R28-TD-07.
- Iteration 3 (LOW, cosmetic): out-of-scope unless combined with HIGH or
  MEDIUM commit.
- Deferred to future stage: none for this stage.

See [part-03](./cache-handling-phase28-design/part-03-prioritized-fix-order.md)
for the iteration sequencing.

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace, and stays under the 300-line durable-doc cap.
