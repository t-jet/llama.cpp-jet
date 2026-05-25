# Phase 1 Implementation Design: Alternate Hybrid Cache Mode - Part 5: continued-5

Source: [../cache-handling-phase1-design.md](../cache-handling-phase1-design.md)

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
    entry.namespace_id = compute_namespace_id();  // Assign to current namespace
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
    // Count entries per namespace
    std::map<std::string, size_t> entries_per_namespace;
    for (const auto & entry : entries) {
        entries_per_namespace[entry.namespace_id]++;
    }
    
    return json {
        {"mode", "hybrid"},
        {"entries", entries.size()},
        {"namespaces", entries_per_namespace.size()},
        {"entries_per_namespace", entries_per_namespace},
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
    
    // Determine namespace for this request
    const std::string request_namespace = compute_namespace_id();
    
    auto it_best = entries.end();
    int lcp_best = -1;
    float score_best = -1.0f;
    
    for (auto it = entries.begin(); it != entries.end(); ++it) {
        // Phase 1: Enforce namespace isolation
        if (it->namespace_id != request_namespace) {
            continue;  // Skip entries from different namespaces
        }
        
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
```
