// Stage 10 focused test: cold-store hardening.

#include "server-cache-hybrid.h"
#include "server-cache-store-cold.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <chrono>
#include <filesystem>
#include <fstream>
#include <memory>
#include <stdexcept>
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

namespace fs = std::filesystem;

static server_tokens create_tokens(const std::vector<int> & ids) {
    server_tokens tokens;
    for (int id : ids) {
        tokens.push_back(id);
    }
    return tokens;
}

static common_params create_test_params() {
    common_params params;
    params.model.path = "stage10-test-model.gguf";
    return params;
}

static bool rows_have(const json & rows, const std::string & key, const std::string & value) {
    for (const auto & row : rows) {
        if (row.contains(key) && row[key] == value && row.contains("value") && row["value"].get<size_t>() > 0) {
            return true;
        }
    }
    return false;
}

static void test_cold_store_rejects_root_directory() {
    printf("stage10: cold store rejects root directory...\n");
    const fs::path root = fs::temp_directory_path().root_path();
    if (!root.empty()) {
        server_cache_store_cold store;
        TEST_ASSERT(!store.configure(root.string(), COLD_STORE_FORMAT_VERSION_1));
    }
    printf("  PASSED\n");
}

static void test_cold_store_root_with_dotdot_chars() {
    printf("stage10: cold store root with dotdot chars...\n");
    const fs::path tmp_dir = fs::temp_directory_path() / "stage10_safe..root";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);

    server_cache_store_cold store;
    TEST_ASSERT(store.configure(tmp_dir.string(), COLD_STORE_FORMAT_VERSION_1));

    cold_descriptor_snapshot snapshot{};
    snapshot.payload_id = 42;
    snapshot.pair_state = 0;
    snapshot.format_version = COLD_STORE_FORMAT_VERSION_1;
    snapshot.target_size_bytes = 4;

    std::vector<uint8_t> target = { 1, 2, 3, 4 };
    std::vector<uint8_t> draft;
    const cold_ref ref = store.write(42, target, draft, snapshot);
    TEST_ASSERT(ref == 42);

    std::vector<uint8_t> read_target;
    std::vector<uint8_t> read_draft;
    cold_descriptor_snapshot read_snapshot{};
    TEST_ASSERT(store.read(ref, read_target, read_draft, read_snapshot));
    TEST_ASSERT(read_target == target);
    TEST_ASSERT(read_draft.empty());
    TEST_ASSERT(read_snapshot.payload_id == 42);
    TEST_ASSERT(store.remove(ref));

    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

static void test_repeated_integrity_failure_is_stable() {
    printf("stage10: repeated cold-store integrity failure is stable...\n");
    const fs::path tmp_dir = fs::temp_directory_path() / "stage10_integrity_failure";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);

    server_cache_store_cold store;
    TEST_ASSERT(store.configure(tmp_dir.string(), COLD_STORE_FORMAT_VERSION_1));

    cold_descriptor_snapshot snapshot{};
    snapshot.payload_id = 77;
    snapshot.pair_state = 0;
    snapshot.format_version = COLD_STORE_FORMAT_VERSION_1;
    snapshot.target_size_bytes = 4;

    std::vector<uint8_t> target = { 9, 8, 7, 6 };
    std::vector<uint8_t> draft;
    const cold_ref ref = store.write(77, target, draft, snapshot);
    TEST_ASSERT(ref == 77);

    const fs::path cold_file = tmp_dir / "4d.cold";
    {
        std::ofstream ofs(cold_file, std::ios::binary | std::ios::trunc);
        ofs << "bad";
    }

    std::vector<uint8_t> read_target;
    std::vector<uint8_t> read_draft;
    cold_descriptor_snapshot read_snapshot{};
    TEST_ASSERT(!store.read(ref, read_target, read_draft, read_snapshot));
    TEST_ASSERT(!store.read(ref, read_target, read_draft, read_snapshot));
    TEST_ASSERT(store.remove(ref));

    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

static void test_startup_rejects_impossible_budgets() {
    printf("stage10: startup rejects impossible budgets...\n");
    const common_params params = create_test_params();

    bool caught_negative = false;
    try {
        hybrid_cache_controller ctrl(params, -2, 1000, nullptr, nullptr);
    } catch (const std::runtime_error & e) {
        caught_negative = std::string(e.what()).find("budget") != std::string::npos;
    }
    TEST_ASSERT(caught_negative);

    bool caught_tiny_token_budget = false;
    try {
        hybrid_cache_controller ctrl(params, 2, 1, nullptr, nullptr);
    } catch (const std::runtime_error & e) {
        caught_tiny_token_budget = std::string(e.what()).find("budget") != std::string::npos;
    }
    TEST_ASSERT(caught_tiny_token_budget);

    hybrid_cache_controller unlimited_ok(params, -1, 0, nullptr, nullptr);
    TEST_ASSERT(unlimited_ok.get_stats()["hot_payload_budget_bytes"] == -1);
    printf("  PASSED\n");
}

static void test_tiny_hot_budget_records_pressure_rows() {
    printf("stage10: tiny hot budget records pressure rows...\n");
    const common_params params = create_test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
    ctrl.debug_set_hot_payload_budget_bytes_for_tests(16, false);

    prepared_prompt_metadata metadata;
    metadata.protect_system = true;
    const bool admitted = ctrl.debug_try_admit_entry_for_tests(create_tokens({1, 2, 3, 4}), metadata, 128, 0);
    TEST_ASSERT(!admitted);

    const json stats = ctrl.get_stats();
    TEST_ASSERT(stats["n_protected_root_admission_rejections"] == 1);
    TEST_ASSERT(rows_have(stats["cache_protected_root_decisions_by_shape"], "reason", "budget"));
    TEST_ASSERT(rows_have(stats["cache_structured_diagnostics_by_shape"], "event", "protected_root_pressure"));
    printf("  PASSED\n");
}

static void test_branch_metadata_pressure_large_forest() {
    printf("stage10: branch metadata pressure large forest...\n");
    const common_params params = create_test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
    ctrl.debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

    for (int i = 0; i < 64; ++i) {
        ctrl.debug_add_entry_for_tests(create_tokens({i, i + 1, i + 2}), false, "stage10-large-forest", 32, 0);
    }
    ctrl.debug_set_branch_metadata_soft_max_for_tests(1);

    const json stats = ctrl.get_stats();
    TEST_ASSERT(stats["branch_forest"]["total_nodes"].get<size_t>() >= 64);
    TEST_ASSERT(stats["n_branch_metadata_over_limit_events"].get<size_t>() > 0 ||
                stats["cache_branch_pruning_total"].get<size_t>() > 0);
    printf("  PASSED\n");
}

static void test_queue_pressure_records_bounded_rows() {
    printf("stage10: queue pressure records bounded rows...\n");
    const fs::path tmp_dir = fs::temp_directory_path() / "stage10_queue_pressure";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);

    const common_params params = create_test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
    ctrl.debug_set_cold_store_for_tests(tmp_dir.string());
    ctrl.debug_set_io_worker_queue_capacity_for_tests(1);
    ctrl.debug_add_entry_for_tests(create_tokens({10, 11, 12}), false, "stage10-queue", 128, 0);
    ctrl.debug_add_entry_for_tests(create_tokens({13, 14, 15}), false, "stage10-queue", 128, 0);

    const bool first = ctrl.demote_payload(1);
    const bool second = ctrl.demote_payload(2);
    TEST_ASSERT(first);
    TEST_ASSERT(!second);

    const json stats = ctrl.get_stats();
    TEST_ASSERT(stats["n_demotion_queue_full"] == 1);
    TEST_ASSERT(rows_have(stats["cache_payload_transitions_by_shape"], "reason", "queue_full"));
    TEST_ASSERT(rows_have(stats["cache_structured_diagnostics_by_shape"], "event", "queue_pressure"));

    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

static void test_shutdown_with_pending_work_is_bounded() {
    printf("stage10: shutdown with pending work is bounded...\n");
    const fs::path tmp_dir = fs::temp_directory_path() / "stage10_shutdown_pending";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);

    const common_params params = create_test_params();
    {
        hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr, tmp_dir.string());
        ctrl.debug_add_entry_for_tests(create_tokens({20, 21, 22}), false, "stage10-shutdown", 128, 0);
        (void) ctrl.demote_payload(1);
    }

    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

static void test_exact_restore_and_integrity_rows() {
    printf("stage10: exact restore and integrity rows...\n");
    const common_params params = create_test_params();
    hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
    ctrl.debug_add_entry_for_tests(create_tokens({30, 31, 32}), false, "stage10-exact", 128, 0);

    TEST_ASSERT(ctrl.debug_validate_first_payload_for_tests(false));
    TEST_ASSERT(ctrl.debug_corrupt_first_payload_for_tests());
    TEST_ASSERT(!ctrl.debug_validate_first_payload_for_tests(false));

    const json stats = ctrl.get_stats();
    TEST_ASSERT(rows_have(stats["cache_exact_blob_restores_by_shape"], "result", "success"));
    TEST_ASSERT(rows_have(stats["cache_exact_blob_restores_by_shape"], "result", "failure"));
    TEST_ASSERT(rows_have(stats["cache_fallback_restores_by_shape"], "result", "fallback"));
    TEST_ASSERT(rows_have(stats["cache_structured_diagnostics_by_shape"], "event", "descriptor_rejection"));
    printf("  PASSED\n");
}

static void test_cold_store_configure_empty_path() {
    printf("stage10: cold store configure with empty path...\n");
    server_cache_store_cold store;
    TEST_ASSERT(!store.configure("", COLD_STORE_FORMAT_VERSION_1));
    TEST_ASSERT(!store.is_configured());
    printf("  PASSED\n");
}

static void test_cold_store_configure_nonexistent_path() {
    printf("stage10: cold store configure with nonexistent path...\n");
    const fs::path tmp = fs::temp_directory_path() / "stage10_does_not_exist_dir";
    fs::remove_all(tmp);
    server_cache_store_cold store;
    TEST_ASSERT(!store.configure(tmp.string(), COLD_STORE_FORMAT_VERSION_1));
    TEST_ASSERT(!store.is_configured());
    printf("  PASSED\n");
}

static void test_cold_store_configure_file_not_dir() {
    printf("stage10: cold store configure with file not directory...\n");
    const fs::path tmp = fs::temp_directory_path() / "stage10_not_a_dir.txt";
    {
        std::ofstream ofs(tmp);
        ofs << "x";
    }
    server_cache_store_cold store;
    TEST_ASSERT(!store.configure(tmp.string(), COLD_STORE_FORMAT_VERSION_1));
    fs::remove(tmp);
    printf("  PASSED\n");
}

static void test_cold_store_write_read_unconfigured() {
    printf("stage10: cold store write/read on unconfigured store...\n");
    server_cache_store_cold store;
    cold_descriptor_snapshot snap{};
    snap.payload_id = 1;
    TEST_ASSERT(store.write(1, {1, 2, 3}, {}, snap) == 0);
    std::vector<uint8_t> tgt, drf;
    cold_descriptor_snapshot snap2{};
    TEST_ASSERT(!store.read(1, tgt, drf, snap2));
    TEST_ASSERT(!store.remove(1));
    TEST_ASSERT(store.delete_ids({1, 2, 3}) == 0);
    printf("  PASSED\n");
}

static void test_cold_store_fault_injection_write() {
    printf("stage10: cold store fault injection write failure...\n");
    const fs::path tmp_dir = fs::temp_directory_path() / "stage10_fault_write";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);

    server_cache_store_cold store;
    TEST_ASSERT(store.configure(tmp_dir.string(), COLD_STORE_FORMAT_VERSION_1));

    cold_descriptor_snapshot snap{};
    snap.payload_id = 11;
    snap.target_size_bytes = 4;

    store.debug_set_write_failure_for_tests(true);
    std::vector<uint8_t> target = { 1, 2, 3, 4 };
    TEST_ASSERT(store.write(11, target, {}, snap) == 0);
    store.debug_set_write_failure_for_tests(false);

    const cold_ref ref = store.write(11, target, {}, snap);
    TEST_ASSERT(ref == 11);
    TEST_ASSERT(store.remove(ref));
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

static void test_cold_store_fault_injection_read() {
    printf("stage10: cold store fault injection read failure...\n");
    const fs::path tmp_dir = fs::temp_directory_path() / "stage10_fault_read";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);

    server_cache_store_cold store;
    TEST_ASSERT(store.configure(tmp_dir.string(), COLD_STORE_FORMAT_VERSION_1));

    cold_descriptor_snapshot snap{};
    snap.payload_id = 21;
    snap.target_size_bytes = 4;
    std::vector<uint8_t> target = { 5, 6, 7, 8 };
    const cold_ref ref = store.write(21, target, {}, snap);
    TEST_ASSERT(ref == 21);

    store.debug_set_read_failure_for_tests(true);
    std::vector<uint8_t> tgt, drf;
    cold_descriptor_snapshot snap2{};
    TEST_ASSERT(!store.read(ref, tgt, drf, snap2));
    store.debug_set_read_failure_for_tests(false);

    TEST_ASSERT(store.read(ref, tgt, drf, snap2));
    TEST_ASSERT(tgt == target);
    TEST_ASSERT(store.remove(ref));
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

static void test_cold_store_validation_magic_mismatch() {
    printf("stage10: cold store validation magic mismatch...\n");
    const fs::path tmp_dir = fs::temp_directory_path() / "stage10_magic_mismatch";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);

    server_cache_store_cold store;
    TEST_ASSERT(store.configure(tmp_dir.string(), COLD_STORE_FORMAT_VERSION_1));

    cold_descriptor_snapshot snap{};
    snap.payload_id = 31;
    snap.target_size_bytes = 4;
    std::vector<uint8_t> target = { 9, 9, 9, 9 };
    const cold_ref ref = store.write(31, target, {}, snap);
    TEST_ASSERT(ref == 31);

    // Corrupt the file by overwriting with non-magic bytes
    const std::string final_path = (tmp_dir / "1f.cold").string();
    {
        std::ofstream ofs(final_path, std::ios::binary | std::ios::trunc);
        uint8_t bad[64] = {};
        ofs.write(reinterpret_cast<const char *>(bad), sizeof(bad));
    }

    std::vector<uint8_t> tgt, drf;
    cold_descriptor_snapshot snap2{};
    TEST_ASSERT(!store.read(ref, tgt, drf, snap2));
    TEST_ASSERT(store.remove(ref));
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

static void test_cold_store_truncated_file() {
    printf("stage10: cold store truncated file...\n");
    const fs::path tmp_dir = fs::temp_directory_path() / "stage10_truncated";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);

    server_cache_store_cold store;
    TEST_ASSERT(store.configure(tmp_dir.string(), COLD_STORE_FORMAT_VERSION_1));

    cold_descriptor_snapshot snap{};
    snap.payload_id = 41;
    snap.target_size_bytes = 4;
    std::vector<uint8_t> target = { 1, 1, 1, 1 };
    const cold_ref ref = store.write(41, target, {}, snap);
    TEST_ASSERT(ref == 41);

    // Truncate the file to a size smaller than the header
    const std::string final_path = (tmp_dir / "29.cold").string();
    {
        std::ofstream ofs(final_path, std::ios::binary | std::ios::trunc);
        uint8_t small[8] = {};
        ofs.write(reinterpret_cast<const char *>(small), sizeof(small));
    }

    std::vector<uint8_t> tgt, drf;
    cold_descriptor_snapshot snap2{};
    TEST_ASSERT(!store.read(ref, tgt, drf, snap2));
    TEST_ASSERT(store.remove(ref));
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

static void test_cold_store_pair_state_target_and_draft() {
    printf("stage10: cold store target_and_draft pair state...\n");
    const fs::path tmp_dir = fs::temp_directory_path() / "stage10_pair_state_draft";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);

    server_cache_store_cold store;
    TEST_ASSERT(store.configure(tmp_dir.string(), COLD_STORE_FORMAT_VERSION_1));

    cold_descriptor_snapshot snap{};
    snap.payload_id = 51;
    snap.pair_state = 1;  // target_and_draft
    snap.target_size_bytes = 4;
    snap.draft_size_bytes = 2;
    std::vector<uint8_t> target = { 0xAA, 0xBB, 0xCC, 0xDD };
    std::vector<uint8_t> draft = { 0xEE, 0xFF };
    const cold_ref ref = store.write(51, target, draft, snap);
    TEST_ASSERT(ref == 51);

    std::vector<uint8_t> read_target, read_draft;
    cold_descriptor_snapshot read_snap{};
    TEST_ASSERT(store.read(ref, read_target, read_draft, read_snap));
    TEST_ASSERT(read_target == target);
    TEST_ASSERT(read_draft == draft);
    TEST_ASSERT(read_snap.pair_state == 1);
    TEST_ASSERT(read_snap.draft_size_bytes == 2);
    TEST_ASSERT(store.remove(ref));
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

static void test_cold_store_delete_ids() {
    printf("stage10: cold store delete_ids batch...\n");
    const fs::path tmp_dir = fs::temp_directory_path() / "stage10_delete_ids";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);

    server_cache_store_cold store;
    TEST_ASSERT(store.configure(tmp_dir.string(), COLD_STORE_FORMAT_VERSION_1));

    cold_descriptor_snapshot snap{};
    snap.target_size_bytes = 4;
    std::vector<uint8_t> target = { 0x10, 0x20, 0x30, 0x40 };
    for (uint64_t id = 61; id <= 64; ++id) {
        snap.payload_id = id;
        const cold_ref wrote_ref = store.write(id, target, {}, snap);
        TEST_ASSERT(wrote_ref == id);
    }
    // List files in tmp_dir to verify writes actually created files
    int file_count = 0;
    for (const auto & entry : fs::directory_iterator(tmp_dir)) {
        if (entry.path().extension() == ".cold") {
            file_count++;
        }
    }
    TEST_ASSERT(file_count == 4);
    std::unordered_set<uint64_t> ids = { 61, 62, 63, 64, 99 };
    const size_t deleted = store.delete_ids(ids);
    TEST_ASSERT(deleted == 4);
    // After delete, only the non-existent (99) should remain, all 4 real files removed
    int remaining = 0;
    for (const auto & entry : fs::directory_iterator(tmp_dir)) {
        if (entry.path().extension() == ".cold") {
            remaining++;
        }
    }
    TEST_ASSERT(remaining == 0);
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

static void test_cold_store_remove_nonexistent() {
    printf("stage10: cold store remove nonexistent...\n");
    const fs::path tmp_dir = fs::temp_directory_path() / "stage10_remove_nonexistent";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);

    server_cache_store_cold store;
    TEST_ASSERT(store.configure(tmp_dir.string(), COLD_STORE_FORMAT_VERSION_1));
    // remove a ref that was never written -> succeeds (idempotent)
    TEST_ASSERT(store.remove(9999));
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

int main() {
    printf("==================================================\n");
    printf("Stage 10: Cold-store hardening\n");
    printf("==================================================\n\n");

    test_cold_store_rejects_root_directory();
    test_cold_store_root_with_dotdot_chars();
    test_repeated_integrity_failure_is_stable();
    test_startup_rejects_impossible_budgets();
    test_tiny_hot_budget_records_pressure_rows();
    test_branch_metadata_pressure_large_forest();
    test_queue_pressure_records_bounded_rows();
    test_shutdown_with_pending_work_is_bounded();
    test_exact_restore_and_integrity_rows();
    test_cold_store_configure_empty_path();
    test_cold_store_configure_nonexistent_path();
    test_cold_store_configure_file_not_dir();
    test_cold_store_write_read_unconfigured();
    test_cold_store_fault_injection_write();
    test_cold_store_fault_injection_read();
    test_cold_store_validation_magic_mismatch();
    test_cold_store_truncated_file();
    test_cold_store_pair_state_target_and_draft();
    test_cold_store_delete_ids();
    test_cold_store_remove_nonexistent();

    printf("\n==================================================\n");
    printf("Stage 10 cold-store hardening tests passed\n");
    printf("==================================================\n");
    return 0;
}
