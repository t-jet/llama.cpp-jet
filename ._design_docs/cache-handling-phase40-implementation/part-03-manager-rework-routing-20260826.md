# Stage 40 Manager rework routing

Date: 2026-08-26
Stage: 40 (Upstream merge cycle)
Review: implementation-plan-review-20260826.md
Verdict: REWORK (1 BLOCKING, 6 NON-BLOCKING, 2 INFO)

## BLOCKING finding disposition

| ID | Finding | Required correction |
|----|---------|-------------------|
| F40-PMR-01 | Missing full per-commit triage table for all ~180 filtered commits (INTEGRATE + NO-OP). Only REWORK rows listed. | Developer must add a complete per-commit triage table covering ALL filtered commits per guide part-01 section 5. Each row: SHA, subject, file-glob group, affected contract, decision, reason citing contract. |

## NON-BLOCKING finding disposition

| ID | Required correction |
|----|-------------------|
| F40-PMR-02 | Fix SHA drift between part-01 and part-06 (`f5014e1a79d3` vs `f014e1a79d3`; `8c146a836630` vs `8c146a83630`). Verify all SHAs against actual git log. |
| F40-PMR-03 | Record D40-PLAN-01 staleness decision in both part-01 and part-06. The ref is now fresh — update metadata accordingly. |
| F40-PMR-06 | Add Stage 39 closure contracts (coverage floor 0.8486, VS2022 gap) to aggregate summary. |
| F40-PMR-07 | Name I-34-01/I-34-02 preservation explicitly in Track 2 (route/session lifecycle) scope. |

## Back to Developer

Same session rules: one gate at a time. Fix part-01 and part-06, update the entry doc status to reflect "awaiting re-review", then hand back to Manager.

## After corrections

Developer produces corrected part-01 and part-06. Manager verifies corrections applied, then delegates to fresh Architect session for re-review.