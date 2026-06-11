#pragma once

#include "server-cache-controller.h"
#include "server-cache-graph.h"
#include "server-cache-policy-lru.h"
#include "server-cache-store-cold.h"
#include "server-cache-io-worker.h"
#include "server-task.h"

#include <chrono>
#include <list>
#include <map>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <string>
#include <functional>
#include <cstdint>

// Forward declarations
struct server_slot;

// Phase 3: Comprehensive namespace compatibility key (Gap 2.2)
// Tracks all runtime configuration that affects cache compatibility
struct cache_compatibility_key {
    // Model identity
    std::string model_path_hash;              // Hash of model file path
    std::string model_params_hash;            // Hash of key model hyperparameters
    
    // Draft model (for speculative decoding)
    std::string draft_context_mode;           // none, separate draft model, target MTP, or separate-model MTP
    std::string draft_model_hash;             // Hash of draft model identity or "none"
    
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

enum class payload_kind {
    exact_blob,
    checkpoint,
};

enum class cache_workload_profile {
    plain_transformer,
    checkpoint_dependent,
    unsupported,
};

enum class payload_pair_state {
    target_only,
    target_and_draft,
};

enum class payload_residency_state {
    hot,
    demoting,   // Transient: hot payload is being written to cold store
    promoting,  // Transient: cold payload is being read back to hot store
    cold,
    evicted,
};

// Residency state transition table (Stage 6):
//
//   hot      -> demoting    : demotion initiated by residency policy
//   demoting -> cold        : demotion completed successfully (hot bytes released)
//   demoting -> hot         : demotion enqueue failed (queue-full revert, NB-2)
//   demoting -> evicted     : demotion failed after hot bytes released (should not happen with NB-5 pinning)
//   cold     -> promoting   : promotion initiated on restore request
//   promoting -> hot        : promotion completed successfully
//   promoting -> cold       : promotion enqueue failed (queue-full revert, NB-2)
//   promoting -> evicted    : promotion failed (integrity check failure)
//   hot      -> evicted    : hot eviction when cold store not configured or demotion fails
//   cold     -> evicted    : cold file deleted or invalidated
//
// Operations blocked while in transient state:
//   demoting : no concurrent demotion, no promotion, no restore, no eviction
//   promoting: no concurrent promotion, no demotion, no eviction
//
// Transient states resolve to stable states via:
//   - Completion callback (success or failure) from the I/O worker
//   - Immediate revert on queue-full failure (NB-2)
//
// Guard: transient states (demoting, promoting) are internal to the cache
// controller. They must not be visible outside the cache subsystem. While a
// descriptor is in a transient state, the controller must not select it for
// any other transition. External code must only observe hot, cold, or evicted.

// Validate that a residency state transition is allowed by the state machine.
// Returns true if the transition from -> to is a valid transition per the
// table above, false otherwise.
inline bool can_transition(payload_residency_state from, payload_residency_state to) {
    switch (from) {
        case payload_residency_state::hot:
            return to == payload_residency_state::demoting
                || to == payload_residency_state::evicted;
        case payload_residency_state::demoting:
            return to == payload_residency_state::cold
                || to == payload_residency_state::hot
                || to == payload_residency_state::evicted;
        case payload_residency_state::promoting:
            return to == payload_residency_state::hot
                || to == payload_residency_state::cold
                || to == payload_residency_state::evicted;
        case payload_residency_state::cold:
            return to == payload_residency_state::promoting
                || to == payload_residency_state::evicted;
        case payload_residency_state::evicted:
            return false;  // No transitions out of evicted
    }
    return false;
}

enum class payload_debug_fault {
    unsupported_version,
    unsupported_kind,
    zero_target_size,
    target_size_mismatch,
    missing_target_bytes,
    bad_store_ref,
    missing_hot_record,
    owner_mismatch,
    cold_residency,
    unexpected_draft_for_target_only,
    missing_draft_for_pair,
    draft_size_mismatch,
    draft_checksum_mismatch,
    demoting_residency,   // Stage 6: inject demoting transient state for tests
    promoting_residency,   // Stage 6: inject promoting transient state for tests
};

struct payload_store_ref {
    uint64_t id = 0;
};

struct payload_descriptor {
    uint64_t payload_id = 0;
    payload_kind kind = payload_kind::exact_blob;
    payload_pair_state pair_state = payload_pair_state::target_only;
    uint32_t format_version = 1;
    size_t target_size_bytes = 0;
    size_t draft_size_bytes = 0;
    size_t resident_payload_bytes = 0;
    uint64_t target_checksum = 0;
    uint64_t draft_checksum = 0;
    payload_store_ref store_ref;
    payload_residency_state residency = payload_residency_state::hot;
    uint64_t owner_entry_id = 0;
    uint64_t created_sequence = 0;
    uint64_t last_validated_sequence = 0;
    int64_t token_span_start = 0;
    int64_t token_span_end = 0;
    llama_pos position_start = 0;
    llama_pos position_end = 0;
    bool checkpoint_boundary_required = false;
    bool checkpoint_boundary_native = false;
    int checkpoint_boundary_kind = -1;
    uint64_t boundary_checksum = 0;
    std::string boundary_id;
    std::string workload_profile;
};

struct hot_payload_record {
    uint64_t payload_id = 0;
    std::vector<uint8_t> target;
    std::vector<uint8_t> draft;
};

// Phase 1 hybrid cache entry with LRU tracking
struct hybrid_cache_entry {
    server_tokens tokens;                          // Token sequence for this cache entry
    std::list<common_prompt_checkpoint> checkpoints; // Checkpoints for this entry
    prepared_prompt_metadata metadata;             // Prompt boundary metadata for this entry
    std::string namespace_id;                      // Namespace (model + config identifier)
    uint64_t payload_id = 0;                       // Descriptor-owned exact-blob payload
    uint64_t checkpoint_payload_id = 0;             // Descriptor-owned checkpoint payload
    uint64_t branch_node_id = 0;                   // Forest node metadata identity

    uint64_t entry_id = 0;                         // Stable identifier for policy plans
    uint64_t insertion_sequence = 0;               // Stable tie-breaker for equal recency
    uint64_t use_sequence = 0;                     // Deterministic LRU recency key
    size_t use_count = 0;                          // Number of times used
    bool protected_root = false;                   // Protected from eviction
    size_t resident_payload_bytes_cached = 0;      // Descriptor byte fields cached for policy sorting
    bool has_target_payload_cached = false;
    bool has_draft_payload_cached = false;

    hybrid_cache_entry() = default;

    // Calculate total size of this entry in bytes
    // __declspec(noinline) (T114a fix 2026-06-05): keep these accessors
    // out-of-line so OpenCppCoverage attributes the body to this header
    // instead of the test .cpp call site under MSVC /Ob1.
    __declspec(noinline) size_t size() const {
        size_t sz = 0;
        sz += tokens.size() * sizeof(llama_token);  // token storage
        sz += resident_payload_bytes_cached;         // descriptor-owned exact blob bytes
        for (const auto & cp : checkpoints) {
            sz += cp.data_tgt.size();
            sz += cp.data_dft.size();
        }
        sz += namespace_id.size();
        return sz;
    }

    // Get number of tokens
    __declspec(noinline) int n_tokens() const { return tokens.size(); }

    __declspec(noinline) size_t resident_payload_bytes() const { return resident_payload_bytes_cached; }

    __declspec(noinline) bool has_target_payload() const { return has_target_payload_cached; }

    __declspec(noinline) bool has_draft_payload() const { return has_draft_payload_cached; }

    // Mark this entry as used (update LRU metadata)
    __declspec(noinline) void mark_used(uint64_t sequence) {
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
        llama_context * ctx_dft,
        const std::string & cold_path = "");

    ~hybrid_cache_controller() override;

    // Cache controller interface implementation
    bool save_slot(server_slot & slot, const prepared_prompt_metadata & metadata) override;
    bool load_slot(server_slot & slot, const server_task & task) override;
    void update() override;
    json get_stats() const override;
    size_t size() const override;
    size_t n_tokens() const override;

    // Non-destructive cache restore for hybrid mode
    // Returns true if a matching entry was found and restored into the slot
    // Unlike load_slot(), this does not require the slot to be cleared first
    bool try_restore_from_cache(server_slot & slot, const server_task & task);
    void release_branch_node_ref(uint64_t node_id) override;

    // Phase 6: Cold layer demotion and promotion
    // Demote a hot payload to cold storage. Returns true if demotion was initiated.
    // The descriptor transitions to demoting state. Completion is handled asynchronously.
    bool demote_payload(uint64_t payload_id);

    // Promote a cold payload back to hot storage. Returns true if promotion was initiated.
    // The descriptor transitions to promoting state. Completion is handled asynchronously.
    bool promote_payload(uint64_t payload_id);

    // Process pending I/O completion results from the worker.
    // Must be called from the server_context thread at safe scheduling points.
    void process_completions();

    // Phase 3: Build comprehensive compatibility key (Gap 2.2)
    cache_compatibility_key build_compatibility_key() const;

    // Phase 3: Validate configuration safety for hybrid cache (Gap 2.2)
    bool validate_hybrid_cache_safety(bool log_warnings = true) const;

#ifdef LLAMA_SERVER_CACHE_TESTS
    // Test helpers for pure lookup/index coverage without a llama context.
    void debug_add_entry_for_tests(server_tokens tokens, bool protected_root = false, const std::string & namespace_id = "");
    void debug_add_entry_for_tests(server_tokens tokens, bool protected_root, const std::string & namespace_id, size_t target_bytes, size_t draft_bytes);
    void debug_add_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata);
    // Stage 14 test 20 fix: 3-arg form that preserves protected_root while
    // matching the lookup's namespace computed from metadata. The 2-arg
    // metadata form does not expose protected_root, so protected_root-based
    // eviction assertions in test 20 require this overload.
    void debug_add_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata, bool protected_root);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens, const prepared_prompt_metadata & metadata);
    bool debug_fail_restore_for_tests(const server_tokens & tokens, const prepared_prompt_metadata & metadata);
    bool debug_try_admit_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata, size_t target_bytes, size_t draft_bytes);
    bool debug_refresh_entry_for_tests(const server_tokens & tokens, bool protected_root = false, const std::string & namespace_id = "");
    void debug_set_hot_payload_budget_bytes_for_tests(size_t limit_size_bytes, bool unlimited = false);
    void debug_set_branch_metadata_soft_max_for_tests(size_t limit_size_bytes);
    bool debug_acquire_first_branch_ref_for_tests();
    bool debug_release_first_branch_ref_for_tests();
    bool debug_pin_first_branch_ref_for_tests();
    size_t debug_entry_count_for_tests() const;
    void debug_mark_first_entry_used_for_tests();
    cache_compatibility_key debug_get_compatibility_key_for_tests() const;
    cache_compatibility_key debug_get_compatibility_key_for_tests(bool runtime_has_draft) const;
    bool debug_validate_first_payload_for_tests(bool runtime_has_draft);
    bool debug_corrupt_first_payload_for_tests();
    bool debug_evict_first_payload_for_tests();
    bool debug_evict_last_payload_for_tests();
    bool debug_inject_first_payload_fault_for_tests(payload_debug_fault fault);
    bool debug_transaction_for_tests(bool runtime_has_draft, bool fail_target, bool fail_draft, bool fail_commit);
    bool debug_empty_preimage_draft_failure_for_tests();
    bool debug_unsupported_empty_clear_for_tests();
    bool debug_rollback_failure_for_tests();
    bool debug_rematerialize_first_entry_for_tests(size_t target_bytes, size_t draft_bytes, bool fail_attach = false);
    bool debug_first_entry_metadata_only_for_tests() const;
    bool debug_first_entry_has_payload_for_tests() const;
    bool debug_try_admit_stage8_for_tests(server_tokens tokens, const std::string & namespace_id, size_t target_bytes, size_t draft_bytes);
    bool debug_add_child_entry_for_tests(server_tokens tokens, const std::string & namespace_id, size_t target_bytes, size_t draft_bytes);
    int debug_select_restore_source_tokens_for_tests(server_tokens tokens, const std::string & namespace_id);
    cache_workload_profile debug_detect_workload_profile_for_tests() const;
    cache_compatibility_key debug_get_compatibility_key_for_tests(bool runtime_has_draft, cache_workload_profile profile) const;
    bool debug_admit_checkpoint_for_tests(size_t target_bytes, size_t draft_bytes);
    bool debug_admit_checkpoint_for_tests(size_t target_bytes, size_t draft_bytes, bool fail_after_descriptor);
    bool debug_admit_checkpoint_for_tests(size_t target_bytes, size_t draft_bytes, int64_t token_span_end);
    bool debug_validate_first_checkpoint_for_tests();
    bool debug_first_checkpoint_metadata_for_tests(const std::string & boundary_id, int64_t token_span_start, int64_t token_span_end, uint64_t boundary_checksum) const;
    int debug_first_checkpoint_restore_token_count_for_tests() const;
    bool debug_corrupt_first_checkpoint_boundary_checksum_for_tests();
    bool debug_first_entry_has_checkpoint_for_tests() const;
    uint64_t debug_first_checkpoint_payload_id_for_tests() const;
    bool debug_demote_first_checkpoint_for_tests();
    int debug_select_stage9_restore_source_tokens_for_tests(server_tokens tokens, const std::string & namespace_id, cache_workload_profile profile);
    bool debug_request_stage9_checkpoint_promotion_for_tests(server_tokens tokens, const std::string & namespace_id);

    // Phase 6 Step 6: Demotion protocol test hooks
    void debug_set_cold_store_for_tests(const std::string & path) {
        cold_store.configure(path, COLD_STORE_FORMAT_VERSION_1);
    }
    void debug_start_io_worker_for_tests() {
        io_worker.debug_set_cold_store_for_tests(&cold_store);
        io_worker.start();
    }
    void debug_stop_io_worker_for_tests() {
        process_completions();
        io_worker.stop();
    }
    void debug_set_io_worker_queue_capacity_for_tests(size_t capacity) {
        io_worker.debug_set_queue_capacity_for_tests(capacity);
    }
    void debug_set_cold_store_validation_failure_for_tests(io_failure_reason reason) {
        cold_store.debug_set_validation_failure_for_tests(reason);
    }
    void debug_set_cold_store_read_failure_for_tests(bool fail) {
        cold_store.debug_set_read_failure_for_tests(fail);
    }

    // Step 8: Test accessors for cold_store and io_worker
    server_cache_store_cold & debug_cold_store_for_tests() { return cold_store; }
    server_cache_io_worker & debug_io_worker_for_tests() { return io_worker; }

    // Step 11: Test hooks for residency state query and promotion failure injection
    payload_residency_state debug_get_residency_state_for_tests(uint64_t payload_id) {
        auto it = payload_descriptors.find(payload_id);
        if (it == payload_descriptors.end()) {
            return payload_residency_state::evicted;
        }
        return it->second.residency;
    }

    void debug_inject_promotion_failure_for_tests(uint64_t payload_id) {
        debug_promotion_failure_payload_ids_.insert(payload_id);
    }

    void debug_clear_promotion_failures_for_tests() {
        debug_promotion_failure_payload_ids_.clear();
    }
#endif

private:
#ifndef LLAMA_SERVER_CACHE_TESTS
    void debug_add_entry_for_tests(server_tokens tokens, bool protected_root = false, const std::string & namespace_id = "");
    void debug_add_entry_for_tests(server_tokens tokens, bool protected_root, const std::string & namespace_id, size_t target_bytes, size_t draft_bytes);
    void debug_add_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata);
    // Stage 14 test 20 fix: 3-arg form that preserves protected_root while
    // matching the lookup's namespace computed from metadata.
    void debug_add_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata, bool protected_root);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens, const prepared_prompt_metadata & metadata);
    bool debug_fail_restore_for_tests(const server_tokens & tokens, const prepared_prompt_metadata & metadata);
    bool debug_try_admit_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata, size_t target_bytes, size_t draft_bytes);
    bool debug_refresh_entry_for_tests(const server_tokens & tokens, bool protected_root = false, const std::string & namespace_id = "");
    void debug_set_hot_payload_budget_bytes_for_tests(size_t limit_size_bytes, bool unlimited = false);
    void debug_set_branch_metadata_soft_max_for_tests(size_t limit_size_bytes);
    bool debug_acquire_first_branch_ref_for_tests();
    bool debug_release_first_branch_ref_for_tests();
    bool debug_pin_first_branch_ref_for_tests();
    size_t debug_entry_count_for_tests() const;
    void debug_mark_first_entry_used_for_tests();
    cache_compatibility_key debug_get_compatibility_key_for_tests() const;
    cache_compatibility_key debug_get_compatibility_key_for_tests(bool runtime_has_draft) const;
    bool debug_validate_first_payload_for_tests(bool runtime_has_draft);
    bool debug_corrupt_first_payload_for_tests();
    bool debug_evict_first_payload_for_tests();
    bool debug_evict_last_payload_for_tests();
    bool debug_inject_first_payload_fault_for_tests(payload_debug_fault fault);
    bool debug_transaction_for_tests(bool runtime_has_draft, bool fail_target, bool fail_draft, bool fail_commit);
    bool debug_empty_preimage_draft_failure_for_tests();
    bool debug_unsupported_empty_clear_for_tests();
    bool debug_rollback_failure_for_tests();
    bool debug_rematerialize_first_entry_for_tests(size_t target_bytes, size_t draft_bytes, bool fail_attach = false);
    bool debug_first_entry_metadata_only_for_tests() const;
    bool debug_first_entry_has_payload_for_tests() const;
    bool debug_try_admit_stage8_for_tests(server_tokens tokens, const std::string & namespace_id, size_t target_bytes, size_t draft_bytes);
    bool debug_add_child_entry_for_tests(server_tokens tokens, const std::string & namespace_id, size_t target_bytes, size_t draft_bytes);
    int debug_select_restore_source_tokens_for_tests(server_tokens tokens, const std::string & namespace_id);
    cache_workload_profile debug_detect_workload_profile_for_tests() const;
    cache_compatibility_key debug_get_compatibility_key_for_tests(bool runtime_has_draft, cache_workload_profile profile) const;
    bool debug_admit_checkpoint_for_tests(size_t target_bytes, size_t draft_bytes);
    bool debug_admit_checkpoint_for_tests(size_t target_bytes, size_t draft_bytes, bool fail_after_descriptor);
    bool debug_admit_checkpoint_for_tests(size_t target_bytes, size_t draft_bytes, int64_t token_span_end);
    bool debug_validate_first_checkpoint_for_tests();
    bool debug_first_checkpoint_metadata_for_tests(const std::string & boundary_id, int64_t token_span_start, int64_t token_span_end, uint64_t boundary_checksum) const;
    int debug_first_checkpoint_restore_token_count_for_tests() const;
    bool debug_corrupt_first_checkpoint_boundary_checksum_for_tests();
    bool debug_first_entry_has_checkpoint_for_tests() const;
    uint64_t debug_first_checkpoint_payload_id_for_tests() const;
    bool debug_demote_first_checkpoint_for_tests();
    int debug_select_stage9_restore_source_tokens_for_tests(server_tokens tokens, const std::string & namespace_id, cache_workload_profile profile);
    bool debug_request_stage9_checkpoint_promotion_for_tests(server_tokens tokens, const std::string & namespace_id);
#endif

    // Phase 1/2: List-based storage (non-destructive, no removal on load)
    std::list<hybrid_cache_entry> entries;
    branch_forest_index forest;
    std::unordered_map<uint64_t, payload_descriptor> payload_descriptors;
    std::unordered_map<uint64_t, hot_payload_record> hot_payloads;

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

    // Phase 6: Cold store and async I/O worker
    server_cache_store_cold cold_store;
    server_cache_io_worker io_worker;

    // Phase 6 Step 11: Per-payload promotion failure injection set
#ifdef LLAMA_SERVER_CACHE_TESTS
    std::unordered_set<uint64_t> debug_promotion_failure_payload_ids_;
#endif

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
    uint64_t next_payload_id = 1;
    size_t branch_metadata_ram_soft_max = 0;

    // Statistics
    size_t n_hits = 0;
    size_t n_misses = 0;
    size_t n_evictions = 0;
    size_t n_payload_evictions = 0;
    size_t n_payload_eviction_bytes = 0;
    size_t n_protected_root_decisions = 0;
    size_t n_protected_root_evictions = 0;
    size_t n_protected_root_admission_rejections = 0;
    size_t n_restore_failures = 0;
    size_t n_descriptor_validation_failures = 0;
    size_t n_pairing_violations = 0;
    size_t n_fallback_restores = 0;
    size_t n_restore_target_apply_failures = 0;
    size_t n_restore_draft_apply_failures = 0;
    size_t n_restore_commit_failures = 0;
    size_t n_restore_rollback_failures = 0;
    size_t n_branch_nodes_created = 0;
    size_t n_branch_token_lookups = 0;
    size_t n_branch_checksum_lookups = 0;
    size_t n_branch_lookup_hits = 0;
    std::map<std::string, size_t> n_branch_token_lookups_by_namespace;
    std::map<std::string, size_t> n_branch_checksum_lookups_by_namespace;
    size_t n_namespace_validation_passes = 0;
    size_t n_namespace_validation_failures = 0;
    size_t n_branch_metadata_over_limit_events = 0;
    size_t n_eviction_payload_blocked_refs = 0;
    size_t n_slot_ref_acquires = 0;
    size_t n_slot_ref_releases = 0;
    size_t n_forest_lock_acquires = 0;
    size_t n_forest_lock_retries = 0;

    // Phase 6: Cold layer statistics
    size_t n_demotion_successes = 0;
    size_t n_demotion_failures = 0;
    size_t n_promotion_successes = 0;
    size_t n_promotion_failures = 0;
    size_t n_cold_evictions = 0;
    size_t n_demotion_queue_full = 0;
    size_t n_promotion_queue_full = 0;
    size_t n_cold_payload_bytes = 0;              // Total bytes in cold store (incremented on demotion success)
    size_t n_protected_root_demotions = 0;         // Protected roots that were demoted

    // Phase 6 Step 10: Promotion latency histogram
    // Buckets: 0-1ms, 1-5ms, 5-10ms, 10-50ms, 50-100ms, 100-500ms, 500ms-1s, 1s+
    static constexpr size_t PROMOTION_LATENCY_BUCKET_COUNT = 8;
    size_t n_promotion_latency_buckets[PROMOTION_LATENCY_BUCKET_COUNT] = {};
    std::chrono::steady_clock::time_point promotion_enqueue_time;

    // Phase 6 Step 10: Cold payload count gauge
    size_t n_cold_payload_count = 0;              // Count of descriptors with residency_state == cold

    // Phase 6 Step 10: Promotion failure reason counters
    size_t n_promotion_failure_checksum_mismatch = 0;
    size_t n_promotion_failure_not_found = 0;
    size_t n_promotion_failure_other = 0;

    // Phase 6 Step 10: Demotion failure reason counters
    size_t n_demotion_failure_write_error = 0;
    size_t n_demotion_failure_other = 0;

    // Stage 8: Re-materialization and metadata-only metrics
    size_t n_cache_metadata_only_retentions = 0;
    size_t n_cache_node_rematerializations = 0;
    size_t n_cache_node_rematerialization_bytes = 0;
    size_t n_cache_validation_mismatches = 0;
    size_t n_cache_mismatch_parent_selections = 0;
    size_t n_cache_equivalent_branch_deduplications = 0;
    size_t n_cache_branch_prunings = 0;
    size_t n_cache_branch_pruned_metadata_bytes = 0;
    size_t n_cache_cold_cleanup_total = 0;
    size_t n_cache_branch_metadata_admission_rejections = 0;
    size_t n_checkpoint_admission_successes = 0;
    size_t n_checkpoint_admission_failures = 0;
    size_t n_checkpoint_hits = 0;
    size_t n_checkpoint_restore_successes = 0;
    size_t n_checkpoint_restore_failures = 0;
    std::map<std::string, size_t> n_checkpoint_hits_by_shape;
    std::map<std::string, size_t> n_checkpoint_restores_by_shape;
    std::map<std::string, size_t> n_stage10_exact_restores_by_shape;
    std::map<std::string, size_t> n_stage10_payload_transitions_by_shape;
    std::map<std::string, size_t> n_stage10_payload_evictions_by_shape;
    std::map<std::string, size_t> n_stage10_protected_root_decisions_by_shape;
    std::map<std::string, size_t> n_stage10_fallback_restores_by_shape;
    std::map<std::string, size_t> n_stage10_diagnostics_by_shape;
    size_t n_workload_profile_plain = 0;
    size_t n_workload_profile_checkpoint_dependent = 0;
    size_t n_workload_profile_unsupported = 0;

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
    void record_branch_lookup(const std::string & namespace_id, const char * method);

    bool evict_entry_by_id(uint64_t entry_id, server_cache_eviction_reason reason);
    void evict_until_within_budget();
    void refresh_existing_entry(std::list<hybrid_cache_entry>::iterator it, bool protected_root);
    uint64_t create_branch_node_for_entry(hybrid_cache_entry & entry, uint64_t parent_node_id = 0);
    void sync_branch_node_from_entry(const hybrid_cache_entry & entry);
    bool entry_has_payload_for_restore(const hybrid_cache_entry & entry) const;
    bool materialize_entry_payload(
        std::list<hybrid_cache_entry>::iterator it,
        std::vector<uint8_t> target,
        std::vector<uint8_t> draft,
        bool runtime_has_draft,
        std::string * failure_reason = nullptr);
    std::list<hybrid_cache_entry>::iterator find_equivalent_entry(
        const server_tokens & tokens,
        const std::string & namespace_id);
    uint64_t select_mismatch_parent_for_admission(
        const server_tokens & tokens,
        const std::string & namespace_id);
    std::list<hybrid_cache_entry>::iterator admit_entry_with_payload(
        server_tokens tokens,
        const prepared_prompt_metadata & metadata,
        const std::string & namespace_id,
        bool protected_root,
        std::vector<uint8_t> target,
        std::vector<uint8_t> draft,
        bool runtime_has_draft,
        uint64_t parent_node_id,
        std::string * failure_reason = nullptr);
    bool enforce_branch_metadata_admission_budget(
        std::list<hybrid_cache_entry>::iterator it,
        const std::string & namespace_id,
        std::string * failure_reason = nullptr);
    bool acquire_branch_node_ref_for_slot(server_slot & slot, uint64_t node_id);
    std::list<hybrid_cache_entry>::iterator find_entry_by_branch_node(uint64_t node_id);
    std::list<hybrid_cache_entry>::const_iterator find_entry_by_branch_node(uint64_t node_id) const;
    std::list<hybrid_cache_entry>::iterator select_restore_source_for_metadata_only(
        std::list<hybrid_cache_entry>::iterator selected,
        const std::string & namespace_id,
        const std::vector<llama_token> & lookup_tokens,
        bool * validation_mismatch = nullptr,
        bool * unavailable = nullptr);
    void record_branch_metadata_pressure();
    void remove_payload(uint64_t payload_id);
    void mark_payload_evicted(hybrid_cache_entry & entry);
    bool mark_payload_kind_evicted(hybrid_cache_entry & entry, payload_kind kind);
    bool remove_entry_after_eviction(std::list<hybrid_cache_entry>::iterator it);
    bool attach_payload(
        hybrid_cache_entry & entry,
        std::vector<uint8_t> target,
        std::vector<uint8_t> draft,
        bool runtime_has_draft,
        std::string * failure_reason = nullptr);
    bool attach_payload(
        hybrid_cache_entry & entry,
        std::vector<uint8_t> target,
        std::vector<uint8_t> draft,
        bool runtime_has_draft,
        payload_kind kind,
        std::string * failure_reason = nullptr);
    bool attach_checkpoint_payload(
        hybrid_cache_entry & entry,
        std::vector<uint8_t> target,
        std::vector<uint8_t> draft,
        bool runtime_has_draft,
        const common_prompt_checkpoint * checkpoint = nullptr,
        const prepared_prompt_metadata * metadata = nullptr,
        std::string * failure_reason = nullptr,
        bool fail_after_descriptor = false);
    bool admit_latest_checkpoint(
        hybrid_cache_entry & entry,
        const common_prompt_checkpoint & checkpoint,
        bool runtime_has_draft,
        std::string * failure_reason = nullptr);
    const hot_payload_record * resolve_hot_payload(const hybrid_cache_entry & entry, std::string * failure_reason) const;
    const hot_payload_record * resolve_hot_payload(uint64_t payload_id, std::string * failure_reason) const;
    bool validate_payload_for_restore(
        const hybrid_cache_entry & entry,
        bool runtime_has_draft,
        std::string * failure_reason = nullptr,
        const hot_payload_record ** record_out = nullptr);
    bool validate_payload_for_restore(
        const hybrid_cache_entry & entry,
        payload_kind kind,
        bool runtime_has_draft,
        std::string * failure_reason = nullptr,
        const hot_payload_record ** record_out = nullptr);
    bool validate_checkpoint_descriptor_metadata(
        const hybrid_cache_entry & entry,
        const payload_descriptor & descriptor,
        const prepared_prompt_metadata * metadata,
        std::string * failure_reason = nullptr) const;
    bool validate_descriptor_against_record(
        const hybrid_cache_entry & entry,
        const payload_descriptor & descriptor,
        const hot_payload_record & record,
        bool runtime_has_draft,
        bool require_hot,
        std::string * failure_reason = nullptr) const;
    void record_payload_validation_failure(const std::string & reason);
    uint64_t payload_checksum(const std::vector<uint8_t> & bytes) const;
    bool runtime_pair_matches(payload_pair_state pair_state, bool runtime_has_draft, std::string * failure_reason) const;
    cache_workload_profile detect_workload_profile() const;
    std::list<hybrid_cache_entry>::iterator select_restore_candidate(
        const std::vector<uint64_t> & forest_candidates,
        const server_tokens & tokens_new,
        cache_workload_profile profile);
    payload_kind select_restore_payload_kind(const hybrid_cache_entry & entry, cache_workload_profile profile) const;
    llama_state_seq_flags restore_state_flags_for_payload(payload_kind kind) const;
    int restored_token_count_for_payload(const hybrid_cache_entry & entry, payload_kind kind) const;
    bool checkpoint_path_valid_for_restore(const hybrid_cache_entry & entry, std::string * failure_reason = nullptr) const;
    bool entry_has_payload_descriptor_for_restore(const hybrid_cache_entry & entry, payload_kind kind) const;
    bool entry_has_payload_kind_for_restore(const hybrid_cache_entry & entry, payload_kind kind) const;
    uint64_t entry_payload_id_for_kind(const hybrid_cache_entry & entry, payload_kind kind) const;
    void set_entry_payload_id_for_kind(hybrid_cache_entry & entry, payload_kind kind, uint64_t payload_id);
    void refresh_entry_payload_accounting(hybrid_cache_entry & entry);
    void record_workload_profile(cache_workload_profile profile);
    void record_checkpoint_hit(const payload_descriptor & descriptor);
    void record_checkpoint_restore(const payload_descriptor & descriptor, bool success);
    void record_exact_restore(const payload_descriptor & descriptor, const char * result, const char * reason);
    void record_payload_transition(const char * operation, const payload_descriptor & descriptor, const char * result, const char * reason);
    void record_payload_eviction(const payload_descriptor & descriptor, const char * result, const char * reason);
    void record_protected_root_decision(const char * decision, const char * pressure_source, const char * result, const char * reason);
    void record_fallback_restore(const char * strategy, payload_kind kind, cache_workload_profile profile, const char * result, const char * reason);
    void record_stage10_diagnostic(const char * event, const char * result, const char * reason, const payload_descriptor * descriptor = nullptr);

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
    std::vector<server_cache_policy_candidate> build_policy_candidates();
    uint64_t next_use_sequence();
    void assign_entry_identity(hybrid_cache_entry & entry);

    // Compute namespace ID from current context and request compatibility state.
    std::string compute_namespace_id() const;
    std::string compute_namespace_id(const prepared_prompt_metadata & metadata) const;
    cache_compatibility_key build_compatibility_key(bool runtime_has_draft) const;
    cache_compatibility_key build_compatibility_key(bool runtime_has_draft, cache_workload_profile profile) const;

    // Phase 6: Cold layer demotion and promotion completion handlers
    void handle_demotion_completion(io_completion_result & result);
    void handle_promotion_completion(io_completion_result & result);

    // Phase 2: Index maintenance helpers
    void add_to_lru_index(std::list<hybrid_cache_entry>::iterator it);
    void remove_from_lru_index(std::list<hybrid_cache_entry>::iterator it);
    void update_lru_index(std::list<hybrid_cache_entry>::iterator it, lru_key_t old_key);
    void add_to_prefix_index(std::list<hybrid_cache_entry>::iterator it);
    void remove_from_prefix_index(std::list<hybrid_cache_entry>::iterator it);
    token_prefix_t get_token_prefix(const server_tokens & tokens) const;
    token_prefix_t get_token_prefix(const server_tokens & tokens, size_t n_prefix) const;
};
