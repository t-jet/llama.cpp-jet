# Stage 28 design part 03: Prioritized fix order

Status: design; Manager gate decision D28-DESIGN-01 2026-06-26
Date: 2026-06-26
Stage: 28 (Technical Debt Removal + Open Bug Fixes)
Owner: Architect (sequencing); Developer (execution per iteration)

## Scope

Iteration plan for the Stage 28 fix scope. Iteration 1 contains HIGH
items (user-impacting). Iteration 2 contains MEDIUM items
(maintainability). Iteration 3 contains LOW items (cosmetic) but those
are out-of-scope unless bundled with a HIGH or MEDIUM commit.

Each iteration has:

- One clean build at start (preserves the previous iteration's binary
  on disk for evidence continuity).
- One focused test pass (existing tests must still pass).
- One Stage 24 rerun if any production code changed.

---

## Iteration 1: HIGH severity (user-impacting) — binding

Four items: R28-BUG-01, R28-BUG-02, R28-BUG-03, R28-BUG-04.

### Order within iteration 1

Recommended sequence:

1. **R28-BUG-03 first (ASan LNK2038)** — build infrastructure fix.
   Smallest diff (~10 lines CMake). No test changes. Unblocks future
   ASan reruns, which the next fix (TP-26-UT6) will benefit from.
2. **R28-BUG-01 second (TP-26-UT6)** — test code only. Replaces mixed
   `assert` / explicit-abort pattern with uniform abort-on-fail. Adds
   deterministic Release-build test execution. No production code
   change. The fix can be verified on the existing build-cuda binary
   with no new build.
3. **R28-BUG-04 third (async worker Phase A + B)** — production code
   fix. Phase A replaces 2 broken production callers (`load_slot` line
   4929 and `stage23_admit_checkpoint_store` line 1875-1899) with
   `tx_promote_payload`. Phase B adds `[[deprecated]]` markers to the
   async API surface (start, stop, enqueue_demotion, enqueue_promotion,
   process_completions, drain_results, debug_*_io_worker_for_tests) so
   compile errors surface every remaining async caller. Developer
   migrates the 41+ test refs in the same commit so the tree stays
   build-clean. Order: Phase A first, then Phase B in the same commit.
4. **R28-BUG-02 fourth (cold-store drift)** — most complex. Requires a
   diagnosis step (one-shot diagnostic logging) to identify the orphan-
   file path, then a focused fix. The new TP-28-UT-01 unit test
   reproduces the orphan path deterministically.

### Iteration 1 deliverables

- Clean Release build of `build-cuda/bin/Release/llama-server.exe`.
- Clean Release build of `build-cuda/bin/Release/test-cache-controller.exe`.
- Clean Release build of `build-cuda-asan/bin/Release/llama-server.exe`
  (no LNK2038 errors).
- 138/138 unit tests pass (was 110 PASS + abort; post-fix 138 PASS).
  Test pack retains the 41+ async test refs after migration to
  `execute_inline` / `execute_*_inline` helpers; total count
  unchanged.
- New TP-28-UT-01 unit test reproducing the orphan-file path passes.
- Stage 24 -07 rerun: S02 hybrid filesystem <= 512 MiB budget
  (was 5.37 GiB). All other rows unchanged.
- Stage 24 -07 rerun: cold-checkpoint restore (S03) returns in
  < 100 ms instead of 30 s hang (was R28-BUG-04 Phase A).
- Stage 24 -07 rerun: cold-payload restore (S02 hybrid) does not leak
  descriptors in `promoting` state (was R28-BUG-04 Phase A).

### Iteration 1 estimated diff

- `tools/server/server-cache-hybrid.cpp`: ~60 lines (R28-BUG-02
  diagnosis + fix ~30; R28-BUG-04 Phase A prod caller fixes ~30).
- `tools/server/server-cache-io-worker.{h,cpp}`: ~10 lines (R28-BUG-04
  Phase B deprecation markers).
- `tests/test-cache-controller.cpp`: ~130 lines (TP-26-UT6 abort
  pattern replacement ~50 + new TP-28-UT-01 test ~50 + 41+ async
  test refs migrated to `execute_inline` ~30 net).
- `tools/server/CMakeLists.txt` or side-channel `build-cuda-asan`
  CMakeLists: ~10 lines.
- **Total: ~210 lines** across 4 files.

### Iteration 1 risk profile

See [part-05](./cache-handling-phase28-design/part-05-risks.md).
Highest risk is R28-BUG-02 because the diagnosis step may reveal the
root cause is more involved than the three candidates listed. Second
highest is R28-BUG-04 Phase B because the 41+ test ref migration may
surface unexpected dependencies on the worker thread (delay injection,
queue capacity, running state). If diagnosis shows Candidate A is
wrong (which is likely given the drift direction), the fix scope
grows. The iteration 1 plan accounts for this by sequencing
R28-BUG-02 last so earlier fixes can stabilize the build, and by
placing R28-BUG-04 third so its test migration is done before the
cold-store drift rerun.

---

## Iteration 2: MEDIUM severity (maintainability) — binding

Seven items: R28-TD-01, R28-TD-02, R28-TD-03, R28-TD-04, R28-TD-05,
R28-TD-06, R28-TD-07.

R28-TD-05 is added per user direction 2026-06-26 (async worker
infrastructure deletion). It is conditional on R28-BUG-04 Phase B
landing in iteration 1; if iter 1 deprecation markers do not compile
clean or if any test ref was missed, R28-TD-05 slips to iter 3.

### Order within iteration 2

Recommended sequence:

1. **R28-TD-04 + R28-TD-07 (runner fixes)**: the runner `leak_scan`
   property error and missing `--crash-dump-dir` flag are the smallest
   fixes and unblock future QA reruns. Bundle as one runner commit.
2. **R28-TD-03 (SEH activation smoke test)**: small focused test that
   requires Windows-only build. No production code change.
3. **R28-TD-02 (R26-OBS-01 regression test)**: focused controller test
   for demote queue saturation. No production code change.
4. **R28-TD-05 (worker thread deletion)**: delete the worker thread
   internals, queue/result fields, `start`/`stop`, and the
   `LLAMA_SERVER_CACHE_TESTS` debug accessors. Depends on iter 1
   Phase B deprecation compile-clean. No production code change to
   the tx_* or execute_inline paths.
5. **R28-TD-06 (Stage 27 doc tense update)**: 3-line doc fix.
6. **R28-TD-01 (Stage 24 stale closure-link text)**: 5-line doc fix.

### Iteration 2 deliverables

- Clean Release build of `build-cuda/bin/Release/llama-server.exe` (no
  changes to production code other than worker thread deletion).
- 138 + 2 unit tests pass (was 138; adds TP-28-UT-02 SEH smoke,
  TP-28-UT-03 demote queue saturation). Test count unchanged after
  R28-TD-05 deletion (the 41+ async test refs migrated in iter 1
  Phase B stay at the same count).
- Runner exit code 0 on Stage 24 dry-run (was non-zero with
  `leak_scan` property error).
- Stage 24 rerun writes the durable report at the configured path
  (was BLOCKED-runner-cleanup in -07).

### Iteration 2 estimated diff

- `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`:
  ~10 lines (R28-TD-04 + R28-TD-07).
- `tests/test-cache-controller.cpp`: ~70 lines (TP-28-UT-02 + TP-28-UT-03).
- `tools/server/server-cache-io-worker.{h,cpp}`: ~30 lines (R28-TD-05
  deletion of worker internals and debug accessors).
- `tools/server/server-cache-hybrid.h`: ~10 lines (remove the 4
  `debug_*_io_worker_for_tests` accessors and their forward decls).
- `._design_docs/cache-handling-phase24-implementation/part-16-manager-closure-20260625.md`:
  ~5 lines.
- `._design_docs/cache-handling-phase27-design/part-04-verification-plan.md`:
  ~3 lines.
- **Total: ~128 lines** across 6 files.

---

## Iteration 3: LOW severity (cosmetic) — out-of-scope

11 items: R28-TD-08 through R28-TD-18. Out-of-scope unless combined
with a HIGH or MEDIUM commit. Documented in part-01 for future
reference. None are user-impacting.

---

## Deferred items

None for this stage. R28-TD-05 was originally deferred to Stage 29
under the old Stage 28 design; promotion to iteration 2 here is
conditional on iter 1 R28-BUG-04 Phase B compile-clean.

---

## Sequencing rationale

Iteration 1 is binding. Iteration 2 is binding. Iteration 3 is
out-of-scope for this stage. Each iteration produces a clean binary,
a clean test report, and an updated tracker row. Manager gates are
between iterations (D-ITER-01..03 PASS), not after each fix.

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace, and stays under the 300-line durable-doc cap.
