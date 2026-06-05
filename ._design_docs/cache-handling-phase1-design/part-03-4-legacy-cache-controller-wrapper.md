# Phase 1 Implementation Design: Alternate Hybrid Cache Mode - Part 3: 4. Legacy Cache Controller Wrapper

Source: [../cache-handling-phase1-design.md](../cache-handling-phase1-design.md)

### 4. Legacy Cache Controller Wrapper

**File**: `tools/server/server-cache-legacy.h` (new)

```cpp
#pragma once

#include "server-cache-controller.h"
#include "server-task.h"

// Wrapper around existing server_prompt_cache to implement cache_controller interface
class legacy_cache_controller : public cache_controller {
public:
    legacy_cache_controller(
        int32_t limit_size_mib,
        size_t limit_tokens,
        llama_context * ctx_tgt,
        llama_context * ctx_dft);
    
    ~legacy_cache_controller() override = default;
    
    bool save_slot(const server_slot & slot) override;
    bool load_slot(server_slot & slot, const server_task & task) override;
    void update() override;
    json get_stats() const override;
    size_t size() const override;
    size_t n_tokens() const override;

private:
    std::unique_ptr<server_prompt_cache> cache;
    llama_context * ctx_tgt;
    llama_context * ctx_dft;
};
```

**File**: `tools/server/server-cache-legacy.cpp` (new)

```cpp
#include "server-cache-legacy.h"
#include "server-context.h"  // For server_slot definition

legacy_cache_controller::legacy_cache_controller(
    int32_t limit_size_mib,
    size_t limit_tokens,
    llama_context * ctx_tgt,
    llama_context * ctx_dft)
    : ctx_tgt(ctx_tgt)
    , ctx_dft(ctx_dft)
{
    cache = std::make_unique<server_prompt_cache>(limit_size_mib, limit_tokens);
}

bool legacy_cache_controller::save_slot(const server_slot & slot) {
    // Delegate to slot's existing prompt_save method
    return const_cast<server_slot&>(slot).prompt_save(*cache);
}

bool legacy_cache_controller::load_slot(server_slot & slot, const server_task & task) {
    // Delegate to slot's existing prompt_load method
    return slot.prompt_load(*cache, task.tokens);
}

void legacy_cache_controller::update() {
    cache->update();
}

json legacy_cache_controller::get_stats() const {
    return json {
        {"mode", "legacy"},
        {"entries", cache->states.size()},
        {"size_bytes", cache->size()},
        {"size_tokens", cache->n_tokens()},
        {"limit_bytes", cache->limit_size},
        {"limit_tokens", cache->limit_tokens},
    };
}

size_t legacy_cache_controller::size() const {
    return cache->size();
}

size_t legacy_cache_controller::n_tokens() const {
    return cache->n_tokens();
}
```

