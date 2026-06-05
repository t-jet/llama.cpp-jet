# Patch Notes - Part 1: Results

Source: [../fix-qwen-summary.md](../fix-qwen-summary.md)

## Results

On the investigated Qwen 3.6 `draft-mtp` workload, the validated configuration completed a 10+ hour run without crashing and processed the complex agentic workflow at close to the expected speed.

That long-run result comes from the investigated configuration used during the fix development. A fresh equivalent long-run validation run on the exact current checked-out tree is not recorded in this note.

The current fix state is intended to cover the full observed and inferred failure set for this workload:

- CUDA OOM during real prompt processing even though `-fit` reported that the configuration should fit
- silent exits during prompt-cache save and during checkpoint creation on long-running cached sessions
- first-request failures on very large prompt-prefill batches
- startup-time CUDA failure in the MTP draft context after a failed reserve/fallback path
- silent process termination under severe host-memory pressure if a standard exception escaped task scheduling or slot updates
- allocator aborts in the GGML meta backend during repeated MTP draft graph reuse on similar tensor-split workloads

## Branch and compilation

This note describes the diff between:

- current `origin/master` base: `40d5358d3c730b81729ba81cd5c44ed596d02510` (`tests : move save-load-state from examples to tests (#23336)`)
- current branch head: `a4303153fe84c1ce33fa071d604fc6e4f6e9d657` (`fix: correct indentation in MTP pre-norm embedding setup`)

The fixed branch is hosted in the forked repository [here](https://github.com/t-jet/llama.cpp-jet/tree/fix_mtp_server_instability).


Relative to `origin/master`, the current state differs in ten files:

- `common/common.cpp`
- `common/fit.cpp`
- `common/fit.h`
- `common/speculative.cpp`
- `ggml/src/ggml-backend-meta.cpp`
- `src/llama-context.cpp`
- `tools/server/server-context.cpp`
- `tools/server/server-queue.cpp`
- `tools/server/server-task.cpp`
- `tools/server/server-task.h`

Build environment used during the investigation:

- Windows 11 Pro 25H2
- AMD Ryzen 7900X
- 2 x NVIDIA RTX 5060 Ti 16 GB
- 64 GB RAM
- Visual Studio 2026 Developer prompt
- CUDA 13.1 toolkit

CMake commands used during the investigation:

```text
cmake -S . -B build-cuda -G "Visual Studio 17 2022" -A x64 -DGGML_CUDA=ON -DGGML_NATIVE=OFF -DBUILD_SHARED_LIBS=OFF
cmake --build build-cuda --config Release -j --clean-first --target llama-cli llama-mtmd-cli llama-server llama-gguf-split
```

Incremental validation command:

```text
cmake --build build-cuda --config Release -j --target llama-server
```

Long-run validation configuration used during the investigation:

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

Reproduction configuration used for the large-prompt and startup failures:

```cmd
llama-server.exe ^
  -m c:\Users\think\.lmstudio\models\unsloth\Qwen3.6-27B-MTP-GGUF\Qwen3.6-27B-Q4_K_M.gguf ^
  --port 52411 ^
  -c 140000 ^
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
  --cache-ram 16384 ^
  --metrics
```

## Summary

This change stabilizes `llama-server` on Qwen 3.6 hybrid/recurrent workloads with `draft-mtp` enabled in six places where memory management or speculative integration was too optimistic:

- the fit / startup path, where the secondary MTP draft context was outside the original fit budget
- the runtime prompt-cache / checkpoint path, where large prompt state and checkpoint exports could terminate the process or accumulate excessive RAM
- the speculative MTP prompt-prefill path, where the server was not recognizing speculative prompt batches correctly under the current upstream signaling contract
- the MTP draft-context startup path, where the reserve/fallback path could poison CUDA state on this workload
- the main runtime callback path, where uncaught standard exceptions from task scheduling or slot updates could unwind out of the queue loop under host-memory pressure
- the backend meta-buffer reset path, where cached split/tensor state could survive across repeated graph allocation cycles

The change therefore targets six related failure modes:

- CUDA OOM during real prompt processing even though `-fit` reported that the configuration should fit
- silent exits during prompt-cache save and during checkpoint creation on long-running cached sessions
- first-request failures on very large prompt-prefill batches because speculative prompt batches were not being capped and were not marking prompt output rows correctly
- startup-time CUDA failure in the MTP draft context after a failed pipeline-parallel reserve path
- silent process termination if a `std::bad_alloc` or another standard exception escaped the main runtime callbacks
- allocator aborts in `ggml_new_object` / meta-buffer graph allocation on similar repeated-reuse MTP workloads

The branch keeps caching enabled, preserves the existing reuse logic, includes active fit accounting for the MTP draft context, makes both fitting and runtime state export account for MTP / checkpoint memory more realistically, adapts the speculative prompt path to the current upstream implementation, adds a narrow runtime exception barrier around the main queue callbacks, and resets cached meta-buffer state before repeated graph allocation cycles.

## 1. Symptoms And Diagnostic Logic

### Symptoms

One failure mode was a CUDA error during prompt processing on a later turn of a large `draft-mtp` session, even though the `-fit` step had already reported that the configuration met device-memory targets.

The relevant pattern was:

- `common_fit_params` reported that the projected memory usage fit available GPU memory
- the server then created the MTP draft context afterwards
- prompt processing then failed with a CUDA error during actual evaluation

That suggested a startup-time underestimation rather than a steady-state logic bug in the prompt processor itself.

Another failure mode was a silent server exit immediately after a log line like:

```text
srv prompt_save: - saving prompt with length ..., total state size = ... MiB
```

There was no subsequent `prompt_load`, no cache-state summary, and no explicit error from the server. That strongly suggested the process was dying inside or immediately after prompt-state export, not during normal slot selection or request execution.

Another observed failure tail reached:

- `slot init_sampler`
- then stopping before the next normal checkpoint / decode progress line

That tail points to the checkpoint creation path or the immediate decode handoff that follows it.

On the large-prompt path, a separate failure mode was a first-request failure. The critical current upstream behavior is that MTP prompt hidden-state demand is reported through `need_embd_pre_norm()` rather than through `need_embd()` alone. If the server batching logic does not account for that, then:

- speculative MTP prompt batches are not recognized correctly
- the first prompt batch is no longer capped conservatively
- prompt tokens are no longer marked as output rows for the speculative pre-norm flow

That is enough to trigger first-request failure on very large prompt-prefill batches.

Another failure mode was a startup-time failure in the MTP draft context:

- the draft context attempted a pipeline-parallel reserve path during startup
- that path could fail with a large host-buffer allocation failure
- the reserve logic could retry without pipeline parallelism and appear to recover
- a subsequent CUDA call during server initialization could still abort with a generic CUDA error, consistent with a poisoned CUDA state after the failed reserve path

That made startup itself unstable even before the first request was processed.

Under severe host-memory pressure, another plausible failure mode was silent process termination from an escaped standard exception:

- `server_queue::start_loop()` invoked task scheduling and slot updates through callbacks without a queue-level exception barrier
- `server_context::start_loop()` executed that loop on the main thread
- an escaped `std::bad_alloc` or another standard exception from those runtime paths could therefore terminate the process instead of returning task errors

On a closely related CUDA / MTP / tensor-split workload, another failure class reached a hard allocator abort in the GGML meta backend:

- the stack ran through `ggml_backend_meta_buffer_init_tensor()`, `ggml_gallocr_alloc_graph()`, `llama_context::process_ubatch()`, the MTP draft path, and `server_context_impl::update_slots()`
- the terminal failure was `ggml_new_object: not enough space in the context's memory pool`
- current `origin/master` still reset the meta buffer by resetting only the simple child buffers, not the cached split/tensor state or the per-buffer ggml contexts

### Diagnostic logic

The investigation separated the problem into seven concrete paths:

#### 1. MTP context fitting path

- `common_fit_params()` runs before the server creates the MTP draft context.
- For `draft-mtp` without a separate draft model, the fit step budgets only the primary context.
- The additional `ctx_type = LLAMA_CONTEXT_TYPE_MTP` context is created afterwards, so its context + compute overhead is outside the fit margins.

That explains why `-fit` could say the setup fit, but prompt processing could still fail with CUDA OOM once the real MTP context existed.

#### 2. Prompt-cache save path

- `get_available_slot()` may save the old slot state before reusing the slot for a new task.
- `server_slot::prompt_save()` exported the live target and draft state into RAM and also duplicated prompt metadata, including the full checkpoint list.
- For long recurrent / MTP prompts, the live state was already large, and the checkpoint list added several more GiB of RAM pressure.

#### 3. Checkpoint creation path

- During prompt processing, the server periodically creates rollback checkpoints for recurrent / bounded-removal contexts.
- These checkpoints were also exported through `llama_state_seq_get_data_ext()`.
- The export path assumed success and could abort the process on short-copy or mismatch behavior.

#### 4. Speculative prompt-prefill path

- The current upstream signaling contract reports MTP prompt hidden-state demand through `need_embd_pre_norm()`.
- The local server batching logic must still translate that requirement into output-row handling for prompt batches.
- If it does not, the required first-request protection is effectively disabled.

#### 5. MTP draft-context startup path

- The draft context used a more aggressive startup scheduling path than this workload could tolerate.
- The fallback path after reserve failure was not cleanly recovering on the tested Windows setup.

#### 6. Main runtime exception path

- `server_queue::start_loop()` invoked `process_single_task()` and `update_slots()` through callbacks without a queue-level catch boundary.
- Those runtime paths contain allocations and helper calls that are not all converted into task-local errors.
- Under severe host-memory pressure, an escaped `std::bad_alloc` or another standard exception could unwind out of the main loop and terminate the server.

#### 7. Meta-backend reset / graph allocation path

- The GGML meta backend keeps cached split-state and simple-tensor mappings in the meta-buffer context.
- The reset path only reset the simple child buffers, leaving those caches and the per-buffer ggml contexts alive across allocation cycles.
- On repeated MTP draft graph allocation, especially with tensor split, that stale state could plausibly feed into a later allocator abort in the context memory pool.

The key log evidence was:

- fit reporting sufficient headroom before the MTP context existed
- the MTP draft context then allocating additional KV and compute memory after the fit step
- failure tails that reached `slot init_sampler` after prompt-save activity and then stopped before the next checkpoint or decode progress line
- checkpoint sizes staying very large on this model, often around 170 to 220 MiB each
- cached prompt entries growing to multi-GiB sizes because the cache stored both full prompt state and a long checkpoint list
- the server running with `COMMON_CONTEXT_SEQ_RM_TYPE_RS`, which means checkpoints remain part of the normal reuse path for this workload
- first-request failures clustering around very large prompt-prefill batches
- startup failures clustering around the MTP draft-context reserve/fallback path
- queue callbacks being wired directly to task scheduling and slot updates without a top-level runtime exception barrier
- a related allocator-abort stack on similar hardware reaching `ggml_backend_meta_buffer_init_tensor()` and `ggml_new_object()` during repeated MTP draft reuse

The resulting diagnosis was:

- the later-turn CUDA failure came from missing MTP overhead in the fit budget
- prompt-cache save failures came from large-state pressure
- checkpoint failures came from unguarded checkpoint export and uncontrolled checkpoint memory accumulation
- the large-prompt first-request failure came from the server not adapting its batching logic to the current upstream MTP signaling contract
- the startup failure came from the MTP draft-context reserve/fallback path
- silent host-memory-pressure crashes could also come from an escaped standard exception in the main runtime callbacks
- allocator aborts on similar repeated-reuse workloads could also come from stale GGML meta-buffer cached state surviving reset boundaries

## 2. Fix Logic

