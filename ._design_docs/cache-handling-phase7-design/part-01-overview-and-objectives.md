# Stage 7 Design: Branch Graph Foundation -- Part 1: Overview and Objectives

## Goal

Build the shared branch forest with compatibility namespaces and multi-slot reuse. After Stage 7, the cache is no longer a flat list of entries. It is a forest of `BranchNode` objects organized by namespace, with parent-child relationships, slot-transient references, and a shared-budget model that accounts for branch-metadata RAM as a separate dimension.

## Scope

- Define `BranchNode` data structure with ID, namespace, parent, token span, checksum span, positions, usage, residency, protection, and payload references
- Implement `NamespaceKey` for compatibility keying: model identity, draft presence, tokenizer semantics, workload profile
- Build `BranchForestIndex` with parent-child relationships and per-namespace topology
- Implement branch lookup by token/checksum spans
- Implement branch traversal without requiring hot payloads
- Allow multiple slots to reference the same branch node without ownership transfer
- Add namespace validation before restore
- Preserve shared roots even when longer descendants exist
- Implement shared-budget model across all namespaces with global eviction
- Support concurrent operation of multiple namespaces (different models or workload profiles)

## Prerequisites from Stages 1-6

- Stage 1: Non-destructive save/load, entries remain in cache after load (R1-R17)
- Stage 2: Namespace keying exists as `cache_compatibility_key` in `server-cache-hybrid.h` (R27-R33)
- Stage 3: Exact blob cache with usage tracking, multi-slot reuse (R34-R56)
- Stage 4: Byte-accounted LRU eviction with protected roots (R57-R68)
- Stage 5: Payload descriptor separation, target/draft pairing, transactional restore (R69-R79)
- Stage 6: Cold payload storage, async I/O worker, demotion/promotion protocols (R38a-R38c, R55a)
- R8: Branch metadata must be resident in RAM even when payloads are cold (deferred from Stage 6)
- R38a-R38c: Payload demotion must not require branch pruning (deferred from Stage 6)

## Non-Goals (Deferred to Stage 8+)

- Metadata-only nodes and re-materialization (Stage 8): Stage 7 nodes always carry payload references. The `is_metadata_only` flag is defined but always false.
- Equivalent-branch deduplication (Stage 8): Stage 7 may create duplicate branches for equivalent token sequences. Convergence is deferred.
- Checkpoint-first restore (Stage 9): Stage 7 only supports exact-blob restore.
- Branch pruning as a distinct lifecycle event (Stage 8+): Stage 7 does not prune, orphan, or reparent graph nodes in response to metadata pressure.
- Re-materialization from nearest payload-bearing ancestor (Stage 8).
- Cold-layer cleanup triggered by pruning (Stage 8+).

## Acceptance Criteria (Summary)

- Branch nodes are first-class reusable objects in a shared forest
- Slots hold transient references, not ownership
- Namespace prevents unsafe cross-model/cross-config restores
- Shared roots are preserved across sessions
- Multiple slots can traverse the same branch structure
- Multiple namespaces can coexist and share budgets without cross-namespace restore
- Global hot-payload LRU eviction works correctly across namespace boundaries
- Branch-metadata RAM is tracked as a separate budget dimension with internal/test-only soft-limit diagnostics (R8, R93)

## Requirement Traceability

| Requirement | Stage 7 Coverage |
|-------------|-----------------|
| R8 (branch metadata resident in RAM) | BranchNode metadata always in RAM; payload may be hot or cold |
| R38a-R38c (payload demotion independent of branch pruning) | Branch graph survives payload demotion; pruning deferred to Stage 8+ |
| R80 (slots reference without ownership) | Slot holds transient node_id reference |
| R81 (restore doesn't consume for others) | Non-destructive: node remains after restore |
| R82 (not one-shot entries) | BranchNode persists across slot lifetimes |
| R83 (multiple slots traverse same graph) | Shared forest with slot-transient refs |
| R83a (converge on equivalent branch) | Partially covered — `find_nodes_by_token_span()` and `find_nodes_by_checksum_span()` provide the query primitives for detecting equivalent branches; full deduplication deferred to Stage 8 |
| R90-R92 (correctness, valid state, explicit failure) | Namespace validation, explicit error paths |
| R93 (configurable budget controls) | Three-part accounting: hot RAM (`--cache-ram`), branch-metadata RAM (internal/test-only soft limit with metrics), cold-layer storage. Global across all namespaces, no per-namespace quotas. The public metadata-budget CLI remains deferred. |
| R99-R107 (testability) | Test hooks, deterministic IDs, injectable policies |
