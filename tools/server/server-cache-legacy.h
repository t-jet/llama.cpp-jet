#pragma once

#include "server-cache-controller.h"
#include "server-task.h"

// Forward declarations
struct server_slot;

// Wrapper around existing server_prompt_cache to implement cache_controller interface
// This maintains exact legacy behavior: FIFO eviction and destructive cache hits
class legacy_cache_controller : public cache_controller {
public:
    legacy_cache_controller(
        const common_params & params,
        int32_t limit_size_mib,
        size_t limit_tokens,
        llama_context * ctx_tgt,
        llama_context * ctx_dft);

    ~legacy_cache_controller() override = default;

    // Cache controller interface implementation
    bool save_slot(server_slot & slot, const prepared_prompt_metadata & metadata) override;
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
