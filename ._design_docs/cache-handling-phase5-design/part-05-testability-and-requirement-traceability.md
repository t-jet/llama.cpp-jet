# Phase 5 design: payload-metadata separation and target/draft pairing - Part 5: Testability and requirement traceability

Source: [../cache-handling-phase5-design.md](../cache-handling-phase5-design.md)

## Test seams

The design requires focused tests that do not depend on full model-backed inference.

Required seams:

- deterministic payload IDs or injectable ID generation
- deterministic use sequences for descriptor creation and validation
- fake hot payload store
- small checksum helper with fixed test vectors
- pairing validator callable without a live slot
- descriptor registry tests independent of LRU policy tests
- restore applier tests that can simulate target success, draft success, commit failure, and partial failure
- live-slot state probes or snapshots that can prove a failed restore leaves the slot in its pre-restore state

Storage-facing code must be abstract enough that Stage 6 can substitute a cold-store test backend without rewriting descriptor validation.

## Required test coverage

Unit tests should cover:

- descriptor creation for target-only exact blobs
- descriptor creation for target-plus-draft exact blobs
- unsupported descriptor version rejection
- checksum mismatch rejection
- size mismatch rejection
- missing target bytes rejection
- missing draft bytes rejection when draft is required
- unexpected draft bytes rejection for target-only descriptors
- runtime pair mismatch rejection
- restore usage refresh only after full pair success
- validation failure before staging leaves live target and draft state untouched
- failed target restore leaves draft unapplied
- failed target restore leaves the live slot in its pre-restore state and reports fallback
- failed draft restore after staged target success makes the full restore fail
- failed draft restore after target apply success leaves the live slot in its pre-restore state
- failed draft restore after target apply success does not report an exact hit, refresh recency, or update usage
- failed draft restore after target apply success emits restore failure and fallback diagnostics or metrics
- transaction commit failure restores the pre-restore state and falls back
- eviction removes target and draft bytes together
- evicted descriptors cannot be restored
- resident byte accounting uses descriptor byte fields

Integration tests should cover:

- legacy mode unchanged
- hybrid exact-blob restore still works after descriptor separation
- Stage 4 LRU and protected-root behavior still use the same resident byte budget
- diagnostics and metrics fire for descriptor and pairing failures
- fallback path runs when descriptor validation rejects a candidate
- fallback path runs when draft apply fails after target apply success, with no half-restored target/draft pair left in the live slot

Coverage evidence should be reported in the implementation phase, not in this design.

## Requirement traceability

| Requirement | Stage 5 design coverage |
| --- | --- |
| R9-R10 | Pairing is enforced for save, transactional restore, eviction, and future offload states. |
| R13 | Target-plus-draft configurations require `target_and_draft` descriptors and a restore transaction that cannot leave a half-restored live slot. |
| R36 | Invalid, unavailable, or partially applied descriptor payloads emit diagnostics and fall back safely. |
| R36a-R36d | Metadata-only path validation and mismatch-parent selection are out of Stage 5 scope and remain Stage 8 branch-graph work. Stage 5 must not make descriptor choices that block those rules later. |
| R37 | Descriptor records are separate from payload bytes. |
| R38 | Descriptor fields prepare for metadata use when payload bytes are not hot; Stage 5 limits this to hot or evicted exact blobs. |
| R38a-R38c | Payload demotion, metadata-only retention, branch pruning, and cold cleanup are deferred. Stage 5 separates descriptor state from payload bytes so later stages can implement those lifecycle rules. |
| R39-R48 | Descriptor fields cover ranking, residency, and payload handles where applicable before the branch graph stage. |
| R39a-R39c | Re-materialization and prompt-segment validation are deferred with metadata-only nodes. Stage 5 validation covers descriptor bytes only. |
| R52 | Future cold offload must preserve the same target/draft pair state. |
| R55 | Integrity failure handling is defined through checksums and reject/fallback behavior. |
| R93-R98 | Hot payload bytes and transition metrics remain measurable; cold transition benchmarking is deferred to Stage 6. |
| R104 | Tests must cover target-plus-draft pairing across descriptor validation, transactional restore failure points, and future hot/cold transitions. |
| R105 | Missing, invalid, or unsupported payload descriptors must fall back safely. |
| R112 | Policy, metadata management, payload storage, and validation responsibilities stay separated. |
| R117 | The design keeps existing slot, prompt-cache, checkpoint, target, draft, and task terminology. |
| R122 | Descriptor schema is versioned and reserved for forward evolution. |
| R127 | Hot payload storage is testable through substitute stores or fixtures. |
| R133 | Descriptor integrity, pairing, and future payload handles are security review items. |

## Stage 5 acceptance checks

The design is reviewable when:

- descriptor fields and ownership rules are explicit
- pair states and runtime compatibility rules are explicit
- save, restore, and eviction behavior all preserve target/draft atomicity
- validation failure behavior is fail-closed and observable
- cold storage, branch graph, checkpoint payloads, and implementation planning are excluded
- requirement traceability is recorded

The later implementation is acceptable only after a separate manager handoff opens implementation work.
