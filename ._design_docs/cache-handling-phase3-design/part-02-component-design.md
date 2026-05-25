# Phase 3 Design: Non-Destructive Exact Blob Cache - Part 2: Component Design

Source: [../cache-handling-phase3-design.md](../cache-handling-phase3-design.md)

## Current State (After Stage 2)

### Existing Infrastructure

**`hybrid_cache_entry` structure** (from `server-cache-hybrid.h`):
```cpp
struct hybrid_cache_entry {
    server_tokens tokens;                          // Token sequence
    server_prompt_data data;                       // Serialized state (target + draft)
    std::list<common_prompt_checkpoint> checkpoints; // Checkpoints (unused in Stage 3)
    prepared_prompt_metadata metadata;             // Prompt boundary metadata
    std::string namespace_id;                      // Model + config identifier
    
    std::chrono::system_clock::time_point last_used_time;  // LRU tracking
    size_t use_count = 0;                          // Access counter
    bool protected_root = false;                   // Eviction protection (flag prepared for Stage 4)
    // Note: residency_state field (hot/cold) prepared for Stage 6, currently all entries are hot
    
    void mark_used();                              // Update LRU metadata
    size_t size() const;                           // Calculate byte size
    int n_tokens() const;                          // Token count
};
```

**Implementation Notes**:
- **Protected roots**: The `protected_root` flag is added in Stage 3 for forward compatibility. Full protection semantics (budget pressure handling, explicit refusal when protected roots exceed budget) are implemented in Stage 4 per Architecture ADR-005.
- **Residency state**: Field prepared for Stage 6 cold storage implementation; currently all entries remain hot in RAM.

**`hybrid_cache_controller` class**:
```cpp
class hybrid_cache_controller : public cache_controller {
    std::list<hybrid_cache_entry> entries;         // Main storage
    std::multimap<...> lru_index;                  // For efficient eviction
    std::unordered_map<...> prefix_index;          // For efficient lookup
    
    // Statistics
    size_t n_hits = 0;
    size_t n_misses = 0;
    size_t n_evictions = 0;
    size_t n_restore_failures = 0;
    
    // Current placeholder methods (to be implemented)
    bool save_slot(...);  // Returns true but doesn't save
    bool load_slot(...);  // Uses find_best_match but doesn't restore
    
    // Working helper methods
    find_best_match(...);  // Finds matching entry using prefix index
    evict_lru();           // Evicts oldest non-protected entry
    should_protect(...);   // Determines protection status
};
```

**Boundary metadata threading** (from Stage 2):
- `prepared_prompt_metadata` populated in HTTP layer during chat template application
- Metadata flows through `server_task` to cache controller
- Minimal fallback metadata for non-chat endpoints

## Required Changes for Stage 3

### 1. Implement `save_slot()` Method

**Current state** (placeholder):
```cpp
bool hybrid_cache_controller::save_slot(
    const server_slot & slot,
    const prepared_prompt_metadata & metadata)
{
    SRV_DBG("%s", " - hybrid cache: save_slot integration pending\n");
    return true;  // Placeholder
}
```

**Target implementation** (full state serialization):

```cpp
bool hybrid_cache_controller::save_slot(
    const server_slot & slot,
    const prepared_prompt_metadata & metadata)
{
    // 1. Validate slot has content to save
    if (slot.prompt.tokens.empty()) {
        SRV_WRN("%s", " - hybrid cache: cannot save empty slot\n");
        return false;
    }
    
    // 2. Create new cache entry
    hybrid_cache_entry entry;
    entry.tokens = slot.prompt.tokens;
    entry.namespace_id = compute_namespace_id(metadata);
    entry.metadata = metadata;
    entry.last_used_time = std::chrono::system_clock::now();
    entry.use_count = 1;  // Initial save counts as first use
    entry.protected_root = should_protect(metadata);
    
    // 3. Serialize context state (target + draft)
    if (slot.ctx_tgt) {
        size_t state_size_tgt = llama_state_get_size(slot.ctx_tgt);
        entry.data.main.resize(state_size_tgt);
        llama_state_get_data(slot.ctx_tgt, entry.data.main.data(), state_size_tgt);
    }
    
    if (slot.ctx_dft) {
        size_t state_size_dft = llama_state_get_size(slot.ctx_dft);
        entry.data.drft.resize(state_size_dft);
        llama_state_get_data(slot.ctx_dft, entry.data.drft.data(), state_size_dft);
    }
    
    // 4. Check if equivalent entry already exists (deduplication)
    auto existing = find_exact_match(entry.tokens, entry.namespace_id);
    if (existing != entries.end()) {
        // Update existing entry instead of creating duplicate
        existing->mark_used();
        update_lru_index(existing, existing->last_used_time);
        SRV_DBG(" - hybrid cache: updated existing entry with %d tokens\n", 
                entry.n_tokens());
        return true;
    }
    
    // 5. Add to cache storage and indexes
    entries.push_back(std::move(entry));
    auto it = std::prev(entries.end());
    add_to_lru_index(it);
    add_to_prefix_index(it);
    
    SRV_DBG(" - hybrid cache: saved entry with %d tokens (%.2f KiB)\n",
            it->n_tokens(), it->size() / 1024.0);
    
    return true;
}
```

**Key design decisions**:
- Serialize full state immediately to ensure atomic snapshot
- Deduplicate identical entries to save memory
- Mark as used immediately (initial save counts as first access)
- Apply protection heuristics based on metadata

### 2. Implement `load_slot()` Method

**Current state** (finds match but doesn't restore):
```cpp
bool hybrid_cache_controller::load_slot(
    server_slot & slot,
    const server_task & task)
{
    auto it = find_best_match(task.prompt_tokens, task.prompt_metadata);
    if (it == entries.end()) {
        n_misses++;
        return false;
    }
    
    n_hits++;
    // TODO: Actually restore state to slot
    return false;  // Placeholder
}
```

**Target implementation** (full state restoration):

```cpp
bool hybrid_cache_controller::load_slot(
    server_slot & slot,
    const server_task & task)
{
    // 1. Find best matching entry
    auto it = find_best_match(task.prompt_tokens, task.prompt_metadata);
    if (it == entries.end()) {
        n_misses++;
        SRV_DBG("%s", " - hybrid cache: no matching entry found\n");
        return false;
    }
    
    // 2. Validate match quality (exact match only in Stage 3)
    if (it->tokens.size() != task.prompt_tokens.size()) {
        n_misses++;
        SRV_DBG(" - hybrid cache: partial match rejected (%d vs %d tokens)\n",
                it->tokens.size(), task.prompt_tokens.size());
        return false;
    }
    
    // 3. Restore target context state
    if (!it->data.main.empty() && slot.ctx_tgt) {
        size_t restored = llama_state_set_data(
            slot.ctx_tgt,
            it->data.main.data(),
            it->data.main.size());
        
        if (restored != it->data.main.size()) {
            n_restore_failures++;
            SRV_ERR(" - hybrid cache: target state restore failed "
                    "(%zu bytes restored, %zu expected)\n",
                    restored, it->data.main.size());
            return false;
        }
    } else if (it->data.main.empty()) {
        n_restore_failures++;
        SRV_ERR("%s", " - hybrid cache: entry has no target state data\n");
        return false;
    }
    
    // 4. Restore draft context state (if present)
    if (!it->data.drft.empty() && slot.ctx_dft) {
        size_t restored = llama_state_set_data(
            slot.ctx_dft,
            it->data.drft.data(),
            it->data.drft.size());
        
        if (restored != it->data.drft.size()) {
            n_restore_failures++;
            SRV_ERR(" - hybrid cache: draft state restore failed "
                    "(%zu bytes restored, %zu expected)\n",
                    restored, it->data.drft.size());
            // Continue anyway - draft is optional
        }
    }
    
    // 5. Copy tokens and metadata to slot (non-destructive)
    slot.prompt.tokens = it->tokens;
    slot.prompt_metadata = it->metadata;
    
    // 6. Update usage tracking (NON-DESTRUCTIVE - entry stays in cache)
    const auto old_time = it->last_used_time;
    it->mark_used();
    update_lru_index(it, old_time);
    
    n_hits++;
    SRV_DBG(" - hybrid cache: restored %d tokens from cache "
            "(use_count=%zu, total_hits=%zu)\n",
            it->n_tokens(), it->use_count, n_hits);
    
    return true;
}
```

**Key design decisions**:
- Require exact match for Stage 3 (partial matches deferred to later stages)
- Fail explicitly if state restoration returns wrong byte count
- Copy tokens and metadata to slot (no move semantics)
- Update LRU index atomically with access tracking
- Entry remains in cache after successful load

### 3. Add Helper Methods

**`find_exact_match()` for deduplication**:
```cpp
std::list<hybrid_cache_entry>::iterator 
hybrid_cache_controller::find_exact_match(
    const server_tokens & tokens,
    const std::string & namespace_id)
{
    // Use prefix index for fast candidate filtering
    auto prefix_it = prefix_index.find(get_token_prefix(tokens, PREFIX_INDEX_LENGTH));
    if (prefix_it == prefix_index.end()) {
        return entries.end();
    }
    
    // Check each candidate for exact match
    for (auto it : prefix_it->second) {
        if (it->namespace_id != namespace_id) {
            continue;
        }
        if (it->tokens == tokens) {
            return it;  // Exact match found
        }
    }
    
    return entries.end();
}
```

**Deduplication Scope**: Stage 3 implements simple token-sequence identity checking (same tokens + namespace). This prevents duplicate storage of identical cache entries. **Equivalent-branch deduplication** (R83a) with convergence selection and deterministic tie-breaking is deferred to Stage 8 when full branch graph topology is implemented.

**`compute_namespace_id()` variants**:
```cpp
std::string hybrid_cache_controller::compute_namespace_id() const {
    // Fallback: use context pointers as namespace identifier
    std::ostringstream oss;
    oss << "ctx_" << ctx_tgt;
    if (ctx_dft) {
        oss << "_dft_" << ctx_dft;
    }
    return oss.str();
}

std::string hybrid_cache_controller::compute_namespace_id(
    const prepared_prompt_metadata & metadata) const
{
    // Prefer metadata-derived namespace if available
    if (metadata.has_boundaries() && !metadata.compatibility_key.empty()) {
        return metadata.compatibility_key;
    }
    return compute_namespace_id();  // Fallback
}
```

**`update_lru_index()` for atomic LRU updates**:
```cpp
void hybrid_cache_controller::update_lru_index(
    std::list<hybrid_cache_entry>::iterator entry_it,
    std::chrono::system_clock::time_point old_time)
{
    // Remove old LRU entry
    auto range = lru_index.equal_range(old_time);
    for (auto it = range.first; it != range.second; ++it) {
        if (it->second == entry_it) {
            lru_index.erase(it);
            break;
        }
    }
    
    // Add new LRU entry with updated time
    lru_index.emplace(entry_it->last_used_time, entry_it);
}
```

### 4. Data Structure Extensions

**Add `compatibility_key` to `prepared_prompt_metadata`** (in `server-task.h`):
```cpp
struct prepared_prompt_metadata {
    std::vector<prompt_boundary> boundaries;
    std::string compatibility_key;  // NEW: for namespace identification
    
    // Existing methods...
    bool has_boundaries() const;
    void add_boundary(...);
    // etc.
};
```

This key is computed during boundary extraction in Stage 2 and encodes model-specific configuration that affects state compatibility.

---

**Next**: [Part 3: Implementation Steps](./part-03-implementation-steps.md)
