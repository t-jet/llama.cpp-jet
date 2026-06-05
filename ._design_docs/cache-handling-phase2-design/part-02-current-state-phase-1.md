# Phase 2 Implementation Design: Completing Architecture Stages 1-2 - Part 2: Current State (Phase 1)

Source: [../cache-handling-phase2-design.md](../cache-handling-phase2-design.md)

#### Current State (Phase 1)

```cpp
bool hybrid_cache_controller::save_slot(const server_slot & slot) {
    // TODO: Implement in Phase 2
    LOG_WRN("Hybrid cache save not yet implemented\n");
    return false;
}

bool hybrid_cache_controller::load_slot(server_slot & slot, 
                                        const server_tokens & tokens) {
    // TODO: Implement in Phase 2
    LOG_WRN("Hybrid cache load not yet implemented\n");
    return false;
}
```

#### Phase 2 Design

**Save Operation**:

```cpp
bool hybrid_cache_controller::save_slot(const server_slot & slot) {
    // 1. Serialize target state
    std::vector<uint8_t> data_tgt;
    const size_t size_tgt = llama_state_get_size(slot.ctx);
    data_tgt.resize(size_tgt);
    
    if (llama_state_get_data(slot.ctx, data_tgt.data(), size_tgt) != size_tgt) {
        LOG_ERR("Failed to serialize target state for slot %d\n", slot.id);
        stats.n_save_failures++;
        return false;
    }
    
    // 2. Serialize draft state if present
    std::vector<uint8_t> data_dft;
    if (slot.ctx_dft != nullptr) {
        const size_t size_dft = llama_state_get_size(slot.ctx_dft);
        data_dft.resize(size_dft);
        
        if (llama_state_get_data(slot.ctx_dft, data_dft.data(), size_dft) != size_dft) {
            LOG_ERR("Failed to serialize draft state for slot %d\n", slot.id);
            stats.n_save_failures++;
            return false;
        }
    }
    
    // 3. Copy checkpoints if present
    std::list<common_prompt_checkpoint> checkpoints_copy = slot.checkpoints;
    
    // 4. Create cache entry
    hybrid_cache_entry entry;
    entry.tokens = slot.cache_tokens;  // Full token sequence
    entry.data_tgt = std::move(data_tgt);
    entry.data_dft = std::move(data_dft);
    entry.checkpoints = std::move(checkpoints_copy);
    entry.namespace_id = current_namespace_id;  // From context
    entry.last_used_time = std::chrono::steady_clock::now();
    entry.use_count = 0;
    entry.protected_root = should_protect(slot);  // Protection policy
    
    // 5. Check if we need to evict
    size_t entry_size = calculate_entry_size(entry);
    while (current_size + entry_size > max_size && !entries.empty()) {
        if (!evict_lru()) {
            LOG_ERR("Failed to evict entry to make space\n");
            stats.n_save_failures++;
            return false;
        }
    }
    
    // 6. Add to cache
    entries.push_back(std::move(entry));
    current_size += entry_size;
    stats.n_entries++;
    
    LOG_DBG("Saved slot %d to hybrid cache (tokens=%zu, size=%zu)\n",
            slot.id, entry.tokens.size(), entry_size);
    
    return true;
}
```

**Load Operation with Prefix Matching**:

```cpp
bool hybrid_cache_controller::load_slot(server_slot & slot, 
                                        const server_tokens & tokens) {
    // 1. Find best matching entry
    auto best_entry = find_best_match(tokens, current_namespace_id);
    
    if (best_entry == entries.end()) {
        stats.n_misses++;
        LOG_DBG("No cache match for slot %d (tokens=%zu)\n", 
                slot.id, tokens.size());
        return false;
    }
    
    // 2. Validate match
    if (best_entry->tokens.size() > tokens.size()) {
        LOG_ERR("Cache entry longer than request (bug in find_best_match)\n");
        stats.n_misses++;
        return false;
    }
    
    // 3. Restore target state (non-destructive)
    if (llama_state_set_data(slot.ctx, 
                            best_entry->data_tgt.data(), 
                            best_entry->data_tgt.size()) != best_entry->data_tgt.size()) {
        LOG_ERR("Failed to restore target state for slot %d\n", slot.id);
        stats.n_load_failures++;
        return false;
    }
    
    // 4. Restore draft state if present
    if (!best_entry->data_dft.empty() && slot.ctx_dft != nullptr) {
        if (llama_state_set_data(slot.ctx_dft, 
                                best_entry->data_dft.data(), 
                                best_entry->data_dft.size()) != best_entry->data_dft.size()) {
            LOG_ERR("Failed to restore draft state for slot %d\n", slot.id);
            stats.n_load_failures++;
            return false;
        }
    }
    
    // 5. Restore checkpoints
    slot.checkpoints = best_entry->checkpoints;
    
    // 6. Update slot metadata
    slot.cache_tokens = best_entry->tokens;
    slot.n_past = best_entry->tokens.size();
    
    // 7. Mark entry as used (non-destructive hit)
    best_entry->mark_used();
    stats.n_hits++;
    
    LOG_DBG("Loaded cache for slot %d (hit %zu/%zu tokens)\n",
            slot.id, best_entry->tokens.size(), tokens.size());
    
    return true;
}
```

**Helper: Find Best Prefix Match**:

```cpp
std::list<hybrid_cache_entry>::iterator 
hybrid_cache_controller::find_best_match(const server_tokens & tokens,
                                        uint64_t namespace_id) {
    auto best = entries.end();
    size_t best_len = 0;
    
    for (auto it = entries.begin(); it != entries.end(); ++it) {
        // Skip wrong namespace
        if (it->namespace_id != namespace_id) {
            continue;
        }
        
        // Check prefix match
        size_t match_len = 0;
        const size_t max_len = std::min(it->tokens.size(), tokens.size());
        
        for (size_t i = 0; i < max_len; i++) {
            if (it->tokens[i] != tokens[i]) {
                break;
            }
            match_len++;
        }
        
        // Update best match
        if (match_len > best_len && match_len == it->tokens.size()) {
            // Full prefix match and longer than current best
            best = it;
            best_len = match_len;
        }
    }
    
    return best;
}
```

**Protection Policy**:

```cpp
bool hybrid_cache_controller::should_protect(const server_slot & slot) const {
    // Phase 2: Simple heuristic - protect if explicitly marked
    // Future phases can add sophisticated policies:
    // - Protect system prompts
    // - Protect frequently-used roots
    // - Protect based on boundary metadata
    
    // For now, check if slot has protection hint in metadata
    if (slot.task && 
        !slot.task->prompt_metadata.boundaries.empty()) {
        
        // Check if first boundary is SYSTEM_START
        const auto & first = slot.task->prompt_metadata.boundaries.front();
        if (first.type == boundary_type::SYSTEM_START) {
            return true;  // Protect system prompts
        }
    }
    
    return false;
}
```

#### Implementation Notes

1. **Serialization Safety**:
   - Always check `llama_state_get_size()` before allocating buffers
   - Verify return values from `llama_state_get_data()` match expected sizes
   - Handle partial failures gracefully

2. **Memory Management**:
   - Use `std::move()` to avoid copying large buffers
   - Calculate entry sizes before insertion
   - Trigger eviction before adding new entries

3. **Non-Destructive Semantics**:
   - Entries remain in `entries` list after load
   - Only `mark_used()` updates, no removal
   - Eviction is separate from loading

4. **Namespace Isolation**:
   - Always check `namespace_id` during lookup
   - Prevents cross-namespace cache hits
   - Shared budget but isolated matching

---

### Component 2: Boundary Metadata Extraction

**File**: `tools/server/server-chat.cpp`

#### Current State (Phase 1)

Chat template application produces only tokens, no boundary information:

```cpp
// Simplified current flow
std::vector<llama_token> apply_chat_template(...) {
    // Apply jinja template to messages
    std::string formatted = jinja.render(template_str, messages);
    
    // Tokenize
    std::vector<llama_token> tokens = llama_tokenize(ctx, formatted, ...);
    
    return tokens;  // No boundary information
}
```

