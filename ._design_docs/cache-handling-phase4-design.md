# Phase 4 Design: LRU Eviction Policy with Protected Roots

Status: Accepted and closed for Stage 4  
Date: May 27, 2026  
Architecture document: [cache-handling-architecture.md](cache-handling-architecture.md)  
Requirements document: [cache-handling-requirements.md](cache-handling-requirements.md)  
Stage definition: [Stage 4: LRU Eviction Policy with Protected Roots](cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md#stage-4-lru-eviction-policy-with-protected-roots)

## Scope

Phase 4 defines the eviction-policy contract for the alternate hybrid cache mode. It turns the LRU and protected-root scaffolding from earlier phases into an explicit byte-accounted policy design.

The design is limited to hot full-state prompt-cache payloads that already exist in the hybrid cache path. It does not introduce cold storage, payload descriptors, first-class branch graph nodes, metadata-only nodes, or checkpoint-first restore behavior. Those remain later-stage work.

## Contents

This document is split into smaller part files. Read the parts in order when reviewing or implementing Phase 4.

- [Part 1: Overview and scope](./cache-handling-phase4-design/part-01-overview-and-scope.md)
- [Part 2: Policy and interfaces](./cache-handling-phase4-design/part-02-policy-and-interfaces.md)
- [Part 3: Protected-root budget behavior](./cache-handling-phase4-design/part-03-protected-root-budget-behavior.md)
- [Part 4: Observability and metrics](./cache-handling-phase4-design/part-04-observability-and-metrics.md)
- [Part 5: Testability and requirement traceability](./cache-handling-phase4-design/part-05-testability-and-requirement-traceability.md)
- [Part 6: Review gate and handoff](./cache-handling-phase4-design/part-06-review-gate-and-handoff.md)
- [Part 7: Independent design review](./cache-handling-phase4-design/part-07-independent-design-review.md)

## Stage gate

Phase 4 passed independent design review on May 27, 2026. Part 6 records the accepted Stage 4 constraint that policy selection stays internal while LRU is the only implemented policy. Part 7 records the independent review verdict and implementation handoff.

Stage 4 is closed against this design. The implementation, review fixes, re-review, and QA evidence are recorded in the Phase 4 implementation log.
