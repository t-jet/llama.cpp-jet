# Stage 19 design part 3: test plan rows, closure criteria, traceability

Status: authored; pending Architect design review
Date: 2026-06-18
Stage: 19 (System-Level Model Warmup Crash Investigation)
Source: [entry doc](../cache-handling-phase19-design.md)

## Test plan rows proposed

The test plan is a separate durable doc (under
`cache-handling-test-plan/`). The Stage 19 design proposes these rows;
the test plan agent picks them up or modifies based on the design
review.

| Row | Tier | Type | Description |
| --- | --- | --- | --- |
| TP-19-RT1 | integration | reproduction | baseline launch with no cache flags, 5x repeat, expect clean `/health` 200 each run |
| TP-19-RT2 | integration | reproduction | baseline launch with system memory snapshot before/after, expect working set stable |
| TP-19-RT3 | integration | regression | Stage 18 IT1 + IT3 cache-flag-induced paths still PASS (smoke check on rerun) |
| TP-19-FT1 | focused | signature | if crash reproduces, capture crash signature in test-cache-controller fixture (size, address, stack frame count) for future regression |

Count by tier: 3 integration, 1 focused. Total 4 rows proposed.

## Closure criteria

Stage 19 closes when:

1. The reproduction plan runs in a fresh Developer session.
2. The root cause analysis (Step 1-3) produces a Branch A, B, or C
   verdict with evidence.
3. The fix proposal (or no-fix decision) is applied or recorded.
4. The test plan rows pass (Branch A) or are recorded as no-op
   (Branch B/C).
5. The Manager closure decision records the verdict and any follow-up.

## Traceability

| Source decision | Stage 19 design link |
| --- | --- |
| D17-EXEC-02 (Stage 17 closure 2026-06-17) | Branch A/B/C question; reproduction plan; root cause analysis Step 3 |
| D18-CLOSURE-01 substantive finding (Stage 18 closure 2026-06-18) | Reproduction plan Step 1 (validation block gate analysis); Branch C (Stage 18 fix may already cover) |
| `test-report-20260617-01.md` F-17-EXEC-01 row 14 (baseline crash 1/1) | Reproduction plan RT1.1 baseline evidence source |
| `cache-handling-phase17-implementation/part-06-architect-bugfix-review-gate-01.md` row 14 (3/3 baseline trials) | Reproduction plan RT1.2 repeat count rationale |
| `cache-handling-phase17-implementation/part-06-architect-bugfix-review-gate-01.md` row 16 (crash at warmup stage) | Root cause analysis Step 2 crash site candidates |
| Stage 18 fix: validation block moved from 1381-1427 to 1242-1291 | Reproduction plan Step 1 (validation block gate analysis) |

This file uses LF line endings, plain ASCII status labels, and stays under
the 300-line durable doc cap.
