# Part 181: D39-QA-08 Step 11 fault-injection test fix

Date: 2026-07-17
Status: ACCEPTED BY PART 182 PASS
Related QA report: `../.test_reports/test-report-20260717-08.md`
Fix report: `../.test_reports/test-report-20260717-08-fixes.md`

## Scope

Part 180 classified D39-QA-08 as stale test automation in
`tests/test-step11-test-hooks-fault-injection.cpp`. This part records the
test-only port to the current synchronous transaction controller. No product
code, TP-39-03 workload, fixture, budget, threshold, seam route, or coverage
script changed.

## Changes

- Removed all Step 11 calls to retired async worker delay, queue-capacity, and
  completion-drain APIs.
- Replaced delayed completion assumptions with direct `tx_demote_payload` and
  `tx_promote_payload` assertions.
- Retired the async-only queue-full and shutdown-race rows with local rationale:
  the current controller has no worker queue and no background worker thread.
- Preserved fault coverage for cold-store read validation by corrupting the
  committed `.cold` file before synchronous promotion.
- Preserved the demotion write-failure row through the current cold-store write
  failure hook.

## Evidence

Fresh focused build root:
`build-stage39-qa08-step11-fix-20260717`

Commands and results:

| Command | Result |
| --- | --- |
| `cmake -S . -B build-stage39-qa08-step11-fix-20260717 -DCMAKE_BUILD_TYPE=Release -DLLAMA_STAGE39_LIVE_TEST_SEAM=ON -DLLAMA_BUILD_TESTS=ON -DGGML_CUDA=OFF` | PASS |
| `cmake --build build-stage39-qa08-step11-fix-20260717 --config Release --target test-step11-test-hooks-fault-injection --parallel 4` | PASS |
| `.\build-stage39-qa08-step11-fix-20260717\bin\Release\test-step11-test-hooks-fault-injection.exe` | PASS |
| `rg -n "debug_set_completion_delay_for_tests|debug_set_io_worker_queue_capacity_for_tests|process_completions" tests/test-step11-test-hooks-fault-injection.cpp` | PASS, no matches |

Notes:

- The executable passed all 17 Step 11 rows.
- Payload-id and pair-state byte mutations are rejected through the header
  checksum guard before the lower field-specific check. The test documents and
  accepts that current file-integrity order.
- TP-39-03 and coverage were deliberately not run.

## Handoff

Developer correction is accepted by Architect Part 182. QA should rerun the
exact D39-QA-08 gate order from Part 179 without widening scope.
