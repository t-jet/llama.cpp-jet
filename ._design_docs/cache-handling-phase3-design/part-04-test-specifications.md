# Phase 3 Design: Non-Destructive Exact Blob Cache - Part 4: Test Specifications

Source: [../cache-handling-phase3-design.md](../cache-handling-phase3-design.md)

## Test Organization

Tests are organized into three tiers following the architecture verification strategy:

1. **Unit tests**: Test individual methods in isolation with mocks/fakes
2. **Integration tests**: Test component interactions with real llama_context
3. **End-to-end tests**: Test full request/response cycles

All tests are added to `tests/test-cache-controller.cpp` unless otherwise noted.

## Unit Test Specifications

### Group 1: Helper Method Tests

**Test: `compute_namespace_id_consistent`**

```cpp
TEST_CASE("hybrid_cache compute_namespace_id consistent") {
    // Setup: Create controller with contexts
    llama_context* ctx_tgt = create_mock_context();
    hybrid_cache_controller cache(/*size=*/100, /*tokens=*/1000, ctx_tgt, nullptr);
    
    // Act: Compute namespace ID twice
    std::string ns1 = cache.compute_namespace_id();
    std::string ns2 = cache.compute_namespace_id();
    
    // Assert: Same ID returned
    REQUIRE(ns1 == ns2);
    REQUIRE(!ns1.empty());
}
```

**Test: `compute_namespace_id_prefers_metadata`**

```cpp
TEST_CASE("hybrid_cache compute_namespace_id prefers metadata") {
    // Setup: Create controller and metadata with compatibility key
    hybrid_cache_controller cache(100, 1000, ctx_tgt, nullptr);
    prepared_prompt_metadata meta;
    meta.compatibility_key = "model_v1_config_abc";
    
    // Act: Compute with and without metadata
    std::string ns_no_meta = cache.compute_namespace_id();
    std::string ns_with_meta = cache.compute_namespace_id(meta);
    
    // Assert: Metadata key preferred
    REQUIRE(ns_with_meta == "model_v1_config_abc");
    REQUIRE(ns_no_meta != ns_with_meta);
}
```

**Test: `find_exact_match_finds_matching_entry`**

```cpp
TEST_CASE("hybrid_cache find_exact_match finds matching entry") {
    // Setup: Add entry with known tokens
    hybrid_cache_controller cache(100, 1000, nullptr, nullptr);
    server_tokens tokens = {1, 2, 3, 4, 5};
    cache.debug_add_entry_for_tests(tokens, false, "test_ns");
    
    // Act: Search for exact match
    auto it = cache.find_exact_match(tokens, "test_ns");
    
    // Assert: Match found
    REQUIRE(it != cache.entries.end());
    REQUIRE(it->tokens == tokens);
}
```

**Test: `find_exact_match_respects_namespace`**

```cpp
TEST_CASE("hybrid_cache find_exact_match respects namespace") {
    // Setup: Add entries in different namespaces
    hybrid_cache_controller cache(100, 1000, nullptr, nullptr);
    server_tokens tokens = {1, 2, 3};
    cache.debug_add_entry_for_tests(tokens, false, "ns_a");
    cache.debug_add_entry_for_tests(tokens, false, "ns_b");
    
    // Act: Search in specific namespace
    auto it_a = cache.find_exact_match(tokens, "ns_a");
    auto it_b = cache.find_exact_match(tokens, "ns_b");
    auto it_c = cache.find_exact_match(tokens, "ns_c");
    
    // Assert: Matches respect namespace boundaries
    REQUIRE(it_a != cache.entries.end());
    REQUIRE(it_b != cache.entries.end());
    REQUIRE(it_c == cache.entries.end());
    REQUIRE(it_a->namespace_id == "ns_a");
    REQUIRE(it_b->namespace_id == "ns_b");
}
```

**Test: `update_lru_index_atomically_updates`**

```cpp
TEST_CASE("hybrid_cache update_lru_index atomically updates") {
    // Setup: Add entry and note initial time
    hybrid_cache_controller cache(100, 1000, nullptr, nullptr);
    cache.debug_add_entry_for_tests({1, 2, 3});
    auto old_time = cache.entries.begin()->last_used_time;
    
    // Act: Mark as used (updates time)
    cache.debug_mark_first_entry_used_for_tests();
    auto new_time = cache.entries.begin()->last_used_time;
    
    // Assert: LRU index reflects new time
    REQUIRE(new_time > old_time);
    REQUIRE(cache.lru_index.find(new_time) != cache.lru_index.end());
    REQUIRE(cache.lru_index.find(old_time) == cache.lru_index.end());
}
```

### Group 2: Save Slot Tests

**Test: `save_slot_creates_entry`**

```cpp
TEST_CASE("hybrid_cache save_slot creates entry") {
    // Setup: Create controller and slot with tokens
    hybrid_cache_controller cache(100, 1000, nullptr, nullptr);
    server_slot slot = create_mock_slot({1, 2, 3, 4});
    prepared_prompt_metadata meta;
    
    // Act: Save slot
    size_t before_count = cache.debug_entry_count_for_tests();
    bool result = cache.save_slot(slot, meta);
    size_t after_count = cache.debug_entry_count_for_tests();
    
    // Assert: Entry created
    REQUIRE(result == true);
    REQUIRE(after_count == before_count + 1);
}
```

**Test: `save_slot_deduplicates_identical_entries`**

```cpp
TEST_CASE("hybrid_cache save_slot deduplicates identical entries") {
    // Setup: Create slot with tokens
    hybrid_cache_controller cache(100, 1000, nullptr, nullptr);
    server_slot slot = create_mock_slot({1, 2, 3});
    prepared_prompt_metadata meta;
    meta.compatibility_key = "test_ns";
    
    // Act: Save same slot twice
    cache.save_slot(slot, meta);
    size_t count_after_first = cache.debug_entry_count_for_tests();
    cache.save_slot(slot, meta);
    size_t count_after_second = cache.debug_entry_count_for_tests();
    
    // Assert: No duplicate created
    REQUIRE(count_after_first == 1);
    REQUIRE(count_after_second == 1);
}
```

**Test: `save_slot_applies_protected_root_flag`**

```cpp
TEST_CASE("hybrid_cache save_slot applies protected_root flag") {
    // Setup: Create metadata with protection hint
    hybrid_cache_controller cache(100, 1000, nullptr, nullptr);
    server_slot slot = create_mock_slot({1, 2, 3});
    prepared_prompt_metadata meta;
    meta.add_boundary({SYSTEM_START, 0, {}}); // Indicates system prompt
    
    // Act: Save slot
    cache.save_slot(slot, meta);
    
    // Assert: Entry protected
    REQUIRE(cache.entries.begin()->protected_root == true);
}
```

**Test: `save_slot_rejects_empty_slots`**

```cpp
TEST_CASE("hybrid_cache save_slot rejects empty slots") {
    // Setup: Create empty slot
    hybrid_cache_controller cache(100, 1000, nullptr, nullptr);
    server_slot slot = create_mock_slot({});  // No tokens
    prepared_prompt_metadata meta;
    
    // Act: Attempt to save
    bool result = cache.save_slot(slot, meta);
    
    // Assert: Rejected
    REQUIRE(result == false);
    REQUIRE(cache.debug_entry_count_for_tests() == 0);
}
```

### Group 3: Load Slot Tests (Non-Destructive Behavior)

**Test: `load_slot_finds_exact_match`**

```cpp
TEST_CASE("hybrid_cache load_slot finds exact match") {
    // Setup: Add entry and create matching task
    hybrid_cache_controller cache(100, 1000, nullptr, nullptr);
    server_tokens tokens = {1, 2, 3, 4, 5};
    prepared_prompt_metadata meta;
    cache.debug_add_entry_for_tests(tokens, meta);
    
    server_task task;
    task.prompt_tokens = tokens;
    task.prompt_metadata = meta;
    server_slot slot = create_mock_slot({});
    
    // Act: Load slot
    bool result = cache.load_slot(slot, task);
    
    // Assert: Match found
    REQUIRE(result == true);
    REQUIRE(slot.prompt.tokens == tokens);
}
```

**Test: `load_slot_rejects_partial_match`**

```cpp
TEST_CASE("hybrid_cache load_slot rejects partial match") {
    // Setup: Add entry with 5 tokens, request has 3 tokens
    hybrid_cache_controller cache(100, 1000, nullptr, nullptr);
    cache.debug_add_entry_for_tests({1, 2, 3, 4, 5});
    
    server_task task;
    task.prompt_tokens = {1, 2, 3};  // Partial match
    server_slot slot = create_mock_slot({});
    
    // Act: Attempt to load
    bool result = cache.load_slot(slot, task);
    
    // Assert: Rejected in Stage 3 (exact match required)
    REQUIRE(result == false);
}
```

**Test: `load_slot_non_destructive`**

```cpp
TEST_CASE("hybrid_cache load_slot is non-destructive") {
    // Setup: Add entry
    hybrid_cache_controller cache(100, 1000, nullptr, nullptr);
    server_tokens tokens = {1, 2, 3};
    cache.debug_add_entry_for_tests(tokens);
    size_t count_before = cache.debug_entry_count_for_tests();
    
    // Act: Load twice
    server_task task;
    task.prompt_tokens = tokens;
    server_slot slot1 = create_mock_slot({});
    server_slot slot2 = create_mock_slot({});
    
    bool result1 = cache.load_slot(slot1, task);
    size_t count_after_first = cache.debug_entry_count_for_tests();
    bool result2 = cache.load_slot(slot2, task);
    size_t count_after_second = cache.debug_entry_count_for_tests();
    
    // Assert: Entry remains in cache after both loads
    REQUIRE(result1 == true);
    REQUIRE(result2 == true);
    REQUIRE(count_before == 1);
    REQUIRE(count_after_first == 1);
    REQUIRE(count_after_second == 1);
}
```

**Test: `load_slot_updates_usage_tracking`**

```cpp
TEST_CASE("hybrid_cache load_slot updates usage tracking") {
    // Setup: Add entry
    hybrid_cache_controller cache(100, 1000, nullptr, nullptr);
    server_tokens tokens = {1, 2, 3};
    cache.debug_add_entry_for_tests(tokens);
    size_t initial_use_count = cache.entries.begin()->use_count;
    auto initial_time = cache.entries.begin()->last_used_time;
    
    // Act: Load slot
    std::this_thread::sleep_for(std::chrono::milliseconds(10));
    server_task task;
    task.prompt_tokens = tokens;
    server_slot slot = create_mock_slot({});
    cache.load_slot(slot, task);
    
    size_t final_use_count = cache.entries.begin()->use_count;
    auto final_time = cache.entries.begin()->last_used_time;
    
    // Assert: Usage metadata updated
    REQUIRE(final_use_count == initial_use_count + 1);
    REQUIRE(final_time > initial_time);
}
```

**Test: `load_slot_increments_hit_miss_stats`**

```cpp
TEST_CASE("hybrid_cache load_slot increments hit/miss stats") {
    // Setup: Add one entry
    hybrid_cache_controller cache(100, 1000, nullptr, nullptr);
    cache.debug_add_entry_for_tests({1, 2, 3});
    
    // Act: Load matching task (hit)
    server_task task1;
    task1.prompt_tokens = {1, 2, 3};
    server_slot slot1 = create_mock_slot({});
    cache.load_slot(slot1, task1);
    
    // Act: Load non-matching task (miss)
    server_task task2;
    task2.prompt_tokens = {4, 5, 6};
    server_slot slot2 = create_mock_slot({});
    cache.load_slot(slot2, task2);
    
    // Assert: Stats reflect hits and misses
    json stats = cache.get_stats();
    REQUIRE(stats["n_hits"] == 1);
    REQUIRE(stats["n_misses"] == 1);
}
```

## Integration Test Specifications

### Group 4: State Serialization/Restoration Tests

**Test: `save_load_preserves_context_state`**

```cpp
TEST_CASE("hybrid_cache save and load preserves context state") {
    // Setup: Create real llama_context and process tokens
    auto model = load_test_model();
    auto ctx = llama_new_context_with_model(model, default_params());
    llama_decode(ctx, create_batch({1, 2, 3, 4, 5}));
    
    // Capture state before save
    size_t state_size_before = llama_state_get_size(ctx);
    std::vector<uint8_t> expected_state(state_size_before);
    llama_state_get_data(ctx, expected_state.data(), state_size_before);
    
    // Act: Save slot
    hybrid_cache_controller cache(100, 10000, ctx, nullptr);
    server_slot slot = wrap_context_in_slot(ctx, {1, 2, 3, 4, 5});
    prepared_prompt_metadata meta;
    cache.save_slot(slot, meta);
    
    // Act: Clear context and reload
    llama_kv_cache_clear(ctx);
    server_task task;
    task.prompt_tokens = {1, 2, 3, 4, 5};
    cache.load_slot(slot, task);
    
    // Assert: Restored state matches original
    size_t state_size_after = llama_state_get_size(ctx);
    std::vector<uint8_t> actual_state(state_size_after);
    llama_state_get_data(ctx, actual_state.data(), state_size_after);
    
    REQUIRE(state_size_before == state_size_after);
    REQUIRE(expected_state == actual_state);
}
```

**Test: `save_load_handles_draft_context`**

```cpp
TEST_CASE("hybrid_cache save and load handles draft context") {
    // Setup: Create target + draft contexts
    auto model = load_test_model();
    auto ctx_tgt = llama_new_context_with_model(model, default_params());
    auto ctx_dft = llama_new_context_with_model(model, draft_params());
    
    llama_decode(ctx_tgt, create_batch({1, 2, 3}));
    llama_decode(ctx_dft, create_batch({1, 2}));
    
    // Act: Save with both contexts
    hybrid_cache_controller cache(100, 10000, ctx_tgt, ctx_dft);
    server_slot slot = wrap_contexts_in_slot(ctx_tgt, ctx_dft, {1, 2, 3});
    cache.save_slot(slot, {});
    
    // Assert: Both state blobs populated
    REQUIRE(cache.entries.begin()->data.main.size() > 0);
    REQUIRE(cache.entries.begin()->data.drft.size() > 0);
    
    // Act: Load and verify both restored
    llama_kv_cache_clear(ctx_tgt);
    llama_kv_cache_clear(ctx_dft);
    server_task task;
    task.prompt_tokens = {1, 2, 3};
    cache.load_slot(slot, task);
    
    // Assert: Both contexts restored correctly
    REQUIRE(llama_get_kv_cache_used_cells(ctx_tgt) > 0);
    REQUIRE(llama_get_kv_cache_used_cells(ctx_dft) > 0);
}
```

**Test: `load_slot_handles_restore_failure`**

```cpp
TEST_CASE("hybrid_cache load_slot handles restore failure gracefully") {
    // Setup: Create entry with corrupted state data
    hybrid_cache_controller cache(100, 1000, ctx_tgt, nullptr);
    hybrid_cache_entry entry;
    entry.tokens = {1, 2, 3};
    entry.data.main = {0xFF, 0xFF, 0xFF};  // Invalid state data
    cache.entries.push_back(std::move(entry));
    
    // Act: Attempt to load
    server_task task;
    task.prompt_tokens = {1, 2, 3};
    server_slot slot = create_mock_slot({});
    bool result = cache.load_slot(slot, task);
    
    // Assert: Failure handled gracefully
    REQUIRE(result == false);
    json stats = cache.get_stats();
    REQUIRE(stats["n_restore_failures"] == 1);
}
```

### Group 5: Multi-Slot Reuse Tests

**Test: `multiple_slots_reuse_same_entry`**

```cpp
TEST_CASE("hybrid_cache multiple slots can reuse same entry") {
    // Setup: Save one entry
    auto ctx = create_test_context();
    hybrid_cache_controller cache(100, 10000, ctx, nullptr);
    server_slot save_slot = create_test_slot(ctx, {1, 2, 3, 4, 5});
    cache.save_slot(save_slot, {});
    
    // Act: Load into three different slots
    server_task task;
    task.prompt_tokens = {1, 2, 3, 4, 5};
    
    server_slot slot1 = create_empty_slot(ctx);
    server_slot slot2 = create_empty_slot(ctx);
    server_slot slot3 = create_empty_slot(ctx);
    
    bool r1 = cache.load_slot(slot1, task);
    bool r2 = cache.load_slot(slot2, task);
    bool r3 = cache.load_slot(slot3, task);
    
    // Assert: All three loads succeeded
    REQUIRE(r1 == true);
    REQUIRE(r2 == true);
    REQUIRE(r3 == true);
    
    // Assert: Entry remains in cache
    REQUIRE(cache.debug_entry_count_for_tests() == 1);
    
    // Assert: Each slot has independent copy
    REQUIRE(&slot1.prompt.tokens != &slot2.prompt.tokens);
    REQUIRE(&slot2.prompt.tokens != &slot3.prompt.tokens);
}
```

## End-to-End Test Specifications

### Group 6: Full Request Cycle Tests

**Test: `e2e_chat_completion_with_cache`**

Outline (manual test, not automated in Stage 3):

1. Start llama-server with `--cache-mode hybrid --cache-size-mib 100`
2. Send chat completion request with system prompt + user message
3. Verify response generated correctly
4. Send second request with same system prompt, different user message
5. Verify cache hit logged in server output
6. Verify second request faster than first (cache benefit)
7. Check `/cache/stats` endpoint, verify `n_hits > 0`

**Test: `e2e_multi_turn_conversation`**

Outline (manual test):

1. Start llama-server in hybrid mode
2. Send turn 1: system + user1 → assistant1
3. Send turn 2: system + user1 + assistant1 + user2 → assistant2
4. Verify turn 2 reuses cached prefix from turn 1
5. Verify `n_hits >= 1` in stats
6. Send turn 3 with same history → verify further cache reuse

---

## Coverage Target

All test groups must achieve **≥80% line coverage** on:

- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- New methods in `tools/server/server-cache-controller.cpp`

Measured via OpenCppCoverage as specified in Part 3.

---

**Next**: [Part 5: Metrics and Observability](./part-05-metrics-and-observability.md)
