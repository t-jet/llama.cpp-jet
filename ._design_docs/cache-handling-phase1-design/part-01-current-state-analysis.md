# Phase 1 Implementation Design: Alternate Hybrid Cache Mode - Part 1: Current State Analysis

Source: [../cache-handling-phase1-design.md](../cache-handling-phase1-design.md)

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
- Global eviction across all namespaces (no per-namespace fairness in Phase 1)

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

### 1. Cache Mode Selection and Namespace Identification

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

