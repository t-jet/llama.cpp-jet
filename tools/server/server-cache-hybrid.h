#pragma once

#include "server-cache-controller.h"
#include "server-task.h"

#include <list>
#include <map>
#include <unordered_map>
#include <vector>
#include <chrono>
#include <string>
#include <functional>

// Forward declarations
struct server_slot;

// Phase 1 hybrid cache entry with LRU tracking
struct hybrid_cache_entry {
    server_tokens tokens;                          // Token sequence for this cache entry
    server_prompt_data data;                       // Serialized state (target + draft)
    std::list<common_prompt_checkpoint> checkpoints; // Checkpoints for this entry
    prepared_prompt_metadata metadata;             // Prompt boundary metadata for this entry
    std::string namespace_id;                      // Namespace (model + config identifier)
    
    // LRU tracking (Phase 1)
    std::chrono::system_clock::time_point last_used_time;  // Last access time
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

    // Mark this entry as used (update LRU metadata)
    void mark_used() {
        last_used_time = std::chrono::system_clock::now();
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

#ifdef LLAMA_SERVER_CACHE_TESTS
    // Test helpers for pure lookup/index coverage without a llama context.
    void debug_add_entry_for_tests(server_tokens tokens, bool protected_root = false, const std::string & namespace_id = "");
    void debug_add_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens, const prepared_prompt_metadata & metadata);
    size_t debug_entry_count_for_tests() const;
    void debug_mark_first_entry_used_for_tests();
#endif

private:
#ifndef LLAMA_SERVER_CACHE_TESTS
    void debug_add_entry_for_tests(server_tokens tokens, bool protected_root = false, const std::string & namespace_id = "");
    void debug_add_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens, const prepared_prompt_metadata & metadata);
    size_t debug_entry_count_for_tests() const;
    void debug_mark_first_entry_used_for_tests();
#endif

    // Phase 1/2: List-based storage (non-destructive, no removal on load)
    std::list<hybrid_cache_entry> entries;

    // Phase 2: Performance indexes
    // LRU index: sorted by last_used_time for O(log n) eviction
    using lru_entry_t = std::pair<
        std::chrono::system_clock::time_point,
        std::list<hybrid_cache_entry>::iterator
    >;
    std::multimap<std::chrono::system_clock::time_point,
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
    size_t limit_size;       // size limit in bytes, 0 = no limit
    size_t limit_tokens;     // token limit, 0 = no limit
    llama_context * ctx_tgt; // target context
    llama_context * ctx_dft; // draft context (may be null)

    // Statistics
    size_t n_hits = 0;
    size_t n_misses = 0;
    size_t n_evictions = 0;
    size_t n_restore_failures = 0;

    // Find best matching entry for given tokens and metadata
    // Returns iterator to best match, or entries.end() if no suitable match
    std::list<hybrid_cache_entry>::iterator find_best_match(
        const server_tokens & tokens_new,
        const prepared_prompt_metadata & metadata);

    // Evict least recently used entry (respects protected_root flag)
    void evict_lru();

    // Check if entry should be protected from eviction
    bool should_protect(const hybrid_cache_entry & entry) const;

    // Calculate total size of all entries
    size_t calculate_total_size() const;

    // Calculate total tokens of all entries
    size_t calculate_total_tokens() const;

    // Compute namespace ID from current context and request compatibility state.
    std::string compute_namespace_id() const;
    std::string compute_namespace_id(const prepared_prompt_metadata & metadata) const;

    // Phase 2: Index maintenance helpers
    void add_to_lru_index(std::list<hybrid_cache_entry>::iterator it);
    void remove_from_lru_index(std::list<hybrid_cache_entry>::iterator it);
    void update_lru_index(std::list<hybrid_cache_entry>::iterator it,
                         std::chrono::system_clock::time_point old_time);
    void add_to_prefix_index(std::list<hybrid_cache_entry>::iterator it);
    void remove_from_prefix_index(std::list<hybrid_cache_entry>::iterator it);
    token_prefix_t get_token_prefix(const server_tokens & tokens) const;
    token_prefix_t get_token_prefix(const server_tokens & tokens, size_t n_prefix) const;
};
