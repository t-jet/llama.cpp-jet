# Stage 7 Design: Branch Graph Foundation -- Part 2: Component Design

## 2.1 BranchNode Data Structure

The `BranchNode` replaces the flat `hybrid_cache_entry` as the primary cache object. It is defined in a new header `server-cache-graph.h`. The struct matches the architecture's C4 Code View class diagram (see `cache-handling-architecture/part-01-method.md`).

```cpp
struct branch_node {
    // Identity
    uint64_t node_id;                          // Unique within forest
    std::string namespace_id;                  // Compatibility namespace key
    uint64_t parent_id;                        // 0 = root node

    // Token span (replaces fork_offset with architecture's span model)
    int64_t n_tokens;                          // Number of tokens in this node's span
    int64_t pos_min;                           // Minimum KV position
    int64_t pos_max;                           // Maximum KV position
    std::vector<llama_token> token_span;        // Exact token sequence for this node

    // Checksum span (from boundary metadata)
    uint64_t token_checksum;                   // Rolling checksum of token sequence
    std::vector<uint64_t> prefix_checksums;     // prefix_checksums[i] covers token_span[0..i]

    // Usage tracking (architecture's single `usage` field)
    uint64_t use_sequence;                     // LRU recency key (global sequence)
    uint64_t use_count;                        // Number of times used
    uint64_t insertion_sequence;               // Stable tie-breaker

    // Residency state
    enum class residency { hot, cold, evicted };
    residency residency_state;                 // Current payload residency

    // Protection
    bool protected_root;                       // Protects graph topology; raises payload retention priority

    // Metadata-only flag (always false in Stage 7; forward compat with Stage 8)
    bool is_metadata_only;

    // Payload references (architecture's exact_blob_ref and checkpoint_ref)
    uint64_t exact_blob_payload_id;            // Payload descriptor ID (0 = none)
    uint64_t checkpoint_payload_id;            // Checkpoint descriptor ID (0 = none)

    // Budget accounting
    size_t resident_payload_bytes;             // Cached from descriptor for policy sorting
    bool has_target_payload;
    bool has_draft_payload;

    // Slot reference count (transient, not ownership)
    std::atomic<uint32_t> slot_ref_count;

    branch_node() : slot_ref_count(0), residency_state(residency::hot) {}

    size_t metadata_ram_bytes() const {
        size_t sz = sizeof(branch_node);
        sz += namespace_id.size();
        sz += token_span.capacity() * sizeof(llama_token);
        sz += prefix_checksums.capacity() * sizeof(uint64_t);
        return sz;
    }
};
```

Key design decisions:
- `slot_ref_count` is atomic for safe concurrent slot operations. It tracks how many slots currently reference this node. A node with ref_count > 0 cannot be removed from the forest or selected for payload eviction. This is a valid addition justified by Stage 7 requirements (R80-R83) -- the architecture's BranchNode class diagram does not include it because slot-level reference counting is a Stage 7 implementation detail, not an architectural invariant.
- `protected_root` protects root graph metadata and parent-child topology from graph removal. It is not a hot-payload pin: protected root payload bytes still count against `hot_payload_ram_max` and remain eligible for demotion or eviction after lower-priority candidates are exhausted.
- `is_metadata_only` is defined but always false in Stage 7. The field exists to maintain forward compatibility with Stage 8.
- `exact_blob_payload_id` and `checkpoint_payload_id` reference `payload_descriptor` objects in the existing hot payload store (Stages 1-5). Stage 7 does not introduce a new payload store.
- `metadata_ram_bytes()` enables per-node branch-metadata RAM accounting for the shared-budget model (R8, R93).
- Token span is represented by `n_tokens`, `pos_min`, `pos_max`, and the exact `token_span` vector. The vector is the Stage 7 lookup source of truth. It lets the controller answer prefix-token queries without loading hot payload bytes or reconstructing tokens from descriptors.
- `token_checksum` stores the checksum for the full `token_span`. `prefix_checksums` stores rolling prefix checksums so checksum lookup can validate a requested prefix length without comparing every token first.
- Fields deliberately absent from the architecture's class diagram and not included: `fork_offset` (replaced by span model), `generation`, `subtree_size`, `created_at`, `last_used` (usage tracking uses `use_sequence`/`use_count`/`insertion_sequence`).

## 2.2 BranchForestIndex

The `BranchForestIndex` manages the shared forest of `BranchNode` objects. It is defined in `server-cache-graph.h` alongside `branch_node`.

```cpp
class branch_forest_index {
public:
    branch_forest_index();

    // Node lifecycle
    uint64_t create_node(const std::string & namespace_id,
                         uint64_t parent_id,
                         const std::vector<llama_token> & tokens,
                         int64_t pos_min, int64_t pos_max,
                         uint64_t token_checksum,
                         bool protected_root);
    bool remove_node(uint64_t node_id);
    branch_node * get_node(uint64_t node_id);
    const branch_node * get_node(uint64_t node_id) const;

    // Lookup
    std::vector<uint64_t> find_nodes_by_token_span(
        const std::string & namespace_id,
        const std::vector<llama_token> & prefix,
        size_t min_match_tokens) const;
    std::vector<uint64_t> find_nodes_by_checksum_span(
        const std::string & namespace_id,
        uint64_t checksum,
        size_t match_tokens) const;

    // Traversal
    std::vector<uint64_t> get_children(uint64_t node_id) const;
    uint64_t get_parent(uint64_t node_id) const;
    std::vector<uint64_t> get_path_to_root(uint64_t node_id) const;
    std::vector<uint64_t> get_descendants(uint64_t node_id) const;

    // Namespace management
    std::vector<std::string> get_namespaces() const;
    size_t namespace_node_count(const std::string & namespace_id) const;
    std::vector<uint64_t> namespace_roots(const std::string & namespace_id) const;

    // Budget accounting
    size_t total_metadata_ram_bytes() const;
    size_t namespace_metadata_ram_bytes(const std::string & namespace_id) const;

    // Slot reference management
    bool acquire_slot_ref(uint64_t node_id);
    bool release_slot_ref(uint64_t node_id);
    uint32_t slot_ref_count(uint64_t node_id) const;

    // Payload eviction support. Returns unreferenced payload-bearing nodes ordered
    // by retention class, then LRU recency: unprotected first, protected roots last.
    std::vector<uint64_t> payload_eviction_candidates(size_t max_count) const;
    bool is_protected(uint64_t node_id) const;

    // Iteration
    size_t size() const;

private:
    std::unordered_map<uint64_t, branch_node> nodes_;
    std::unordered_map<uint64_t, std::vector<uint64_t>> children_;  // parent_id -> child_ids
    std::unordered_map<std::string, std::vector<uint64_t>> namespace_roots_; // ns -> root node_ids
    std::atomic<uint64_t> next_node_id_;
    mutable std::mutex mutex_;
};
```

Key design decisions:
- `children_` map enables O(1) child lookup for traversal without scanning all nodes.
- `namespace_roots_` tracks root nodes (parent_id == 0) per namespace for fast root preservation.
- `next_node_id_` is a monotonically increasing atomic counter. Node IDs are never reused within a session.
- `mutex_` protects all mutable state. The forest is a shared resource accessed by all slots.
- `remove_node()` is not a budget-enforcement primitive in Stage 7. It is limited to explicit teardown and tests, and it fails if the node has active slot references or retained children.
- `find_nodes_by_token_span` compares the requested prefix against each candidate's `token_span`. A node matches when `token_span` starts with `prefix` and `prefix.size() >= min_match_tokens`.
- `find_nodes_by_checksum_span` compares `checksum` against `prefix_checksums[match_tokens - 1]` for candidates with at least `match_tokens` tokens. The checksum API is length-qualified; callers must pass the number of tokens represented by the checksum.
- Both lookup methods return all matching nodes, not just the longest. The caller selects the best match. This supports future deduplication in Stage 8 without implementing deduplication in Stage 7.
- **Namespace scope**: `BranchForestIndex` is a single shared forest instance that holds nodes from all namespaces. Each node carries its own `namespace_id`. Lookup methods (`find_nodes_by_token_span`, `find_nodes_by_checksum_span`) accept a `namespace_id` parameter to scope the search. The caller is responsible for passing the correct namespace. This design avoids per-namespace index instances and enables global eviction across all namespaces from a single forest.

## 2.3 NamespaceKey

The `NamespaceKey` extends the existing `cache_compatibility_key` from `server-cache-hybrid.h` with a formal `compute()` method and validation logic. It is defined in `server-cache-graph.h`.

```cpp
struct namespace_key {
    // Model identity
    std::string model_path_hash;
    std::string model_params_hash;

    // Draft model
    std::string draft_context_mode;   // none, separate, target_mtp, separate_model_mtp
    std::string draft_model_hash;

    // Tokenizer and template
    std::string tokenizer_id;
    std::string template_id;

    // Active modifiers
    std::vector<std::string> lora_adapters;
    std::vector<std::string> control_vectors;

    // Multimodal configuration
    std::string mm_projector_id;
    int mm_patch_size;
    bool mm_use_dynamic_tokens;

    // Context and KV configuration
    int n_ctx;
    int n_batch;
    bool kv_unified;

    // Workload profile
    std::string workload_profile;

    std::string compute() const;
    static bool is_compatible(const std::string & ns_a, const std::string & ns_b);
};
```

The `compute()` method produces a deterministic string hash from all components. The `is_compatible()` static method compares two namespace strings for exact equality. In Stage 7, compatibility is strict equality -- no fuzzy matching or version tolerance.

## 2.4 Compatibility Validator

A standalone validation function that checks namespace compatibility before restore:

```cpp
// Returns true if the slot's current namespace matches the branch node's namespace.
// Called before any restore operation.
bool validate_namespace_compatibility(
    const std::string & slot_namespace,
    const std::string & branch_namespace);
```

In Stage 7, this is a simple string equality check. Future stages may add fuzzy matching or version-range tolerance.

## 2.5 Shared-Budget Model

The budget model extends the existing three-part budget from the architecture (hot payload RAM, cold-layer storage) with a third dimension: branch-metadata RAM. This matches the architecture's "Multi-Namespace Operation" section in `cache-handling-architecture/part-02-restore-and-residency-flow.md` and satisfies R93.

```cpp
struct cache_budget {
    size_t hot_payload_ram_max;       // Max bytes for hot payloads (existing, --cache-ram)
    size_t branch_metadata_ram_soft_max; // Internal/test-only metadata pressure threshold
    size_t cold_storage_max;          // Max bytes for cold layer (existing)
};
```

Budget enforcement rules:
- All namespaces share the same three-part budget pool. No per-namespace quotas or reservations.
- Branch-metadata RAM is tracked by `branch_forest_index::total_metadata_ram_bytes()`.
- Stage 7 does not add a public metadata-budget CLI flag. The architecture keeps public metadata-budget flags deferred; Stage 7 uses an internal/test-only `branch_metadata_ram_soft_max` setting so tests can exercise accounting and diagnostics without committing an operator-facing option.
- When branch-metadata RAM exceeds the internal soft limit, Stage 7 records over-budget diagnostics and metrics but does not prune, reparent, or delete branch graph nodes.
- Hot payload RAM enforcement remains global: a namespace with many hot payloads may trigger payload eviction or cold demotion for nodes from other namespaces according to the existing payload LRU policy.
- Protected root payload bytes are included in hot payload RAM accounting. The policy skips protected-root payloads while unprotected payload candidates can satisfy the budget, but protected-root payloads are still eligible if the cache remains over budget after all lower-priority candidates have been demoted or evicted.
- This replaces the earlier per-namespace slot-limit model (`NamespaceBudget` with per-namespace `max_slots`), which contradicted the architecture's shared-budget requirement.
- Payload eviction and branch node pruning are independent events. Stage 7 may evict or demote payload bytes while the node itself remains in the forest (R38a-R38c).
- Branch-metadata budget enforcement that removes metadata is deferred to Stage 8, where metadata-only retention, safe pruning, descendant reachability, and cold cleanup contracts are designed together.
- A node with active slot references (`slot_ref_count > 0`) is not eligible for graph removal.
- Protected roots are not eligible for graph removal. This graph protection does not remove their payload bytes from hot-payload budget accounting.

## 2.6 Slot Reference Model

Slots hold transient references to branch nodes. The reference model is:

- When a slot saves a prompt, it creates or finds a `BranchNode` and acquires a slot reference via `acquire_slot_ref()`.
- When a slot loads from a branch node, it acquires a slot reference. The node remains in the forest.
- When a slot finishes with a branch node (slot release or overwrite), it releases the reference via `release_slot_ref()`.
- A node with `slot_ref_count == 0` may become eligible for payload eviction. Graph removal remains limited to explicit teardown and tests in Stage 7.
- Multiple slots can reference the same node simultaneously. Each slot independently acquires and releases its reference.
- Restoring for one slot does not consume the node for others (R81).

## 2.7 Global Eviction Across Namespaces

The hot payload eviction policy operates on the entire forest, not per-namespace. Candidate ordering follows Stage 4 protected-root budget behavior:

1. Collect unreferenced, payload-bearing nodes from every namespace.
2. Partition candidates into unprotected payloads and protected-root payloads.
3. Sort each partition by `use_sequence` (oldest first), then by `insertion_sequence` as a deterministic tie-breaker.
4. Evict or demote unprotected payload bytes first.
5. If the hot payload budget is still exceeded, evict or demote protected-root payload bytes oldest first. Emit protected-over-budget diagnostics before taking this action.
6. Leave `branch_node` metadata, parent-child links, namespace indexes, token spans, and checksum spans intact.
7. If `total_metadata_ram_bytes()` exceeds `branch_metadata_ram_soft_max`, emit metrics and diagnostics only. Stage 7 must not orphan children, reset `parent_id`, delete subtrees, or convert nodes to metadata-only as a response to metadata pressure.

Branch pruning is a Stage 8 lifecycle event. Stage 7 graph removal is limited to explicit controller teardown or test-only lifecycle calls that fail when the node has active slot refs or retained descendants. Production budget pressure must not call `remove_node()`.

## 2.8 Shared Root Preservation

Root nodes (parent_id == 0) with `protected_root == true` are never removed from the forest. Their metadata, token/checksum spans, parent-child topology, namespace membership, and root index entries remain resident even when longer descendants exist. Their payload residency is separate: protected-root payloads have higher retention priority than unprotected payloads, but they are eligible for demotion or eviction when protected bytes would otherwise keep hot payload RAM over budget. The `namespace_roots_` index enables fast root lookup without scanning all nodes.

## 2.9 File Structure

New files:
- `tools/server/server-cache-graph.h` -- BranchNode, BranchForestIndex, NamespaceKey, compatibility validator
- `tools/server/server-cache-graph.cpp` -- Implementation

Modified files:
- `tools/server/server-cache-hybrid.h` -- Integrate BranchForestIndex, replace flat entry list with forest
- `tools/server/server-cache-hybrid.cpp` -- Route save/load through forest
- `tools/server/server-cache-controller.h` -- Add budget dimension for branch-metadata RAM
- `tools/server/CMakeLists.txt` -- Add new source files

## 2.10 Architecture Decision Records

- **ADR-003** (Replace Flat Prompt Ownership with a Shared Branch Forest): Stage 7 implements this ADR. The flat `hybrid_cache_entry` list is replaced by `BranchForestIndex`.
- **ADR-009** (Distinguish Payload Eviction from Branch Pruning): Stage 7 implements the payload-eviction side. Branch pruning is deferred to Stage 8+.
