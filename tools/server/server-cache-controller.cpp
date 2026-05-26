#include "server-cache-controller.h"
#include "server-cache-legacy.h"   // Wrapper for existing implementation
#include "server-cache-hybrid.h"   // New hybrid implementation

std::unique_ptr<cache_controller> create_cache_controller(
    cache_mode mode,
    const common_params & params,
    int32_t limit_size_mib,
    size_t limit_tokens,
    llama_context * ctx_tgt,
    llama_context * ctx_dft)
{
    switch (mode) {
        case CACHE_MODE_LEGACY:
            return std::make_unique<legacy_cache_controller>(
                params, limit_size_mib, limit_tokens, ctx_tgt, ctx_dft);

        case CACHE_MODE_HYBRID:
            return std::make_unique<hybrid_cache_controller>(
                params, limit_size_mib, limit_tokens, ctx_tgt, ctx_dft);

        default:
            throw std::invalid_argument("invalid cache mode");
    }
}
