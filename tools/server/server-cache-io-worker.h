#pragma once

#include "server-cache-store-cold.h"

#include <atomic>
#include <cstdint>
#include <optional>
#include <vector>

// Cold store I/O worker.
//
// Stage 28 R28-BUG-04 Phase C: the async worker body (background thread,
// work queue, result queue, enqueue/queue-full scheduling) has been
// removed. Demotion and promotion now execute synchronously on the
// calling thread via execute_inline / execute_demotion_inline /
// execute_promotion_inline. These inline paths are the production
// entry points and are called from hybrid_cache_controller::tx_demote_payload
// and tx_promote_payload under cache_state_mutex_ so the residency
// transition is observed as a single atomic step by other threads.
//
// The class is retained as a thin container for the inline execution
// helpers and the cold-store pointer so callers can keep their existing
// per-controller wiring (debug_io_worker_for_tests() accessor, etc.)
// without churning the controller's storage layout.

enum class io_task_type {
    demotion,
    promotion,
};

// Work item for synchronous inline execution. Same fields as the prior
// async queue item; the controller populates a local copy and calls
// execute_inline().
struct io_work_item {
    io_task_type type = io_task_type::demotion;
    uint64_t payload_id = 0;
    cold_ref ref = 0;

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
    ~server_cache_io_worker() = default;

    // Non-copyable, non-movable
    server_cache_io_worker(const server_cache_io_worker &) = delete;
    server_cache_io_worker & operator=(const server_cache_io_worker &) = delete;

    // Synchronous inline execution. Runs the cold-store read or write on
    // the calling thread and returns the completion result. The caller
    // (tx_demote_payload / tx_promote_payload) holds cache_state_mutex_,
    // so the descriptor residency transition is observed as a single
    // atomic step. Returns std::nullopt when no cold store is wired.
    std::optional<io_completion_result> execute_inline(const io_work_item & item);

    // Convenience wrappers used by tx_demote_payload and tx_promote_payload.
    std::optional<io_completion_result> execute_demotion_inline(
        uint64_t payload_id,
        const cold_descriptor_snapshot & descriptor_snapshot,
        const std::vector<uint8_t> & target_bytes,
        const std::vector<uint8_t> & draft_bytes);
    std::optional<io_completion_result> execute_promotion_inline(
        uint64_t payload_id,
        cold_ref ref,
        const cold_descriptor_snapshot & descriptor_snapshot);

#ifdef LLAMA_SERVER_CACHE_TESTS
    // Test hook: wire the cold store pointer directly. Used by cold-store
    // constructor wiring in tests that construct the controller with a
    // cold-path string.
    void debug_set_cold_store_for_tests(server_cache_store_cold * store) { cold_store_ = store; }
#endif

private:
    io_completion_result process_demotion(io_work_item & item);
    io_completion_result process_promotion(io_work_item & item);

    // Cold store reference; set via debug_set_cold_store_for_tests or
    // by the hybrid_cache_controller friend declaration below.
    server_cache_store_cold * cold_store_ = nullptr;

    void set_cold_store(server_cache_store_cold * store) { cold_store_ = store; }

    // Allow hybrid_cache_controller to set the cold store.
    friend class hybrid_cache_controller;
};