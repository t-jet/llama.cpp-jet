# Patch Notes - Part 2: E. Harden prompt-cache save and slot handoff in `tools/server/server-context.cpp`, `tools/server/server-task.cpp`, and `tools/server/server-task.h`

Source: [../fix-qwen-eval-2.md](../fix-qwen-eval-2.md)

### E. Harden prompt-cache save and slot handoff in `tools/server/server-context.cpp`, `tools/server/server-task.cpp`, and `tools/server/server-task.h`

The current upstream-relative prompt-cache hardening remains in place:

- `server_slot::prompt_save()` now returns `bool`
- exact byte counts are validated for both target and draft export
- failed exports discard the incomplete cached prompt instead of leaving a half-initialized entry behind
- the save path can move prompt metadata into the cache during slot reuse to avoid duplicating large token / checkpoint metadata in host RAM
- cached checkpoint lists are trimmed after save
- `server_prompt_cache::alloc()` only reserves the state buffers and no longer clones all metadata up front
- `server_prompt_cache::discard()` is declared in `tools/server/server-task.h` and defined in `tools/server/server-task.cpp` to remove incomplete cache entries explicitly

### F. Make checkpoint export fail-soft and trim before allocation in `tools/server/server-context.cpp`

The checkpoint logic is still substantially more conservative than upstream:

- `checkpoint_update_tgt()` and `checkpoint_update_dft()` catch `std::bad_alloc`, validate exact byte counts, and return failure instead of assuming export succeeded
- `checkpoints_enabled` disables further checkpoint creation for the task after the first export failure
- `disable_checkpoints(...)` clears saved live checkpoints and speculative checkpoint state
- `trim_checkpoints_for_allocation(...)` evicts old checkpoints before the next checkpoint buffer is allocated
- live checkpoint creation and speculative checkpoint creation both use the fail-soft helpers
- speculative checkpoint export failure clears the speculative draft/checkpoint path for that step instead of aborting

### G. Enforce prompt-cache limits on both admission and eviction in `tools/server/server-task.cpp`

The retained prompt-cache limit fix still has two parts.

First, admission is screened before the new cache entry is created:

- estimated size is computed as `prompt.size() + state_size_tgt + state_size_dft`
- oversized prompt state is skipped immediately
- over-token-limit prompts are skipped immediately too

Second, eviction is no longer forced to keep one state alive:

- `update()` now evicts while the cache is non-empty and still over size or token budget
- the final oversized entry can be removed too

### H. Remove the response-queue logging race in `tools/server/server-queue.cpp`

The queue fix is unchanged in intent:

- move the `RES_DBG(...) waiting_task_ids.size()` reads under `mutex_results` in `add_waiting_task_id()` and `remove_waiting_task_id()`

## 3. Possible Effects On Other Functionality

### More conservative speculative prompt prefill

Because speculative MTP prompt slices are bounded more aggressively than upstream, prompt-prefill throughput may be somewhat lower on some systems.

Effect:

- very large MTP prompts may be processed in more, smaller prompt batches
- peak host-output pressure is lower
- first-request stability is favored over maximum prompt-prefill throughput

### Prompt-cache save can reject very large states earlier

Because oversized states are now screened at admission time, some large prompts that upstream would try to cache are skipped immediately.

Effect:

- host prompt caching may be used less often for the largest prompts
- later requests may replay more tokens instead of restoring from host cache
- cache RAM usage is better bounded

### Cache can become empty after pressure instead of keeping one huge entry

This branch no longer guarantees that one cached prompt survives if that prompt itself violates the cache budget.

Effect:

- prompt reuse may temporarily drop to zero after an allocation failure
- the configured cache limit becomes enforceable in practice

### Checkpoint reuse degrades sooner after one export failure

Once checkpoint export fails for a task, this branch disables further checkpoints for that task.

Effect:

- rollback / reuse quality may degrade for the remainder of that task
- the server avoids repeatedly re-entering the same failing high-memory export path

### MTP startup is less aggressive than upstream

Because pipeline parallelism is disabled for `LLAMA_CONTEXT_TYPE_MTP`, the draft MTP context no longer follows the same startup scheduling path as upstream.

Effect:

- startup avoids the observed reserve/fallback/CUDA-error path on this workload
- draft-context startup and steady-state scheduling may be slightly more conservative than upstream on multi-GPU systems

### `--fit` becomes more conservative again for `draft-mtp`

Because the fit hook is active again, `--fit` once more pre-reserves extra headroom for the later MTP draft context on the margins it can represent.

Effect:

- GPU-fit results for `draft-mtp` can become more conservative again, which is the intended effect
- this directly addresses the original stage-one undercount where fit ran before the later MTP context existed
- host overhead is still not fully enforced for GPU-backed runs because the current fit API has only per-device margins

### MTP target behavior intentionally differs from upstream

This remains the most important upstream-relative behavior difference.

Effect:

- upstream uses the unmasked target pre-norm path for this speculative caller
- this branch keeps the target on masked output rows so the server-side batching logic and speculative hidden-state extraction stay aligned on this workload

### Verification status for this upstream-relative addendum

This document now reflects the current code state relative to current `origin/master`, not the earlier rebased state captured by the previous draft.

At the time of writing:

- the retained checked-out diff against `origin/master` now spans the nine files listed at the top of this document
- the current upstream base already includes `#23269`
- later branch fixes after that rebase include the `need_embd_pre_norm()` batching correction and the MTP startup pipeline-parallel mitigation
- the original stage-one fit-hook behavior has now also been restored in `common/common.cpp`
- the branch has been reviewed against the current source tree and current upstream-relative diff
- a fresh end-to-end soak run after the latest branch state is not recorded here
- a fresh in-editor CMake Tools build confirmation is still unavailable in this environment because of the MSVC feature-detection/configure issue

So this addendum should now be read as an accurate inventory of the current retained changes relative to `origin/master`, including the later follow-up fixes, but not as a claim that a new full validation cycle has already completed.
