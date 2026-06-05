# Phase 2 Implementation Design: Completing Architecture Stages 1-2 - Part 10: 2. Multi-Slot Concurrency

Source: [../cache-handling-phase2-design.md](../cache-handling-phase2-design.md)

#### 2. Multi-Slot Concurrency

```cpp
TEST_CASE("multi_slot_concurrent_cache_access") {
    // Setup with multiple slots
    common_params params;
    params.cache_mode_val = CACHE_MODE_HYBRID;
    params.n_parallel = 4;
    
    server_context ctx;
    ctx.load_model(params);
    
    // Process multiple requests concurrently
    std::vector<std::future<response>> futures;
    
    for (int i = 0; i < 10; i++) {
        json req = create_test_request();
        futures.push_back(std::async([&ctx, req]() {
            return ctx.process_request(req);
        }));
    }
    
    // Wait for all
    for (auto & fut : futures) {
        auto resp = fut.get();
        REQUIRE(resp.success);
    }
    
    // Verify no corruption
    auto stats = ctx.get_cache_stats();
    REQUIRE(stats.n_save_failures == 0);
    REQUIRE(stats.n_load_failures == 0);
}
```

### Performance Benchmarks

```cpp
BENCHMARK("hybrid_cache_save_100_entries") {
    hybrid_cache_controller ctrl(2000_MB, 100000, ctx, nullptr);
    
    for (int i = 0; i < 100; i++) {
        server_slot slot;
        slot.cache_tokens = generate_random_tokens(1000);
        ctrl.save_slot(slot);
    }
};

BENCHMARK("hybrid_cache_lookup_hits") {
    hybrid_cache_controller ctrl(2000_MB, 100000, ctx, nullptr);
    
    // Prepopulate
    std::vector<server_tokens> stored;
    for (int i = 0; i < 100; i++) {
        server_slot slot;
        slot.cache_tokens = generate_random_tokens(1000);
        stored.push_back(slot.cache_tokens);
        ctrl.save_slot(slot);
    }
    
    // Benchmark lookups
    for (const auto & tokens : stored) {
        server_slot slot;
        ctrl.load_slot(slot, tokens);
    }
};
```

### Line Coverage Reporting

Phase 2 requires a measurable line-coverage report, not only a successful build. On Windows/MSVC, use OpenCppCoverage against a Debug build of the focused cache tests.

Build the coverage target:

```powershell
cmake -S . -B build-coverage -DLLAMA_BUILD_TESTS=ON -DBUILD_SHARED_LIBS=OFF
cmake --build build-coverage --config Debug --target test-cache-controller
```

Run the focused cache coverage report:

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

Run the broad server/test coverage report for context:

```powershell
D:\app\OpenCppCoverage\OpenCppCoverage.exe `
  --sources D:\source\llama.cpp-jet\tools\server `
  --sources D:\source\llama.cpp-jet\tests `
  --excluded_sources D:\source\llama.cpp-jet\build-coverage `
  --excluded_sources D:\source\llama.cpp-jet\build-phase2 `
  --export_type html:D:\source\llama.cpp-jet\build-coverage\coverage-html `
  --export_type cobertura:D:\source\llama.cpp-jet\build-coverage\coverage.xml `
  -- D:\source\llama.cpp-jet\build-coverage\bin\Debug\test-cache-controller.exe
```

The Phase 2 verification report must include:

- exact commands run
- pass/fail result for the test executable
- HTML and Cobertura report paths
- focused total line rate
- per-file line rates for cache-controller and metadata files
- any untested paths, especially model-backed `save_slot()` and `load_slot()`

Do not claim 80% coverage from compile success or stub tests. If the focused report is below 80%, either add tests or document why the remaining uncovered lines require a model-backed integration test.

---

## Performance Considerations

### Memory Overhead

| Component | Phase 1 | Phase 2 | Change |
|-----------|---------|---------|--------|
| Entry storage | List of entries | Same | No change |
| LRU tracking | Inline timestamp | + multimap index | ~40 bytes/entry |
| Prefix index | None | + hash map | ~100 bytes/entry |
| **Total overhead** | 0 | **~140 bytes/entry** | Acceptable |

For 1000 entries: ~140 KB additional overhead (negligible compared to payload sizes).

### Time Complexity

| Operation | Phase 1 | Phase 2 | Improvement |
|-----------|---------|---------|-------------|
| Save | O(n) eviction | O(log n) eviction | 10-100x faster |
| Load | O(n) scan | O(m) indexed | 5-50x faster |
| Evict | O(n) scan | O(log n) multimap | 10-100x faster |
| Update LRU | O(n) | O(log n) | 10-100x faster |

### Expected Performance

With 10,000 cached entries:
- **Phase 1 Eviction**: ~10,000 comparisons (10ms @ 1M cmp/s)
- **Phase 2 Eviction**: ~13 tree lookups (<0.1ms)
- **Speedup**: ~100x

With prefix index hit rate 90%:
- **Phase 1 Lookup**: ~10,000 comparisons average
- **Phase 2 Lookup**: ~10 candidate comparisons
- **Speedup**: ~1000x

---

## Migration Path

### Backward Compatibility

**Legacy Mode (Default)**:
- Unchanged behavior from Phase 1
- Zero regressions
- All existing tests pass

**Hybrid Mode (Opt-in)**:
- Fully functional (no placeholders)
- New boundary metadata features
- Performance optimizations enabled

### Upgrade Path

**From Phase 1 to Phase 2**:

1. **Code Changes**:
   - Replace placeholder save/load implementations
   - Add boundary extraction to HTTP layer
   - Remove dual cache structures
   - Add statistics endpoints

2. **Configuration**:
   - No new required parameters
   - Optional: Configure cache budgets
   - Optional: Enable Prometheus metrics

3. **Testing**:
   - Run full test suite
   - Verify legacy mode unchanged
   - Benchmark hybrid mode performance
   - Check for memory leaks

### Rollback Plan

If issues discovered:

1. **Immediate**: Revert to `--cache-mode=legacy` (no code change needed)
2. **Code Rollback**: Phase 1 implementation remains intact as legacy controller
3. **Data Compatibility**: No persistent state, no migration needed

---

## Success Criteria

### Functional Requirements

- [ ] Hybrid mode save/load fully implemented (no placeholders)
- [ ] Boundary metadata extracted from chat templates
- [ ] Metadata flows from HTTP to cache
- [ ] Statistics accessible via HTTP endpoints
- [ ] Dual cache structures removed
- [ ] No circular dependencies

### Performance Requirements

- [ ] LRU eviction O(log n) complexity
- [ ] Prefix lookup O(m) complexity, m << n
- [ ] Memory overhead < 200 bytes/entry
- [ ] Benchmarks show 10x+ improvement in eviction
- [ ] Benchmarks show 5x+ improvement in lookup

### Quality Requirements

- [ ] 80%+ test coverage maintained
- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] No memory leaks (valgrind clean)
- [ ] No data races (thread sanitizer clean)
- [ ] Zero regressions in legacy mode
- [ ] Clean compilation (zero warnings)

### Documentation Requirements

- [ ] Implementation log updated with progress
- [ ] Verification report documenting Phase 2 completion
- [ ] Performance benchmarks documented
- [ ] API documentation for new endpoints
- [ ] Migration guide for users

---

