# Cache handling phases 1 and 2 implementation gaps - Part 2: Hybrid exact-blob matching

Source: [../cache-handling-phases-1-and-2-implementation-gaps.md](../cache-handling-phases-1-and-2-implementation-gaps.md)

#### Hybrid exact-blob matching

Changed hybrid lookup so exact full-state blobs are selected only when the whole cached entry is a prefix of the new request. Divergent partial matches are now rejected before restore.

Files changed:

- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tools/server/server-cache-hybrid.h`

What changed:

- `find_best_match()` no longer accepts a cached entry when only part of that cached entry matches the request.
- `load_slot()` has a second guard that rejects partial exact-blob matches before applying state.
- Cache hit accounting now increments only after restore succeeds.

Covered by test:

- `test_hybrid_rejects_partial_blob_match`

#### Target/draft paired restore

Changed hybrid restore validation so a target-plus-draft cache entry must have the expected paired payloads before restore proceeds. Draft restore failure now fails the cache load instead of logging a warning and returning success.

Files changed:

- `tools/server/server-context.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`

What changed:

- `load_slot()` validates expected target and draft payloads before applying state.
- Target and draft restore byte counts must match the stored payload sizes.
- Added `n_restore_failures` to hybrid cache stats.

Remaining gap:

- This path still needs a model-backed integration test with a real target/draft context. The current unit target cannot exercise `llama_state_seq_set_data_ext()`.

#### Prefix-index lookup

Changed hybrid prefix lookup so requests also check shorter prefix buckets. This fixes the case where a cached entry shorter than `PREFIX_INDEX_LENGTH` is a valid prefix of a longer request.

Files changed:

- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`

Covered by test:

- `test_hybrid_prefix_index_short_entry`

#### Prepared-prompt metadata shape

Extended prepared-prompt metadata so it can represent spans and later validation/protection data while keeping the existing point-style API.

Files changed:

- `tools/server/server-task.h`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`

What changed:

- `prompt_boundary` now carries `token_start`, `token_end`, `checksum`, and `protect`.
- `prepared_prompt_metadata` now carries `compatibility_key`, `preparation_id`, `degraded_reason`, `protect_system`, and `protect_messages`.
- Added `add_span()` and `degraded()` helpers.
- Generic rendered-text metadata now records span checksums and marks fallback completion metadata as degraded.

Covered by test:

- `test_metadata_spans`

Remaining gap:

- Boundary capture is still rendered-text post-processing, not native capture during template rendering/tokenization. It is now better marked as degraded/minimal where appropriate, but full Stage 2 capture still needs fixture-backed work.

#### Test coverage

Expanded `tests/test-cache-controller.cpp` from 15 checks to 18 checks.

New checks:

- span metadata fields and clear behavior
- rejection of divergent partial exact-blob matches
- lookup of cached prefixes shorter than the prefix-index length

Added small hybrid debug helpers so lookup/index behavior can be tested without a model context:

- `debug_add_entry_for_tests()`
- `debug_find_match_tokens_for_tests()`

These helpers are intentionally limited to pure lookup/index coverage.

### Test results

Commands run after changes:

```text
cmake --build build-phase2 --config Release --target test-cache-controller
cmake --build build-phase2 --config Release --target llama-server
ctest --test-dir build-phase2 -C Release -R test-cache-controller --output-on-failure
.\build-phase2\bin\Release\test-cache-controller.exe
```

Results:

- `test-cache-controller` built successfully.
- `llama-server` built successfully.
- CTest result: 1/1 tests passed.
- Direct test executable result: 18/18 checks passed.

Direct test output included these new passing checks:

```text
test-cache-controller: metadata spans... PASSED
test-cache-controller: hybrid rejects partial blob match... PASSED
test-cache-controller: hybrid prefix index short entry... PASSED
```

Coverage note:

- Unit coverage was expanded for the pure controller and metadata logic touched here.
- Line/branch coverage was not measured because no coverage tool was available in this build environment.
- Runtime save/load coverage with real llama contexts remains incomplete.

### Remaining work

The following gaps are still open:

1. Add model-backed integration tests for hybrid save/load round trip.
2. Add target-plus-draft integration coverage for paired restore success and failure.
3. Replace rendered-text boundary inference with prompt-preparation capture or mark all inferred metadata as degraded until fixture tests prove it.
4. Add fixture tests for repeated message content, empty content, tool calls, and templates that add role/control tokens.
5. Decide whether the debug lookup helpers should stay, move behind a test macro, or be replaced by a small pure helper module.

## Coverage run

Date: 2026-05-24

OpenCppCoverage was found at:

```text
D:\app\OpenCppCoverage\OpenCppCoverage.exe
```

### Coverage build

Commands run:

```text
cmake -S . -B build-coverage -DLLAMA_BUILD_TESTS=ON -DBUILD_SHARED_LIBS=OFF
cmake --build build-coverage --config Debug --target test-cache-controller
```

Result:

- Debug test target built successfully at `build-coverage\bin\Debug\test-cache-controller.exe`.
- Build produced expected existing warnings from other project files, but no cache-test build failure.

### Broad server/test coverage

Command run:

```text
D:\app\OpenCppCoverage\OpenCppCoverage.exe ^
  --sources D:\source\llama.cpp-jet\tools\server ^
  --sources D:\source\llama.cpp-jet\tests ^
  --excluded_sources D:\source\llama.cpp-jet\build-coverage ^
  --excluded_sources D:\source\llama.cpp-jet\build-phase2 ^
  --export_type html:D:\source\llama.cpp-jet\build-coverage\coverage-html ^
  --export_type cobertura:D:\source\llama.cpp-jet\build-coverage\coverage.xml ^
  -- D:\source\llama.cpp-jet\build-coverage\bin\Debug\test-cache-controller.exe
```

Result:

- Test executable passed all 18 checks.
- HTML report: `build-coverage\coverage-html\index.html`
- Cobertura report: `build-coverage\coverage.xml`
- Overall line rate across selected `tools/server` and `tests` sources: 8.22% (`505/6143` lines).

Interpretation:

- This broad number is expected to be low because `test-cache-controller` links the server library but only exercises a small cache-controller slice.
- It should not be used as the quality gate for the current corrective pass.

### Focused cache coverage

Command run:

```text
D:\app\OpenCppCoverage\OpenCppCoverage.exe ^
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-hybrid.cpp ^
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-hybrid.h ^
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-controller.cpp ^
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-controller.h ^
  --sources D:\source\llama.cpp-jet\tools\server\server-task.h ^
  --sources D:\source\llama.cpp-jet\tests\test-cache-controller.cpp ^
  --export_type html:D:\source\llama.cpp-jet\build-coverage\coverage-cache-html ^
  --export_type cobertura:D:\source\llama.cpp-jet\build-coverage\coverage-cache.xml ^
  -- D:\source\llama.cpp-jet\build-coverage\bin\Debug\test-cache-controller.exe
```

Result:

- Test executable passed all 18 checks.
- HTML report: `build-coverage\coverage-cache-html\index.html`
- Cobertura report: `build-coverage\coverage-cache.xml`
- Focused line rate: 72.52% (`438/604` lines).

Per-file line rates:

| File | Line rate |
| --- | ---: |
| `tests/test-cache-controller.cpp` | 100.00% |
| `tools/server/server-cache-controller.h` | 100.00% |
| `tools/server/server-cache-legacy.h` | 100.00% |
| `tools/server/server-cache-hybrid.h` | 91.18% |
| `tools/server/server-cache-controller.cpp` | 83.33% |
| `tools/server/server-cache-hybrid.cpp` | 53.80% |
| `tools/server/server-task.h` | 45.75% |

Interpretation:

- Focused coverage is now measurable and useful for this corrective pass.
- `server-cache-hybrid.cpp` remains below the desired 80% because model-backed `save_slot()` and `load_slot()` paths are not exercised by the unit test.
- `server-task.h` includes broad task code beyond prepared-prompt metadata, which lowers its file-level line rate.

Next coverage targets:

1. Add a model-backed hybrid save/load integration test to cover `save_slot()` and `load_slot()`.
2. Add target-plus-draft restore tests to cover paired restore failure and success.
3. Consider narrowing future coverage gates to the cache-controller files or adding separate coverage groups for metadata, lookup, and runtime restore.

## Coverage improvement pass

Date: 2026-05-24

Status: complete for the low-coverage files called out by OpenCppCoverage.

### Changes made

Added focused unit tests for previously uncovered cache and task inline paths:

- hybrid LRU eviction by token limit
- protected-entry skip and all-protected fallback eviction
- namespace miss lookup
- empty-request lookup
- LRU index update through a debug helper
- `server_task` inline helper methods
- base/final/partial/error task-result inline methods
- `server_prompt_data` and `server_prompt` inline helpers

Added limited test/debug helpers to `hybrid_cache_controller` so pure lookup and index behavior can be tested without a llama model context:

- `debug_add_entry_for_tests(server_tokens, bool protected_root, const std::string & namespace_id)`
- `debug_find_match_tokens_for_tests(const server_tokens &)`
- `debug_entry_count_for_tests()`
- `debug_mark_first_entry_used_for_tests()`

These helpers are for pure controller/index coverage only. They do not replace model-backed restore tests.

