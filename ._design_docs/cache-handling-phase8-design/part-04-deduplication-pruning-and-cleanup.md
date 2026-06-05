# Stage 8 design: metadata-only nodes and re-materialization -- Part 4: deduplication, pruning, and cleanup

Source: [../cache-handling-phase8-design.md](../cache-handling-phase8-design.md)

## Equivalent-branch identity

Two branch nodes are equivalent when all of these fields match:

- namespace ID
- validated token path from namespace root to the node
- `n_tokens`, `pos_min`, and `pos_max`
- token span or checksum span for each segment
- target/draft presence and workload profile expectations
- protection semantics relevant to topology

Payload residency does not decide equivalence. A payload-bearing node and a metadata-only node can represent the same validated path.

## Deduplication rules

Before creating a new node, the controller must search for an equivalent branch in the same namespace.

1. If an equivalent payload-bearing node exists, reuse it.
2. If only equivalent metadata-only nodes exist, reuse the best candidate and re-materialize it when needed.
3. If validation mismatch caused divergence, search only under the selected mismatch parent or root for the new branch path.
4. If two equivalent branches already exist because of earlier behavior, choose one canonical node and leave the other for safe pruning after it has no payload, descendants, or slot refs.

Canonical selection uses deterministic ordering:

1. Payload-bearing before metadata-only.
2. More descendants before fewer descendants.
3. Protected root ancestry before unprotected ancestry.
4. Newer `use_sequence`.
5. Lower `insertion_sequence`.
6. Lower `node_id`.

Deduplication must never merge nodes across namespaces or attach one payload descriptor to multiple branch nodes.

## Branch-metadata budget enforcement

Stage 8 turns branch-metadata budget from diagnostic-only accounting into an enforced pruning input.

Metadata pressure handling:

1. Recalculate total and per-namespace metadata bytes.
2. Prefer payload actions first when the pressured budget is hot payload RAM or cold storage.
3. If metadata RAM remains over budget, build metadata prune candidates from unreferenced metadata-only leaves.
4. Exclude protected roots, namespace roots needed for lookup, active slot refs, and any node with retained descendants.
5. Sort candidates by pruning score.
6. Prune until usage is under budget or no safe candidate remains.
7. If no safe candidate remains, refuse new metadata admission or emit over-budget diagnostics according to the caller's operation.

Pruning score is deterministic:

1. Unprotected before protected.
2. Metadata-only before payload-bearing.
3. Leaf before internal node.
4. Lower reuse value.
5. Older `metadata_last_used_sequence` or `use_sequence`.
6. Higher metadata byte cost.
7. Lower `insertion_sequence`.
8. Lower `node_id`.

Payload-bearing internal nodes are not metadata-prune candidates in Stage 8. The controller may evict their payload first and reconsider them later only if they become safe metadata-only leaves.

## Cold cleanup safety

Cold cleanup runs when pruning deletes a node or when payload eviction deletes cold bytes.

Cleanup must prove ownership before deletion:

- The descriptor is owned by the node being cleaned.
- No retained branch node references that descriptor ID.
- No retained descendant depends on that descriptor for independent restore.
- Target and draft pair descriptors are cleaned together when both exist.
- Store references are normalized internal handles, never request-derived paths.

If any ownership check fails, cleanup must leave the cold payload in place, emit a diagnostic, and block branch pruning when deletion is required for consistency.

## Transaction boundaries

Operations that change graph topology or descriptor ownership need pre-apply validation and rollback:

- Payload eviction validates references and pair state before deleting bytes or clearing descriptor IDs.
- Re-materialization saves the new payload before flipping `is_metadata_only` to false.
- Branch pruning validates descendants, references, protection, and cleanup before removing indexes.
- Deduplication chooses the canonical node before any caller observes the newly created node.

If rollback cannot restore exact pre-operation state, the design requires a scratch-apply path that commits only after all validation passes.

## Concurrency rules

- Graph mutations hold the forest mutex or an equivalent single-writer guard.
- Slot references block payload eviction and branch pruning for the referenced node.
- Equivalent-branch lookup and admission must be atomic with node creation to prevent duplicate admission under concurrent requests.
- Metrics update after commit. Failed preflight checks emit failure counters but must not report committed lifecycle events.
