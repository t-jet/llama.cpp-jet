# Phase 3 Design: Non-Destructive Exact Blob Cache - Part 3: Implementation Steps

Source: [../cache-handling-phase3-design.md](../cache-handling-phase3-design.md)

## Implementation Workflow

Stage 3 should be implemented in six incremental steps, each producing a testable checkpoint.

**Parallel Work Note**: While implementing Stage 3 core functionality, Stage 2 completion work proceeds in parallel (see [Part 1: Stage 2 Completion Requirements](./part-01-overview-and-objectives.md#stage-2-completion-requirements)). Specifically:

- **Gap 2.2 (Comprehensive namespace keys)** should complete **before or during Step 3.1** to provide proper namespace isolation
- **Gap 2.3 (Fixture tests)** can proceed independently and validates boundary correctness
- **Gap 2.1 (Native boundary capture)** can complete any time before final Phase 3 integration

Until native boundary capture is ready, Phase 3 uses degraded metadata with explicit markers (see Step 3.1 below).

### Step 3.1: Add Helper Methods and Data Structures

**Objective**: Establish foundation for save/load implementation

**Parallel Stage 2 Work**: This step should coordinate with **Gap 2.2 (Comprehensive Namespace Compatibility Keys)** implementation. The `compatibility_key` field added here will be populated by the comprehensive key builder from Gap 2.2.

**Tasks**:

1. Add `compatibility_key` field to `prepared_prompt_metadata` in `server-task.h`
2. **[Gap 2.2 Integration]** Implement comprehensive namespace key builder (see Part 1, Gap 2.2 for design)
3. Implement `compute_namespace_id()` method (no-argument version)
4. Implement `compute_namespace_id(metadata)` method (metadata-aware version, uses comprehensive key)
5. Implement `find_exact_match()` helper for deduplication
6. Implement `update_lru_index()` helper for atomic LRU updates
7. **[Degraded Metadata Marker]** Add `boundaries_native` flag to `prepared_prompt_metadata`
8. **[Degraded Metadata Marker]** Set `metadata.degraded_reason = "inferred_from_rendered_text"` in current boundary extraction code

**Files Modified**:

- `tools/server/server-task.h` (add compatibility_key field, boundaries_native flag, degraded_reason field)
- `tools/server/server-cache-hybrid.h` (add method declarations, comprehensive key structure from Gap 2.2)
- `tools/server/server-cache-hybrid.cpp` (add method implementations)
- `tools/server/server-context.cpp` (mark current boundary extraction as degraded)

**Test Coverage**:

- Unit test: `compute_namespace_id()` returns consistent values for same context
- Unit test: `compute_namespace_id(metadata)` prefers metadata key over context pointer
- Unit test: Comprehensive namespace key components produce different keys (from Gap 2.2 tests)
- Unit test: `find_exact_match()` finds exact token sequence matches
- Unit test: `find_exact_match()` respects namespace boundaries
- Unit test: `update_lru_index()` atomically updates multimap
- Unit test: Degraded metadata properly marked

**Exit Criteria**:

- All helper methods compile without warnings
- Unit tests pass at 100%
- Comprehensive namespace keys prevent unsafe cross-restore (Gap 2.2 acceptance criteria met)
- Degraded metadata explicitly marked and visible in diagnostics
- No behavioral changes to existing code
- Code follows llama.cpp style conventions

---

### Step 3.2: Implement `save_slot()` Without State Serialization

**Objective**: Implement cache entry creation and deduplication logic

**Tasks**:

1. Replace `save_slot()` placeholder with real implementation
2. Validate slot has content to save
3. Create `hybrid_cache_entry` with tokens, metadata, namespace
4. Apply protection heuristics based on metadata
5. Check for existing entry via `find_exact_match()`
6. Add new entry to storage and indexes
7. Skip state serialization temporarily (leave `data.main` and `data.drft` empty)

**Files Modified**:

- `tools/server/server-cache-hybrid.cpp` (replace save_slot implementation)

**Test Coverage**:

- Unit test: `save_slot()` creates entry with correct tokens
- Unit test: `save_slot()` deduplicates identical token sequences
- Unit test: `save_slot()` applies protected_root flag correctly
- Unit test: `save_slot()` adds entry to both storage and indexes
- Unit test: `save_slot()` returns false for empty slots

**Exit Criteria**:

- `save_slot()` creates and indexes entries correctly
- Deduplication works as expected
- No state serialization yet (intentional)
- All tests pass

---

### Step 3.3: Add State Serialization to `save_slot()`

**Objective**: Complete save path with full context state capture

**Tasks**:

1. Add target context serialization using `llama_state_get_size()` and `llama_state_get_data()`
2. Add draft context serialization (if `ctx_dft` exists)
3. Add error handling for serialization failures
4. Add diagnostic logging for saved state size

**Files Modified**:

- `tools/server/server-cache-hybrid.cpp` (extend save_slot implementation)

**Test Coverage**:

- Integration test: Save slot with target context, verify state blob size > 0
- Integration test: Save slot with target+draft contexts, verify both blobs populated
- Integration test: Save slot without contexts, verify graceful handling
- Manual test: Compare saved state size against `llama_state_get_size()` result

**Exit Criteria**:

- State serialization produces non-empty data blobs
- Draft context handled correctly when present
- Error paths log diagnostics
- Integration tests pass with real llama_context

---

### Step 3.4: Implement `load_slot()` Without State Restoration

**Objective**: Implement matching and usage tracking logic

**Tasks**:

1. Replace `load_slot()` placeholder with real implementation
2. Call `find_best_match()` to locate candidate entry
3. Validate match quality (require exact match in Stage 3)
4. Copy tokens and metadata to slot
5. Update usage tracking via `mark_used()` and `update_lru_index()`
6. Skip state restoration temporarily
7. Update hit/miss statistics

**Files Modified**:

- `tools/server/server-cache-hybrid.cpp` (replace load_slot implementation)

**Test Coverage**:

- Unit test: `load_slot()` finds exact match via prefix index
- Unit test: `load_slot()` rejects partial matches
- Unit test: `load_slot()` updates `last_used_time` and `use_count`
- Unit test: `load_slot()` increments `n_hits` on match
- Unit test: `load_slot()` increments `n_misses` on no match
- Unit test: `load_slot()` updates LRU index atomically

**Exit Criteria**:

- Match finding works correctly
- Usage tracking updates as expected
- Non-destructive behavior verified (entry stays in cache)
- Multiple slots can load from same entry
- All unit tests pass

---

### Step 3.5: Add State Restoration to `load_slot()`

**Objective**: Complete load path with full context state restoration

**Tasks**:

1. Add target context restoration using `llama_state_set_data()`
2. Validate restored byte count matches expected size
3. Add draft context restoration (if `data.drft` present)
4. Add error handling for restoration failures
5. Increment `n_restore_failures` on errors
6. Add diagnostic logging for restore operations

**Files Modified**:

- `tools/server/server-cache-hybrid.cpp` (extend load_slot implementation)

**Test Coverage**:

- Integration test: Save and load same slot, verify tokens match
- Integration test: Save slot A, load into slot B, verify independent state
- Integration test: Restore target context, verify byte count equals saved size
- Integration test: Restore target+draft, verify both contexts restored
- Integration test: Simulate restore failure, verify graceful error handling
- Integration test: Load same entry twice, verify usage count increments

**Exit Criteria**:

- State restoration produces correct byte counts
- Restored contexts behave correctly in inference
- Error paths fail explicitly with diagnostics
- Multiple slots can restore from same cached entry
- Integration tests pass with real llama_context

---

### Step 3.6: End-to-End Validation and Metrics

**Objective**: Validate complete save/load cycle and verify metrics

**Tasks**:

1. Run end-to-end integration test: save slot → load slot → verify inference correctness
2. Verify metrics in `get_stats()`: hits, misses, evictions, restore_failures
3. Verify LRU eviction respects `protected_root` flag
4. Verify budget enforcement triggers eviction when limits exceeded
5. Run performance benchmark: measure hit rate and restore latency
6. Compare legacy vs. hybrid mode behavior side-by-side

**Files Modified**:

- None (validation only)

**Test Coverage**:

- End-to-end test: Complete chat request using hybrid cache
- End-to-end test: Multi-turn conversation reusing cached prompt
- Benchmark: Measure cache hit rate for repeated prompts
- Benchmark: Measure restore latency vs. fresh context creation
- Integration test: Verify legacy mode unchanged when `--cache-mode=legacy`

**Exit Criteria**:

- End-to-end inference produces correct results
- Metrics accurately reflect cache behavior
- Performance meets baseline expectations (no regressions)
- Hybrid mode demonstrably improves hit rate vs. legacy
- All acceptance criteria met (see Part 6)

---

## Build and Test Commands

### Compile Implementation

```powershell
cmake -S . -B build-phase3 -DLLAMA_BUILD_TESTS=ON -DBUILD_SHARED_LIBS=OFF
cmake --build build-phase3 --config Release --target test-cache-controller
cmake --build build-phase3 --config Release --target llama-server
```

### Run Unit Tests

```powershell
ctest --test-dir build-phase3 -C Release -R test-cache-controller --output-on-failure
```

### Run Coverage Analysis

```powershell
cmake --build build-coverage --config Debug --target test-cache-controller

D:\app\OpenCppCoverage\OpenCppCoverage.exe `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-hybrid.cpp `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-hybrid.h `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-controller.cpp `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-controller.h `
  --sources D:\source\llama.cpp-jet\tools\server\server-task.h `
  --sources D:\source\llama.cpp-jet\tests\test-cache-controller.cpp `
  --export_type html:D:\source\llama.cpp-jet\build-coverage\coverage-phase3-html `
  --export_type cobertura:D:\source\llama.cpp-jet\build-coverage\coverage-phase3.xml `
  -- D:\source\llama.cpp-jet\build-coverage\bin\Debug\test-cache-controller.exe
```

### Verify Coverage Meets Target

```powershell
# Parse coverage XML for line rate
[xml]$coverage = Get-Content "build-coverage\coverage-phase3.xml"
$lineRate = [double]$coverage.coverage.'line-rate'
$percentage = $lineRate * 100

Write-Host "Coverage: $percentage%"
if ($percentage -lt 80.0) {
    Write-Error "Coverage below 80% threshold"
    exit 1
}
```

---

**Next**: [Part 4: Test Specifications](./part-04-test-specifications.md)
