# Phase 4 Design: LRU Eviction Policy with Protected Roots - Part 6: Review gate and handoff

Source: [../cache-handling-phase4-design.md](../cache-handling-phase4-design.md)

## Design decisions

- Use `--cache-ram` as the hot payload RAM budget for Phase 4.
- Keep eviction policy selection internal while LRU is the only implemented policy.
- Treat protected roots as higher-priority eviction candidates, not pinned memory.
- Evict unprotected entries before protected entries.
- Evict protected entries when protected payload bytes alone exceed the budget.
- Reject a newly saved entry that individually exceeds the configured budget.
- Keep branch pruning, cold demotion, and metadata-only retention out of Phase 4.
- Use deterministic recency for tests.

## Findings and manager dispositions

### Finding 1: CLI policy selection is deferred

Requirements R20a and R20b call for an explicit eviction-policy CLI and policy-specific parameters. The Stage 4 architecture says to keep policy selection internal while LRU is the only implemented policy and defer `--cache-eviction-policy` until another policy exists.

Manager disposition: accepted for the Stage 4 design gate. Phase 4 follows the Stage 4 architecture source, which deliberately defers `--cache-eviction-policy` until a second policy exists.

Implementation requirement: document the deferral in implementation notes and keep the policy interface pluggable so the CLI can be added later without reworking restore behavior.

### Finding 2: Earlier documents blur LRU scaffolding with Stage 4 acceptance

Phase 3 documents and implementation notes mention LRU indexes and protected-root flags. Those pieces are useful, but Stage 4 acceptance requires resident-byte policy semantics, protected-root budget behavior, diagnostics, and the new metrics.

Manager disposition: accepted for the Stage 4 design gate. Do not count Phase 3 LRU scaffolding as Phase 4 completion unless implementation review verifies all Phase 4 requirements in this design.

Implementation requirement: Phase 4 implementation docs must list which existing pieces were reused and which Stage 4 behaviors were added or changed.

## Acceptance criteria

Phase 4 design is implementable when:

- scope, prerequisites, assumptions, interfaces, constraints, observability, and testability are documented
- protected-root budget behavior is explicit for normal pressure, over-budget protected roots, single-entry oversize, and unlimited budget
- metrics and stats fields are named
- requirement traceability is recorded
- findings are closed or accepted by the manager

Phase 4 implementation is acceptable when:

- LRU eviction is usage-aware and deterministic in tests
- eviction uses resident payload bytes
- target and draft payloads are evicted together
- protected roots survive ordinary pressure but do not bypass the budget
- protected-root over-budget cases emit warnings and metrics
- `--cache-ram` limits are enforced in hybrid mode
- legacy cache behavior remains unchanged
- policy code is isolated enough for a later SLRU or 2Q implementation
- tests cover the required cases in Part 5

## Handoff

Status: reviewable design deliverable. The manager accepts Finding 1 as an architecture-driven Stage 4 deferral, so the next required activity is independent design review.

Next owner: architect for independent design review, then manager checklist review.

Implementation must not add `--cache-eviction-policy` in Phase 4 unless the manager or architect updates the architecture source first. It should preserve the option to add that CLI later.
