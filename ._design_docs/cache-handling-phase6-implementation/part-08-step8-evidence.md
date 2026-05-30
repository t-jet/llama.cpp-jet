# Phase 6 implementation evidence - Part 8: Step 8

## Step 8: Integration with `hybrid_cache_controller` — wiring and startup configuration

**Date:** May 30, 2026
**Status:** Complete (pre-existing implementation verified, acceptance tests added)

### Goal

Wire the cold store and worker into `hybrid_cache_controller` construction and add startup configuration check for `--cache-cold-path`.

### Pre-existing implementation

All Step 8 requirements were already implemented in the codebase from prior Stage 6 partial implementation. This step verified the existing implementation against the design requirements and added focused acceptance tests.

### Verified requirements

| Requirement | Status | Evidence |
| ----------- | ------ | -------- |
| `server-cache-hybrid.h`: `server_cache_store_cold cold_store` and `server_cache_io_worker io_worker` as private members | ✅ PASS | Lines 379-380 in `server-cache-hybrid.h` |
| `server-cache-hybrid.h`: Constructor takes `cold_path` parameter | ✅ PASS | Line 242 in `server-cache-hybrid.h`: `const std::string & cold_path = ""` |
| `server-cache-hybrid.cpp`: Constructor configures cold store if `cold_path` is non-empty | ✅ PASS | Lines 24-28 in `server-cache-hybrid.cpp`: `if (!cold_path.empty()) { cold_store.configure(cold_path, COLD_STORE_FORMAT_VERSION_1) }` |
| `server-cache-hybrid.cpp`: Constructor throws on configure failure (not abort) | ✅ PASS | Lines 29-31: `throw std::runtime_error("cold store configuration failed: " + cold_path)` |
| `server-cache-hybrid.cpp`: Constructor wires cold store to I/O worker | ✅ PASS | Line 33: `io_worker.set_cold_store(&cold_store)` |
| `server-cache-hybrid.cpp`: Constructor starts I/O worker after configure succeeds | ✅ PASS | Lines 36-39: `if (!io_worker.start()) { throw std::runtime_error(...) }` |
| `server-cache-hybrid.cpp`: Destructor calls `io_worker.stop()` before releasing cold store | ✅ PASS | Lines 42-45: `if (io_worker.is_running()) { io_worker.stop(); }` |
| `server-context.cpp`: `create_cache_controller` passes `cold_path` to constructor | ✅ PASS | Lines 1201-1208 in `server-context.cpp` |
| `server-context.cpp`: Validates `--cache-cold-path` requires hybrid mode | ✅ PASS | Lines 1218-1224: checks `cache_mode_active != CACHE_MODE_HYBRID` and throws |
| No use of `abort()` in error paths | ✅ PASS | All error paths use `throw std::runtime_error` |

### Changed files

| File | Change |
| ---- | ------ |
| `tools/server/server-cache-hybrid.h` | Added `debug_cold_store_for_tests()` and `debug_io_worker_for_tests()` accessor methods under `LLAMA_SERVER_CACHE_TESTS` guard for Step 8 acceptance tests. |
| `tests/test-step8-integration-wiring.cpp` | New standalone test file with 13 focused Step 8 tests. |
| `tests/CMakeLists.txt` | Added `test-step8-integration-wiring` build target. |

### Behavior changes

1. **Test accessors** — Two new test accessor methods added to `hybrid_cache_controller` under `LLAMA_SERVER_CACHE_TESTS`: `debug_cold_store_for_tests()` returns a reference to the private `cold_store` member, and `debug_io_worker_for_tests()` returns a reference to the private `io_worker` member. These are needed because the acceptance tests must verify `is_configured()` and `is_running()` on these private members.

### Acceptance tests

**Test file:** `tests/test-step8-integration-wiring.cpp`

| Test | Description | Result |
| ---- | ----------- | ------ |
| 1 | `cold_store.is_configured()` returns true with valid path | PASSED |
| 2 | Worker thread is running after construction | PASSED |
| 3 | Destructor joins the worker thread | PASSED |
| 4 | Empty `cold_path` — cold store not configured | PASSED |
| 5 | Non-existent `cold_path` throws `runtime_error` | PASSED |
| 6 | File path (not directory) as `cold_path` throws `runtime_error` | PASSED |
| 7 | Constructor throws on configure failure (not abort) | PASSED |
| 8 | Cold store uses `FORMAT_VERSION_1` after configuration | PASSED |
| 9 | Destructor calls `io_worker.stop()` | PASSED |
| 10 | Cold store is wired to I/O worker (demotion round-trip) | PASSED |
| 11 | `--cache-cold-path` requires hybrid mode (code inspection) | PASSED |
| 12 | No `abort()` in constructor error paths | PASSED |
| 13 | Default `cold_path` parameter — no configuration | PASSED |

### Build evidence

**Build command:** `cmake --build build --target test-step8-integration-wiring --config Release`
**Result:** PASS — compiled and linked successfully.

**Build command:** `cmake --build build --target llama-server --config Release`
**Result:** PASS — no regressions.

**Build command:** `cmake --build build --target test-step7-promotion-protocol --config Release`
**Result:** PASS — no regressions.

### Test results

**Step 8 standalone test:**

```
==================================================
Step 8: Integration with hybrid_cache_controller
==================================================

step8: cold_store.is_configured() returns true with valid path...
  PASSED
step8: worker thread is running after construction...
  PASSED
step8: destructor joins worker thread...
  PASSED
step8: empty cold_path — cold store not configured...
  PASSED
step8: non-existent cold_path throws runtime_error...
  PASSED
step8: file path (not directory) as cold_path throws runtime_error...
  PASSED
step8: constructor throws on configure failure (not abort)...
  PASSED
step8: cold store uses FORMAT_VERSION_1 after configuration...
  PASSED
step8: destructor calls io_worker.stop()...
  PASSED
step8: cold store is wired to io_worker...
  PASSED
step8: cold_path requires hybrid mode (verified by code inspection)...
  PASSED (verified by code inspection)
step8: no abort() in constructor error paths...
  PASSED
step8: default cold_path parameter — no configuration...
  PASSED

==================================================
All Step 8 tests passed successfully!
==================================================
```text

**Step 7 regression test:** All 16 tests PASSED.

### Implementation notes

- The Step 8 implementation was already complete in the codebase. The constructor in `server-cache-hybrid.cpp` correctly wires `cold_store.configure()`, `io_worker.set_cold_store()`, and `io_worker.start()` in the right order, with proper error handling via `throw std::runtime_error` (not `abort()`).
- The destructor correctly calls `io_worker.stop()` before the cold store is released (member destruction order ensures `io_worker` is destroyed after `cold_store` since `io_worker` is declared after `cold_store` in the class, but the explicit `stop()` call in the destructor ensures clean shutdown before any member destruction).
- The `server-context.cpp` startup validation checks that `--cache-cold-path` requires `--cache-mode hybrid` and throws a descriptive error message before `accept()`.
- The `server_cache_store_cold::configure()` method already performs all five startup validation checks from Step 9 (non-empty path, path exists, is a directory, is writable, and world-writable warning on POSIX).
