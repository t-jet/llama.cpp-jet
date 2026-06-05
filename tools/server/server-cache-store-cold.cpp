#include "server-cache-store-cold.h"
#include "server-common.h"

#include <algorithm>
#include <cinttypes>
#include <cstdio>
#include <cstring>
#include <cctype>
#include <filesystem>
#include <fstream>
#include <sstream>

namespace fs = std::filesystem;

bool server_cache_store_cold::configure(const std::string & root_path, uint8_t format_version) {
    if (root_path.empty()) {
        SRV_ERR(" - cold store: configure failed: root path is empty\n%s", "");
        return false;
    }

    std::error_code ec;
    fs::path normalized = fs::weakly_canonical(fs::absolute(fs::path(root_path), ec), ec);
    if (ec) {
        SRV_ERR(" - cold store: configure failed: cannot normalize root path: %s\n",
                ec.message().c_str());
        return false;
    }

    if (!fs::exists(normalized)) {
        SRV_ERR("%s", " - cold store: configure failed: root path does not exist\n");
        return false;
    }

    if (!fs::is_directory(normalized)) {
        SRV_ERR("%s", " - cold store: configure failed: root path is not a directory\n");
        return false;
    }

    if (!normalized.is_absolute() || normalized == normalized.root_path()) {
        SRV_ERR("%s", " - cold store: configure failed: root path is not an allowed cache directory\n");
        return false;
    }

    const std::string normalized_string = normalized.string();
    if (normalized_string.find('\n') != std::string::npos ||
        normalized_string.find('\r') != std::string::npos ||
        normalized_string.find('\0') != std::string::npos) {
        SRV_ERR("%s", " - cold store: configure failed: root path contains an unsafe control character\n");
        return false;
    }

    fs::path test_file = normalized / ".cold_store_write_test";
    {
        std::ofstream ofs(test_file.string());
        if (!ofs.is_open()) {
            SRV_ERR("%s", " - cold store: configure failed: root directory is not writable\n");
            return false;
        }
        ofs << "test";
        ofs.close();
    }
    fs::remove(test_file, ec);

    // Check for world-writable (security warning only, not a blocker)
    // On POSIX, check if the directory has world-write permission
    // On Windows, this check is less meaningful; skip it
#ifndef _WIN32
    try {
        auto perms = fs::status(normalized).permissions();
        if ((perms & fs::perms::others_write) != fs::perms::none) {
            SRV_WRN("%s", " - cold store: root directory is world-writable; consider restricting permissions\n");
        }
    } catch (...) {
    }
#endif

    root_path_ = normalized_string;
    format_version_ = format_version;
    configured_ = true;

    SRV_INF(" - cold store: configured root '%s', format version %d\n",
            diagnostic_root().c_str(), static_cast<int>(format_version_));

    return true;
}

cold_ref server_cache_store_cold::write(uint64_t payload_id,
                                          const std::vector<uint8_t> & target_bytes,
                                          const std::vector<uint8_t> & draft_bytes,
                                          const cold_descriptor_snapshot & descriptor_snapshot) {
    if (!configured_) {
        return 0;
    }

#ifdef LLAMA_SERVER_CACHE_TESTS
    if (debug_write_failure_) {
        return 0;
    }
#endif

    // Build the cold store header
    cold_store_header header{};
    header.magic = COLD_STORE_MAGIC;
    header.format_version = format_version_;
    header.checksum_algorithm = COLD_STORE_CHECKSUM_ALGORITHM_FNV1A;
    header.payload_id = payload_id;
    header.pair_state = static_cast<uint8_t>(descriptor_snapshot.pair_state);
    header.target_size_bytes = target_bytes.size();
    header.draft_size_bytes = draft_bytes.size();
    header.target_checksum = fnv1a_checksum(target_bytes);
    header.draft_checksum = draft_bytes.empty() ? 0 : fnv1a_checksum(draft_bytes);

    // Compute header checksum over all fields except header_checksum itself
    header.header_checksum = compute_header_checksum(header);

    std::string staging = staging_path(payload_id);
    std::string final = final_path(payload_id);

    if (!validate_path(staging) || !validate_path(final)) {
        SRV_ERR(" - cold store: write failed: payload path escaped root (payload_id=%" PRIu64 ")\n", payload_id);
        return 0;
    }

    std::ofstream ofs(staging, std::ios::binary | std::ios::trunc);
    if (!ofs.is_open()) {
        SRV_ERR(" - cold store: write failed: cannot create staging file (payload_id=%" PRIu64 ")\n",
                payload_id);
        return 0;
    }

    // Serialize and write header
    auto header_bytes = serialize_header(header);
    ofs.write(reinterpret_cast<const char *>(header_bytes.data()), header_bytes.size());
    if (!ofs.good()) {
        SRV_ERR(" - cold store: write failed: cannot write header for payload_id %" PRIu64 "\n", payload_id);
        ofs.close();
        std::error_code ec;
        fs::remove(staging, ec);
        return 0;
    }

    // Write target bytes
    if (!target_bytes.empty()) {
        ofs.write(reinterpret_cast<const char *>(target_bytes.data()), target_bytes.size());
        if (!ofs.good()) {
            SRV_ERR(" - cold store: write failed: cannot write target bytes for payload_id %" PRIu64 "\n", payload_id);
            ofs.close();
            std::error_code ec;
            fs::remove(staging, ec);
            return 0;
        }
    }

    // Write draft bytes
    if (!draft_bytes.empty()) {
        ofs.write(reinterpret_cast<const char *>(draft_bytes.data()), draft_bytes.size());
        if (!ofs.good()) {
            SRV_ERR(" - cold store: write failed: cannot write draft bytes for payload_id %" PRIu64 "\n", payload_id);
            ofs.close();
            std::error_code ec;
            fs::remove(staging, ec);
            return 0;
        }
    }

    ofs.close();

    // Atomic rename from staging to final path
    std::error_code ec;
    fs::rename(staging, final, ec);
    if (ec) {
        SRV_ERR(" - cold store: write failed: cannot rename staging file (payload_id=%" PRIu64 "): %s\n",
                payload_id, ec.message().c_str());
        fs::remove(staging, ec);
        return 0;
    }

    // Assign cold_ref (use payload_id as the ref for simplicity)
    cold_ref ref = next_ref_++;
    // For now, we use payload_id as the ref key since the file path is derived from it
    // The internal registry maps ref -> file path, but since path = f(payload_id),
    // we can use payload_id directly
    ref = payload_id;

    SRV_DBG(" - cold store: wrote cold file for payload_id %" PRIu64 " (ref %" PRIu64 ", %zu + %zu bytes)\n",
            payload_id, ref, target_bytes.size(), draft_bytes.size());

    return ref;
}

bool server_cache_store_cold::read(cold_ref ref,
                                     std::vector<uint8_t> & target_bytes,
                                     std::vector<uint8_t> & draft_bytes,
                                     cold_descriptor_snapshot & descriptor_out) {
    if (!configured_) {
        return false;
    }

#ifdef LLAMA_SERVER_CACHE_TESTS
    if (debug_read_failure_) {
        return false;
    }
#endif

    std::string path = ref_to_path(ref);
    if (!validate_path(path)) {
        SRV_ERR(" - cold store: read failed: payload path escaped root (ref=%" PRIu64 ")\n", ref);
        return false;
    }

    std::ifstream ifs(path, std::ios::binary | std::ios::ate);
    if (!ifs.is_open()) {
        SRV_ERR(" - cold store: read failed: cannot open cold file (ref=%" PRIu64 ")\n", ref);
        return false;
    }

    std::streamsize file_size = ifs.tellg();
    if (file_size < static_cast<std::streamsize>(sizeof(cold_store_header))) {
        SRV_ERR(" - cold store: read failed: file too small (%lld bytes) for ref %" PRIu64 "\n",
                static_cast<long long>(file_size), ref);
        return false;
    }

    ifs.seekg(0, std::ios::beg);

    // Read the entire file into a buffer
    std::vector<uint8_t> file_data(file_size);
    if (!ifs.read(reinterpret_cast<char *>(file_data.data()), file_size)) {
        SRV_ERR(" - cold store: read failed: cannot read file data for ref %" PRIu64 "\n", ref);
        return false;
    }
    ifs.close();

    // Validation step 1: Confirm the file begins with the expected magic bytes
    cold_store_header header{};
    if (!deserialize_header(file_data.data(), file_data.size(), header)) {
        SRV_ERR(" - cold store: read failed: cannot deserialize header for ref %" PRIu64 "\n", ref);
        return false;
    }

    // Validation step 1: magic
    if (header.magic != COLD_STORE_MAGIC) {
        SRV_ERR(" - cold store: validation failed: magic mismatch (expected 0x%08X, got 0x%08X) for ref %" PRIu64 "\n",
                COLD_STORE_MAGIC, header.magic, ref);
#ifdef LLAMA_SERVER_CACHE_TESTS
        if (debug_validation_failure_ == io_failure_reason::validation_magic_mismatch) {
            return false;
        }
#endif
        return false;
    }

    // Validation step 2: format_version
    if (header.format_version != format_version_) {
        SRV_ERR(" - cold store: validation failed: format_version mismatch (expected %d, got %d) for ref %" PRIu64 "\n",
                static_cast<int>(format_version_), static_cast<int>(header.format_version), ref);
#ifdef LLAMA_SERVER_CACHE_TESTS
        if (debug_validation_failure_ == io_failure_reason::validation_format_version_mismatch) {
            return false;
        }
#endif
        return false;
    }

    // Validation step 3: header_checksum
    uint64_t expected_header_checksum = compute_header_checksum(header);
    if (header.header_checksum != expected_header_checksum) {
        SRV_ERR(" - cold store: validation failed: header_checksum mismatch (expected %" PRIu64 ", got %" PRIu64 ") for ref %" PRIu64 "\n",
                expected_header_checksum, header.header_checksum, ref);
#ifdef LLAMA_SERVER_CACHE_TESTS
        if (debug_validation_failure_ == io_failure_reason::validation_header_checksum_mismatch) {
            return false;
        }
#endif
        return false;
    }

    // Validation step 4: checksum_algorithm
    if (header.checksum_algorithm != COLD_STORE_CHECKSUM_ALGORITHM_FNV1A) {
        SRV_ERR(" - cold store: validation failed: unknown checksum_algorithm %d for ref %" PRIu64 "\n",
                static_cast<int>(header.checksum_algorithm), ref);
#ifdef LLAMA_SERVER_CACHE_TESTS
        if (debug_validation_failure_ == io_failure_reason::validation_checksum_algorithm_mismatch) {
            return false;
        }
#endif
        return false;
    }

    // Validation step 5: payload_id
    if (header.payload_id != ref) {
        SRV_ERR(" - cold store: validation failed: payload_id mismatch (expected %" PRIu64 ", got %" PRIu64 ") for ref %" PRIu64 "\n",
                ref, header.payload_id, ref);
#ifdef LLAMA_SERVER_CACHE_TESTS
        if (debug_validation_failure_ == io_failure_reason::validation_payload_id_mismatch) {
            return false;
        }
#endif
        return false;
    }

    // Validation step 6: pair_state
    // pair_state values: 0 = target_only, 1 = target_and_draft
    if (header.pair_state != 0 && header.pair_state != 1) {
        SRV_ERR(" - cold store: validation failed: invalid pair_state %d for ref %" PRIu64 "\n",
                static_cast<int>(header.pair_state), ref);
#ifdef LLAMA_SERVER_CACHE_TESTS
        if (debug_validation_failure_ == io_failure_reason::validation_pair_state_mismatch) {
            return false;
        }
#endif
        return false;
    }

    // Validation step 7: target_size_bytes
    size_t expected_payload_size = sizeof(cold_store_header) + header.target_size_bytes + header.draft_size_bytes;
    if (static_cast<size_t>(file_size) < expected_payload_size) {
        SRV_ERR(" - cold store: validation failed: file too small for declared payload sizes (file %lld, expected %zu) for ref %" PRIu64 "\n",
                static_cast<long long>(file_size), expected_payload_size, ref);
        return false;
    }

    // Validation step 8: draft_size_bytes (already checked in expected_payload_size above)

    // Read target bytes
    const uint8_t * payload_start = file_data.data() + sizeof(cold_store_header);
    target_bytes.assign(payload_start, payload_start + header.target_size_bytes);

    // Read draft bytes
    const uint8_t * draft_start = payload_start + header.target_size_bytes;
    draft_bytes.assign(draft_start, draft_start + header.draft_size_bytes);

    // Validation step 9: target_checksum
    uint64_t computed_target_checksum = fnv1a_checksum(target_bytes);
    if (computed_target_checksum != header.target_checksum) {
        SRV_ERR(" - cold store: validation failed: target_checksum mismatch (expected %" PRIu64 ", computed %" PRIu64 ") for ref %" PRIu64 "\n",
                header.target_checksum, computed_target_checksum, ref);
#ifdef LLAMA_SERVER_CACHE_TESTS
        if (debug_validation_failure_ == io_failure_reason::validation_target_checksum_mismatch) {
            return false;
        }
#endif
        return false;
    }

    // Validation step 10: draft_checksum (for target_and_draft)
    if (header.pair_state == 1) { // target_and_draft
        uint64_t computed_draft_checksum = fnv1a_checksum(draft_bytes);
        if (computed_draft_checksum != header.draft_checksum) {
            SRV_ERR(" - cold store: validation failed: draft_checksum mismatch (expected %" PRIu64 ", computed %" PRIu64 ") for ref %" PRIu64 "\n",
                    header.draft_checksum, computed_draft_checksum, ref);
#ifdef LLAMA_SERVER_CACHE_TESTS
            if (debug_validation_failure_ == io_failure_reason::validation_draft_checksum_mismatch) {
                return false;
            }
#endif
            return false;
        }
    }

    // Populate descriptor_out from the header
    descriptor_out.payload_id = header.payload_id;
    descriptor_out.pair_state = header.pair_state;
    descriptor_out.format_version = header.format_version;
    descriptor_out.target_size_bytes = header.target_size_bytes;
    descriptor_out.draft_size_bytes = header.draft_size_bytes;
    descriptor_out.target_checksum = header.target_checksum;
    descriptor_out.draft_checksum = header.draft_checksum;

    SRV_DBG(" - cold store: read cold file for ref %" PRIu64 " (payload_id %" PRIu64 ", %zu + %zu bytes)\n",
            ref, header.payload_id, target_bytes.size(), draft_bytes.size());

    return true;
}

bool server_cache_store_cold::remove(cold_ref ref) {
    if (!configured_) {
        return false;
    }

    std::string path = ref_to_path(ref);
    if (!validate_path(path)) {
        SRV_ERR(" - cold store: remove failed: payload path escaped root (ref=%" PRIu64 ")\n", ref);
        return false;
    }

    std::error_code ec;
    if (!fs::exists(path, ec)) {
        // File does not exist - that's fine, it's already removed
        return true;
    }

    bool removed = fs::remove(path, ec);
    if (ec || !removed) {
        SRV_WRN(" - cold store: remove failed: cannot delete cold file (ref=%" PRIu64 "): %s\n",
                ref, ec.message().c_str());
        return false;
    }

    SRV_DBG(" - cold store: removed cold file for ref %" PRIu64 "\n", ref);
    return true;
}

size_t server_cache_store_cold::delete_ids(const std::unordered_set<uint64_t> & ids) {
    if (!configured_ || ids.empty()) {
        return 0;
    }

    size_t deleted = 0;
    for (uint64_t id : ids) {
        // Per the header contract, ids that do not exist are silently skipped and
        // must not be counted. remove() is idempotent and returns true for
        // non-existent files, so check fs::exists() first to honor the contract.
        std::string path = ref_to_path(id);
        std::error_code ec;
        if (fs::exists(path, ec) && remove(id)) {
            deleted++;
        }
    }
    return deleted;
}

std::string server_cache_store_cold::final_path(uint64_t payload_id) const {
    std::stringstream ss;
    ss << std::hex << payload_id << ".cold";
    return (fs::path(root_path_) / ss.str()).string();
}

std::string server_cache_store_cold::staging_path(uint64_t payload_id) const {
    return final_path(payload_id) + ".tmp";
}

std::string server_cache_store_cold::ref_to_path(cold_ref ref) const {
    return final_path(ref);
}

bool server_cache_store_cold::validate_path(const std::string & path) const {
    if (!configured_ || path.empty()) {
        return false;
    }
    if (path.find('\n') != std::string::npos ||
        path.find('\r') != std::string::npos ||
        path.find('\0') != std::string::npos) {
        return false;
    }

    std::error_code ec;
    fs::path absolute_path = fs::absolute(fs::path(path), ec);
    if (ec) {
        return false;
    }
    return path_is_under_root(absolute_path);
}

bool server_cache_store_cold::path_is_under_root(const fs::path & path) const {
    std::error_code ec;
    const fs::path root = fs::weakly_canonical(fs::path(root_path_), ec);
    if (ec) {
        return false;
    }

    fs::path normalized = fs::weakly_canonical(path, ec);
    if (ec) {
        normalized = fs::absolute(path, ec);
        if (ec) {
            return false;
        }
        normalized = normalized.lexically_normal();
    }

#ifdef _WIN32
    std::string root_string = root.lexically_normal().string();
    std::string path_string = normalized.lexically_normal().string();
    std::transform(root_string.begin(), root_string.end(), root_string.begin(),
        [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
    std::transform(path_string.begin(), path_string.end(), path_string.begin(),
        [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
#else
    const std::string root_string = root.lexically_normal().string();
    const std::string path_string = normalized.lexically_normal().string();
#endif

    if (path_string == root_string) {
        return true;
    }
    const std::string separator(1, fs::path::preferred_separator);
    std::string root_prefix = root_string;
    if (!root_prefix.empty() && root_prefix.back() != fs::path::preferred_separator) {
        root_prefix += separator;
    }
    return path_string.rfind(root_prefix, 0) == 0;
}

std::string server_cache_store_cold::diagnostic_root() const {
    if (root_path_.empty()) {
        return "unconfigured";
    }
    const fs::path root(root_path_);
    const std::string leaf = root.filename().string();
    return leaf.empty() ? "configured" : leaf;
}

uint64_t server_cache_store_cold::fnv1a_checksum(const uint8_t * data, size_t len) {
    uint64_t hash = 1469598103934665603ull;
    for (size_t i = 0; i < len; ++i) {
        hash ^= data[i];
        hash *= 1099511628211ull;
    }
    return hash;
}

uint64_t server_cache_store_cold::fnv1a_checksum(const std::vector<uint8_t> & bytes) {
    return fnv1a_checksum(bytes.data(), bytes.size());
}

std::vector<uint8_t> server_cache_store_cold::serialize_header(const cold_store_header & header) {
    std::vector<uint8_t> buf(sizeof(header));
    std::memcpy(buf.data(), &header, sizeof(header));
    return buf;
}

bool server_cache_store_cold::deserialize_header(const uint8_t * data, size_t len, cold_store_header & header) {
    if (len < sizeof(header)) {
        return false;
    }
    std::memcpy(&header, data, sizeof(header));
    return true;
}

uint64_t server_cache_store_cold::compute_header_checksum(const cold_store_header & header) {
    // Compute checksum over all header bytes except the header_checksum field itself.
    // The header_checksum field is at offset 56 (bytes 56-63).
    // We checksum bytes 0-55 (everything before header_checksum).
    const uint8_t * raw = reinterpret_cast<const uint8_t *>(&header);
    return fnv1a_checksum(raw, offsetof(cold_store_header, header_checksum));
}
