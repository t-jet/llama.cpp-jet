# Phase 2 Implementation Design: Completing Architecture Stages 1-2 - Part 5: Component 4: Slot Architecture Refactoring

Source: [../cache-handling-phase2-design.md](../cache-handling-phase2-design.md)

### Component 4: Slot Architecture Refactoring

**Objective**: Eliminate dual cache structures and circular dependencies.

#### Current Architecture Issues

1. **Dual Cache Structures** (temporary debt from Phase 1):
   ```cpp
   struct server_context_impl {
       server_prompt_cache prompt_cache;  // Legacy path
       std::unique_ptr<cache_controller> cache_ctrl;  // New path
   };
   ```

2. **Circular Dependency**:
   - `server-cache-legacy.cpp` needs `server_slot` methods
   - `server_slot` defined in `server-context.cpp`
   - Creates circular dependency

3. **Mixed Call Sites**:
   - Some slots call `prompt_cache` directly
   - Some slots call through `cache_ctrl`
   - Inconsistent behavior

#### Phase 2 Refactoring Plan

**Step 1: Move Legacy Controller to Separate File**

Create `tools/server/server-cache-legacy.cpp`:

```cpp
// server-cache-legacy.cpp
#include "server-cache-legacy.h"
#include "server-context.h"  // For server_slot definition

class legacy_cache_controller_impl : public cache_controller {
private:
    server_prompt_cache cache;  // Owns the legacy cache
    
public:
    legacy_cache_controller_impl(size_t max_size, 
                                 size_t max_tokens,
                                 llama_context * ctx,
                                 llama_context * ctx_dft)
        : cache()
    {
        cache.n_tokens = max_tokens;
        // Initialize from parameters
    }
    
    bool save_slot(const server_slot & slot) override {
        // Extract state from slot
        server_prompt prompt;
        prompt.tokens = slot.cache_tokens;
        
        // Serialize target state
        size_t size_tgt = llama_state_get_size(slot.ctx);
        prompt.data.data_tgt.resize(size_tgt);
        llama_state_get_data(slot.ctx, 
                            prompt.data.data_tgt.data(), 
                            size_tgt);
        
        // Serialize draft if present
        if (slot.ctx_dft) {
            size_t size_dft = llama_state_get_size(slot.ctx_dft);
            prompt.data.data_dft.resize(size_dft);
            llama_state_get_data(slot.ctx_dft, 
                                prompt.data.data_dft.data(), 
                                size_dft);
        }
        
        // Copy checkpoints
        prompt.checkpoints = slot.checkpoints;
        
        // Add to cache (legacy alloc logic)
        cache.states.push_back(std::move(prompt));
        
        return true;
    }
    
    bool load_slot(server_slot & slot, 
                   const server_tokens & tokens) override {
        // Find matching cache entry
        auto it = std::find_if(cache.states.begin(), 
                              cache.states.end(),
                              [&](const server_prompt & p) {
            return p.tokens.size() <= tokens.size() &&
                   std::equal(p.tokens.begin(), p.tokens.end(), 
                             tokens.begin());
        });
        
        if (it == cache.states.end()) {
            return false;  // Miss
        }
        
        // Restore state (DESTRUCTIVE - moves out of cache)
        llama_state_set_data(slot.ctx, 
                            it->data.data_tgt.data(), 
                            it->data.data_tgt.size());
        
        if (!it->data.data_dft.empty() && slot.ctx_dft) {
            llama_state_set_data(slot.ctx_dft, 
                                it->data.data_dft.data(), 
                                it->data.data_dft.size());
        }
        
        slot.checkpoints = std::move(it->checkpoints);
        slot.cache_tokens = std::move(it->tokens);
        slot.n_past = slot.cache_tokens.size();
        
        // Remove from cache (destructive hit)
        cache.states.erase(it);
        
        return true;
    }
    
    void update() override {
        cache.update();  // Delegate to legacy FIFO eviction
    }
    
    cache_statistics get_stats() const override {
        cache_statistics stats;
        stats.cache_type = "legacy";
        stats.n_entries = cache.states.size();
        
        // Calculate size
        size_t total_size = 0;
        size_t total_tokens = 0;
        for (const auto & state : cache.states) {
            total_size += state.data.data_tgt.size();
            total_size += state.data.data_dft.size();
            total_tokens += state.tokens.size();
        }
        
        stats.size_bytes = total_size;
        stats.size_mib = total_size / (1024 * 1024);
        stats.n_tokens = total_tokens;
        
        return stats;
    }
    
    size_t size() const override {
        size_t total = 0;
        for (const auto & state : cache.states) {
            total += state.data.data_tgt.size();
            total += state.data.data_dft.size();
        }
        return total;
    }
    
    size_t n_tokens() const override {
        size_t total = 0;
        for (const auto & state : cache.states) {
            total += state.tokens.size();
        }
        return total;
    }
};
```

**Step 2: Update Factory Function**

```cpp
// server-cache-controller.cpp
#include "server-cache-legacy.h"
#include "server-cache-hybrid.h"

std::unique_ptr<cache_controller> create_cache_controller(
    cache_mode mode,
    size_t max_size,
    size_t max_tokens,
    llama_context * ctx,
    llama_context * ctx_dft)
{
    switch (mode) {
        case CACHE_MODE_LEGACY:
            return std::make_unique<legacy_cache_controller_impl>(
                max_size, max_tokens, ctx, ctx_dft);
        
        case CACHE_MODE_HYBRID:
            return std::make_unique<hybrid_cache_controller>(
                max_size, max_tokens, ctx, ctx_dft);
        
        default:
            LOG_ERR("Unknown cache mode: %d\n", static_cast<int>(mode));
            return nullptr;
    }
}
```

**Step 3: Remove Dual Structures from server_context**

```cpp
// server-context.cpp - BEFORE (Phase 1)
struct server_context_impl {
    server_prompt_cache prompt_cache;  // Remove this
    std::unique_ptr<cache_controller> cache_ctrl;
    cache_mode cache_mode_active;
};

// server-context.cpp - AFTER (Phase 2)
struct server_context_impl {
    std::unique_ptr<cache_controller> cache_ctrl;  // Single cache path
    cache_mode cache_mode_active;
};
```

**Step 4: Unify Slot Save/Load Methods**

```cpp
// server-context.cpp
void server_slot::save_to_cache() {
    if (!ctx_impl->cache_ctrl) {
        LOG_WRN("No cache controller available\n");
        return;
    }
    
    // Single unified path
    bool success = ctx_impl->cache_ctrl->save_slot(*this);
    
    if (!success) {
        LOG_WRN("Failed to save slot %d to cache\n", id);
    }
}

bool server_slot::load_from_cache(const server_tokens & tokens) {
    if (!ctx_impl->cache_ctrl) {
        return false;
    }
    
    // Single unified path
    return ctx_impl->cache_ctrl->load_slot(*this, tokens);
}
```

**Step 5: Update Cache Creation in load_model**

```cpp
// server-context.cpp - load_model()
void server_context_impl::load_model(const common_params & params) {
    // ... model loading ...
    
    // Create cache controller (single path)
    cache_mode_active = params.cache_mode_val;
    
    cache_ctrl = create_cache_controller(
        cache_mode_active,
        params.cache_size,
        params.cache_tokens,
        ctx,
        ctx_dft
    );
    
    if (!cache_ctrl) {
        throw std::runtime_error("Failed to create cache controller");
    }
    
    LOG_INF("Cache controller created: mode=%s\n",
            cache_mode_active == CACHE_MODE_LEGACY ? "legacy" : "hybrid");
    
    // No more dual cache structures
}
```

