# Phase 2 Implementation Design: Completing Architecture Stages 1-2 - Part 8: 3. cache_statistics (Enhanced)

Source: [../cache-handling-phase2-design.md](../cache-handling-phase2-design.md)

Status note, 2026-05-25: this enhanced statistics endpoint design is deferred. Current upstream-scope work uses `/metrics` for cache observability and does not add `/cache/stats` or cache fields to `/health`.

#### 3. cache_statistics (Enhanced)

```cpp
struct cache_statistics {
    // Basic info
    std::string cache_type;
    size_t size_bytes;
    size_t size_mib;
    size_t max_size_bytes;
    size_t n_tokens;
    size_t n_entries;
    
    // Hybrid metrics
    uint64_t n_hits;
    uint64_t n_misses;
    uint64_t n_evictions;
    uint64_t n_save_failures;
    uint64_t n_load_failures;
    
    // Namespace info
    std::vector<uint64_t> active_namespaces;
    
    // Computed metrics
    double hit_rate() const {
        uint64_t total = n_hits + n_misses;
        return total > 0 ? static_cast<double>(n_hits) / total : 0.0;
    }
    
    double utilization() const {
        return max_size_bytes > 0 ? 
               static_cast<double>(size_bytes) / max_size_bytes : 0.0;
    }
    
    double miss_rate() const {
        return 1.0 - hit_rate();
    }
};
```

---

## Integration Points

### 1. HTTP Layer → Task Creation

```
HTTP Request
    ↓
[server-http.cpp] handle_chat_completion()
    ↓
[server-chat.cpp] apply_chat_template_with_metadata()
    ├── Extract boundaries during template application
    └── Return: {tokens, metadata}
    ↓
[server-task.cpp] create_task()
    ├── task.prompt_tokens = tokens
    └── task.prompt_metadata = metadata  ← NEW
    ↓
Task Queue
```

### 2. Task → Cache Controller

```
Task from Queue
    ↓
[server-context.cpp] process_task()
    ↓
get_available_slot(task)
    ├── Try to load from cache
    │   └── cache_ctrl->load_slot(slot, task.prompt_tokens)
    │       └── Uses task.prompt_metadata for future boundary-aware matching
    └── If miss, process normally
    ↓
After completion
    ↓
cache_ctrl->save_slot(slot)
    └── Stores with boundary metadata (if available)
```

### 3. Cache Controller → HTTP Stats

```
HTTP GET /health or /cache/stats
    ↓
[server-http.cpp] handle_cache_stats_request()
    ↓
cache_ctrl->get_stats()
    ↓
Format as JSON/Prometheus
    ↓
HTTP Response
```

---

## Implementation Sequence

### Week 1-2: Complete Hybrid Save/Load

**Tasks**:
- [ ] Implement full `hybrid_cache_controller::save_slot()`
- [ ] Implement full `hybrid_cache_controller::load_slot()`
- [ ] Implement `find_best_match()` with prefix matching
- [ ] Add error handling and validation
- [ ] Update `should_protect()` with basic policy
- [ ] Add unit tests for save/load round-trip

**Deliverables**:
- Hybrid mode functional with real workloads
- No more placeholder warnings
- Tests verify state serialization correctness

**Acceptance Criteria**:
- [ ] Save/load round-trip preserves target state
- [ ] Save/load round-trip preserves draft state
- [ ] Save/load round-trip preserves checkpoints
- [ ] Non-destructive behavior verified
- [ ] LRU eviction works correctly
- [ ] Protected roots respected

---

### Week 2-3: Boundary Metadata Extraction

**Tasks**:
- [ ] Create `prepared_prompt_result` structure
- [ ] Implement `apply_chat_template_with_metadata()`
- [ ] Add boundary extraction for ChatML template
- [ ] Add boundary extraction for Llama2 template
- [ ] Add generic/fallback parser
- [ ] Implement template type detection
- [ ] Add fallback path for extraction failures
- [ ] Add diagnostic logging

**Deliverables**:
- Boundaries extracted during chat template application
- Support for major template formats
- Graceful degradation when extraction fails

**Acceptance Criteria**:
- [ ] SYSTEM_START/END boundaries detected
- [ ] MESSAGE_START/END boundaries detected
- [ ] TOOL_CALL_START/END boundaries detected
- [ ] Token offsets correct for all boundaries
- [ ] Fallback works when extraction fails
- [ ] Tests cover multiple template formats

---

### Week 3-4: Metadata Threading

**Tasks**:
- [ ] Update task creation to populate `prompt_metadata`
- [ ] Thread metadata through task queue
- [ ] Make metadata available in slot processing
- [ ] Update `save_slot()` to accept metadata parameter
- [ ] Add diagnostics for missing metadata
- [ ] Add tests for metadata propagation

**Deliverables**:
- Complete metadata flow from HTTP to cache
- Diagnostics when metadata unavailable

**Acceptance Criteria**:
- [ ] Metadata flows HTTP → task → context
- [ ] `save_slot()` receives metadata
- [ ] Diagnostics log when metadata missing
- [ ] `/completion` endpoints handled gracefully
- [ ] Tests verify end-to-end flow

---

### Week 4: Statistics Endpoint Integration

**Tasks**:
- [ ] Define `cache_statistics` structure
- [ ] Implement `get_stats()` for both controllers
- [ ] Extend `/health` endpoint with cache summary
- [ ] Create `/cache/stats` endpoint
- [ ] Implement Prometheus format support
- [ ] Add tests for endpoint responses

**Deliverables**:
- Cache metrics accessible via HTTP
- Support for JSON and Prometheus formats

**Acceptance Criteria**:
- [ ] `/health` includes cache summary
- [ ] `/cache/stats` returns detailed metrics
- [ ] Prometheus format correct
- [ ] Hit rate calculation correct
- [ ] Utilization calculation correct
- [ ] Tests verify metric accuracy

---

### Week 5-6: Slot Architecture Refactoring

**Tasks**:
- [ ] Move `legacy_cache_controller` to separate file
- [ ] Remove `prompt_cache` from `server_context_impl`
- [ ] Unify slot save/load to use cache controller
- [ ] Update factory function
- [ ] Resolve circular dependencies
- [ ] Update CMakeLists.txt
- [ ] Verify legacy mode unchanged

**Deliverables**:
- Clean architecture with single cache path
- No circular dependencies
- Legacy mode fully functional

**Acceptance Criteria**:
- [ ] No `prompt_cache` field in hybrid mode
- [ ] All slots use `cache_ctrl` interface
- [ ] No circular includes
- [ ] Clean compilation
- [ ] Legacy mode tests pass unchanged
- [ ] No behavior regressions

---

### Week 6-7: Performance Optimizations

**Tasks**:
- [ ] Implement LRU index with multimap
- [ ] Update eviction to use index (O(log n))
- [ ] Implement token prefix index
- [ ] Update lookup to use prefix index
- [ ] Update index maintenance on insert/evict
- [ ] Add performance benchmarks
- [ ] Profile hot paths

**Deliverables**:
- Optimized LRU eviction and lookup
- Performance improvements measurable

**Acceptance Criteria**:
- [ ] Eviction complexity O(log n)
- [ ] Lookup complexity O(m) where m << n
- [ ] Benchmarks show improvement
- [ ] No correctness regressions
- [ ] Memory overhead acceptable

---

