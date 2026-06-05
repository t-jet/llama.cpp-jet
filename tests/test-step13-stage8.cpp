// Stage 8 focused tests: metadata-only nodes and re-materialization
// Steps 8.1 through 8.13
//
// Build: cmake --build build --config Release --target test-step13-stage8 -j 4
// Run:   ctest --test-dir build -C Release -R test-step13-stage8 --output-on-failure

#include "server-cache-graph.h"
#include "server-cache-hybrid.h"
#include "server-cache-store-cold.h"
#include "server-common.h"

#include <algorithm>
#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <map>
#include <set>
#include <string>
#include <thread>
#include <vector>

#define TEST_ASSERT(cond) \
    do { \
        if (!(cond)) { \
            fprintf(stderr, "TEST FAILED: %s at %s:%d\n", __func__, __FILE__, __LINE__); \
            exit(1); \
        } \
    } while (0)

// ============================================================================
// Helpers
// ============================================================================

static std::vector<llama_token> tokens(std::initializer_list<int> values) {
    std::vector<llama_token> out;
    for (int value : values) {
        out.push_back(static_cast<llama_token>(value));
    }
    return out;
}

static server_tokens server_test_tokens(std::initializer_list<int> values) {
    server_tokens out;
    for (int value : values) {
        out.push_back(value);
    }
    return out;
}

static common_params test_params() {
    common_params params;
    params.model.path = "stage8-test-model.gguf";
    return params;
}

// ============================================================================
// Step 8.1: Payload eviction with metadata-only retention
// ============================================================================

static void test_evict_unreferenced_node() {
    printf("step8.1: evict unreferenced node, verify is_metadata_only...\n");
    branch_forest_index forest;
    const uint64_t node = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    TEST_ASSERT(node != 0);

    // Set payload fields as if a payload was attached
    branch_node * n = forest.get_node(node);
    TEST_ASSERT(n != nullptr);
    n->exact_blob_payload_id = 100;
    n->resident_payload_bytes = 1024;
    n->has_target_payload = true;
    n->is_metadata_only = false;

    // Evict payload
    TEST_ASSERT(forest.evict_payload(node));
    TEST_ASSERT(forest.is_metadata_only_node(node));
    TEST_ASSERT(forest.get_payload_absent_reason(node) == branch_node::payload_absent_reason::evicted_hot);

    // Verify payload fields cleared
    const branch_node * after = forest.get_node(node);
    TEST_ASSERT(after != nullptr);
    TEST_ASSERT(after->exact_blob_payload_id == 0);
    TEST_ASSERT(after->resident_payload_bytes == 0);
    TEST_ASSERT(!after->has_target_payload);
    TEST_ASSERT(!after->has_draft_payload);

    // Verify topology preserved
    TEST_ASSERT(after->node_id == node);
    TEST_ASSERT(after->namespace_id == "ns");
    TEST_ASSERT(after->parent_id == 0);
    TEST_ASSERT(after->token_span.size() == 3);
    TEST_ASSERT(after->n_tokens == 3);
    printf("  PASSED\n");
}

static void test_evict_slot_ref_blocks() {
    printf("step8.1: slot-ref blocks eviction...\n");
    branch_forest_index forest;
    const uint64_t node = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    TEST_ASSERT(node != 0);

    branch_node * n = forest.get_node(node);
    TEST_ASSERT(n != nullptr);
    n->exact_blob_payload_id = 100;
    n->resident_payload_bytes = 1024;
    n->has_target_payload = true;

    // Acquire slot ref
    TEST_ASSERT(forest.acquire_slot_ref(node));
    TEST_ASSERT(forest.slot_ref_count(node) == 1);

    // Eviction should be blocked
    TEST_ASSERT(!forest.evict_payload(node));

    // Release slot ref
    TEST_ASSERT(forest.release_slot_ref(node));
    TEST_ASSERT(forest.slot_ref_count(node) == 0);

    // Now eviction should succeed
    TEST_ASSERT(forest.evict_payload(node));
    TEST_ASSERT(forest.is_metadata_only_node(node));
    printf("  PASSED\n");
}

static void test_evict_protected_root_allowed() {
    printf("step8.1: protected-root payload eviction allowed (metadata preserved)...\n");
    branch_forest_index forest;
    const uint64_t node = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, true);
    TEST_ASSERT(node != 0);

    branch_node * n = forest.get_node(node);
    TEST_ASSERT(n != nullptr);
    n->exact_blob_payload_id = 100;
    n->resident_payload_bytes = 1024;
    n->has_target_payload = true;

    // Protected root payload eviction is allowed (metadata preserved)
    TEST_ASSERT(forest.evict_payload(node));
    TEST_ASSERT(forest.is_metadata_only_node(node));
    TEST_ASSERT(forest.is_protected(node)); // Still protected
    printf("  PASSED\n");
}

static void test_evict_topology_preserved() {
    printf("step8.1: topology preserved after eviction...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t child = forest.create_node("ns", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);
    const uint64_t grandchild = forest.create_node("ns", child, tokens({1, 2, 3, 4, 5}), 0, 4, 0, false);

    // Set payloads
    for (auto id : {root, child, grandchild}) {
        branch_node * n = forest.get_node(id);
        n->exact_blob_payload_id = id * 100;
        n->resident_payload_bytes = 512;
        n->has_target_payload = true;
    }

    // Evict middle node
    TEST_ASSERT(forest.evict_payload(child));
    TEST_ASSERT(forest.is_metadata_only_node(child));

    // Topology should be preserved
    auto children = forest.get_children(root);
    TEST_ASSERT(children.size() == 1 && children[0] == child);
    auto descendants = forest.get_descendants(root);
    TEST_ASSERT(descendants.size() == 2);
    TEST_ASSERT(forest.get_parent(grandchild) == child);
    auto path = forest.get_path_to_root(grandchild);
    TEST_ASSERT(path.size() == 3);
    printf("  PASSED\n");
}

static void test_evict_nonexistent_node() {
    printf("step8.1: evict nonexistent node returns false...\n");
    branch_forest_index forest;
    TEST_ASSERT(!forest.evict_payload(99999));
    printf("  PASSED\n");
}

// ============================================================================
// Step 8.2: Branch pruning with safety checks
// ============================================================================

static void test_prune_unprotected_leaf_metadata_only() {
    printf("step8.2: prune unprotected leaf metadata-only node...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t leaf = forest.create_node("ns", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);

    // Make leaf metadata-only
    branch_node * l = forest.get_node(leaf);
    l->exact_blob_payload_id = 100;
    l->resident_payload_bytes = 512;
    l->has_target_payload = true;
    TEST_ASSERT(forest.evict_payload(leaf));

    // Prune leaf
    TEST_ASSERT(forest.prune_node(leaf));
    TEST_ASSERT(forest.get_node(leaf) == nullptr);
    printf("  PASSED\n");
}

static void test_prune_reject_active_refs() {
    printf("step8.2: reject prune with active refs...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t leaf = forest.create_node("ns", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);

    branch_node * l = forest.get_node(leaf);
    l->exact_blob_payload_id = 100;
    l->resident_payload_bytes = 512;
    l->has_target_payload = true;
    TEST_ASSERT(forest.evict_payload(leaf));

    TEST_ASSERT(forest.acquire_slot_ref(leaf));
    TEST_ASSERT(!forest.prune_node(leaf));
    TEST_ASSERT(forest.release_slot_ref(leaf));
    TEST_ASSERT(forest.prune_node(leaf));
    printf("  PASSED\n");
}

static void test_prune_reject_protected_root() {
    printf("step8.2: reject prune for protected root...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, true);
    TEST_ASSERT(!forest.prune_node(root));
    printf("  PASSED\n");
}

static void test_prune_reject_retained_descendants() {
    printf("step8.2: reject prune with retained descendants...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t child = forest.create_node("ns", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);

    // Try to prune root while child exists
    TEST_ASSERT(!forest.prune_node(root));

    // Prune child first
    branch_node * c = forest.get_node(child);
    c->exact_blob_payload_id = 100;
    c->resident_payload_bytes = 512;
    c->has_target_payload = true;
    TEST_ASSERT(forest.evict_payload(child));
    TEST_ASSERT(forest.prune_node(child));

    // Now root can be pruned (no descendants)
    TEST_ASSERT(forest.prune_node(root));
    printf("  PASSED\n");
}

static void test_prune_metadata_bytes_decrease() {
    printf("step8.2: metadata bytes decrease after prune...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t leaf = forest.create_node("ns", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);

    const size_t before = forest.total_metadata_ram_bytes();

    branch_node * l = forest.get_node(leaf);
    l->exact_blob_payload_id = 100;
    l->resident_payload_bytes = 512;
    l->has_target_payload = true;
    TEST_ASSERT(forest.evict_payload(leaf));
    TEST_ASSERT(forest.prune_node(leaf));

    const size_t after = forest.total_metadata_ram_bytes();
    TEST_ASSERT(after < before);
    printf("  PASSED\n");
}

// ============================================================================
// Step 8.3: Equivalent-branch lookup and deduplication
// ============================================================================

static void test_equivalent_nodes_by_token_path() {
    printf("step8.3: equivalent nodes found by token path match...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t a = forest.create_node("ns", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);
    const uint64_t b = forest.create_node("ns", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);

    // a and b have same token path under same root
    auto equiv = forest.find_equivalent_nodes("ns", tokens({1, 2, 3, 4}), 0, 3);
    TEST_ASSERT(equiv.size() >= 2);
    TEST_ASSERT(std::find(equiv.begin(), equiv.end(), a) != equiv.end());
    TEST_ASSERT(std::find(equiv.begin(), equiv.end(), b) != equiv.end());
    printf("  PASSED\n");
}

static void test_equivalent_payload_bearing_preferred() {
    printf("step8.3: payload-bearing preferred over metadata-only...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t meta = forest.create_node("ns", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);
    const uint64_t payload = forest.create_node("ns", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);

    // Make meta metadata-only
    branch_node * m = forest.get_node(meta);
    m->exact_blob_payload_id = 100;
    m->resident_payload_bytes = 512;
    m->has_target_payload = true;
    TEST_ASSERT(forest.evict_payload(meta));

    // Make payload payload-bearing
    branch_node * p = forest.get_node(payload);
    p->exact_blob_payload_id = 200;
    p->resident_payload_bytes = 1024;
    p->has_target_payload = true;

    // Canonical should prefer payload-bearing
    const uint64_t canonical = forest.canonical_node_id("ns", tokens({1, 2, 3, 4}), 0, 3);
    TEST_ASSERT(canonical == payload);
    printf("  PASSED\n");
}

static void test_equivalent_cross_namespace_rejected() {
    printf("step8.3: cross-namespace equivalence rejected...\n");
    branch_forest_index forest;
    forest.create_node("ns-a", 0, tokens({1, 2, 3, 4}), 0, 3, 0, false);
    forest.create_node("ns-b", 0, tokens({1, 2, 3, 4}), 0, 3, 0, false);

    auto equiv = forest.find_equivalent_nodes("ns-a", tokens({1, 2, 3, 4}), 0, 3);
    // Should only find nodes in ns-a
    for (uint64_t id : equiv) {
        const branch_node * n = forest.get_node(id);
        TEST_ASSERT(n->namespace_id == "ns-a");
    }
    printf("  PASSED\n");
}

// ============================================================================
// Step 8.4: Deterministic branch lookup and mismatch-parent selection
// ============================================================================

static void test_rank_by_token_match_length() {
    printf("step8.4: ranking by token match length...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t short_node = forest.create_node("ns", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);
    const uint64_t long_node = forest.create_node("ns", root, tokens({1, 2, 3, 4, 5, 6}), 0, 5, 0, false);

    // Rank candidates for a query that matches both
    std::vector<uint64_t> candidates = {short_node, long_node};
    auto ranked = forest.rank_candidates("ns", candidates, tokens({1, 2, 3, 4, 5, 6}));
    TEST_ASSERT(ranked.size() == 2);
    // Longer match should be first
    TEST_ASSERT(ranked[0] == long_node);
    TEST_ASSERT(ranked[1] == short_node);
    printf("  PASSED\n");
}

static void test_rank_payload_bearing_before_metadata() {
    printf("step8.4: payload-bearing before metadata-only...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t meta = forest.create_node("ns", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);
    const uint64_t payload = forest.create_node("ns", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);

    branch_node * m = forest.get_node(meta);
    m->exact_blob_payload_id = 100;
    m->resident_payload_bytes = 512;
    m->has_target_payload = true;
    TEST_ASSERT(forest.evict_payload(meta));

    branch_node * p = forest.get_node(payload);
    p->exact_blob_payload_id = 200;
    p->resident_payload_bytes = 1024;
    p->has_target_payload = true;

    std::vector<uint64_t> candidates = {meta, payload};
    auto ranked = forest.rank_candidates("ns", candidates, tokens({1, 2, 3, 4}));
    TEST_ASSERT(ranked.size() == 2);
    TEST_ASSERT(ranked[0] == payload);
    TEST_ASSERT(ranked[1] == meta);
    printf("  PASSED\n");
}

static void test_mismatch_parent_selection() {
    printf("step8.4: mismatch-parent selection with partial validation...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t child = forest.create_node("ns", root, tokens({1, 2, 3, 4, 5}), 0, 4, 0, false);

    // Request tokens that match root but diverge at child
    std::vector<llama_token> request = tokens({1, 2, 3, 9, 9});
    uint64_t parent = forest.select_mismatch_parent("ns", request, {child});
    // Deepest validated ancestor should be root (tokens 1,2,3 match)
    TEST_ASSERT(parent == root);
    printf("  PASSED\n");
}

// ============================================================================
// Step 8.5: Re-materialization planning and validation protocol
// ============================================================================

static void test_rematerialization_plan_full_match() {
    printf("step8.5: re-materialization plan full match...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t child = forest.create_node("ns", root, tokens({1, 2, 3, 4, 5}), 0, 4, 0, false);

    // Set root payload (payload-bearing ancestor)
    branch_node * r = forest.get_node(root);
    r->exact_blob_payload_id = 50;
    r->resident_payload_bytes = 256;
    r->has_target_payload = true;

    // Make child metadata-only
    branch_node * c = forest.get_node(child);
    c->exact_blob_payload_id = 100;
    c->resident_payload_bytes = 512;
    c->has_target_payload = true;
    TEST_ASSERT(forest.evict_payload(child));

    // Plan re-materialization with matching tokens
    // validated_tokens = root(3) + child(5) = 8
    auto plan = forest.plan_rematerialization("ns", tokens({1, 2, 3, 4, 5}), child);
    TEST_ASSERT(plan.selected_node_id == child);
    TEST_ASSERT(plan.validated_tokens == 8);
    TEST_ASSERT(plan.mismatch_node_id == 0);
    TEST_ASSERT(plan.deepest_validated_node_id == child);
    printf("  PASSED\n");
}

static void test_rematerialization_plan_checksum_mismatch() {
    printf("step8.5: checksum mismatch detected...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t child = forest.create_node("ns", root, tokens({1, 2, 3, 4, 5}), 0, 4, 0, false);

    // Set root payload (payload-bearing ancestor)
    branch_node * r = forest.get_node(root);
    r->exact_blob_payload_id = 50;
    r->resident_payload_bytes = 256;
    r->has_target_payload = true;

    branch_node * c = forest.get_node(child);
    c->exact_blob_payload_id = 100;
    c->resident_payload_bytes = 512;
    c->has_target_payload = true;
    TEST_ASSERT(forest.evict_payload(child));

    // Plan with mismatching tokens
    auto plan = forest.plan_rematerialization("ns", tokens({1, 2, 3, 9, 9}), child);
    TEST_ASSERT(plan.mismatch_node_id == child);
    TEST_ASSERT(plan.deepest_validated_node_id == root);
    TEST_ASSERT(plan.validated_tokens == 3);
    printf("  PASSED\n");
}

static void test_rematerialization_plan_missing_ancestor() {
    printf("step8.5: missing ancestor payload detected...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t child = forest.create_node("ns", root, tokens({1, 2, 3, 4, 5}), 0, 4, 0, false);

    // Make both metadata-only (no payload-bearing ancestor)
    branch_node * r = forest.get_node(root);
    r->exact_blob_payload_id = 50;
    r->resident_payload_bytes = 256;
    r->has_target_payload = true;
    TEST_ASSERT(forest.evict_payload(root));

    branch_node * c = forest.get_node(child);
    c->exact_blob_payload_id = 100;
    c->resident_payload_bytes = 512;
    c->has_target_payload = true;
    TEST_ASSERT(forest.evict_payload(child));

    auto plan = forest.plan_rematerialization("ns", tokens({1, 2, 3, 4, 5}), child);
    TEST_ASSERT(plan.fallback_reason == cache_fallback_reason::no_payload_ancestor);
    printf("  PASSED\n");
}

static void test_hybrid_immediate_eviction_retains_metadata_only_node() {
    printf("step8.6/8.11: immediate eviction records metadata-only retention...\n");
    common_params params = test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(server_test_tokens({11, 12, 13}), false, "stage8", 256, 0);

    TEST_ASSERT(ctrl.debug_evict_first_payload_for_tests());
    json stats = ctrl.get_stats();
    TEST_ASSERT(stats["resident_payload_bytes"] == 0);
    TEST_ASSERT(stats["n_evicted_payload_descriptors"] == 1);
    TEST_ASSERT(stats["cache_metadata_only_retentions_total"] == 1);
    printf("  PASSED\n");
}

static void test_hybrid_successful_rematerialization_updates_payload() {
    printf("step8.6: successful controller re-materialization updates payload...\n");
    common_params params = test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(server_test_tokens({21, 22, 23}), false, "stage8", 128, 0);

    TEST_ASSERT(ctrl.debug_evict_first_payload_for_tests());
    TEST_ASSERT(ctrl.debug_first_entry_metadata_only_for_tests());
    TEST_ASSERT(ctrl.debug_rematerialize_first_entry_for_tests(256, 0));
    TEST_ASSERT(!ctrl.debug_first_entry_metadata_only_for_tests());
    TEST_ASSERT(ctrl.debug_first_entry_has_payload_for_tests());

    json stats = ctrl.get_stats();
    TEST_ASSERT(stats["cache_node_rematerializations_total"] == 1);
    TEST_ASSERT(stats["cache_node_rematerialization_bytes_total"] == 256);
    printf("  PASSED\n");
}

static void test_hybrid_restore_selects_payload_ancestor_for_metadata_only_node() {
    printf("step8.5/8.6: production restore selection uses payload ancestor for metadata-only node...\n");
    common_params params = test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(server_test_tokens({61, 62, 63}), false, "stage8-restore", 128, 0);
    TEST_ASSERT(ctrl.debug_add_child_entry_for_tests(server_test_tokens({61, 62, 63, 64, 65}), "stage8-restore", 128, 0));
    TEST_ASSERT(ctrl.debug_evict_last_payload_for_tests());

    const int source_tokens = ctrl.debug_select_restore_source_tokens_for_tests(
        server_test_tokens({61, 62, 63, 64, 65}), "stage8-restore");
    TEST_ASSERT(source_tokens == 3);
    printf("  PASSED\n");
}

static void test_hybrid_rematerialization_failure_keeps_metadata_only() {
    printf("step8.6: failed controller re-materialization leaves metadata-only node...\n");
    common_params params = test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(server_test_tokens({24, 25, 26}), false, "stage8", 128, 0);

    TEST_ASSERT(ctrl.debug_evict_first_payload_for_tests());
    TEST_ASSERT(!ctrl.debug_rematerialize_first_entry_for_tests(256, 0, true));
    TEST_ASSERT(ctrl.debug_first_entry_metadata_only_for_tests());
    TEST_ASSERT(!ctrl.debug_first_entry_has_payload_for_tests());

    json stats = ctrl.get_stats();
    TEST_ASSERT(stats["cache_node_rematerializations_total"] == 0);
    printf("  PASSED\n");
}

static void test_hybrid_rematerialization_commits_target_draft_together() {
    printf("step8.6: target/draft payloads commit together during re-materialization...\n");
    common_params params = test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(server_test_tokens({27, 28, 29}), false, "stage8", 128, 64);

    TEST_ASSERT(ctrl.debug_evict_first_payload_for_tests());
    TEST_ASSERT(ctrl.debug_rematerialize_first_entry_for_tests(256, 96));
    TEST_ASSERT(ctrl.debug_first_entry_has_payload_for_tests());

    json stats = ctrl.get_stats();
    TEST_ASSERT(stats["n_target_and_draft_payload_descriptors"] == 1);
    TEST_ASSERT(stats["cache_node_rematerialization_bytes_total"] == 352);
    printf("  PASSED\n");
}

static void test_hybrid_mismatch_creates_new_branch() {
    printf("step8.7/8.11: mismatch creates new branch and records diagnostics...\n");
    common_params params = test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(server_test_tokens({1, 2, 3}), false, "stage8-mismatch", 128, 0);
    TEST_ASSERT(ctrl.debug_add_child_entry_for_tests(server_test_tokens({1, 2, 3, 4, 5}), "stage8-mismatch", 128, 0));
    TEST_ASSERT(ctrl.debug_evict_last_payload_for_tests());

    TEST_ASSERT(ctrl.debug_try_admit_stage8_for_tests(server_test_tokens({1, 2, 3, 9, 9}), "stage8-mismatch", 128, 0));
    json stats = ctrl.get_stats();
    TEST_ASSERT(stats["n_entries"] == 3);
    TEST_ASSERT(stats["branch_forest"]["total_nodes"] == 3);
    TEST_ASSERT(stats["cache_validation_mismatches_total"] == 1);
    TEST_ASSERT(stats["cache_mismatch_parent_selections_total"] == 1);
    printf("  PASSED\n");
}

static void test_hybrid_equivalent_payload_bearing_reused() {
    printf("step8.8/8.11: equivalent payload-bearing branch is reused...\n");
    common_params params = test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(server_test_tokens({31, 32, 33}), false, "stage8-equiv", 128, 0);

    TEST_ASSERT(ctrl.debug_try_admit_stage8_for_tests(server_test_tokens({31, 32, 33}), "stage8-equiv", 256, 0));
    json stats = ctrl.get_stats();
    TEST_ASSERT(stats["n_entries"] == 1);
    TEST_ASSERT(stats["cache_equivalent_branch_deduplications_total"] == 1);
    printf("  PASSED\n");
}

static void test_hybrid_equivalent_metadata_only_rematerialized() {
    printf("step8.8: equivalent metadata-only branch is re-materialized...\n");
    common_params params = test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(server_test_tokens({34, 35, 36}), false, "stage8-equiv", 128, 0);
    TEST_ASSERT(ctrl.debug_evict_first_payload_for_tests());

    TEST_ASSERT(ctrl.debug_try_admit_stage8_for_tests(server_test_tokens({34, 35, 36}), "stage8-equiv", 256, 0));
    json stats = ctrl.get_stats();
    TEST_ASSERT(stats["n_entries"] == 1);
    TEST_ASSERT(stats["cache_equivalent_branch_deduplications_total"] == 1);
    TEST_ASSERT(stats["cache_node_rematerializations_total"] == 1);
    printf("  PASSED\n");
}

static void test_cold_cleanup_keeps_retained_descendant_payload() {
    printf("step8.10: retained descendant ownership blocks cold cleanup deletion...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t child = forest.create_node("ns", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);

    branch_node * r = forest.get_node(root);
    branch_node * c = forest.get_node(child);
    TEST_ASSERT(r != nullptr && c != nullptr);
    r->is_metadata_only = true;
    r->absent_reason = branch_node::payload_absent_reason::evicted_hot;
    c->exact_blob_payload_id = 700;
    c->resident_payload_bytes = 0;
    c->has_target_payload = false;
    c->residency_state = branch_node::residency::cold;

    auto referenced = forest.cleanup_cold();
    TEST_ASSERT(referenced.find(700) != referenced.end());
    printf("  PASSED\n");
}

static void test_branch_metadata_admission_rejects_protected_root_pressure() {
    printf("step8.9/8.11: protected-root metadata pressure rejects admission...\n");
    common_params params = test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);

    ctrl.debug_add_entry_for_tests(server_test_tokens({41, 42, 43}), true, "stage8-budget", 128, 0);
    ctrl.debug_set_branch_metadata_soft_max_for_tests(1);

    TEST_ASSERT(!ctrl.debug_try_admit_stage8_for_tests(server_test_tokens({44, 45, 46}), "stage8-budget", 128, 0));
    json stats = ctrl.get_stats();
    TEST_ASSERT(stats["n_entries"] == 1);
    TEST_ASSERT(stats["cache_branch_metadata_admission_rejections_total"] == 1);
    TEST_ASSERT(stats["branch_metadata_over_limit"] == true);
    printf("  PASSED\n");
}

static void test_branch_metadata_admission_rejects_active_ref_pressure() {
    printf("step8.9/8.11: active-ref metadata pressure rejects admission...\n");
    common_params params = test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(server_test_tokens({51, 52, 53}), false, "stage8-budget", 128, 0);
    TEST_ASSERT(ctrl.debug_acquire_first_branch_ref_for_tests());
    ctrl.debug_set_branch_metadata_soft_max_for_tests(1);

    TEST_ASSERT(!ctrl.debug_try_admit_stage8_for_tests(server_test_tokens({54, 55, 56}), "stage8-budget", 128, 0));
    json stats = ctrl.get_stats();
    TEST_ASSERT(stats["n_entries"] == 1);
    TEST_ASSERT(stats["cache_branch_metadata_admission_rejections_total"] == 1);
    TEST_ASSERT(stats["branch_forest"]["active_slot_refs"] == 1);
    TEST_ASSERT(ctrl.debug_release_first_branch_ref_for_tests());
    printf("  PASSED\n");
}

// ============================================================================
// Main
// ============================================================================

int main() {
    printf("Stage 8 Step 13 focused tests\n");

    // Step 8.1: Payload eviction with metadata-only retention
    test_evict_unreferenced_node();
    test_evict_slot_ref_blocks();
    test_evict_protected_root_allowed();
    test_evict_topology_preserved();
    test_evict_nonexistent_node();

    // Step 8.2: Branch pruning with safety checks
    test_prune_unprotected_leaf_metadata_only();
    test_prune_reject_active_refs();
    test_prune_reject_protected_root();
    test_prune_reject_retained_descendants();
    test_prune_metadata_bytes_decrease();

    // Step 8.3: Equivalent-branch lookup and deduplication
    test_equivalent_nodes_by_token_path();
    test_equivalent_payload_bearing_preferred();
    test_equivalent_cross_namespace_rejected();

    // Step 8.4: Deterministic branch lookup and mismatch-parent selection
    test_rank_by_token_match_length();
    test_rank_payload_bearing_before_metadata();
    test_mismatch_parent_selection();

    // Step 8.5: Re-materialization planning and validation protocol
    test_rematerialization_plan_full_match();
    test_rematerialization_plan_checksum_mismatch();
    test_rematerialization_plan_missing_ancestor();
    test_hybrid_immediate_eviction_retains_metadata_only_node();
    test_hybrid_successful_rematerialization_updates_payload();
    test_hybrid_restore_selects_payload_ancestor_for_metadata_only_node();
    test_hybrid_rematerialization_failure_keeps_metadata_only();
    test_hybrid_rematerialization_commits_target_draft_together();
    test_hybrid_mismatch_creates_new_branch();
    test_hybrid_equivalent_payload_bearing_reused();
    test_hybrid_equivalent_metadata_only_rematerialized();
    test_cold_cleanup_keeps_retained_descendant_payload();
    test_branch_metadata_admission_rejects_protected_root_pressure();
    test_branch_metadata_admission_rejects_active_ref_pressure();

    printf("All Stage 8 focused tests passed\n");
    return 0;
}
