# Part 175: D39-QA-07 Step 7 promotion test fix

Date: 2026-07-17
Status: PASS
Scope: `test-step7-promotion-protocol` stale async API port

## Trigger

D39-QA-07 failed during the clean Release seam-ON build because
`tests/test-step7-promotion-protocol.cpp` still used retired async
`hybrid_cache_controller` APIs. Developer review classified the failure as
stale test automation, not a product API defect. The current controller runs
demotion and promotion synchronously through the transaction path and has no
worker queue or completion drain.

Fix report:
`../.test_reports/test-report-20260717-07-fixes.md`

## Changes

Code changed:

- `tests/test-step7-promotion-protocol.cpp`

Behavior changed:

- removed `debug_start_io_worker_for_tests`,
  `debug_stop_io_worker_for_tests`,
  `debug_set_io_worker_queue_capacity_for_tests`, `process_completions`, and
  async wait calls from the Step 7 promotion protocol test;
- changed successful promotion checks to assert final inline hot residency;
- changed cold-file deletion, truncated target/draft, and checksum mismatch
  cases to assert `promote_payload` returns `false` and leaves the descriptor
  evicted;
- kept promotion validation, success, failure, target/draft, retention,
  multiple-promotion, nonexistent-descriptor, and already-promoting checks;
- retired async queue-full coverage with a local rationale because the worker
  queue was removed by the synchronous transaction model;
- replaced the obsolete completion-drain inspection with a live inline
  promotion-dispatch regression.

No product files changed.

## Evidence

Fresh clean seam-ON Release configure:

```powershell
cmake -S . -B build-stage39-step7-fix-20260717-01 -DCMAKE_BUILD_TYPE=Release -DLLAMA_STAGE39_LIVE_TEST_SEAM=ON -DLLAMA_BUILD_TESTS=ON -DGGML_CUDA=OFF
```

Result: PASS, exit `0`.

Focused build target:

```powershell
cmake --build build-stage39-step7-fix-20260717-01 --config Release --target test-step7-promotion-protocol -j 4
```

Result: PASS, exit `0`.

Repaired executable:

```powershell
.\build-stage39-step7-fix-20260717-01\bin\Release\test-step7-promotion-protocol.exe
```

Result: PASS, exit `0`; all 16 tests passed.

Not run by request:

- TP-39-03 model run
- coverage

## Handoff

The immediate clean-build blocker from D39-QA-07 is fixed for the Step 7
promotion protocol target. Next owner is Manager/QA for a fresh D39-QA-07 rerun
gate that rebuilds the full authorized target set, then resumes parser, pure,
TP-39-03, and coverage rows only under the approved sequence.
