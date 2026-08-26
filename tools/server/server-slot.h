#pragma once

// server_slot full definition. Previously inline at server-context.cpp:239..901.
// Stage 25: moved to a header so hybrid_cache_controller transaction methods
// (tx_save / tx_load / tx_restore / tx_apply_restore, defined in
// server-cache-hybrid.cpp) can access slot members without taking a separate
// copy. Both server-context.cpp and the cache layer include this header.

#include "common.h"
#include "server-task.h"
#include "server-common.h"

#include "llama.h"
#include "mtmd.h"
#include "sampling.h"
#include "speculative.h"

#include <nlohmann/json.hpp>

#include <cinttypes>
#include <cstdint>
#include <functional>
#include <list>
#include <map>
#include <memory>
#include <string>
#include <vector>

// Stage 25: slot_state enum moved from server-context.cpp so server_slot
// in this header can use it as the type of the `state` member.
enum slot_state {
    SLOT_STATE_IDLE,
    SLOT_STATE_WAIT_OTHER, // after assigning a task, but waiting for parent slot to process prompt
    SLOT_STATE_STARTED,    // after assigning a task and about to process prompt
    SLOT_STATE_PROCESSING_PROMPT,
    SLOT_STATE_DONE_PROMPT,
    SLOT_STATE_GENERATING,
};

struct server_slot {
    int id;

    llama_context * ctx_tgt = nullptr;
    llama_context * ctx_dft = nullptr;

    // multimodal
    mtmd_context * mctx = nullptr;

    // speculative decoding
    common_speculative * spec;

    llama_tokens spec_draft;
    llama_tokens spec_prompt;
    std::vector<int32_t> spec_i_batch;
    common_prompt_checkpoint spec_ckpt;

    // TODO: move members that belong to the task (such as `generated_text`, `has_new_line`) to task_results_state
    //       see https://github.com/ggml-org/llama.cpp/pull/18283#issuecomment-3710175837
    std::unique_ptr<const server_task> task;
    std::unique_ptr<const server_task> task_prev; // used for debugging

    // used to determine the slot that has been used the longest
    int64_t t_last_used = -1;

    // generation props
    int32_t n_ctx       = 0;  // context size per slot
    int32_t n_keep      = 0;
    int32_t n_decoded   = 0;
    int32_t n_remaining = -1;
    int32_t i_batch     = -1;

    int32_t n_prompt_tokens_cache     = 0;
    int32_t n_prompt_tokens_processed = 0;
    bool    hybrid_cache_restored     = false;

    size_t last_nl_pos = 0;

    std::string  generated_text;
    std::string  debug_generated_text;
    llama_tokens generated_tokens;

    std::vector<completion_token_output> generated_token_probs;

    bool has_next_token = true;
    bool has_new_line   = false;
    bool truncated      = false;

    stop_type stop;

    std::string stopping_word;

    // state
    slot_state state = SLOT_STATE_IDLE;

    server_prompt prompt;
    prepared_prompt_metadata prompt_metadata;
    bool checkpoints_enabled = true;
    uint64_t hybrid_cache_branch_node_id = 0;

    static size_t checkpoints_size(const server_prompt & src_prompt) {
        size_t total = 0;
        for (const auto & ckpt : src_prompt.checkpoints) {
            total += ckpt.size();
        }
        return total;
    }

    size_t trim_checkpoints(server_prompt & dst_prompt, size_t max_bytes, const char * reason) const {
        size_t total = checkpoints_size(dst_prompt);
        size_t removed = 0;

        while (dst_prompt.checkpoints.size() > 1 && total > max_bytes) {
            const auto & cur = dst_prompt.checkpoints.front();

            SLT_WRN(*this,
                    "erasing old context checkpoint due to %s limit (pos_min = %d, pos_max = %d, n_tokens = %" PRId64 ", size = %.3f MiB)\n",
                    reason,
                    cur.pos_min,
                    cur.pos_max,
                    cur.n_tokens,
                    (float) cur.size() / 1024 / 1024);

            total -= cur.size();
            dst_prompt.checkpoints.erase(dst_prompt.checkpoints.begin());
            removed++;
        }

        return removed;
    }

    size_t trim_checkpoints_for_allocation(server_prompt & dst_prompt, size_t max_bytes, size_t reserve_bytes, const char * reason) const {
        if (max_bytes == 0 || reserve_bytes == 0) {
            return 0;
        }

        size_t total = checkpoints_size(dst_prompt);
        size_t removed = 0;

        while (!dst_prompt.checkpoints.empty() && total + reserve_bytes > max_bytes) {
            const auto & cur = dst_prompt.checkpoints.front();

            SLT_WRN(*this,
                    "erasing old context checkpoint due to %s limit (pos_min = %d, pos_max = %d, n_tokens = %" PRId64 ", size = %.3f MiB)\n",
                    reason,
                    cur.pos_min,
                    cur.pos_max,
                    cur.n_tokens,
                    (float) cur.size() / 1024 / 1024);

            total -= cur.size();
            dst_prompt.checkpoints.erase(dst_prompt.checkpoints.begin());
            removed++;
        }

        return removed;
    }

    void disable_checkpoints(const char * reason) {
        if (checkpoints_enabled) {
            checkpoints_enabled = false;

            const size_t n_cleared = prompt.checkpoints.size();
            prompt.checkpoints.clear();
            spec_ckpt.clear();

            SLT_WRN(*this,
                    "disabling further context checkpoints for this task after %s; cleared %zu saved checkpoints\n",
                    reason,
                    n_cleared);
        }
    }

    bool checkpoint_update_tgt(common_prompt_checkpoint & ckpt, llama_state_seq_flags flags) const {
        if (ctx_tgt == nullptr) {
            return true;
        }

        const size_t ckpt_size = llama_state_seq_get_size_ext(ctx_tgt, id, flags);

        try {
            ckpt.data_tgt.resize(ckpt_size);
        } catch (const std::bad_alloc & e) {
            SLT_ERR(*this, "failed to allocate target checkpoint state (%zu bytes): %s\n", ckpt_size, e.what());
            ckpt.clear_tgt();
            return false;
        }

        const size_t n = llama_state_seq_get_data_ext(ctx_tgt, ckpt.data_tgt.data(), ckpt_size, id, flags);
        if (n != ckpt_size) {
            SLT_ERR(*this, "failed to save target checkpoint state: expected %zu bytes, got %zu\n", ckpt_size, n);
            ckpt.clear_tgt();
            return false;
        }

        return true;
    }

    bool checkpoint_update_dft(common_prompt_checkpoint & ckpt, llama_state_seq_flags flags) const {
        if (ctx_dft == nullptr) {
            return true;
        }

        const size_t ckpt_size = llama_state_seq_get_size_ext(ctx_dft, id, flags);

        try {
            ckpt.data_dft.resize(ckpt_size);
        } catch (const std::bad_alloc & e) {
            SLT_ERR(*this, "failed to allocate draft checkpoint state (%zu bytes): %s\n", ckpt_size, e.what());
            ckpt.clear_dft();
            return false;
        }

        const size_t n = llama_state_seq_get_data_ext(ctx_dft, ckpt.data_dft.data(), ckpt_size, id, flags);
        if (n != ckpt_size) {
            SLT_ERR(*this, "failed to save draft checkpoint state: expected %zu bytes, got %zu\n", ckpt_size, n);
            ckpt.clear_dft();
            return false;
        }

        return true;
    }

    bool prompt_save(server_prompt_cache & prompt_cache, bool move_metadata = false) {
        const size_t cur_size_tgt =           llama_state_seq_get_size_ext(ctx_tgt, id, LLAMA_STATE_SEQ_FLAGS_NONE);
        const size_t cur_size_dft = ctx_dft ? llama_state_seq_get_size_ext(ctx_dft, id, LLAMA_STATE_SEQ_FLAGS_NONE) : 0;

        const size_t cur_size = cur_size_tgt + cur_size_dft;

        SRV_WRN(" - saving prompt with length %d, total state size = %.3f MiB (draft: %.3f MiB)\n",
                (int) prompt.tokens.size(), cur_size / (1024.0 * 1024.0), cur_size_dft / (1024.0 * 1024.0));

        auto * cur = prompt_cache.alloc(prompt, cur_size_tgt, cur_size_dft);
        if (cur == nullptr) {
            return false;
        }

        const size_t n_tgt = llama_state_seq_get_data_ext(ctx_tgt, cur->data.main.data(), cur_size_tgt, id, LLAMA_STATE_SEQ_FLAGS_NONE);
        if (n_tgt != cur_size_tgt) {
            SLT_ERR(*this, "failed to save target state: expected %zu bytes, got %zu\n", cur_size_tgt, n_tgt);
            prompt_cache.discard(&cur->prompt);
            return false;
        }

        if (ctx_dft) {
            const size_t n_dft = llama_state_seq_get_data_ext(ctx_dft, cur->data.drft.data(), cur_size_dft, id, LLAMA_STATE_SEQ_FLAGS_NONE);
            if (n_dft != cur_size_dft) {
                SLT_ERR(*this, "failed to save draft state: expected %zu bytes, got %zu\n", cur_size_dft, n_dft);
                prompt_cache.discard(&cur->prompt);
                return false;
            }
        }

        if (move_metadata) {
            cur->prompt.tokens = std::move(prompt.tokens);
            cur->prompt.checkpoints = std::move(prompt.checkpoints);
        } else {
            cur->prompt.tokens = prompt.tokens.clone();
            cur->prompt.checkpoints = prompt.checkpoints;
        }

        trim_checkpoints(cur->prompt, cur_size, "prompt cache checkpoint memory");

        return true;
    }

    bool prompt_load(server_prompt_cache & prompt_cache, const server_tokens & tokens) {
        bool res = prompt_cache.load(prompt, tokens, ctx_tgt, ctx_dft, id);
        if (!res) {
            SLT_WRN(*this, "%s", "failed to load prompt from cache\n");
        }

        return res;
    }

    void prompt_clear(bool allow_processing) {
        if (!allow_processing) {
            GGML_ASSERT(!is_processing());
        }

        SLT_INF(*this, "clearing prompt with %zu tokens\n", prompt.tokens.size());

        llama_memory_seq_rm(llama_get_memory(ctx_tgt), id, -1, -1);
        if (ctx_dft) {
            llama_memory_seq_rm(llama_get_memory(ctx_dft), id, -1, -1);
        }

        prompt.tokens.clear();
        prompt_metadata.clear();
        hybrid_cache_restored = false;
        if (hybrid_cache_branch_node_id != 0) {
            if (callback_on_branch_ref_release) {
                callback_on_branch_ref_release(hybrid_cache_branch_node_id);
            }
            hybrid_cache_branch_node_id = 0;
        }
    }

    std::vector<common_adapter_lora_info> lora;
    int32_t alora_invocation_start = -1;

    // sampling
    json json_schema;

    common_sampler_ptr smpl;

    llama_token sampled; // in speculative mode, this is the last accepted token

    // stats
    size_t n_sent_text = 0; // number of sent text character

    int64_t t_print_last = 0;
    int64_t t_start_process_prompt;
    int64_t t_start_generation;

    double t_prompt_processing = 0.0; // ms
    double t_token_generation = 0.0;  // ms

    std::function<void(int /* id_slot */)> callback_on_release;
    std::function<void(uint64_t /* node_id */)> callback_on_branch_ref_release;

    // Speculative decoding stats
    int32_t n_draft_total = 0;      // Total draft tokens generated
    int32_t n_draft_accepted = 0;   // Draft tokens actually accepted

    void reset() {
        SLT_DBG(*this, "%s", "\n");

        n_prompt_tokens_cache = 0;
        hybrid_cache_restored = false;

        last_nl_pos    = 0;
        generated_text = "";
        has_new_line   = false;
        truncated      = false;
        stop           = STOP_TYPE_NONE;
        stopping_word  = "";
        n_sent_text    = 0;
        checkpoints_enabled = true;

        if (can_speculate()) {
            spec_draft.clear();
            spec_i_batch.clear();
            spec_ckpt.clear();
        }
        generated_tokens.clear();
        generated_token_probs.clear();
        json_schema = json();

        // clear speculative decoding stats
        n_draft_total = 0;
        n_draft_accepted = 0;

        task_prev = std::move(task);
        task.reset();

        llama_set_sampler(ctx_tgt, id, nullptr);

        // clear alora start
        alora_invocation_start = -1;
    }

    void init_sampler() const {
        common_sampler_reset(smpl.get());

        if (!task->need_sampling()) {
            return;
        }

        const int64_t t_start = ggml_time_us();

        int n_text = 0;

        for (int i = 0; i < (int) prompt.tokens.size(); i++) {
            const llama_token id = prompt.tokens[i];

            if (id != LLAMA_TOKEN_NULL) {
                common_sampler_accept(smpl.get(), id, false);
                n_text++;
            }
        }

        SLT_TRC(*this, "init sampler, took %0.2f ms, tokens: text = %d, total = %d\n",
                (ggml_time_us() - t_start) / 1000.0, n_text, (int) prompt.tokens.size());
    }

    bool need_embd() const {
        GGML_ASSERT(task);
        return task->need_embd();
    }

    // if the context does not have a memory module then all embeddings have to be computed within a single ubatch
    // also we cannot split if the pooling would require any past tokens
    // (MTP supports splitting — uses task->need_embd() not need_embd())
    bool can_split() const {
        GGML_ASSERT(task);

        return
            !task->need_embd() ||
            (llama_get_memory(ctx_tgt) && llama_pooling_type(ctx_tgt) == LLAMA_POOLING_TYPE_LAST);
    }

    bool can_batch_with(server_slot & other_slot) const {
        GGML_ASSERT(task);

        return task->type == other_slot.task->type && are_lora_equal(lora, other_slot.lora);
    }

    bool has_budget(const common_params & global_params) {
        GGML_ASSERT(task);

        if (task->params.n_predict == -1 && global_params.n_predict == -1) {
            return true; // limitless
        }

        n_remaining = -1;

        if (task->params.n_predict != -1) {
            n_remaining = task->params.n_predict - n_decoded;
        } else if (global_params.n_predict != -1) {
            n_remaining = global_params.n_predict - n_decoded;
        }

        return n_remaining > 0; // no budget
    }

    bool is_processing() const {
        return state != SLOT_STATE_IDLE;
    }

    bool can_speculate() const {
        return !!spec;
    }

    void add_token(const completion_token_output & token) {
        if (!is_processing()) {
            SLT_WRN(*this, "%s", "slot is not processing\n");
            return;
        }

        generated_token_probs.push_back(token);
    }

    int get_n_draft_max() const {
        GGML_ASSERT(task);

        if (!can_speculate()) {
            return 0;
        }

        // determine the max draft that fits the current slot state
        // note: slot.prompt is not yet expanded with the `id` token sampled above
        //       also, need to leave space for 1 extra token to allow context shifts
        int n_draft_max = n_ctx - prompt.n_tokens() - 2;

        if (n_remaining > 0) {
            n_draft_max = std::min(n_draft_max, n_remaining - 1);
        }

        SLT_DBG(*this, "max possible draft: %d\n", n_draft_max);

        return n_draft_max;
    }

    void update_batch(llama_batch & batch) {
        if (spec_draft.empty()) {
            // no speculative decoding
            i_batch = batch.n_tokens;

            common_batch_add(batch, sampled, prompt.tokens.pos_next(), { this->id }, true);

            SLT_DBG(*this, "slot decode token, id=%d, n_ctx = %d, n_tokens = %d, truncated = %d\n",
                    sampled, n_ctx, prompt.n_tokens(), truncated);
        } else {
            SLT_DBG(*this, "generate_draft: id=%d, #tokens=%zu, #draft=%zu, pos_next=%d\n",
                    sampled, prompt.tokens.size(), spec_draft.size(), prompt.tokens.pos_next());

            GGML_ASSERT(spec_i_batch.empty());

            spec_i_batch.push_back(batch.n_tokens);
            for (size_t i = 0; i < spec_draft.size(); i++) {
                spec_i_batch.push_back(batch.n_tokens + i + 1);
            }

            auto pos0 = prompt.tokens.pos_next();

            common_batch_add(batch, sampled, pos0++, { this->id }, true);
            for (auto token : spec_draft) {
                common_batch_add(batch, token, pos0++, { this->id }, true);
            }
        }

        prompt.tokens.push_back(sampled);
        prompt.tokens.insert(spec_draft);
    }

    void release() {
        if (is_processing()) {
            GGML_ASSERT(task);

            SLT_INF(*this, "stop processing: n_tokens = %d, truncated = %d\n", prompt.n_tokens(), truncated);

            t_last_used        =  ggml_time_us();
            t_token_generation = (ggml_time_us() - t_start_generation) / 1e3;

            state = SLOT_STATE_IDLE;

            // do not keep context of the child slots - the parent's context is enough
            if (task->is_child()) {
                prompt_clear(false);
            }

            reset();

            callback_on_release(id);
        }
    }

    server_slot_stats get_timings() const {
        server_slot_stats stats;
        stats.n_prompt_cached    = n_prompt_tokens_cache;
        stats.n_prompt_processed = n_prompt_tokens_processed;
        stats.n_gen              = n_decoded;

        stats.n_draft_tokens   = n_draft_total;
        stats.n_draft_accepted = n_draft_accepted;

        // map slot timing fields (absolute us timestamps + ms durations) to server_slot_stats
        stats.t_start       = t_start_process_prompt;
        stats.t_prompt_last = t_start_generation;
        stats.t_gen_last    = t_start_generation + (int64_t)(t_token_generation * 1000.0);

        return stats;
    }

    size_t find_stopping_strings(const std::string & text, const size_t last_token_size, bool is_full_stop) {
        GGML_ASSERT(task);

        size_t stop_pos = std::string::npos;

        for (const std::string & word : task->params.antiprompt) {
            size_t pos;

            if (is_full_stop) {
                const size_t tmp      = word.size() + last_token_size;
                const size_t from_pos = text.size() > tmp ? text.size() - tmp : 0;

                pos = text.find(word, from_pos);
            } else {
                // otherwise, partial stop
                pos = string_find_partial_stop(text, word);
            }

            if (pos != std::string::npos && (stop_pos == std::string::npos || pos < stop_pos)) {
                if (is_full_stop) {
                    stop           = STOP_TYPE_WORD;
                    stopping_word  = word;
                    has_next_token = false;
                }
                stop_pos = pos;
            }
        }

        return stop_pos;
    }

    void print_timings_tg() {
        if (n_decoded < 100) {
            return;
        }

        const int64_t t_now = ggml_time_us();

        if (t_now - t_print_last < 3*1000*1000) {
            return;
        }

        t_print_last = t_now;

        const double n_gen_second = 1e3 / t_token_generation * n_decoded;

        SLT_INF(*this, "n_decoded = %6d, tg = %6.2f t/s\n", n_decoded, n_gen_second);
    }

    void print_timings_pp() const {
        const double n_prompt_second = 1e3 / t_prompt_processing / n_prompt_tokens_processed * n_prompt_tokens_processed;
        const double f_progress = (float) prompt.n_tokens() / task->n_tokens();

        if (t_prompt_processing < 3000.0) {
            return;
        }

        SLT_INF(*this, "prompt processing, n_tokens = %6d, progress = %.2f, t = %6.2f s / %.2f tokens per second\n",
                n_prompt_tokens_processed, f_progress, t_prompt_processing / 1e3, n_prompt_second);
    }

    void print_timings() const {
        const double t_prompt        =       t_prompt_processing / n_prompt_tokens_processed;
        const double n_prompt_second = 1e3 / t_prompt_processing * n_prompt_tokens_processed;

        const double t_gen        =       t_token_generation / n_decoded;
        const double n_gen_second = 1e3 / t_token_generation * n_decoded;

        SLT_INF(*this,
                "prompt eval time = %10.2f ms / %5d tokens (%8.2f ms per token, %8.2f tokens per second)\n",
                t_prompt_processing, n_prompt_tokens_processed, t_prompt, n_prompt_second);

        SLT_INF(*this,
                "       eval time = %10.2f ms / %5d tokens (%8.2f ms per token, %8.2f tokens per second)\n",
                t_token_generation, n_decoded, t_gen, n_gen_second);

        SLT_INF(*this,
                "      total time = %10.2f ms / %5d tokens\n",
                t_prompt_processing + t_token_generation, n_prompt_tokens_processed + n_decoded);

        SLT_INF(*this,
                "   graphs reused = %10d\n",
                llama_perf_context(ctx_tgt).n_reused);

        if (n_draft_total > 0) {
            const float draft_ratio = (float) n_draft_accepted / n_draft_total;
            SLT_INF(*this,
                    "draft acceptance = %0.5f (%5d accepted / %5d generated)\n",
                    draft_ratio, n_draft_accepted, n_draft_total);
        }

        common_speculative_print_stats(spec);
    }

    json to_json(bool only_metrics = false) const {
        json res;

        res = {
            {"id",            id},
            {"n_ctx",         n_ctx},
            {"speculative",   can_speculate()},
            {"is_processing", is_processing()},
        };

        const auto & ptask = task ? task : task_prev;

        if (ptask) {
            res["id_task"] = ptask->id;
            res["n_prompt_tokens"]           = (int32_t) prompt.tokens.size();
            res["n_prompt_tokens_processed"] = n_prompt_tokens_processed;
            res["n_prompt_tokens_cache"]     = n_prompt_tokens_cache;
            res["params"] = ptask->params.to_json(only_metrics);
            res["next_token"] = {
                {
                    {"has_next_token", has_next_token},
                    {"has_new_line",   has_new_line},
                    {"n_remain",       n_remaining},
                    {"n_decoded",      n_decoded},
                }
            };

            if (!only_metrics) {
                res["prompt"] = ptask->tokens.detokenize(ctx_tgt, true);
                res["generated"] = generated_text.empty() ? debug_generated_text : generated_text;
            }
        }

        return res;
    }

    void copy_state_to(server_slot & other) const {
        GGML_ASSERT(state == SLOT_STATE_DONE_PROMPT);

        llama_memory_seq_rm(llama_get_memory(ctx_tgt), other.id,     -1, -1);
        llama_memory_seq_cp(llama_get_memory(ctx_tgt), id, other.id, -1, -1);

        if (ctx_dft) {
            llama_memory_seq_rm(llama_get_memory(ctx_dft), other.id,     -1, -1);
            llama_memory_seq_cp(llama_get_memory(ctx_dft), id, other.id, -1, -1);
        }

        other.n_decoded   = n_decoded;
        other.n_remaining = n_remaining;
        other.i_batch     = i_batch;

        other.t_start_process_prompt    = t_start_process_prompt;
        other.t_prompt_processing       = t_prompt_processing;
        other.n_prompt_tokens_cache     = n_prompt_tokens_cache;
        other.n_prompt_tokens_processed = n_prompt_tokens_processed;

        other.prompt = prompt.clone();
        other.init_sampler();
    }
};
