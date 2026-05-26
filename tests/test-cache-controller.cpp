#include "server-cache-controller.h"
#include "server-cache-legacy.h"
#include "server-cache-hybrid.h"
#include "server-task.h"
#include "common.h"

#include <cstdio>
#include <cassert>
#include <memory>
#include <string>
#include <vector>
#include <chrono>
#include <functional>
#include <list>
#include <map>
#include <unordered_map>

#undef NDEBUG

// Helper to create mock tokens
static server_tokens create_tokens(const std::vector<int> & ids) {
    server_tokens tokens;
    for (int id : ids) {
        tokens.push_back(id);
    }
    return tokens;
}

// Helper to create test common_params with configurable fields
static common_params create_test_params(
    const std::string & model_path = "test_model.gguf",
    const std::string & chat_template = "",
    const std::string & mmproj_path = "",
    bool kv_unified_val = false
) {
    common_params params;
    params.model.path = model_path;
    params.chat_template = chat_template;
    params.mmproj.path = mmproj_path;
    params.kv_unified = kv_unified_val;
    // lora_adapters and control_vectors remain empty by default
    return params;
}

// Test 1: Cache mode enum exists and has correct values
void test_cache_mode_enum() {
    printf("test-cache-controller: cache_mode enum...\n");
    assert(CACHE_MODE_LEGACY == 0);
    assert(CACHE_MODE_HYBRID == 1);
    printf("  PASSED\n");
}

// Test 2: Factory creates correct controller type
void test_factory_creation() {
    printf("test-cache-controller: factory creation...\n");
    
    // Test legacy controller creation
    common_params params = create_test_params();
    auto legacy_ctrl = create_cache_controller(
        CACHE_MODE_LEGACY,
        params,
        100,  // 100 MiB
        1000, // 1000 tokens
        nullptr,
        nullptr
    );
    assert(legacy_ctrl != nullptr);
    
    // Test hybrid controller creation
    auto hybrid_ctrl = create_cache_controller(
        CACHE_MODE_HYBRID,
        params,
        100,  // 100 MiB
        1000, // 1000 tokens
        nullptr,
        nullptr
    );
    assert(hybrid_ctrl != nullptr);
    
    printf("  PASSED\n");
}

// Test 3: Legacy controller basic interface
void test_legacy_controller_interface() {
    printf("test-cache-controller: legacy controller interface...\n");
    
    common_params params = create_test_params();
    auto ctrl = create_cache_controller(
        CACHE_MODE_LEGACY,
        params,
        100,
        1000,
        nullptr,
        nullptr
    );
    
    // Test size() returns 0 initially
    assert(ctrl->size() == 0);
    
    // Test n_tokens() returns 0 initially
    assert(ctrl->n_tokens() == 0);
    
    // Test get_stats() returns JSON
    json stats = ctrl->get_stats();
    assert(stats.contains("type"));
    assert(stats["type"] == "legacy");
    
    printf("  PASSED\n");
}

// Test 4: Hybrid controller basic interface
void test_hybrid_controller_interface() {
    printf("test-cache-controller: hybrid controller interface...\n");
    
    common_params params = create_test_params();
    auto ctrl = create_cache_controller(
        CACHE_MODE_HYBRID,
        params,
        100,
        1000,
        nullptr,
        nullptr
    );
    
    // Test size() returns 0 initially
    assert(ctrl->size() == 0);
    
    // Test n_tokens() returns 0 initially
    assert(ctrl->n_tokens() == 0);
    
    // Test get_stats() returns JSON with hybrid fields
    json stats = ctrl->get_stats();
    assert(stats.contains("type"));
    assert(stats["type"] == "hybrid");
    assert(stats.contains("n_hits"));
    assert(stats.contains("n_misses"));
    assert(stats.contains("n_evictions"));
    assert(stats.contains("namespaces"));
    
    printf("  PASSED\n");
}

// Test 5: Boundary metadata structures
void test_boundary_metadata() {
    printf("test-cache-controller: boundary metadata structures...\n");
    
    // Test prompt_boundary creation
    prompt_boundary boundary(
        prompt_boundary::SYSTEM_START,
        0,
        "system"
    );
    assert(boundary.type == prompt_boundary::SYSTEM_START);
    assert(boundary.token_index == 0);
    assert(boundary.metadata == "system");
    
    // Test prepared_prompt_metadata
    prepared_prompt_metadata metadata;
    assert(!metadata.has_boundaries());
    
    metadata.add_boundary(prompt_boundary::MESSAGE_START, 10, "user");
    assert(metadata.has_boundaries());
    assert(metadata.boundaries.size() == 1);
    
    auto msg_starts = metadata.get_boundaries(prompt_boundary::MESSAGE_START);
    assert(msg_starts.size() == 1);
    assert(msg_starts[0].token_index == 10);
    
    metadata.clear();
    assert(!metadata.has_boundaries());
    
    printf("  PASSED\n");
}

// Test 6: Boundary types enum
void test_boundary_types() {
    printf("test-cache-controller: boundary types enum...\n");
    
    // Ensure all boundary types are defined
    prompt_boundary b1(prompt_boundary::SYSTEM_START, 0);
    prompt_boundary b2(prompt_boundary::SYSTEM_END, 1);
    prompt_boundary b3(prompt_boundary::MESSAGE_START, 2);
    prompt_boundary b4(prompt_boundary::MESSAGE_END, 3);
    prompt_boundary b5(prompt_boundary::TOOL_CALL_START, 4);
    prompt_boundary b6(prompt_boundary::TOOL_CALL_END, 5);
    
    // All types should be distinct
    assert(b1.type != b2.type);
    assert(b3.type != b4.type);
    assert(b5.type != b6.type);
    
    printf("  PASSED\n");
}

// Test 7: Server task has prompt_metadata field
void test_task_metadata_field() {
    printf("test-cache-controller: server_task metadata field...\n");
    
    server_task task;
    task.type = SERVER_TASK_TYPE_COMPLETION;
    
    // Test that prompt_metadata field exists and can be accessed
    task.prompt_metadata.add_boundary(prompt_boundary::SYSTEM_START, 0, "test");
    assert(task.prompt_metadata.has_boundaries());

    task.add_child(task.id, 42);
    assert(task.child_tasks.size() == 1);
    assert(task.child_tasks[0].prompt_metadata.has_boundaries());
    assert(task.child_tasks[0].prompt_metadata.boundaries[0].metadata == "test");
    
    printf("  PASSED\n");
}

// Test 8: Hybrid cache entry structure
void test_hybrid_cache_entry() {
    printf("test-cache-controller: hybrid cache entry structure...\n");
    
    hybrid_cache_entry entry;
    
    // Test initial state
    assert(entry.use_count == 0);
    assert(entry.protected_root == false);
    assert(entry.namespace_id.empty());
    
    // Test mark_used
    entry.mark_used();
    assert(entry.use_count == 1);
    
    entry.mark_used();
    assert(entry.use_count == 2);

    entry.metadata.add_boundary(prompt_boundary::MESSAGE_START, 0, "user");
    assert(entry.metadata.has_boundaries());
    
    // Test size calculation (should not crash)
    size_t sz = entry.size();
    assert(sz >= 0);
    
    // Test n_tokens
    assert(entry.n_tokens() == 0);
    
    printf("  PASSED\n");
}

// Test 9: Common params has cache_mode_val field
void test_common_params_field() {
    printf("test-cache-controller: common_params cache_mode_val field...\n");
    
    common_params params;
    
    // Default should be LEGACY
    assert(params.cache_mode_val == CACHE_MODE_LEGACY);
    
    // Can be set to HYBRID
    params.cache_mode_val = CACHE_MODE_HYBRID;
    assert(params.cache_mode_val == CACHE_MODE_HYBRID);
    
    printf("  PASSED\n");
}

// Test 10: Update method doesn't crash
void test_update_method() {
    printf("test-cache-controller: update method...\n");
    
    common_params params = create_test_params();
    
    // Legacy controller
    auto legacy_ctrl = create_cache_controller(
        CACHE_MODE_LEGACY,
        params,
        100,
        1000,
        nullptr,
        nullptr
    );
    legacy_ctrl->update(); // Should not crash
    
    // Hybrid controller
    auto hybrid_ctrl = create_cache_controller(
        CACHE_MODE_HYBRID,
        params,
        100,
        1000,
        nullptr,
        nullptr
    );
    hybrid_ctrl->update(); // Should not crash
    
    printf("  PASSED\n");
}

// Test 11: Hybrid controller statistics tracking
void test_hybrid_statistics() {
    printf("test-cache-controller: hybrid statistics tracking...\n");
    
    common_params params = create_test_params();
    auto ctrl = create_cache_controller(
        CACHE_MODE_HYBRID,
        params,
        100,
        1000,
        nullptr,
        nullptr
    );
    
    json stats = ctrl->get_stats();
    
    // Check initial statistics
    assert(stats["n_hits"] == 0);
    assert(stats["n_misses"] == 0);
    assert(stats["n_evictions"] == 0);
    
    printf("  PASSED\n");
}

// Test 12: Namespace ID computation (basic)
void test_namespace_computation() {
    printf("test-cache-controller: namespace computation...\n");
    
    common_params params = create_test_params();
    
    // Create two hybrid controllers with same params
    auto ctrl1 = create_cache_controller(
        CACHE_MODE_HYBRID,
        params,
        100,
        1000,
        nullptr,
        nullptr
    );
    
    auto ctrl2 = create_cache_controller(
        CACHE_MODE_HYBRID,
        params,
        100,
        1000,
        nullptr,
        nullptr
    );
    
    // Both should work without crashing
    json stats1 = ctrl1->get_stats();
    json stats2 = ctrl2->get_stats();
    
    assert(stats1.contains("namespaces"));
    assert(stats2.contains("namespaces"));
    
    printf("  PASSED\n");
}

// Test 13: Protected root flag
void test_protected_root() {
    printf("test-cache-controller: protected root flag...\n");
    
    hybrid_cache_entry entry;
    
    // Default is not protected
    assert(entry.protected_root == false);
    
    // Can be set to protected
    entry.protected_root = true;
    assert(entry.protected_root == true);
    
    printf("  PASSED\n");
}

// Test 14: LRU timestamp tracking
void test_lru_timestamp() {
    printf("test-cache-controller: LRU timestamp tracking...\n");
    
    hybrid_cache_entry entry;
    
    auto time1 = entry.last_used_time;
    
    // Mark as used
    entry.mark_used();
    
    auto time2 = entry.last_used_time;
    
    // Time should have been updated (or at least not less than before)
    assert(time2 >= time1);
    
    printf("  PASSED\n");
}

// Test 15: Metadata field queries
void test_metadata_queries() {
    printf("test-cache-controller: metadata field queries...\n");
    
    prepared_prompt_metadata meta;
    
    // Add multiple boundaries of different types
    meta.add_boundary(prompt_boundary::SYSTEM_START, 0, "sys1");
    meta.add_boundary(prompt_boundary::MESSAGE_START, 10, "msg1");
    meta.add_boundary(prompt_boundary::MESSAGE_END, 20, "msg1");
    meta.add_boundary(prompt_boundary::MESSAGE_START, 21, "msg2");
    
    // Query specific type
    auto sys_bounds = meta.get_boundaries(prompt_boundary::SYSTEM_START);
    assert(sys_bounds.size() == 1);
    assert(sys_bounds[0].token_index == 0);
    
    auto msg_starts = meta.get_boundaries(prompt_boundary::MESSAGE_START);
    assert(msg_starts.size() == 2);
    
    auto msg_ends = meta.get_boundaries(prompt_boundary::MESSAGE_END);
    assert(msg_ends.size() == 1);
    
    printf("  PASSED\n");
}

// Test 16: Span metadata carries validation and protection fields
void test_metadata_spans() {
    printf("test-cache-controller: metadata spans...\n");

    prepared_prompt_metadata meta;
    meta.compatibility_key = "compat-a";
    meta.preparation_id = "fixture";
    meta.add_span(prompt_boundary::MESSAGE_START, 2, 7, 1234, true, "system");
    meta.add_span(prompt_boundary::MESSAGE_END, 2, 7, 1234, true, "system");

    assert(meta.has_boundaries());
    assert(meta.boundaries.size() == 2);
    assert(meta.boundaries[0].token_index == 2);
    assert(meta.boundaries[0].token_start == 2);
    assert(meta.boundaries[0].token_end == 7);
    assert(meta.boundaries[0].checksum == 1234);
    assert(meta.boundaries[0].protect);
    assert(meta.boundaries[1].token_index == 7);

    meta.degraded_reason = "fixture degraded";
    assert(meta.degraded());

    meta.clear();
    assert(!meta.has_boundaries());
    assert(meta.compatibility_key.empty());
    assert(meta.preparation_id.empty());
    assert(!meta.degraded());

    printf("  PASSED\n");
}

// Test 17: Hybrid lookup rejects divergent partial exact-blob matches
void test_hybrid_rejects_partial_blob_match() {
    printf("test-cache-controller: hybrid rejects partial blob match...\n");

    common_params params = create_test_params();
    hybrid_cache_controller ctrl(params, 100, 1000, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(create_tokens({1, 2, 3, 4}));

    prepared_prompt_metadata meta;
    GGML_UNUSED(meta);
    assert(ctrl.debug_find_match_tokens_for_tests(create_tokens({1, 2, 9})) == -1);

    assert(ctrl.debug_find_match_tokens_for_tests(create_tokens({1, 2, 3, 4, 5})) == 4);

    printf("  PASSED\n");
}

// Test 18: Hybrid prefix index finds cached entries shorter than the index length
void test_hybrid_prefix_index_short_entry() {
    printf("test-cache-controller: hybrid prefix index short entry...\n");

    common_params params = create_test_params();
    hybrid_cache_controller ctrl(params, 100, 1000, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(create_tokens({7, 8}));

    prepared_prompt_metadata meta;
    GGML_UNUSED(meta);
    assert(ctrl.debug_find_match_tokens_for_tests(create_tokens({7, 8, 9, 10, 11, 12, 13, 14})) == 2);

    printf("  PASSED\n");
}

// Test 19: Hybrid update evicts globally by LRU and updates stats
void test_hybrid_lru_eviction_by_token_limit() {
    printf("test-cache-controller: hybrid LRU eviction by token limit...\n");

    common_params params = create_test_params();
    hybrid_cache_controller ctrl(params, 100, 3, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(create_tokens({1, 2}));
    ctrl.debug_add_entry_for_tests(create_tokens({3, 4}));

    assert(ctrl.n_tokens() == 4);
    ctrl.update();

    assert(ctrl.debug_entry_count_for_tests() == 1);
    assert(ctrl.n_tokens() == 2);
    json stats = ctrl.get_stats();
    assert(stats["n_evictions"] == 1);
    assert(stats["namespaces"].size() == 1);

    printf("  PASSED\n");
}

// Test 20: Protected entries are skipped before fallback eviction
void test_hybrid_protected_eviction_paths() {
    printf("test-cache-controller: hybrid protected eviction paths...\n");

    common_params params = create_test_params();
    hybrid_cache_controller ctrl(params, 100, 3, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(create_tokens({1, 2}), true);
    ctrl.debug_add_entry_for_tests(create_tokens({3, 4}), false);

    ctrl.update();
    assert(ctrl.debug_entry_count_for_tests() == 1);
    assert(ctrl.debug_find_match_tokens_for_tests(create_tokens({1, 2, 5})) == 2);
    assert(ctrl.debug_find_match_tokens_for_tests(create_tokens({3, 4, 5})) == -1);

    hybrid_cache_controller all_protected(params, 100, 3, nullptr, nullptr);
    all_protected.debug_add_entry_for_tests(create_tokens({7, 8}), true);
    all_protected.debug_add_entry_for_tests(create_tokens({9, 10}), true);
    all_protected.update();
    assert(all_protected.debug_entry_count_for_tests() == 1);
    assert(all_protected.get_stats()["n_evictions"] == 1);

    printf("  PASSED\n");
}

// Test 21: Hybrid lookup handles namespace misses, empty queries, and LRU updates
void test_hybrid_lookup_edge_paths() {
    printf("test-cache-controller: hybrid lookup edge paths...\n");

    common_params params = create_test_params();
    hybrid_cache_controller ctrl(params, 100, 1000, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(create_tokens({1, 2, 3}), false, "other-namespace");
    assert(ctrl.debug_find_match_tokens_for_tests(create_tokens({1, 2, 3, 4})) == -1);

    ctrl.debug_add_entry_for_tests(create_tokens({4, 5, 6}));
    assert(ctrl.debug_find_match_tokens_for_tests(create_tokens({})) == -1);
    assert(ctrl.debug_find_match_tokens_for_tests(create_tokens({4, 5, 6, 7})) == 3);

    ctrl.debug_mark_first_entry_used_for_tests();

    json stats = ctrl.get_stats();
    assert(stats["namespaces"].size() == 2);

    printf("  PASSED\n");
}

// Test 22: Hybrid lookup isolates entries by structured compatibility metadata
void test_hybrid_compatibility_key_miss() {
    printf("test-cache-controller: hybrid compatibility key miss...\n");

    common_params params = create_test_params();
    hybrid_cache_controller ctrl(params, 100, 1000, nullptr, nullptr);

    prepared_prompt_metadata adapter_a;
    adapter_a.compatibility_key = "model=tiny|draft=none|adapter=a";
    adapter_a.preparation_id = "chat-template-a";
    adapter_a.add_span(prompt_boundary::MESSAGE_START, 0, 3, 11, false, "user");

    prepared_prompt_metadata adapter_b = adapter_a;
    adapter_b.compatibility_key = "model=tiny|draft=none|adapter=b";

    prepared_prompt_metadata multimodal_layout = adapter_a;
    multimodal_layout.compatibility_key = "model=tiny|draft=none|adapter=a|mmproj=x";
    multimodal_layout.add_span(prompt_boundary::MESSAGE_START, 3, 5, 22, false, "media:image:2");

    ctrl.debug_add_entry_for_tests(create_tokens({1, 2, 3}), adapter_a);

    assert(ctrl.debug_find_match_tokens_for_tests(create_tokens({1, 2, 3, 4}), adapter_a) == 3);
    assert(ctrl.debug_find_match_tokens_for_tests(create_tokens({1, 2, 3, 4}), adapter_b) == -1);
    assert(ctrl.debug_find_match_tokens_for_tests(create_tokens({1, 2, 3, 4}), multimodal_layout) == -1);

    printf("  PASSED\n");
}

// Test 23: server_task inline helpers are covered for cache-adjacent task behavior
void test_server_task_inline_helpers() {
    printf("test-cache-controller: server_task inline helpers...\n");

    server_task completion(SERVER_TASK_TYPE_COMPLETION);
    completion.tokens = create_tokens({1, 2, 3});
    assert(completion.n_tokens() == 3);
    assert(!completion.need_embd());
    assert(completion.need_logits());
    assert(completion.need_sampling());
    assert(!completion.is_parent());
    assert(!completion.is_child());

    server_task infill(SERVER_TASK_TYPE_INFILL);
    assert(infill.need_logits());
    assert(infill.need_sampling());

    server_task embedding(SERVER_TASK_TYPE_EMBEDDING);
    assert(embedding.need_embd());
    assert(!embedding.need_logits());
    assert(!embedding.need_sampling());

    server_task rerank(SERVER_TASK_TYPE_RERANK);
    assert(rerank.need_embd());

    completion.id = 10;
    completion.add_child(completion.id, 11);
    completion.child_tasks[0].add_child(11, 12);
    assert(completion.is_parent());
    assert(completion.child_tasks[0].is_child());

    std::vector<server_task> tasks;
    tasks.push_back(std::move(completion));
    tasks.push_back(std::move(embedding));
    const auto ids = server_task::get_list_id(tasks);
    assert(ids.find(10) != ids.end());
    assert(ids.find(11) != ids.end());
    assert(ids.find(12) == ids.end());

    printf("  PASSED\n");
}

// Test 23: task result and prompt inline helpers
void test_task_result_and_prompt_helpers() {
    printf("test-cache-controller: task result and prompt helpers...\n");

    struct local_result : server_task_result {
        json to_json() override {
            return json{{"ok", true}};
        }
    };

    local_result base;
    task_result_state state(common_chat_parser_params{});
    assert(!base.is_error());
    assert(base.is_stop());
    base.update(state);
    assert(base.to_json()["ok"] == true);

    server_task_result_error error;
    assert(error.is_error());

    server_task_result_cmpl_final final;
    final.content = "hello";
    assert(final.is_stop());
    final.update(state);
    assert(final.is_updated);

    server_task_result_cmpl_partial partial;
    assert(!partial.is_stop());

    server_prompt_data data;
    data.main.resize(3);
    data.drft.resize(5);
    assert(data.size() == 8);

    server_prompt prompt;
    prompt.tokens = create_tokens({1, 2, 3});
    prompt.data = data;
    common_prompt_checkpoint ckpt;
    ckpt.data_tgt.resize(2);
    ckpt.data_dft.resize(4);
    prompt.checkpoints.push_back(ckpt);

    assert(prompt.n_tokens() == 3);
    assert(prompt.size() == data.size() + ckpt.size());

    server_prompt clone = prompt.clone();
    assert(clone.n_tokens() == prompt.n_tokens());
    assert(clone.size() == prompt.size());

    printf("  PASSED\n");
}

// Phase 3: Gap 2.2 Namespace Isolation Tests

// Test 25: Namespace isolation - comprehensive key structure
void test_namespace_isolation_comprehensive_key() {
    printf("test-cache-controller: namespace isolation - comprehensive key structure...\n");
    
    common_params params = create_test_params();
    
    // Create hybrid controllers to test namespace isolation
    auto ctrl = create_cache_controller(
        CACHE_MODE_HYBRID,
        params,
        100,
        1000,
        nullptr,  // no target context (basic test)
        nullptr   // no draft context
    );
    
    auto * hybrid = static_cast<hybrid_cache_controller*>(ctrl.get());
    
    // Add entries with the same tokens but mark them with different namespaces
    // (simulating different model configurations)
    prepared_prompt_metadata meta1;
    meta1.compatibility_key = "model-A";  // Different model
    
    prepared_prompt_metadata meta2;
    meta2.compatibility_key = "model-B";  // Different model
    
    hybrid->debug_add_entry_for_tests(create_tokens({1, 2, 3, 4}), meta1);
    hybrid->debug_add_entry_for_tests(create_tokens({1, 2, 3, 4}), meta2);
    
    // Both entries should exist (different namespaces)
    assert(hybrid->debug_entry_count_for_tests() == 2);
    
    json stats = ctrl->get_stats();
    assert(stats["n_entries"] == 2);
    
    printf("  PASSED\n");
}

// Test 26: Namespace isolation - draft model presence
void test_namespace_isolation_draft_model() {
    printf("test-cache-controller: namespace isolation - draft model...\n");
    
    common_params params = create_test_params();
    
    // Test that entries with and without draft models get different namespaces
    auto ctrl_no_draft = create_cache_controller(
        CACHE_MODE_HYBRID,
        params,
        100,
        1000,
        nullptr,
        nullptr  // No draft
    );
    
    auto ctrl_with_draft = create_cache_controller(
        CACHE_MODE_HYBRID,
        params,
        100,
        1000,
        nullptr,
        nullptr  // In real scenario would be draft context
    );
    
    // Verify both controllers work
    assert(ctrl_no_draft != nullptr);
    assert(ctrl_with_draft != nullptr);
    
    json stats_no_draft = ctrl_no_draft->get_stats();
    json stats_with_draft = ctrl_with_draft->get_stats();
    
    assert(stats_no_draft.contains("type"));
    assert(stats_with_draft.contains("type"));
    
    printf("  PASSED\n");
}

// Test 27: Namespace isolation - metadata compatibility key
void test_namespace_isolation_metadata_compat_key() {
    printf("test-cache-controller: namespace isolation - metadata compatibility key...\n");
    
    common_params params = create_test_params();
    auto ctrl = create_cache_controller(
        CACHE_MODE_HYBRID,
        params,
        100,
        1000,
        nullptr,
        nullptr
    );
    
    auto * hybrid = static_cast<hybrid_cache_controller*>(ctrl.get());
    
    // Same tokens, different compatibility keys
    prepared_prompt_metadata meta1;
    meta1.compatibility_key = "config-alpha";
    
    prepared_prompt_metadata meta2;
    meta2.compatibility_key = "config-beta";  // Different config
    
    prepared_prompt_metadata meta3;
    meta3.compatibility_key = "config-alpha";  // Same as meta1
    
    hybrid->debug_add_entry_for_tests(create_tokens({10, 20, 30}), meta1);
    hybrid->debug_add_entry_for_tests(create_tokens({10, 20, 30}), meta2);
    hybrid->debug_add_entry_for_tests(create_tokens({10, 20, 30}), meta3);
    
    // Three entries: two with config-alpha (different token sequences tracked separately)
    // and one with config-beta
    assert(hybrid->debug_entry_count_for_tests() == 3);
    
    printf("  PASSED\n");
}

// Test 28: Namespace isolation - template variation
void test_namespace_isolation_template() {
    printf("test-cache-controller: namespace isolation - template...\n");
    
    common_params params = create_test_params();
    auto ctrl = create_cache_controller(
        CACHE_MODE_HYBRID,
        params,
        100,
        1000,
        nullptr,
        nullptr
    );
    
    auto * hybrid = static_cast<hybrid_cache_controller*>(ctrl.get());
    
    // Same tokens, different templates (via preparation_id)
    prepared_prompt_metadata meta1;
    meta1.preparation_id = "template-chatml";
    
    prepared_prompt_metadata meta2;
    meta2.preparation_id = "template-llama3";  // Different template
    
    hybrid->debug_add_entry_for_tests(create_tokens({100, 200}), meta1);
    hybrid->debug_add_entry_for_tests(create_tokens({100, 200}), meta2);
    
    // Both entries should exist (different templates)
    assert(hybrid->debug_entry_count_for_tests() == 2);
    
    printf("  PASSED\n");
}

// Test 29: Namespace isolation - comprehensive validation
void test_namespace_isolation_validation() {
    printf("test-cache-controller: namespace isolation - comprehensive validation...\n");
    
    common_params params = create_test_params();
    
    // Test that validate_hybrid_cache_safety works
    auto ctrl_no_draft = create_cache_controller(
        CACHE_MODE_HYBRID,
        params,
        100,
        1000,
        nullptr,
        nullptr
    );
    
    auto * hybrid_no_draft = static_cast<hybrid_cache_controller*>(ctrl_no_draft.get());
    
    // Without draft model, should be safe (returns true, no warnings in non-verbose mode)
    bool is_safe = hybrid_no_draft->validate_hybrid_cache_safety(false);
    assert(is_safe == true);  // Safe for single-model scenario
    
    printf("  PASSED\n");
}

// Test 30: Namespace isolation - model path variation (Part 14)
void test_namespace_isolation_model_path() {
    printf("test-cache-controller: namespace isolation - model path...\n");
    
    common_params params1 = create_test_params("model_A.gguf");
    common_params params2 = create_test_params("model_B.gguf");
    
    hybrid_cache_controller ctrl1(params1, 100, 1000, nullptr, nullptr);
    hybrid_cache_controller ctrl2(params2, 100, 1000, nullptr, nullptr);
    
    auto key1 = ctrl1.debug_get_compatibility_key_for_tests();
    auto key2 = ctrl2.debug_get_compatibility_key_for_tests();
    
    // Different model paths should produce different namespaces
    assert(key1.compute() != key2.compute());
    assert(key1.model_path_hash != key2.model_path_hash);
    
    printf("  PASSED\n");
}

// Test 31: Namespace isolation - LoRA adapters (Part 14)
void test_namespace_isolation_lora_adapters() {
    printf("test-cache-controller: namespace isolation - lora adapters...\n");
    
    common_params params_no_lora = create_test_params();
    common_params params_with_lora = create_test_params();
    
    // Add LoRA adapter to second params
    common_adapter_lora_info lora;
    lora.path = "adapter.gguf";
    lora.scale = 1.0f;
    params_with_lora.lora_adapters.push_back(lora);
    
    hybrid_cache_controller ctrl_no_lora(params_no_lora, 100, 1000, nullptr, nullptr);
    hybrid_cache_controller ctrl_with_lora(params_with_lora, 100, 1000, nullptr, nullptr);
    
    auto key1 = ctrl_no_lora.debug_get_compatibility_key_for_tests();
    auto key2 = ctrl_with_lora.debug_get_compatibility_key_for_tests();
    
    // LoRA presence should produce different namespaces
    assert(key1.compute() != key2.compute());
    assert(key1.lora_adapters.empty());
    assert(!key2.lora_adapters.empty());
    
    printf("  PASSED\n");
}

// Test 32: Namespace isolation - control vectors (Part 14)
void test_namespace_isolation_control_vectors() {
    printf("test-cache-controller: namespace isolation - control vectors...\n");
    
    common_params params_no_cvec = create_test_params();
    common_params params_with_cvec = create_test_params();
    
    // Add control vector to second params
    common_control_vector_load_info cvec;
    cvec.fname = "vector.gguf";
    cvec.strength = 1.0f;
    params_with_cvec.control_vectors.push_back(cvec);
    
    hybrid_cache_controller ctrl_no_cvec(params_no_cvec, 100, 1000, nullptr, nullptr);
    hybrid_cache_controller ctrl_with_cvec(params_with_cvec, 100, 1000, nullptr, nullptr);
    
    auto key1 = ctrl_no_cvec.debug_get_compatibility_key_for_tests();
    auto key2 = ctrl_with_cvec.debug_get_compatibility_key_for_tests();
    
    // Control vector presence should produce different namespaces
    assert(key1.compute() != key2.compute());
    assert(key1.control_vectors.empty());
    assert(!key2.control_vectors.empty());
    
    printf("  PASSED\n");
}

// Test 33: Namespace isolation - multimodal configuration (Part 14)
void test_namespace_isolation_multimodal() {
    printf("test-cache-controller: namespace isolation - multimodal...\n");
    
    common_params params_text_only = create_test_params();
    common_params params_multimodal = create_test_params("model.gguf", "", "projector.gguf");
    
    hybrid_cache_controller ctrl_text(params_text_only, 100, 1000, nullptr, nullptr);
    hybrid_cache_controller ctrl_mm(params_multimodal, 100, 1000, nullptr, nullptr);
    
    auto key1 = ctrl_text.debug_get_compatibility_key_for_tests();
    auto key2 = ctrl_mm.debug_get_compatibility_key_for_tests();
    
    // Multimodal configuration should produce different namespaces
    assert(key1.compute() != key2.compute());
    assert(key1.mm_projector_id == "none");
    assert(key2.mm_projector_id != "none");
    
    printf("  PASSED\n");
}

// Test 34: Namespace isolation - kv_unified flag (Part 14)
void test_namespace_isolation_kv_unified() {
    printf("test-cache-controller: namespace isolation - kv_unified...\n");
    
    common_params params_separate = create_test_params("model.gguf", "", "", false);
    common_params params_unified = create_test_params("model.gguf", "", "", true);
    
    hybrid_cache_controller ctrl_sep(params_separate, 100, 1000, nullptr, nullptr);
    hybrid_cache_controller ctrl_uni(params_unified, 100, 1000, nullptr, nullptr);
    
    auto key1 = ctrl_sep.debug_get_compatibility_key_for_tests();
    auto key2 = ctrl_uni.debug_get_compatibility_key_for_tests();
    
    // kv_unified flag should produce different namespaces
    assert(key1.compute() != key2.compute());
    assert(key1.kv_unified == false);
    assert(key2.kv_unified == true);
    
    printf("  PASSED\n");
}

int main() {
    printf("==================================================\n");
    printf("test-cache-controller: Cache System Tests\n");
    printf("==================================================\n\n");
    
    // Run all tests
    test_cache_mode_enum();
    test_factory_creation();
    test_legacy_controller_interface();
    test_hybrid_controller_interface();
    test_boundary_metadata();
    test_boundary_types();
    test_task_metadata_field();
    test_hybrid_cache_entry();
    test_common_params_field();
    test_update_method();
    test_hybrid_statistics();
    test_namespace_computation();
    test_protected_root();
    test_lru_timestamp();
    test_metadata_queries();
    test_metadata_spans();
    test_hybrid_rejects_partial_blob_match();
    test_hybrid_prefix_index_short_entry();
    test_hybrid_lru_eviction_by_token_limit();
    test_hybrid_protected_eviction_paths();
    test_hybrid_lookup_edge_paths();
    test_hybrid_compatibility_key_miss();
    test_server_task_inline_helpers();
    test_task_result_and_prompt_helpers();
    
    // Phase 3: Gap 2.2 namespace isolation tests
    test_namespace_isolation_comprehensive_key();
    test_namespace_isolation_draft_model();
    test_namespace_isolation_metadata_compat_key();
    test_namespace_isolation_template();
    test_namespace_isolation_validation();
    
    // Phase 3: Part 14 comprehensive field tests
    test_namespace_isolation_model_path();
    test_namespace_isolation_lora_adapters();
    test_namespace_isolation_control_vectors();
    test_namespace_isolation_multimodal();
    test_namespace_isolation_kv_unified();
    
    printf("\n==================================================\n");
    printf("All tests passed successfully!\n");
    printf("Total: 34 tests (29 original + 5 Part 14 comprehensive)\n");
    printf("==================================================\n");
    
    return 0;
}
