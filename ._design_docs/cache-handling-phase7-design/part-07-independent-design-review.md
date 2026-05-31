# Part 07: Independent design review - Stage 7

Reviewer: Architect agent  
Date: 2026-05-31  
Verdict: REWORK

## Scope

Reviewed the Stage 7 design entry and Parts 01-06 against the cache architecture and
requirements.

Documents reviewed:

- `cache-handling-phase7-design.md`
- `part-01-overview-and-objectives.md`
- `part-02-component-design.md`
- `part-03-implementation-steps.md`
- `part-04-test-specifications.md`
- `part-05-metrics-and-observability.md`
- `part-06-acceptance-criteria.md`

Reference documents:

- `cache-handling-architecture/part-01-method.md`
- `cache-handling-architecture/part-02-restore-and-residency-flow.md`
- `cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md`
- `cache-handling-requirements/part-02-fully-slot-independent-shared-reuse.md`
- `cache-handling-phase6-design/part-06-testability-and-requirement-traceability.md`
- `cache-handling-phase6-design/part-07-exclusions-risks-and-review-readiness.md`

## Finding details

The detailed review text was split to satisfy the 300-line document rule:

- [Part 07A: blocking findings](part-07a-independent-design-review-blocking.md)
- [Part 07B: non-blocking findings and traceability](part-07b-independent-design-review-nonblocking.md)

## Summary

Blocking findings:

| Finding | Area | Summary |
| --- | --- | --- |
| B1 | Architecture traceability | The proposed `BranchNode` was a slot metadata record, not the shared forest node required by the architecture. |
| B2 | Budget model | The design used per-namespace slot limits instead of the required shared global budget model. |
| B3 | Namespace compatibility | `NamespaceKey` lacked model, draft, tokenizer, workload, and runtime-modifier compatibility semantics. |

Non-blocking findings:

| Finding | Area | Summary |
| --- | --- | --- |
| N1 | Component design | `BranchForestIndex` key scope was ambiguous across namespaces. |
| N2 | Component design | `fork_offset` conflicted with the architecture's span model. |
| N3 | Requirement traceability | R83a deduplication was claimed as covered but should be marked partial or deferred. |
| N4 | Requirement traceability | R93 budget traceability did not cover the three byte-budget dimensions. |
| N5 | Implementation steps | Budget integration file list missed the controller boundary. |
| N6 | Test specifications | The concurrency test needed thread count, operation mix, duration, and consistency checks. |
| N7 | Metrics | The lock contention metric needed a measurable definition or replacement counters. |

## Gate decision

Stage 7 design review verdict: REWORK.

Handoff state: design corrections required before implementation planning.
