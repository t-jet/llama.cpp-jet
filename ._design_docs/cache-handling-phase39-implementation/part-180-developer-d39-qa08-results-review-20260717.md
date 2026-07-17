# Part 180: Developer D39-QA-08 results review

Date: 2026-07-17
Verdict: REWORK REQUIRED
Related report: `._design_docs/.test_reports/test-report-20260717-08.md`
Developer review: `._design_docs/.test_reports/test-report-20260717-08-developer-review.md`

## Decision

D39-QA-08 fails at the clean seam-ON Release full-target build. The failure is
stale test/automation in `tests/test-step11-test-hooks-fault-injection.cpp`.
It is not a Stage 39 product bug, not an execution-environment blocker, and
not a design mismatch.

The failing test still calls retired async worker APIs:

- `server_cache_io_worker::debug_set_completion_delay_for_tests`
- `hybrid_cache_controller::debug_set_io_worker_queue_capacity_for_tests`
- `hybrid_cache_controller::process_completions`

The current product API is synchronous. `server-cache-hybrid.h` documents that
`process_completions` was removed and demotion/promotion now execute through
`tx_demote_payload` and `tx_promote_payload` under `cache_state_mutex_`.
`server-cache-io-worker.h` documents that the async worker body, work queue,
result queue, and queue-full scheduling were removed.

## Repeated stale async failures

The repeated async failures point to remaining old test targets, not a broader
Stage 39 design or implementation mismatch.

D39-QA-07 exposed the same class in Step 7. Part 175 ported Step 7 to the
current synchronous controller API, and Part 178 accepted the later controller
matrix fix. D39-QA-08 now exposes Step 11 as another old target that was not
yet ported. The product headers and Stage 25 migration contract agree on the
synchronous model, and the failure occurs at compile time before any runtime
Stage 39 behavior is exercised.

The durable risk is test inventory drift: Developer should audit the remaining
D39-QA target set for calls to retired async worker and completion-drain APIs
while fixing Step 11.

## Owner and correction scope

Owner: Developer.

Correction scope:

- Port `tests/test-step11-test-hooks-fault-injection.cpp` to current
  synchronous fault-injection behavior.
- Remove or replace old async delay, queue-capacity, completion-drain, and
  worker-shutdown-race assertions.
- Preserve meaningful cold-store validation, write-failure, promotion-failure,
  demotion, promotion, and target/draft pair fault coverage using current
  controller hooks.
- Do not add compatibility shims for retired async APIs.
- Do not change product code unless the port reveals a separate, reviewed
  missing synchronous test hook.
- Do not change TP-39-03 workload, fixtures, budgets, thresholds, seams, or
  coverage scripts under this handoff.

## Evidence required from the fix

Developer must provide:

- Fresh clean seam-ON Release configure.
- Focused build of `test-step11-test-hooks-fault-injection`.
- Direct execution of the repaired Step 11 binary.
- Search or compile evidence that Step 11 no longer calls
  `process_completions`, `debug_set_completion_delay_for_tests`, or
  `debug_set_io_worker_queue_capacity_for_tests`.
- A short mapping of retired async rows to their synchronous replacement or
  explicit removal.

QA retest after Developer and Architect review:

- Repeat Manager Part 179's D39-QA-08 order: clean full target build,
  PowerShell 7/5 parser and pure tests, one canonical TP-39-03 node, and only
  then four coverage blocks after full `Assert-Tp3903` PASS.

No code was changed for this review.
