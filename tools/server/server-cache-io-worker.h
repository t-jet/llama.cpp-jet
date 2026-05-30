#pragma once

#include "server-cache-store-cold.h"

#include <atomic>
#include <condition_variable>
#include <cstdint>
#include <mutex>
#include <queue>
#include <thread>
#include <vector>

// Async I/O worker for cold store operations.
// Runs as a single background thread that executes demotion writes and promotion reads.
// The controller enqueues tasks and receives completion results through a result queue.
// The server_context thread must never block on cold I/O or on a full work queue.

enum class io_task_type {
    demotion,
    promotion,
};

// Work item for the I/O worker queue
struct io_work_item {
    io_task_type type = io_task_type::demotion;
    uint64_t payload_id = 0;
    cold_ref ref = 0;  // cold_ref for promotion tasks

    // For demotion: snapshot of the descriptor fields and payload bytes
    // We store copies since the controller must not hold locks during I/O
    uint8_t pair_state = 0;
    uint8_t format_version = 1;
    uint64_t target_size_bytes = 0;
    uint64_t draft_size_bytes = 0;
    uint64_t target_checksum = 0;
    uint64_t draft_checksum = 0;
    std::vector<uint8_t> target_bytes;
    std::vector<uint8_t> draft_bytes;
};

class server_cache_io_worker {
public:
    server_cache_io_worker() = default;
    ~server_cache_io_worker();

    // Non-copyable, non-movable
    server_cache_io_worker(const server_cache_io_worker &) = delete;
    server_cache_io_worker & operator=(const server_cache_io_worker &) = delete;

    // Start the worker thread and the work queue.
    // Returns true on success, false on thread creation failure.
    // Must be called after the cold store is configured.
    bool start();

    // Drain pending work, signal the thread to exit, and join.
    // In-progress tasks are completed before exit.
    // Queued but not started tasks receive a cancelled failure result.
    void stop();

    // Enqueue a demotion task.
    // Returns true on success, false if the queue is full (NB-2: fail-fast, no blocking).
    // The controller must set residency_state = demoting before calling this.
    // On queue-full, the controller must immediately revert residency_state = hot.
    bool enqueue_demotion(uint64_t payload_id,
                          const cold_descriptor_snapshot & descriptor_snapshot,
                          const std::vector<uint8_t> & target_bytes,
                          const std::vector<uint8_t> & draft_bytes);

    // Enqueue a promotion task.
    // Returns true on success, false if the queue is full (NB-2: fail-fast, no blocking).
    // The controller must set residency_state = promoting before calling this.
    // On queue-full, the controller must immediately revert residency_state = cold.
    bool enqueue_promotion(uint64_t payload_id,
                           cold_ref ref,
                           const cold_descriptor_snapshot & descriptor_snapshot);

    // Drain the result queue and return all pending completion results.
    // Called by the controller at safe scheduling points (before update() or restore).
    std::vector<io_completion_result> drain_results();

    // Check if the worker is running
    bool is_running() const { return running_.load(); }

#ifdef LLAMA_SERVER_CACHE_TESTS
    // Test hooks
    void debug_set_queue_capacity_for_tests(size_t capacity) { debug_queue_capacity_ = capacity; }
    void debug_set_completion_delay_for_tests(int delay_ms) { debug_completion_delay_ms_ = delay_ms; }
    void debug_set_cold_store_for_tests(server_cache_store_cold * store) { cold_store_ = store; }
#endif

private:
    // Default queue capacity
    static constexpr size_t DEFAULT_QUEUE_CAPACITY = 32;

    // Worker thread function
    void worker_thread_func();

    // Process a single work item
    io_completion_result process_demotion(io_work_item & item);
    io_completion_result process_promotion(io_work_item & item);

    std::thread worker_thread_;
    std::atomic<bool> running_{false};
    std::atomic<bool> stopping_{false};

    // Work queue
    std::mutex queue_mutex_;
    std::condition_variable queue_cv_;
    std::queue<io_work_item> work_queue_;
    size_t queue_capacity_ = DEFAULT_QUEUE_CAPACITY;

    // Result queue
    std::mutex result_mutex_;
    std::vector<io_completion_result> result_queue_;

    // Cold store reference (set during start)
    server_cache_store_cold * cold_store_ = nullptr;

    void set_cold_store(server_cache_store_cold * store) { cold_store_ = store; }

#ifdef LLAMA_SERVER_CACHE_TESTS
    size_t debug_queue_capacity_ = 0;  // 0 means use default
    int debug_completion_delay_ms_ = 0;
#endif

    // Allow hybrid_cache_controller to set the cold store
    friend class hybrid_cache_controller;
};