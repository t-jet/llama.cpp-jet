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
#include <limits>
#include <map>
#include <set>

#ifdef _WIN32
#include <io.h>
#include <fcntl.h>
#include <windows.h>
#else
#include <fcntl.h>
#include <unistd.h>
#endif

namespace fs = std::filesystem;

namespace {
constexpr uint32_t TX_MAGIC = 0x39585443;
constexpr uint8_t TX_VERSION = 1;
constexpr uint32_t CLAIM_MAGIC = 0x394d4c43;
constexpr uint8_t CLAIM_VERSION = 1;

template<typename T> void put(std::ostream & out, const T & value) { out.write((const char *) &value, sizeof(value)); }
template<typename T> bool get(std::istream & in, T & value) { return !!in.read((char *) &value, sizeof(value)); }
void put_string(std::ostream & out, const std::string & value) { uint64_t n = value.size(); put(out, n); out.write(value.data(), n); }
bool get_string(std::istream & in, std::string & value) {
    uint64_t n = 0; if (!get(in, n) || n > (1u << 20)) return false;
    value.resize((size_t) n); return !n || !!in.read(value.data(), (std::streamsize) n);
}
void put_descriptor(std::ostream & out, const cold_recovered_descriptor & d) {
    put(out, d.file); put(out, d.payload_kind); put(out, d.owner); put(out, d.created_sequence);
    put(out, d.last_validated_sequence); put(out, d.token_span_start); put(out, d.token_span_end);
    put(out, d.position_start); put(out, d.position_end); put(out, d.checkpoint_boundary_required);
    put(out, d.checkpoint_boundary_native); put(out, d.checkpoint_boundary_kind); put(out, d.boundary_checksum);
    put_string(out, d.boundary_id); put_string(out, d.workload_profile);
}
bool get_descriptor(std::istream & in, cold_recovered_descriptor & d) {
    return get(in, d.file) && get(in, d.payload_kind) && d.payload_kind <= 1 && get(in, d.owner) && d.owner.owner_link <= 1 &&
        get(in, d.created_sequence) && get(in, d.last_validated_sequence) && get(in, d.token_span_start) &&
        get(in, d.token_span_end) && get(in, d.position_start) && get(in, d.position_end) &&
        get(in, d.checkpoint_boundary_required) && get(in, d.checkpoint_boundary_native) &&
        get(in, d.checkpoint_boundary_kind) && get(in, d.boundary_checksum) &&
        get_string(in, d.boundary_id) && get_string(in, d.workload_profile);
}
bool replace_file(const fs::path & temp, const fs::path & final) {
    std::error_code ec; fs::remove(final, ec); ec.clear(); fs::rename(temp, final, ec); return !ec;
}
bool flush_file(const fs::path & path) {
#ifdef _WIN32
    int fd = _open(path.string().c_str(), _O_RDWR | _O_BINARY); if (fd < 0) return false;
    const bool ok = _commit(fd) == 0; _close(fd); return ok;
#else
    int fd = open(path.c_str(), O_RDONLY); if (fd < 0) return false;
    const bool ok = fsync(fd) == 0; close(fd); return ok;
#endif
}
bool flush_directory(const fs::path & path) {
#ifdef _WIN32
    (void) path;
    return true;
#else
    int fd = open(path.c_str(), O_RDONLY | O_DIRECTORY); if (fd < 0) return false;
    const bool ok = fsync(fd) == 0; close(fd); return ok;
#endif
}
}

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

cold_prepare_result server_cache_store_cold::prepare(uint64_t payload_id,
        const std::vector<uint8_t> & target_bytes, const std::vector<uint8_t> & draft_bytes,
        const cold_descriptor_snapshot & snapshot) {
    cold_prepare_result result;
    if (!configured_) { result.code = cold_prepare_result_code::not_configured; return result; }
    if (target_bytes.size() > UINT64_MAX - draft_bytes.size() ||
        target_bytes.size() + draft_bytes.size() > UINT64_MAX - sizeof(cold_store_header)) {
        result.code = cold_prepare_result_code::size_overflow; return result;
    }
#ifdef LLAMA_SERVER_CACHE_TESTS
    if (debug_write_failure_) return result;
#endif
    cold_store_header header{};
    header.format_version = format_version_; header.payload_id = payload_id; header.pair_state = snapshot.pair_state;
    header.target_size_bytes = target_bytes.size(); header.draft_size_bytes = draft_bytes.size();
    header.target_checksum = fnv1a_checksum(target_bytes);
    header.draft_checksum = draft_bytes.empty() ? 0 : fnv1a_checksum(draft_bytes);
    header.header_checksum = compute_header_checksum(header);
    prepared_cold_object object;
    object.descriptor = snapshot; object.descriptor.payload_id = payload_id;
    object.descriptor.format_version = format_version_; object.descriptor.target_size_bytes = target_bytes.size();
    object.descriptor.draft_size_bytes = draft_bytes.size(); object.descriptor.target_checksum = header.target_checksum;
    object.descriptor.draft_checksum = header.draft_checksum;
    object.exact_bytes = sizeof(header) + target_bytes.size() + draft_bytes.size();
    object.staging_path = fs::path(root_path_) / (std::to_string(payload_id) + ".cold.prepare");
    object.final_path = final_path(payload_id);
    if (!validate_path(object.staging_path.string()) || !validate_path(object.final_path.string())) return result;
    std::ofstream out(object.staging_path, std::ios::binary | std::ios::trunc);
    auto bytes = serialize_header(header);
    out.write((const char *) bytes.data(), bytes.size());
    out.write((const char *) target_bytes.data(), target_bytes.size());
    out.write((const char *) draft_bytes.data(), draft_bytes.size()); out.close();
    if (!out || !flush_file(object.staging_path)) { std::error_code ec; fs::remove(object.staging_path, ec); return result; }
    result.object = std::move(object);
    result.code = validate_prepared(result.object) == cold_validate_result::valid ?
        cold_prepare_result_code::success : cold_prepare_result_code::validation_error;
    if (!result) { std::error_code ec; fs::remove(result.object.staging_path, ec); }
    return result;
}

cold_validate_result server_cache_store_cold::validate_prepared(const prepared_cold_object & object) const {
    if (!validate_path(object.staging_path.string())) return cold_validate_result::invalid_path;
    std::error_code ec; const uint64_t size = fs::file_size(object.staging_path, ec);
    if (ec) return cold_validate_result::missing;
    if (size != object.exact_bytes || size < sizeof(cold_store_header)) return cold_validate_result::invalid_size;
    std::ifstream in(object.staging_path, std::ios::binary);
    std::vector<uint8_t> bytes((size_t) size); if (!in.read((char *) bytes.data(), bytes.size())) return cold_validate_result::invalid_contents;
    cold_store_header h{}; if (!deserialize_header(bytes.data(), bytes.size(), h)) return cold_validate_result::invalid_contents;
    if (h.magic != COLD_STORE_MAGIC || h.format_version != format_version_ || h.header_checksum != compute_header_checksum(h) ||
        h.payload_id != object.descriptor.payload_id || h.pair_state != object.descriptor.pair_state ||
        h.target_size_bytes != object.descriptor.target_size_bytes || h.draft_size_bytes != object.descriptor.draft_size_bytes ||
        sizeof(h) + h.target_size_bytes + h.draft_size_bytes != size) return cold_validate_result::invalid_contents;
    const uint8_t * payload = bytes.data() + sizeof(h);
    if (fnv1a_checksum(payload, (size_t) h.target_size_bytes) != h.target_checksum ||
        (h.draft_size_bytes && fnv1a_checksum(payload + h.target_size_bytes, (size_t) h.draft_size_bytes) != h.draft_checksum))
        return cold_validate_result::invalid_contents;
    return cold_validate_result::valid;
}

bool server_cache_store_cold::quarantine(const cold_victim & victim, const cold_tx_id & tx_id) {
#ifdef LLAMA_SERVER_CACHE_TESTS
    if (debug_hit_tx_fault(debug_tx_fault::quarantine)) return false;
#endif
    fs::path source = victim.final_path.empty() ? final_path(victim.payload_id) : victim.final_path;
    fs::path dest = victim.quarantine_path.empty() ? source.string() + ".q." + std::to_string(tx_id) : victim.quarantine_path;
    if (!validate_path(source.string()) || !validate_path(dest.string())) return false;
    std::error_code ec;
    if (!fs::exists(source, ec)) return fs::exists(dest, ec);
    fs::rename(source, dest, ec); return !ec && flush_directory(root_path_);
}

bool server_cache_store_cold::publish(prepared_cold_object & object, const cold_tx_id &) {
#ifdef LLAMA_SERVER_CACHE_TESTS
    if (debug_hit_tx_fault(debug_tx_fault::publish)) return false;
#endif
    if (validate_prepared(object) != cold_validate_result::valid) return false;
    std::error_code ec;
    if (fs::exists(object.final_path, ec)) return false;
    fs::rename(object.staging_path, object.final_path, ec); return !ec && flush_directory(root_path_);
}

std::string server_cache_store_cold::manifest_path(cold_tx_id tx_id) const {
    return (fs::path(root_path_) / ("tx-" + std::to_string(tx_id) + ".manifest")).string();
}

bool server_cache_store_cold::write_manifest(const cold_tx_manifest & m) {
#ifdef LLAMA_SERVER_CACHE_TESTS
    if (m.state != cold_tx_state::committed && debug_hit_tx_fault(debug_tx_fault::manifest)) return false;
#endif
    if (!configured_ || m.state > cold_tx_state::committed) return false;
    fs::path final = manifest_path(m.tx_id), temp = final.string() + ".new";
    std::ofstream out(temp, std::ios::binary | std::ios::trunc);
    put(out, TX_MAGIC); put(out, TX_VERSION); put(out, m.state); put(out, m.tx_id); put_descriptor(out, m.incoming_descriptor);
    put(out, m.incoming_exact_bytes); put_string(out, m.incoming_final_path.string());
    put(out, m.logical_bytes_before); put(out, m.victim_bytes); put(out, m.logical_bytes_after);
    put_string(out, m.incoming.staging_path.string());
    uint64_t count = m.victims.size(); put(out, count);
    for (const auto & v : m.victims) { put_descriptor(out, v.descriptor); put(out, v.exact_bytes); put_string(out, v.quarantine_path.string()); put(out, v.committed_tombstone); }
    out.close(); if (!out || !flush_file(temp)) { std::error_code ec; fs::remove(temp, ec); return false; }
    return replace_file(temp, final) && flush_directory(root_path_);
}

bool server_cache_store_cold::mark_committed(cold_tx_manifest & manifest) {
#ifdef LLAMA_SERVER_CACHE_TESTS
    if (debug_hit_tx_fault(debug_tx_fault::commit_marker)) return false;
#endif
    const auto old = manifest.state; manifest.state = cold_tx_state::committed;
    if (!write_manifest(manifest)) { manifest.state = old; return false; }
    return apply_claims(manifest);
}

std::string server_cache_store_cold::claims_path() const {
    return (fs::path(root_path_) / "ownership.claims").string();
}

bool server_cache_store_cold::apply_claims(const cold_recovered_commit & committed) {
    std::map<uint64_t, std::pair<cold_recovered_descriptor, uint64_t>> claims;
    const fs::path current = claims_path();
    if (fs::exists(current)) {
        std::ifstream in(current, std::ios::binary);
        uint32_t magic = 0; uint8_t version = 0; uint64_t count = 0;
        if (!get(in, magic) || magic != CLAIM_MAGIC || !get(in, version) || version != CLAIM_VERSION ||
            !get(in, count) || count > 100000) return false;
        for (uint64_t i = 0; i < count; ++i) {
            cold_recovered_descriptor descriptor; uint64_t bytes = 0;
            if (!get_descriptor(in, descriptor) || !get(in, bytes) || descriptor.file.payload_id == 0 ||
                !claims.emplace(descriptor.file.payload_id, std::make_pair(descriptor, bytes)).second) return false;
        }
    }
    for (const auto & victim : committed.victims) claims.erase(victim.descriptor.file.payload_id);
    claims[committed.incoming_descriptor.file.payload_id] = {committed.incoming_descriptor, committed.incoming_exact_bytes};
    const fs::path temp = current.string() + ".new";
    std::ofstream out(temp, std::ios::binary | std::ios::trunc);
    put(out, CLAIM_MAGIC); put(out, CLAIM_VERSION); put(out, static_cast<uint64_t>(claims.size()));
    for (const auto & item : claims) { put_descriptor(out, item.second.first); put(out, item.second.second); }
    out.close();
    if (!out || !flush_file(temp)) { std::error_code ec; fs::remove(temp, ec); return false; }
    return replace_file(temp, current) && flush_directory(root_path_);
}

bool server_cache_store_cold::remove_claim(uint64_t payload_id) {
    const fs::path current = claims_path();
    if (!fs::exists(current)) return true;
    std::ifstream in(current, std::ios::binary);
    uint32_t magic = 0; uint8_t version = 0; uint64_t count = 0;
    std::vector<std::pair<cold_recovered_descriptor, uint64_t>> claims;
    if (!get(in, magic) || magic != CLAIM_MAGIC || !get(in, version) || version != CLAIM_VERSION ||
        !get(in, count) || count > 100000) return false;
    for (uint64_t i = 0; i < count; ++i) {
        cold_recovered_descriptor descriptor; uint64_t bytes = 0;
        if (!get_descriptor(in, descriptor) || !get(in, bytes)) return false;
        if (descriptor.file.payload_id != payload_id) claims.push_back({std::move(descriptor), bytes});
    }
    in.close();
    const fs::path temp = current.string() + ".new";
    std::ofstream out(temp, std::ios::binary | std::ios::trunc);
    put(out, CLAIM_MAGIC); put(out, CLAIM_VERSION); put(out, static_cast<uint64_t>(claims.size()));
    for (const auto & item : claims) { put_descriptor(out, item.first); put(out, item.second); }
    out.close();
    if (!out || !flush_file(temp)) { std::error_code ec; fs::remove(temp, ec); return false; }
    return replace_file(temp, current) && flush_directory(root_path_);
}

cold_cleanup_result server_cache_store_cold::cleanup(cold_tx_manifest & manifest) {
    cold_cleanup_result result;
#ifdef LLAMA_SERVER_CACHE_TESTS
    if (debug_hit_tx_fault(debug_tx_fault::cleanup)) { result.success = false; return result; }
#endif
    std::error_code ec;
    for (const auto & v : manifest.victims) {
#ifdef LLAMA_SERVER_CACHE_TESTS
        if (debug_hit_tx_fault(debug_tx_fault::victim_unlink)) { result.success = false; continue; }
#endif
        if (!v.quarantine_path.empty() && fs::exists(v.quarantine_path, ec)) {
            ec.clear(); if (fs::remove(v.quarantine_path, ec)) result.files_removed++; else result.success = false;
        }
    }
    if (result.success) {
#ifdef LLAMA_SERVER_CACHE_TESTS
        if (debug_hit_tx_fault(debug_tx_fault::manifest_unlink)) return {false, result.files_removed};
#endif
        fs::remove(manifest_path(manifest.tx_id), ec); if (ec || !flush_directory(root_path_)) result.success = false;
    }
    return result;
}

cold_store_recovery_result server_cache_store_cold::recover_transactions() {
    cold_store_recovery_result result;
    if (!configured_) { result.mutation_disabled = true; return result; }
    std::error_code ec;
    if (fs::exists(claims_path(), ec)) {
        std::ifstream in(claims_path(), std::ios::binary);
        uint32_t magic = 0; uint8_t version = 0; uint64_t count = 0;
        bool ok = get(in, magic) && magic == CLAIM_MAGIC && get(in, version) && version == CLAIM_VERSION &&
            get(in, count) && count <= 100000;
        std::set<std::pair<uint64_t, uint8_t>> owners;
        for (uint64_t i = 0; ok && i < count; ++i) {
            cold_recovered_commit claim{};
            ok = get_descriptor(in, claim.incoming_descriptor) && get(in, claim.incoming_exact_bytes);
            const auto & d = claim.incoming_descriptor;
            const auto owner = std::make_pair(d.owner.entry_id, d.owner.owner_link);
            ok = ok && d.file.payload_id != 0 && d.owner.entry_id != 0 && d.payload_kind <= 1 &&
                d.owner.owner_link <= 1 && d.owner.owner_link == (d.payload_kind == 1) && owners.insert(owner).second;
            claim.incoming_final_path = final_path(d.file.payload_id);
            ok = ok && fs::exists(claim.incoming_final_path, ec) && !ec;
            if (ok) result.claims.push_back(std::move(claim));
        }
        if (!ok) result.mutation_disabled = true;
    }
    for (const auto & entry : fs::directory_iterator(root_path_, ec)) {
        if (ec || entry.path().extension() != ".manifest") continue;
        std::ifstream in(entry.path(), std::ios::binary);
        cold_tx_manifest m; uint32_t magic = 0; uint8_t version = 0; std::string path; uint64_t count = 0;
        bool ok = get(in, magic) && magic == TX_MAGIC && get(in, version) && version == TX_VERSION &&
            get(in, m.state) && m.state <= cold_tx_state::committed && get(in, m.tx_id) &&
            get_descriptor(in, m.incoming_descriptor) && get(in, m.incoming_exact_bytes) && get_string(in, path);
        m.incoming_final_path = path;
        ok = ok && get(in, m.logical_bytes_before) && get(in, m.victim_bytes) && get(in, m.logical_bytes_after) && get_string(in, path) && get(in, count) && count <= 100000;
        m.incoming.staging_path = path; m.incoming.final_path = m.incoming_final_path;
        for (uint64_t i = 0; ok && i < count; ++i) {
            cold_recovered_victim v; ok = get_descriptor(in, v.descriptor) && get(in, v.exact_bytes) && get_string(in, path) && get(in, v.committed_tombstone);
            v.quarantine_path = path; m.victims.push_back(std::move(v));
        }
        uint64_t summed = 0;
        for (const auto & v : m.victims) { if (summed > UINT64_MAX - v.exact_bytes) ok = false; else summed += v.exact_bytes; }
        ok = ok && summed == m.victim_bytes && m.logical_bytes_before >= m.victim_bytes &&
            m.logical_bytes_before - m.victim_bytes <= UINT64_MAX - m.incoming_exact_bytes &&
            m.logical_bytes_before - m.victim_bytes + m.incoming_exact_bytes == m.logical_bytes_after &&
            validate_path(m.incoming_final_path.string());
        if (!ok) { result.mutation_disabled = true; continue; }
        if (m.state == cold_tx_state::committed) {
            if (!apply_claims(m)) result.mutation_disabled = true;
            result.committed.push_back(m);
            continue;
        }

        // Pre-commit replay restores old final files before removing incoming work.
        if (fs::exists(m.incoming_final_path, ec)) { ec.clear(); if (!fs::remove(m.incoming_final_path, ec)) result.precommit_cleanup.success = false; else result.precommit_cleanup.files_removed++; }
        if (fs::exists(m.incoming.staging_path, ec)) { ec.clear(); if (!fs::remove(m.incoming.staging_path, ec)) result.precommit_cleanup.success = false; else result.precommit_cleanup.files_removed++; }
        for (const auto & v : m.victims) {
            const fs::path final = final_path(v.descriptor.file.payload_id);
            if (fs::exists(v.quarantine_path, ec) && !fs::exists(final, ec)) { ec.clear(); fs::rename(v.quarantine_path, final, ec); if (ec) result.precommit_cleanup.success = false; }
        }
        if (result.precommit_cleanup.success) { ec.clear(); fs::remove(entry.path(), ec); if (ec) result.precommit_cleanup.success = false; }
        if (!result.precommit_cleanup.success) result.mutation_disabled = true;
    }
    if (ec) result.mutation_disabled = true;
    return result;
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
        return remove_claim(ref);
    }

    bool removed = fs::remove(path, ec);
    if (ec || !removed) {
        SRV_WRN(" - cold store: remove failed: cannot delete cold file (ref=%" PRIu64 "): %s\n",
                ref, ec.message().c_str());
        return false;
    }

    if (!remove_claim(ref)) {
        SRV_WRN(" - cold store: removed payload but failed to clear ownership claim (ref=%" PRIu64 ")\n", ref);
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
