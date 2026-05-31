# Part 07B: independent design review non-blocking findings

Source: [Part 07](part-07-independent-design-review.md)  
Reviewer: Architect agent  
Date: 2026-05-31  
Verdict: REWORK

## N1: BranchForestIndex key scope ambiguity

Location: `part-02-component-design.md` section 2.2.

The reviewed `BranchForestIndex` used `slot_id` as the key in node and child maps. A slot id is
only unique within a namespace, so the API did not make cross-namespace ownership clear.

Recommendation: add namespace identity to the index or document that callers must select the
correct namespace-scoped index.

## N2: fork_offset vs. the span model

Location: `part-02-component-design.md` section 2.1.

The design used `fork_offset`, while the architecture used `n_tokens`, `pos_min`, and `pos_max`.
Those are different span models.

Recommendation: align with the architecture span fields or document why `fork_offset` is sufficient
for Stage 7.

## N3: R83a traceability is incorrect

Locations:

- `part-01-overview-and-objectives.md` section 1.6
- `part-06-acceptance-criteria.md` section 6.2

The review found that R83a equivalent-branch deduplication was claimed as covered by Stage 7. The
design only provided a common-ancestor query primitive.

Recommendation: mark R83a as partially covered and defer full deduplication to Stage 8.

## N4: R93 budget model mismatch

Location: `part-01-overview-and-objectives.md` section 1.6.

R93 requires budget controls for hot payload RAM, branch metadata RAM, and cold-layer usage. The
reviewed design only described per-namespace slot limits.

Recommendation: add the three byte-budget dimensions or document the deferral.

## N5: Budget integration file list incomplete

Location: `part-03-implementation-steps.md` Step 7.4.

The implementation step referenced `cache_slot.cpp`, but the architecture places budget enforcement
in the cache controller.

Recommendation: add the controller file boundary to the implementation step.

## N6: Concurrency test specification lacks detail

Location: `part-04-test-specifications.md` Test 7.14.

The concurrency test did not specify thread count, operation mix, duration, consistency checks, or
TSAN expectations.

Recommendation:

- use at least 4 threads
- use an operation mix such as add, query, remove, and ref-count update
- run for a fixed duration
- verify node count, parent links, and child links after the run
- run under TSAN where the platform supports it

## N7: Lock contention metric is underspecified

Location: `part-05-metrics-and-observability.md` section 5.1.

The reviewed `cache_branch_forest_lock_contention` ratio did not define how it would be measured.

Recommendation: replace it with acquire and retry counters, or document a measurable formula.

## Traceability assessment

| Architecture deliverable | Reviewed coverage | Status |
| --- | --- | --- |
| Shared `BranchNode` with namespace, token span, usage, residency, protection, and payload refs | Different slot metadata struct | Mismatch |
| Compatibility namespace keying | Trivial `(namespace_id, slot_id)` key | Missing |
| Branch forest with parent-child relationships | Covered | Covered |
| Token and checksum lookup | Not present | Missing |
| Traversal without hot payloads | Not explicit | Missing |
| Multiple slot references without ownership transfer | Ref counting present | Covered |
| Namespace validation before restore | Not present | Missing |
| Shared root preservation | Not addressed | Missing |
| Shared global budget and global eviction | Per-namespace limits | Contradicts |

## Handoff

Design review state: REWORK.

The re-review should check the corrected `BranchNode`, global budget model, compatibility namespace
key, R83a/R93 traceability, and lock metric definition.
