# Phase 5 design: payload-metadata separation and target/draft pairing - Part 1: Scope, prerequisites, and assumptions

Source: [../cache-handling-phase5-design.md](../cache-handling-phase5-design.md)

## Objective

Stage 5 turns serialized cache payloads into objects described by explicit metadata. The descriptor is the durable in-memory contract used by later stages for hot/cold residency, branch graph references, and integrity checks.

The second objective is pairing enforcement. If a cache object was created for a target-plus-draft runtime, all operations treat target and draft payloads as one unit. A restore, eviction, descriptor update, or future demotion must not split the pair.

## Prerequisites

- Stage 1 through Stage 4 design and implementation entries exist in [document-index.md](../document-index.md).
- Stage 4 is closed in [Phase 4 implementation Part 9](../cache-handling-phase4-implementation/part-09-stage-closure-decision.md).
- Hybrid mode already has exact blob save/restore behavior, non-destructive hits, deterministic usage tracking, byte-accounted LRU, and protected-root policy behavior.
- The default legacy cache path remains unchanged when hybrid mode is disabled.
- The Stage 4 hot payload budget uses serialized target plus draft bytes as one eviction unit.

## In scope

- Define first-class payload descriptors for exact full-state blobs.
- Keep serialized payload bytes in a separate payload record or store object, even while the only resident store is hot RAM.
- Record descriptor fields needed by later checkpoint and cold-layer stages without implementing those later stages.
- Enforce target-only and target-plus-draft pair state on save, restore, validation, and eviction.
- Add validation and diagnostics for descriptor version, checksum, byte size, residency state, and target/draft consistency.
- Keep policy, descriptor ownership, payload bytes, validation, and restore application in separate responsibilities.

## Out of scope

- Filesystem cold storage.
- Asynchronous promotion or demotion.
- Checkpoint payload admission as first-class branch nodes.
- Branch graph topology, metadata-only nodes, re-materialization, and branch pruning.
- New cache CLI flags.
- An implementation plan or code changes.

## Assumptions

- Phase 5 works against the current hybrid exact-blob cache entries, not the future branch graph.
- A descriptor may contain future-ready fields such as `payload_kind`, `store_ref`, and `residency_state`, but Stage 5 only admits hot exact-blob payloads.
- Checkpoint payload descriptors use the same schema later, but Stage 5 does not need checkpoint save or restore behavior.
- Draft state is optional only when the active runtime has no draft context. If a runtime has a draft context, the descriptor must require draft payload bytes.
- Descriptor checks run before any live slot state is mutated.
- Restore recency continues to update only after the full target/draft restore succeeds.

## Stage boundary

Stage 5 is a structural correctness stage. It should not change cache hit selection, protected-root ranking, LRU ordering, prompt boundary behavior, or the operator CLI surface. Any implementation later derived from this design must keep those behavior changes out unless a separate approved design updates the boundary.
