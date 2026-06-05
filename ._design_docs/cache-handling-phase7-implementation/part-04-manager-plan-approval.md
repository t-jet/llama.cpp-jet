# Stage 7 implementation plan - Part 4

Source: [../cache-handling-phase7-implementation.md](../cache-handling-phase7-implementation.md)  
Approval date: May 31, 2026  
Manager decision: ACCEPT IMPLEMENTATION PLAN

## Evidence checked

- Accepted design gate: [Stage 7 design Part 11](../cache-handling-phase7-design/part-11-manager-design-gate.md)
- Implementation plan: [Part 1](part-01-implementation-plan.md) and [Part 2](part-02-evidence-plan-and-risks.md)
- Independent plan review: [Part 3](part-03-independent-plan-review.md), verdict PASS
- Document index: [document-index.md](../document-index.md)

## Decision

The Stage 7 implementation plan is approved. Code implementation is open for the approved branch graph foundation scope.

Implementation must follow the ordered plan in Parts 1 and 2. Each implementation step must record changed files, behavior changes, build commands, focused test commands, results, metrics or diagnostics evidence when applicable, coverage status, and any plan deviation.

## Constraints

- Preserve Stage 4 protected-root payload budget behavior.
- Preserve Stage 5 descriptor validation, target/draft pairing, and transactional restore behavior.
- Preserve Stage 6 cold residency, async I/O, promotion, and demotion contracts.
- Keep metadata pressure diagnostic-only in Stage 7. Do not add branch pruning, metadata-only lifecycle behavior, equivalent-branch deduplication, or checkpoint-first restore.
- Do not advance to implementation review until code, tests, and implementation evidence are aligned.

## Handoff

Gate: Implementation  
Owner: Developer  
Expected deliverable: Stage 7 code, tests, and implementation evidence following the approved plan.
