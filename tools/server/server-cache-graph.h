#pragma once

#include "llama.h"

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <unordered_map>
#include <unordered_set>
#include <vector>

// Stage 8: Fallback reason for re-materialization planning
enum class cache_fallback_reason {
    none,
    no_payload_ancestor,
    namespace_mismatch,
    pair_state_mismatch,
    validation_mismatch,
    materialization_failed,
    promotion_failed,
};

// Stage 8: Re-materialization plan result
struct rematerialization_plan {
    uint64_t selected_node_id = 0;
    uint64_t source_payload_node_id = 0;   // 0 means replay from root
    uint64_t materialize_node_id = 0;      // selected node or equivalent target
    uint64_t deepest_validated_node_id = 0;
    uint64_t mismatch_node_id = 0;
    std::vector<uint64_t> path_node_ids;
    size_t validated_tokens = 0;
    bool requires_new_branch = false;
    uint64_t new_branch_parent_id = 0;
    cache_fallback_reason fallback_reason = cache_fallback_reason::none;
};

struct branch_traversal_counts {
    size_t path_to_root = 0;
    size_t descendants = 0;
    size_t children = 0;
};

struct branch_node {
    uint64_t node_id = 0;
    std::string namespace_id;
    uint64_t parent_id = 0;

    int64_t n_tokens = 0;
    int64_t pos_min = 0;
    int64_t pos_max = 0;
    std::vector<llama_token> token_span;

    uint64_t token_checksum = 0;
    std::vector<uint64_t> prefix_checksums;

    uint64_t use_sequence = 0;
    uint64_t use_count = 0;
    uint64_t insertion_sequence = 0;

    enum class residency {
        hot,
        cold,
        evicted,
    };
    residency residency_state = residency::hot;

    bool protected_root = false;
    bool is_metadata_only = false;

    // Reason payload is absent (meaningful when is_metadata_only is true)
    enum class payload_absent_reason {
        none,           // Payload is present (is_metadata_only should be false)
        evicted_hot,    // Hot payload was evicted to free RAM
        evicted_cold,   // Cold payload was deleted
        demoted,        // Payload was demoted to cold store (metadata-only in hot layer)
        never_owned,    // Node was created without a payload (e.g., intermediate branch)
    };
    payload_absent_reason absent_reason = payload_absent_reason::none;

    uint64_t exact_blob_payload_id = 0;
    uint64_t checkpoint_payload_id = 0;

    size_t resident_payload_bytes = 0;
    bool has_target_payload = false;
    bool has_draft_payload = false;

    std::atomic<uint32_t> slot_ref_count{0};

    branch_node() = default;
    branch_node(const branch_node & other);
    branch_node & operator=(const branch_node & other);
    branch_node(branch_node && other) noexcept;
    branch_node & operator=(branch_node && other) noexcept;

    size_t metadata_ram_bytes() const;
};

struct namespace_key {
    std::string model_path_hash;
    std::string model_params_hash;
    std::string draft_context_mode;
    std::string draft_model_hash;
    std::string tokenizer_id;
    std::string template_id;
    std::vector<std::string> lora_adapters;
    std::vector<std::string> control_vectors;
    std::string mm_projector_id;
    int mm_patch_size = 0;
    bool mm_use_dynamic_tokens = false;
    int n_ctx = 0;
    int n_batch = 0;
    bool kv_unified = false;
    std::string workload_profile;

    std::string compute() const;
    static bool is_compatible(const std::string & ns_a, const std::string & ns_b);
};

bool validate_namespace_compatibility(
    const std::string & slot_namespace,
    const std::string & branch_namespace);

class branch_forest_index {
public:
    branch_forest_index();

    uint64_t create_node(
        const std::string & namespace_id,
        uint64_t parent_id,
        const std::vector<llama_token> & tokens,
        int64_t pos_min,
        int64_t pos_max,
        uint64_t token_checksum,
        bool protected_root);
    bool remove_node(uint64_t node_id);
    branch_node * get_node(uint64_t node_id);
    const branch_node * get_node(uint64_t node_id) const;

    std::vector<uint64_t> find_nodes_by_token_span(
        const std::string & namespace_id,
        const std::vector<llama_token> & prefix,
        size_t min_match_tokens) const;
    std::vector<uint64_t> find_nodes_by_checksum_span(
        const std::string & namespace_id,
        uint64_t checksum,
        size_t match_tokens) const;

    std::vector<uint64_t> get_children(uint64_t node_id) const;
    uint64_t get_parent(uint64_t node_id) const;
    std::vector<uint64_t> get_path_to_root(uint64_t node_id) const;
    std::vector<uint64_t> get_descendants(uint64_t node_id) const;

    std::vector<std::string> get_namespaces() const;
    size_t namespace_node_count(const std::string & namespace_id) const;
    std::vector<uint64_t> namespace_roots(const std::string & namespace_id) const;

    size_t total_metadata_ram_bytes() const;
    size_t namespace_metadata_ram_bytes(const std::string & namespace_id) const;

    bool acquire_slot_ref(uint64_t node_id);
    bool release_slot_ref(uint64_t node_id);
    uint32_t slot_ref_count(uint64_t node_id) const;

    // Stage 8: Payload eviction with metadata-only retention.
    // Evicts payload from a node, clearing descriptor references and setting
    // is_metadata_only=true. Returns false if slot refs block eviction.
    // If pair_evict is true and the node has a paired payload (target+draft),
    // both sides are cleared together.
    bool evict_payload(uint64_t node_id, bool pair_evict = true);

    // Query whether a node is metadata-only (has no owned payload)
    bool is_metadata_only_node(uint64_t node_id) const;

    // Get the payload absent reason for a metadata-only node
    branch_node::payload_absent_reason get_payload_absent_reason(uint64_t node_id) const;

    // Stage 8: Branch pruning with safety checks.
    // Removes a metadata-only node after validating:
    // - No active slot references
    // - Not a protected root
    // - No retained descendants
    // Returns true if the node was pruned.
    bool prune_node(uint64_t node_id);

    // Stage 8: Equivalent-branch lookup.
    // Finds nodes in the given namespace with matching token path.
    std::vector<uint64_t> find_equivalent_nodes(
        const std::string & namespace_id,
        const std::vector<llama_token> & token_path,
        int64_t pos_min,
        int64_t pos_max) const;

    // Stage 8: Canonical node selection from equivalent candidates.
    // Uses deterministic ordering: payload-bearing before metadata-only,
    // more descendants before fewer, protected-root ancestry, use_sequence,
    // insertion_sequence, node_id.
    uint64_t canonical_node_id(
        const std::string & namespace_id,
        const std::vector<llama_token> & token_path,
        int64_t pos_min,
        int64_t pos_max) const;

    // Stage 8: Rank candidates by deterministic ordering.
    // 8-tier tie-breaking: token match length, checksum confidence,
    // payload-bearing before metadata-only, protected-root ancestry,
    // use_sequence, insertion_sequence, node_id.
    std::vector<uint64_t> rank_candidates(
        const std::string & namespace_id,
        const std::vector<uint64_t> & candidate_ids,
        const std::vector<llama_token> & request_tokens) const;

    // Stage 8: Select mismatch parent from validated candidates.
    // Returns the deepest validated ancestor node_id, or 0 if none.
    uint64_t select_mismatch_parent(
        const std::string & namespace_id,
        const std::vector<llama_token> & request_tokens,
        const std::vector<uint64_t> & candidate_ids) const;

    // Stage 8: Plan re-materialization for a metadata-only node.
    // Validates token/checksum spans along the path from the nearest
    // payload-bearing ancestor to the selected node.
    rematerialization_plan plan_rematerialization(
        const std::string & namespace_id,
        const std::vector<llama_token> & request_tokens,
        uint64_t selected_node_id) const;

    // Stage 8: Build metadata prune candidates.
    // Returns metadata-only leaf nodes that are safe to prune:
    // - No active slot references
    // - Not a protected root
    // - No retained descendants
    // Sorted by pruning score (oldest use_sequence first).
    std::vector<uint64_t> metadata_prune_candidates() const;

    // Stage 8: Enforce metadata budget by pruning candidates.
    // Returns the number of bytes freed by pruning.
    // Stops when under budget or no safe candidate remains.
    size_t enforce_metadata_budget(size_t soft_max_bytes);

    // Stage 8: Cold cleanup ownership safety.
    // Iterates all retained branch nodes, collects referenced descriptor IDs,
    // and returns the set of descriptor IDs that are safe to delete
    // (not referenced by any retained node).
    std::unordered_set<uint64_t> cleanup_cold() const;

    std::vector<uint64_t> payload_eviction_candidates(size_t max_count) const;
    bool is_protected(uint64_t node_id) const;

    size_t size() const;
    size_t active_slot_refs() const;
    uint32_t peak_slot_refs() const;
    branch_traversal_counts traversal_counts() const;

private:
    std::unordered_map<uint64_t, branch_node> nodes_;
    std::unordered_map<uint64_t, std::vector<uint64_t>> children_;
    std::unordered_map<std::string, std::vector<uint64_t>> namespace_roots_;
    std::atomic<uint64_t> next_node_id_{1};
    std::atomic<uint32_t> peak_slot_refs_{0};
    mutable branch_traversal_counts traversal_counts_;
    mutable std::mutex mutex_;
};
