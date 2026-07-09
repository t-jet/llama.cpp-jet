# Stage 35 F35-QA-01 fix re-review

Report fixed: [test-report-20260708-01.md](test-report-20260708-01.md)
Fix report: [test-report-20260708-01-fixes.md](test-report-20260708-01-fixes.md)
Prior review: [test-report-20260708-01-fix-review.md](test-report-20260708-01-fix-review.md)
Date: 2026-07-08
Reviewer: Architect
Scope: F35-QA-FIX-01 re-review only
Verdict: PASS

## Scope checked

Reviewed the F35-QA-FIX-01 rework against:

- QA report `test-report-20260708-01.md`.
- Developer fix report `test-report-20260708-01-fixes.md`.
- Prior Architect fix review `test-report-20260708-01-fix-review.md`.
- Stage 35 design and implementation handoff.
- Stage 35 test plan Part 40 coverage row.
- Current unstaged diffs in `tests/test-step10-metrics.cpp`,
  `tests/test-stage10-cold-store-hardening.cpp`, and
  `._design_docs/cache-handling-test-scripts/run_coverage.ps1`.
- Current staged diff for the same files.

No product source fix, full test run, commit, push, PR, reviewer response, or
merge abort was performed.

## Decisions

F35-QA-FIX-01 is closed.

`tests/test-step10-metrics.cpp` now uses deterministic synchronous demotion
paths:

- `test_demotion_success_counter()` adds one hot payload, calls
  `tx_demote_payload(1)`, and requires `n_demotion_successes == 1`,
  `n_demotion_failures == 0`, and `n_cold_payload_count == 1`.
- `test_cold_payload_bytes_gauge()` adds a target-and-draft payload with
  `target_bytes=100` and `draft_bytes=25`, calls `tx_demote_payload(1)`, and
  requires exact cold metrics: `n_cold_payload_bytes == 125`,
  `n_cold_payload_count == 1`, `n_cold_payload_descriptors == 1`, and
  `n_hot_payload_descriptors == 0`.
- `test_evictions_not_counting_demotions()` captures
  `n_payload_evictions`, calls `tx_demote_payload(1)`, requires demotion
  success to advance by one, and requires the eviction counter to stay
  unchanged.

These checks now fail if synchronous demotion does not complete, if cold
bytes/count/descriptors do not update, or if demotion is incorrectly counted as
payload eviction.

The async drain and queue-capacity hooks remain removed from the active fix.
Current diffs for the reviewed files contain no `process_completions` call and
no `debug_set_io_worker_queue_capacity_for_tests` call. The stale Step 6, Step
7, and Step 11 tests still contain retired async-worker references, but
`run_coverage.ps1` no longer treats those async-only tests as TP-35-COV-01
focused coverage targets. That mapping is acceptable because Part 40 requires
focused coverage for current feature-mode source, not preservation of retired
worker behavior as an active denominator.

The coverage script still runs the current focused targets:
`test-cache-controller`, `test-step10-metrics`,
`test-stage10-cold-store-hardening`, `test-step12-branch-graph`, and
`test-step13-stage8`, plus the optional server probe when enabled. It keeps the
hybrid cache implementation files in the coverage source set and removes only
retired async-only test files from the test denominator.

## Evidence checked

- `git diff --cached -- ...` for the three reviewed paths is empty.
- `git diff -- ...` shows only test/script changes for the reviewed paths.
- `rg` found no active `process_completions` or
  `debug_set_io_worker_queue_capacity_for_tests` reference in
  `tests/test-step10-metrics.cpp`,
  `tests/test-stage10-cold-store-hardening.cpp`, or
  `run_coverage.ps1`.
- `server-cache-hybrid.cpp` shows `tx_demote_payload` executes inline, calls
  `handle_demotion_completion`, and on success increments
  `n_cold_payload_bytes`, `n_cold_payload_count`, and
  `n_demotion_successes`.
- `debug_add_entry_for_tests(..., target_bytes, draft_bytes)` constructs target
  and draft byte vectors with the requested sizes, so the exact `125` byte
  assertion is tied to the real descriptor sizes used by the test.
- `git diff --check -- tests/test-step10-metrics.cpp
  tests/test-stage10-cold-store-hardening.cpp
  ._design_docs/cache-handling-test-scripts/run_coverage.ps1` produced no
  whitespace errors.

## Handoff

Status: PASS.

Next owner: QA.

Next gate: rerun TP-35-COV-01 with the corrected focused coverage target set.
The previously passed Stage 35 runtime, route, metrics, router, stream, and
Stage 34 synthetic rows do not need a full rerun for this test-only fix unless
Manager expands the gate.
