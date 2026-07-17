# Developer review: test-report-20260717-08

Date: 2026-07-17
Reviewer: Developer agent
Input report: `._design_docs/.test_reports/test-report-20260717-08.md`
Evidence root: `._test_output/test-report-20260717-08/`
Verdict: REWORK REQUIRED

## Scope reviewed

- Manager rerun gate:
  `._design_docs/cache-handling-phase39-implementation/part-179-manager-d39-qa08-rerun-gate-20260717.md`
- QA report:
  `._design_docs/.test_reports/test-report-20260717-08.md`
- Build evidence:
  `._test_output/test-report-20260717-08/build/build-error-summary.txt`
  and `build-full-target-set.log`
- Failing test:
  `tests/test-step11-test-hooks-fault-injection.cpp`
- Current synchronous controller API:
  `tools/server/server-cache-hybrid.h`
  and `tools/server/server-cache-io-worker.h`
- Stage 25 transaction contract:
  `._design_docs/cache-handling-phase25-design/part-03-per-operation-migration.md`

## Classification

The build failure is stale test/automation, not a product bug, execution
blocker, or design mismatch.

The compiler failure is confined to
`tests/test-step11-test-hooks-fault-injection.cpp`. The first failing symbol is
`server_cache_io_worker::debug_set_completion_delay_for_tests` at line 155.
The same target also calls removed `hybrid_cache_controller::process_completions`
and `debug_set_io_worker_queue_capacity_for_tests`.

Current product headers explicitly reject that async model:

- `server-cache-hybrid.h:428-431` says `process_completions` was removed and
  demotion/promotion now run synchronously through `tx_demote_payload` and
  `tx_promote_payload`.
- `server-cache-hybrid.h:433-455` names `tx_save`, `tx_load`, `tx_restore`,
  `tx_apply_restore`, `tx_demote_payload`, `tx_promote_payload`,
  `tx_evict_entry`, and `tx_update` as the current transaction surface.
- `server-cache-io-worker.h:12-23` says the async worker body, queue, result
  queue, and queue-full scheduling were removed; the class now exists as a
  thin inline helper container.
- `server-cache-io-worker.h:58-74` exposes inline execution helpers only, not
  completion-delay or queue-capacity hooks.
- Stage 25 migration text at
  `cache-handling-phase25-design/part-03-per-operation-migration.md:146-154`
  says there is no completion drain and old `process_completions` test calls
  must move to the synchronous transaction surface.

Because the product header no longer promises the removed APIs and documents
the replacement, this is a stale Step 11 test target. Adding compatibility
shims or restoring async queue semantics would be the wrong fix.

## Broader stale-async assessment

This does not prove a broader design or implementation mismatch. It proves that
at least one more old test target still carries pre-Stage-25/28 async worker
assumptions.

Evidence:

- D39-QA-07 failed on the same class of stale async calls in
  `test-step7-promotion-protocol`.
- Part 175 ported Step 7 to the synchronous controller API and passed focused
  seam-ON Release build plus executable checks.
- Part 178 accepted the later controller terminal matrix fix, so the current
  product API and C++ terminal behavior are already reviewed after that port.
- D39-QA-08 now fails before any parser, pure, model-backed, or coverage row
  runs, and the only reported failure is missing retired async members in
  Step 11.

So the pattern is remaining old tests, not a current design split. The durable
risk is coverage-target drift: more legacy unit targets may still compile only
when they happen not to be included in the current D39-QA target set.

## Findings

| ID | Finding | Classification | Owner | Required correction |
| --- | --- | --- | --- | --- |
| F39-QA08-01 | `test-step11-test-hooks-fault-injection.cpp` still calls removed async worker delay, queue-capacity, and completion-drain APIs. | Stale test/automation | Developer | Port Step 11 to the synchronous transaction model. Remove async delay/queue-full/shutdown-race assumptions, or replace them with current observable fault paths through `tx_demote_payload`, `tx_promote_payload`, `tx_update`, cold-store failure hooks, and existing transaction/debug helpers. |
| F39-QA08-02 | D39-QA-08 stopped at the clean full target build, so PowerShell parser/pure checks, canonical TP-39-03, and coverage blocks have no fresh evidence. | Blocked by stale test target | QA after Developer fix | Rerun the exact D39-QA-08 order after F39-QA08-01 is reviewed: clean seam-ON Release full target build, PowerShell 7 parser/pure, Windows PowerShell 5 parser/pure, one canonical TP-39-03 node, then the four coverage blocks only after full `Assert-Tp3903` PASS. |

## Retest scope

Developer correction scope:

- `tests/test-step11-test-hooks-fault-injection.cpp` only, unless the port
  exposes a missing current test helper that must be reviewed separately.
- No product-code fix is authorized by this review.
- No fixture, workload, seam, budget, threshold, coverage script, or TP-39-03
  driver change is authorized by this review.

Developer evidence required before QA rerun:

- Fresh clean seam-ON Release configure for the repair build root.
- Focused build of `test-step11-test-hooks-fault-injection`.
- Direct execution of the repaired Step 11 binary.
- A search or compile proof that the test no longer calls
  `process_completions`, `debug_set_completion_delay_for_tests`, or
  `debug_set_io_worker_queue_capacity_for_tests`.
- A short note identifying which old async fault rows were retired versus
  which current synchronous fault rows still provide coverage.

QA retest scope after Developer and Architect review:

- Repeat the D39-QA-08 command order from Manager Part 179 without widening it.
- Stop on the first verdict-fixing failure.
- Keep coverage blocked until canonical TP-39-03 reaches full
  `Assert-Tp3903` PASS.

## Handoff

Owner: Developer.

Next durable implementation record:
`._design_docs/cache-handling-phase39-implementation/part-180-developer-d39-qa08-results-review-20260717.md`.

No code was changed in this review session.
