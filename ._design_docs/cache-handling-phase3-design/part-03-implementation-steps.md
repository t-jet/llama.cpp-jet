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
3. **[Architecture Update]** Update `create_cache_controller()` factory to accept `common_params` reference
4. **[Architecture Update]** Update `hybrid_cache_controller` constructor to accept and store `common_params` reference
5. Implement `compute_namespace_id()` method (no-argument version)
6. Implement `compute_namespace_id(metadata)` method (metadata-aware version, uses comprehensive key)
7. Implement `build_compatibility_key()` using `params` member for full 14-field population
8. Implement `find_exact_match()` helper for deduplication
9. Implement `update_lru_index()` helper for atomic LRU updates
10. **[Degraded Metadata Marker]** Add `boundaries_native` flag to `prepared_prompt_metadata`
11. **[Degraded Metadata Marker]** Set `metadata.degraded_reason = "inferred_from_rendered_text"` in current boundary extraction code

**Files Modified**:

- `tools/server/server-task.h` (add compatibility_key field, boundaries_native flag, degraded_reason field)
- `tools/server/server-cache-controller.h` (update factory signature)
- `tools/server/server-cache-controller.cpp` (pass params to constructors)
- `tools/server/server-cache-hybrid.h` (add params member, method declarations, comprehensive key structure from Gap 2.2)
- `tools/server/server-cache-hybrid.cpp` (update constructor, add method implementations with full params access)
- `tools/server/server-cache-legacy.h` (update constructor signature for consistency)
- `tools/server/server-cache-legacy.cpp` (update constructor signature for consistency)
- `tools/server/server-context.cpp` (pass params_base to cache controller creation, mark current boundary extraction as degraded)

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

---

## Addendum: Production Integration Approach

**Added**: May 26, 2026  
**Status**: Implementation Complete

### Overview

During production integration, the implementation followed the design steps but required additional integration points beyond the `save_slot()` and `load_slot()` methods themselves. This addendum documents the actual production integration approach.

### Integration Point 1: Save Triggers After Completion

**Design Assumption**: The design assumed `save_slot()` would be called as part of the normal slot lifecycle.

**Production Reality**: Explicit save triggers were required after completion responses to capture finalized slot state.

**Implementation**:

Two save trigger locations in `server-context.cpp`:

1. **Normal completion path** (line ~3608): After `send_final_response()` and before `slot.release()`
2. **Speculative decoding path** (line ~3728): After `send_final_response()` and before `slot.release()`

**Code Pattern**:
```cpp
slot.print_timings();
send_final_response(slot);
metrics.on_prediction(slot);

// Save to hybrid cache after successful completion
if (cache_ctrl && slot.task->type == SERVER_TASK_TYPE_COMPLETION) {
    cache_ctrl->save_slot(slot, slot.prompt_metadata);
}

slot.release();
```

**Rationale**:
- Placement ensures slot state is complete and stable
- Conditional logic restricts to hybrid mode completion tasks only
- `save_slot()` internally handles mode differentiation (hybrid vs legacy)
- No explicit error handling needed (save_slot() logs internally)

### Integration Point 2: Non-Destructive Load Mechanism

**Design Assumption**: The design described `load_slot()` as the primary load mechanism.

**Production Reality**: A separate non-destructive method was required because `load_slot()` was being called in a legacy FIFO context that destructively cleared slots.

**Implementation**:

Added `try_restore_from_cache()` method to provide non-destructive cache lookup:

**Purpose**: Lookup and restore cache entry without modifying slot state on miss.

**Location**: `server-context.cpp` lines ~5332-5450

**Key Differences from `load_slot()`**:
1. **Non-destructive**: Returns false on miss without clearing slot
2. **Task-based**: Takes `task` parameter with tokens and metadata, not slot state
3. **Explicit namespace check**: Validates namespace_id before restoration
4. **Separate from legacy flow**: Called in hybrid-specific code path only

### Integration Point 3: Separated Code Paths in get_available_slot()

**Design Assumption**: Cache lookup would happen uniformly across modes.

**Production Reality**: Legacy FIFO cache pattern (save → clear → load) conflicts fundamentally with hybrid non-destructive semantics.

**Implementation**:

Separated code paths in `get_available_slot()` (lines ~1465-1505):

**Hybrid Mode Path**:
```cpp
if (cache_ctrl && cache_mode_active == CACHE_MODE_HYBRID 
    && task.type == SERVER_TASK_TYPE_COMPLETION) {
    
    // Try non-destructive restore
    if (cache_ctrl->try_restore_from_cache(*ret, task)) {
        // Cache hit - slot restored
    } else {
        // Cache miss - clear only if slot has old content
        if (!ret->prompt.tokens.empty()) {
            ret->prompt_clear(false);
        }
    }
    
    cache_ctrl->update();
}
```

**Legacy Mode Path** (preserved unchanged):
```cpp
else if (update_cache && cache_mode_active != CACHE_MODE_HYBRID) {
    // Legacy: destructive save/load cycle
    if (tokens.size() > 0) {
        if (cache_ctrl->save_slot(*ret, ret->prompt_metadata)) {
            ret->prompt_clear(false);  // Destructive clear
        }
    }
    
    if (!cache_ctrl->load_slot(*ret, task)) {
        ret->prompt_clear(false);
    }
    
    cache_ctrl->update();
}
```

**Rationale**:
- Clear conditional branching prevents mode conflicts
- Non-destructive semantics preserved for hybrid mode
- Legacy behavior unchanged for backward compatibility
- Each path handles its own timing and logging

### Architecture Compliance

This production approach fully complies with Architecture Part 2 requirements:

1. **Non-Destructive Reuse**: Slot state preserved on miss, only cleared if needed
2. **Namespace Validation**: Explicit check in `try_restore_from_cache()`
3. **Separated Code Paths**: Clear conditional prevents legacy/hybrid conflicts
4. **Proper Integration Point**: Load happens before slot initialization, not after destructive operations

### Lessons Learned

1. **Integration points matter**: Well-designed methods still need explicit integration into request flow
2. **Legacy compatibility**: Existing patterns may conflict with new semantics - separation is required
3. **Non-destructive semantics**: Requires explicit support throughout the call chain, not just in cache methods
4. **Explicit save triggers**: Cannot rely on implicit lifecycle hooks for critical operations

### Impact on Design Steps

The six-step implementation workflow remains valid, but Step 3.6 (End-to-End Validation) should explicitly include:

- **Save trigger integration**: Identify and instrument completion paths
- **Load mechanism integration**: Ensure lookup happens before slot initialization  
- **Code path separation**: Verify legacy and hybrid modes don't interfere
- **Non-destructive verification**: Confirm slot state preserved on cache miss

These integration tasks are distinct from implementing the `save_slot()` and `load_slot()` methods themselves.

