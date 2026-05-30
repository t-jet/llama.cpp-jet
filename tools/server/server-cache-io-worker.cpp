#include "server-cache-io-worker.h"
#include "server-common.h"

#include <chrono>
#include <cinttypes>

server_cache_io_worker::~server_cache_io_worker() {
    stop();
}

bool server_cache_io_worker::start() {
    if (running_.load()) {
        return true;  // Already running
    }

    stopping_.store(false);
    running_.store(true);

    try {
        worker_thread_ = std::thread(&server_cache_io_worker::worker_thread_func, this);
    } catch (const std::system_error & e) {
        SRV_ERR(" - cold store I/O worker: failed to start worker thread: %s\n", e.what());
        running_.store(false);
        return false;
    }

    SRV_INF(" - cold store I/O worker: started\n%s", "");
    return true;
}

void server_cache_io_worker::stop() {
    if (!running_.load()) {
        return;
    }

    stopping_.store(true);
    queue_cv_.notify_all();

    if (worker_thread_.joinable()) {
        worker_thread_.join();
    }

    running_.store(false);

    // Drain remaining work items as cancelled
    {
        std::lock_guard<std::mutex> lock(queue_mutex_);
        while (!work_queue_.empty()) {
            io_work_item item = std::move(work_queue_.front());
            work_queue_.pop();

            io_completion_result result{};
            result.payload_id = item.payload_id;
            result.is_demotion = (item.type == io_task_type::demotion);
            result.success = false;
            result.failure_reason = io_failure_reason::cancelled;

            {
                std::lock_guard<std::mutex> rlock(result_mutex_);
                result_queue_.push_back(std::move(result));
            }
        }
    }

    SRV_INF(" - cold store I/O worker: stopped\n%s", "");
}

bool server_cache_io_worker::enqueue_demotion(uint64_t payload_id,
                                                const cold_descriptor_snapshot & descriptor_snapshot,
                                                const std::vector<uint8_t> & target_bytes,
                                                const std::vector<uint8_t> & draft_bytes) {
    size_t capacity = queue_capacity_;
#ifdef LLAMA_SERVER_CACHE_TESTS
    if (debug_queue_capacity_ > 0) {
        capacity = debug_queue_capacity_;
    }
#endif

    std::lock_guard<std::mutex> lock(queue_mutex_);
    if (work_queue_.size() >= capacity) {
        SRV_WRN(" - cold store I/O worker: demotion queue full (%zu/%zu) for payload_id %" PRIu64 "\n",
                work_queue_.size(), capacity, payload_id);
        return false;
    }

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

    work_queue_.push(std::move(item));
    queue_cv_.notify_one();

    return true;
}

bool server_cache_io_worker::enqueue_promotion(uint64_t payload_id,
                                                 cold_ref ref,
                                                 const cold_descriptor_snapshot & descriptor_snapshot) {
    size_t capacity = queue_capacity_;
#ifdef LLAMA_SERVER_CACHE_TESTS
    if (debug_queue_capacity_ > 0) {
        capacity = debug_queue_capacity_;
    }
#endif

    std::lock_guard<std::mutex> lock(queue_mutex_);
    if (work_queue_.size() >= capacity) {
        SRV_WRN(" - cold store I/O worker: promotion queue full (%zu/%zu) for payload_id %" PRIu64 "\n",
                work_queue_.size(), capacity, payload_id);
        return false;
    }

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

    work_queue_.push(std::move(item));
    queue_cv_.notify_one();

    return true;
}

std::vector<io_completion_result> server_cache_io_worker::drain_results() {
    std::lock_guard<std::mutex> lock(result_mutex_);
    std::vector<io_completion_result> results;
    results.swap(result_queue_);
    return results;
}

void server_cache_io_worker::worker_thread_func() {
    while (true) {
        io_work_item item;

        {
            std::unique_lock<std::mutex> lock(queue_mutex_);
            queue_cv_.wait(lock, [this] { return !work_queue_.empty() || stopping_.load(); });

            if (stopping_.load() && work_queue_.empty()) {
                break;
            }

            if (work_queue_.empty()) {
                continue;
            }

            item = std::move(work_queue_.front());
            work_queue_.pop();
        }

#ifdef LLAMA_SERVER_CACHE_TESTS
        if (debug_completion_delay_ms_ > 0) {
            std::this_thread::sleep_for(std::chrono::milliseconds(debug_completion_delay_ms_));
        }
#endif

        io_completion_result result;
        if (item.type == io_task_type::demotion) {
            result = process_demotion(item);
        } else {
            result = process_promotion(item);
        }

        {
            std::lock_guard<std::mutex> lock(result_mutex_);
            result_queue_.push_back(std::move(result));
        }
    }
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