# Part 174: Developer D39-QA-07 results review

Date: 2026-07-17
Status: REWORK REQUIRED
Scope: QA report 20260717-07 clean-build failure

## Verdict

Full review:
`../.test_reports/test-report-20260717-07-developer-review.md`

D39-QA-07 failed before parser, pure, TP-39-03, or coverage execution because
`test-step7-promotion-protocol` still calls removed async
`hybrid_cache_controller` APIs. This is stale test/automation. No Stage 39
product defect is established.

Manager Part 173 authorized the failed target as part of the clean Release
seam-ON build. QA report 07 records configure PASS, build FAIL, and 36
removed-member errors beginning with
`debug_start_io_worker_for_tests` at
`tests/test-step7-promotion-protocol.cpp:212`. The same target still calls
`process_completions`, `debug_stop_io_worker_for_tests`, and
`debug_set_io_worker_queue_capacity_for_tests`.

Current controller code intentionally retired that async surface. The header
states that `process_completions` was removed and demotion/promotion now run
synchronously through the transaction path. The implementation wires cold-store
access through an inline helper and calls `handle_promotion_completion` before
`promote_payload` or `tx_promote_payload` returns.

## Correction and retest

Developer owns a test-only correction in
`tests/test-step7-promotion-protocol.cpp`: port Step 7 promotion tests to the
current synchronous API, remove worker start/stop, queue-capacity, completion
drain, and completion-wait assumptions, and assert final immediate residency
and metric outcomes. Queue-full coverage must be deleted or replaced because
the public worker-queue path no longer exists.

Retest after the fix must include a fresh clean Release seam-ON configure and
the full D39-QA-07 build target set. `test-step7-promotion-protocol` must also
execute, not just compile. After focused Developer evidence and any required
review, Manager must authorize the fresh D39-QA-07 rerun. Coverage remains
blocked until the canonical TP-39-03 node reaches full `Assert-Tp3903` PASS.

No product code, fixture, workload, seam, budget, threshold, stage-plan, commit,
push, PR, or reviewer-response change is authorized by this review. No fix,
build, test, model run, or coverage command ran here.
