#pragma once

#include "server-cache-controller.h"
#include "server-cache-graph.h"
#include "server-cache-policy-lru.h"
#include "server-cache-store-cold.h"
#include "server-cache-io-worker.h"
#include "server-slot.h"
#include "server-task.h"

#include <chrono>
#include <array>
#include <list>
#include <map>
#include <mutex>
#include <tuple>
#include <unordered_map>
#include <unordered_set>
#include <vector>
#include <string>
#include <functional>
#include <cstdint>

// Forward declarations
// server_slot is fully defined in server-slot.h (included above) so the
// hybrid cache transaction layer (tx_save / tx_load / tx_restore /
// tx_apply_restore) can access slot members directly. The full struct was
// moved out of server-context.cpp in Stage 25 to enable B-1 routing.

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

enum class cache_restore_miss_reason {
    namespace_mismatch,
    token_count_mismatch,
    checksum_mismatch,
    exact_entry_absent,
    unsafe_prefix_rejected,
    payload_unavailable,
    unsupported_route_or_profile,
};

enum class cache_two_layer_mode : uint8_t { hybrid };
enum class cache_two_layer_result : uint8_t { retained_cold, evicted, bypassed, retained_hot };
enum class cache_two_layer_reason : uint8_t {
    cold_room, cold_room_made, both_filled, oversized_both, cold_disabled,
    io_error, integrity_error, size_overflow,
};
enum class cache_cold_transaction_result : uint8_t { commit, rollback, recovery };
enum class cache_cold_transaction_reason : uint8_t {
    none, stage_write, stage_validate, victim_quarantine, incoming_publish,
    apply, commit_marker, cleanup, manifest,
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

#ifdef LLAMA_STAGE39_LIVE_TEST_SEAM
struct stage39_live_pressure_inventory_row {
    uint64_t payload_id = 0;
    uint64_t owner_entry_id = 0;
    std::string payload_kind;
    std::string pair_state;
    std::string residency;
    bool protected_root = false;
    uint64_t slot_reference_count = 0;
    uint64_t resident_bytes = 0;
    bool has_serialized_cold_bytes = false;
    uint64_t serialized_cold_bytes = 0;
    uint64_t hot_order = 0;
    uint64_t cold_rank = 0;
    bool eligible = false;
};

struct stage39_live_pressure_cold_set {
    uint64_t incoming_payload_id = 0;
    uint64_t incoming_owner_entry_id = 0;
    std::vector<stage39_live_pressure_inventory_row> candidates;
};

struct stage39_live_pressure_hot_order {
    uint64_t owner_entry_id = 0;
    uint64_t desired_hot_order = 0;
};

struct stage39_live_pressure_cold_rank {
    uint64_t payload_id = 0;
    uint64_t desired_cold_rank = 0;
};

struct stage39_prepared_proof_binding {
    std::string workload_role;
    uint64_t request_number = 0;
    uint64_t pressure_step = 0;
    uint64_t payload_id = 0;
    uint64_t owner_entry_id = 0;
    std::string payload_kind;
    std::string pair_state;
    bool runtime_has_draft = false;
    uint64_t target_size_bytes = 0;
    uint64_t draft_size_bytes = 0;
    uint64_t target_checksum = 0;
    uint64_t draft_checksum = 0;
};

struct stage39_live_pressure_request {
    std::string operation;
    std::string scenario;
    size_t hot_budget_bytes = 0;
    uint64_t cold_budget_bytes = 0;
    uint64_t snapshot_generation = 0;
    std::string snapshot_token;
    uint64_t incoming_payload_id = 0;
    uint64_t incoming_owner_entry_id = 0;
    std::vector<stage39_live_pressure_inventory_row> hot_candidates;
    std::vector<stage39_live_pressure_cold_set> cold_sets;
    std::vector<stage39_live_pressure_hot_order> desired_hot_orders;
    std::vector<stage39_live_pressure_cold_rank> desired_cold_ranks;
    std::string tp39_03_cold_owner_setup;
    std::string tp39_03_setup;
    std::string run_id;
    std::string process_identity;
    std::string proof_token;
    std::string test_session_id;
    std::string terminal_hmac;
    std::string fault;
    std::vector<uint64_t> proof_payload_ids;
    std::vector<stage39_prepared_proof_binding> prepared_bindings;
};

struct stage39_live_pressure_result {
    bool success = false;
    bool consumed = false;
    bool pressure_started = false;
    std::string error;
    json body;
};
#endif

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

// Stage 14 comprehensive fix: debug_attach_options bundles all the
// test-infrastructure parameters identified across the cycle into a
// single struct. The comprehensive helpers below use the struct to
// avoid overload proliferation. A default-constructed struct matches
// the prior simple-helper behavior. Defined unconditionally so the
// struct is available to both the public test-only block and the
// private production-side stub declarations. The struct itself is a
// passive data type with no runtime cost in production builds.
struct debug_attach_options {
    size_t target_bytes = 0;                  // > 0 required for Stage 5 admission
    size_t draft_bytes = 0;                  // 0 for target-only
    bool fail_after_descriptor = false;      // mirrors the 3-arg bool overload
    int64_t token_span_end = -1;             // -1 means use full token count
    bool protected_root = false;             // protected from eviction
    bool bypass_workload_profile = false;    // skip the workload profile check
    bool force_empty_draft_preimage_failure = false; // next draft preimage check fails
    bool fail_token_span_check = false;      // token span boundary failure
    std::string namespace_override;          // empty means compute from metadata
    bool runtime_has_draft = true;           // mirrors validate_payload_for_restore's runtime flag
};

// Phase 1 hybrid cache controller
// Features:
//   - Non-destructive cache hits (entries remain in cache after loading)
//   - LRU eviction policy
//   - Protected roots
//   - Multi-namespace support
//
// Stage 25: atomic transactional cache writes. All cache-state mutations
// happen inside a critical section guarded by cache_state_mutex_. The slot
// lifecycle calls tx_save / tx_restore / tx_apply_restore / tx_load (public
// methods) which acquire the mutex once at entry. The recursive mutex allows
// the documented inner-call set:
//   tx_save -> tx_evict_entry
//   tx_restore -> tx_promote_payload (inline cold read)
//   tx_update -> tx_evict_entry
// The mutex is not held during the live-slot apply step (OQ-25-01 SPLIT);
// tx_apply_restore re-acquires for owner-view sync and metrics finalize.
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

    // Stage 28 R28-BUG-04 Phase C: the async completion drain
    // (process_completions) has been removed. Demotion and promotion now
    // execute synchronously under cache_state_mutex_ via tx_demote_payload
    // and tx_promote_payload, so there is no queued completion to drain.

    // Stage 25: atomic transactional cache writes. The tx_* methods below
    // acquire cache_state_mutex_ once at entry and release once at exit.
    // They are the new canonical entry points for slot lifecycle work.
    // tx_save / tx_load wrap the legacy save / load flows; tx_restore
    // performs plan selection under lock and returns a cache_response the
    // slot thread applies outside the lock; tx_apply_restore re-acquires
    // the lock to finalize owner-view sync and metrics (OQ-25-01 SPLIT).
    bool tx_save(server_slot & slot, const prepared_prompt_metadata & metadata);
    bool tx_load(server_slot & slot, const server_task & task);
    // Stage 25: synchronous inline demotion / promotion. tx_demote_payload
    // runs the cold-store write inline on the calling thread under the
    // cache-state mutex and applies the success/failure path immediately,
    // so the descriptor residency transitions in one call.
    bool tx_demote_payload(uint64_t payload_id, bool defer_final_decision = false);
    bool tx_promote_payload(uint64_t payload_id);
    // Stage 25: transactional eviction. Wraps evict_entry_by_id with the
    // lock guard. Preserves the over-hot-budget guard from D-EXEC-24-01
    // and the token-limit guaranteed-progress fallback from D-EXEC-24-02.
    bool tx_evict_entry(uint64_t entry_id, server_cache_eviction_reason reason);
    // Stage 25: transactional update. The eviction loop, cold cleanup,
    // branch-metadata prune, and token-limit loop run inside one
    // critical section. No more completion drain.
    void tx_update();

#ifdef LLAMA_STAGE39_LIVE_TEST_SEAM
    stage39_live_pressure_result stage39_live_pressure_control(
        const stage39_live_pressure_request & request);
    void debug_fail_stage39_setup_after_first_write_for_tests() {
        stage39_fail_setup_after_first_write_for_tests_ = true;
    }
    void debug_fail_stage39_owner_setup_write_for_tests(size_t position) {
        stage39_fail_owner_setup_write_for_tests_ = position;
    }
    void debug_stage39_forbidden_effect_probe_for_tests(const std::string & effect) {
        stage39_forbidden_effect_probe_ = effect;
    }
#endif

    // Stage 25: cache_response holds the restore plan computed under lock.
    // tx_restore returns it; the slot thread applies target/draft bytes
    // to the live llama_context outside the lock; tx_apply_restore
    // re-acquires the lock to finalize owner-view sync and metrics.
    // entry_tokens / entry_checkpoints / entry_metadata are captured at
    // tx_restore time so the apply step can update slot prompt state
    // without re-locking the cache (the apply step is OUTSIDE the lock
    // per OQ-25-01 SPLIT; re-looking up the entry after lock release
    // would race with eviction).
    struct cache_response {
        bool found = false;
        cache_restore_miss_reason miss_reason = cache_restore_miss_reason::exact_entry_absent;
        uint64_t entry_id = 0;
        payload_kind selected_payload_kind = payload_kind::exact_blob;
        llama_state_seq_flags restore_flags = LLAMA_STATE_SEQ_FLAGS_NONE;
        int restored_token_count = 0;
        std::vector<uint8_t> target_bytes;
        std::vector<uint8_t> draft_bytes;
        bool runtime_has_draft = false;
        cache_workload_profile profile = cache_workload_profile::plain_transformer;
        payload_pair_state pair_state = payload_pair_state::target_only;
        std::string lookup_namespace_id;
        bool fallback_used = false;
        // Captured entry state for apply-outside-lock (OQ-25-01 SPLIT).
        server_tokens entry_tokens;
        std::list<common_prompt_checkpoint> entry_checkpoints;
        prepared_prompt_metadata entry_metadata;
    };
    cache_response tx_restore(server_slot & slot, const server_task & task);
    void tx_apply_restore(server_slot & slot, const cache_response & plan, bool apply_ok);

    // Phase 3: Build comprehensive compatibility key (Gap 2.2)
    cache_compatibility_key build_compatibility_key() const;

    // Phase 3: Validate configuration safety for hybrid cache (Gap 2.2)
    bool validate_hybrid_cache_safety(bool log_warnings = true) const;

#ifdef LLAMA_SERVER_CACHE_TESTS
    // Comprehensive attach helper. When opts.namespace_override is non-empty,
    // the override is used in place of compute_namespace_id(metadata). When
    // opts.bypass_workload_profile is true, the workload profile check is
    // skipped (for tests that build a controller with nullptr ctx_tgt).
    // Test-only path; gated by LLAMA_SERVER_CACHE_TESTS.
    bool debug_attach_payload_for_tests(server_tokens && tokens,
                                        const prepared_prompt_metadata & meta,
                                        const debug_attach_options & opts = {});

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
    // Stage 14 test 21 fix: 2-arg form that uses a literal namespace string
    // instead of compute_namespace_id(metadata). The 2-arg metadata form
    // computes a hash from empty metadata which differs from the literal
    // namespace used by 5-arg debug_add_entry_for_tests calls.
    int debug_find_match_tokens_for_tests(const server_tokens & tokens, const std::string & namespace_id);
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
    std::string debug_compute_namespace_id_for_tests(const prepared_prompt_metadata & metadata) const;
    bool debug_validate_first_payload_for_tests(bool runtime_has_draft);
    bool debug_corrupt_first_payload_for_tests();
    bool debug_evict_first_payload_for_tests();
    bool debug_evict_last_payload_for_tests();
    bool debug_inject_first_payload_fault_for_tests(payload_debug_fault fault);
    bool debug_transaction_for_tests(bool runtime_has_draft, bool fail_target, bool fail_draft, bool fail_commit);
    // Stage 14 comprehensive fix: add runtime_has_draft parameter so the
    // test can control whether the hard-coded validate_payload_for_restore
    // call inside the helper uses runtime_has_draft=true or =false. The
    // tests add an entry as target_only (draft_bytes=0); the original
    // hard-coded true caused the validation to fail with "runtime does
    // not accept draft payload" and the assertion to crash. Default true
    // preserves the prior behavior for any caller that omits the arg.
    bool debug_empty_preimage_draft_failure_for_tests(bool runtime_has_draft = true);
    bool debug_unsupported_empty_clear_for_tests(bool runtime_has_draft = true);
    bool debug_rollback_failure_for_tests(bool runtime_has_draft = true);
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
    // Stage 14 test_stage9 fix: 4-arg form that bypasses the workload profile
    // check in validate_checkpoint_descriptor_metadata. Test-only path
    // (gated by LLAMA_SERVER_CACHE_TESTS); used by tests that build a
    // controller with nullptr ctx_tgt (which makes detect_workload_profile
    // return unsupported) and still need to admit a checkpoint payload.
    bool debug_admit_checkpoint_for_tests(size_t target_bytes, size_t draft_bytes, int64_t token_span_end, bool bypass_workload_profile);
    // Stage 14 comprehensive fix: opts-based overload of checkpoint
    // admission. Bundles the bypass flag and any future per-call test
    // knobs into a struct. The 4-arg bool overload above delegates here.
    // Test-only path; gated by LLAMA_SERVER_CACHE_TESTS.
    bool debug_admit_checkpoint_for_tests(size_t target_bytes,
                                          size_t draft_bytes,
                                          int64_t token_span_end,
                                          const debug_attach_options & opts);
    bool debug_validate_first_checkpoint_for_tests();
    bool debug_first_checkpoint_metadata_for_tests(const std::string & boundary_id, int64_t token_span_start, int64_t token_span_end, uint64_t boundary_checksum) const;
    int debug_first_checkpoint_restore_token_count_for_tests() const;
    bool debug_corrupt_first_checkpoint_boundary_checksum_for_tests();
    bool debug_first_entry_has_checkpoint_for_tests() const;
    uint64_t debug_first_checkpoint_payload_id_for_tests() const;
    bool debug_demote_first_checkpoint_for_tests();
    int debug_select_stage9_restore_source_tokens_for_tests(server_tokens tokens, const std::string & namespace_id, cache_workload_profile profile);
    bool debug_request_stage9_checkpoint_promotion_for_tests(server_tokens tokens, const std::string & namespace_id);
    void debug_record_stage17_prefix_miss_for_tests(
        const server_tokens & tokens,
        const prepared_prompt_metadata & metadata);
    cache_restore_miss_reason debug_classify_stage17_miss_for_tests(
        const server_tokens & tokens,
        const prepared_prompt_metadata & metadata) const;

    // Stage 38 F38-IMPL-01: test-only hook to drive the private prefix
    // validator with a forced pair_state when the test controller has no
    // live draft context (ctx_dft is nullptr). Adds the entry to the cache
    // if not present, then returns the validator verdict. runtime_has_draft
    // controls the pair_state passed in.
    cache_restore_miss_reason debug_validate_strict_prefix_for_tests(
        const server_tokens & entry_tokens,
        const prepared_prompt_metadata & entry_metadata,
        const server_tokens & request_tokens,
        const prepared_prompt_metadata & request_metadata,
        cache_workload_profile profile,
        bool runtime_has_draft,
        payload_kind selected_payload_kind);

    // Phase 6 Step 6: Demotion protocol test hooks
    void debug_set_cold_store_for_tests(const std::string & path) {
        cold_store.configure(path, COLD_STORE_FORMAT_VERSION_1);
        io_worker.set_cold_store(&cold_store);
    }
    // Stage 28 R28-BUG-04 Phase C: debug_start_io_worker_for_tests,
    // debug_stop_io_worker_for_tests, and
    // debug_set_io_worker_queue_capacity_for_tests have been removed
    // along with the async worker thread. Demotion and promotion now
    // execute synchronously via tx_demote_payload / tx_promote_payload;
    // there is no worker to start, no queue to bound, and no completion
    // to drain. The cold-store pointer is still wired via debug_set_cold_store_for_tests
    // above or via the controller constructor when cold-path is non-empty.
    void debug_set_cold_store_validation_failure_for_tests(io_failure_reason reason) {
        cold_store.debug_set_validation_failure_for_tests(reason);
    }
    void debug_set_cold_store_read_failure_for_tests(bool fail) {
        cold_store.debug_set_read_failure_for_tests(fail);
    }

    // Stage 25: test-only debug accessor for the cache-state mutex so the
    // TP-25-UT1 and TP-25-UT10 contention tests can hold the lock from a
    // worker thread without going through a public tx_* method.
    std::recursive_mutex & debug_get_cache_state_mutex_for_tests() { return cache_state_mutex_; }

    // Stage 25: test-only debug hooks for the transaction layer. These
    // expose the new tx_* methods and the reentrancy counter so TP-25-UT1
    // through TP-25-UT10 can assert on atomicity, isolation, and the
    // bounded diagnostic counters.
    bool debug_run_save_transaction_for_tests(server_slot & slot, const prepared_prompt_metadata & metadata);
    hybrid_cache_controller::cache_response debug_run_restore_transaction_for_tests(server_slot & slot, const server_task & task);
    hybrid_cache_controller::cache_response debug_capture_first_payload_for_tests(bool runtime_has_draft);
    void debug_apply_restore_transaction_for_tests(server_slot & slot, const hybrid_cache_controller::cache_response & plan, bool apply_ok);
    size_t debug_get_transaction_depth_for_tests() const { return server_context_tx_depth_; }
    size_t debug_get_reentrancy_depth_limit_for_tests() const { return reentrancy_depth_limit_; }
    size_t debug_get_transaction_wait_exceeded_for_tests() const { return n_transaction_wait_exceeded; }
    size_t debug_get_apply_restore_syncs_for_tests() const { return n_apply_restore_owner_view_syncs; }
    void debug_set_reentrancy_depth_limit_for_tests(size_t limit) { reentrancy_depth_limit_ = limit; }
    bool debug_force_reentrant_call_for_tests(server_slot & slot, const prepared_prompt_metadata & metadata);
    bool debug_force_deep_reentrant_call_for_tests(server_slot & slot, const prepared_prompt_metadata & metadata);
    bool debug_force_locked_sleep_for_tests(int sleep_ms);
    bool debug_stage34_commit_saved_payload_for_tests(
        server_slot & slot,
        server_tokens tokens,
        const prepared_prompt_metadata & metadata,
        size_t target_bytes,
        size_t draft_bytes);
    size_t debug_get_tx_save_slow_reads_for_tests(int slot_id) const;
    void debug_reset_tx_save_slow_reads_for_tests();
    void debug_set_tx_save_forced_target_bytes_for_tests(size_t bytes);
    void debug_set_tx_save_slow_read_hook_for_tests(std::function<void(int, bool)> hook);
    size_t debug_get_tx_save_second_pass_dedupes_for_tests() const;
    void debug_reset_tx_save_second_pass_dedupes_for_tests();

    // Step 8: Test accessors for cold_store and io_worker
    server_cache_store_cold & debug_cold_store_for_tests() { return cold_store; }
#ifdef LLAMA_STAGE39_LIVE_TEST_SEAM
    uint64_t debug_cache_generation_for_tests() const { return cache_generation_; }
    uint64_t debug_recovery_generation_for_tests() const { return stage39_recovery_generation_for_tests_; }
    uint64_t debug_recovery_cleanup_generation_for_tests() const { return stage39_recovery_cleanup_generation_for_tests_; }
    void debug_stage39_prepared_fault_for_tests(const std::string & fault) { stage39_requested_fault_ = fault; }
#endif
    void debug_set_cold_budget_bytes_for_tests(uint64_t bytes) {
        std::lock_guard<std::recursive_mutex> lock(cache_state_mutex_);
        cold_budget_bytes = static_cast<int64_t>(bytes);
#ifdef LLAMA_STAGE39_LIVE_TEST_SEAM
        advance_cache_generation_locked();
#endif
    }
    void debug_set_cold_accounting_for_tests(size_t payload, size_t quarantine) {
        std::lock_guard<std::recursive_mutex> lock(cache_state_mutex_);
        n_cold_payload_bytes = payload;
        n_cold_quarantine_bytes_ = quarantine;
#ifdef LLAMA_STAGE39_LIVE_TEST_SEAM
        advance_cache_generation_locked();
#endif
    }
    bool debug_demote_first_payload_for_tests() {
        for (const auto & item : payload_descriptors) {
            if (item.second.residency == payload_residency_state::hot) return tx_demote_payload(item.first);
        }
        return false;
    }
    bool debug_record_two_layer_decision_for_tests(cache_two_layer_mode mode, cache_two_layer_result result, cache_two_layer_reason reason) {
        return record_two_layer_decision(mode, result, reason, 0);
    }
    bool debug_record_cold_transaction_for_tests(cache_two_layer_mode mode, cache_cold_transaction_result result, cache_cold_transaction_reason reason) {
        return record_cold_transaction(mode, result, reason, 0);
    }
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
    // Stage 14 comprehensive fix: production-side stubs for the test
    // helpers declared in the public LLAMA_SERVER_CACHE_TESTS block. These
    // match the public signatures exactly so that the test-only code
    // paths compile out cleanly in production builds.
    bool debug_attach_payload_for_tests(server_tokens && tokens,
                                        const prepared_prompt_metadata & meta,
                                        const debug_attach_options & opts = {});
    void debug_add_entry_for_tests(server_tokens tokens, bool protected_root = false, const std::string & namespace_id = "");
    void debug_add_entry_for_tests(server_tokens tokens, bool protected_root, const std::string & namespace_id, size_t target_bytes, size_t draft_bytes);
    void debug_add_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata);
    // Stage 14 test 20 fix: 3-arg form that preserves protected_root while
    // matching the lookup's namespace computed from metadata.
    void debug_add_entry_for_tests(server_tokens tokens, const prepared_prompt_metadata & metadata, bool protected_root);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens);
    int debug_find_match_tokens_for_tests(const server_tokens & tokens, const prepared_prompt_metadata & metadata);
    // Stage 14 test 21 fix: 2-arg form that uses a literal namespace string
    // (test-only path; gated by LLAMA_SERVER_CACHE_TESTS).
    int debug_find_match_tokens_for_tests(const server_tokens & tokens, const std::string & namespace_id);
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
    std::string debug_compute_namespace_id_for_tests(const prepared_prompt_metadata & metadata) const;
    bool debug_validate_first_payload_for_tests(bool runtime_has_draft);
    bool debug_corrupt_first_payload_for_tests();
    bool debug_evict_first_payload_for_tests();
    bool debug_evict_last_payload_for_tests();
    bool debug_inject_first_payload_fault_for_tests(payload_debug_fault fault);
    bool debug_transaction_for_tests(bool runtime_has_draft, bool fail_target, bool fail_draft, bool fail_commit);
    // Stage 14 comprehensive fix: add runtime_has_draft parameter.
    bool debug_empty_preimage_draft_failure_for_tests(bool runtime_has_draft = true);
    bool debug_unsupported_empty_clear_for_tests(bool runtime_has_draft = true);
    bool debug_rollback_failure_for_tests(bool runtime_has_draft = true);
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
    // Stage 14 test_stage9 fix: see public-section comment above.
    bool debug_admit_checkpoint_for_tests(size_t target_bytes, size_t draft_bytes, int64_t token_span_end, bool bypass_workload_profile);
    // Stage 14 comprehensive fix: opts-based overload (see public section).
    bool debug_admit_checkpoint_for_tests(size_t target_bytes,
                                          size_t draft_bytes,
                                          int64_t token_span_end,
                                          const debug_attach_options & opts);
    bool debug_validate_first_checkpoint_for_tests();
    bool debug_first_checkpoint_metadata_for_tests(const std::string & boundary_id, int64_t token_span_start, int64_t token_span_end, uint64_t boundary_checksum) const;
    int debug_first_checkpoint_restore_token_count_for_tests() const;
    bool debug_corrupt_first_checkpoint_boundary_checksum_for_tests();
    bool debug_first_entry_has_checkpoint_for_tests() const;
    uint64_t debug_first_checkpoint_payload_id_for_tests() const;
    bool debug_demote_first_checkpoint_for_tests();
    int debug_select_stage9_restore_source_tokens_for_tests(server_tokens tokens, const std::string & namespace_id, cache_workload_profile profile);
    bool debug_request_stage9_checkpoint_promotion_for_tests(server_tokens tokens, const std::string & namespace_id);
    // Stage 25: production-side stubs for the transaction-layer debug
    // hooks. Match the public signatures so the test-only code paths
    // compile out cleanly in production builds.
    bool debug_run_save_transaction_for_tests(server_slot & slot, const prepared_prompt_metadata & metadata);
    hybrid_cache_controller::cache_response debug_run_restore_transaction_for_tests(server_slot & slot, const server_task & task);
    hybrid_cache_controller::cache_response debug_capture_first_payload_for_tests(bool runtime_has_draft);
    void debug_apply_restore_transaction_for_tests(server_slot & slot, const hybrid_cache_controller::cache_response & plan, bool apply_ok);
    size_t debug_get_transaction_depth_for_tests() const { return server_context_tx_depth_; }
    size_t debug_get_reentrancy_depth_limit_for_tests() const { return reentrancy_depth_limit_; }
    size_t debug_get_transaction_wait_exceeded_for_tests() const { return n_transaction_wait_exceeded; }
    size_t debug_get_apply_restore_syncs_for_tests() const { return n_apply_restore_owner_view_syncs; }
    void debug_set_reentrancy_depth_limit_for_tests(size_t limit) { reentrancy_depth_limit_ = limit; }
    bool debug_force_reentrant_call_for_tests(server_slot & slot, const prepared_prompt_metadata & metadata);
    bool debug_force_deep_reentrant_call_for_tests(server_slot & slot, const prepared_prompt_metadata & metadata);
    bool debug_force_locked_sleep_for_tests(int sleep_ms);
    bool debug_stage34_commit_saved_payload_for_tests(
        server_slot & slot,
        server_tokens tokens,
        const prepared_prompt_metadata & metadata,
        size_t target_bytes,
        size_t draft_bytes);
    size_t debug_get_tx_save_slow_reads_for_tests(int slot_id) const;
    void debug_reset_tx_save_slow_reads_for_tests();
    void debug_set_tx_save_forced_target_bytes_for_tests(size_t bytes);
    void debug_set_tx_save_slow_read_hook_for_tests(std::function<void(int, bool)> hook);
    size_t debug_get_tx_save_second_pass_dedupes_for_tests() const;
    void debug_reset_tx_save_second_pass_dedupes_for_tests();
    std::recursive_mutex & debug_get_cache_state_mutex_for_tests() { return cache_state_mutex_; }
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

    // Phase 6: Cold store and inline I/O worker
    // Stage 28 R28-BUG-04 Phase C: io_worker is now a thin synchronous
    // container (no thread, no work queue, no result queue). The inline
    // execution helpers are the only entry points.
    server_cache_store_cold cold_store;
    server_cache_io_worker io_worker;

    // Stage 25: atomic transactional cache writes.
    // The recursive mutex guards the controller's mutable state for the
    // duration of one slot request. The documented inner-call set is
    // tx_save -> tx_evict_entry, tx_restore -> tx_promote_payload (inline),
    // tx_update -> tx_evict_entry. Cross-thread reentrance is impossible
    // because the worker thread no longer mutates controller state (Option B
    // worker retirement per OQ-25-02).
    std::recursive_mutex cache_state_mutex_;

#ifdef LLAMA_STAGE39_LIVE_TEST_SEAM
    struct stage39_prepared_record {
        stage39_prepared_proof_binding binding;
        uint64_t expected_generation = 0;
        uint64_t observed_generation = 0;
        uint64_t serialized_bytes = 0;
        uint64_t staging_file_bytes = 0;
    };

    struct stage39_prepared_session {
        bool active = false;
        bool terminal = false;
        bool success = false;
        bool checkpoint_attempted = false;
        bool checkpoint_prepared = false;
        bool common_sync_observed = false;
        size_t common_sync_count = 0;
        uint64_t discovery_generation = 0;
        uint64_t post_setup_generation = 0;
        uint64_t expected_step = 0;
        uint64_t expected_generation = 0;
        uint64_t exact_return_generation = 0;
        uint64_t common_sync_generation = 0;
        uint64_t final_generation = 0;
        std::string process_identity;
        std::string test_session_id;
        std::string run_id;
        std::string fault;
        std::string error;
        std::vector<std::string> mismatch_flags;
        std::vector<stage39_prepared_proof_binding> expectations;
        std::vector<stage39_prepared_record> records;
        json pre_apply_state;
        json terminal_body;
        std::string terminal_hmac;
    };

    bool stage39_live_pressure_consumed_ = false;
    bool stage39_fail_setup_after_first_write_for_tests_ = false;
    size_t stage39_fail_owner_setup_write_for_tests_ = 0;
    uint64_t cache_generation_ = 1;
    uint64_t stage39_recovery_generation_for_tests_ = 0;
    uint64_t stage39_recovery_cleanup_generation_for_tests_ = 0;
    size_t stage39_checkpoint_classification_count_ = 0;
    size_t stage39_checkpoint_publish_count_ = 0;
    size_t stage39_checkpoint_commit_count_ = 0;
    size_t stage39_checkpoint_cold_file_event_count_ = 0;
    size_t stage39_checkpoint_descriptor_mutation_count_ = 0;
    size_t stage39_checkpoint_link_mutation_count_ = 0;
    size_t stage39_explicit_generation_advance_count_ = 0;
    size_t stage39_later_kind_work_count_ = 0;
    size_t stage39_post_abort_pressure_count_ = 0;
    size_t stage39_post_abort_diagnostic_count_ = 0;
    std::array<uint8_t, 32> stage39_snapshot_nonce_{};
    stage39_prepared_session stage39_prepared_session_;
    std::string stage39_requested_fault_;
    std::string stage39_forbidden_effect_probe_;
#endif

    // Stage 25: reentrancy counter for the server-context thread. Slot
    // threads use server_slot::cache_tx_depth (defined where server_slot
    // lives). The counter is incremented at lock_guard entry and
    // decremented at lock_guard exit. OQ-25-06 chose slot context member
    // (not thread_local) so the counter persists across thread joins.
    // I-34-01: tx_save dedupes equivalent entries by token span and namespace.
    // I-34-02: tx_save slow context reads run outside this mutex.
    size_t server_context_tx_depth_ = 0;
    size_t reentrancy_depth_limit_ = 4;

    // Stage 25: bounded diagnostic threshold. The slot thread records a
    // transaction_wait_exceeded diagnostic when its wait exceeds the
    // threshold (default 500 ms; OQ-25-03). The diagnostic is bounded and
    // does not abort the wait.
    std::chrono::milliseconds transaction_wait_threshold_{500};
    size_t n_transaction_wait_exceeded = 0;
    size_t n_apply_restore_owner_view_syncs = 0;

    // Phase 6 Step 11: Per-payload promotion failure injection set
#ifdef LLAMA_SERVER_CACHE_TESTS
    std::unordered_set<uint64_t> debug_promotion_failure_payload_ids_;
    mutable std::mutex debug_tx_save_mutex_;
    std::unordered_map<int, size_t> debug_tx_save_slow_reads_by_slot_;
    size_t debug_tx_save_forced_target_bytes_ = 0;
    std::function<void(int, bool)> debug_tx_save_slow_read_hook_;
    size_t debug_tx_save_second_pass_dedupes_ = 0;
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
    size_t n_cold_quarantine_bytes_ = 0;
    bool cold_mutation_disabled_ = false;
    cold_tx_id next_cold_tx_id_ = 1;
    std::map<std::pair<uint64_t, uint8_t>, uint64_t> recovered_payload_owners_;
    bool last_demote_failure_was_capacity_ = false;
    cache_two_layer_reason last_demote_failure_reason_ = cache_two_layer_reason::io_error;
    std::unordered_map<uint64_t, size_t> cold_payload_bytes_by_id_; // per-id actual write size; lets eviction subtract exact bytes
    std::map<std::tuple<cache_two_layer_mode, cache_two_layer_result, cache_two_layer_reason>, size_t> n_two_layer_decisions_;
    std::map<std::tuple<cache_two_layer_mode, cache_cold_transaction_result, cache_cold_transaction_reason>, size_t> n_cold_transactions_;
    size_t n_protected_root_demotions = 0;         // Protected roots that were demoted
    int64_t cold_budget_bytes = -1;                // -1 = unlimited, 0 = cold writes disabled
    size_t n_cold_demotions_skipped = 0;
    std::map<std::string, size_t> n_cold_evictions_by_shape;
    std::map<std::string, size_t> n_cold_demotions_skipped_by_shape;

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
    size_t n_cold_cleanup_startup_orphan = 0;
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
    std::map<std::string, size_t> n_restore_misses_by_shape;
    std::map<std::string, size_t> n_prompt_evidence_records_by_shape;
    std::map<std::string, size_t> n_prefix_candidates_by_shape;
    std::map<std::string, size_t> n_checkpoint_admissions_by_shape;
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

    // Stage 25: developer-time guard. Asserts the calling thread already
    // holds cache_state_mutex_. Uses try_lock + immediate unlock so the
    // helper compiles to a no-op in release builds that define NDEBUG.
    void tx_assert_mutex_held() const;
#ifdef LLAMA_SERVER_CACHE_TESTS
    void debug_note_tx_save_slow_read_for_tests(int slot_id, bool draft);
    void debug_note_tx_save_second_pass_dedupe_for_tests();
#endif
    // Stage 25: developer-time guard for unexpected reentrance. Called from
    // helper entry points that must NOT run inside a transaction except via
    // the documented inner-call set. Release build is a no-op.
    void tx_assert_not_reentrant() const;

    // Stage 28 R28-BUG-02: scan the cold store root for .cold files whose
    // payload_id is not present in cold_payload_bytes_by_id_ and delete
    // them. Called from the constructor after cold_store.configure()
    // succeeds. Holds cache_state_mutex_ (recursive, so nested calls work).
    void reconcile_cold_store_with_per_id_map();

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
        bool fail_after_descriptor = false,
        bool bypass_workload_profile = false);
    bool admit_latest_checkpoint(
        hybrid_cache_entry & entry,
        const common_prompt_checkpoint & checkpoint,
        bool runtime_has_draft,
        std::string * failure_reason = nullptr,
        bool bypass_workload_profile = false);
    bool admit_latest_checkpoint_and_store_metadata(
        hybrid_cache_entry & entry,
        const std::list<common_prompt_checkpoint> & checkpoints,
        bool runtime_has_draft,
        std::string * failure_reason = nullptr,
        bool bypass_workload_profile = false);
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
        std::string * failure_reason = nullptr,
        bool bypass_workload_profile = false) const;
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
    std::list<hybrid_cache_entry>::iterator find_prefix_candidate(
        const server_tokens & tokens_new,
        const std::string & namespace_id,
        cache_workload_profile profile);
    cache_restore_miss_reason classify_restore_miss(
        const server_tokens & tokens_new,
        const std::string & namespace_id) const;
    void record_restore_miss(
        cache_restore_miss_reason reason,
        cache_workload_profile profile,
        payload_pair_state pair_state,
        const server_task & task,
        const std::string & lookup_namespace_id,
        const hybrid_cache_entry * prefix_candidate = nullptr);
    void record_prompt_evidence(
        bool hit,
        cache_restore_miss_reason reason,
        cache_workload_profile profile,
        payload_pair_state pair_state,
        const server_task & task,
        const std::string & lookup_namespace_id,
        const hybrid_cache_entry * prefix_candidate = nullptr);
    void record_prefix_candidate(const char * result, const char * reason);
    cache_restore_miss_reason validate_strict_prefix_candidate(
        const hybrid_cache_entry & entry,
        const server_task & task,
        cache_workload_profile profile,
        payload_pair_state pair_state,
        payload_kind selected_payload_kind) const;
    bool cold_budget_allows_write(size_t bytes) const;
    bool cold_budget_make_room(size_t bytes, const payload_descriptor & descriptor);
    size_t calculate_demoting_payload_bytes() const;
    void record_cold_demotion_skipped(const payload_descriptor & descriptor, const char * reason);
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
    bool record_two_layer_decision(cache_two_layer_mode mode, cache_two_layer_result result, cache_two_layer_reason reason, uint64_t payload_id);
    bool record_cold_transaction(cache_two_layer_mode mode, cache_cold_transaction_result result, cache_cold_transaction_reason reason, cold_tx_id tx_id);

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
    struct policy_candidate_enumeration {
        std::vector<server_cache_policy_candidate> candidates;
        size_t blocked_references = 0;
    };
    policy_candidate_enumeration enumerate_hot_policy_candidates_core();
    std::vector<server_cache_policy_candidate> build_policy_candidates();
    std::vector<uint64_t> enumerate_cold_policy_candidates_core(uint64_t incoming_owner_entry_id) const;
#ifdef LLAMA_STAGE39_LIVE_TEST_SEAM
    bool stage39_validate_inventory_integrity(std::string & error) const;
    json stage39_build_snapshot_locked(std::string & error);
    std::string stage39_snapshot_token_locked(const json & snapshot) const;
    std::string stage39_process_identity_locked() const;
    json stage39_build_runtime_proof_locked(const std::vector<uint64_t> & payload_ids, std::string & error);
    bool stage39_capture_prepared_locked(const payload_descriptor & descriptor,
        const hot_payload_record & record, const prepared_cold_object & prepared);
    bool stage39_prepared_abort_locked() const;
    void stage39_latch_prepared_abort_locked(const char * error, const char * mismatch);
    bool stage39_midpoint_after_exact_locked(const hybrid_cache_entry & entry);
    void stage39_record_common_sync_locked(const hybrid_cache_entry & entry);
    void stage39_capture_prepared_baseline_locked(const hybrid_cache_entry & entry);
    void stage39_finalize_prepared_locked(const hybrid_cache_entry * entry);
    stage39_live_pressure_result stage39_retrieve_prepared_locked(const stage39_live_pressure_request & request);
    void advance_cache_generation_locked(bool explicit_advance = true);
#endif
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
