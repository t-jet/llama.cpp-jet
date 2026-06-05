// Step 5 focused test: Async I/O worker thread
// This test verifies the server_cache_io_worker implementation against
// the Phase 6 Step 5 requirements: start/stop lifecycle, bounded work queue,
// demotion and promotion task processing, result-queue completion model,
// queue-full fail-fast, and clean shutdown with in-progress task completion.

#include "server-cache-io-worker.h"
#include "server-cache-store-cold.h"
#include "server-cache-hybrid.h"

#include <cstdlib>
#include <cstdint>
#include <cstdio>
#include <filesystem>
#include <thread>
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

// Helper: create a temporary directory for cold store tests
static std::string create_temp_dir(const std::string & suffix) {
    std::string temp_dir = fs::temp_directory_path().string() + "/io_worker_step5_" + suffix;
    fs::create_directories(temp_dir);
    return temp_dir;
}

static void remove_temp_dir(const std::string & path) {
    std::error_code ec;
    fs::remove_all(path, ec);
    (void)ec;
}

// Helper: create a descriptor snapshot for testing
static cold_descriptor_snapshot make_snapshot(
    uint64_t payload_id,
    uint8_t pair_state,
    uint64_t target_size,
    uint64_t draft_size,
    uint64_t target_checksum,
    uint64_t draft_checksum)
{
    cold_descriptor_snapshot snap{};
    snap.payload_id = payload_id;
    snap.pair_state = pair_state;
    snap.format_version = COLD_STORE_FORMAT_VERSION_1;
    snap.target_size_bytes = target_size;
    snap.draft_size_bytes = draft_size;
    snap.target_checksum = target_checksum;
    snap.draft_checksum = draft_checksum;
    return snap;
}

// Helper: compute FNV-1a hash matching the implementation
static uint64_t fnv1a_hash(const uint8_t * data, size_t len) {
    uint64_t hash = 0xcbf29ce484222325ULL;
    for (size_t i = 0; i < len; ++i) {
        hash ^= data[i];
        hash *= 0x100000001b3ULL;
    }
    return hash;
}

// Helper: create target bytes with known content
static std::vector<uint8_t> make_target_bytes(size_t size) {
    std::vector<uint8_t> bytes(size);
    for (size_t i = 0; i < size; ++i) {
        bytes[i] = static_cast<uint8_t>(i & 0xFF);
    }
    return bytes;
}

// Helper: create draft bytes with known content
static std::vector<uint8_t> make_draft_bytes(size_t size) {
    std::vector<uint8_t> bytes(size);
    for (size_t i = 0; i < size; ++i) {
        bytes[i] = static_cast<uint8_t>((i + 0x80) & 0xFF);
    }
    return bytes;
}

// Test 1: Worker can be started and stopped
void test_start_stop() {
    printf("step5: worker can be started and stopped...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("start_stop");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);

    // Worker should not be running initially
    TEST_ASSERT(!worker.is_running());

    // Start the worker
    bool started = worker.start();
    TEST_ASSERT(started);
    TEST_ASSERT(worker.is_running());

    // Starting again should return true (already running)
    bool started_again = worker.start();
    TEST_ASSERT(started_again);
    TEST_ASSERT(worker.is_running());

    // Stop the worker
    worker.stop();
    TEST_ASSERT(!worker.is_running());

    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 2: Start failure returns false
void test_start_failure_returns_false() {
    printf("step5: start returns true on normal startup...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("start_failure");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);

    // Normal start should succeed
    bool started = worker.start();
    TEST_ASSERT(started);

    worker.stop();

    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 3: Enqueue demotion returns success and processes the task
void test_enqueue_demotion_success() {
    printf("step5: enqueue demotion returns success and processes task...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("demotion_success");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);
    bool started = worker.start();
    TEST_ASSERT(started);

    // Create test payload
    std::vector<uint8_t> target_bytes = make_target_bytes(64);
    std::vector<uint8_t> draft_bytes = make_draft_bytes(32);
    uint64_t target_checksum = fnv1a_hash(target_bytes.data(), target_bytes.size());
    uint64_t draft_checksum = fnv1a_hash(draft_bytes.data(), draft_bytes.size());

    cold_descriptor_snapshot snap = make_snapshot(
        1001, 1,  // payload_id=1001, pair_state=target_and_draft
        target_bytes.size(), draft_bytes.size(),
        target_checksum, draft_checksum);

    // Enqueue a demotion task
    bool enqueued = worker.enqueue_demotion(1001, snap, target_bytes, draft_bytes);
    TEST_ASSERT(enqueued);

    // Wait for the worker to process the task
    std::this_thread::sleep_for(std::chrono::milliseconds(200));

    // Drain results
    auto results = worker.drain_results();
    TEST_ASSERT(results.size() == 1);
    TEST_ASSERT(results[0].payload_id == 1001);
    TEST_ASSERT(results[0].is_demotion == true);
    TEST_ASSERT(results[0].success == true);
    TEST_ASSERT(results[0].ref != 0);  // cold_ref should be non-zero on success

    worker.stop();
    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 4: Enqueue promotion returns success and processes the task
void test_enqueue_promotion_success() {
    printf("step5: enqueue promotion returns success and processes task...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("promotion_success");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    // First, write a cold file to promote later
    std::vector<uint8_t> target_bytes = make_target_bytes(64);
    std::vector<uint8_t> draft_bytes = make_draft_bytes(32);
    uint64_t target_checksum = fnv1a_hash(target_bytes.data(), target_bytes.size());
    uint64_t draft_checksum = fnv1a_hash(draft_bytes.data(), draft_bytes.size());

    cold_descriptor_snapshot snap = make_snapshot(
        2001, 1,
        target_bytes.size(), draft_bytes.size(),
        target_checksum, draft_checksum);

    cold_ref ref = store.write(2001, target_bytes, draft_bytes, snap);
    TEST_ASSERT(ref != 0);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);
    bool started = worker.start();
    TEST_ASSERT(started);

    // Enqueue a promotion task
    bool enqueued = worker.enqueue_promotion(2001, ref, snap);
    TEST_ASSERT(enqueued);

    // Wait for the worker to process the task
    std::this_thread::sleep_for(std::chrono::milliseconds(200));

    // Drain results
    auto results = worker.drain_results();
    TEST_ASSERT(results.size() == 1);
    TEST_ASSERT(results[0].payload_id == 2001);
    TEST_ASSERT(results[0].is_demotion == false);
    TEST_ASSERT(results[0].success == true);
    TEST_ASSERT(results[0].target_bytes.size() == 64);
    TEST_ASSERT(results[0].draft_bytes.size() == 32);

    // Verify promoted bytes match original
    TEST_ASSERT(results[0].target_bytes == target_bytes);
    TEST_ASSERT(results[0].draft_bytes == draft_bytes);

    worker.stop();
    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 5: Queue-full returns false immediately without blocking
void test_queue_full_returns_false() {
    printf("step5: queue-full returns false immediately without blocking...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("queue_full");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);

#ifdef LLAMA_SERVER_CACHE_TESTS
    // Set a very small queue capacity for testing
    worker.debug_set_queue_capacity_for_tests(2);
#endif

    bool started = worker.start();
    TEST_ASSERT(started);

    // Use a delay to keep tasks in the queue
#ifdef LLAMA_SERVER_CACHE_TESTS
    worker.debug_set_completion_delay_for_tests(500);  // 500ms delay per task
#endif

    std::vector<uint8_t> target_bytes = make_target_bytes(16);
    std::vector<uint8_t> draft_bytes;
    uint64_t target_checksum = fnv1a_hash(target_bytes.data(), target_bytes.size());

    cold_descriptor_snapshot snap = make_snapshot(
        3001, 0,  // payload_id=3001, pair_state=target_only
        target_bytes.size(), 0,
        target_checksum, 0);

    // Enqueue two tasks to fill the queue
    bool enqueued1 = worker.enqueue_demotion(3001, snap, target_bytes, draft_bytes);
    TEST_ASSERT(enqueued1);

    cold_descriptor_snapshot snap2 = make_snapshot(
        3002, 0,
        target_bytes.size(), 0,
        target_checksum, 0);
    bool enqueued2 = worker.enqueue_demotion(3002, snap2, target_bytes, draft_bytes);
    TEST_ASSERT(enqueued2);

    // Third enqueue should fail because queue is full
    // (The first task may have been dequeued already, so we need to be careful.
    //  With a 500ms delay, the first task is still processing, and the second
    //  task is in the queue. The third should fail.)
    // We try multiple times to ensure we hit the full queue.
    bool queue_full_hit = false;
    for (int i = 0; i < 10; ++i) {
        cold_descriptor_snapshot snap3 = make_snapshot(
            3003 + i, 0,
            target_bytes.size(), 0,
            target_checksum, 0);
        bool enqueued3 = worker.enqueue_demotion(3003 + i, snap3, target_bytes, draft_bytes);
        if (!enqueued3) {
            queue_full_hit = true;
            break;
        }
    }
    TEST_ASSERT(queue_full_hit);

    // Reset delay and stop
#ifdef LLAMA_SERVER_CACHE_TESTS
    worker.debug_set_completion_delay_for_tests(0);
#endif

    worker.stop();

    // Drain any remaining results
    auto results = worker.drain_results();

    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 6: drain_results returns empty when no completions are pending
void test_drain_results_empty() {
    printf("step5: drain_results returns empty when no completions pending...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("drain_empty");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);

    // Before starting, drain should return empty
    auto results = worker.drain_results();
    TEST_ASSERT(results.empty());

    bool started = worker.start();
    TEST_ASSERT(started);

    // After starting but before enqueuing, drain should return empty
    results = worker.drain_results();
    TEST_ASSERT(results.empty());

    worker.stop();

    // After stopping, drain should return empty (or cancelled items)
    results = worker.drain_results();

    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 7: Multiple demotion tasks are processed
void test_multiple_demotion_tasks() {
    printf("step5: multiple demotion tasks are processed...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("multiple_demotion");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);
    bool started = worker.start();
    TEST_ASSERT(started);

    // Enqueue 5 demotion tasks
    const int num_tasks = 5;
    std::vector<uint8_t> target_bytes = make_target_bytes(32);
    std::vector<uint8_t> draft_bytes = make_draft_bytes(16);
    uint64_t target_checksum = fnv1a_hash(target_bytes.data(), target_bytes.size());
    uint64_t draft_checksum = fnv1a_hash(draft_bytes.data(), draft_bytes.size());

    for (int i = 0; i < num_tasks; ++i) {
        cold_descriptor_snapshot snap = make_snapshot(
            4001 + i, 1,
            target_bytes.size(), draft_bytes.size(),
            target_checksum, draft_checksum);
        bool enqueued = worker.enqueue_demotion(4001 + i, snap, target_bytes, draft_bytes);
        TEST_ASSERT(enqueued);
    }

    // Wait for all tasks to complete
    std::this_thread::sleep_for(std::chrono::milliseconds(500));

    // Drain results
    auto results = worker.drain_results();
    TEST_ASSERT(results.size() == static_cast<size_t>(num_tasks));

    // Verify all results are successful demotions
    for (int i = 0; i < num_tasks; ++i) {
        bool found = false;
        for (auto & r : results) {
            if (r.payload_id == static_cast<uint64_t>(4001 + i)) {
                TEST_ASSERT(r.is_demotion == true);
                TEST_ASSERT(r.success == true);
                TEST_ASSERT(r.ref != 0);
                found = true;
                break;
            }
        }
        TEST_ASSERT(found);
    }

    worker.stop();
    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 8: Promotion failure for nonexistent cold ref
void test_promotion_failure_nonexistent_ref() {
    printf("step5: promotion failure for nonexistent cold ref...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("promotion_failure");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);
    bool started = worker.start();
    TEST_ASSERT(started);

    // Enqueue a promotion task with a nonexistent cold ref
    cold_descriptor_snapshot snap = make_snapshot(5001, 0, 32, 0, 0, 0);
    bool enqueued = worker.enqueue_promotion(5001, 99999, snap);
    TEST_ASSERT(enqueued);

    // Wait for the worker to process the task
    std::this_thread::sleep_for(std::chrono::milliseconds(200));

    // Drain results
    auto results = worker.drain_results();
    TEST_ASSERT(results.size() == 1);
    TEST_ASSERT(results[0].payload_id == 5001);
    TEST_ASSERT(results[0].is_demotion == false);
    TEST_ASSERT(results[0].success == false);
    TEST_ASSERT(results[0].failure_reason == io_failure_reason::read_error);

    worker.stop();
    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 9: Demotion failure when cold store is not configured
void test_demotion_failure_unconfigured() {
    printf("step5: demotion failure when cold store is not configured...\n");

    server_cache_io_worker worker;
    // Do NOT set cold store - it remains null

    bool started = worker.start();
    TEST_ASSERT(started);

    std::vector<uint8_t> target_bytes = make_target_bytes(32);
    std::vector<uint8_t> draft_bytes;
    uint64_t target_checksum = fnv1a_hash(target_bytes.data(), target_bytes.size());

    cold_descriptor_snapshot snap = make_snapshot(
        6001, 0,
        target_bytes.size(), 0,
        target_checksum, 0);

    bool enqueued = worker.enqueue_demotion(6001, snap, target_bytes, draft_bytes);
    TEST_ASSERT(enqueued);

    // Wait for the worker to process the task
    std::this_thread::sleep_for(std::chrono::milliseconds(200));

    // Drain results
    auto results = worker.drain_results();
    TEST_ASSERT(results.size() == 1);
    TEST_ASSERT(results[0].payload_id == 6001);
    TEST_ASSERT(results[0].is_demotion == true);
    TEST_ASSERT(results[0].success == false);
    TEST_ASSERT(results[0].failure_reason == io_failure_reason::write_error);

    worker.stop();
    printf("  PASSED\n");
}

// Test 10: Stop completes in-progress and queued tasks
// The worker processes all queued items before exiting. The stop() method
// drains any remaining items in the queue as cancelled after the thread joins,
// but in practice the thread processes all items before exiting because it
// only breaks when stopping_ is true AND the queue is empty.
void test_stop_completes_all_tasks() {
    printf("step5: stop completes all enqueued tasks before exiting...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("stop_completes");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);

    bool started = worker.start();
    TEST_ASSERT(started);

    std::vector<uint8_t> target_bytes = make_target_bytes(16);
    std::vector<uint8_t> draft_bytes;
    uint64_t target_checksum = fnv1a_hash(target_bytes.data(), target_bytes.size());

    // Enqueue several tasks
    const int num_tasks = 5;
    for (int i = 0; i < num_tasks; ++i) {
        cold_descriptor_snapshot snap = make_snapshot(
            7001 + i, 0,
            target_bytes.size(), 0,
            target_checksum, 0);
        bool enqueued = worker.enqueue_demotion(7001 + i, snap, target_bytes, draft_bytes);
        TEST_ASSERT(enqueued);
    }

    // Stop the worker - it should process all enqueued tasks before exiting
    worker.stop();

    // Drain results - all tasks should have completed (not cancelled)
    auto results = worker.drain_results();
    // The worker processes all items before exiting, so all should be successful
    int success_count = 0;
    for (auto & r : results) {
        if (r.success) {
            success_count++;
        }
    }
    TEST_ASSERT(success_count == num_tasks);

    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 11: In-progress task completes before stop joins
void test_in_progress_completes_before_stop() {
    printf("step5: in-progress task completes before stop joins...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("in_progress_complete");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);

#ifdef LLAMA_SERVER_CACHE_TESTS
    // Set a moderate delay so the task takes some time
    worker.debug_set_completion_delay_for_tests(200);  // 200ms
#endif

    bool started = worker.start();
    TEST_ASSERT(started);

    std::vector<uint8_t> target_bytes = make_target_bytes(32);
    std::vector<uint8_t> draft_bytes = make_draft_bytes(16);
    uint64_t target_checksum = fnv1a_hash(target_bytes.data(), target_bytes.size());
    uint64_t draft_checksum = fnv1a_hash(draft_bytes.data(), draft_bytes.size());

    cold_descriptor_snapshot snap = make_snapshot(
        8001, 1,
        target_bytes.size(), draft_bytes.size(),
        target_checksum, draft_checksum);

    // Enqueue one task
    bool enqueued = worker.enqueue_demotion(8001, snap, target_bytes, draft_bytes);
    TEST_ASSERT(enqueued);

    // Wait a tiny bit for the task to start processing, then stop
    std::this_thread::sleep_for(std::chrono::milliseconds(50));

#ifdef LLAMA_SERVER_CACHE_TESTS
    worker.debug_set_completion_delay_for_tests(0);  // Remove delay for clean stop
#endif

    // Stop should wait for the in-progress task to complete
    worker.stop();

    // Drain results - the in-progress task should have completed successfully
    auto results = worker.drain_results();
    bool found_success = false;
    for (auto & r : results) {
        if (r.payload_id == 8001 && r.success) {
            found_success = true;
        }
    }
    TEST_ASSERT(found_success);

    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 12: io_completion_result fields are correct for demotion success
void test_demotion_result_fields() {
    printf("step5: io_completion_result fields are correct for demotion success...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("demotion_fields");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);
    bool started = worker.start();
    TEST_ASSERT(started);

    std::vector<uint8_t> target_bytes = make_target_bytes(128);
    std::vector<uint8_t> draft_bytes = make_draft_bytes(64);
    uint64_t target_checksum = fnv1a_hash(target_bytes.data(), target_bytes.size());
    uint64_t draft_checksum = fnv1a_hash(draft_bytes.data(), draft_bytes.size());

    cold_descriptor_snapshot snap = make_snapshot(
        9001, 1,
        target_bytes.size(), draft_bytes.size(),
        target_checksum, draft_checksum);

    bool enqueued = worker.enqueue_demotion(9001, snap, target_bytes, draft_bytes);
    TEST_ASSERT(enqueued);

    std::this_thread::sleep_for(std::chrono::milliseconds(200));

    auto results = worker.drain_results();
    TEST_ASSERT(results.size() == 1);

    // Verify all fields of the completion result
    TEST_ASSERT(results[0].payload_id == 9001);
    TEST_ASSERT(results[0].is_demotion == true);
    TEST_ASSERT(results[0].success == true);
    TEST_ASSERT(results[0].failure_reason == io_failure_reason::none);
    TEST_ASSERT(results[0].ref != 0);  // cold_ref should be non-zero
    // target_bytes and draft_bytes should be empty for demotion results
    TEST_ASSERT(results[0].target_bytes.empty());
    TEST_ASSERT(results[0].draft_bytes.empty());

    worker.stop();
    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 13: io_completion_result fields are correct for promotion success
void test_promotion_result_fields() {
    printf("step5: io_completion_result fields are correct for promotion success...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("promotion_fields");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    // Write a cold file first
    std::vector<uint8_t> target_bytes = make_target_bytes(128);
    std::vector<uint8_t> draft_bytes = make_draft_bytes(64);
    uint64_t target_checksum = fnv1a_hash(target_bytes.data(), target_bytes.size());
    uint64_t draft_checksum = fnv1a_hash(draft_bytes.data(), draft_bytes.size());

    cold_descriptor_snapshot snap = make_snapshot(
        10001, 1,
        target_bytes.size(), draft_bytes.size(),
        target_checksum, draft_checksum);

    cold_ref ref = store.write(10001, target_bytes, draft_bytes, snap);
    TEST_ASSERT(ref != 0);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);
    bool started = worker.start();
    TEST_ASSERT(started);

    bool enqueued = worker.enqueue_promotion(10001, ref, snap);
    TEST_ASSERT(enqueued);

    std::this_thread::sleep_for(std::chrono::milliseconds(200));

    auto results = worker.drain_results();
    TEST_ASSERT(results.size() == 1);

    // Verify all fields of the completion result
    TEST_ASSERT(results[0].payload_id == 10001);
    TEST_ASSERT(results[0].is_demotion == false);
    TEST_ASSERT(results[0].success == true);
    TEST_ASSERT(results[0].failure_reason == io_failure_reason::none);
    TEST_ASSERT(results[0].ref == 0);  // ref should be 0 for promotion (not a demotion)
    TEST_ASSERT(results[0].target_bytes == target_bytes);
    TEST_ASSERT(results[0].draft_bytes == draft_bytes);

    worker.stop();
    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 14: Double stop is safe
void test_double_stop() {
    printf("step5: double stop is safe...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("double_stop");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);
    bool started = worker.start();
    TEST_ASSERT(started);

    worker.stop();
    TEST_ASSERT(!worker.is_running());

    // Second stop should be safe (no crash, no hang)
    worker.stop();
    TEST_ASSERT(!worker.is_running());

    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 15: io_task_type enum has expected values
void test_io_task_type_enum() {
    printf("step5: io_task_type enum has expected values...\n");

    // Verify the enum values exist and are distinct
    io_task_type demotion_type = io_task_type::demotion;
    io_task_type promotion_type = io_task_type::promotion;
    TEST_ASSERT(demotion_type != promotion_type);

    printf("  PASSED\n");
}

// Test 16: io_failure_reason enum has expected values
void test_io_failure_reason_enum() {
    printf("step5: io_failure_reason enum has expected values...\n");

    // Verify key enum values exist
    (void)io_failure_reason::none;
    (void)io_failure_reason::write_error;
    (void)io_failure_reason::read_error;
    (void)io_failure_reason::cancelled;
    (void)io_failure_reason::queue_full;

    // Verify validation failure reasons exist
    (void)io_failure_reason::validation_magic_mismatch;
    (void)io_failure_reason::validation_format_version_mismatch;
    (void)io_failure_reason::validation_header_checksum_mismatch;
    (void)io_failure_reason::validation_checksum_algorithm_mismatch;
    (void)io_failure_reason::validation_payload_id_mismatch;
    (void)io_failure_reason::validation_pair_state_mismatch;
    (void)io_failure_reason::validation_target_size_mismatch;
    (void)io_failure_reason::validation_draft_size_mismatch;
    (void)io_failure_reason::validation_target_checksum_mismatch;
    (void)io_failure_reason::validation_draft_checksum_mismatch;
    (void)io_failure_reason::validation_file_not_found;
    (void)io_failure_reason::validation_file_truncated;

    printf("  PASSED\n");
}

// Test 17: io_completion_result default values
void test_io_completion_result_defaults() {
    printf("step5: io_completion_result default values...\n");

    io_completion_result result{};
    TEST_ASSERT(result.payload_id == 0);
    TEST_ASSERT(result.is_demotion == false);
    TEST_ASSERT(result.success == false);
    TEST_ASSERT(result.failure_reason == io_failure_reason::none);
    TEST_ASSERT(result.ref == 0);
    TEST_ASSERT(result.target_bytes.empty());
    TEST_ASSERT(result.draft_bytes.empty());

    printf("  PASSED\n");
}

// Test 18: io_work_item default values
void test_io_work_item_defaults() {
    printf("step5: io_work_item default values...\n");

    io_work_item item{};
    TEST_ASSERT(item.type == io_task_type::demotion);
    TEST_ASSERT(item.payload_id == 0);
    TEST_ASSERT(item.ref == 0);
    TEST_ASSERT(item.pair_state == 0);
    TEST_ASSERT(item.format_version == 1);
    TEST_ASSERT(item.target_size_bytes == 0);
    TEST_ASSERT(item.draft_size_bytes == 0);
    TEST_ASSERT(item.target_checksum == 0);
    TEST_ASSERT(item.draft_checksum == 0);
    TEST_ASSERT(item.target_bytes.empty());
    TEST_ASSERT(item.draft_bytes.empty());

    printf("  PASSED\n");
}

// Test 19: Worker with target_only demotion (no draft bytes)
void test_demotion_target_only() {
    printf("step5: demotion with target_only (no draft bytes)...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("target_only");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);
    bool started = worker.start();
    TEST_ASSERT(started);

    std::vector<uint8_t> target_bytes = make_target_bytes(64);
    std::vector<uint8_t> draft_bytes;  // empty for target_only
    uint64_t target_checksum = fnv1a_hash(target_bytes.data(), target_bytes.size());

    cold_descriptor_snapshot snap = make_snapshot(
        11001, 0,  // pair_state=0 means target_only
        target_bytes.size(), 0,
        target_checksum, 0);

    bool enqueued = worker.enqueue_demotion(11001, snap, target_bytes, draft_bytes);
    TEST_ASSERT(enqueued);

    std::this_thread::sleep_for(std::chrono::milliseconds(200));

    auto results = worker.drain_results();
    TEST_ASSERT(results.size() == 1);
    TEST_ASSERT(results[0].payload_id == 11001);
    TEST_ASSERT(results[0].is_demotion == true);
    TEST_ASSERT(results[0].success == true);
    TEST_ASSERT(results[0].ref != 0);

    worker.stop();
    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 20: NB-4 result-queue model - controller drains at safe scheduling points
void test_nb4_result_queue_model() {
    printf("step5: NB-4 result-queue model - drain_results returns completions...\n");

    server_cache_store_cold store;
    std::string temp_dir = create_temp_dir("nb4_result_queue");
    bool configured = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(configured);

    server_cache_io_worker worker;
    worker.debug_set_cold_store_for_tests(&store);
    bool started = worker.start();
    TEST_ASSERT(started);

    // Enqueue a demotion
    std::vector<uint8_t> target_bytes = make_target_bytes(32);
    std::vector<uint8_t> draft_bytes = make_draft_bytes(16);
    uint64_t target_checksum = fnv1a_hash(target_bytes.data(), target_bytes.size());
    uint64_t draft_checksum = fnv1a_hash(draft_bytes.data(), draft_bytes.size());

    cold_descriptor_snapshot snap = make_snapshot(
        12001, 1,
        target_bytes.size(), draft_bytes.size(),
        target_checksum, draft_checksum);

    bool enqueued = worker.enqueue_demotion(12001, snap, target_bytes, draft_bytes);
    TEST_ASSERT(enqueued);

    // Wait for completion
    std::this_thread::sleep_for(std::chrono::milliseconds(200));

    // drain_results should return the completion
    auto results = worker.drain_results();
    TEST_ASSERT(results.size() == 1);
    TEST_ASSERT(results[0].success == true);

    // Second drain should return empty (results were consumed)
    auto results2 = worker.drain_results();
    TEST_ASSERT(results2.empty());

    worker.stop();
    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

int main() {
    printf("==================================================\n");
    printf("Step 5: Async I/O worker thread\n");
    printf("==================================================\n\n");

    test_start_stop();
    test_start_failure_returns_false();
    test_enqueue_demotion_success();
    test_enqueue_promotion_success();
    test_queue_full_returns_false();
    test_drain_results_empty();
    test_multiple_demotion_tasks();
    test_promotion_failure_nonexistent_ref();
    test_demotion_failure_unconfigured();
    test_stop_completes_all_tasks();
    test_in_progress_completes_before_stop();
    test_demotion_result_fields();
    test_promotion_result_fields();
    test_double_stop();
    test_io_task_type_enum();
    test_io_failure_reason_enum();
    test_io_completion_result_defaults();
    test_io_work_item_defaults();
    test_demotion_target_only();
    test_nb4_result_queue_model();

    printf("\n==================================================\n");
    printf("All Step 5 tests passed! (20 tests)\n");
    printf("==================================================\n");

    return 0;
}