#pragma once

#include <cstdint>
#include <string>
#include <unordered_set>
#include <vector>

// Cold payload store: manages versioned filesystem files for demoted payloads.
// Disabled unless a root path is configured via configure().
//
// NB-3 resolution: The cold_ref_for(payload_id) operation was removed from this
// interface. The controller always holds the cold ref in store_ref.id for any
// cold descriptor, so a separate lookup is not needed within Stage 6 scope.
// If a future stage requires a scan-based lookup, it can be added then.

// Cold store header format constants
constexpr uint32_t COLD_STORE_MAGIC = 0x4C434343; // "LCCC" - Llama Cold Cache Chunk
constexpr uint8_t COLD_STORE_FORMAT_VERSION_1 = 1;
constexpr uint8_t COLD_STORE_CHECKSUM_ALGORITHM_FNV1A = 1;

// Opaque handle for cold file references. The controller stores a cold_ref
// in store_ref.id when the descriptor moves to cold state.
using cold_ref = uint64_t;

// Cold store header: self-describing header stored at the beginning of each cold file.
// All multi-byte fields are stored in little-endian byte order.
struct cold_store_header {
    uint32_t magic = COLD_STORE_MAGIC;              // bytes 0-3: fixed marker
    uint8_t  format_version = COLD_STORE_FORMAT_VERSION_1; // byte 4: schema version
    uint8_t  checksum_algorithm = COLD_STORE_CHECKSUM_ALGORITHM_FNV1A; // byte 5: checksum algorithm ID
    uint8_t  _reserved[2] = {0, 0};                  // bytes 6-7: reserved for alignment
    uint64_t payload_id = 0;                         // bytes 8-15: stable payload ID
    uint8_t  pair_state = 0;                         // byte 16: target_only or target_and_draft
    uint8_t  _reserved2[7] = {0, 0, 0, 0, 0, 0, 0}; // bytes 17-23: reserved
    uint64_t target_size_bytes = 0;                  // bytes 24-31: target payload length
    uint64_t draft_size_bytes = 0;                   // bytes 32-39: draft payload length (0 for target_only)
    uint64_t target_checksum = 0;                    // bytes 40-47: FNV-1a checksum of target bytes
    uint64_t draft_checksum = 0;                     // bytes 48-55: FNV-1a checksum of draft bytes (0 for target_only)
    uint64_t header_checksum = 0;                    // bytes 56-63: FNV-1a checksum of all preceding header bytes
};

static_assert(sizeof(cold_store_header) == 64, "cold_store_header must be exactly 64 bytes");

// Result of a cold store operation
enum class cold_store_result {
    success,
    failure_not_configured,
    failure_write_error,
    failure_read_error,
    failure_validation_error,
    failure_not_found,
    failure_path_traversal,
    failure_rename_error,
    failure_disk_full,
};

// Failure reasons for I/O worker completion callbacks
enum class io_failure_reason {
    none,
    write_error,
    read_error,
    validation_magic_mismatch,
    validation_format_version_mismatch,
    validation_header_checksum_mismatch,
    validation_checksum_algorithm_mismatch,
    validation_payload_id_mismatch,
    validation_pair_state_mismatch,
    validation_target_size_mismatch,
    validation_draft_size_mismatch,
    validation_target_checksum_mismatch,
    validation_draft_checksum_mismatch,
    validation_file_not_found,
    validation_file_truncated,
    queue_full,
    cancelled,
};

// Completion result posted by the I/O worker
struct io_completion_result {
    uint64_t payload_id = 0;
    bool is_demotion = false;       // true for demotion, false for promotion
    bool success = false;
    io_failure_reason failure_reason = io_failure_reason::none;
    cold_ref ref = 0;               // cold_ref on demotion success
    std::vector<uint8_t> target_bytes; // promoted target bytes on promotion success
    std::vector<uint8_t> draft_bytes;  // promoted draft bytes on promotion success
};

// Descriptor snapshot for cold store operations.
// This is a simplified version of payload_descriptor that contains only the fields
// needed for cold file serialization, avoiding a dependency on the full descriptor type.
struct cold_descriptor_snapshot {
    uint64_t payload_id = 0;
    uint8_t  pair_state = 0;  // payload_pair_state value
    uint8_t  format_version = 1;
    uint64_t target_size_bytes = 0;
    uint64_t draft_size_bytes = 0;
    uint64_t target_checksum = 0;
    uint64_t draft_checksum = 0;
};

class server_cache_store_cold {
public:
    server_cache_store_cold() = default;
    ~server_cache_store_cold() = default;

    // Non-copyable, non-movable
    server_cache_store_cold(const server_cache_store_cold &) = delete;
    server_cache_store_cold & operator=(const server_cache_store_cold &) = delete;

    // Validate and open the cold store root directory.
    // Returns true on success, false on failure.
    // On failure, the cold store remains unconfigured and is_configured() returns false.
    // root_path must be a non-empty path to an existing writable directory.
    // format_version is the cold file format version to use for writes.
    bool configure(const std::string & root_path, uint8_t format_version);

    // Write a cold file for the given payload.
    // Returns a cold_ref on success, or 0 on failure.
    // The write uses atomic write-and-rename: a staging file is written first,
    // then renamed to the final path. No partial file is visible at the final path.
    cold_ref write(uint64_t payload_id,
                   const std::vector<uint8_t> & target_bytes,
                   const std::vector<uint8_t> & draft_bytes,
                   const cold_descriptor_snapshot & descriptor_snapshot);

    // Read and validate a cold file.
    // Returns true on success and populates target_bytes, draft_bytes, and descriptor_out.
    // Returns false on any validation failure.
    // Validation checks are performed in the order specified in design Part 3:
    // magic, format_version, header_checksum, checksum_algorithm, payload_id,
    // pair_state, target_size_bytes, draft_size_bytes, target_checksum, draft_checksum.
    bool read(cold_ref ref,
              std::vector<uint8_t> & target_bytes,
              std::vector<uint8_t> & draft_bytes,
              cold_descriptor_snapshot & descriptor_out);

    // Remove a cold file. Called when the owning descriptor is deleted or evicted.
    // Returns true if the file was removed or did not exist.
    bool remove(cold_ref ref);

    // Stage 8: Batch delete cold files by ID set.
    // Deletes all cold files whose ref IDs are in the given set.
    // Returns the number of files successfully deleted.
    // IDs that do not exist are silently skipped.
    size_t delete_ids(const std::unordered_set<uint64_t> & ids);

    // Return true only when a valid root path is set and configure() succeeded.
    bool is_configured() const { return configured_; }

#ifdef LLAMA_SERVER_CACHE_TESTS
    // Test hooks for fault injection
    void debug_set_write_failure_for_tests(bool fail) { debug_write_failure_ = fail; }
    void debug_set_read_failure_for_tests(bool fail) { debug_read_failure_ = fail; }
    void debug_set_validation_failure_for_tests(io_failure_reason reason) { debug_validation_failure_ = reason; }
#endif

private:
    // Derive the final file path from a payload_id
    std::string final_path(uint64_t payload_id) const;

    // Derive the staging file path from a payload_id
    std::string staging_path(uint64_t payload_id) const;

    // Derive the file path from a cold_ref (which is the payload_id)
    std::string ref_to_path(cold_ref ref) const;

    // Validate that a path does not contain traversal sequences
    bool validate_path(const std::string & path) const;

    // Compute FNV-1a checksum (same algorithm as hybrid controller)
    static uint64_t fnv1a_checksum(const uint8_t * data, size_t len);
    static uint64_t fnv1a_checksum(const std::vector<uint8_t> & bytes);

    // Serialize header to byte buffer
    static std::vector<uint8_t> serialize_header(const cold_store_header & header);

    // Deserialize header from byte buffer
    static bool deserialize_header(const uint8_t * data, size_t len, cold_store_header & header);

    // Compute header checksum over all fields except the header_checksum field itself
    static uint64_t compute_header_checksum(const cold_store_header & header);

    std::string root_path_;
    uint8_t format_version_ = COLD_STORE_FORMAT_VERSION_1;
    bool configured_ = false;
    uint64_t next_ref_ = 1;  // Next cold_ref to assign

#ifdef LLAMA_SERVER_CACHE_TESTS
    bool debug_write_failure_ = false;
    bool debug_read_failure_ = false;
    io_failure_reason debug_validation_failure_ = io_failure_reason::none;
#endif
};