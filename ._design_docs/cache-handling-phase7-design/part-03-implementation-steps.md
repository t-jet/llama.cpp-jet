# Stage 7 Design: Branch Graph Foundation -- Part 3: Implementation Steps

## Step 7.1: Create server-cache-graph.h with BranchNode and NamespaceKey

**Files**: `tools/server/server-cache-graph.h` (new)

**Description**: Define `branch_node` struct, `namespace_key` struct with `compute()` method, and `validate_namespace_compatibility()` function.

**Details**:
- `branch_node` with all fields from Section 2.1
- `namespace_key` with all fields from Section 2.3
- `namespace_key::compute()` produces a deterministic SHA-256-like string hash
- `validate_namespace_compatibility()` performs strict string equality
- `metadata_ram_bytes()` helper for budget accounting
- Exact `token_span` storage and rolling `prefix_checksums` for lookup
- Atomic `slot_ref_count` for concurrent slot access

**Test expectations**: Unit tests verify struct layout, hash computation, and equality checks.

**Dependencies**: None (new file).

## Step 7.2: Create server-cache-graph.cpp with BranchForestIndex

**Files**: `tools/server/server-cache-graph.cpp` (new)

**Description**: Implement `BranchForestIndex` class with node lifecycle, lookup, traversal, namespace management, budget accounting, and slot reference management.

**Details**:
- `create_node()`: Allocate node_id, insert into `nodes_`, update `children_` and `namespace_roots_`
- `remove_node()`: Explicit teardown/test helper. Remove from `nodes_`, `children_`, `namespace_roots_`. Fail if `slot_ref_count > 0` or the node has retained children.
- `find_nodes_by_token_span()`: Linear scan over namespace nodes, compare the requested prefix to `token_span`, return all matching candidates
- `find_nodes_by_checksum_span()`: Linear scan over namespace nodes, compare the length-qualified checksum to `prefix_checksums[match_tokens - 1]`
- `get_children()`: O(1) lookup from `children_` map
- `get_path_to_root()`: Walk parent chain to root
- `get_descendants()`: BFS from node_id
- `acquire_slot_ref()` / `release_slot_ref()`: Atomic increment/decrement
- `payload_eviction_candidates()`: Collect unreferenced payload-bearing nodes across all namespaces, sort unprotected payloads by `use_sequence` first, then protected-root payloads by `use_sequence`
- `total_metadata_ram_bytes()`: Sum of `metadata_ram_bytes()` across all nodes

**Test expectations**: Unit tests for all public methods. Concurrency tests for slot ref counting.

**Dependencies**: Step 7.1.

## Step 7.3: Integrate BranchForestIndex into hybrid_cache_controller

**Files**: `tools/server/server-cache-hybrid.h`, `tools/server/server-cache-hybrid.cpp`

**Description**: Replace the flat `std::list<hybrid_cache_entry>` with `BranchForestIndex`. Route save/load operations through the forest.

**Details**:
- Add `branch_forest_index forest_` member to `hybrid_cache_controller`
- `save_slot()`: Create or find a `BranchNode` in the forest, acquire slot reference, store payload descriptor reference
- `load_slot()`: Look up branch node by token/checksum span, validate namespace, acquire slot reference, restore from payload
- `find_exact_match()`: Replaced by `forest_.find_nodes_by_token_span()`
- Eviction: Use `forest_.payload_eviction_candidates()` instead of scanning a flat list
- Protected root tracking: Use `branch_node::protected_root` instead of `hybrid_cache_entry::protected_root`
- Slot release: Call `forest_.release_slot_ref()` when slot is done with a node

**Test expectations**: Existing save/load tests pass with forest-backed implementation. No regression in hit rates.

**Dependencies**: Step 7.2.

## Step 7.4: Add Branch-Metadata RAM Budget Dimension

**Files**: `tools/server/server-cache-controller.h`, `tools/server/server-cache-hybrid.h`, `tools/server/server-cache-hybrid.cpp`

**Description**: Add internal branch-metadata RAM accounting to the cache controller. Keep metadata-budget enforcement observable but non-pruning in Stage 7.

**Details**:
- Add `size_t branch_metadata_ram_soft_max` to the cache controller's internal/test configuration. Do not add a public CLI flag in Stage 7.
- In the eviction path (in `server-cache-hybrid.cpp`), after hot payload eviction, check `forest_.total_metadata_ram_bytes()` against `branch_metadata_ram_soft_max`.
- If metadata usage exceeds the soft limit, update metrics and emit diagnostics with current bytes, soft max, and the largest contributing namespaces.
- Do not evict, prune, reparent, or orphan branch graph nodes to satisfy metadata pressure in Stage 7.
- Keep global hot payload eviction active across all namespaces. Payload eviction may clear or demote payload bytes, but it must leave graph metadata and topology intact.
- Keep protected-root payloads in the hot-payload accounting path. The controller skips them while unprotected payloads can satisfy the budget, then demotes or evicts protected-root payloads with explicit diagnostics if protected payload bytes would otherwise keep the cache over budget.
- Budget enforcement lives in the cache controller layer, not in `cache_slot.cpp`. The controller owns the budget and the forest; slots interact with the controller, not directly with budget limits.

**Test expectations**: Unit tests verify metadata accounting and over-budget diagnostics. Integration tests verify that hot payload eviction is global across namespaces and that metadata pressure does not remove or reparent graph nodes.

**Dependencies**: Step 7.3.

## Step 7.5: Add Namespace Validation Before Restore

**Files**: `tools/server/server-cache-hybrid.cpp`

**Description**: Call `validate_namespace_compatibility()` before any restore operation. Reject restore on mismatch.

**Details**:
- In `load_slot()`, after finding candidate nodes, validate each candidate's namespace against the slot's current namespace
- On mismatch: log warning, skip candidate, try next candidate
- If no candidates pass validation: return cache miss (fall through to full decode)
- Add metric for namespace validation failures

**Test expectations**: Unit tests verify that cross-namespace restore is rejected. Integration tests verify same-namespace restore succeeds.

**Dependencies**: Step 7.1, Step 7.3.

## Step 7.6: Add Multi-Slot Reference Tracking

**Files**: `tools/server/server-cache-hybrid.cpp`, `tools/server/server-cache-graph.cpp`

**Description**: Ensure slot reference counting works correctly across concurrent slot operations.

**Details**:
- Slot save: acquire reference on the created/found node
- Slot load: acquire reference on the matched node
- Slot release (slot reset, slot overwrite): release reference on previously held node
- Slot destruction: release all held references
- Verify that a node with multiple slot references is not eligible for payload eviction or graph removal
- Verify that releasing the last reference makes the node eligible for payload eviction

**Test expectations**: Multi-threaded tests verify concurrent acquire/release correctness. Tests verify that nodes with active refs survive payload eviction cycles.

**Dependencies**: Step 7.2, Step 7.3.

## Step 7.7: Add Shared Root Preservation

**Files**: `tools/server/server-cache-graph.cpp`, `tools/server/server-cache-hybrid.cpp`

**Description**: Ensure protected root nodes are never removed from the forest, while their payloads remain lower-priority eviction candidates under protected-over-budget pressure.

**Details**:
- `payload_eviction_candidates()` returns unprotected, unreferenced payloads first and protected-root, unreferenced payloads after them
- Under ordinary pressure, demote or evict unprotected payloads before protected-root payloads
- If the budget cannot be satisfied by unprotected payloads, demote or evict protected-root payloads oldest first and emit protected-over-budget diagnostics
- Reject admission for a new protected-root payload that individually exceeds the configured hot payload budget, matching Stage 4 behavior
- When a descendant payload is evicted or demoted, its protected root ancestor remains in the graph
- Root preservation is independent of payload eviction: root metadata and topology remain, while the root payload may be hot, cold, or evicted according to the payload residency policy
- Add metrics for protected root count and protected-root payload decisions

**Test expectations**: Tests verify that protected root graph nodes survive payload eviction cycles. Tests verify that unprotected payloads are selected before protected-root payloads, and that protected-root payloads are demoted or evicted when protected bytes alone exceed the hot payload budget.

**Dependencies**: Step 7.2.

## Step 7.8: Add Multi-Namespace Concurrent Operation

**Files**: `tools/server/server-cache-graph.cpp`, `tools/server/server-cache-hybrid.cpp`

**Description**: Verify that multiple namespaces can coexist in the same forest, sharing budgets without cross-namespace restore.

**Details**:
- `BranchForestIndex` already supports multiple namespaces via `namespace_id` field
- `find_nodes_by_token_span()` filters by namespace_id
- Eviction candidates are global across all namespaces
- Namespace validation prevents cross-namespace restore
- Add metrics for per-namespace node count and metadata RAM

**Test expectations**: Tests create nodes in multiple namespaces, verify correct isolation, verify global hot-payload eviction across namespaces.

**Dependencies**: Step 7.2, Step 7.5.

## Step 7.9: Update CMakeLists.txt

**Files**: `tools/server/CMakeLists.txt`

**Description**: Add `server-cache-graph.cpp` to the build.

**Details**:
- Add `server-cache-graph.cpp` to the server source file list
- Ensure `server-cache-graph.h` is in the include path

**Test expectations**: Build succeeds. All existing tests pass.

**Dependencies**: Step 7.1, Step 7.2.

## Implementation Order and Dependencies

```
Step 7.1 (header) --> Step 7.2 (forest impl) --> Step 7.3 (hybrid integration)
                                                      |
                                                      +--> Step 7.4 (budget)
                                                      +--> Step 7.5 (validation)
                                                      +--> Step 7.6 (slot refs)
                                                      +--> Step 7.7 (roots)
                                                      +--> Step 7.8 (multi-ns)
                                                      +--> Step 7.9 (build)
```

Steps 7.4-7.8 can be implemented in parallel after Step 7.3 is complete. Step 7.9 must be last.
