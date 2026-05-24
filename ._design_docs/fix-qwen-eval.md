# Patch Notes

**Disclaimer 1** This patch doesn't pretend to become a PR, just provides a record of the investigation and fix for this specific issue.
**Discaimer 2** I'm not an expert in llama-server internals, so information below produced with a help of GenAI as well as the patch itself.

## Results

Instead of crashing after three-four request in the complex agentic workflow, configuration ran for 10+ hours without crashing on the same workflow and successfully processed all requests almost at the expected speed.

## Branch and compilation.

Patch was applied on top of `main` branch at commit `64b38b561b987679c4e1c6231f93860d3eec2638` (2026-05-16).

Build was done on Win11 with Visual Studio 2026 Developer prompt and CUDA 13.1 toolkit.

CMake commands was:
```text
cmake -S . -B build-cuda -G "Visual Studio 17 2022" -A x64 -DGGML_CUDA=ON -DGGML_NATIVE=OFF -DBUILD_SHARED_LIBS=OFF
cmake --build build-cuda --config Release -j --clean-first --target llama-cli llama-mtmd-cli llama-server llama-gguf-split
```

Workstation parameters: Windows 11 Pro 25H2, AMD Ryzen 7900X, 2 x NVIDIA RTX 5060 Ti 16 GB, 64GB RAM

llama-server launch parameters:
```cmd
llama-server.exe ^
  -m c:\models\unsloth\Qwen3.6-27B-MTP-GGUF\Qwen3.6-27B-Q5_K_M.gguf ^
  --port 35762 ^
  -c 65536 ^
  --parallel 1 ^
  --flash-attn on ^
  --no-context-shift ^
  -ngl -1 ^
  --threads -1 ^
  --jinja ^
  --reasoning on ^
  --no-mmap ^
  --mlock ^
  --spec-type draft-mtp ^
  --spec-draft-n-max 3 ^
  -lv 4 ^
  --cache-type-k q8_0 ^
  --cache-type-v q8_0 ^
  --metrics
```

## Summary

This change stabilizes `llama-server` on Qwen 3.6 hybrid/recurrent workloads with `draft-mtp` enabled in two separate places where memory management was previously too optimistic:

- the fit / startup path, where MTP draft-context overhead was not included in the memory budget
- the runtime prompt-cache / checkpoint path, where large prompt state and checkpoint exports could terminate the process or accumulate excessive RAM

The commit therefore addresses two related failure modes:

- CUDA OOM during real prompt processing even though `-fit` reported that the configuration should fit
- silent exits during prompt-cache save and later during checkpoint creation on long-running cached sessions

The patch keeps caching enabled, preserves the existing reuse logic, and makes both fitting and runtime state export account for MTP / checkpoint memory more realistically.

## 1. Initial Symptoms And Diagnostic Logic

### Initial symptoms

The first symptom was not a silent exit. It was a CUDA failure during prompt processing on a later turn of a large `draft-mtp` session, even though the initial fit step had already reported that the configuration met all device-memory targets.

The relevant pattern was:

- `common_fit_params` reported that the projected memory usage fit available GPU memory
- the server then created the MTP draft context afterwards
- prompt processing failed later with a CUDA error during actual evaluation

That suggested a startup-time underestimation rather than a steady-state logic bug in the prompt processor itself.

The second symptom was a silent server exit immediately after a log line like:

```text
srv prompt_save: - saving prompt with length ..., total state size = ... MiB
```

There was no subsequent `prompt_load`, no cache-state summary, and no explicit error from the server. That strongly suggested the process was dying inside or immediately after prompt-state export, not during normal slot selection or request execution.

After the MTP fit fix, and then after the first prompt-save fix, the crash point moved. The server now survived model initialization and later survived `prompt_save`, updated the cache successfully, continued serving requests, and only died later during a subsequent long request. The new tail showed the server reaching:

- `slot init_sampler`
- then stopping before the next normal checkpoint / decode progress line

That narrowed the second failure to the checkpoint creation path or the immediate decode handoff that follows it.

### Diagnostic logic

The investigation separated the problem into three concrete paths:

1. MTP context fitting path

- `common_fit_params()` runs before the server creates the MTP draft context.
- For `draft-mtp` without a separate draft model, the fit step was only budgeting the primary context.
- The additional `ctx_type = LLAMA_CONTEXT_TYPE_MTP` context was created afterwards, so its context + compute overhead was outside the fit margins.

That explains why `-fit` could say the setup fit, but actual prompt processing still failed later with CUDA OOM once the real MTP context existed.

1. Prompt-cache save path

- `get_available_slot()` may save the old slot state before reusing the slot for a new task.
- `server_slot::prompt_save()` exported the live target and draft state into RAM and also duplicated prompt metadata, including the full checkpoint list.
- For long recurrent / MTP prompts, the live state was already large, and the checkpoint list added several more GiB of RAM pressure.

1. Checkpoint creation path

- During prompt processing, the server periodically creates rollback checkpoints for recurrent / bounded-removal contexts.
- These checkpoints were also exported through `llama_state_seq_get_data_ext()`.
- The export path assumed success and would abort the process on short-copy / mismatch behavior.

The key log evidence was:

- fit reporting sufficient headroom before the MTP context existed
- the MTP draft context then allocating additional KV / compute memory after the fit step
- prompt-cache save no longer being the final line after the first patch
- checkpoint sizes staying very large on this model, often around 170-220 MiB each
- cached prompt entries growing to multi-GiB sizes because the cache stored both full prompt state and a long checkpoint list
- the server running with `COMMON_CONTEXT_SEQ_RM_TYPE_RS`, which means checkpoints remain part of the normal reuse path for this workload

From that, the working diagnosis was:

- the earliest CUDA failure came from missing MTP overhead in the fit budget
- after that was addressed, the next failure came from the prompt-cache save path under large-state pressure
- the remaining failure came from unguarded checkpoint export and uncontrolled checkpoint memory accumulation

## 2. Fix Logic

### A. Account for MTP draft-context overhead during `-fit`

The `common/` side of the patch adds a dedicated helper in [common/fit.cpp](common/fit.cpp) and declares it in [common/fit.h](common/fit.h):

- `common_get_mtp_ctx_memory_overhead(...)`

That helper:

- loads the model with `no_alloc = true`
- creates a temporary `llama_context` with `ctx_type = LLAMA_CONTEXT_TYPE_MTP`
- forces `n_rs_seq = 0` for that temporary MTP measurement context
- reads the memory breakdown from the constructed context
- sums only `context + compute` overhead per device and for host memory

The corresponding change in [common/common.cpp](common/common.cpp) uses that helper when all of the following are true:

- fitting is enabled
- `draft-mtp` is active
- there is no separate draft model

Instead of mutating the user’s original fit targets, the code copies `params.fit_params_target` into a temporary `fit_targets` vector, adds the measured MTP overhead to those margins, and passes the adjusted margins into `common_fit_params()`.

This means the fit step now leaves enough headroom for the MTP context that will actually be created later by the server.

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

The previous logic limited checkpoints only by count. That is not enough when each checkpoint can be hundreds of MiB.

The fix adds byte-based trimming in two places:

1. Live slot checkpoints

- after creating a checkpoint, old checkpoints are dropped until the total checkpoint bytes are roughly bounded by one full prompt-state budget

1. Cached prompt checkpoints

- before keeping a prompt in the host prompt cache, its checkpoint list is trimmed using a similar budget

This keeps caching enabled while preventing checkpoint memory from growing far beyond the size of the actual reusable state.

### G. Keep speculative decoding functional when checkpoint export fails

The speculative checkpoint path now degrades gracefully:

- if speculative checkpoint export fails, the speculative draft / checkpoint is cleared for that step
- the server continues without using that speculative checkpoint rather than aborting

This keeps `draft-mtp` usable even under high memory pressure.

## 3. Possible Effects On Other Functionality

### Fit may choose more conservative settings for `draft-mtp`

Because MTP draft-context overhead is now included in the fit margins, automatic fitting may choose a smaller context size or otherwise leave more headroom on GPU devices than before.

Effect:

- `-fit` results for `draft-mtp` can become more conservative
- this is expected, because the previous fit result was undercounting real runtime memory
- non-MTP and separate-draft-model configurations should be unchanged by this logic

### Slightly longer startup when `-fit` and `draft-mtp` are both used

The new helper creates a temporary MTP context to measure overhead before the final fit decision is applied.

Effect:

- startup can do one extra model/context measurement pass in this specific configuration
- this only affects the fitting path, not steady-state generation

### Reduced rollback depth in long sessions

Because checkpoints are now trimmed by bytes as well as by count, long-running sessions may keep fewer old checkpoints than before, especially on recurrent / MTP models with large checkpoint payloads.

Effect:

- rollback may fall back to a newer checkpoint and replay a slightly longer suffix
- prompt reuse still works, but some restores may save less work than before in the extreme long-context case

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
- cross-request or cross-slot resume may sometimes require replaying a longer suffix than before
- total RAM use is significantly better bounded

### No intended change to prompt selection or decoding semantics

The patch does not change:

- slot selection heuristics
- prompt similarity logic
- the main decode path when state export succeeds
- the correctness of existing cache reuse / checkpoint restore logic

The goal is not to change model behavior, but to make the server survive large-state export failures and avoid pathological checkpoint memory growth.

