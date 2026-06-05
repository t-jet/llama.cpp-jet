# Phase 2 Implementation Design: Completing Architecture Stages 1-2 - Part 9: Week 7-8: Integration Testing

Source: [../cache-handling-phase2-design.md](../cache-handling-phase2-design.md)

### Week 7-8: Integration Testing

**Tasks**:
- [ ] End-to-end tests with real models
- [ ] Multi-slot concurrent access tests
- [ ] Boundary metadata round-trip tests
- [ ] Statistics accuracy tests
- [ ] Performance regression tests
- [ ] Legacy mode compatibility tests
- [ ] Stress tests with memory pressure

**Deliverables**:
- Comprehensive test suite
- 80%+ coverage maintained
- All tests passing

**Acceptance Criteria**:
- [ ] All Phase 2 components tested
- [ ] No regressions in legacy mode
- [ ] Performance targets met
- [ ] 80% code coverage
- [ ] No memory leaks
- [ ] Clean under valgrind/sanitizers

---

## Testing Strategy

### Unit Tests

#### 1. Hybrid Save/Load Tests

```cpp
TEST_CASE("hybrid_save_load_roundtrip") {
    // Create controller
    hybrid_cache_controller ctrl(2000_MB, 100000, ctx, nullptr);
    
    // Create slot with state
    server_slot slot;
    slot.cache_tokens = {1, 2, 3, 4, 5};
    // ... populate slot state ...
    
    // Save
    REQUIRE(ctrl.save_slot(slot));
    
    // Clear slot
    slot.cache_tokens.clear();
    
    // Load
    REQUIRE(ctrl.load_slot(slot, {1, 2, 3, 4, 5}));
    
    // Verify
    REQUIRE(slot.cache_tokens == std::vector{1, 2, 3, 4, 5});
    // ... verify state restored ...
}

TEST_CASE("hybrid_prefix_matching") {
    hybrid_cache_controller ctrl(2000_MB, 100000, ctx, nullptr);
    
    // Save entry with tokens [1,2,3,4,5]
    server_slot slot1;
    slot1.cache_tokens = {1, 2, 3, 4, 5};
    ctrl.save_slot(slot1);
    
    // Try to load with longer sequence [1,2,3,4,5,6,7]
    server_slot slot2;
    REQUIRE(ctrl.load_slot(slot2, {1, 2, 3, 4, 5, 6, 7}));
    
    // Should get prefix [1,2,3,4,5]
    REQUIRE(slot2.cache_tokens == std::vector{1, 2, 3, 4, 5});
}

TEST_CASE("hybrid_non_destructive") {
    hybrid_cache_controller ctrl(2000_MB, 100000, ctx, nullptr);
    
    // Save once
    server_slot slot1;
    slot1.cache_tokens = {1, 2, 3};
    ctrl.save_slot(slot1);
    
    // Load multiple times
    server_slot slot2, slot3;
    REQUIRE(ctrl.load_slot(slot2, {1, 2, 3}));
    REQUIRE(ctrl.load_slot(slot3, {1, 2, 3}));  // Should still hit
    
    // Verify both loads succeeded
    REQUIRE(slot2.cache_tokens == std::vector{1, 2, 3});
    REQUIRE(slot3.cache_tokens == std::vector{1, 2, 3});
}
```

#### 2. Boundary Extraction Tests

```cpp
TEST_CASE("boundary_extraction_chatml") {
    json messages = json::array();
    messages.push_back({
        {"role", "system"},
        {"content", "You are a helpful assistant."}
    });
    messages.push_back({
        {"role", "user"},
        {"content", "Hello!"}
    });
    
    prepared_prompt_result result = apply_chat_template_with_metadata(
        ctx, messages, chatml_template, true);
    
    REQUIRE(result.success);
    REQUIRE(!result.metadata.boundaries.empty());
    
    // Verify system boundaries
    REQUIRE(result.metadata.has_boundaries());
    auto boundaries = result.metadata.get_boundaries();
    
    bool has_system_start = false;
    bool has_system_end = false;
    for (const auto & b : boundaries) {
        if (b.type == boundary_type::SYSTEM_START) has_system_start = true;
        if (b.type == boundary_type::SYSTEM_END) has_system_end = true;
    }
    
    REQUIRE(has_system_start);
    REQUIRE(has_system_end);
}

TEST_CASE("boundary_extraction_fallback") {
    // Unknown template format
    std::string weird_template = "{{weird_format}}";
    
    json messages = json::array();
    messages.push_back({{"role", "user"}, {"content", "test"}});
    
    // Should not crash, should return tokens without boundaries
    prepared_prompt_result result = apply_chat_template_with_metadata(
        ctx, messages, weird_template, false);
    
    REQUIRE(result.success);
    REQUIRE(!result.tokens.empty());
    // Metadata may be empty (fallback)
}
```

#### 3. Performance Optimization Tests

```cpp
TEST_CASE("lru_eviction_performance") {
    hybrid_cache_controller ctrl(100_MB, 10000, ctx, nullptr);
    
    // Fill cache with many entries
    for (int i = 0; i < 1000; i++) {
        server_slot slot;
        slot.cache_tokens = generate_random_tokens(100);
        ctrl.save_slot(slot);
    }
    
    // Measure eviction time
    auto start = std::chrono::high_resolution_clock::now();
    
    for (int i = 0; i < 100; i++) {
        ctrl.evict_lru();
    }
    
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    
    // Should be fast (< 100ms for 100 evictions)
    REQUIRE(duration.count() < 100);
}

TEST_CASE("prefix_lookup_performance") {
    hybrid_cache_controller ctrl(1000_MB, 100000, ctx, nullptr);
    
    // Add many entries
    for (int i = 0; i < 10000; i++) {
        server_slot slot;
        slot.cache_tokens = generate_random_tokens(50);
        ctrl.save_slot(slot);
    }
    
    // Measure lookup time
    auto start = std::chrono::high_resolution_clock::now();
    
    for (int i = 0; i < 1000; i++) {
        server_slot slot;
        auto tokens = generate_random_tokens(50);
        ctrl.load_slot(slot, tokens);  // May hit or miss
    }
    
    auto end = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::milliseconds>(end - start);
    
    // Should be fast (< 500ms for 1000 lookups)
    REQUIRE(duration.count() < 500);
}
```

### Integration Tests

#### 1. End-to-End with Real Model

```cpp
TEST_CASE("e2e_chat_with_hybrid_cache") {
    // Load model in hybrid mode
    common_params params;
    params.cache_mode_val = CACHE_MODE_HYBRID;
    params.cache_size = 2000_MB;
    
    server_context ctx;
    ctx.load_model(params);
    
    // First request
    json req1 = {
        {"messages", json::array({
            {{"role", "system"}, {"content", "You are helpful."}},
            {{"role", "user"}, {"content", "Hi!"}}
        })}
    };
    
    auto resp1 = ctx.process_request(req1);
    REQUIRE(resp1.success);
    
    // Second request with same system prompt (should hit cache)
    json req2 = {
        {"messages", json::array({
            {{"role", "system"}, {"content", "You are helpful."}},
            {{"role", "user"}, {"content", "Hello again!"}}
        })}
    };
    
    auto resp2 = ctx.process_request(req2);
    REQUIRE(resp2.success);
    
    // Check stats - should have cache hit
    auto stats = ctx.get_cache_stats();
    REQUIRE(stats.n_hits > 0);
}
```

