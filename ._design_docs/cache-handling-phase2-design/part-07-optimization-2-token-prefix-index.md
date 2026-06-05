# Phase 2 Implementation Design: Completing Architecture Stages 1-2 - Part 7: Optimization 2: Token Prefix Index

Source: [../cache-handling-phase2-design.md](../cache-handling-phase2-design.md)

#### Optimization 2: Token Prefix Index

**Index Maintenance**:

```cpp
// Add to index when inserting entry
void hybrid_cache_controller::add_to_prefix_index(
    std::list<hybrid_cache_entry>::iterator entry_it)
{
    const auto & tokens = entry_it->tokens;
    
    if (tokens.size() < PREFIX_INDEX_LENGTH) {
        // Short sequence - index entire thing
        token_prefix prefix(tokens.begin(), tokens.end());
        prefix_index[prefix].push_back(entry_it);
    } else {
        // Index first N tokens
        token_prefix prefix(tokens.begin(), 
                          tokens.begin() + PREFIX_INDEX_LENGTH);
        prefix_index[prefix].push_back(entry_it);
    }
}

void hybrid_cache_controller::remove_from_prefix_index(
    std::list<hybrid_cache_entry>::iterator entry_it)
{
    const auto & tokens = entry_it->tokens;
    
    token_prefix prefix;
    if (tokens.size() < PREFIX_INDEX_LENGTH) {
        prefix = token_prefix(tokens.begin(), tokens.end());
    } else {
        prefix = token_prefix(tokens.begin(), 
                            tokens.begin() + PREFIX_INDEX_LENGTH);
    }
    
    auto it = prefix_index.find(prefix);
    if (it != prefix_index.end()) {
        auto & vec = it->second;
        vec.erase(std::remove(vec.begin(), vec.end(), entry_it), vec.end());
        
        if (vec.empty()) {
            prefix_index.erase(it);
        }
    }
}
```

**Optimized Lookup** (O(m) where m = candidates, typically m << n):

```cpp
std::list<hybrid_cache_entry>::iterator 
hybrid_cache_controller::find_best_match(const server_tokens & tokens,
                                        uint64_t namespace_id)
{
    // Build search prefix
    token_prefix search_prefix;
    if (tokens.size() < PREFIX_INDEX_LENGTH) {
        search_prefix = token_prefix(tokens.begin(), tokens.end());
    } else {
        search_prefix = token_prefix(tokens.begin(), 
                                    tokens.begin() + PREFIX_INDEX_LENGTH);
    }
    
    // Look up candidates in index
    auto it = prefix_index.find(search_prefix);
    if (it == prefix_index.end()) {
        return entries.end();  // No candidates
    }
    
    // Check only indexed candidates (not all entries)
    const auto & candidates = it->second;
    
    auto best = entries.end();
    size_t best_len = 0;
    
    for (auto candidate_it : candidates) {
        // Skip wrong namespace
        if (candidate_it->namespace_id != namespace_id) {
            continue;
        }
        
        // Verify full prefix match
        size_t match_len = 0;
        const size_t max_len = std::min(candidate_it->tokens.size(), 
                                       tokens.size());
        
        for (size_t i = 0; i < max_len; i++) {
            if (candidate_it->tokens[i] != tokens[i]) {
                break;
            }
            match_len++;
        }
        
        // Update best match
        if (match_len > best_len && 
            match_len == candidate_it->tokens.size()) {
            best = candidate_it;
            best_len = match_len;
        }
    }
    
    return best;
}
```

**Hash Function for Token Prefix**:

```cpp
struct TokenPrefixHash {
    size_t operator()(const std::vector<llama_token> & prefix) const {
        size_t hash = 0;
        for (llama_token tok : prefix) {
            hash ^= std::hash<llama_token>{}(tok) + 0x9e3779b9 + 
                   (hash << 6) + (hash >> 2);
        }
        return hash;
    }
};
```

#### Optimization 3: Memory Pool for Entries

Reduce allocation overhead:

```cpp
// Optional: Use object pool for cache entries
class CacheEntryPool {
private:
    std::vector<hybrid_cache_entry> pool;
    std::vector<size_t> free_list;
    
public:
    hybrid_cache_entry * allocate() {
        if (free_list.empty()) {
            pool.emplace_back();
            return &pool.back();
        }
        
        size_t idx = free_list.back();
        free_list.pop_back();
        return &pool[idx];
    }
    
    void deallocate(hybrid_cache_entry * entry) {
        size_t idx = entry - pool.data();
        free_list.push_back(idx);
        entry->reset();  // Clear data
    }
};
```

#### Performance Targets

| Operation | Phase 1 (Before) | Phase 2 (After) | Improvement |
|-----------|------------------|-----------------|-------------|
| LRU Eviction | O(n) | O(log n) | ~10-100x faster |
| Prefix Lookup | O(n) | O(m), m << n | ~5-50x faster |
| Cache Insert | O(1) | O(log n) | Slightly slower but acceptable |
| Cache Hit (update) | O(n) | O(log n) | ~10-100x faster |

---

## Data Structures

### Updated Structures for Phase 2

#### 1. hybrid_cache_controller (Enhanced)

```cpp
class hybrid_cache_controller : public cache_controller {
private:
    // Core storage
    std::list<hybrid_cache_entry> entries;
    
    // Performance indexes
    std::multimap<std::chrono::steady_clock::time_point,
                  std::list<hybrid_cache_entry>::iterator> lru_index;
    std::unordered_map<token_prefix,
                       std::vector<std::list<hybrid_cache_entry>::iterator>,
                       TokenPrefixHash> prefix_index;
    
    // Contexts and limits
    llama_context * ctx;
    llama_context * ctx_dft;
    size_t max_size;
    size_t max_tokens;
    size_t current_size;
    uint64_t current_namespace_id;
    
    // Statistics
    mutable hybrid_cache_statistics stats;
    
public:
    // Constructor
    hybrid_cache_controller(size_t max_size, size_t max_tokens,
                           llama_context * ctx, llama_context * ctx_dft);
    
    // cache_controller interface (FULLY IMPLEMENTED)
    bool save_slot(const server_slot & slot) override;
    bool load_slot(server_slot & slot, const server_tokens & tokens) override;
    void update() override;
    cache_statistics get_stats() const override;
    size_t size() const override;
    size_t n_tokens() const override;
    
private:
    // Helpers
    std::list<hybrid_cache_entry>::iterator find_best_match(
        const server_tokens & tokens, uint64_t namespace_id);
    bool evict_lru();
    bool should_protect(const server_slot & slot) const;
    size_t calculate_entry_size(const hybrid_cache_entry & entry) const;
    uint64_t compute_namespace_id() const;
    
    // Index maintenance
    void add_to_lru_index(std::list<hybrid_cache_entry>::iterator it);
    void remove_from_lru_index(std::list<hybrid_cache_entry>::iterator it,
                               std::chrono::steady_clock::time_point old_time);
    void update_lru_index(std::list<hybrid_cache_entry>::iterator it,
                         std::chrono::steady_clock::time_point old_time);
    void add_to_prefix_index(std::list<hybrid_cache_entry>::iterator it);
    void remove_from_prefix_index(std::list<hybrid_cache_entry>::iterator it);
};
```

#### 2. prepared_prompt_result (New)

```cpp
struct prepared_prompt_result {
    server_tokens tokens;
    prepared_prompt_metadata metadata;
    bool success;
    std::string error_message;
    
    prepared_prompt_result() : success(false) {}
};
```

