# Stage 7 Design: Branch Graph Foundation -- Part 4: Test Specifications

## Test File

New test file: `tests/test-step12-branch-graph.cpp`

## Test 7.4.1: BranchNode Creation and Basic Properties

**Type**: Unit

**Description**: Verify that `branch_node` structs are created with correct default values and that `metadata_ram_bytes()` returns a reasonable estimate.

**Scenarios**:
1. Create a default `branch_node`. Verify `node_id == 0`, `slot_ref_count == 0`, `is_metadata_only == false`.
2. Create a node with 10 tokens. Verify `token_span.size() == 10`, `prefix_checksums.size() == 10`, and `metadata_ram_bytes()` includes token and checksum vector capacity.
3. Verify that `exact_blob_payload_id` and `checkpoint_payload_id` default to 0.

## Test 7.4.2: NamespaceKey Computation and Validation

**Type**: Unit

**Description**: Verify that `namespace_key::compute()` produces deterministic hashes and that `validate_namespace_compatibility()` enforces strict equality.

**Scenarios**:
1. Two identical `namespace_key` objects produce identical hash strings.
2. Two `namespace_key` objects differing only in `model_path_hash` produce different hash strings.
3. Two `namespace_key` objects differing only in `draft_context_mode` produce different hash strings.
4. `validate_namespace_compatibility("ns_a", "ns_a")` returns true.
5. `validate_namespace_compatibility("ns_a", "ns_b")` returns false.
6. Empty namespace strings are handled without crash.

## Test 7.4.3: BranchForestIndex Node Lifecycle

**Type**: Unit

**Description**: Verify that `BranchForestIndex` correctly manages node creation, lookup, and removal.

**Scenarios**:
1. Create a root node. Verify `get_node()` returns it. Verify `size() == 1`.
2. Create a child node with `parent_id` pointing to root. Verify `get_children(root_id)` includes child.
3. Remove a leaf node with no slot refs. Verify `size()` decreases.
4. Attempt to remove a node with `slot_ref_count > 0`. Verify it fails.
5. Create nodes in two namespaces. Verify `get_namespaces()` returns both.

## Test 7.4.4: Branch Lookup by Token Span

**Type**: Unit

**Description**: Verify that `find_nodes_by_token_span()` returns correct candidates.

**Scenarios**:
1. Create nodes with token sequences [1,2,3] and [1,2,3,4,5] in the same namespace. Search for prefix [1,2]. Verify both nodes are returned.
2. Search for prefix [1,2,3,4,5,6]. Verify no nodes returned.
3. Search with `min_match_tokens = 3`. Verify only nodes with >= 3 matching prefix tokens are returned.
4. Search in namespace "ns_a" when nodes exist in "ns_b". Verify no results.

## Test 7.4.5: Branch Lookup by Checksum Span

**Type**: Unit

**Description**: Verify that length-qualified `find_nodes_by_checksum_span()` returns correct candidates.

**Scenarios**:
1. Create nodes with rolling prefix checksums. Search with the checksum for a 3-token prefix and `match_tokens = 3`. Verify correct nodes returned.
2. Search with no matching checksums. Verify empty result.
3. Search with the right checksum and wrong `match_tokens`. Verify no false hit.

## Test 7.4.6: Parent-Child Traversal

**Type**: Unit

**Description**: Verify that traversal methods return correct topology.

**Scenarios**:
1. Build a tree: root -> child1 -> grandchild. Verify `get_path_to_root(grandchild)` returns [grandchild, child1, root].
2. Verify `get_children(root)` returns [child1].
3. Verify `get_descendants(root)` returns [child1, grandchild].
4. Attempt to remove a parent with retained descendants. Verify removal fails and the child still reports the original parent.

## Test 7.4.7: Slot Reference Correctness

**Type**: Unit / Concurrency

**Description**: Verify that slot reference counting works correctly, including concurrent access.

**Scenarios**:
1. Create a node. Acquire a slot ref. Verify `slot_ref_count == 1`.
2. Acquire a second slot ref from a different "slot". Verify `slot_ref_count == 2`.
3. Release one ref. Verify `slot_ref_count == 1`.
4. Release the last ref. Verify `slot_ref_count == 0`.
5. Attempt to remove a node with ref_count > 0. Verify failure.
6. After releasing all refs, remove the node. Verify success.
7. **Concurrency**: Spawn N >= 4 threads with operation mix: 30% add, 30% query, 20% remove, 20% ref_count update. Run for at least 5 seconds of continuous concurrent operation. After all threads complete, verify: (a) `nodes_` size matches expected count, (b) no child has a parent not in `nodes_`, (c) no parent in `children_` has a child not in `nodes_`. Run under ThreadSanitizer (TSAN) for data race detection.

## Test 7.4.8: Shared Root Preservation

**Type**: Unit

**Description**: Verify that protected root graph nodes survive payload eviction cycles and that protected-root payloads follow Stage 4 budget behavior.

**Scenarios**:
1. Create a protected root and an unprotected, payload-bearing non-root node. Under ordinary hot RAM pressure, verify the unprotected payload is selected before the protected-root payload.
2. Create a protected root with a long descendant chain. Evict or demote payloads under hot RAM pressure. Verify all graph nodes remain linked to the root.
3. Set hot RAM low enough that unprotected payloads cannot satisfy the budget. Verify the protected-root payload is demoted or evicted with protected-over-budget diagnostics, while the protected root node remains in the graph.
4. Attempt to admit a new protected-root payload that individually exceeds the hot payload budget. Verify admission is rejected or falls back before insertion, and diagnostics include the protected entry size and budget.

## Test 7.4.9: Multi-Slot Reference Correctness

**Type**: Integration

**Description**: Verify that multiple slots can reference the same branch node without ownership transfer.

**Scenarios**:
1. Slot A saves a prompt, creating a branch node. Slot B loads the same prompt (cache hit). Both hold refs.
2. Slot A releases its ref (slot reset). Node remains because Slot B still holds a ref.
3. Slot B loads from the node. Verify correct payload is restored.
4. Slot B releases its ref. Node becomes eligible for payload eviction.

## Test 7.4.10: Namespace Validation Before Restore

**Type**: Integration

**Description**: Verify that namespace validation prevents unsafe cross-model restore.

**Scenarios**:
1. Save a prompt in namespace "model_a". Attempt to restore in namespace "model_b". Verify cache miss.
2. Save a prompt in namespace "model_a". Restore in same namespace. Verify cache hit.
3. Save prompts in two namespaces. Verify each namespace only finds its own nodes.

## Test 7.4.11: Multi-Namespace Concurrent Operation with Shared Budgets

**Type**: Integration

**Description**: Verify that multiple namespaces coexist and share budgets without cross-namespace restore.

**Scenarios**:
1. Create nodes in namespace "ns_a" and "ns_b". Verify `get_namespaces()` returns both.
2. Set hot payload RAM low enough that only some payloads can remain hot. Verify payload eviction selects from both namespaces (global LRU).
3. Set the internal metadata soft max below current usage. Verify diagnostics report over-budget metadata without removing nodes from either namespace.
4. Verify that namespace A cannot restore namespace B's nodes.

## Test 7.4.12: Branch-Metadata RAM Accounting and Soft-Limit Diagnostics

**Type**: Unit / Integration

**Description**: Verify that Stage 7 accounts for branch-metadata RAM and reports soft-limit pressure without pruning graph nodes.

**Scenarios**:
1. Create nodes until `total_metadata_ram_bytes()` exceeds `branch_metadata_ram_soft_max`. Verify metrics and diagnostics report over-budget state.
2. Verify that nodes with active slot refs are not removed under metadata pressure.
3. Verify that protected roots are not removed under metadata pressure.
4. Verify that `metadata_ram_bytes()` accounting is consistent with actual memory usage.
5. Verify that parent-child topology is unchanged after metadata soft-limit checks.

## Test 7.4.13: Global Hot-Payload LRU Eviction Across Namespaces

**Type**: Integration

**Description**: Verify that global hot-payload LRU eviction works correctly across namespace boundaries while graph metadata remains intact.

**Scenarios**:
1. Create hot payloads in namespace "ns_a" (old use_sequence) and "ns_b" (new use_sequence). Evict under hot RAM pressure. Verify "ns_a" payloads are evicted or demoted first.
2. Create hot payloads with interleaved use_sequences across namespaces. Verify eviction order is global, not per-namespace.
3. Add protected-root payloads in both namespaces. Verify unprotected payloads are demoted or evicted before protected-root payloads, then verify protected-root payloads are demoted or evicted oldest first if protected bytes alone exceed the budget.
4. Verify that after payload eviction, all branch nodes and parent-child links remain present.

## Test 7.4.14: Regression: Existing Save/Load Still Works

**Type**: Regression

**Description**: Verify that existing save/load tests pass with the forest-backed implementation.

**Scenarios**:
1. Run all existing Stage 1-6 save/load tests with the new `BranchForestIndex`-backed controller.
2. Verify hit rates are not degraded.
3. Verify non-destructive behavior (entry remains after load).
