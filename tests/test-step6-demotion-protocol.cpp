#include "server-cache-hybrid.h"
#include "server-cache-store-cold.h"
#include "common.h"

#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <string>
#include <vector>

#define REQUIRE(cond, message) do { if (!(cond)) { std::fprintf(stderr, "FAIL: %s\n", message); std::abort(); } } while (0)

namespace fs = std::filesystem;

static server_tokens tokens(std::initializer_list<int> ids) {
    server_tokens result;
    for (int id : ids) result.push_back(id);
    return result;
}

static common_params params() {
    common_params result;
    result.model.path = "test_model.gguf";
    return result;
}

static fs::path fresh_dir(const char * name) {
    const fs::path path = fs::temp_directory_path() / (std::string("step6_sync_") + name);
    std::error_code ec;
    fs::remove_all(path, ec);
    fs::create_directories(path, ec);
    REQUIRE(!ec, "could not create cold-store fixture");
    return path;
}

static void test_sync_demotion_commits_cold_payload() {
    const fs::path root = fresh_dir("commit");
    hybrid_cache_controller ctrl(params(), 2, 1000, nullptr, nullptr);
    ctrl.debug_set_cold_store_for_tests(root.string());
    ctrl.debug_add_entry_for_tests(tokens({1, 2, 3}), false, "step6", 128, 0);
    REQUIRE(ctrl.demote_payload(1), "synchronous demotion failed");
    const auto stats = ctrl.get_stats();
    REQUIRE(stats["n_cold_payload_descriptors"] == 1, "descriptor did not become cold");
    REQUIRE(stats["n_demotion_successes"] == 1, "success counter mismatch");
    REQUIRE(stats["n_cold_payload_bytes"] == 128, "cold payload bytes mismatch");
    std::error_code ec;
    fs::remove_all(root, ec);
}

static void test_sync_demotion_rejects_invalid_inputs() {
    hybrid_cache_controller missing_store(params(), 2, 1000, nullptr, nullptr);
    missing_store.debug_add_entry_for_tests(tokens({4, 5}), false, "step6", 64, 0);
    REQUIRE(!missing_store.demote_payload(1), "demotion accepted without cold store");
    REQUIRE(!missing_store.demote_payload(999), "demotion accepted unknown payload");

    const fs::path root = fresh_dir("invalid");
    hybrid_cache_controller invalid_state(params(), 2, 1000, nullptr, nullptr);
    invalid_state.debug_set_cold_store_for_tests(root.string());
    invalid_state.debug_add_entry_for_tests(tokens({6, 7}), false, "step6", 64, 0);
    REQUIRE(invalid_state.debug_inject_first_payload_fault_for_tests(payload_debug_fault::demoting_residency),
        "could not create demoting-state fixture");
    REQUIRE(!invalid_state.demote_payload(1), "demotion accepted non-hot descriptor");
    std::error_code ec;
    fs::remove_all(root, ec);
}

static void test_target_draft_pair_is_atomic() {
    const fs::path root = fresh_dir("pair");
    hybrid_cache_controller ctrl(params(), 2, 1000, nullptr, nullptr);
    ctrl.debug_set_cold_store_for_tests(root.string());
    ctrl.debug_add_entry_for_tests(tokens({8, 9}), false, "step6-pair", 128, 64);
    REQUIRE(ctrl.demote_payload(1), "target/draft demotion failed");
    const auto stats = ctrl.get_stats();
    REQUIRE(stats["n_target_and_draft_payload_descriptors"] == 1, "pair descriptor lost");
    REQUIRE(stats["n_cold_payload_descriptors"] == 1, "pair was not committed atomically");
    REQUIRE(stats["n_cold_payload_bytes"] == 192, "pair cold payload bytes mismatch");
    std::error_code ec;
    fs::remove_all(root, ec);
}

static void test_pressure_demotes_before_eviction() {
    const fs::path root = fresh_dir("pressure");
    hybrid_cache_controller ctrl(params(), 100, 1000, nullptr, nullptr);
    ctrl.debug_set_hot_payload_budget_bytes_for_tests(200);
    ctrl.debug_set_cold_store_for_tests(root.string());
    ctrl.debug_add_entry_for_tests(tokens({10}), false, "step6-pressure", 150, 0);
    ctrl.debug_add_entry_for_tests(tokens({11}), false, "step6-pressure", 150, 0);
    const auto stats = ctrl.get_stats();
    REQUIRE(stats["resident_payload_bytes"].get<size_t>() <= 200, "hot budget exceeded");
    REQUIRE(stats["n_demotion_successes"].get<size_t>() == 1, "pressure did not demote victim");
    REQUIRE(stats["n_payload_evictions"].get<size_t>() == 0, "payload evicted while cold had room");
    REQUIRE(ctrl.debug_entry_count_for_tests() == 2, "payload pressure removed lookup entry");
    std::error_code ec;
    fs::remove_all(root, ec);
}

int main() {
    test_sync_demotion_commits_cold_payload();
    test_sync_demotion_rejects_invalid_inputs();
    test_target_draft_pair_is_atomic();
    test_pressure_demotes_before_eviction();
    std::puts("test-step6-demotion-protocol: PASS");
    return 0;
}
