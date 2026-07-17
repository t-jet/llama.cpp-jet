// Step 11 focused test: test hooks and fault injection
// Verifies LLAMA_SERVER_CACHE_TESTS hooks against the current synchronous
// transaction controller. Stage 25/28 retired the async worker queue and
// delayed completion model, so former queue, delay, and shutdown-race rows are
// retained only as local "retired path" checks with no queue assertions.

#include "server-cache-hybrid.h"
#include "server-cache-store-cold.h"
#include "server-cache-io-worker.h"
#include "server-task.h"
#include "common.h"

#include <cstdlib>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <vector>

// Custom assertion macro that works in both Debug and Release modes.
// Uses exit() instead of abort() for graceful termination.
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

static fs::path reset_temp_dir(const char * name) {
    fs::path tmp_dir = fs::temp_directory_path() / name;
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);
    return tmp_dir;
}

static std::unique_ptr<hybrid_cache_controller> create_controller_with_cold(
    const fs::path & cold_dir,
    int32_t budget_mib = 100,
    size_t budget_tokens = 1000)
{
    common_params params;
    params.model.path = "test_model.gguf";
    return std::make_unique<hybrid_cache_controller>(
        params, budget_mib, budget_tokens, nullptr, nullptr, cold_dir.string());
}

static void add_single_payload(hybrid_cache_controller & ctrl, size_t target_bytes = 100, size_t draft_bytes = 0) {
    ctrl.debug_add_entry_for_tests(create_tokens({1, 2, 3, 4, 5}), false, "ns1", target_bytes, draft_bytes);
}

static void assert_queue_metrics_zero(const hybrid_cache_controller & ctrl) {
    const json stats = ctrl.get_stats();
    TEST_ASSERT(stats["n_demotion_queue_full"].get<size_t>() == 0);
    TEST_ASSERT(stats["n_promotion_queue_full"].get<size_t>() == 0);
}

enum class cold_file_fault {
    magic,
    format_version,
    header_checksum,
    payload_id,
    pair_state,
    target_checksum,
    draft_checksum,
};

static uint64_t fnv1a_hash(const uint8_t * data, size_t len) {
    uint64_t hash = 0xcbf29ce484222325ULL;
    for (size_t i = 0; i < len; ++i) {
        hash ^= data[i];
        hash *= 0x100000001b3ULL;
    }
    return hash;
}

static void write_u64_le(std::vector<uint8_t> & data, size_t offset, uint64_t value) {
    TEST_ASSERT(data.size() >= offset + sizeof(value));
    std::memcpy(data.data() + offset, &value, sizeof(value));
}

static void refresh_header_checksum(std::vector<uint8_t> & data) {
    TEST_ASSERT(data.size() >= sizeof(cold_store_header));
    const uint64_t checksum = fnv1a_hash(data.data(), 56);
    write_u64_le(data, 56, checksum);
}

static void corrupt_cold_file(const fs::path & cold_dir, cold_file_fault fault, size_t target_bytes) {
    const fs::path cold_file = cold_dir / "1.cold";
    std::ifstream input(cold_file, std::ios::binary | std::ios::ate);
    TEST_ASSERT(input.is_open());
    const std::streamsize file_size = input.tellg();
    TEST_ASSERT(file_size > 0);
    input.seekg(0, std::ios::beg);
    std::vector<uint8_t> data(static_cast<size_t>(file_size));
    TEST_ASSERT(static_cast<bool>(input.read(reinterpret_cast<char *>(data.data()), file_size)));
    input.close();

    TEST_ASSERT(data.size() >= sizeof(cold_store_header));
    switch (fault) {
        case cold_file_fault::magic:
            data[0] ^= 0xFF;
            break;
        case cold_file_fault::format_version:
            data[4] = 0xFE;
            break;
        case cold_file_fault::header_checksum:
            data[56] ^= 0xFF;
            break;
        case cold_file_fault::payload_id:
            write_u64_le(data, 8, 2);
            refresh_header_checksum(data);
            break;
        case cold_file_fault::pair_state:
            data[16] = 2;
            refresh_header_checksum(data);
            break;
        case cold_file_fault::target_checksum:
            TEST_ASSERT(data.size() > sizeof(cold_store_header));
            data[sizeof(cold_store_header)] ^= 0xFF;
            break;
        case cold_file_fault::draft_checksum:
            TEST_ASSERT(data.size() > sizeof(cold_store_header) + target_bytes);
            data[sizeof(cold_store_header) + target_bytes] ^= 0xFF;
            break;
    }

    std::ofstream output(cold_file, std::ios::binary | std::ios::trunc);
    TEST_ASSERT(output.is_open());
    output.write(reinterpret_cast<const char *>(data.data()), static_cast<std::streamsize>(data.size()));
    TEST_ASSERT(static_cast<bool>(output));
}

static void run_promotion_failure_case(
        const char * dir_name,
        cold_file_fault fault,
        size_t target_bytes = 100,
        size_t draft_bytes = 0) {
    fs::path tmp_dir = reset_temp_dir(dir_name);
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        add_single_payload(*ctrl, target_bytes, draft_bytes);
        TEST_ASSERT(ctrl->tx_demote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::cold);

        corrupt_cold_file(tmp_dir, fault, target_bytes);
        TEST_ASSERT(!ctrl->tx_promote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::evicted);

        const json stats = ctrl->get_stats();
        TEST_ASSERT(stats["n_promotion_failures"].get<size_t>() == 1);
        TEST_ASSERT(stats["n_evicted_payload_descriptors"].get<size_t>() == 1);
    }
    fs::remove_all(tmp_dir);
}

static void run_read_failure_case(const char * dir_name) {
    fs::path tmp_dir = reset_temp_dir(dir_name);
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        add_single_payload(*ctrl);
        TEST_ASSERT(ctrl->tx_demote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::cold);

        ctrl->debug_set_cold_store_read_failure_for_tests(true);
        TEST_ASSERT(!ctrl->tx_promote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::evicted);

        const json stats = ctrl->get_stats();
        TEST_ASSERT(stats["n_promotion_failures"].get<size_t>() == 1);
        TEST_ASSERT(stats["n_evicted_payload_descriptors"].get<size_t>() == 1);
        ctrl->debug_set_cold_store_read_failure_for_tests(false);
    }
    fs::remove_all(tmp_dir);
}

// Test 1: residency hook reads stable sync state
void test_get_residency_state() {
    printf("step11: residency hook reads stable sync state...\n");
    fs::path tmp_dir = reset_temp_dir("step11_test_residency_state");
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        add_single_payload(*ctrl);
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::hot);
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(99999) == payload_residency_state::evicted);

        TEST_ASSERT(ctrl->tx_demote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::cold);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 2: promotion failure injection causes sync promotion failure
void test_inject_promotion_failure() {
    printf("step11: promotion failure injection causes sync promotion failure...\n");
    fs::path tmp_dir = reset_temp_dir("step11_test_promo_failure_inject");
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        add_single_payload(*ctrl);
        TEST_ASSERT(ctrl->tx_demote_payload(1));

        ctrl->debug_inject_promotion_failure_for_tests(1);
        TEST_ASSERT(!ctrl->tx_promote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::evicted);

        const json stats = ctrl->get_stats();
        TEST_ASSERT(stats["n_promotion_failures"].get<size_t>() == 1);
        TEST_ASSERT(stats["n_promotion_failure_checksum_mismatch"].get<size_t>() == 1);
        ctrl->debug_clear_promotion_failures_for_tests();
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 3: cold-store backend hook wires the inline worker helper
void test_set_cold_store_backend() {
    printf("step11: cold-store backend hook wires inline helper...\n");
    fs::path tmp_dir = reset_temp_dir("step11_test_cold_store_backend");
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        TEST_ASSERT(ctrl->debug_cold_store_for_tests().is_configured());
        add_single_payload(*ctrl);
        TEST_ASSERT(ctrl->tx_demote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::cold);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 4: sync demotion and promotion complete before return
void test_sync_transactions_complete_inline() {
    printf("step11: sync demotion and promotion complete before return...\n");
    fs::path tmp_dir = reset_temp_dir("step11_test_sync_inline");
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        add_single_payload(*ctrl);
        TEST_ASSERT(ctrl->tx_demote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::cold);

        TEST_ASSERT(ctrl->tx_promote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::hot);

        const json stats = ctrl->get_stats();
        TEST_ASSERT(stats["n_demotion_successes"].get<size_t>() == 1);
        TEST_ASSERT(stats["n_promotion_successes"].get<size_t>() == 1);
        assert_queue_metrics_zero(*ctrl);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 5: retired queue-capacity row has no sync-controller equivalent
void test_worker_queue_capacity_path_retired() {
    printf("step11: retired queue-capacity row has no sync-controller equivalent...\n");
    fs::path tmp_dir = reset_temp_dir("step11_test_queue_capacity_retired");
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        // The async queue was removed. The current local contract is that
        // inline demotion/promotion succeeds without a queue-pressure hook and
        // leaves both queue-pressure counters at zero.
        add_single_payload(*ctrl);
        TEST_ASSERT(ctrl->tx_demote_payload(1));
        TEST_ASSERT(ctrl->tx_promote_payload(1));
        assert_queue_metrics_zero(*ctrl);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 6: fault injection - checksum corruption before promotion
void test_fault_checksum_corruption() {
    printf("step11: fault injection - checksum corruption before promotion...\n");
    run_promotion_failure_case(
        "step11_fault_checksum",
        cold_file_fault::target_checksum);
    printf("  PASSED\n");
}

// Test 7: fault injection - header truncation read failure
void test_fault_header_truncation() {
    printf("step11: fault injection - header truncation read failure...\n");
    run_read_failure_case("step11_fault_truncation");
    printf("  PASSED\n");
}

// Test 8: fault injection - payload_id mismatch
void test_fault_payload_id_mismatch() {
    printf("step11: fault injection - payload_id mismatch...\n");
    run_promotion_failure_case(
        "step11_fault_payload_id",
        cold_file_fault::payload_id);
    printf("  PASSED\n");
}

// Test 9: fault injection - pair_state mismatch
void test_fault_pair_state_mismatch() {
    printf("step11: fault injection - pair_state mismatch...\n");
    run_promotion_failure_case(
        "step11_fault_pair_state",
        cold_file_fault::pair_state);
    printf("  PASSED\n");
}

// Test 10: fault injection - format_version unknown
void test_fault_format_version_unknown() {
    printf("step11: fault injection - format_version unknown...\n");
    run_promotion_failure_case(
        "step11_fault_format_version",
        cold_file_fault::format_version);
    printf("  PASSED\n");
}

// Test 11: fault injection - demotion write failure
void test_fault_demotion_write_failure() {
    printf("step11: fault injection - demotion write failure...\n");
    fs::path tmp_dir = reset_temp_dir("step11_fault_write_failure");
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);
        ctrl->debug_cold_store_for_tests().debug_set_write_failure_for_tests(true);

        add_single_payload(*ctrl);
        TEST_ASSERT(!ctrl->tx_demote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::hot);

        const json stats = ctrl->get_stats();
        TEST_ASSERT(stats["n_demotion_successes"].get<size_t>() == 0);
        TEST_ASSERT(stats["n_cold_payload_descriptors"].get<size_t>() == 0);
        ctrl->debug_cold_store_for_tests().debug_set_write_failure_for_tests(false);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 12: fault injection - retired queue-full demotion row
void test_fault_queue_full_demotion_path_retired() {
    printf("step11: fault injection - retired queue-full demotion row...\n");
    fs::path tmp_dir = reset_temp_dir("step11_fault_queue_full_demotion_retired");
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        // No worker queue exists in the sync model. Demotion completes inline;
        // this row guards the retired path by proving no queue-pressure metric
        // is raised during normal demotion.
        add_single_payload(*ctrl);
        TEST_ASSERT(ctrl->tx_demote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::cold);
        assert_queue_metrics_zero(*ctrl);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 13: fault injection - retired queue-full promotion row
void test_fault_queue_full_promotion_path_retired() {
    printf("step11: fault injection - retired queue-full promotion row...\n");
    fs::path tmp_dir = reset_temp_dir("step11_fault_queue_full_promotion_retired");
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        // Promotion uses the same inline transaction model, so the old queue
        // pressure branch has no current equivalent.
        add_single_payload(*ctrl);
        TEST_ASSERT(ctrl->tx_demote_payload(1));
        TEST_ASSERT(ctrl->tx_promote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::hot);
        assert_queue_metrics_zero(*ctrl);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 14: fault injection - retired worker shutdown race row
void test_fault_worker_shutdown_race_path_retired() {
    printf("step11: fault injection - retired worker shutdown race row...\n");
    fs::path tmp_dir = reset_temp_dir("step11_fault_shutdown_race_retired");
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        // There is no background worker to race with destruction. The current
        // equivalent is that any demotion requested before destruction has
        // already reached stable residency before the controller is released.
        add_single_payload(*ctrl);
        TEST_ASSERT(ctrl->tx_demote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::cold);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 15: fault injection - draft-side promotion failure for target_and_draft
void test_fault_draft_side_promotion_failure() {
    printf("step11: fault injection - draft-side promotion failure for target_and_draft...\n");
    fs::path tmp_dir = reset_temp_dir("step11_fault_draft_promo");
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        add_single_payload(*ctrl, 100, 50);
        TEST_ASSERT(ctrl->tx_demote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::cold);

        corrupt_cold_file(tmp_dir, cold_file_fault::draft_checksum, 100);
        TEST_ASSERT(!ctrl->tx_promote_payload(1));
        TEST_ASSERT(ctrl->debug_get_residency_state_for_tests(1) == payload_residency_state::evicted);

        const json stats = ctrl->get_stats();
        TEST_ASSERT(stats["n_promotion_failures"].get<size_t>() == 1);
        TEST_ASSERT(stats["n_promotion_failure_other"].get<size_t>() == 1);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 16: fault injection - magic mismatch
void test_fault_magic_mismatch() {
    printf("step11: fault injection - magic mismatch...\n");
    run_promotion_failure_case(
        "step11_fault_magic",
        cold_file_fault::magic);
    printf("  PASSED\n");
}

// Test 17: fault injection - header checksum mismatch
void test_fault_header_checksum_mismatch() {
    printf("step11: fault injection - header checksum mismatch...\n");
    run_promotion_failure_case(
        "step11_fault_header_checksum",
        cold_file_fault::header_checksum);
    printf("  PASSED\n");
}

int main() {
    printf("==================================================\n");
    printf("Step 11: Test hooks and fault injection\n");
    printf("==================================================\n\n");

    test_get_residency_state();
    test_inject_promotion_failure();
    test_set_cold_store_backend();
    test_sync_transactions_complete_inline();
    test_worker_queue_capacity_path_retired();
    test_fault_checksum_corruption();
    test_fault_header_truncation();
    test_fault_payload_id_mismatch();
    test_fault_pair_state_mismatch();
    test_fault_format_version_unknown();
    test_fault_demotion_write_failure();
    test_fault_queue_full_demotion_path_retired();
    test_fault_queue_full_promotion_path_retired();
    test_fault_worker_shutdown_race_path_retired();
    test_fault_draft_side_promotion_failure();
    test_fault_magic_mismatch();
    test_fault_header_checksum_mismatch();

    printf("\n==================================================\n");
    printf("Step 11: All tests PASSED\n");
    printf("==================================================\n");
    return 0;
}
