# Phase 5 implementation: test-hook review

Source: [../cache-handling-phase5-implementation.md](../cache-handling-phase5-implementation.md)

## Review scope

Review date: May 28, 2026

This review covers only the Developer changes made after QA report [test-report-20260528-02.md](../.test_reports/test-report-20260528-02.md) blocked Stage 5 on missing focused and fault-injection evidence.

Reviewed files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tests/test-cache-controller.cpp`
- `._design_docs/cache-handling-phase5-implementation/part-08-review-fix-evidence.md`

The earlier production rollback implementation in `tools/server/server-context.cpp` was treated as the accepted Part 9 baseline.

## Verdict

PASS.

The added focused tests and fault hooks match the accepted Stage 5 design. I found no weakening of production descriptor validation, target/draft pair enforcement, rollback semantics, hit accounting, recency refresh, or Stage 5 metrics.

## Decisions

The descriptor fault injector mutates only test-created cache entries. The new helper methods are public only for the `LLAMA_SERVER_CACHE_TESTS` build and private in normal builds. Production save and restore paths still create descriptors through `attach_payload(...)` and restore through `validate_payload_for_restore(...)`.

The new checks cover the evidence gaps that blocked QA, except H43:

- H41 and N16-N18: unsupported descriptor version/kind, zero or mismatched target size, missing target bytes, bad store reference, missing hot record, owner mismatch, and checksum failure.
- H42 and N20: both pair-state mismatch directions.
- H44: validation rejection, target apply failure, draft apply failure, commit failure, rollback failure, fallback counters, and no-hit behavior.
- H46 and N23: unsupported empty-side clear preflight.
- H48 and N21: evicted and cold residency rejection.
- N19: unexpected draft bytes for target-only and missing draft bytes for target-plus-draft descriptors.

H43 remains outside this focused harness because it needs a public target-plus-draft model fixture. The Part 8 follow-up states that limitation without treating it as covered.

## Required corrections

None.

## Handoff

State: ready for QA rerun.

Next owner: QA or manager for Stage 5 verification gating.
