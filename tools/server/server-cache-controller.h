#pragma once

#include "server-task.h"
#include "server-common.h"
#include "common.h"
#include "llama.h"

#include <memory>

// Forward declarations
struct server_prompt;
struct server_slot;

// Abstract cache controller interface for prompt caching
// Implementations:
//   - legacy_cache_controller: wraps existing server_prompt_cache
//   - hybrid_cache_controller: new LRU-based non-destructive cache
class cache_controller {
public:
    virtual ~cache_controller() = default;

    // Save slot state to cache
    // Returns true if successful
    virtual bool save_slot(server_slot & slot, const prepared_prompt_metadata & metadata) = 0;

    // Load matching cache entry into slot
    // Returns true if a match was found and loaded
    virtual bool load_slot(server_slot & slot, const server_task & task) = 0;

    // Non-destructive cache restore (for hybrid mode)
    // Returns true if a matching entry was found and restored
    // Default implementation calls load_slot for backwards compatibility
    virtual bool try_restore_from_cache(server_slot & slot, const server_task & task) {
        // Default: use standard load_slot (works for legacy cache)
        return load_slot(slot, task);
    }

    virtual void release_branch_node_ref(uint64_t node_id) {
        GGML_UNUSED(node_id);
    }

    // Perform cache maintenance (eviction, cleanup)
    virtual void update() = 0;

    // Get cache statistics
    virtual json get_stats() const = 0;

    // Get current cache size in bytes
    virtual size_t size() const = 0;

    // Get total number of tokens cached
    virtual size_t n_tokens() const = 0;
};

// Factory function to create appropriate cache controller based on mode
std::unique_ptr<cache_controller> create_cache_controller(
    cache_mode mode,
    const common_params & params,
    int32_t limit_size_mib,
    size_t limit_tokens,
    llama_context * ctx_tgt,
    llama_context * ctx_dft,
    const std::string & cold_path = "");
