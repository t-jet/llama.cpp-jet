# Phase 4 Design: LRU Eviction Policy with Protected Roots - Part 5: Testability and requirement traceability

Source: [../cache-handling-phase4-design.md](../cache-handling-phase4-design.md)

## Test strategy

Phase 4 needs isolated policy tests and hybrid-controller integration tests.

Policy tests should use synthetic candidates. They should not require a live model context.

Controller tests should verify that the controller:

- computes resident payload bytes correctly
- keeps target and draft payloads as one eviction unit
- refreshes recency only after successful restore
- executes policy eviction plans without leaving stale index entries
- reports stats and metrics consistently

## Required cases

LRU ordering:

- oldest unprotected entry is evicted first
- restore refreshes recency
- failed restore does not refresh recency
- equivalent-entry refresh updates recency without duplicating the entry
- deterministic tie-breaking works for equal recency inputs

Byte accounting:

- eviction uses serialized target plus draft bytes
- an entry larger than `--cache-ram` is rejected on admission
- unlimited budget records usage but does not evict
- budget pressure after insertion evicts enough entries to fit

Protected roots:

- protected entries survive while unprotected candidates can satisfy the budget
- protected entries count against the budget
- protected entries are evicted when protected bytes exceed the budget
- diagnostics are emitted when protected roots exceed the budget
- protected admission rejection increments the protected-root decision counter

Metrics:

- payload eviction counter increments once per evicted entry
- protected-root decision counter increments for skip, pressure, evict, and reject paths
- JSON stats expose resident payload bytes and protected byte totals
- Prometheus export includes the new counters when metrics are enabled

## Determinism

Tests should not depend on wall-clock sleeps. Use a monotonic use sequence, an injected clock, or another deterministic recency source.

When two entries have the same recency key, tie-breaking must be stable. The preferred tie-breaker is insertion sequence, then entry id. The exact rule can vary, but it must be documented in implementation notes and covered by tests.

## Requirement traceability

| Requirement | Phase 4 coverage |
| --- | --- |
| R1-R4, R107-R111 | Hybrid mode remains opt-in; legacy cache behavior is unchanged. |
| R9-R10 | Target and draft payloads are one eviction unit. |
| R15-R17 | Non-destructive hits still refresh usage and keep exact restore available. |
| R18-R19 | FIFO behavior is replaced by LRU in hybrid mode. |
| R20 | Controller-policy boundary allows later policies without changing restore correctness. |
| R20a | Deferred in Phase 4 by architecture instruction; recorded as an open design exception. |
| R20b | Deferred until policy selection or policy-specific tuning exists. `--cache-ram` remains the active budget parameter. |
| R21-R22 | Eviction decisions use resident payload bytes and usage recency. |
| R23-R26 | Protected roots have retention priority, count against budgets, and warn when over budget. |
| R34-R36 | Eviction-induced misses use safe fallback; restore failures do not refresh usage. |
| R57-R60 | Phase 4 covers hot payload RAM budget and protection semantics; cold and metadata budgets remain later-stage work. |
| R61, R66-R68 | Payload eviction and protected-root decisions are observable. Restore failure metrics remain from earlier phases. |
| R79 | Protected state is modeled at cache-entry level until first-class branch nodes exist. |
| R90-R92 | Correctness and explicit failure behavior take priority over hit rate. |
| R93-R98 | Hot payload budget is measurable; broader benchmark dimensions remain later-stage work. |
| R99-R100, R125-R129 | Policy and protected-root behavior are testable in isolation and through integration tests. |
| R112-R119, R130-R131 | Policy, storage, restore, and metrics responsibilities stay separated. |
| R120-R124 | Budget pressure and restore failures are explicit and deterministic where feasible. |

## Coverage target

New or materially changed hybrid cache policy code must meet the project target of at least 80 percent line coverage. Tests should cover the behavior listed above even if line coverage is already higher.

