# Phase 2 Implementation Design: Completing Architecture Stages 1-2 - Part 6: Dependency Resolution

Source: [../cache-handling-phase2-design.md](../cache-handling-phase2-design.md)

#### Dependency Resolution

**Updated Include Structure**:

```
server-cache-controller.h (interface)
        ↑
        ├── server-cache-legacy.h
        │   └── server-cache-legacy.cpp (includes server-context.h)
        │
        └── server-cache-hybrid.h
            └── server-cache-hybrid.cpp

server-context.h (server_slot definition)
        ↓
server-context.cpp (includes server-cache-controller.h)
```

**No Circular Dependencies**:
- `server-cache-controller.h` only declares interface (no slot dependency)
- `server-cache-legacy.cpp` includes `server-context.h` (one direction)
- `server-context.cpp` includes `server-cache-controller.h` (other direction)
- Clean separation maintained

---

### Component 5: Performance Optimizations

#### Current Performance Issues

1. **O(n) LRU Eviction**:
   ```cpp
   // Phase 1 implementation - linear scan
   bool hybrid_cache_controller::evict_lru() {
       auto oldest = entries.end();
       auto oldest_time = std::chrono::steady_clock::time_point::max();
       
       for (auto it = entries.begin(); it != entries.end(); ++it) {
           if (!it->protected_root && it->last_used_time < oldest_time) {
               oldest = it;
               oldest_time = it->last_used_time;
           }
       }
       // ... evict oldest ...
   }
   ```
   **Issue**: Scans all entries on every eviction. With large caches, this becomes expensive.

2. **O(n) Prefix Matching**:
   ```cpp
   // Phase 1 implementation - linear search
   auto find_best_match(const server_tokens & tokens) {
       for (auto it = entries.begin(); it != entries.end(); ++it) {
           // Check prefix match...
       }
   }
   ```
   **Issue**: Checks every entry. No indexing by token prefix.

#### Optimization 1: Indexed LRU with Priority Queue

**Data Structure**:

```cpp
// server-cache-hybrid.h
class hybrid_cache_controller : public cache_controller {
private:
    // Storage
    std::list<hybrid_cache_entry> entries;
    
    // NEW: LRU index using multimap (sorted by last_used_time)
    using lru_entry = std::pair<
        std::chrono::steady_clock::time_point,  // last_used_time
        std::list<hybrid_cache_entry>::iterator  // entry pointer
    >;
    std::multimap<std::chrono::steady_clock::time_point,
                  std::list<hybrid_cache_entry>::iterator> lru_index;
    
    // NEW: Token prefix index (first N tokens → entries)
    static constexpr size_t PREFIX_INDEX_LENGTH = 8;
    using token_prefix = std::vector<llama_token>;
    std::unordered_map<
        token_prefix,
        std::vector<std::list<hybrid_cache_entry>::iterator>,
        TokenPrefixHash
    > prefix_index;
};
```

**Optimized Eviction** (O(log n)):

```cpp
bool hybrid_cache_controller::evict_lru() {
    if (lru_index.empty()) {
        return false;
    }
    
    // Find oldest non-protected entry in O(log n)
    for (auto it = lru_index.begin(); it != lru_index.end(); ++it) {
        auto entry_it = it->second;
        
        if (!entry_it->protected_root) {
            // Found eviction candidate
            size_t entry_size = calculate_entry_size(*entry_it);
            
            // Remove from prefix index
            remove_from_prefix_index(entry_it);
            
            // Remove from LRU index
            lru_index.erase(it);
            
            // Remove from main storage
            entries.erase(entry_it);
            
            current_size -= entry_size;
            stats.n_evictions++;
            stats.n_entries--;
            
            LOG_DBG("Evicted LRU entry (size=%zu, entries remaining=%zu)\n",
                    entry_size, entries.size());
            
            return true;
        }
    }
    
    // All entries are protected - evict anyway
    if (!lru_index.empty()) {
        LOG_WRN("All entries protected, forcing eviction of oldest\n");
        auto it = lru_index.begin();
        auto entry_it = it->second;
        
        // Same eviction logic...
        return true;
    }
    
    return false;
}
```

**Update LRU Index on Access**:

```cpp
void hybrid_cache_entry::mark_used() {
    // Update timestamp
    auto old_time = last_used_time;
    last_used_time = std::chrono::steady_clock::now();
    use_count++;
    
    // Notify controller to update index
    // (Controller maintains lru_index, entry just updates timestamp)
}

// In controller
void hybrid_cache_controller::update_lru_index(
    std::list<hybrid_cache_entry>::iterator entry_it,
    std::chrono::steady_clock::time_point old_time)
{
    // Remove old index entry
    auto range = lru_index.equal_range(old_time);
    for (auto it = range.first; it != range.second; ++it) {
        if (it->second == entry_it) {
            lru_index.erase(it);
            break;
        }
    }
    
    // Insert new index entry
    lru_index.insert({entry_it->last_used_time, entry_it});
}
```

