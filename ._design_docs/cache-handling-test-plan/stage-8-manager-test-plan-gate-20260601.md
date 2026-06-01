# Stage 8 manager test-plan gate - 2026-06-01

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

Manager decision: ACCEPT TEST PLAN

## Evidence checked

- [Stage 8 test-plan part](part-10-stage8-metadata-only-rematerialization.md)
- [Stage 8 test-plan review](stage-8-test-plan-review-20260601.md), verdict PASS
- [Stage 8 implementation re-review](../cache-handling-phase8-implementation/part-10-architect-implementation-re-review-20260601.md), verdict PASS
- [cache-handling-test-scripts README](../cache-handling-test-scripts/README.md)

## Decision

The Stage 8 test plan is accepted. QA execution is open.

Execution must use the evidence-source rules from Part 10:

- public HTTP evidence for model-backed cache behavior, metrics snapshots, and public surface regression when it can create the required precondition
- `test-step13-stage8` for metadata-only graph internals, re-materialization, mismatch handling, equivalent deduplication, admission rejection, and cold cleanup ownership
- `test-cache-controller` for controller-level regression and inherited Stage 4-7 behavior
- `tools/server/tests/unit/test_cache_modes.py` for public Prometheus metric shape and `/cache/stats` behavior
- `BLOCKED` for rows whose required harness, model, or internal precondition is unavailable

## Handoff

Gate: Test execution
Owner: QA
Expected deliverable: a fresh full Stage 8 test report under `._design_docs/.test_reports/`.
