#include "server-cache-graph.h"

#include <algorithm>
#include <atomic>
#include <cstdio>
#include <cstdlib>
#include <thread>
#include <vector>

#define TEST_ASSERT(cond) \
    do { \
        if (!(cond)) { \
            fprintf(stderr, "TEST FAILED: %s at %s:%d\n", __func__, __FILE__, __LINE__); \
            exit(1); \
        } \
    } while (0)

static std::vector<llama_token> tokens(std::initializer_list<int> values) {
    std::vector<llama_token> out;
    for (int value : values) {
        out.push_back(static_cast<llama_token>(value));
    }
    return out;
}

static void test_branch_node_defaults() {
    printf("step12: branch_node defaults...\n");
    branch_node node;
    TEST_ASSERT(node.node_id == 0);
    TEST_ASSERT(node.slot_ref_count.load() == 0);
    TEST_ASSERT(!node.is_metadata_only);
    TEST_ASSERT(node.exact_blob_payload_id == 0);
    TEST_ASSERT(node.checkpoint_payload_id == 0);

    node.namespace_id = "ns";
    node.token_span = tokens({1, 2, 3, 4});
    node.prefix_checksums = {1, 2, 3, 4};
    TEST_ASSERT(node.metadata_ram_bytes() >= sizeof(branch_node));
    printf("  PASSED\n");
}

static void test_namespace_key() {
    printf("step12: namespace key...\n");
    namespace_key a;
    a.model_path_hash = "model-a";
    a.draft_context_mode = "none";
    a.n_ctx = 4096;

    namespace_key b = a;
    TEST_ASSERT(a.compute() == b.compute());
    b.model_path_hash = "model-b";
    TEST_ASSERT(a.compute() != b.compute());
    b = a;
    b.draft_context_mode = "target_mtp";
    TEST_ASSERT(a.compute() != b.compute());
    TEST_ASSERT(validate_namespace_compatibility("ns", "ns"));
    TEST_ASSERT(!validate_namespace_compatibility("ns-a", "ns-b"));
    TEST_ASSERT(validate_namespace_compatibility("", ""));
    printf("  PASSED\n");
}

static void test_lifecycle_and_traversal() {
    printf("step12: lifecycle and traversal...\n");
    branch_forest_index forest;
    const uint64_t root = forest.create_node("ns-a", 0, tokens({1, 2, 3}), 0, 2, 0, true);
    TEST_ASSERT(root != 0);
    const uint64_t child = forest.create_node("ns-a", root, tokens({1, 2, 3, 4}), 0, 3, 0, false);
    const uint64_t grandchild = forest.create_node("ns-a", child, tokens({1, 2, 3, 4, 5}), 0, 4, 0, false);
    const uint64_t other = forest.create_node("ns-b", 0, tokens({9, 9}), 0, 1, 0, false);
    TEST_ASSERT(other != 0);
    TEST_ASSERT(forest.size() == 4);

    auto children = forest.get_children(root);
    TEST_ASSERT(children.size() == 1 && children[0] == child);
    auto path = forest.get_path_to_root(grandchild);
    TEST_ASSERT(path.size() == 3 && path[0] == grandchild && path[1] == child && path[2] == root);
    auto descendants = forest.get_descendants(root);
    TEST_ASSERT(descendants.size() == 2);
    TEST_ASSERT(std::find(descendants.begin(), descendants.end(), child) != descendants.end());
    TEST_ASSERT(std::find(descendants.begin(), descendants.end(), grandchild) != descendants.end());
    const branch_traversal_counts counts = forest.traversal_counts();
    TEST_ASSERT(counts.children == 1);
    TEST_ASSERT(counts.path_to_root == 1);
    TEST_ASSERT(counts.descendants == 1);
    TEST_ASSERT(!forest.remove_node(child));
    TEST_ASSERT(forest.get_parent(grandchild) == child);

    auto namespaces = forest.get_namespaces();
    TEST_ASSERT(namespaces.size() == 2);
    TEST_ASSERT(forest.namespace_node_count("ns-a") == 3);
    TEST_ASSERT(forest.namespace_roots("ns-a").size() == 1);

    TEST_ASSERT(forest.remove_node(grandchild));
    TEST_ASSERT(forest.remove_node(child));
    TEST_ASSERT(!forest.remove_node(root));
    printf("  PASSED\n");
}

static void test_lookup() {
    printf("step12: token and checksum lookup...\n");
    branch_forest_index forest;
    const uint64_t a = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    const uint64_t b = forest.create_node("ns", 0, tokens({1, 2, 3, 4, 5}), 0, 4, 0, false);
    forest.create_node("other", 0, tokens({1, 2, 3}), 0, 2, 0, false);

    auto prefix = forest.find_nodes_by_token_span("ns", tokens({1, 2}), 2);
    TEST_ASSERT(prefix.size() == 2);
    TEST_ASSERT(std::find(prefix.begin(), prefix.end(), a) != prefix.end());
    TEST_ASSERT(std::find(prefix.begin(), prefix.end(), b) != prefix.end());
    TEST_ASSERT(forest.find_nodes_by_token_span("ns", tokens({1, 2}), 3).empty());
    TEST_ASSERT(forest.find_nodes_by_token_span("ns", tokens({1, 2, 3, 4, 5, 6}), 1).empty());
    TEST_ASSERT(forest.find_nodes_by_token_span("missing", tokens({1, 2}), 1).empty());

    const branch_node * node_b = forest.get_node(b);
    TEST_ASSERT(node_b != nullptr);
    const uint64_t checksum = node_b->prefix_checksums[2];
    auto checksum_hits = forest.find_nodes_by_checksum_span("ns", checksum, 3);
    TEST_ASSERT(checksum_hits.size() == 2);
    TEST_ASSERT(forest.find_nodes_by_checksum_span("ns", checksum, 4).empty());
    TEST_ASSERT(forest.find_nodes_by_checksum_span("ns", checksum ^ 0xff, 3).empty());
    printf("  PASSED\n");
}

static void test_slot_refs_and_eviction_candidates() {
    printf("step12: slot refs and eviction candidates...\n");
    branch_forest_index forest;
    const uint64_t protected_root = forest.create_node("ns-a", 0, tokens({1}), 0, 0, 0, true);
    const uint64_t old_unprotected = forest.create_node("ns-b", 0, tokens({2}), 0, 0, 0, false);
    const uint64_t new_unprotected = forest.create_node("ns-a", 0, tokens({3}), 0, 0, 0, false);

    branch_node * root = forest.get_node(protected_root);
    branch_node * old_node = forest.get_node(old_unprotected);
    branch_node * new_node = forest.get_node(new_unprotected);
    TEST_ASSERT(root != nullptr && old_node != nullptr && new_node != nullptr);
    root->exact_blob_payload_id = 10;
    root->resident_payload_bytes = 100;
    root->has_target_payload = true;
    root->use_sequence = 1;
    old_node->exact_blob_payload_id = 11;
    old_node->resident_payload_bytes = 100;
    old_node->has_target_payload = true;
    old_node->use_sequence = 2;
    new_node->exact_blob_payload_id = 12;
    new_node->resident_payload_bytes = 100;
    new_node->has_target_payload = true;
    new_node->use_sequence = 3;

    auto candidates = forest.payload_eviction_candidates(0);
    TEST_ASSERT(candidates.size() == 3);
    TEST_ASSERT(candidates[0] == old_unprotected);
    TEST_ASSERT(candidates[1] == new_unprotected);
    TEST_ASSERT(candidates[2] == protected_root);

    TEST_ASSERT(forest.acquire_slot_ref(old_unprotected));
    TEST_ASSERT(forest.slot_ref_count(old_unprotected) == 1);
    candidates = forest.payload_eviction_candidates(0);
    TEST_ASSERT(std::find(candidates.begin(), candidates.end(), old_unprotected) == candidates.end());
    TEST_ASSERT(!forest.remove_node(old_unprotected));
    TEST_ASSERT(forest.release_slot_ref(old_unprotected));
    TEST_ASSERT(forest.slot_ref_count(old_unprotected) == 0);
    printf("  PASSED\n");
}

static void test_concurrent_refs() {
    printf("step12: concurrent slot refs...\n");
    branch_forest_index forest;
    const uint64_t node_id = forest.create_node("ns", 0, tokens({1, 2, 3}), 0, 2, 0, false);
    std::atomic<bool> ok{true};
    std::vector<std::thread> threads;
    for (int t = 0; t < 8; ++t) {
        threads.emplace_back([&]() {
            for (int i = 0; i < 2000; ++i) {
                ok = ok && forest.acquire_slot_ref(node_id);
                ok = ok && forest.release_slot_ref(node_id);
                (void) forest.get_node(node_id);
                (void) forest.get_path_to_root(node_id);
            }
        });
    }
    for (auto & thread : threads) {
        thread.join();
    }
    TEST_ASSERT(ok.load());
    TEST_ASSERT(forest.slot_ref_count(node_id) == 0);
    TEST_ASSERT(forest.peak_slot_refs() > 0);
    printf("  PASSED\n");
}

int main() {
    printf("Stage 7 Step 12 branch graph tests\n");
    test_branch_node_defaults();
    test_namespace_key();
    test_lifecycle_and_traversal();
    test_lookup();
    test_slot_refs_and_eviction_candidates();
    test_concurrent_refs();
    printf("All branch graph tests passed\n");
    return 0;
}
