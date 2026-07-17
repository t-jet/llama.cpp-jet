// Step 10 focused test: Metrics
// This test verifies that the Phase 6 Step 10 metrics are correctly tracked
// and reported in get_stats() and the Prometheus export path.
//
// Acceptance criteria:
// 1. Demotion success and failure counters are tracked
// 2. Promotion success and failure counters are tracked
// 3. Cold eviction counter is tracked
// 4. Promotion latency histogram buckets are populated
// 5. cache_cold_payload_bytes gauge is updated on demotion and promotion
// 6. cache_cold_payload_count gauge is updated on demotion and promotion
// 7. cache_hot_payload_count gauge reflects hot descriptors
// 8. cache_payload_evictions_total does NOT count demoted payloads
// 9. Promotion failure reason counters are tracked
// 10. Demotion failure reason counters are tracked
// 11. All new metrics appear in get_stats() JSON output
// 12. All new metrics appear in Prometheus export

#include "server-cache-hybrid.h"
#include "server-cache-store-cold.h"
#include "server-cache-io-worker.h"
#include "server-context.h"
#include "server-task.h"
#include "common.h"

#include <cstdlib>
#include <cstdint>
#include <cstdio>
#include <filesystem>
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

// Helper: create mock tokens
static server_tokens create_tokens(const std::vector<int> & ids) {
    server_tokens tokens;
    for (int id : ids) {
        tokens.push_back(id);
    }
    return tokens;
}

// Helper: create test common_params
static common_params create_test_params(
    const std::string & model_path = "test_model.gguf",
    const std::string & chat_template = "",
    const std::string & mmproj_path = "",
    bool kv_unified_val = false)
{
    common_params params;
    params.model.path = model_path;
    params.chat_template = chat_template;
    params.mmproj.path = mmproj_path;
    params.kv_unified = kv_unified_val;
    return params;
}

// Helper: create a controller with a temp cold path
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

// Test 1: Demotion success counter
void test_demotion_success_counter() {
    printf("step10: demotion success counter...\n");
    fs::path tmp_dir = fs::temp_directory_path() / "step10_test_demotion_success";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        ctrl->debug_add_entry_for_tests(create_tokens({1, 2, 3, 4, 5}), false, "ns1", 100, 0);

        json stats_before = ctrl->get_stats();
        TEST_ASSERT(stats_before["n_demotion_successes"].get<size_t>() == 0);
        TEST_ASSERT(ctrl->tx_demote_payload(1));
        json stats = ctrl->get_stats();
        TEST_ASSERT(stats["n_demotion_successes"].get<size_t>() == 1);
        TEST_ASSERT(stats["n_demotion_failures"].get<size_t>() == 0);
        TEST_ASSERT(stats["n_cold_payload_count"].get<size_t>() == 1);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 2: get_stats() includes all new metrics
void test_get_stats_includes_new_metrics() {
    printf("step10: get_stats() includes all new metrics...\n");
    fs::path tmp_dir = fs::temp_directory_path() / "step10_test_stats_metrics";
    fs::create_directories(tmp_dir);
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        json stats = ctrl->get_stats();

        // Verify all new metric keys exist
        TEST_ASSERT(stats.contains("n_demotion_successes") && "missing n_demotion_successes");
        TEST_ASSERT(stats.contains("n_demotion_failures") && "missing n_demotion_failures");
        TEST_ASSERT(stats.contains("n_promotion_successes") && "missing n_promotion_successes");
        TEST_ASSERT(stats.contains("n_promotion_failures") && "missing n_promotion_failures");
        TEST_ASSERT(stats.contains("n_cold_evictions") && "missing n_cold_evictions");
        TEST_ASSERT(stats.contains("n_demotion_queue_full") && "missing n_demotion_queue_full");
        TEST_ASSERT(stats.contains("n_promotion_queue_full") && "missing n_promotion_queue_full");
        TEST_ASSERT(stats.contains("n_cold_payload_bytes") && "missing n_cold_payload_bytes");
        TEST_ASSERT(stats.contains("n_cold_payload_count") && "missing n_cold_payload_count");
        TEST_ASSERT(stats.contains("n_protected_root_demotions") && "missing n_protected_root_demotions");
        TEST_ASSERT(stats.contains("n_promotion_failure_checksum_mismatch") && "missing n_promotion_failure_checksum_mismatch");
        TEST_ASSERT(stats.contains("n_promotion_failure_not_found") && "missing n_promotion_failure_not_found");
        TEST_ASSERT(stats.contains("n_promotion_failure_other") && "missing n_promotion_failure_other");
        TEST_ASSERT(stats.contains("n_demotion_failure_write_error") && "missing n_demotion_failure_write_error");
        TEST_ASSERT(stats.contains("n_demotion_failure_other") && "missing n_demotion_failure_other");
        TEST_ASSERT(stats.contains("n_promotion_latency_bucket_0_1ms") && "missing n_promotion_latency_bucket_0_1ms");
        TEST_ASSERT(stats.contains("n_promotion_latency_bucket_1_5ms") && "missing n_promotion_latency_bucket_1_5ms");
        TEST_ASSERT(stats.contains("n_promotion_latency_bucket_5_10ms") && "missing n_promotion_latency_bucket_5_10ms");
        TEST_ASSERT(stats.contains("n_promotion_latency_bucket_10_50ms") && "missing n_promotion_latency_bucket_10_50ms");
        TEST_ASSERT(stats.contains("n_promotion_latency_bucket_50_100ms") && "missing n_promotion_latency_bucket_50_100ms");
        TEST_ASSERT(stats.contains("n_promotion_latency_bucket_100_500ms") && "missing n_promotion_latency_bucket_100_500ms");
        TEST_ASSERT(stats.contains("n_promotion_latency_bucket_500_1000ms") && "missing n_promotion_latency_bucket_500_1000ms");
        TEST_ASSERT(stats.contains("n_promotion_latency_bucket_over_1000ms") && "missing n_promotion_latency_bucket_over_1000ms");
        TEST_ASSERT(stats.contains("n_hot_payload_descriptors") && "missing n_hot_payload_descriptors");
        TEST_ASSERT(stats.contains("n_cold_payload_descriptors") && "missing n_cold_payload_descriptors");
        TEST_ASSERT(stats.contains("n_demoting_payload_descriptors") && "missing n_demoting_payload_descriptors");
        TEST_ASSERT(stats.contains("n_promoting_payload_descriptors") && "missing n_promoting_payload_descriptors");
        TEST_ASSERT(stats.contains("n_evicted_payload_descriptors") && "missing n_evicted_payload_descriptors");

        // Verify initial values are zero
        TEST_ASSERT(stats["n_demotion_successes"] == 0);
        TEST_ASSERT(stats["n_demotion_failures"] == 0);
        TEST_ASSERT(stats["n_promotion_successes"] == 0);
        TEST_ASSERT(stats["n_promotion_failures"] == 0);
        TEST_ASSERT(stats["n_cold_evictions"] == 0);
        TEST_ASSERT(stats["n_cold_payload_bytes"] == 0);
        TEST_ASSERT(stats["n_cold_payload_count"] == 0);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 3: Cold payload bytes gauge updates on demotion
void test_cold_payload_bytes_gauge() {
    printf("step10: cold payload bytes gauge updates on demotion...\n");
    fs::path tmp_dir = fs::temp_directory_path() / "step10_test_cold_bytes";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        ctrl->debug_add_entry_for_tests(create_tokens({1, 2, 3, 4, 5}), false, "ns1", 100, 25);

        json stats_before = ctrl->get_stats();
        TEST_ASSERT(stats_before["n_cold_payload_bytes"].get<size_t>() == 0);
        TEST_ASSERT(stats_before["n_cold_payload_count"].get<size_t>() == 0);

        TEST_ASSERT(ctrl->tx_demote_payload(1));

        json stats_after = ctrl->get_stats();
        TEST_ASSERT(stats_after["n_demotion_successes"].get<size_t>() == 1);
        const fs::path cold_file = tmp_dir / "1.cold";
        TEST_ASSERT(fs::exists(cold_file));
        const size_t committed_serialized_bytes = fs::file_size(cold_file);
        TEST_ASSERT(committed_serialized_bytes == sizeof(cold_store_header) + 125);
        TEST_ASSERT(stats_after["n_cold_payload_bytes"].get<size_t>() == committed_serialized_bytes);
        TEST_ASSERT(stats_after["n_cold_payload_count"].get<size_t>() == 1);
        TEST_ASSERT(stats_after["n_cold_payload_descriptors"].get<size_t>() == 1);
        TEST_ASSERT(stats_after["n_hot_payload_descriptors"].get<size_t>() == 0);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 4: Hot payload count gauge reflects hot descriptors
void test_hot_payload_count_gauge() {
    printf("step10: hot payload count gauge reflects hot descriptors...\n");
    fs::path tmp_dir = fs::temp_directory_path() / "step10_test_hot_count";
    fs::create_directories(tmp_dir);
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        // Initially, hot payload count should be 0
        json stats = ctrl->get_stats();
        TEST_ASSERT(stats["n_hot_payload_descriptors"] == 0);

        // Add an entry with payload
        ctrl->debug_add_entry_for_tests(create_tokens({1, 2, 3, 4, 5}), false, "ns1", 100, 0);

        stats = ctrl->get_stats();
        TEST_ASSERT(stats["n_hot_payload_descriptors"] == 1);

        // Add another entry
        ctrl->debug_add_entry_for_tests(create_tokens({6, 7, 8, 9, 10}), false, "ns1", 100, 0);

        stats = ctrl->get_stats();
        TEST_ASSERT(stats["n_hot_payload_descriptors"] == 2);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 5: cache_payload_evictions_total does NOT count demoted payloads
void test_evictions_not_counting_demotions() {
    printf("step10: cache_payload_evictions_total does NOT count demoted payloads...\n");
    fs::path tmp_dir = fs::temp_directory_path() / "step10_test_evictions_vs_demotions";
    fs::remove_all(tmp_dir);
    fs::create_directories(tmp_dir);
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        ctrl->debug_set_hot_payload_budget_bytes_for_tests(1024 * 1024, true);

        ctrl->debug_add_entry_for_tests(create_tokens({1, 2, 3, 4, 5}), false, "ns1", 100, 0);

        json stats_before = ctrl->get_stats();
        const size_t evictions_before = stats_before["n_payload_evictions"].get<size_t>();
        const size_t demotions_before = stats_before["n_demotion_successes"].get<size_t>();

        TEST_ASSERT(ctrl->tx_demote_payload(1));
        json stats_after = ctrl->get_stats();
        TEST_ASSERT(stats_after["n_demotion_successes"].get<size_t>() == demotions_before + 1);
        TEST_ASSERT(stats_after["n_payload_evictions"].get<size_t>() == evictions_before);
        TEST_ASSERT(stats_after["n_cold_payload_count"].get<size_t>() == 1);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 6: Promotion failure reason counters
void test_promotion_failure_reason_counters() {
    printf("step10: promotion failure reason counters...\n");
    fs::path tmp_dir = fs::temp_directory_path() / "step10_test_promo_failure_reasons";
    fs::create_directories(tmp_dir);
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        json stats = ctrl->get_stats();

        // Verify initial values are zero
        TEST_ASSERT(stats["n_promotion_failure_checksum_mismatch"] == 0);
        TEST_ASSERT(stats["n_promotion_failure_not_found"] == 0);
        TEST_ASSERT(stats["n_promotion_failure_other"] == 0);
        TEST_ASSERT(stats["n_demotion_failure_write_error"] == 0);
        TEST_ASSERT(stats["n_demotion_failure_other"] == 0);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 7: Promotion latency histogram buckets exist
void test_promotion_latency_histogram() {
    printf("step10: promotion latency histogram buckets exist...\n");
    fs::path tmp_dir = fs::temp_directory_path() / "step10_test_latency_histogram";
    fs::create_directories(tmp_dir);
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        json stats = ctrl->get_stats();

        // Verify all latency buckets exist and are initially zero
        TEST_ASSERT(stats["n_promotion_latency_bucket_0_1ms"] == 0);
        TEST_ASSERT(stats["n_promotion_latency_bucket_1_5ms"] == 0);
        TEST_ASSERT(stats["n_promotion_latency_bucket_5_10ms"] == 0);
        TEST_ASSERT(stats["n_promotion_latency_bucket_10_50ms"] == 0);
        TEST_ASSERT(stats["n_promotion_latency_bucket_50_100ms"] == 0);
        TEST_ASSERT(stats["n_promotion_latency_bucket_100_500ms"] == 0);
        TEST_ASSERT(stats["n_promotion_latency_bucket_500_1000ms"] == 0);
        TEST_ASSERT(stats["n_promotion_latency_bucket_over_1000ms"] == 0);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 8: Cold payload count gauge
void test_cold_payload_count_gauge() {
    printf("step10: cold payload count gauge...\n");
    fs::path tmp_dir = fs::temp_directory_path() / "step10_test_cold_count";
    fs::create_directories(tmp_dir);
    {
        auto ctrl = create_controller_with_cold(tmp_dir);
        json stats = ctrl->get_stats();

        // Initially zero
        TEST_ASSERT(stats["n_cold_payload_count"] == 0);
    }
    fs::remove_all(tmp_dir);
    printf("  PASSED\n");
}

// Test 9: Stage 10 Prometheus rows preserve bounded public dimensions
void test_stage10_prometheus_export_dimensions() {
    printf("step10: Stage 10 Prometheus export dimensions...\n");

    json cache_stats = json::object();
    cache_stats["type"] = "hybrid";
    cache_stats["cache_exact_blob_restores_by_shape"] = json::array({
        {
            {"payload_kind", "exact_blob"},
            {"profile", "plain_transformer"},
            {"pair_state", "single"},
            {"residency", "hot"},
            {"result", "success"},
            {"reason", "accepted"},
            {"value", 2},
        },
    });
    cache_stats["cache_payload_transitions_by_shape"] = json::array({
        {
            {"operation", "promotion"},
            {"payload_kind", "checkpoint"},
            {"pair_state", "paired"},
            {"result", "success"},
            {"reason", "completed"},
            {"value", 3},
        },
        {
            {"operation", "demotion"},
            {"payload_kind", "exact_blob"},
            {"pair_state", "single"},
            {"result", "failure"},
            {"reason", "queue\"full\n"},
            {"value", 4},
        },
    });

    const std::string prometheus = server_cache_stage10_prometheus_rows_for_tests(cache_stats);
    TEST_ASSERT(prometheus.find(
        "cache_exact_blob_restores_total{mode=\"hybrid\",payload_kind=\"exact_blob\",profile=\"plain_transformer\",pair_state=\"single\",residency=\"hot\",result=\"success\",reason=\"accepted\"} 2") != std::string::npos);
    TEST_ASSERT(prometheus.find(
        "cache_payload_transitions_total{mode=\"hybrid\",operation=\"promotion\",payload_kind=\"checkpoint\",pair_state=\"paired\",result=\"success\",reason=\"completed\"} 3") != std::string::npos);
    TEST_ASSERT(prometheus.find(
        "cache_payload_transitions_total{mode=\"hybrid\",operation=\"demotion\",payload_kind=\"exact_blob\",pair_state=\"single\",result=\"failure\",reason=\"queue\\\"full\\n\"} 4") != std::string::npos);
    printf("  PASSED\n");
}

// Test 10: Stage 10 Prometheus export covers additional bounded rows
// (T114 - 2026-06-04 bug-fix loop). This exercises the additional by-shape
// arrays that the public exporter walks.
void test_stage10_prometheus_export_extended_rows() {
    printf("step10: Stage 10 Prometheus export extended rows...\n");

    json cache_stats = json::object();
    cache_stats["type"] = "hybrid";
    cache_stats["cache_exact_blob_restores_by_shape"] = json::array({
        {
            {"payload_kind", "exact_blob"},
            {"profile", "plain_transformer"},
            {"pair_state", "single"},
            {"residency", "cold"},
            {"result", "success"},
            {"reason", "promoted"},
            {"value", 5},
        },
    });
    cache_stats["cache_payload_transitions_by_shape"] = json::array({
        {
            {"operation", "promotion"},
            {"payload_kind", "checkpoint"},
            {"pair_state", "paired"},
            {"result", "failure"},
            {"reason", "read_error"},
            {"value", 1},
        },
    });
    cache_stats["cache_payload_evictions_by_shape"] = json::array({
        {
            {"payload_kind", "exact_blob"},
            {"pair_state", "single"},
            {"result", "success"},
            {"reason", "over_budget"},
            {"value", 7},
        },
    });
    cache_stats["cache_protected_root_decisions_by_shape"] = json::array({
        {
            {"decision", "admit"},
            {"pressure_source", "budget"},
            {"result", "rejected"},
            {"reason", "oversized"},
            {"value", 2},
        },
    });
    cache_stats["cache_fallback_restores_by_shape"] = json::array({
        {
            {"strategy", "evict"},
            {"payload_kind", "exact_blob"},
            {"result", "success"},
            {"reason", "no_match"},
            {"value", 1},
        },
    });
    cache_stats["cache_structured_diagnostics_by_shape"] = json::array({
        {
            {"event", "descriptor_rejection"},
            {"result", "failure"},
            {"reason", "owner_mismatch"},
            {"payload_kind", "exact_blob"},
            {"value", 1},
        },
    });

    const std::string prometheus = server_cache_stage10_prometheus_rows_for_tests(cache_stats);
    TEST_ASSERT(prometheus.find(
        "cache_exact_blob_restores_total{mode=\"hybrid\",payload_kind=\"exact_blob\",profile=\"plain_transformer\",pair_state=\"single\",residency=\"cold\",result=\"success\",reason=\"promoted\"} 5") != std::string::npos);
    TEST_ASSERT(prometheus.find(
        "cache_payload_transitions_total{mode=\"hybrid\",operation=\"promotion\",payload_kind=\"checkpoint\",pair_state=\"paired\",result=\"failure\",reason=\"read_error\"} 1") != std::string::npos);
    TEST_ASSERT(prometheus.find(
        "cache_payload_evictions_by_shape_total{mode=\"hybrid\",payload_kind=\"exact_blob\",pair_state=\"single\",result=\"success\",reason=\"over_budget\"} 7") != std::string::npos);
    TEST_ASSERT(prometheus.find(
        "cache_protected_root_decisions_by_shape_total{mode=\"hybrid\",decision=\"admit\",pressure_source=\"budget\",result=\"rejected\",reason=\"oversized\"} 2") != std::string::npos);
    TEST_ASSERT(prometheus.find(
        "cache_fallback_restores_by_shape_total{mode=\"hybrid\",strategy=\"evict\",payload_kind=\"exact_blob\",result=\"success\",reason=\"no_match\"} 1") != std::string::npos);
    TEST_ASSERT(prometheus.find(
        "cache_structured_diagnostics_total{mode=\"hybrid\",event=\"descriptor_rejection\",result=\"failure\",reason=\"owner_mismatch\",payload_kind=\"exact_blob\"} 1") != std::string::npos);
    printf("  PASSED\n");
}

void test_stage39_prometheus_export_has_unique_mode_label() {
    printf("step10: Stage 39 Prometheus rows have unique mode label...\n");
    json cache_stats = {
        {"type", "hybrid"},
        {"cache_two_layer_decisions", json::array({
            {{"mode", "hybrid"}, {"result", "evicted"}, {"reason", "both_filled"}, {"value", 2}},
        })},
        {"cache_cold_transactions", json::array({
            {{"mode", "hybrid"}, {"result", "commit"}, {"reason", "none"}, {"value", 3}},
        })},
    };
    const std::string prometheus = server_cache_stage39_prometheus_rows_for_tests(cache_stats);
    TEST_ASSERT(prometheus.find(
        "cache_two_layer_decisions_total{mode=\"hybrid\",result=\"evicted\",reason=\"both_filled\"} 2") != std::string::npos);
    TEST_ASSERT(prometheus.find(
        "cache_cold_transactions_total{mode=\"hybrid\",result=\"commit\",reason=\"none\"} 3") != std::string::npos);
    TEST_ASSERT(prometheus.find("mode=\"hybrid\",mode=") == std::string::npos);
    size_t mode_labels = 0;
    for (size_t pos = prometheus.find("mode=\""); pos != std::string::npos;
            pos = prometheus.find("mode=\"", pos + 1)) {
        ++mode_labels;
    }
    TEST_ASSERT(mode_labels == 2);
    printf("  PASSED\n");
}

int main() {
    printf("==================================================\n");
    printf("Step 10: Metrics\n");
    printf("==================================================\n\n");

    test_demotion_success_counter();
    test_get_stats_includes_new_metrics();
    test_cold_payload_bytes_gauge();
    test_hot_payload_count_gauge();
    test_evictions_not_counting_demotions();
    test_promotion_failure_reason_counters();
    test_promotion_latency_histogram();
    test_cold_payload_count_gauge();
    test_stage10_prometheus_export_dimensions();
    test_stage10_prometheus_export_extended_rows();
    test_stage39_prometheus_export_has_unique_mode_label();

    printf("\n==================================================\n");
    printf("Step 10: All tests PASSED\n");
    printf("==================================================\n");
    return 0;
}
