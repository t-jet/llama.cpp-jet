# Patch Notes - Part 2: A. Account for MTP draft-context overhead during `-fit`

Source: [../fix-qwen-summary.md](../fix-qwen-summary.md)

### A. Account for MTP draft-context overhead during `-fit`

The `common/` side of the change keeps the dedicated helper in [common/fit.cpp](common/fit.cpp) and [common/fit.h](common/fit.h):

- `common_get_mtp_ctx_memory_overhead(...)`

That helper:

- loads the model with `no_alloc = true`
- creates a temporary `llama_context` with `ctx_type = LLAMA_CONTEXT_TYPE_MTP`
- forces `n_rs_seq = 0` for that temporary MTP measurement context
- reads the memory breakdown from the constructed context
- sums only `context + compute` overhead per device and for host memory

In the current branch state, [common/common.cpp](common/common.cpp) uses that helper when all of the following are true:

- fitting is enabled
- `draft-mtp` is active
- there is no separate draft model

Instead of mutating the user's original fit targets, the code copies `params.fit_params_target` into a temporary `fit_targets` vector, adds the measured MTP overhead to the device margins, and passes the adjusted margins into `common_fit_params()`.

Important current caveat:

- the current fit API still consumes per-device margins only
- so the helper's host-memory entry can be enforced only in the host-only case
- for GPU-backed runs the host overhead is logged, but not fully enforced by the current fit API

This leaves enough GPU headroom for the MTP context that the server creates at runtime.

### B. Harden prompt-cache save

The prompt-cache path was changed so that `prompt_save()` now:

- checks the exact byte count returned by `llama_state_seq_get_data_ext()` for both target and draft state
- discards incomplete cache entries if state export fails
- returns failure instead of leaving a partially initialized cache record behind

Related cache-management changes in `server_prompt_cache` support that behavior:

- `alloc()` now focuses on reserving the state buffers first, instead of eagerly cloning the full prompt metadata during allocation
- `discard()` removes incomplete cache entries when prompt export fails mid-save

This turns prompt-cache save from a crash-prone path into a recoverable path.

### C. Avoid duplicating the full checkpoint list during cache save

When a slot is being repurposed, the old code effectively kept two large copies of prompt metadata alive at once:

- the live slot prompt and checkpoints
- the cached prompt and checkpoints being written into RAM

The fix changes this to move prompt metadata into the cache when appropriate, then clear the live slot before reloading. That removes a major temporary RAM spike during slot reuse.

### D. Add fail-soft checkpoint export helpers

The server now has dedicated helpers for checkpoint export of target and draft state. These helpers:

- allocate checkpoint buffers explicitly
- catch `std::bad_alloc`
- validate the exact number of bytes returned by state export
- clear the failed checkpoint buffer and report failure instead of aborting the process

This logic is used for:

- normal prompt-processing checkpoints
- speculative / MTP checkpoint paths

### E. Skip invalid checkpoints instead of aborting

Checkpoint creation now builds a temporary checkpoint first and only appends it to the prompt if export succeeds. If export fails, the server logs a warning and skips that checkpoint.

That means the request can continue with less rollback coverage instead of killing the process.

### F. Trim checkpoint memory by bytes, not only by count

The count-only checkpoint limit is not enough when each checkpoint can be hundreds of MiB.

The fix adds byte-based trimming in two places:

#### 1. Live slot checkpoints

- before creating a new checkpoint, old checkpoints can be evicted so the next allocation fits the intended budget
- after creating a checkpoint, old checkpoints are dropped until total checkpoint bytes are bounded more realistically

#### 2. Cached prompt checkpoints

- before keeping a prompt in the host prompt cache, its checkpoint list is trimmed using a similar budget

This keeps caching enabled while preventing checkpoint memory from growing far beyond the size of the actual reusable state.

### G. Keep speculative decoding functional when checkpoint export fails

The speculative checkpoint path now degrades gracefully:

- if speculative checkpoint export fails, the speculative draft / checkpoint is cleared for that step
- the server continues without using that speculative checkpoint rather than aborting

This keeps `draft-mtp` usable even under high memory pressure.

### H. Adapt speculative prompt handling to current `origin/master`

Relative to current `origin/master`, which already offloads MTP draft sampling to the backend when available, the current branch additionally treats speculative MTP prompt hidden-state demand as an output-row requirement in the server batching logic.

The current branch state:

- treats speculative MTP pre-norm needs as output-row needs through `server_slot::need_embd()` by folding in both `common_speculative_need_embd(spec)` and `common_speculative_need_embd_pre_norm(spec)`
- keeps the MTP target pre-norm path on masked rows in `common/speculative.cpp`
- preserves the masked/unmasked extraction split in `src/llama-context.cpp`
- uses a bounded `n_batch_prompt` for speculative prompt prefill
- keeps batch-wide `llama_set_embeddings(ctx_tgt, ...)` tied to actual embedding requests only

This preserves first-request protection while staying compatible with the current upstream speculative code.

### I. Disable pipeline parallelism for `LLAMA_CONTEXT_TYPE_MTP`

The current branch disables pipeline parallelism up front for `LLAMA_CONTEXT_TYPE_MTP` in `src/llama-context.cpp`.

This is scoped narrowly because pipeline parallelism is only an optimization here and it increases memory usage during graph reservation. On this workload, the MTP draft context was the one that entered the failing reserve/retry path, so disabling it for `LLAMA_CONTEXT_TYPE_MTP` avoids that unstable startup path while leaving non-MTP contexts unchanged.

That is specifically to avoid the startup-time draft-context reserve/fallback failure seen on this workload.

### J. Remove the response-queue logging race

The response-queue fix moves the `waiting_task_ids.size()` debug reads under `mutex_results` in:

- `server_response::add_waiting_task_id()`
- `server_response::remove_waiting_task_id()`

This removes the debug-level data race without changing queue semantics.

### K. Add a runtime exception barrier around the main queue callbacks

The current branch now wraps the queue callbacks that drive:

- task scheduling
- slot updates
- sleeping-state transitions

Escaped `std::bad_alloc` and other standard exceptions in task scheduling or slot updates are now:

- logged explicitly
- converted into task errors when possible
- followed by slot release and prompt clearing for any affected active slots

For parent tasks, the same failure handling is applied to the whole task family so child tasks do not remain waiting indefinitely.

Sleeping-state callback exceptions are logged and terminate the queue loop cleanly instead of unwinding out of the main server loop.

Important caveat:

- this hardening covers escaped standard exceptions
- it does not intercept explicit `GGML_ABORT` paths or backend-level fatal failures

### L. Reset cached state in the GGML meta-buffer reset path

The current branch now hardens `ggml_backend_meta_buffer_reset()` in `ggml/src/ggml-backend-meta.cpp`.

The reset path now:

- clears the cached split-state map
- clears the cached simple-tensor map
- calls `ggml_reset()` on each per-buffer ggml context
- resets each child backend buffer afterwards

This keeps per-reset tensor/context state from leaking into the next graph allocation cycle.

Important caveat:

- this is a coherence fix for repeated reuse of the meta backend
- it does not convert allocator aborts into recoverable runtime errors if some other backend-level failure still occurs

## 3. Possible Effects On Other Functionality

### Fit may choose more conservative settings for `draft-mtp`

Because MTP draft-context overhead is included in the active fit margins, automatic fitting may choose a smaller context size or otherwise leave more headroom on GPU devices than `origin/master`.

Effect:

- `-fit` results for `draft-mtp` can become more conservative
- this is expected, because the baseline fit result undercounts real runtime memory on this workload
- host overhead is still not fully enforced for GPU-backed runs because the current fit API has only per-device margins
- non-MTP and separate-draft-model configurations should otherwise be unchanged by this logic

### Slightly longer startup when `-fit` and `draft-mtp` are both used

The helper creates a temporary MTP context to measure overhead before the final fit decision is applied.

Effect:

- startup can do one extra model/context measurement pass in this specific configuration
- this only affects the fitting path, not steady-state generation

### More conservative speculative prompt prefill

Because speculative MTP prompt slices are bounded more aggressively than `origin/master`, prompt-prefill throughput may be somewhat lower on some systems.

Effect:

- very large MTP prompts may be processed in more, smaller prompt batches
- peak host-output pressure is lower
- first-request stability is favored over maximum prompt-prefill throughput

### Reduced rollback depth in long sessions

Because checkpoints are now trimmed by bytes as well as by count, long-running sessions may keep fewer old checkpoints than a count-only policy, especially on recurrent / MTP models with large checkpoint payloads.

Effect:

- rollback may fall back to a newer checkpoint and replay a slightly longer suffix
- prompt reuse still works, but some restores may save less work in the extreme long-context case

### Graceful degradation instead of hard failure

If checkpoint export or speculative checkpoint export fails, the server now skips the checkpoint.

Effect:

- some requests may lose a reuse optimization for that step
- the server stays alive instead of terminating

This is an intentional tradeoff in favor of stability.

### Slightly different cache contents

Cached prompt entries may now retain fewer checkpoints because oversized checkpoint lists are trimmed before the prompt is stored in RAM.

Effect:

- host cache still works
- cross-request or cross-slot resume may sometimes require replaying a longer suffix
- total RAM use is significantly better bounded

### MTP startup is less aggressive than `origin/master`

Because pipeline parallelism is disabled for `LLAMA_CONTEXT_TYPE_MTP`, the draft MTP context no longer follows the same startup scheduling path as `origin/master`.

Effect:

- startup avoids the observed reserve/fallback/CUDA-error path on this workload
- draft-context startup and steady-state scheduling may be slightly more conservative than `origin/master` on multi-GPU systems

### Severe host-memory pressure may fail requests instead of killing the server

Because the main queue callbacks now catch escaped standard exceptions, severe host-memory pressure can now degrade into request failure instead of immediate process termination.

Effect:

- escaped `std::bad_alloc` and other standard exceptions in task scheduling or slot updates are logged and translated into task errors when possible
- affected slots are released and their prompt state is cleared before reuse
- explicit `GGML_ABORT` and backend-level fatal failures are still outside this guard

### Slightly more work on meta-buffer reset paths

Because the GGML meta-buffer reset now clears cached split/tensor state and resets the child ggml contexts, the next graph allocation cycle may have to rebuild that cached metadata.

Effect:

- repeated graph reuse after reset may do a bit more setup work than before
- this is intended to preserve allocator correctness across reset boundaries

