# Phase 1 Implementation Design: Alternate Hybrid Cache Mode - Part 4: 5. Hybrid Cache Controller

Source: [../cache-handling-phase1-design.md](../cache-handling-phase1-design.md)

### 5. Hybrid Cache Controller

**File**: `tools/server/server-cache-hybrid.h` (new)

```cpp
#pragma once

#include "server-cache-controller.h"
#include "server-task.h"

#include <list>
#include <chrono>

// Phase 1 hybrid cache entry with LRU tracking
struct hybrid_cache_entry {
    server_tokens tokens;
    server_prompt_data data;  // Full-state blob (target + draft)
    std::list<common_prompt_checkpoint> checkpoints;
    
    // Phase 1: Namespace identification
    std::string namespace_id;  // Compatibility namespace (model + config hash)
    
    // Phase 1: Metadata for LRU and protection
    int64_t last_used_time;   // Timestamp of last access (microseconds since epoch)
    int32_t use_count;         // Number of times accessed
    bool protected_root;       // Protected from normal eviction
    
    // Phase 1: Boundary metadata (optional)
    prepared_prompt_metadata metadata;
    
    size_t size() const {
        size_t res = data.size();
        for (const auto & ckpt : checkpoints) {
            res += ckpt.size();
        }
        return res;
    }
    
    int n_tokens() const {
        return tokens.size();
    }
    
    // Update access time and count
    void mark_used() {
        last_used_time = ggml_time_us();
        use_count++;
    }
};

// Phase 1 hybrid cache controller
class hybrid_cache_controller : public cache_controller {
public:
    hybrid_cache_controller(
        int32_t limit_size_mib,
        size_t limit_tokens,
        llama_context * ctx_tgt,
        llama_context * ctx_dft);
    
    ~hybrid_cache_controller() override = default;
    
    bool save_slot(const server_slot & slot) override;
    bool load_slot(server_slot & slot, const server_task & task) override;
    void update() override;
    json get_stats() const override;
    size_t size() const override;
    size_t n_tokens() const override;

private:
    // Phase 1: List-based storage (same as legacy, but non-destructive)
    std::list<hybrid_cache_entry> entries;
    
    size_t limit_size;    // in bytes, 0 = no limit
    size_t limit_tokens;  // in tokens, 0 = no limit
    
    llama_context * ctx_tgt;
    llama_context * ctx_dft;
    
    // Stats
    size_t n_hits = 0;
    size_t n_misses = 0;
    size_t n_evictions = 0;
    
    // Helper methods
    std::list<hybrid_cache_entry>::iterator find_best_match(
        const server_tokens & tokens_new,
        const prepared_prompt_metadata & metadata);
    
    void evict_lru();  // Evict least recently used entry (global across namespaces)
    bool should_protect(const hybrid_cache_entry & entry) const;
    size_t calculate_total_size() const;
    size_t calculate_total_tokens() const;
    std::string compute_namespace_id() const;  // Compute namespace from current context
};
```

**File**: `tools/server/server-cache-hybrid.cpp` (new)

