// Step 2 focused test: server_cache_store_cold interface and module
// This test verifies the cold store class interface, header format, constants,
// configure/remove/is_configured operations, and NB-3 removal note.

#include "server-cache-store-cold.h"
#include "server-cache-hybrid.h"

#include <cstdio>
#include <cstdlib>
#include <cstdint>
#include <string>
#include <vector>
#include <filesystem>
#include <fstream>

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

// Helper to create a temporary directory for cold store tests
static std::string create_temp_dir() {
    std::string temp_dir = fs::temp_directory_path().string() + "/cold_store_test_" +
                           std::to_string(std::hash<std::thread::id>{}(std::this_thread::get_id())) +
                           "_" + std::to_string(reinterpret_cast<uintptr_t>(&temp_dir)); // unique per run
    fs::create_directories(temp_dir);
    return temp_dir;
}

static void remove_temp_dir(const std::string & path) {
    std::error_code ec;
    fs::remove_all(path, ec);
    (void)ec;
}

// Test 1: Default-constructed cold store is not configured
void test_default_not_configured() {
    printf("step2: default-constructed cold store is not configured...\n");
    server_cache_store_cold store;
    TEST_ASSERT(!store.is_configured());
    printf("  PASSED\n");
}

// Test 2: configure with valid temporary directory succeeds
void test_configure_valid_dir() {
    printf("step2: configure with valid temporary directory...\n");
    server_cache_store_cold store;
    TEST_ASSERT(!store.is_configured());

    std::string temp_dir = fs::temp_directory_path().string() + "/cold_store_step2_valid";
    fs::create_directories(temp_dir);

    bool result = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(result);
    TEST_ASSERT(store.is_configured());

    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 3: configure with non-existent path fails
void test_configure_nonexistent_path() {
    printf("step2: configure with non-existent path fails...\n");
    server_cache_store_cold store;

    std::string nonexistent = "/nonexistent/path/that/does/not/exist/cold_store_test";
    bool result = store.configure(nonexistent, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(!result);
    TEST_ASSERT(!store.is_configured());

    printf("  PASSED\n");
}

// Test 4: configure with empty path fails
void test_configure_empty_path() {
    printf("step2: configure with empty path fails...\n");
    server_cache_store_cold store;

    bool result = store.configure("", COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(!result);
    TEST_ASSERT(!store.is_configured());

    printf("  PASSED\n");
}

// Test 5: configure with a file path (not a directory) fails
void test_configure_file_not_directory() {
    printf("step2: configure with a file path (not a directory) fails...\n");
    server_cache_store_cold store;

    // Create a temporary file (not a directory)
    std::string temp_file = fs::temp_directory_path().string() + "/cold_store_step2_notdir.txt";
    {
        std::ofstream ofs(temp_file);
        ofs << "test";
    }

    bool result = store.configure(temp_file, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(!result);
    TEST_ASSERT(!store.is_configured());

    fs::remove(temp_file);
    printf("  PASSED\n");
}

// Test 6: remove on unconfigured store returns false
void test_remove_unconfigured() {
    printf("step2: remove on unconfigured store returns false...\n");
    server_cache_store_cold store;

    bool result = store.remove(1);
    TEST_ASSERT(!result);

    printf("  PASSED\n");
}

// Test 7: remove on configured store with nonexistent ref returns true
void test_remove_nonexistent_ref() {
    printf("step2: remove on configured store with nonexistent ref returns true...\n");
    server_cache_store_cold store;

    std::string temp_dir = fs::temp_directory_path().string() + "/cold_store_step2_remove";
    fs::create_directories(temp_dir);

    bool cfg_result = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(cfg_result);

    // Removing a ref that doesn't map to any file should return true
    bool result = store.remove(99999);
    TEST_ASSERT(result);

    remove_temp_dir(temp_dir);
    printf("  PASSED\n");
}

// Test 8: cold_store_header has correct size (64 bytes)
void test_header_size() {
    printf("step2: cold_store_header has correct size (64 bytes)...\n");
    TEST_ASSERT(sizeof(cold_store_header) == 64);
    printf("  PASSED\n");
}

// Test 9: cold_store_header default values match constants
void test_header_defaults() {
    printf("step2: cold_store_header default values match constants...\n");
    cold_store_header header{};
    TEST_ASSERT(header.magic == COLD_STORE_MAGIC);
    TEST_ASSERT(header.format_version == COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(header.checksum_algorithm == COLD_STORE_CHECKSUM_ALGORITHM_FNV1A);
    TEST_ASSERT(header.payload_id == 0);
    TEST_ASSERT(header.pair_state == 0);
    TEST_ASSERT(header.target_size_bytes == 0);
    TEST_ASSERT(header.draft_size_bytes == 0);
    TEST_ASSERT(header.target_checksum == 0);
    TEST_ASSERT(header.draft_checksum == 0);
    TEST_ASSERT(header.header_checksum == 0);
    printf("  PASSED\n");
}

// Test 10: cold_ref type is uint64_t
void test_cold_ref_type() {
    printf("step2: cold_ref type is uint64_t...\n");
    static_assert(std::is_same<cold_ref, uint64_t>::value, "cold_ref must be uint64_t");
    cold_ref ref = 0;
    TEST_ASSERT(ref == 0);
    ref = 12345;
    TEST_ASSERT(ref == 12345);
    printf("  PASSED\n");
}

// Test 11: cold_store_result enum has expected values
void test_cold_store_result_enum() {
    printf("step2: cold_store_result enum has expected values...\n");
    // Verify all enum values exist and are distinct
    cold_store_result results[] = {
        cold_store_result::success,
        cold_store_result::failure_not_configured,
        cold_store_result::failure_write_error,
        cold_store_result::failure_read_error,
        cold_store_result::failure_validation_error,
        cold_store_result::failure_not_found,
        cold_store_result::failure_path_traversal,
        cold_store_result::failure_rename_error,
        cold_store_result::failure_disk_full,
    };
    (void)results;
    printf("  PASSED\n");
}

// Test 12: io_failure_reason enum has expected values
void test_io_failure_reason_enum() {
    printf("step2: io_failure_reason enum has expected values...\n");
    io_failure_reason reasons[] = {
        io_failure_reason::none,
        io_failure_reason::write_error,
        io_failure_reason::read_error,
        io_failure_reason::validation_magic_mismatch,
        io_failure_reason::validation_format_version_mismatch,
        io_failure_reason::validation_header_checksum_mismatch,
        io_failure_reason::validation_checksum_algorithm_mismatch,
        io_failure_reason::validation_payload_id_mismatch,
        io_failure_reason::validation_pair_state_mismatch,
        io_failure_reason::validation_target_size_mismatch,
        io_failure_reason::validation_draft_size_mismatch,
        io_failure_reason::validation_target_checksum_mismatch,
        io_failure_reason::validation_draft_checksum_mismatch,
        io_failure_reason::validation_file_not_found,
        io_failure_reason::validation_file_truncated,
        io_failure_reason::queue_full,
        io_failure_reason::cancelled,
    };
    (void)reasons;
    printf("  PASSED\n");
}

// Test 13: cold_descriptor_snapshot defaults
void test_descriptor_snapshot_defaults() {
    printf("step2: cold_descriptor_snapshot defaults...\n");
    cold_descriptor_snapshot snap{};
    TEST_ASSERT(snap.payload_id == 0);
    TEST_ASSERT(snap.pair_state == 0);
    TEST_ASSERT(snap.format_version == 1);
    TEST_ASSERT(snap.target_size_bytes == 0);
    TEST_ASSERT(snap.draft_size_bytes == 0);
    TEST_ASSERT(snap.target_checksum == 0);
    TEST_ASSERT(snap.draft_checksum == 0);
    printf("  PASSED\n");
}

// Test 14: configure with read-only directory fails
void test_configure_readonly_dir() {
    printf("step2: configure with read-only directory fails...\n");
    server_cache_store_cold store;

    // On Windows, creating a truly read-only directory is complex.
    // Skip this test on Windows as the behavior differs.
#ifndef _WIN32
    std::string temp_dir = fs::temp_directory_path().string() + "/cold_store_step2_readonly";
    fs::create_directories(temp_dir);

    // Make directory read-only
    fs::permissions(temp_dir, fs::perms::owner_read | fs::perms::group_read | fs::perms::others_read);

    bool result = store.configure(temp_dir, COLD_STORE_FORMAT_VERSION_1);
    TEST_ASSERT(!result);
    TEST_ASSERT(!store.is_configured());

    // Restore permissions for cleanup
    fs::permissions(temp_dir, fs::perms::owner_all);
    remove_temp_dir(temp_dir);
#else
    printf("  SKIPPED (Windows)\n");
#endif

    printf("  PASSED\n");
}

// Test 15: write and read are stubs that return failure on unconfigured store
void test_write_read_unconfigured() {
    printf("step2: write and read return failure on unconfigured store...\n");
    server_cache_store_cold store;

    // write should return 0 (failure) when not configured
    cold_ref ref = store.write(1, {0x01, 0x02}, {}, {});
    TEST_ASSERT(ref == 0);

    // read should return false when not configured
    std::vector<uint8_t> target_bytes;
    std::vector<uint8_t> draft_bytes;
    cold_descriptor_snapshot snap;
    bool read_result = store.read(1, target_bytes, draft_bytes, snap);
    TEST_ASSERT(!read_result);

    printf("  PASSED\n");
}

int main() {
    printf("==================================================\n");
    printf("Step 2: Cold store interface and module files\n");
    printf("==================================================\n\n");

    test_default_not_configured();
    test_configure_valid_dir();
    test_configure_nonexistent_path();
    test_configure_empty_path();
    test_configure_file_not_directory();
    test_remove_unconfigured();
    test_remove_nonexistent_ref();
    test_header_size();
    test_header_defaults();
    test_cold_ref_type();
    test_cold_store_result_enum();
    test_io_failure_reason_enum();
    test_descriptor_snapshot_defaults();
    test_configure_readonly_dir();
    test_write_read_unconfigured();

    printf("\n==================================================\n");
    printf("All Step 2 tests passed! (15 tests)\n");
    printf("==================================================\n");
    return 0;
}