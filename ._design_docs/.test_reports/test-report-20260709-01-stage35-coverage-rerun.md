# Stage 35 focused TP-35-COV-01 coverage rerun

Date: 2026-07-09
Stage: 35
Scope: F35-QA-02 / TP-35-COV-01
Verdict: PASS

## Inputs

- Stage 35 implementation log:
  `._design_docs/cache-handling-phase35-implementation.md`
- Manager coverage decision:
  `._design_docs/cache-handling-phase35-implementation/part-32-manager-coverage-contract-decision-20260708.md`
- Coverage fix and review:
  `._design_docs/cache-handling-phase35-implementation/part-33-f35-qa-02-coverage-fix-review-20260709.md`

## Clean build

```powershell
cmake --build build-stage35-qa --config Release --target clean
cmake --build build-stage35-qa --config Release --target llama-server test-cache-controller test-step1-state-machine test-step2-cold-store test-step3-4-cold-store-write-read test-step9-startup-validation test-step10-metrics test-stage10-policy-lru test-stage10-cold-store-hardening test-step12-branch-graph test-step13-stage8 -j 8
```

Result: PASS.

Notes: MSVC emitted existing conversion warnings and existing `%zu` warnings in
nearby Stage 26 test assertions. No build error occurred.

## Execution

The coverage wrapper still has the known local `.cov` production issue through
its `Start-Process` path. QA used direct OpenCppCoverage invocation for each
focused target and merged the resulting binary coverage files.

Focused targets:

- `test-cache-controller`
- `test-step1-state-machine`
- `test-step2-cold-store`
- `test-step3-4-cold-store-write-read`
- `test-step9-startup-validation`
- `test-step10-metrics`
- `test-stage10-policy-lru`
- `test-stage10-cold-store-hardening`
- `test-step12-branch-graph`
- `test-step13-stage8`

Artifacts:

- `_test_output/stage35-f35-qa-02-dev/coverage-direct-13-clean/coverage-report.md`
- `_test_output/stage35-f35-qa-02-dev/coverage-direct-13-clean/coverage-summary.json`
- `_test_output/stage35-f35-qa-02-dev/coverage-direct-13-clean/coverage-merged.xml`
- `_test_output/stage35-f35-qa-02-dev/coverage-direct-13-clean/html/`
- `_test_output/stage35-f35-qa-02-dev/coverage-direct-13-clean/cov-binary/`

## Results

| Row | Result | Evidence |
| --- | --- | --- |
| Clean focused build | PASS | All required coverage targets built after `clean`. |
| Focused target execution | PASS | Direct OpenCppCoverage produced 10 `.cov` files. |
| Combined coverage floor | PASS | `0.8112`, `7795 / 9609`, threshold `0.80`. |
| Product-only coverage floor | PASS | `0.7026`, `2833 / 4032`, threshold `0.70`. |

## QA verdict

TP-35-COV-01 passes after F35-QA-02 rework. No remaining QA failure is assigned
from this focused rerun.
