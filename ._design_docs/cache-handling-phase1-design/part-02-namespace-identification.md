# Phase 1 Implementation Design: Alternate Hybrid Cache Mode - Part 2: Namespace Identification

Source: [../cache-handling-phase1-design.md](../cache-handling-phase1-design.md)

#### Namespace Identification

Phase 1 implements basic namespace support to enable multi-model operation:

```cpp
// Compute namespace identifier from model and runtime configuration
std::string compute_namespace_id(
    const llama_model * model_tgt,
    const llama_model * model_dft,
    const common_params & params)
{
    // Phase 1: Simple hash-based namespace
    // Include: model path, draft model path (if any), key runtime flags
    std::string key = model_tgt ? llama_model_desc(model_tgt) : "";
    if (model_dft) {
        key += "|draft:" + std::string(llama_model_desc(model_dft));
    }
    // Add material runtime modifiers that affect state validity
    // (e.g., active adapters would be added here)
    
    // Simple hash for Phase 1
    return std::to_string(std::hash<std::string>{}(key));
}
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

