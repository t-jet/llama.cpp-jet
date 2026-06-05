# Stage 8 design: metadata-only nodes and re-materialization -- Part 2: interfaces and lifecycle rules

Source: [../cache-handling-phase8-design.md](../cache-handling-phase8-design.md)

## Component changes

Stage 8 extends the Stage 7 branch graph and hybrid controller. It does not add a new top-level subsystem.

| Component | Stage 8 responsibility |
| --- | --- |
| `branch_node` | Treat `is_metadata_only` as live state. Track last topology use, metadata prune eligibility, and payload absence reasons. |
| `branch_forest_index` | Add safe payload eviction, metadata-only retention, branch pruning, equivalent lookup, and deterministic candidate ordering. |
| `server_cache_hybrid_controller` | Request re-materialization plans, apply mismatch decisions, and admit deduplicated nodes. |
| Payload descriptor store | Clear descriptor ownership on payload eviction and verify singular ownership before cold cleanup. |
| Residency policy | Prefer payload demotion or eviction before branch pruning when payload actions can satisfy pressure. |
| Metrics and diagnostics | Report metadata-only transitions, re-materialization, mismatch, deduplication, pruning, and cleanup decisions. |

## Branch node state

Stage 8 keeps the Stage 7 fields and makes these semantics binding:

- `is_metadata_only == false`: the node may own `exact_blob_payload_id`, `checkpoint_payload_id`, or both.
- `is_metadata_only == true`: the node owns no payload descriptor and remains only as graph metadata.
- `residency_state == evicted`: payload bytes and owned descriptors are absent. This can coexist with `is_metadata_only == true`.
- `protected_root == true`: graph metadata cannot be pruned by ordinary budget pressure. Payload bytes remain budgeted and can still be demoted or evicted under the Stage 4 and Stage 7 rules.
- `slot_ref_count > 0`: neither payload eviction nor branch pruning may mutate the node in a way that invalidates the active slot reference.

Implementation may add explicit fields such as `metadata_last_used_sequence`, `metadata_prune_class`, or `payload_absent_reason` if that keeps pruning and diagnostics clear.

## Payload eviction lifecycle

Payload eviction is allowed only for an unreferenced node. It follows this order:

1. Validate that no slot currently references the node.
2. Validate target/draft pair state. If the node owns a paired payload, evict or delete both sides as one operation.
3. Remove hot bytes or cold files through the existing payload store contract.
4. Clear only the payload descriptor references owned by this node.
5. Set `is_metadata_only = true` if the node remains useful for lookup, ranking, traversal, or descendant reachability.
6. Preserve `node_id`, namespace, parent, children, token span, checksum span, usage, protection, and metadata accounting.
7. Emit payload eviction and metadata-only retention metrics separately.

Payload eviction must not call graph removal as a side effect.

## Branch pruning lifecycle

Branch pruning removes metadata, so it has stricter checks:

1. Reject pruning if the node has active slot references.
2. Reject pruning for protected roots unless a later approved stage defines an explicit protected-root removal operation.
3. Reject pruning if removing the node would orphan retained descendants or break lookup/traversal.
4. Allow pruning of a leaf metadata-only node when no retained descendant depends on it.
5. Allow pruning of an internal metadata-only node only when the operation can reparent or remove descendants without changing validated path semantics. Stage 8 does not require internal-node reparenting; the conservative default is to reject it.
6. Before deletion, run cold cleanup ownership checks for any descriptor or store reference exclusively owned by the pruned node.
7. Remove the node from parent-child indexes, namespace indexes, lookup indexes, and metadata byte accounting as one graph transaction.
8. Emit branch pruning metrics. Do not count pruning as payload eviction unless payload bytes are also removed.

## Metadata-only retention rules

A node should be retained as metadata-only when at least one condition is true:

- It has retained descendants.
- It is needed to find the path to a retained descendant.
- It is a namespace root or protected root.
- It is part of the best known branch path for recent lookup or ranking.
- It is needed to reject or explain future mismatch decisions.

A metadata-only node may be pruned only when none of those conditions applies and the pruning transaction passes the lifecycle checks above.

## Budget model

Stage 8 uses three budget dimensions:

- hot payload RAM, controlled by existing hot-payload budget behavior
- branch-metadata RAM, enforced against configured or internal/test budget
- cold-layer storage, enforced by the existing cold store capacity model

Budget pressure order:

1. Demote hot payload bytes to cold if the cold budget can accept them.
2. Evict payload bytes while retaining metadata if that satisfies the pressured budget.
3. Delete cold payload bytes whose owner can safely become metadata-only.
4. Prune metadata-only leaves that are unprotected, unreferenced, and not needed by retained descendants.
5. Refuse admission or emit over-budget diagnostics if only protected or required topology remains.

Stage 8 must not satisfy branch-metadata pressure by deleting topology that is still required for retained descendants.
