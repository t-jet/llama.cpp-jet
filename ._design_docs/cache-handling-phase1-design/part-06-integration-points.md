# Phase 1 Implementation Design: Alternate Hybrid Cache Mode - Part 6: Integration Points

Source: [../cache-handling-phase1-design.md](../cache-handling-phase1-design.md)

```cpp
        return;
    }
    
    // Phase 1: Global LRU eviction across all namespaces
    // Find LRU entry that is not protected (regardless of namespace)
    auto it_lru = entries.end();
    int64_t time_lru = INT64_MAX;
    
    for (auto it = entries.begin(); it != entries.end(); ++it) {
        // Skip protected entries
        if (should_protect(*it)) {
            continue;
        }
        
        if (it->last_used_time < time_lru) {
            time_lru = it->last_used_time;
            it_lru = it;
        }
    }
    
    if (it_lru == entries.end()) {
        // All entries are protected, evict oldest protected entry
        SRV_WRN("All cache entries are protected, evicting oldest protected entry\n");
        it_lru = std::min_element(entries.begin(), entries.end(),
            [](const hybrid_cache_entry & a, const hybrid_cache_entry & b) {
                return a.last_used_time < b.last_used_time;
            });
    }
    
    SRV_INF("Evicting cache entry: namespace=%s, tokens=%d, size=%.3f MiB, use_count=%d, protected=%s\n",
            it_lru->namespace_id.c_str(),
            it_lru->n_tokens(),
            it_lru->size() / (1024.0 * 1024.0),
            it_lru->use_count,
            it_lru->protected_root ? "yes" : "no");
    
    entries.erase(it_lru);
    n_evictions++;
}

bool hybrid_cache_controller::should_protect(const hybrid_cache_entry & entry) const {
    // Phase 1: Simple protection based on explicit flag
    // Phase 2+ will add policy-based protection
    return entry.protected_root;
}

size_t hybrid_cache_controller::calculate_total_size() const {
    size_t total = 0;
    for (const auto & entry : entries) {
        total += entry.size();
    }
    return total;
}

size_t hybrid_cache_controller::calculate_total_tokens() const {
    size_t total = 0;
    for (const auto & entry : entries) {
        total += entry.n_tokens();
    }
    return total;
}

std::string hybrid_cache_controller::compute_namespace_id() const {
    // Phase 1: Compute namespace from current context state
    // Include model identity and runtime configuration that affects state validity
    std::string key = ctx_tgt ? std::string(llama_model_desc(llama_get_model(ctx_tgt))) : "";
    
    if (ctx_dft) {
        key += "|draft:" + std::string(llama_model_desc(llama_get_model(ctx_dft)));
    }
    
    // Phase 2+: Add LoRA adapters, quantization settings, multimodal flags, etc.
    // For now, simple model-based namespace is sufficient
    
    // Return hash of the key
    return std::to_string(std::hash<std::string>{}(key));
}
```

---

## Integration Points

### 1. HTTP Layer Integration

**File**: `tools/server/server-chat.cpp`

#### Boundary Extraction During Template Application

```cpp
// After chat template application, extract boundaries
// This is a conceptual example - actual implementation depends on template engine details

prepared_prompt_metadata extract_boundaries_from_template(
    const std::string & formatted_prompt,
    const json & messages,
    const std::string & template_name)
{
    prepared_prompt_metadata meta;
    meta.template_name = template_name;
    
    // Phase 1: Simple heuristic-based boundary detection
    // This is a placeholder - actual implementation needs template engine support
    
    // Example: Detect message boundaries based on known template patterns
    // Real implementation should track boundaries during template application
    
    return meta;
}
```

**Note**: Full boundary extraction requires modifications to the chat template engine to track boundaries during application. Phase 1 may start with basic heuristics and improve in later iterations.

### 2. Task Creation Integration

**File**: `tools/server/server-task.cpp`

#### Attach Metadata to Task

```cpp
// In task creation functions, attach prepared-prompt metadata

server_task_uptr server_task::create_task_completion(
    const json & data,
    const llama_vocab * vocab,
    const common_params & params_base,
    int n_ctx_slot,
    const std::vector<llama_logit_bias> & logit_bias_eog,
    const prepared_prompt_metadata & prompt_metadata)  // NEW parameter
{
    auto task = std::make_unique<server_task>(SERVER_TASK_TYPE_COMPLETION);
    
    // ... existing parameter parsing ...
    
    // Phase 1: Attach prepared-prompt metadata
    task->prompt_metadata = prompt_metadata;
    
    return task;
}
```

### 3. Server Context Integration

**File**: `tools/server/server-context.cpp`

#### Replace Direct Cache Usage with Controller

```cpp
// In server_context_impl, replace server_prompt_cache with cache_controller

struct server_context_impl {
    // ... existing fields ...
    
    // OLD: std::unique_ptr<server_prompt_cache> prompt_cache;
    // NEW:
    std::unique_ptr<cache_controller> cache_ctrl;
    
    // ... methods ...
};

// In load_model():
bool server_context_impl::load_model(common_params & params) {
    // ... existing model loading ...
    
    if (params_base.cache_ram_mib != 0) {
        SRV_INF("Creating cache controller: mode=%s, size_limit=%d MiB\n",
                params_base.cache_mode == CACHE_MODE_HYBRID ? "hybrid" : "legacy",
                params_base.cache_ram_mib);
        
        cache_ctrl = create_cache_controller(
            params_base.cache_mode,
            params_base.cache_ram_mib,
            n_ctx,
            ctx_tgt.get(),
            ctx_dft.get()
        );
    }
    
    // ... rest of loading ...
}

// In get_available_slot(), replace direct cache calls:
server_slot * server_context_impl::get_available_slot(const server_task & task) {
    // ... slot selection logic ...
    
    if (update_cache && cache_ctrl) {
        SRV_INF("Updating cache\n");
        const int64_t t_start = ggml_time_us();
        
        // Save current slot state (if non-empty)
        if (ret->prompt.tokens.size() > 0) {
            cache_ctrl->save_slot(*ret);
        }
        
        // Try to load matching state
        if (!cache_ctrl->load_slot(*ret, task)) {
            ret->prompt_clear(false);
        }
        
        // Update cache (triggers eviction if needed)
        cache_ctrl->update();
        
        SRV_INF("Cache update took %.2f ms\n", (ggml_time_us() - t_start) / 1000.0);
    }
    
    return ret;
}

// In slot_save_and_clear() for idle slot caching:
void server_context_impl::slot_save_and_clear(server_slot & slot) {
    if (slot.prompt.n_tokens() == 0 || !cache_ctrl) {
        return;
    }
    SLT_INF(slot, "Saving idle slot to cache\n");
    cache_ctrl->save_slot(slot);
    slot.prompt_clear(false);
    cache_ctrl->update();
}
```

---

## Implementation Sequence

### Step 1: Foundation (Week 1)

**Goal**: Establish mode selection and controller interface

1. Add `cache_mode` enum and parameter to `common_params`
2. Add `--cache-mode` CLI argument parsing
3. Create `server-cache-controller.h` with abstract interface
4. Create factory function in `server-cache-controller.cpp`
5. Add unit tests for mode selection

**Deliverable**: Compiles with mode selection, no behavior change

### Step 2: Legacy Wrapper (Week 1-2)

**Goal**: Wrap existing cache in controller interface

1. Create `server-cache-legacy.h` and `.cpp`
2. Implement wrapper that delegates to existing `server_prompt_cache`
3. Update `server_context_impl` to use `cache_controller` interface
4. Test that legacy mode matches existing behavior exactly

**Deliverable**: Legacy mode works identically to current implementation

### Step 3: Boundary Metadata (Week 2-3)

**Goal**: Add prepared-prompt metadata structures

1. Add `prompt_boundary` and `prepared_prompt_metadata` structs to `server-task.h`
2. Add `prompt_metadata` field to `server_task`
3. Add placeholder boundary extraction in HTTP layer
4. Verify metadata is transported through task pipeline
5. Add unit tests for metadata structures

**Deliverable**: Metadata structures defined and transported (but not yet used)

