#include "server-cache-io-worker.h"
#include "server-common.h"

#include <cinttypes>

// Stage 28 R28-BUG-04 Phase C: the async worker thread, work queue,
// result queue, enqueue/queue-full scheduling, and worker_thread_func
// have been removed. Demotion and promotion now execute synchronously
// on the calling thread via execute_inline / execute_demotion_inline /
// execute_promotion_inline. The caller (hybrid_cache_controller's
// tx_demote_payload / tx_promote_payload) holds cache_state_mutex_ so
// the descriptor residency transition is observed as a single atomic
// step by other threads.

std::optional<io_completion_result> server_cache_io_worker::execute_inline(const io_work_item & item) {
    if (!cold_store_ || !cold_store_->is_configured()) {
        return std::nullopt;
    }
    io_work_item local_item = item;
    io_completion_result result;
    if (local_item.type == io_task_type::demotion) {
        result = process_demotion(local_item);
    } else {
        result = process_promotion(local_item);
    }
    return result;
}

std::optional<io_completion_result> server_cache_io_worker::execute_demotion_inline(
        uint64_t payload_id,
        const cold_descriptor_snapshot & descriptor_snapshot,
        const std::vector<uint8_t> & target_bytes,
        const std::vector<uint8_t> & draft_bytes) {
    io_work_item item{};
    item.type = io_task_type::demotion;
    item.payload_id = payload_id;
    item.pair_state = descriptor_snapshot.pair_state;
    item.format_version = descriptor_snapshot.format_version;
    item.target_size_bytes = descriptor_snapshot.target_size_bytes;
    item.draft_size_bytes = descriptor_snapshot.draft_size_bytes;
    item.target_checksum = descriptor_snapshot.target_checksum;
    item.draft_checksum = descriptor_snapshot.draft_checksum;
    item.target_bytes = target_bytes;
    item.draft_bytes = draft_bytes;
    return execute_inline(item);
}

std::optional<io_completion_result> server_cache_io_worker::execute_promotion_inline(
        uint64_t payload_id,
        cold_ref ref,
        const cold_descriptor_snapshot & descriptor_snapshot) {
    io_work_item item{};
    item.type = io_task_type::promotion;
    item.payload_id = payload_id;
    item.ref = ref;
    item.pair_state = descriptor_snapshot.pair_state;
    item.format_version = descriptor_snapshot.format_version;
    item.target_size_bytes = descriptor_snapshot.target_size_bytes;
    item.draft_size_bytes = descriptor_snapshot.draft_size_bytes;
    item.target_checksum = descriptor_snapshot.target_checksum;
    item.draft_checksum = descriptor_snapshot.draft_checksum;
    return execute_inline(item);
}

io_completion_result server_cache_io_worker::process_demotion(io_work_item & item) {
    io_completion_result result{};
    result.payload_id = item.payload_id;
    result.is_demotion = true;

    if (!cold_store_ || !cold_store_->is_configured()) {
        result.success = false;
        result.failure_reason = io_failure_reason::write_error;
        SRV_ERR(" - cold store I/O worker: demotion failed: cold store not configured for payload_id %" PRIu64 "\n",
                item.payload_id);
        return result;
    }

    cold_descriptor_snapshot snapshot{};
    snapshot.payload_id = item.payload_id;
    snapshot.pair_state = item.pair_state;
    snapshot.format_version = item.format_version;
    snapshot.target_size_bytes = item.target_size_bytes;
    snapshot.draft_size_bytes = item.draft_size_bytes;
    snapshot.target_checksum = item.target_checksum;
    snapshot.draft_checksum = item.draft_checksum;

    cold_ref ref = cold_store_->write(
        item.payload_id,
        item.target_bytes,
        item.draft_bytes,
        snapshot);

    if (ref == 0) {
        result.success = false;
        result.failure_reason = io_failure_reason::write_error;
        SRV_ERR(" - cold store I/O worker: demotion write failed for payload_id %" PRIu64 "\n",
                item.payload_id);
        return result;
    }

    result.success = true;
    result.ref = ref;
    SRV_DBG(" - cold store I/O worker: demotion completed for payload_id %" PRIu64 " (ref %" PRIu64 ")\n",
            item.payload_id, ref);
    return result;
}

io_completion_result server_cache_io_worker::process_promotion(io_work_item & item) {
    io_completion_result result{};
    result.payload_id = item.payload_id;
    result.is_demotion = false;

    if (!cold_store_ || !cold_store_->is_configured()) {
        result.success = false;
        result.failure_reason = io_failure_reason::read_error;
        SRV_ERR(" - cold store I/O worker: promotion failed: cold store not configured for payload_id %" PRIu64 "\n",
                item.payload_id);
        return result;
    }

    std::vector<uint8_t> target_bytes;
    std::vector<uint8_t> draft_bytes;
    cold_descriptor_snapshot descriptor_out;

    bool read_ok = cold_store_->read(
        item.ref,
        target_bytes,
        draft_bytes,
        descriptor_out);

    if (!read_ok) {
        result.success = false;
        result.failure_reason = io_failure_reason::read_error;
        SRV_ERR(" - cold store I/O worker: promotion read failed for payload_id %" PRIu64 " (ref %" PRIu64 ")\n",
                item.payload_id, item.ref);
        return result;
    }

    result.success = true;
    result.target_bytes = std::move(target_bytes);
    result.draft_bytes = std::move(draft_bytes);
    SRV_DBG(" - cold store I/O worker: promotion completed for payload_id %" PRIu64 " (ref %" PRIu64 ")\n",
            item.payload_id, item.ref);
    return result;
}