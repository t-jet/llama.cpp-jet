# Stage 35 F35-QA-01 fix review

Report fixed: [test-report-20260708-01.md](test-report-20260708-01.md)
Fix report: [test-report-20260708-01-fixes.md](test-report-20260708-01-fixes.md)
Date: 2026-07-08
Reviewer: Architect
Scope: F35-QA-01 / TP-35-COV-01 fix review only
Verdict: REWORK

## Scope checked

Reviewed the Developer fix against:

- Stage 35 design and implementation handoff.
- QA report `test-report-20260708-01.md`.
- Developer test-results review `test-report-20260708-01-developer-review.md`.
- Stage 35 regression plan Part 40.
- Stage 25 synchronous transaction model.
- Current diffs in `tests/test-step10-metrics.cpp`,
  `tests/test-stage10-cold-store-hardening.cpp`, and
  `._design_docs/cache-handling-test-scripts/run_coverage.ps1`.

No product source fix, full test run, commit, push, PR, reviewer response, or
merge abort was performed.

## Decisions

The fix is correct to remove the obsolete async drain calls. Stage 25 Part 3
maps `process_completions` to removed behavior, and the current
`server-cache-hybrid.h` documents that demotion and promotion now execute
synchronously through `tx_demote_payload` and `tx_promote_payload`. Readding
`process_completions` would be architecturally wrong.

The coverage target cleanup is also valid in principle. The removed Step 6,
Step 7, and Step 11 targets still call `process_completions` or
`debug_set_io_worker_queue_capacity_for_tests`; those tests describe the
retired async worker contract, not the Stage 25 synchronous controller.
Keeping them in TP-35-COV-01 would preserve dead behavior as required
coverage.

No product behavior is hidden in the reviewed fix. The relevant diff changes
only the focused tests and the coverage script.

## Blocking finding

### F35-QA-FIX-01: Step 10 metrics checks compile but no longer prove the metric behavior they claim

Files:

- `tests/test-step10-metrics.cpp`
- `._design_docs/.test_reports/test-report-20260708-01-fixes.md`

The fix removes the stale `process_completions()` calls, but several Step 10
metric assertions still pass even if no demotion or cold-byte update happens:

- `test_demotion_success_counter()` reads `n_demotion_successes` after the
  demotion-triggering operation, then asserts `demotion_successes >= 0` on a
  `size_t`.
- `test_cold_payload_bytes_gauge()` reads `n_cold_payload_bytes`, then asserts
  `cold_bytes >= 0` on a `size_t`.
- `test_evictions_not_counting_demotions()` only checks the eviction counter
  when `demotion_successes > 0`; if the current synchronous demotion path does
  nothing, the test still passes.

That is enough to fix the compile failure, but not enough to satisfy the
Developer review requirement to keep the same Stage 10 metrics contract on the
current synchronous API. It also weakens the fix report's claim that the tests
"read metrics immediately after synchronous demotion-triggering operations":
they read them, but do not require the current demotion/cold-store metric
state to change.

Required correction:

- Update the affected Step 10 metrics tests so at least one deterministic
  current synchronous path proves demotion success, cold payload byte/count
  update, and eviction-vs-demotion counter behavior. Direct `demote_payload`
  or a deterministic budget-triggered demotion is acceptable.
- Keep `process_completions` and async queue-capacity hooks removed.
- Update the fix report with the corrected assertion semantics and focused
  evidence.
- Rebuild the corrected TP-35-COV-01 target set and rerun the same focused
  direct tests before QA reruns coverage.

## Non-blocking observations

- `tests/test-stage10-cold-store-hardening.cpp` is aligned with the Stage 25
  model: it now requires both demotions to complete synchronously and requires
  queue-full metrics/diagnostics to stay absent.
- `run_coverage.ps1` keeps current focused targets and still includes the
  hybrid cache implementation files in the denominator. Removing the retired
  async-only test files is acceptable after F35-QA-FIX-01 restores meaningful
  sync metrics assertions in the remaining Step 10 target.

## Handoff

Status: REWORK.

Next owner: Developer.

Next action: fix F35-QA-FIX-01 in the focused test path, refresh the fix
report, then return for Architect fix re-review before QA reruns TP-35-COV-01.
