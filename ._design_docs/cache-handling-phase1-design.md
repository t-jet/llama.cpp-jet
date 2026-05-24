# Phase 1 Implementation Design: Alternate Hybrid Cache Mode

**Status**: Draft  
**Date**: 2026-05-24  
**Phase**: 1 of 3  
**Primary Sources**: `cache-handling-requirements.md`, `cache-handling-architecture.md`

## Executive Summary

This document provides detailed implementation guidance for Phase 1 of the alternate hybrid cache mode. Phase 1 establishes the foundational architecture for the hybrid cache system while maintaining full backward compatibility with the existing cache implementation.

Phase 1 delivers:
- **Mode gate architecture** that cleanly separates legacy and hybrid cache paths
- **Prepared-prompt boundary metadata** for message-aware cache placement
- **Non-destructive cache hits** that preserve reusable entries
- **LRU eviction policy** with configurable protection for important roots
- **Full legacy compatibility** with zero behavioral changes when hybrid mode is disabled

Phase 1 explicitly defers shared branch graphs, checkpoint-first traversal, and cold-layer storage to later phases, keeping the implementation scope focused and reviewable.

## Table of Contents

1. [Current State Analysis](#current-state-analysis)
2. [Phase 1 Scope](#phase-1-scope)
3. [Architecture Overview](#architecture-overview)
4. [Detailed Component Design](#detailed-component-design)
5. [Data Structures](#data-structures)
6. [Integration Points](#integration-points)
7. [Implementation Sequence](#implementation-sequence)
8. [Testing Strategy](#testing-strategy)
9. [Migration Path](#migration-path)

---

## Current State Analysis

### Existing Cache Implementation

The current `server_prompt_cache` (defined in `tools/server/server-task.h` and implemented in `tools/server/server-task.cpp`) has these characteristics:

```cpp
struct server_prompt_cache {
    std::list<server_prompt> states;    // FIFO list of cached prompts
    size_t limit_size = 0;              // in bytes, 0 = no limit
    size_t limit_tokens = 0;            // in tokens, 0 = no limit
    
    size_t size() const;
    size_t n_tokens() const;
    server_prompt * alloc(const server_prompt & prompt, size_t state_size_main, size_t state_size_drft);
    bool load(server_prompt & prompt, const server_tokens & tokens_new, 
              llama_context * ctx_tgt, llama_context * ctx_dft, int32_t id_slot);
    void update();
};
```

**Current Behavior**:
1. **Destructive hits**: `load()` moves the matched entry out of the cache and into the slot, removing it from `states`
2. **FIFO eviction**: `update()` removes oldest entries first when size limits are exceeded
3. **Prefix removal**: `alloc()` removes any cached prompt that is fully contained in the new prompt being saved
4. **Full-state storage**: Each entry stores complete serialized target and optional draft state in `server_prompt_data`
5. **Checkpoint inclusion**: Checkpoints are stored as part of `server_prompt` but not independently reusable

```cpp
struct server_prompt {
    server_tokens tokens;                           // Token sequence
    server_prompt_data data;                        // Full serialized state (target + draft)
    std::list<common_prompt_checkpoint> checkpoints; // Slot-local checkpoints
};
```

### Checkpoint Implementation

Checkpoints are managed per-slot in `server_slot` (tools/server/server-context.cpp):

```cpp
struct common_prompt_checkpoint {
    int64_t n_tokens;
    llama_pos pos_min;
    llama_pos pos_max;
    std::vector<uint8_t> data_tgt;  // Target state
    std::vector<uint8_t> data_dft;  // Draft state (if applicable)
};
```

**Current Behavior**:
- Checkpoints are lineage-local to a slot's prompt
- Trimmed oldest-first when memory limits are hit
- Not independently addressable or reusable across slots
- Cleared when slot is released or checkpoints are disabled

### HTTP Layer and Prompt Preparation

The HTTP layer handles chat template application in `tools/server/server-chat.cpp` and task creation in `tools/server/server-task.cpp`:

**Current Flow**:
1. HTTP endpoint receives request (e.g., `/v1/chat/completions`)
2. Chat template is applied to messages (in `server-chat.cpp`)
3. Resulting prompt is tokenized
4. `server_task` is created with tokenized prompt
5. Task enters `server_context` for processing

**Gap**: No explicit boundary metadata is preserved after template application. Message boundaries, tool call boundaries, and system prompt extents are lost by the time the task reaches `server_context`.

### Slot Management and Cache Interaction

Slot lifecycle in `server_context_impl` (tools/server/server-context.cpp):

```cpp
server_slot * get_available_slot(const server_task & task) {
    // 1. Try to find slot with prompt similarity (if enabled)
    // 2. Fall back to LRU slot selection
    // 3. If update_cache is true:
    //    - Save current slot state to prompt cache
    //    - Try to load matching cached state
    //    - Update cache (triggers eviction if needed)
}
```

**Current Integration Points**:
- `slot.prompt_save(prompt_cache)` - saves slot state to cache
- `slot.prompt_load(prompt_cache, tokens)` - loads matching cache entry into slot
- `prompt_cache.update()` - handles eviction

---

## Phase 1 Scope

### In Scope

✅ **Mode Gate Architecture**
- CLI flag to enable hybrid mode: `--cache-mode [legacy|hybrid]`
- Dispatch mechanism in cache operations
- Zero behavioral change when hybrid mode is disabled

✅ **Prepared-Prompt Boundary Metadata**
- Data structure for capturing boundaries after template application
- Integration into task creation pipeline
- Transport through `server_task` to `server_context`

✅ **Non-Destructive Cache Hits**
- Cache entries remain available after being matched
- Usage tracking for recency
- Copy-on-restore semantics instead of move

✅ **LRU Eviction Policy**
- Replace FIFO with LRU in hybrid mode
- Resident-byte accounting
- Eviction based on usage recency

✅ **Protected Roots**
- Marking mechanism for important cache entries
- Protection from normal eviction
- Configurable protection rules

✅ **Hybrid State Retention**
- Keep existing full-state blob behavior
- Preserve target/draft pairing
- Maintain checkpoint storage (but not yet as first-class reusable objects)

### Explicitly Deferred to Phase 2

❌ **Shared Branch Graph**
- Multi-slot branch sharing
- Independent branch node lifecycle
- Topology-based branch traversal

❌ **Checkpoint-First Restore Strategy**
- Checkpoints as canonical branch points
- Profile-based restore planning
- Checkpoint-dependent model optimizations

❌ **Equivalent-Branch Deduplication**
- Convergent path detection
- Deterministic branch joining

### Explicitly Deferred to Phase 3

❌ **Cold Layer Storage**
- Payload offload to disk
- Hot/cold residency management
- Asynchronous promotion/demotion

❌ **Metadata-Only Branch Nodes**
- Branch nodes without owned payloads
- Re-materialization from ancestors

❌ **Three-Part Budget System**
- Separate hot/cold/metadata budgets
- Budget-aware pruning vs. eviction decisions

---

## Architecture Overview

### High-Level Design

Phase 1 introduces a **cache controller interface** that dispatches to either the legacy implementation or the new hybrid implementation based on the selected cache mode.

```
┌─────────────────────────────────────────────────────────────┐
│                    server_context_impl                       │
│                                                              │
│  ┌────────────────────────────────────────────────────┐    │
│  │          Cache Controller Interface                 │    │
│  │                                                      │    │
│  │  ┌──────────────┐         ┌──────────────────┐    │    │
│  │  │   Legacy     │         │   Hybrid Cache   │    │    │
│  │  │   Cache      │         │   Controller     │    │    │
│  │  │              │         │                  │    │    │
│  │  │ (existing    │         │ (new Phase 1     │    │    │
│  │  │  behavior)   │         │  implementation) │    │    │
│  │  └──────────────┘         └──────────────────┘    │    │
│  │         ▲                          ▲               │    │
│  │         │                          │               │    │
│  │         └──────────┬───────────────┘               │    │
│  │                    │                               │    │
│  │            Mode selection at startup               │    │
│  │         (--cache-mode legacy|hybrid)               │    │
│  └────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Component Layering

```
┌──────────────────────────────────────────────────────────┐
│ HTTP Layer (server-http.cpp, server-chat.cpp)           │
│ - Chat template application                             │
│ - Boundary metadata extraction (NEW)                    │
└──────────────────────────┬───────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│ Task Layer (server-task.cpp, server-task.h)             │
│ - server_task creation                                  │
│ - Boundary metadata transport (NEW)                     │
└──────────────────────────┬───────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────┐
│ Cache Controller (server-cache-controller.cpp) (NEW)    │
│ - Mode dispatch (legacy vs. hybrid)                     │
│ - Unified interface for slot operations                 │
└──────────────────────────┬───────────────────────────────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
┌─────────────────────────┐  ┌────────────────────────────┐
│ Legacy Cache            │  │ Hybrid Cache               │
│ (server-task.cpp)       │  │ (server-cache-hybrid.cpp)  │
│ - Existing behavior     │  │ (NEW)                      │
│ - FIFO eviction         │  │ - Non-destructive hits     │
│ - Destructive hits      │  │ - LRU eviction             │
│                         │  │ - Protected roots          │
└─────────────────────────┘  └────────────────────────────┘
```

---

## Detailed Component Design

### 1. Cache Mode Selection

**File**: `common/common.h` (for parameters), `tools/server/main.cpp` (for CLI parsing)

#### CLI Flag

```cpp
// In common/common.h, add to common_params:
enum cache_mode {
    CACHE_MODE_LEGACY = 0,
    CACHE_MODE_HYBRID = 1,
};

struct common_params {
    // ... existing fields ...
    cache_mode cache_mode = CACHE_MODE_LEGACY;  // Default to legacy for compatibility
};
```

#### CLI Parsing

```cpp
// In tools/server/main.cpp, add argument handling:
if (arg == "--cache-mode") {
    if (++i >= argc) {
        invalid_param = true;
        break;
    }
    std::string mode_str = argv[i];
    if (mode_str == "legacy") {
        params.cache_mode = CACHE_MODE_LEGACY;
    } else if (mode_str == "hybrid") {
        params.cache_mode = CACHE_MODE_HYBRID;
    } else {
        fprintf(stderr, "error: invalid cache mode '%s' (must be 'legacy' or 'hybrid')\n", 
                mode_str.c_str());
        return 1;
    }
    continue;
}
```

### 2. Prepared-Prompt Boundary Metadata

**File**: `tools/server/server-task.h` (new structures)

#### Data Structures

```cpp
// Represents one boundary point in the prepared prompt
struct prompt_boundary {
    enum boundary_type {
        BOUNDARY_NONE = 0,
        BOUNDARY_MESSAGE_START,     // Start of a user/assistant/system message
        BOUNDARY_MESSAGE_END,       // End of a message
        BOUNDARY_TOOL_CALL_START,   // Start of a tool call
        BOUNDARY_TOOL_CALL_END,     // End of a tool call  
        BOUNDARY_SYSTEM_END,        // End of system prompt
        BOUNDARY_MEDIA_START,       // Start of multimodal content
        BOUNDARY_MEDIA_END,         // End of multimodal content
    };
    
    boundary_type type = BOUNDARY_NONE;
    int32_t token_offset = -1;      // Token index in the prepared prompt
    std::string label;               // Optional label (e.g., "user", "assistant", "system")
    std::string id;                  // Optional ID (e.g., message ID, tool call ID)
    
    json to_json() const {
        return json {
            {"type", (int)type},
            {"token_offset", token_offset},
            {"label", label},
            {"id", id},
        };
    }
};

// Metadata for a prepared prompt with boundaries
struct prepared_prompt_metadata {
    std::vector<prompt_boundary> boundaries;
    
    // Derived convenience fields
    int32_t system_end_offset = -1;      // End of system prompt, -1 if none
    int32_t first_message_offset = 0;    // Start of first user/assistant message
    
    // Protection hints from request
    bool protect_system = false;         // Protect system prompt from eviction
    bool protect_messages = false;       // Protect all messages from eviction
    
    // For debugging and logging
    std::string template_name;           // Name of chat template used (if any)
    
    bool empty() const {
        return boundaries.empty();
    }
    
    void clear() {
        boundaries.clear();
        system_end_offset = -1;
        first_message_offset = 0;
        protect_system = false;
        protect_messages = false;
        template_name.clear();
    }
    
    json to_json() const {
        json j;
        j["boundaries"] = json::array();
        for (const auto & b : boundaries) {
            j["boundaries"].push_back(b.to_json());
        }
        j["system_end_offset"] = system_end_offset;
        j["first_message_offset"] = first_message_offset;
        j["protect_system"] = protect_system;
        j["protect_messages"] = protect_messages;
        j["template_name"] = template_name;
        return j;
    }
};
```

#### Integration into server_task

```cpp
// In tools/server/server-task.h, extend server_task:
struct server_task {
    // ... existing fields ...
    
    // Phase 1: Prepared-prompt boundary metadata
    prepared_prompt_metadata prompt_metadata;
    
    // ... existing methods ...
};
```

### 3. Cache Controller Interface

**File**: `tools/server/server-cache-controller.h` (new)

#### Abstract Interface

```cpp
#pragma once

#include "server-task.h"
#include "server-common.h"
#include "llama.h"

#include <memory>

// Forward declarations
struct server_prompt;
struct server_slot;

// Abstract cache controller interface
class cache_controller {
public:
    virtual ~cache_controller() = default;
    
    // Save slot state to cache
    // Returns false if save failed (e.g., allocation failure)
    virtual bool save_slot(const server_slot & slot) = 0;
    
    // Load matching cache state into slot
    // Returns false if no suitable match found
    virtual bool load_slot(server_slot & slot, const server_task & task) = 0;
    
    // Perform cache maintenance (eviction, stats update, etc.)
    virtual void update() = 0;
    
    // Get cache statistics for logging/metrics
    virtual json get_stats() const = 0;
    
    // Get cache size in bytes
    virtual size_t size() const = 0;
    
    // Get number of cached tokens
    virtual size_t n_tokens() const = 0;
};

// Factory function to create appropriate cache controller based on mode
std::unique_ptr<cache_controller> create_cache_controller(
    cache_mode mode,
    int32_t limit_size_mib,
    size_t limit_tokens,
    llama_context * ctx_tgt,
    llama_context * ctx_dft
);
```

**File**: `tools/server/server-cache-controller.cpp` (new)

```cpp
#include "server-cache-controller.h"
#include "server-cache-legacy.h"   // Wrapper for existing implementation
#include "server-cache-hybrid.h"   // New hybrid implementation

std::unique_ptr<cache_controller> create_cache_controller(
    cache_mode mode,
    int32_t limit_size_mib,
    size_t limit_tokens,
    llama_context * ctx_tgt,
    llama_context * ctx_dft)
{
    switch (mode) {
        case CACHE_MODE_LEGACY:
            return std::make_unique<legacy_cache_controller>(
                limit_size_mib, limit_tokens, ctx_tgt, ctx_dft);
        
        case CACHE_MODE_HYBRID:
            return std::make_unique<hybrid_cache_controller>(
                limit_size_mib, limit_tokens, ctx_tgt, ctx_dft);
        
        default:
            SRV_ERR("Unknown cache mode: %d, defaulting to legacy\n", (int)mode);
            return std::make_unique<legacy_cache_controller>(
                limit_size_mib, limit_tokens, ctx_tgt, ctx_dft);
    }
}
```

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
    
    void evict_lru();  // Evict least recently used entry
    bool should_protect(const hybrid_cache_entry & entry) const;
    size_t calculate_total_size() const;
    size_t calculate_total_tokens() const;
};
```

**File**: `tools/server/server-cache-hybrid.cpp` (new)

```cpp
#include "server-cache-hybrid.h"
#include "server-context.h"
#include "common.h"

hybrid_cache_controller::hybrid_cache_controller(
    int32_t limit_size_mib,
    size_t limit_tokens,
    llama_context * ctx_tgt,
    llama_context * ctx_dft)
    : ctx_tgt(ctx_tgt)
    , ctx_dft(ctx_dft)
{
    this->limit_size = 1024ull * 1024ull * (limit_size_mib < 0 ? 0 : limit_size_mib);
    this->limit_tokens = limit_tokens;
    
    SRV_INF("Hybrid cache initialized: size_limit=%.1f MiB, token_limit=%zu\n",
            this->limit_size / (1024.0 * 1024.0), this->limit_tokens);
}

bool hybrid_cache_controller::save_slot(const server_slot & slot) {
    if (slot.prompt.n_tokens() == 0) {
        return false;
    }
    
    // Get state size
    const size_t cur_size_tgt = llama_state_seq_get_size_ext(
        ctx_tgt, slot.id, LLAMA_STATE_SEQ_FLAGS_NONE);
    const size_t cur_size_dft = ctx_dft ? 
        llama_state_seq_get_size_ext(ctx_dft, slot.id, LLAMA_STATE_SEQ_FLAGS_NONE) : 0;
    const size_t cur_size = cur_size_tgt + cur_size_dft;
    
    SRV_INF("Saving prompt to hybrid cache: length=%d, size=%.3f MiB\n",
            (int)slot.prompt.tokens.size(), cur_size / (1024.0 * 1024.0));
    
    // Check if this exact prompt already exists
    for (auto & entry : entries) {
        if (entry.tokens.size() == slot.prompt.tokens.size() &&
            entry.tokens.get_common_prefix(slot.prompt.tokens) == (int)entry.tokens.size())
        {
            SRV_INF("Prompt already in cache, updating access time\n");
            entry.mark_used();
            return true;
        }
    }
    
    // Allocate state data
    std::vector<uint8_t> state_data_tgt;
    std::vector<uint8_t> state_data_dft;
    
    try {
        state_data_tgt.resize(cur_size_tgt);
        if (cur_size_dft > 0) {
            state_data_dft.resize(cur_size_dft);
        }
    } catch (const std::bad_alloc & e) {
        SRV_ERR("Failed to allocate memory for cache entry: %s\n", e.what());
        // Try eviction and retry
        evict_lru();
        try {
            state_data_tgt.resize(cur_size_tgt);
            if (cur_size_dft > 0) {
                state_data_dft.resize(cur_size_dft);
            }
        } catch (const std::bad_alloc & e2) {
            SRV_ERR("Failed to allocate memory even after eviction: %s\n", e2.what());
            return false;
        }
    }
    
    // Save state
    const size_t n_tgt = llama_state_seq_get_data_ext(
        ctx_tgt, state_data_tgt.data(), cur_size_tgt, slot.id, LLAMA_STATE_SEQ_FLAGS_NONE);
    if (n_tgt != cur_size_tgt) {
        SRV_ERR("Failed to save target state: expected %zu bytes, got %zu\n", cur_size_tgt, n_tgt);
        return false;
    }
    
    if (ctx_dft && cur_size_dft > 0) {
        const size_t n_dft = llama_state_seq_get_data_ext(
            ctx_dft, state_data_dft.data(), cur_size_dft, slot.id, LLAMA_STATE_SEQ_FLAGS_NONE);
        if (n_dft != cur_size_dft) {
            SRV_ERR("Failed to save draft state: expected %zu bytes, got %zu\n", cur_size_dft, n_dft);
            return false;
        }
    }
    
    // Create new entry (non-destructive: clone slot's data)
    hybrid_cache_entry entry;
    entry.tokens = slot.prompt.tokens.clone();
    entry.data.main = std::move(state_data_tgt);
    entry.data.drft = std::move(state_data_dft);
    entry.checkpoints = slot.prompt.checkpoints;  // Copy checkpoints
    entry.last_used_time = ggml_time_us();
    entry.use_count = 1;
    entry.protected_root = false;  // Phase 1: No automatic protection
    
    // Phase 1: Copy prepared-prompt metadata if available from task
    if (slot.task) {
        entry.metadata = slot.task->prompt_metadata;
    }
    
    entries.push_back(std::move(entry));
    
    return true;
}

bool hybrid_cache_controller::load_slot(server_slot & slot, const server_task & task) {
    auto it = find_best_match(task.tokens, task.prompt_metadata);
    
    if (it == entries.end()) {
        SRV_DBG(slot, "No matching cache entry found\n");
        n_misses++;
        return false;
    }
    
    SRV_INF("Loading prompt from hybrid cache: length=%d, size=%.3f MiB\n",
            (int)it->tokens.size(), it->size() / (1024.0 * 1024.0));
    
    // NON-DESTRUCTIVE: Copy state, don't move it
    // Restore target state
    {
        const auto & data = it->data.main;
        if (!data.empty()) {
            const size_t size = data.size();
            const size_t n = llama_state_seq_set_data_ext(
                ctx_tgt, data.data(), size, slot.id, 0);
            if (n != size) {
                SRV_ERR("Failed to restore target state: expected %zu bytes, got %zu\n", size, n);
                n_misses++;
                return false;
            }
        }
    }
    
    // Restore draft state (if applicable)
    {
        const auto & data = it->data.drft;
        if (!data.empty()) {
            GGML_ASSERT(ctx_dft);
            const size_t size = data.size();
            const size_t n = llama_state_seq_set_data_ext(
                ctx_dft, data.data(), size, slot.id, 0);
            if (n != size) {
                SRV_ERR("Failed to restore draft state: expected %zu bytes, got %zu\n", size, n);
                n_misses++;
                return false;
            }
        }
    }
    
    // Copy tokens and checkpoints to slot (non-destructive)
    slot.prompt.tokens = it->tokens.clone();
    slot.prompt.checkpoints = it->checkpoints;
    
    // Update usage tracking
    it->mark_used();
    n_hits++;
    
    SRV_INF("Cache hit! tokens=%d, use_count=%d, protected=%s\n",
            it->n_tokens(), it->use_count, it->protected_root ? "yes" : "no");
    
    return true;
}

void hybrid_cache_controller::update() {
    // Evict until within limits
    while (entries.size() > 1) {
        const size_t cur_size = calculate_total_size();
        const size_t cur_tokens = calculate_total_tokens();
        
        bool exceeded_size = (limit_size > 0 && cur_size > limit_size);
        bool exceeded_tokens = (limit_tokens > 0 && cur_tokens > limit_tokens);
        
        if (!exceeded_size && !exceeded_tokens) {
            break;
        }
        
        evict_lru();
    }
    
    SRV_INF("Hybrid cache state: entries=%zu, size=%.3f MiB, tokens=%zu, hits=%zu, misses=%zu, evictions=%zu\n",
            entries.size(),
            calculate_total_size() / (1024.0 * 1024.0),
            calculate_total_tokens(),
            n_hits, n_misses, n_evictions);
}

json hybrid_cache_controller::get_stats() const {
    return json {
        {"mode", "hybrid"},
        {"entries", entries.size()},
        {"size_bytes", calculate_total_size()},
        {"size_tokens", calculate_total_tokens()},
        {"limit_bytes", limit_size},
        {"limit_tokens", limit_tokens},
        {"hits", n_hits},
        {"misses", n_misses},
        {"evictions", n_evictions},
        {"protected_entries", std::count_if(entries.begin(), entries.end(),
            [](const hybrid_cache_entry & e) { return e.protected_root; })},
    };
}

size_t hybrid_cache_controller::size() const {
    return calculate_total_size();
}

size_t hybrid_cache_controller::n_tokens() const {
    return calculate_total_tokens();
}

std::list<hybrid_cache_entry>::iterator hybrid_cache_controller::find_best_match(
    const server_tokens & tokens_new,
    const prepared_prompt_metadata & metadata)
{
    // Phase 1: Simple prefix matching, similar to legacy behavior
    // Phase 2+ will use boundary-aware matching
    
    auto it_best = entries.end();
    int lcp_best = -1;
    float score_best = -1.0f;
    
    for (auto it = entries.begin(); it != entries.end(); ++it) {
        const int lcp = it->tokens.get_common_prefix(tokens_new);
        
        // Skip if no common prefix
        if (lcp == 0) {
            continue;
        }
        
        // Calculate score: prefer longer matches and higher use counts
        const float f_keep = float(lcp) / it->tokens.size();
        const float f_sim = float(lcp) / tokens_new.size();
        const float score = f_keep * 0.7f + f_sim * 0.3f;  // Weighted score
        
        // Don't trash large prompts (keep at least 25% of tokens)
        if (f_keep < 0.25f) {
            continue;
        }
        
        if (score > score_best || (score == score_best && lcp > lcp_best)) {
            score_best = score;
            lcp_best = lcp;
            it_best = it;
        }
    }
    
    return it_best;
}

void hybrid_cache_controller::evict_lru() {
    if (entries.empty()) {
        return;
    }
    
    // Find LRU entry that is not protected
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
    
    SRV_INF("Evicting cache entry: tokens=%d, size=%.3f MiB, use_count=%d, protected=%s\n",
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

### Step 4: Hybrid Cache Core (Week 3-5)

**Goal**: Implement hybrid cache controller

1. Create `server-cache-hybrid.h` with `hybrid_cache_entry` and `hybrid_cache_controller`
2. Implement non-destructive `save_slot()` (copy instead of move)
3. Implement `load_slot()` with prefix matching
4. Implement basic `find_best_match()` (Phase 1: token-based only)
5. Add unit tests for non-destructive behavior

**Deliverable**: Hybrid mode compiles and passes basic cache tests

### Step 5: LRU Eviction (Week 5-6)

**Goal**: Replace FIFO with LRU

1. Add `last_used_time` and `use_count` to `hybrid_cache_entry`
2. Implement `mark_used()` to update access times
3. Implement `evict_lru()` to remove least recently used entry
4. Implement `calculate_total_size()` and `calculate_total_tokens()`
5. Test eviction behavior under memory pressure

**Deliverable**: LRU eviction works correctly

### Step 6: Protected Roots (Week 6-7)

**Goal**: Add protection mechanism

1. Add `protected_root` flag to `hybrid_cache_entry`
2. Implement `should_protect()` logic
3. Update `evict_lru()` to skip protected entries
4. Add API or config for marking entries as protected
5. Test protection behavior

**Deliverable**: Protected entries are not evicted

### Step 7: Integration and Testing (Week 7-8)

**Goal**: Full integration and validation

1. Update all call sites in `server_context_impl`
2. Add integration tests comparing legacy vs. hybrid modes
3. Add stress tests for memory limits
4. Add performance benchmarks
5. Document behavior differences

**Deliverable**: Phase 1 fully integrated and tested

### Step 8: Observability (Week 8)

**Goal**: Add diagnostics and metrics

1. Implement `get_stats()` for both controllers
2. Add cache metrics to `/health` endpoint
3. Add diagnostic logging for cache decisions
4. Add performance timing for cache operations
5. Document metrics and logging

**Deliverable**: Observable cache behavior

---

## Testing Strategy

### Unit Tests

**File**: `tests/test-cache-controller.cpp` (new)

```cpp
// Test mode selection
void test_cache_mode_selection();

// Test legacy wrapper matches existing behavior
void test_legacy_wrapper_compatibility();

// Test hybrid non-destructive hits
void test_hybrid_non_destructive();

// Test LRU eviction order
void test_hybrid_lru_eviction();

// Test protected roots
void test_hybrid_protected_roots();

// Test boundary metadata structures
void test_boundary_metadata();
```

### Integration Tests

**File**: `tests/test-server-cache-integration.cpp` (new)

```cpp
// Test cache across multiple requests
void test_multi_request_cache_reuse();

// Test cache hit/miss behavior
void test_cache_hit_miss_tracking();

// Test eviction under memory pressure
void test_cache_memory_limits();

// Test target/draft pairing preservation
void test_target_draft_coupling();
```

### Regression Tests

- Verify legacy mode matches current behavior exactly
- Test all existing cache-related server tests in both modes
- Verify idle slot caching works in both modes
- Test speculative decoding with cache enabled

### Performance Tests

- Measure cache hit rate on typical workloads
- Compare legacy vs. hybrid performance
- Measure memory usage patterns
- Test scalability with large caches

---

## Migration Path

### Phase 1 Deployment

1. **Default to legacy mode** for backward compatibility
2. Provide `--cache-mode hybrid` for early adopters
3. Document differences and known limitations
4. Gather feedback on hybrid mode behavior

### Future Phases

- **Phase 2**: Shared branch graphs, checkpoint-first restore
- **Phase 3**: Cold layer storage, metadata-only nodes

### Deprecation Plan (Post-Phase 3)

Once hybrid mode is proven stable and superior:
1. Change default to `--cache-mode hybrid`
2. Deprecate `--cache-mode legacy` with warning
3. Eventually remove legacy implementation

---

## Open Questions and Decisions

### Q1: Boundary Extraction Detail

**Question**: How deeply should Phase 1 integrate with the chat template engine for boundary extraction?

**Options**:
- A) Minimal: Use heuristic post-processing of formatted prompt
- B) Moderate: Add boundary tracking hooks to template engine
- C) Deep: Fully integrate boundaries into template compilation

**Recommendation**: Start with (A) for Phase 1, transition to (B) in Phase 2. Phase 1 should prove the architecture without requiring template engine changes.

### Q2: Protection Mechanism

**Question**: How should entries be marked as protected in Phase 1?

**Options**:
- A) Manual API: Explicit endpoint to mark cache entries as protected
- B) Heuristic: Automatically protect entries with system prompts
- C) Policy-based: Configure protection rules via server settings
- D) Deferred: No automatic protection in Phase 1, add in Phase 2

**Recommendation**: (D) for Phase 1 - add the `protected_root` flag but don't automatically set it. This allows the architecture to exist without adding complexity. Phase 2 can add policy-based protection.

### Q3: Metadata Transport

**Question**: Should `prepared_prompt_metadata` be part of `server_task` or a separate parallel structure?

**Options**:
- A) Part of `server_task`: Direct field access
- B) Separate structure: Passed alongside task
- C) Optional attachment: Task holds `std::optional<prepared_prompt_metadata>`

**Recommendation**: (A) - Direct field in `server_task`. Simpler to implement and maintain. Can always refactor later if needed.

---

## Success Criteria

Phase 1 is complete when:

✅ Legacy mode works identically to current implementation  
✅ Hybrid mode can be enabled via `--cache-mode hybrid`  
✅ Hybrid mode preserves cache entries after hits  
✅ LRU eviction works correctly under memory pressure  
✅ Protected root mechanism exists (even if not automatically used)  
✅ Prepared-prompt metadata structures are defined and transported  
✅ All existing cache-related tests pass in both modes  
✅ New Phase 1 tests achieve >90% coverage of new code  
✅ Documentation explains mode differences  
✅ Zero performance regression in legacy mode

---

## Appendix: File Map

### New Files

```
tools/server/
├── server-cache-controller.h          # Abstract interface
├── server-cache-controller.cpp        # Factory function
├── server-cache-legacy.h              # Legacy wrapper
├── server-cache-legacy.cpp
├── server-cache-hybrid.h              # Phase 1 hybrid implementation
└── server-cache-hybrid.cpp

tests/
├── test-cache-controller.cpp          # Unit tests
└── test-server-cache-integration.cpp  # Integration tests
```

### Modified Files

```
common/common.h                        # Add cache_mode enum
tools/server/main.cpp                  # Add --cache-mode arg
tools/server/server-task.h             # Add boundary metadata structs
tools/server/server-task.cpp           # Add metadata to task creation
tools/server/server-context.h          # Change prompt_cache to cache_ctrl
tools/server/server-context.cpp        # Use cache_controller interface
tools/server/server-chat.cpp           # Add boundary extraction (placeholder)
```

---

## References

- [cache-handling-requirements.md](cache-handling-requirements.md) - Full requirements
- [cache-handling-architecture.md](cache-handling-architecture.md) - Overall architecture
- [AGENTS.md](../AGENTS.md) - Contribution guidelines
- [llama.cpp server documentation](../tools/server/README.md)

---

**End of Phase 1 Design Document**
