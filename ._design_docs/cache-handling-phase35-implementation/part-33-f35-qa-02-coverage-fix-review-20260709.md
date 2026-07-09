# Part 33: F35-QA-02 coverage fix and review

Date: 2026-07-09
Stage: 35
Finding: F35-QA-02 / TP-35-COV-01
Verdict: PASS

## Scope

Part 32 rejected a coverage exception and sent F35-QA-02 back for focused
coverage rework. The rework stayed test-only. No product cache behavior changed.

## Fix summary

`tests/test-cache-controller.cpp` now has current Stage 35 coverage for:

- synchronous restore misses, unsafe-prefix rejection, exact null-context hits,
  checkpoint admission, checkpoint source selection, and restore apply calls;
- metadata-only rematerialization, checkpoint cold promotion, promotion
  completion failure cases, raw prompt evidence, cold-budget checks, sync I/O
  worker paths, and cold-store public failure/success paths;
- base `cache_controller` default restore delegation, LRU protected/tie
  ordering, direct sync worker dispatch and write failure, debug accessors, and
  `demote_payload` rejection paths for missing descriptors, in-progress
  demotion, non-hot residency, unconfigured cold store, missing hot payload,
  target/draft pair mismatch, and cold budget pressure.

The test count is now 152. Existing `%zu` warnings in nearby Stage 26 assertions
remain pre-existing.

## Evidence

Focused build and test:

```powershell
cmake --build build-stage35-qa --config Release --target test-cache-controller -j 8
build-stage35-qa\bin\Release\test-cache-controller.exe
```

Result: PASS. `test-cache-controller` reports 152 tests.

Clean focused coverage build:

```powershell
cmake --build build-stage35-qa --config Release --target clean
cmake --build build-stage35-qa --config Release --target llama-server test-cache-controller test-step1-state-machine test-step2-cold-store test-step3-4-cold-store-write-read test-step9-startup-validation test-step10-metrics test-stage10-policy-lru test-stage10-cold-store-hardening test-step12-branch-graph test-step13-stage8 -j 8
```

Result: PASS.

Direct TP-35-COV-01 coverage rerun:

- `_test_output/stage35-f35-qa-02-dev/coverage-direct-13-clean/coverage-report.md`
- `_test_output/stage35-f35-qa-02-dev/coverage-direct-13-clean/coverage-summary.json`
- `_test_output/stage35-f35-qa-02-dev/coverage-direct-13-clean/coverage-merged.xml`
- `_test_output/stage35-f35-qa-02-dev/coverage-direct-13-clean/cov-binary/`

Measured result:

```text
combined: 0.8112, 7795 / 9609, threshold 0.80 PASS
product-only: 0.7026, 2833 / 4032, threshold 0.70 PASS
```

## Architect fix review

Verdict: PASS.

The rework is acceptable for the Stage 35 coverage contract:

- It is test-only and keeps product behavior unchanged.
- New coverage targets current synchronous cache behavior, not retired async
  worker APIs.
- The added private access is limited to existing test-only coverage style in
  `test-cache-controller.cpp` and exercises concrete current branches.
- The clean focused coverage build and direct OpenCppCoverage rerun meet both
  binding floors.

No blocking findings remain. QA may accept the focused TP-35-COV-01 rerun.
