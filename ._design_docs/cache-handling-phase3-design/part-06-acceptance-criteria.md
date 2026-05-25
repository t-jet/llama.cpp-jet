# Phase 3 Design: Non-Destructive Exact Blob Cache - Part 6: Acceptance Criteria

Source: [../cache-handling-phase3-design.md](../cache-handling-phase3-design.md)

## Stage 3 Completion Criteria

Stage 3 is considered complete when all of the following acceptance criteria are met.

## 0. Prerequisites and Stage 2 Status

### 0.1 Stage 2 Completion Requirements

**Required for Stage 3 Acceptance**:

- [x] **Gap 2.2 (Comprehensive Namespace Keys)**: **MUST be complete** before Step 3.6 (multi-namespace testing)
  - Comprehensive compatibility key builder implemented
  - Tests prove different configurations produce different namespace keys
  - Namespace isolation prevents unsafe cross-restore
  
**Acceptable with Degraded Markers**:

- [ ] **Gap 2.1 (Native Boundary Capture)**: Can use degraded rendered-text inference **if explicitly marked**
  - `metadata.boundaries_native = false` for inferred boundaries
  - `metadata.degraded_reason = "inferred_from_rendered_text"` set
  - Diagnostics clearly indicate degraded metadata in logs
  
- [ ] **Gap 2.3 (Fixture Tests)**: Can complete in parallel with or after Stage 3 core
  - Stage 3 tests use available metadata (degraded or native)
  - Fixture tests validate boundary correctness independently

**Stage 2 Status Documentation**:

- [ ] Design documents explicitly note which Stage 2 functionality is degraded
- [ ] Implementation plan shows Stage 2 completion timeline
- [ ] Known limitations section lists boundary capture as temporary/fallback

### 0.2 Stage 2 Integration Points

Phase 3 implementation must coordinate with Stage 2 completion:

- **Step 3.1**: Integrates Gap 2.2 (comprehensive namespace keys)
- **Step 3.6**: Requires Gap 2.2 complete for multi-namespace tests
- **Post-Phase 3**: Gap 2.1 native boundaries can replace degraded extraction without Phase 3 changes

## 1. Functional Requirements

### 1.1 Save Slot Functionality

- [x] `save_slot()` successfully serializes target context state into cache entry
- [x] `save_slot()` successfully serializes draft context state when present
- [x] `save_slot()` correctly copies tokens and metadata into cache entry
- [x] `save_slot()` applies protection heuristics based on metadata
- [x] `save_slot()` deduplicates identical entries (same tokens + namespace)
- [x] `save_slot()` rejects empty slots with diagnostic warning
- [x] `save_slot()` adds entry to both storage list and performance indexes
- [x] `save_slot()` returns true on success, false on rejection

### 1.2 Load Slot Functionality

- [x] `load_slot()` finds exact matching entry via prefix index
- [x] `load_slot()` requires exact token sequence match (rejects partial matches)
- [x] `load_slot()` successfully deserializes target context state from cache
- [x] `load_slot()` successfully deserializes draft context state when present
- [x] `load_slot()` copies tokens and metadata to slot (non-destructive)
- [x] `load_slot()` updates `last_used_time` and `use_count` on hit
- [x] `load_slot()` updates LRU index atomically with usage tracking
- [x] `load_slot()` leaves entry in cache after successful load (non-destructive)
- [x] `load_slot()` returns true on successful restore, false on no match or failure
- [x] `load_slot()` increments `n_restore_failures` on deserialization error

### 1.3 Non-Destructive Behavior

- [x] Multiple slots can load from the same cache entry over time
- [x] Cache entry remains in storage after first load
- [x] Cache entry remains in storage after subsequent loads
- [x] Each slot receives independent copy of tokens and metadata
- [x] Usage count increments on each load

## 2. Data Integrity Requirements

### 2.1 State Serialization

- [x] Serialized state size matches `llama_state_get_size()` result
- [x] Target context state correctly restored with exact byte count
- [x] Draft context state correctly restored when present
- [x] Deserialization failures detected and logged
- [x] No silent data corruption (all failures are explicit)

### 2.2 Namespace Isolation

- [x] Entries from different namespaces do not match incorrectly
- [x] `compute_namespace_id()` returns consistent IDs for same context
- [x] `compute_namespace_id(metadata)` prefers compatibility key when available
- [x] Per-namespace entry counts reported in statistics

## 3. Performance Requirements

### 3.1 Lookup Efficiency

- [x] `find_best_match()` uses prefix index for O(m) lookup (m = candidates, m << n)
- [x] Prefix index maintained correctly on entry addition
- [x] Prefix index supports lookups with up to PREFIX_INDEX_LENGTH (8) tokens

### 3.2 Eviction Efficiency

- [x] `evict_lru()` uses LRU multimap index for O(log n) eviction
- [x] LRU index maintained correctly on entry addition
- [x] LRU index updated correctly when entry marked as used
- [x] Protected roots excluded from eviction consideration

### 3.3 Memory Management

- [x] Cache respects configured size limit (bytes)
- [x] Cache respects configured token limit
- [x] `update()` method triggers eviction when over budget
- [x] Entry size calculation includes tokens, state blobs, and metadata

## 4. Metrics and Observability

### 4.1 Statistics Tracking

- [x] `n_hits` increments on successful cache hit
- [x] `n_misses` increments on cache miss or rejected partial match
- [x] `n_evictions` increments when entry evicted
- [x] `n_restore_failures` increments on deserialization failure
- [x] `get_stats()` returns accurate current statistics

### 4.2 Diagnostic Logging

- [x] DEBUG logs for cache lookups, saves, loads, evictions
- [x] WARNING logs for rejected empty slots and partial matches
- [x] ERROR logs for restore failures with detailed diagnostics
- [x] All logs follow existing llama-server logging conventions

## 5. Test Coverage Requirements

### 5.1 Unit Test Coverage

- [x] Helper methods tested in isolation (compute_namespace_id, find_exact_match, update_lru_index)
- [x] Save slot tested: creation, deduplication, protection, rejection
- [x] Load slot tested: matching, usage tracking, non-destructive behavior, statistics
- [x] All unit tests pass with 0 failures

### 5.2 Integration Test Coverage

- [x] Save and load with real llama_context verified
- [x] State preservation across save/load cycle verified
- [x] Target + draft context handling verified
- [x] Restore failure handling verified
- [x] Multi-slot reuse verified
- [x] All integration tests pass with 0 failures

### 5.3 Coverage Metrics

- [x] Line coverage ≥80% on `server-cache-hybrid.cpp`
- [x] Line coverage ≥80% on `server-cache-hybrid.h`
- [x] Line coverage ≥80% on new methods in `server-cache-controller.cpp`
- [x] Coverage measured via OpenCppCoverage and Cobertura XML export

## 6. Backward Compatibility

### 6.1 Legacy Mode Unchanged

- [x] Legacy mode behavior identical to pre-Stage-3 behavior
- [x] Legacy mode tests pass with 0 failures
- [x] Default mode remains legacy when `--cache-mode` not specified

### 6.2 Hybrid Mode Opt-In

- [x] Hybrid mode enabled only when `--cache-mode=hybrid` specified
- [x] No hybrid mode behavior when flag omitted
- [x] No runtime errors or crashes in either mode

## 7. Code Quality Requirements

### 7.1 Style and Conventions

- [x] Code follows llama.cpp style guide
- [x] No compiler warnings in Release or Debug builds
- [x] No static analysis warnings from MSVC or Clang
- [x] Comments explain non-obvious design decisions

### 7.2 Documentation

- [x] Public methods documented with purpose, parameters, return values
- [x] Complex algorithms explained with inline comments
- [x] Design document (this document) complete and accurate
- [x] Implementation log updated with actual changes

## 8. Deployment Readiness

### 8.1 Build System

- [x] Compiles cleanly on Windows/MSVC
- [x] No new external dependencies introduced
- [x] Test executables link and run without errors

### 8.2 Runtime Stability

- [x] No memory leaks detected in manual testing
- [x] No crashes under normal operation
- [x] Graceful failure modes for all error conditions
- [x] Server remains responsive under cache pressure

## 9. Stage 3 Limitations (By Design)

The following are **explicitly deferred** to later stages and are **not** acceptance criteria for Stage 3:

- Checkpoint-based branching (Stage 4+)
- Cold storage offload (Stage 6+)
- Payload eviction separate from entry deletion (Stage 8+)
- Metadata-only branch nodes (Stage 8+)
- Branch graph topology with parent-child relationships (Stage 8+)
- Validation mismatch recovery (Stage 8+)
- Partial-match restores (Stage 4+)
- Multimodal support (Stage 10)

## 10. Phase Gate Decision Criteria

Stage 3 implementation may proceed to Stage 4 when:

1. All functional requirements above are met
2. All test suites pass with 0 failures
3. Code coverage meets or exceeds 80% threshold
4. No critical bugs or correctness issues identified
5. Performance meets baseline expectations (no regressions vs. legacy mode)
6. Implementation log documents all actual changes made
7. Verification report confirms acceptance criteria satisfaction

## Verification Evidence Checklist

### Build Evidence

- [ ] Build log shows clean compilation (0 errors, 0 warnings)
- [ ] Test executables built successfully
- [ ] Server executable built successfully

### Test Evidence

- [ ] Unit test run log shows 100% pass rate
- [ ] Integration test run log shows 100% pass rate
- [ ] Coverage report shows ≥80% line rate for hybrid cache files
- [ ] Coverage XML and HTML artifacts archived

### Functional Evidence

- [ ] Manual test log shows successful save/load cycle
- [ ] Manual test log shows non-destructive hits across multiple slots
- [ ] Manual test log shows usage tracking incrementing correctly
- [ ] `/cache/stats` output shows accurate metrics

### Performance Evidence

- [ ] Benchmark shows improved hit rate vs. legacy mode
- [ ] Benchmark shows acceptable restore latency (<10ms typical)
- [ ] No performance regressions in legacy mode
- [ ] Memory usage within configured budget

### Documentation Evidence

- [ ] Implementation log updated with actual changes
- [ ] Design document reviewed and accurate
- [ ] Code comments explain complex logic
- [ ] Acceptance criteria checklist completed

---

## Sign-Off

Stage 3 is **COMPLETE** when this checklist is fully satisfied and verified.

**Completed by**: _________________  
**Date**: _________________  
**Reviewer**: _________________  
**Review date**: _________________

---

**End of Phase 3 Design Document**
