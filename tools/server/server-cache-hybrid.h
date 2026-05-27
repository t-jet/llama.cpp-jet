#pragma once

#include "server-cache-controller.h"
#include "server-cache-policy-lru.h"
#include "server-task.h"

#include <list>
#include <map>
#include <unordered_map>
#include <vector>
#include <string>
#include <functional>

// Forward declarations
struct server_slot;

// Phase 3: Comprehensive namespace compatibility key (Gap 2.2)
// Tracks all runtime configuration that affects cache compatibility
struct cache_compatibility_key {
    // Model identity
    std::string model_path_hash;              // Hash of model file path
    std::string model_params_hash;            // Hash of key model hyperparameters
    
    // Draft model (for speculative decoding)
    std::string draft_model_hash;             // Hash of draft model params or "none"
    
    // Tokenizer and template
    std::string tokenizer_id;                 // Tokenizer identifier from model
    std::string template_id;                  // Template hash or identifier
    
    // Active modifiers
    std::vector<std::string> lora_adapters;   // LoRA adapter paths with scales
    std::vector<std::string> control_vectors; // Control vectors with layer ranges
    
    // Multimodal configuration
    std::string mm_projector_id;              // Multimodal projector identifier
    int mm_patch_size = 0;                    // Image patch size (0 if not multimodal)
    bool mm_use_dynamic_tokens = false;       // Dynamic vs. fixed token count
    
    // Context and KV configuration
    int n_ctx = 0;                            // Context window size
    int n_batch = 0;                          // Batch size
    bool kv_unified = false;                  // Unified KV cache mode
    
    // Workload profile
    std::string workload_profile;             // Workload profile identifier
    
    cache_compatibility_key() = default;
    
    // Compute deterministic hash of all components
    std::string compute() const;
};

// Phase 1 hybrid cache entry with LRU tracking
struct hybrid_cache_entry {
    server_tokens tokens;                          // Token sequence for this cache entry
    server_prompt_data data;                       // Serialized state (target + draft)
    std::list<common_prompt_checkpoint> checkpoints; // Checkpoints for this entry
    prepared_prompt_metadata metadata;             // Prompt boundary metadata for this entry
    std::string namespace_id;                      // Namespace (model + config identifier)

    uint64_t entry_id = 0;                         // Stable identifier for policy plans
    uint64_t insertion_sequence = 0;               // Stable tie-breaker for equal recency
    uint64_t use_sequence = 0;                     // Deterministic LRU recency key
    size_t use_count = 0;                          // Number of times used
    bool protected_root = false;                   // Protected from eviction

    hybrid_cache_entry() = default;

    // Calculate total size of this entry in bytes
    size_t size() const {
        size_t sz = 0;
        sz += tokens.size() * sizeof(llama_token);  // token storage
        sz += data.main.size();                     // target state blob
        sz += data.drft.size();                     // draft state blob
        for (const auto & cp : checkpoints) {
            sz += cp.data_tgt.size();
            sz += cp.data_dft.size();
        }
        sz += namespace_id.size();
        return sz;
    }

    // Get number of tokens
    int n_tokens() const {
        return tokens.size();
    }

    size_t resident_payload_bytes() const {
        return data.main.size() + data.drft.size();
    }

    bool has_target_payload() const {
        return !data.main.empty();
    }

    bool has_draft_payload() const {
        return !data.drft.empty();
    }

    // Mark this entry as used (update LRU metadata)
    void mark_used(uint64_t sequence) {
        use_sequence = sequence;
        use_count++;
    }
};

// Phase 1 hybrid cache controller
// Features:
//   - Non-destructive cache hits (entries remain in cache after loading)
//   - LRU eviction policy
//   - Protected roots
//   - Multi-namespace support
class hybrid_cache_controller : public cache_controller {
public:
    hybrid_cache_controller(
        const common_params & params,
        int32_t limit_size_mib,
        size_t limit_tokens,
        llama_context * ctx_tgt,
        llama_context * ctx_dft);

    ~hybrid_cache_controller() override = default;

    // Cache controller interface implementation
    bool save_slot(const server_slot & slot, const prepared_prompt_metadata & metadata) override;
    bool load_slot(server_slot & slot, const server_task & task) override;
    void update() override;
    json get_stats() const override;
    size_t size() const override;
    size_t n_tokens() const override;

    // Non-destructive cache restore for hybrid mode
    // Returns true if a matching entry was found and restored into the slot
    // Unlike load_slot(), this does not require the slot to be cleared first
    bool try_restore_from_cache(server_slot & slot, const server_task & task);

    // Phase 3: Build comprehensive compatibility key (Gap 2.2)
    cache_compatibility_key build_compatibility_key() const;

    // Phase 3: Validate configuration safety for hybrid cache (Gap 2.2)
    bool validate_hybrid_cache_safety(bool log_warnings = true) const;

#ifdef LLAMA_SERVER_CACHE_TESTS
    // Test helpers for pure lookup/index coverage without a llama context.
    void debug_add_entry_for_tests(server_tokens tokens, bool protected_root = false, const std::string & namespace_id = "");
    void debug_add_entry_for_tests(server_tokens tokens, bool protected_root, const std::string & namespace_id, size_t target_bytes, size_t draft_bytes);
    void debug_add_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens, const prepared_prompt_metadata & metadata);
    bool debug_fail_restore_for_tests(const server_tokens & tokens, const prepared_prompt_metadata & metadata);
    bool debug_try_admit_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata, size_t target_bytes, size_t draft_bytes);
    bool debug_refresh_entry_for_tests(const server_tokens & tokens, bool protected_root = false, const std::string & namespace_id = "");
    void debug_set_hot_payload_budget_bytes_for_tests(size_t limit_size_bytes, bool unlimited = false);
    size_t debug_entry_count_for_tests() const;
    void debug_mark_first_entry_used_for_tests();
    cache_compatibility_key debug_get_compatibility_key_for_tests() const;
#endif

private:
#ifndef LLAMA_SERVER_CACHE_TESTS
    void debug_add_entry_for_tests(server_tokens tokens, bool protected_root = false, const std::string & namespace_id = "");
    void debug_add_entry_for_tests(server_tokens tokens, bool protected_root, const std::string & namespace_id, size_t target_bytes, size_t draft_bytes);
    void debug_add_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens, const prepared_prompt_metadata & metadata);
    bool debug_fail_restore_for_tests(const server_tokens & tokens, const prepared_prompt_metadata & metadata);
    bool debug_try_admit_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata, size_t target_bytes, size_t draft_bytes);
    bool debug_refresh_entry_for_tests(const server_tokens & tokens, bool protected_root = false, const std::string & namespace_id = "");
    void debug_set_hot_payload_budget_bytes_for_tests(size_t limit_size_bytes, bool unlimited = false);
    size_t debug_entry_count_for_tests() const;
    void debug_mark_first_entry_used_for_tests();
    cache_compatibility_key debug_get_compatibility_key_for_tests() const;
#endif

    // Phase 1/2: List-based storage (non-destructive, no removal on load)
    std::list<hybrid_cache_entry> entries;

    // LRU index: sorted by deterministic use sequence for stable tests.
    using lru_key_t = std::pair<uint64_t, uint64_t>;
    std::multimap<lru_key_t,
                  std::list<hybrid_cache_entry>::iterator> lru_index;

    // Token prefix index: hash map for O(m) lookup where m << n
    static constexpr size_t PREFIX_INDEX_LENGTH = 8;
    using token_prefix_t = std::vector<llama_token>;
    struct token_prefix_hash {
        size_t operator()(const token_prefix_t & prefix) const {
            size_t hash = 0;
            for (size_t i = 0; i < prefix.size(); i++) {
                hash = hash * 31 + static_cast<size_t>(prefix[i]);
            }
            return hash;
        }
    };
    std::unordered_map<
        token_prefix_t,
        std::vector<std::list<hybrid_cache_entry>::iterator>,
        token_prefix_hash
    > prefix_index;

    // Configuration
    const common_params & params; // runtime parameters for comprehensive namespace keys
    size_t limit_size;       // size limit in bytes, 0 = no limit
    bool limit_size_unlimited = false;
    size_t limit_tokens;     // token limit, 0 = no limit
    llama_context * ctx_tgt; // target context
    llama_context * ctx_dft; // draft context (may be null)
    server_cache_policy_lru eviction_policy;
    uint64_t next_entry_id = 1;
    uint64_t next_sequence = 1;

    // Statistics
    size_t n_hits = 0;
    size_t n_misses = 0;
    size_t n_evictions = 0;
    size_t n_payload_evictions = 0;
    size_t n_protected_root_decisions = 0;
    size_t n_protected_root_evictions = 0;
    size_t n_protected_root_admission_rejections = 0;
    size_t n_restore_failures = 0;

    // Find best matching entry for given tokens and metadata
    // Returns iterator to best match, or entries.end() if no suitable match
    std::list<hybrid_cache_entry>::iterator find_best_match(
        const server_tokens & tokens_new,
        const prepared_prompt_metadata & metadata);

    // Find exact matching entry for deduplication
    // Returns iterator to exact match, or entries.end() if no match found
    std::list<hybrid_cache_entry>::iterator find_exact_match(
        const server_tokens & tokens,
        const std::string & namespace_id);

    bool evict_entry_by_id(uint64_t entry_id, server_cache_eviction_reason reason);
    void evict_until_within_budget();
    void refresh_existing_entry(std::list<hybrid_cache_entry>::iterator it, bool protected_root);

    // Check if entry should be protected from eviction
    bool should_protect(const hybrid_cache_entry & entry) const;

    // Calculate total size of all entries
    size_t calculate_total_size() const;

    // Calculate total tokens of all entries
    size_t calculate_total_tokens() const;

    size_t calculate_resident_payload_bytes() const;
    size_t calculate_protected_payload_bytes() const;
    size_t calculate_unprotected_payload_bytes() const;
    size_t calculate_protected_entry_count() const;
    bool hot_payload_budget_enabled() const;
    std::vector<server_cache_policy_candidate> build_policy_candidates() const;
    uint64_t next_use_sequence();
    void assign_entry_identity(hybrid_cache_entry & entry);

    // Compute namespace ID from current context and request compatibility state.
    std::string compute_namespace_id() const;
    std::string compute_namespace_id(const prepared_prompt_metadata & metadata) const;

    // Phase 2: Index maintenance helpers
    void add_to_lru_index(std::list<hybrid_cache_entry>::iterator it);
    void remove_from_lru_index(std::list<hybrid_cache_entry>::iterator it);
    void update_lru_index(std::list<hybrid_cache_entry>::iterator it, lru_key_t old_key);
    void add_to_prefix_index(std::list<hybrid_cache_entry>::iterator it);
    void remove_from_prefix_index(std::list<hybrid_cache_entry>::iterator it);
    token_prefix_t get_token_prefix(const server_tokens & tokens) const;
    token_prefix_t get_token_prefix(const server_tokens & tokens, size_t n_prefix) const;
};
