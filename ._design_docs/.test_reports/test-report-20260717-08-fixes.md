# Fix report: test-report-20260717-08

Date: 2026-07-17
Owner: Developer agent
Source report: `test-report-20260717-08.md`
Developer review: `test-report-20260717-08-developer-review.md`
Implementation part: `../cache-handling-phase39-implementation/part-181-d39-qa08-step11-fault-injection-test-fix-20260717.md`
Status: ACCEPTED BY ARCHITECT PART 182 PASS

## Scope

This fix ports `tests/test-step11-test-hooks-fault-injection.cpp` away from
retired async worker delay, queue-capacity, and completion-drain APIs. Product
code was not changed.

The repaired test now uses the current synchronous transaction behavior:

- `tx_demote_payload` for demotion rows
- `tx_promote_payload` for promotion rows
- stable residency assertions immediately after each transaction returns
- direct `.cold` file corruption for promotion read-validation failure rows

## Correction mapping

| Old row | Current outcome |
| --- | --- |
| Worker delay | Retired. Sync demotion and promotion complete before return; the row now asserts final residency and success counters without delay or drain. |
| Worker queue capacity | Retired. There is no worker queue. The row asserts normal inline demotion/promotion and zero queue-pressure counters. |
| Queue full at demotion | Retired. Demotion has no queue-full branch; the row asserts inline cold residency and zero queue-pressure counters. |
| Queue full at promotion | Retired. Promotion has no queue-full branch; the row asserts inline hot residency and zero queue-pressure counters. |
| Worker shutdown race | Retired. There is no background worker to race with destruction; the row asserts requested demotion is stable before controller release. |
| Cold-store validation failures | Preserved. The test corrupts committed cold files for magic, format, header checksum, payload-id/header-protected metadata, pair-state/header-protected metadata, target checksum, and draft checksum paths, then asserts sync promotion failure and eviction. |
| Demotion write failure | Preserved. The cold-store write-failure hook makes `tx_demote_payload` fail and leaves the descriptor hot with no cold descriptor. |

## Evidence

Commands run:

```powershell
cmake -S . -B build-stage39-qa08-step11-fix-20260717 `
  -DCMAKE_BUILD_TYPE=Release `
  -DLLAMA_STAGE39_LIVE_TEST_SEAM=ON `
  -DLLAMA_BUILD_TESTS=ON `
  -DGGML_CUDA=OFF

cmake --build build-stage39-qa08-step11-fix-20260717 `
  --config Release `
  --target test-step11-test-hooks-fault-injection `
  --parallel 4

.\build-stage39-qa08-step11-fix-20260717\bin\Release\test-step11-test-hooks-fault-injection.exe

rg -n "debug_set_completion_delay_for_tests|debug_set_io_worker_queue_capacity_for_tests|process_completions" `
  tests/test-step11-test-hooks-fault-injection.cpp
```

Results:

- Clean seam-ON Release configure: PASS
- Focused `test-step11-test-hooks-fault-injection` build: PASS
- Repaired executable: PASS, 17 Step 11 rows passed
- Retired symbol search in the repaired file: PASS, no matches

Not run:

- TP-39-03 model node
- coverage blocks
- full D39-QA target set

## Handoff

This closes the Developer-side stale Step 11 correction for D39-QA-08. Architect
Part 182 accepts the fix. QA can request the next gated rerun: clean full target
build, PowerShell 7/5 parser and pure checks, canonical TP-39-03, and coverage
only after full `Assert-Tp3903` PASS.
