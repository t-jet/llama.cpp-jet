# Developer review: Stage 39 D39-QA-07

Date: 2026-07-17
Verdict: REWORK REQUIRED
Source: `test-report-20260717-07.md`

## Classification

| Item | Classification | Owner | Next action |
| --- | --- | --- | --- |
| Clean Release seam-ON build failure in `test-step7-promotion-protocol` | Stale test/automation | Developer | Port the Step 7 promotion protocol test to the current synchronous `hybrid_cache_controller` API. |
| `hybrid_cache_controller` product API | No product defect established | None | Preserve the Stage 25/28 synchronous transaction API unless a separate design gate reopens it. |
| Parser, pure, TP-39-03, and coverage execution | Blocked by stale test build failure | QA after Developer fix and Manager gate | Rerun D39-QA-07 from a clean Release seam-ON build after the test compiles. |

The failure is a stale test/automation defect, not a product bug. It is also
not an out-of-scope prerequisite: `test-step7-promotion-protocol` is one of the
authorized clean-build targets in Manager Part 173. Configure passed, several
requested binaries were produced, and the first failure is a deterministic C++
compile error from removed member calls.

## Evidence reviewed

Manager Part 173 authorized a fresh clean Release seam-ON build, PowerShell 7
and Windows PowerShell 5 parser and pure checks, one bounded canonical
TP-39-03 node, then coverage only after full `Assert-Tp3903` PASS. It also
forbade product, fixture, workload, seam, budget, threshold, stage-plan, commit,
push, PR, or reviewer-response changes during QA.

QA report 07 stopped at the first verdict-fixing failure:

- Configure: PASS, exit `0`.
- Build: FAIL, exit `1`.
- First error: `tests\test-step7-promotion-protocol.cpp(212,10): error C2039:
  'debug_start_io_worker_for_tests': is not a member of
  'hybrid_cache_controller'`.
- `build-error-summary.txt` records 36 matching removed-member errors.
- No server started. Parser/pure checks, TP-39-03, and coverage did not run.

The current controller API confirms the test is stale. In
`tools/server/server-cache-hybrid.h`, the class comment says
`process_completions` was removed and demotion/promotion execute synchronously
through `tx_demote_payload` and `tx_promote_payload`. The public surface keeps
`demote_payload`, `promote_payload`, `tx_demote_payload`, `tx_promote_payload`,
and `tx_update`; it does not expose `debug_start_io_worker_for_tests`,
`debug_stop_io_worker_for_tests`, `debug_set_io_worker_queue_capacity_for_tests`,
or `process_completions`.

`tools/server/server-cache-hybrid.cpp` matches that contract. The constructor
wires the cold store to an inline worker helper but does not start a worker
thread. `promote_payload` and `tx_promote_payload` call
`handle_promotion_completion` inline and return the final success value.

The stale test still assumes the retired async model. It starts and stops an
I/O worker, drains completions, sleeps for completion propagation, checks an
intermediate `promoting` state after `promote_payload`, and simulates queue
pressure through a removed worker queue capacity hook.

## Required correction and retest

Developer owns the correction in `tests/test-step7-promotion-protocol.cpp`.
Update only the stale Step 7 test expectations and helper calls needed for the
current synchronous API:

- remove `debug_start_io_worker_for_tests`,
  `debug_stop_io_worker_for_tests`, `debug_set_io_worker_queue_capacity_for_tests`,
  and `process_completions` calls;
- remove sleeps used only to wait for retired async completion drains;
- rewrite success, failure, and corrupted-cold-file cases to assert the final
  immediate state after `demote_payload` or `promote_payload` returns;
- delete or replace queue-full coverage because there is no public worker queue
  path in the current API;
- keep the scope to this stale test unless the port exposes another compile
  error in the same authorized build target list.

Retest scope after the correction:

- configure a fresh clean Release seam-ON build with
  `-DLLAMA_STAGE39_LIVE_TEST_SEAM=ON -DLLAMA_BUILD_TESTS=ON -DGGML_CUDA=OFF`;
- build at least the D39-QA-07 target set:
  `llama-server`, `test-cache-controller`, `test-step10-metrics`,
  `test-stage10-cold-store-hardening`, `test-step6-demotion-protocol`,
  `test-step7-promotion-protocol`, `test-step11-test-hooks-fault-injection`,
  `test-step12-branch-graph`, and `test-step13-stage8`;
- run `test-step7-promotion-protocol` after it compiles so the new synchronous
  assertions are not only compile-checked;
- after Developer evidence and review, request Architect review if required by
  the fix path and then a new Manager gate for D39-QA-07 rerun;
- rerun PowerShell 7/5 parser and pure checks, one canonical TP-39-03 node, and
  only after full `Assert-Tp3903` PASS, the four coverage blocks authorized by
  Parts 149 and 155.

No code fix, build, model run, test run, or coverage command ran during this
review.
