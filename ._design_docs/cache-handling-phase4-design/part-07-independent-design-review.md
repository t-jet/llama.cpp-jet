# Phase 4 Design: LRU Eviction Policy with Protected Roots - Part 7: Independent design review

Source: [../cache-handling-phase4-design.md](../cache-handling-phase4-design.md)

## Review scope

Review date: May 27, 2026

Reviewed documents:

- [Phase 4 design entry](../cache-handling-phase4-design.md)
- [Part 1: Overview and scope](part-01-overview-and-scope.md)
- [Part 2: Policy and interfaces](part-02-policy-and-interfaces.md)
- [Part 3: Protected-root budget behavior](part-03-protected-root-budget-behavior.md)
- [Part 4: Observability and metrics](part-04-observability-and-metrics.md)
- [Part 5: Testability and requirement traceability](part-05-testability-and-requirement-traceability.md)
- [Part 6: Review gate and handoff](part-06-review-gate-and-handoff.md)
- [Stage 4 architecture source](../cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md)
- [Requirements](../cache-handling-requirements.md), especially R15-R26, R20a, R20b, R57-R68, R99-R100, and R125-R129
- [AGENTS.md](../../AGENTS.md)

This was a design review only. No code was reviewed or changed.

## Verdict

PASS.

The Phase 4 design matches the Stage 4 architecture source. It defines byte-accounted LRU eviction, keeps `--cache-ram` as the hot payload budget, gives protected roots higher retention priority without exempting them from accounting, adds explicit protected-root diagnostics, and keeps the eviction-policy boundary pluggable.

The accepted deferral of `--cache-eviction-policy` is documented in Parts 2, 5, and 6. This review does not treat that deferral as a failure because the design keeps policy selection internal while LRU is the only implemented policy and preserves a controller-policy boundary for later policies.

## Findings

No blocking design findings.

Review decisions:

- Stage 4 scope is correctly limited to hot full-state prompt-cache payloads. Cold storage, descriptor formats, checkpoint payload residency, branch pruning, and metadata-only nodes remain later-stage work.
- The policy/controller split is clear enough for implementation review. The controller owns payload storage, indexes, restore behavior, and stats execution. The policy owns ordering and budget decisions.
- Resident-byte accounting is defined as serialized target plus draft bytes, and target-plus-draft entries are one eviction unit.
- Protected roots are weighted eviction candidates, not pinned memory. The design specifies normal pressure, protected-over-budget pressure, single-entry oversize admission, and unlimited-budget behavior.
- Required Stage 4 metrics are named, with Prometheus compatibility guidance and JSON stats fields.
- Test guidance covers LRU ordering, protected-root pressure, budget enforcement, deterministic recency, metrics, and isolated policy testing.

## Requirement checks

R15-R17: Passed. Non-destructive exact hits remain available, successful restores refresh usage, and failed restores do not refresh recency.

R18-R22: Passed. FIFO is replaced by deterministic LRU in hybrid mode, with resident-byte accounting and a pluggable policy contract.

R20a and R20b: Accepted Stage 4 deferral. The design documents the deferral and keeps the policy interface extensible. `--cache-ram` remains the only active policy-related operator setting for this stage.

R23-R26: Passed. Protection is trusted-server policy, integrated with LRU, counted against budget, and diagnosed when it cannot be preserved.

R57-R60: Passed for Stage 4 scope. The design covers hot payload RAM residency and protected roots. Cold demotion, promotion, branch-metadata budgets, and broader residency policy remain assigned to later stages by the architecture.

R61-R68: Passed for Stage 4 scope. Payload eviction and protected-root decisions are observable. Existing hit, miss, and restore failure metrics remain valid, and later-stage metrics are not pulled into Phase 4.

R99-R100 and R125-R129: Passed. The design requires isolated policy tests, controller integration tests, deterministic recency, protected-root cases, and observable assertions.

AGENTS.md: Passed. The review stays concise, does not write PR text or reviewer responses, does not implement code, and keeps the handoff maintainable.

## Required corrections

None.

Implementation must preserve these review conditions:

- Do not add `--cache-eviction-policy` in Phase 4 unless the architecture source changes first.
- Keep the controller-policy boundary free of LRU-specific controller names so SLRU or 2Q can be added later.
- Treat protected roots as retention-priority entries, not memory pins.
- Reject or evict over-budget protected entries with explicit diagnostics rather than leaving resident bytes over budget.
- Cover deterministic recency and protected-root pressure in tests before implementation sign-off.

## Handoff

State: ready for implementation.

Next owner: developer for Phase 4 implementation planning and code work, followed by implementation review and QA.
