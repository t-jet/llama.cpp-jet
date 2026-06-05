# Phase 5 implementation: independent implementation-plan review

Source: [../cache-handling-phase5-implementation.md](../cache-handling-phase5-implementation.md)

## Review scope

Review date: May 27, 2026

Reviewed documents:

- [Phase 5 implementation entry](../cache-handling-phase5-implementation.md)
- [Part 1: Implementation plan](part-01-implementation-plan.md)
- [Phase 5 design entry](../cache-handling-phase5-design.md)
- [Phase 5 design Part 3](../cache-handling-phase5-design/part-03-save-restore-eviction-and-pairing-behavior.md)
- [Phase 5 design Part 4](../cache-handling-phase5-design/part-04-validation-diagnostics-and-observability.md)
- [Phase 5 design Part 5](../cache-handling-phase5-design/part-05-testability-and-requirement-traceability.md)
- [Phase 5 design Part 9](../cache-handling-phase5-design/part-09-independent-design-re-review.md)
- [Phase 4 implementation closure](../cache-handling-phase4-implementation/part-09-stage-closure-decision.md)
- Current cache files: `tools/server/server-cache-hybrid.h`, `tools/server/server-cache-hybrid.cpp`, `tools/server/server-context.cpp`, `tools/server/server-cache-policy-lru.*`, `tests/test-cache-controller.cpp`, and `tools/server/tests/unit/test_cache_modes.py`

This was an implementation-plan review only. No code was changed.

## Verdict

REWORK.

The plan content is close to the approved Phase 5 design. It starts from the current exact-blob baseline, separates descriptor metadata from hot payload bytes, keeps the LRU policy byte-oriented, preserves Stage 4 budget and protected-root behavior, and makes target-plus-draft restore transactional. It also calls out descriptor validation, diagnostics, metrics, failure injection, and evidence expectations.

One blocking gate issue remains. The approved design says implementation planning must wait for manager approval, but the implementation log and Part 1 open implementation planning without a durable manager gate record. This review cannot pass the plan while that prerequisite is missing from the document set.

## Blocking finding

### Finding 1: implementation planning opened without the recorded manager handoff

The Phase 5 design entry says Stage 5 is "ready for manager gate review" and that "implementation planning must wait for manager approval." Design Part 9 also says the implementation handoff is closed until the manager accepts the design gate and explicitly opens implementation planning.

The implementation entry says the plan was opened after independent design re-review passed. Part 1 says Stage 5 is cleared for implementation planning only. Neither file links to a manager gate approval or records the manager handoff that the approved design requires.

This is a sequencing and ownership problem, not a code design problem. Without the manager handoff, the implementation plan may be technically sound but is not yet an approved implementation baseline.

Required correction:

- Add or link the durable manager gate decision that accepts the Phase 5 design and opens implementation planning.
- Update the Phase 5 design entry, design Part 6 or Part 9 if needed, and the implementation entry so all gate-status wording agrees.
- Keep implementation state as blocked for code work until that handoff exists.

Acceptance check:

- A reviewer can start from `document-index.md`, follow the Phase 5 design and implementation entries, and see a single consistent state: manager approved implementation planning, independent implementation-plan review is complete, and code work is either open or blocked with a named reason.

## Plan conformance decisions

No content-level implementation-plan blocker was found.

- Design conformance: Part 1 carries forward the approved descriptor, pair-state, validation, hot-residency, and target-plus-draft transaction rules from design Parts 3, 4, 5, and 9.
- Current baseline: The plan correctly identifies `hybrid_cache_entry::data` as the current payload owner and names `server-context.cpp` as the production save and restore integration point.
- Ordered feasibility: The step order is workable. It introduces descriptor and store types before replacing entry payload ownership, then preserves eviction behavior before refactoring transactional restore.
- Ownership boundaries: The plan keeps policy byte-oriented and assigns descriptor validation, hot-store ownership, pairing validation, and restore application to separate seams.
- Stage 4 preservation: The plan explicitly preserves `--cache-ram` semantics, protected-root priority, equivalent-refresh budget enforcement, payload eviction metrics, and legacy mode behavior.
- Transactional restore: The plan requires pre-live-mutation validation, scratch staging or pre-restore snapshot rollback, no reset-to-empty fallback unless that was the original state, and no hit, usage, or recency update on failed restore.
- Validation and observability: The plan covers descriptor version, kind, residency, owner entry, store ref, size, checksum, pair-state, diagnostics, stats, and Prometheus metrics.
- Tests and failure injection: The plan requires malformed-descriptor tests, pair mismatch tests, save and refresh failure tests, paired eviction tests, restore validation failure tests, target, draft, commit, and rollback failure tests, and server-level regression coverage where unit seams are not enough.
- Evidence: The plan names build and test commands, coverage expectations, and step-by-step implementation log updates.
- Hidden design decisions: The only hidden decision found is the missing manager handoff. Optional choices such as retaining evicted descriptors for diagnostics, checksum helper selection, and restore staging strategy are kept inside the approved design bounds.

## Required corrections

Documentation correction is required before the plan can pass:

- Record or link the manager gate approval that opened Phase 5 implementation planning.
- Align gate wording across the Phase 5 design and implementation entry documents.

No code correction is requested by this review.

## Handoff

State: rework required.

Next owner: manager or architect to record the missing manager handoff and align gate status. After that, this implementation-plan review should be rerun or amended before developer code work starts.
