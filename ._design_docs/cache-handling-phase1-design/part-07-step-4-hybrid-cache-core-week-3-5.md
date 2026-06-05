# Phase 1 Implementation Design: Alternate Hybrid Cache Mode - Part 7: Step 4: Hybrid Cache Core (Week 3-5)

Source: [../cache-handling-phase1-design.md](../cache-handling-phase1-design.md)

### Step 4: Hybrid Cache Core (Week 3-5)

**Goal**: Implement hybrid cache controller

1. Create `server-cache-hybrid.h` with `hybrid_cache_entry` and `hybrid_cache_controller`
2. Implement non-destructive `save_slot()` (copy instead of move)
3. Implement `load_slot()` with prefix matching
4. Implement basic `find_best_match()` (Phase 1: token-based only)
5. Add unit tests for non-destructive behavior

**Deliverable**: Hybrid mode compiles and passes basic cache tests

### Step 5: LRU Eviction (Week 5-6)

**Goal**: Replace FIFO with LRU

1. Add `last_used_time` and `use_count` to `hybrid_cache_entry`
2. Implement `mark_used()` to update access times
3. Implement `evict_lru()` to remove least recently used entry
4. Implement `calculate_total_size()` and `calculate_total_tokens()`
5. Test eviction behavior under memory pressure

**Deliverable**: LRU eviction works correctly

### Step 6: Protected Roots (Week 6-7)

**Goal**: Add protection mechanism

1. Add `protected_root` flag to `hybrid_cache_entry`
2. Implement `should_protect()` logic
3. Update `evict_lru()` to skip protected entries
4. Add API or config for marking entries as protected
5. Test protection behavior

**Deliverable**: Protected entries are not evicted

### Step 7: Integration and Testing (Week 7-8)

**Goal**: Full integration and validation

1. Update all call sites in `server_context_impl`
2. Add integration tests comparing legacy vs. hybrid modes
3. Add stress tests for memory limits
4. Add performance benchmarks
5. Document behavior differences

**Deliverable**: Phase 1 fully integrated and tested

### Step 8: Observability (Week 8)

**Goal**: Add diagnostics and metrics

1. Implement `get_stats()` for both controllers
2. Add cache metrics to `/health` endpoint
3. Add diagnostic logging for cache decisions
4. Add performance timing for cache operations
5. Document metrics and logging

**Deliverable**: Observable cache behavior

---

## Testing Strategy

### Unit Tests

**File**: `tests/test-cache-controller.cpp` (new)

```cpp
// Test mode selection
void test_cache_mode_selection();

// Test legacy wrapper matches existing behavior
void test_legacy_wrapper_compatibility();

// Test hybrid non-destructive hits
void test_hybrid_non_destructive();

// Test LRU eviction order
void test_hybrid_lru_eviction();

// Test protected roots
void test_hybrid_protected_roots();

// Test boundary metadata structures
void test_boundary_metadata();
```

### Integration Tests

**File**: `tests/test-server-cache-integration.cpp` (new)

```cpp
// Test cache across multiple requests
void test_multi_request_cache_reuse();

// Test cache hit/miss behavior
void test_cache_hit_miss_tracking();

// Test eviction under memory pressure
void test_cache_memory_limits();

// Test target/draft pairing preservation
void test_target_draft_coupling();
```

### Regression Tests

- Verify legacy mode matches current behavior exactly
- Test all existing cache-related server tests in both modes
- Verify idle slot caching works in both modes
- Test speculative decoding with cache enabled

### Performance Tests

- Measure cache hit rate on typical workloads
- Compare legacy vs. hybrid performance
- Measure memory usage patterns
- Test scalability with large caches

### Line Coverage Reporting

Use OpenCppCoverage for Windows/MSVC line coverage. Build the focused test target in Debug so PDB symbols are available:

```powershell
cmake -S . -B build-coverage -DLLAMA_BUILD_TESTS=ON -DBUILD_SHARED_LIBS=OFF
cmake --build build-coverage --config Debug --target test-cache-controller
```

For Phase 1 evidence, prefer the focused cache report:

```powershell
D:\app\OpenCppCoverage\OpenCppCoverage.exe `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-hybrid.cpp `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-hybrid.h `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-controller.cpp `
  --sources D:\source\llama.cpp-jet\tools\server\server-cache-controller.h `
  --sources D:\source\llama.cpp-jet\tools\server\server-task.h `
  --sources D:\source\llama.cpp-jet\tests\test-cache-controller.cpp `
  --export_type html:D:\source\llama.cpp-jet\build-coverage\coverage-cache-html `
  --export_type cobertura:D:\source\llama.cpp-jet\build-coverage\coverage-cache.xml `
  -- D:\source\llama.cpp-jet\build-coverage\bin\Debug\test-cache-controller.exe
```

For broader context, also capture the full `tools/server` and `tests` report:

```powershell
D:\app\OpenCppCoverage\OpenCppCoverage.exe `
  --sources D:\source\llama.cpp-jet\tools\server `
  --sources D:\source\llama.cpp-jet\tests `
  --excluded_sources D:\source\llama.cpp-jet\build-coverage `
  --export_type html:D:\source\llama.cpp-jet\build-coverage\coverage-html `
  --export_type cobertura:D:\source\llama.cpp-jet\build-coverage\coverage.xml `
  -- D:\source\llama.cpp-jet\build-coverage\bin\Debug\test-cache-controller.exe
```

Document the HTML path, Cobertura XML path, total line rate, and per-file line rates in the verification report. Do not count broad server coverage as a Phase 1 failure when only the cache-controller unit test is being run; use it to identify the next tests to add.

---

## Migration Path

### Phase 1 Deployment

1. **Default to legacy mode** for backward compatibility
2. Provide `--cache-mode hybrid` for early adopters
3. Document differences and known limitations
4. Gather feedback on hybrid mode behavior

### Future Phases

- **Phase 2**: Shared branch graphs, checkpoint-first restore
- **Phase 3**: Cold layer storage, metadata-only nodes

### Deprecation Plan (Post-Phase 3)

Once hybrid mode is proven stable and superior:
1. Change default to `--cache-mode hybrid`
2. Deprecate `--cache-mode legacy` with warning
3. Eventually remove legacy implementation

---

## Multi-Namespace Operation in Phase 1

### Overview

Phase 1 implements basic multi-namespace support to enable concurrent operation of different models or configurations, consistent with the architecture document's multi-namespace requirements.

### Key Design Decisions

**Namespace Identification**:
- Each cache entry is tagged with a `namespace_id` computed from model identity and runtime configuration
- Namespace ID is a hash of: target model descriptor, draft model descriptor (if any), and material runtime modifiers
- Phase 1 uses a simple string hash; Phase 2+ may use structured namespace keys

**Shared Global Budgets**:
- All namespaces share the single configured RAM budget (no per-namespace quotas)
- Budget accounting is global across all active namespaces
- This matches the architecture's "shared budget model" requirement

**Global LRU Eviction**:
- Eviction policy operates globally: the least-recently-used entry is evicted regardless of which namespace owns it
- Protected roots from all namespaces compete equally for retention
- No namespace-based fairness or affinity in Phase 1
- This matches the architecture's "global eviction policy" requirement

**Namespace Isolation**:
- Lookup (`find_best_match`) filters candidates by namespace ID before prefix matching
- Cross-namespace cache hits are forbidden (entries from different namespaces are skipped)
- Each namespace maintains logically independent cache state within the shared entry list
- This matches the architecture's "cross-namespace behavior" requirement

### Operational Implications

**Multi-Model Scenarios**:
- Loading multiple models simultaneously consumes budget proportional to their combined working sets
- If one model's workload dominates, it may evict entries from less-active models
- Operators should configure budgets accounting for the expected number of concurrent models

**Future Extensions** (Deferred beyond Phase 1):
- Per-namespace budget quotas
- Namespace-aware fairness policies (e.g., fair-share scheduling)
- Namespace priority weights
- Detailed per-namespace metrics and observability

### Example Scenarios

**Scenario 1: Single Model**
- Server loads one model
- All cache entries belong to that model's namespace
- Behaves like single-namespace cache (no cross-namespace concerns)

**Scenario 2: Target + Draft**
- Target and draft models create a single namespace (paired configuration)
- Cache entries are tagged with the paired namespace ID
- Switching draft models creates a new namespace (no cross-restore)

**Scenario 3: Multiple Models**
- Server loads model A and model B (e.g., different quantizations or architectures)
- Each model gets its own namespace
- Global LRU may evict model A's entries when model B is heavily used
- Protected roots can help preserve important entries from both models

