# Stage 35 QA report fix loop

Report fixed: [test-report-20260708-01.md](test-report-20260708-01.md)
Developer review: [test-report-20260708-01-developer-review.md](test-report-20260708-01-developer-review.md)
Date: 2026-07-08
Owner: Developer
Finding: F35-QA-01 / TP-35-COV-01
Status: F35-QA-FIX-01 rework ready for Architect fix re-review

## Root cause

The failed coverage build was test drift, not a Stage 35 product runtime bug.
Stage 25/28 removed the async cache completion drain and retired the worker
queue controls. The current controller completes demotion and promotion
synchronously through the transaction path. Several old coverage-only targets
still asked for removed test hooks:

- `tests/test-step10-metrics.cpp` called
  `hybrid_cache_controller::process_completions()`.
- `tests/test-stage10-cold-store-hardening.cpp` expected a bounded async queue
  full path through `debug_set_io_worker_queue_capacity_for_tests()`.
- The coverage script still listed retired async-only Step 6, Step 7, and Step
  11 targets. Those tests still exercise the removed worker API and are no
  longer valid coverage targets for the synchronous controller contract.

The fix updates tests and coverage mapping only. Product cache code was not
changed.

## Files changed

- `tests/test-step10-metrics.cpp`
  - Removed `process_completions()` calls and now reads metrics immediately
    after synchronous demotion-triggering operations.
  - Removed unused `<thread>` and `<chrono>` includes.
- `tests/test-stage10-cold-store-hardening.cpp`
  - Updated the queue-pressure row to assert the current synchronous behavior:
    both demotions complete, queue-full counters stay zero, and no queue-full
    diagnostic rows are emitted.
- `._design_docs/cache-handling-test-scripts/run_coverage.ps1`
  - Removed retired async-only targets `test-step6-demotion-protocol`,
    `test-step7-promotion-protocol`, and
    `test-step11-test-hooks-fault-injection` from the coverage source list,
    focused target list, and denominator table.
  - Kept current buildable focused targets: `test-cache-controller`,
    `test-step10-metrics`, `test-stage10-cold-store-hardening`,
    `test-step12-branch-graph`, and `test-step13-stage8`.

## Evidence

Source-ref check before the fix:

```text
MERGE_HEAD = 47e1de77aa0f06bf73cfd8c5281d95979f89fcbe
origin/upstream_master = 47e1de77aa0f06bf73cfd8c5281d95979f89fcbe
remote refs/heads/upstream_master = 47e1de77aa0f06bf73cfd8c5281d95979f89fcbe
```

Focused target build:

```powershell
cmake --build build-stage35-qa --config Release --target test-step10-metrics -j 8
```

Result: PASS. `test-step10-metrics.exe` was produced.

Corrected coverage target build:

```powershell
cmake --build build-stage35-qa --config Release --target llama-server test-cache-controller test-step10-metrics test-stage10-cold-store-hardening test-step12-branch-graph test-step13-stage8 -j 8
```

Result: PASS. All corrected coverage targets built.

Direct focused tests:

```powershell
build-stage35-qa\bin\Release\test-step10-metrics.exe
build-stage35-qa\bin\Release\test-stage10-cold-store-hardening.exe
```

Result: PASS for both executables. `test-step10-metrics` reported all Step 10
tests passed. `test-stage10-cold-store-hardening` reported all Stage 10
cold-store hardening tests passed.

Coverage script smoke:

```powershell
pwsh -NoProfile -File .\._design_docs\cache-handling-test-scripts\run_coverage.ps1 `
  -BuildDir build-stage35-qa `
  -OutDir _test_output\stage35-upstream-merge-20260708-01\coverage-fix-rerun `
  -SkipServerProbe
```

Result: PARTIAL. The script ran the corrected 5 focused targets and each target
process exited 0, but this local smoke produced no `.cov` files and stopped at
`No .cov files produced; cannot generate coverage report.` The compile drift is
fixed; full TP-35-COV-01 still needs the normal QA coverage rerun with
OpenCppCoverage evidence and the server probe scope selected by QA/Manager.

Hygiene:

```powershell
git diff --check -- tests/test-step10-metrics.cpp tests/test-stage10-cold-store-hardening.cpp .\._design_docs\cache-handling-test-scripts\run_coverage.ps1
```

Result: PASS.

## F35-QA-FIX-01 rework

Architect fix review
[test-report-20260708-01-fix-review.md](test-report-20260708-01-fix-review.md)
found that `test-step10-metrics` still compiled with weak checks:
`size_t >= 0` assertions and a conditional demotion branch could pass with
zero synchronous demotions.

Rework changed only `tests/test-step10-metrics.cpp`:

- `test_demotion_success_counter()` now drives `tx_demote_payload(1)` on a
  configured cold store and requires `n_demotion_successes == 1`,
  `n_demotion_failures == 0`, and `n_cold_payload_count == 1`.
- `test_cold_payload_bytes_gauge()` now demotes a target-and-draft payload and
  requires exact cold metrics: `n_cold_payload_bytes == 125`,
  `n_cold_payload_count == 1`, `n_cold_payload_descriptors == 1`, and
  `n_hot_payload_descriptors == 0`.
- `test_evictions_not_counting_demotions()` now requires synchronous demotion
  success and requires `n_payload_evictions` to remain unchanged after that
  demotion.

The rework kept `process_completions` and async queue-capacity hooks removed.
No product source changed.

Focused rework build:

```powershell
cmake --build build-stage35-qa --config Release --target test-step10-metrics test-stage10-cold-store-hardening -j 8
```

Result: PASS. Both `test-step10-metrics.exe` and
`test-stage10-cold-store-hardening.exe` were produced.

Focused direct tests:

```powershell
build-stage35-qa\bin\Release\test-step10-metrics.exe
build-stage35-qa\bin\Release\test-stage10-cold-store-hardening.exe
```

Result: PASS for both executables. `test-step10-metrics` reported all 10 Step
10 tests passed. `test-stage10-cold-store-hardening` reported all 20 cold-store
hardening tests passed.

## Retest scope

Architect fix review
[test-report-20260708-01-fix-review.md](test-report-20260708-01-fix-review.md)
returned REWORK. The F35-QA-FIX-01 rework above now adds deterministic current
synchronous metrics assertions before the TP-35-COV-01 rerun.

QA should rerun TP-35-COV-01 with the corrected coverage target set from
`run_coverage.ps1`. At minimum, rebuild:

```powershell
cmake --build build-stage35-qa --config Release --target llama-server test-cache-controller test-step10-metrics test-stage10-cold-store-hardening test-step12-branch-graph test-step13-stage8 -j 8
```

Then rerun:

```powershell
pwsh -NoProfile -File ._design_docs\cache-handling-test-scripts\run_coverage.ps1 `
  -BuildDir build-stage35-qa `
  -OutDir _test_output\stage35-upstream-merge-20260708-01\coverage-rerun
```

Use the generated markdown report for combined, product-only, and per-file
coverage evidence. The previously passed Stage 35 runtime, route, metrics,
router, stream, and Stage 34 synthetic rows do not need a full rerun for this
test-only fix unless Manager expands the gate.

## F35-QA-02 coverage rework attempt

Manager decision
[part-32-manager-coverage-contract-decision-20260708.md](../cache-handling-phase35-implementation/part-32-manager-coverage-contract-decision-20260708.md)
rejected a coverage exception and asked Developer to add current, meaningful
coverage. This attempt changed tests and coverage mapping only. No production
cache behavior changed.

Changes:

- `tests/test-cache-controller.cpp`
  - Added `test_stage35_current_sync_restore_coverage()`.
  - Covers current synchronous `load_slot` miss, unsafe-prefix rejection, exact
    hit with null contexts, checkpoint admission helper overloads, checkpoint
    source selection, hot checkpoint promotion request, restore transaction
    failure branches, and captured restore-plan apply calls.
- `._design_docs/cache-handling-test-scripts/run_coverage.ps1`
  - Restored current buildable focused rows to the coverage target set:
    `test-step1-state-machine`, `test-step2-cold-store`,
    `test-step3-4-cold-store-write-read`, `test-step9-startup-validation`, and
    `test-stage10-policy-lru`.
  - Kept obsolete async-only rows retired: `test-step5-io-worker`,
    `test-step6-demotion-protocol`, `test-step7-promotion-protocol`,
    `test-step8-integration-wiring`, and
    `test-step11-test-hooks-fault-injection`.

Evidence:

```powershell
cmake --build build-stage35-qa --config Release --target llama-server test-cache-controller test-step1-state-machine test-step2-cold-store test-step3-4-cold-store-write-read test-step9-startup-validation test-step10-metrics test-stage10-policy-lru test-stage10-cold-store-hardening test-step12-branch-graph test-step13-stage8 -j 8
```

Result: PASS.

```powershell
build-stage35-qa\bin\Release\test-cache-controller.exe
build-stage35-qa\bin\Release\test-stage10-policy-lru.exe
```

Result: PASS. `test-cache-controller` reports 151 tests.

Wrapper smoke:

```powershell
pwsh -NoProfile -File .\._design_docs\cache-handling-test-scripts\run_coverage.ps1 -BuildDir build-stage35-qa -OutDir _test_output\stage35-f35-qa-02-dev\coverage-wrapper -SkipServerProbe
```

Result: FAIL with the same known wrapper issue: all focused test processes
exited 0, but no `.cov` files were produced through the wrapper.

Direct OpenCppCoverage evidence:

- `_test_output/stage35-f35-qa-02-dev/coverage-direct-03/coverage-report.md`
- `_test_output/stage35-f35-qa-02-dev/coverage-direct-03/coverage-summary.json`
- `_test_output/stage35-f35-qa-02-dev/coverage-direct-03/coverage-merged.xml`
- `_test_output/stage35-f35-qa-02-dev/coverage-direct-03/cov-binary/`

Measured result:

```text
combined: 0.7759, 7143 / 9206, threshold 0.80 FAIL
product-only: 0.6346, 2556 / 4028, threshold 0.70 FAIL
```

This is a meaningful lift over QA rerun -02 (`combined 0.734`,
`product-only 0.5856`) but it does not close TP-35-COV-01. The remaining gap is
mostly in `server-cache-hybrid.cpp` live `llama_context` save/restore/apply
paths and sync completion edge branches. F35-QA-02 is not ready for Architect
fix review yet.

## F35-QA-02 local Manager coverage pass

Subagent capacity was unavailable during this Manager pass, so the Manager
continued the focused coverage rework locally to keep the gate moving. The work
stayed inside test-only coverage scope.

Additional changes:

- `tests/test-cache-controller.cpp`
  - Added Stage 35 focused coverage for metadata-only rematerialization,
    checkpoint cold promotion, promotion completion edge cases, raw prompt
    evidence, cold-budget checks, synchronous I/O worker paths, LRU protected
    ordering, and cold-store public failure/success paths.

Evidence:

```powershell
cmake --build build-stage35-qa --config Release --target test-cache-controller -j 8
build-stage35-qa\bin\Release\test-cache-controller.exe
```

Result: PASS. `test-cache-controller` reports 151 tests. Existing warnings are
pre-existing `%zu` format warnings in nearby Stage 26 assertions.

Coverage wrapper:

```powershell
.\._design_docs\cache-handling-test-scripts\run_coverage.ps1 -BuildDir .\build-stage35-qa -OutDir .\_test_output\stage35-f35-qa-02-dev\coverage-direct-04 -SkipServerProbe
```

Result: FAIL with the known wrapper issue: all focused test processes exited 0,
but no `.cov` files were produced through `Start-Process`.

Direct OpenCppCoverage evidence:

- `_test_output/stage35-f35-qa-02-dev/coverage-direct-09/coverage-report.md`
- `_test_output/stage35-f35-qa-02-dev/coverage-direct-09/coverage-summary.json`
- `_test_output/stage35-f35-qa-02-dev/coverage-direct-09/coverage-merged.xml`
- `_test_output/stage35-f35-qa-02-dev/coverage-direct-09/cov-binary/`

Measured result:

```text
combined: 0.8000+ PASS
product-only: 0.6935, 2796 / 4032, threshold 0.70 FAIL
```

This pass closes the combined threshold but still misses product-only coverage.
F35-QA-02 remains in Developer rework. Next work should target real
`server-cache-hybrid.cpp` product paths, preferably live-context save/restore
and apply branches, rather than adding more broad helper coverage.
