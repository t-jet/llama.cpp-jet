# Part 9: Manager closure 2026-06-27

Status: closed; Manager gate decision D-CLOSURE-28-01 2026-06-27
Date: 2026-06-27
Stage: 28 (Technical Debt Removal + Open Bug Fixes)
Owner: Manager (closure) and Architect (closure sweep)
Scope: closure record for Stage 28 implementation; Stage 28 is closed
with documented carry-over for R28-BUG-04 Phase C.

## Summary

Stage 28 executed via per-step cycle (per user direction 2026-06-26):
- Step 1 R28-BUG-02 (cold-store drift): PASS
- Step 2 R28-BUG-01 (TP-26-UT6 test artifact): PARTIAL (acceptable)
- Step 3 R28-BUG-03 (ASan LNK2038): PASS
- Step 4 R28-BUG-04 Phase B (deprecation): PASS

All 4 sub-steps have independent verification on disk via Select-String
line refs and binary mtime checks. No subagent fabrication in any
verified step (per memory rule "catch subagent fabrication").

## Per-step final classification

| Sub-step | Status | Files modified | Evidence |
| --- | --- | --- | --- |
| Step 1 R28-BUG-02 cold-store drift | PASS | server-cache-hybrid.{h,cpp} + server-cache-store-cold.h + test | test-report-20260627-cold-store-fix.md |
| Step 2 R28-BUG-01 TP-26-UT6 test artifact | PARTIAL | test-cache-controller.cpp (3/4 sites; line 4253 documented exception) | test-report-20260627-stage28-step2-verify.md |
| Step 3 R28-BUG-03 ASan LNK2038 | PASS | build-cuda-asan/CMakeCache.txt | test-report-20260627-asan-lnk2038-fix.md |
| Step 4 R28-BUG-04 Phase B deprecation | PASS | server-cache-io-worker.h + server-cache-hybrid.h | test-report-20260627-async-deprecation.md |

Final test count: **140/140 PASS** on production build (build-cuda)
and ASan+CUDA build (build-cuda-asan).

## Manager decisions (verbatim)

**D-CLOSURE-28-01**: close Stage 28. Code UNCOMMITTED per AGENTS.md;
user approval required for commit. Follow-up open:
- (a) R28-BUG-04 Phase C deletion DEFERRED (impractical without test
  refactor; 46 tests reference debug helpers in tools/server/server-cache-io-worker.h:
  debug_start_io_worker_for_tests, debug_stop_io_worker_for_tests,
  debug_set_completion_delay_for_tests, debug_set_queue_capacity_for_tests).
  Test refactor required before Phase C: migrate tests to either drop async
  timing dependency (use synchronous tx_* equivalents) or accept the
  remaining async scaffolding as test infrastructure.

## Code change summary (UNCOMMITTED per AGENTS.md)

Production code (D-EXEC-28-STEP1 + D-EXEC-28-STEP4):
- tools/server/server-cache-hybrid.cpp +76 (reconcile method + caller)
- tools/server/server-cache-hybrid.h +7 (method decl + counter)
- tools/server/server-cache-store-cold.h +5 (root_path accessor)
- tools/server/server-cache-io-worker.h +2 (2 deprecation markers)
- tools/server/server-context.cpp +1 (Prometheus counter)

Test code:
- tests/test-cache-controller.cpp +308 (TP-28-UT-01 + 3 abort sites
  converted + invariant assertions)

Build config (not in source tree):
- build-cuda-asan/CMakeCache.txt (CACHE_CUDA_FLAGS with ASan)

## Follow-up tasks (open as future stage)

1. (deferred) R28-BUG-04 Phase C: async worker body deletion requires
   test refactor (46 tests reference debug helpers). Future stage.
2. (carried from Stage 27) R28-TD-01..R28-TD-04, R28-TD-06..R28-TD-18
   (MEDIUM/LOW tech debt items from design part-01). 5 MEDIUM in-scope
   items + 11 LOW items remain for future stage.

## Handoff

Next owner: user. Stage 28 closed. Code changes in tools/server/ and
tests/test-cache-controller.cpp UNCOMMITTED per AGENTS.md; user owns
commit decision.
