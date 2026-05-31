#pragma once

#include "llama.h"

#include <atomic>
#include <cstdint>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

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
