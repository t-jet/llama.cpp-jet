# Patch Notes - Part 1: Results

Source: [../fix-qwen-eval-2.md](../fix-qwen-eval-2.md)

## Results

After the latest rebase and follow-up fixes, the current checked-out branch state now differs from current `origin/master` in nine files:

- `common/common.cpp`
- `common/fit.cpp`
- `common/fit.h`
- `common/speculative.cpp`
- `src/llama-context.cpp`
- `tools/server/server-context.cpp`
- `tools/server/server-queue.cpp`
- `tools/server/server-task.cpp`
- `tools/server/server-task.h`

That is the key framing change for this revision of the document.

This note is no longer just a record of the earlier post-rebase runtime fixes. It is now an inventory of the code that still differs from current upstream master after:

- the merge of `llama : MTP clean-up (#23269)` into upstream
- the later rebases onto newer upstream master
- the additional first-request and startup fixes made afterwards on this branch

Relative to current `origin/master`, the retained local changes still target the same family of Qwen 3.6 `draft-mtp` stability problems, but the exact upstream-relative story is now broader:

- the fit path again applies measured MTP context overhead through `common/common.cpp` using the helper retained in `common/fit.*`
- the speculative MTP target path still forces masked pre-norm rows
- server prompt batching now explicitly treats speculative pre-norm needs as output-row needs after the upstream `#23269` cleanup changed that contract
- prompt-cache save and checkpoint export are still hardened against large-state failures
- the host prompt cache still enforces admission and eviction limits more strictly than upstream
- a debug-level race in the response queue is still fixed locally
- the MTP draft context now disables pipeline parallelism up front to avoid a startup-time reserve/fallback failure seen on Windows in this workload

## Branch and compilation

This document is aligned to the current checked-out branch state on top of:

- current upstream base: `ac76808e4db7bbb4082b86e7fbd615934b44ac6e` (`hexagon: enable support for NORM op (#23319)`)
- current committed branch head: `79234c493017b05a118a97818d492a2a9743ff89` (`fix: enhance embedding condition checks in server context`)

The source-level inventory below reflects the current checked-out code, including the later local restoration of the fit hook in `common/common.cpp`.

The upstream base already contains `llama : MTP clean-up (#23269)`. That matters for this document because some of the current branch logic is specifically correcting behavior introduced by that upstream cleanup, rather than carrying forward an older pre-cleanup design.

Earlier validation during the investigation used the same Windows / Visual Studio developer-command environment and the same manual incremental build flow as before.

Configure command used when needed:

```text
cmake -S . -B build-cuda -G "Visual Studio 17 2022" -A x64 -DGGML_CUDA=ON -DGGML_NATIVE=OFF -DBUILD_SHARED_LIBS=OFF
```

Incremental build command used during the investigation:

```text
cmake --build build-cuda --config Release -j --target llama-server
```

The reproduction logs discussed in this addendum came from a server run equivalent to:

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

During this documentation refresh, I aligned the note against the current source tree and the current upstream-relative diff. I did not obtain a fresh in-editor build confirmation because the VS Code CMake Tools configure/build path in this environment is still affected by the MSVC feature-detection problem seen earlier.

## Summary

Relative to current `origin/master`, the current checked-out branch state now retains eight meaningful behavior changes:

- the fit path in `common/common.cpp` again pre-adds measured MTP context overhead to the active `--fit` device margins when `draft-mtp` is active without a separate draft model
- MTP target prompt processing is forced back onto masked pre-norm rows instead of upstream's unmasked-target default for that speculative path
- `src/llama-context.cpp` keeps the masked/unmasked pre-norm extraction split and also disables pipeline parallelism for `LLAMA_CONTEXT_TYPE_MTP`
- server prompt batching is more conservative for speculative MTP prompt prefill and now explicitly treats speculative pre-norm needs as output-row needs after upstream `#23269`
- prompt-cache save and checkpoint export are made fail-soft, including exact byte-count checks, cleanup of incomplete cache entries, and reduced transient host-memory duplication during slot handoff
- live and speculative checkpoints are trimmed and disabled more aggressively after export failure to avoid repeated large allocations on the same task
- prompt-cache limit enforcement and response-queue logging are hardened against oversized cache entries and debug-level races

## 1. Upstream-relative Symptoms And Diagnostic Logic

### A. Upstream `#23269` changed the speculative MTP signaling contract in a way that reopened the first-request failure path

The most important code-state change since the previous draft of this document is that upstream `#23269` changed the speculative MTP implementation contract.

In the current upstream base:

- `common_speculative_impl_draft_mtp::need_embd()` no longer reports the MTP prompt-hidden-state requirement
- `common_speculative_impl_draft_mtp::need_embd_pre_norm()` reports that requirement instead
- the upstream speculative caller still defaults the target pre-norm extraction path to `masked = false`

That matters because the earlier server-side batching fix had been written against an older assumption where the speculative MTP prompt path could still be recognized through `slot.need_embd()` alone.

After rebasing onto newer upstream master, that assumption stopped being true. The practical effect was:

- speculative MTP prompt batches were no longer recognized by the server batching logic
- the first prompt batch stopped being capped conservatively
- prompt tokens stopped being marked as output rows for the speculative pre-norm flow

That reopened the first-request failure path on this branch until the server-side embedding-condition check was adjusted.

### B. Upstream still leaves the MTP target pre-norm path on the unmasked side

The current upstream base already contains the masked/unmasked pre-norm API, so the local branch is not introducing a new runtime contract here.

The upstream-relative problem is narrower:

- upstream selects target-side MTP pre-norm extraction with `masked = false`
- this workload still needs prompt-token rows to line up with the server-side masked output-row batching logic
- using the unmasked target path on this branch was not the retained fix direction

So the local branch still keeps the target-side MTP pre-norm path on masked rows.

### C. Upstream still exports prompt-cache state and checkpoints too optimistically under large recurrent / MTP prompts

The prompt-cache and checkpoint issues documented earlier remain relevant relative to current upstream:

- prompt-cache save may still try to export very large target and draft state into host RAM
- the old save path assumes successful exact export and can duplicate large prompt/checkpoint metadata during slot reuse
- a task that has already failed to export a checkpoint can still re-enter the same allocation-heavy checkpoint path later
- old checkpoints were only trimmed after a new checkpoint was already created, even though the transient peak occurs during allocation of the new checkpoint buffer

Those conditions are still enough to produce host-memory spikes, partial cache state, or repeated large-state allocation attempts on long Qwen MTP sessions.

### D. Upstream prompt-cache limits can still become advisory instead of real

The host prompt cache can still reach the same self-contradictory state seen in the earlier logs:

- prompt-cache save fails with `bad allocation`
- the cache reduces its own size limit
- a later cache summary still reports one cached prompt larger than that reduced limit

That still points to the same two upstream-relative problems:

1. `alloc()` can admit a prompt whose estimated final serialized size already exceeds the configured limit.
2. `update()` only evicts while more than one state remains, so one oversized state can survive indefinitely.

### E. Upstream still has a debug logging race in the response queue

At higher verbosity, the same independent queue bug remains upstream-relative:

- `server_response::add_waiting_task_id()` and `remove_waiting_task_id()` log `waiting_task_ids.size()` before locking `mutex_results`
- those reads race with concurrent modifications to the same set

### F. The MTP draft context can still fail during startup on this workload if it takes the pipeline-parallel reserve/fallback path

The later startup logs exposed another issue that was not captured in the previous revision of this document.

For the MTP draft context on this workload:

- the draft context could attempt a pipeline-parallel reserve path during startup
- that path could fail with a large host-buffer allocation failure
- the reserve logic could retry without pipeline parallelism and appear to recover
- a later CUDA call during server initialization could then abort with a generic CUDA error, consistent with a poisoned CUDA state after the failed reserve path

That made startup itself unstable, even before the first request was processed.

### G. The fit hook is active again, but only for margins that the current fit API can represent

The current `common/fit.*` addition is now active again through `common/common.cpp`.

This checked-out branch state:

- keeps `common_get_mtp_ctx_memory_overhead(...)` in `common/fit.cpp` and `common/fit.h`
- uses that helper again in `common/common.cpp` before `common_fit_params()` is called
- copies `params.fit_params_target` into a temporary `fit_targets` vector
- adds per-device MTP context overhead to that temporary margin vector when `draft-mtp` is active without a separate draft model

The important limitation is that `common_fit_params()` still consumes per-device margins only. So for GPU-backed runs, the helper's host-memory entry can be logged but not enforced by the current fit API.

## 2. Fix Logic Relative To Current `origin/master`

### A. Restore the active fit hook in `common/common.cpp` using `common/fit.cpp` and `common/fit.h`

The current checked-out state now restores the stage-one fit behavior in active code.

The branch contains the helper:

- `common_get_mtp_ctx_memory_overhead(...)`

and `common/common.cpp` now uses it again before calling `common_fit_params()`.

The helper itself:

- loads the model with `no_alloc = true`
- creates a temporary MTP context with `ctx_type = LLAMA_CONTEXT_TYPE_MTP`
- forces `n_rs_seq = 0` for that temporary measurement context
- reads the memory breakdown from the constructed context
- sums only `context + compute` cost per device and for host memory

The active fit hook then:

- detects `draft-mtp` without a separate draft model
- copies `params.fit_params_target` into a temporary `fit_targets` vector
- adds measured MTP overhead to the device margins passed into `common_fit_params()`
- applies host overhead only in the host-only case; otherwise the host overhead is logged but not enforced by the current fit API

So the original stage-one fit idea is now active again, with one explicit caveat about host-memory enforcement.

### B. Keep the MTP target on masked pre-norm rows in `common/speculative.cpp`

The retained local MTP caller change remains narrow:

- `common/speculative.cpp` switches the target-side MTP call from `llama_set_embeddings_pre_norm(ctx_tgt, true, false)` to `llama_set_embeddings_pre_norm(ctx_tgt, true, true)`
- the draft-side path is also left on masked pre-norm rows

So the current upstream-relative behavior change is still:

- upstream uses the unmasked target pre-norm path for this speculative caller
- this branch keeps both target and draft on masked rows for the Qwen MTP workflow being stabilized here

### C. Keep the runtime pre-norm extraction split and disable pipeline parallelism for MTP contexts in `src/llama-context.cpp`

The retained `src/llama-context.cpp` changes now have two separate purposes.

First, the pre-norm extraction code still keeps the masked/unmasked storage split explicit:

- unmasked pre-norm rows are addressed by raw token position
- masked pre-norm rows are addressed by output rows
- the decode-side async copy path adds an explicit row-bound assertion for the selected mode
- unmasked pre-norm output reservation still sizes by batch token count rather than `n_outputs`

Second, the branch now disables pipeline parallelism up front when:

- `cparams.ctx_type == LLAMA_CONTEXT_TYPE_MTP`

That is specifically to avoid the startup-time draft-context failure mode described above.

### D. Treat speculative pre-norm needs as output-row needs and bound prompt prefill in `tools/server/server-context.cpp`

This is the most important server-side correction relative to the current upstream base.

The local branch now treats speculative MTP prompt hidden-state needs as output-row needs through `server_slot::need_embd()` by folding in:

- `common_speculative_need_embd(spec)`
- `common_speculative_need_embd_pre_norm(spec)`

That is the key follow-up to upstream `#23269`.

The prompt loop also retains the earlier batching fix:

- `SPECULATIVE_PROMPT_MAX_OUTPUT_BYTES`
- `SPECULATIVE_PROMPT_SAFE_BATCH_SIZE`
- a derived `n_batch_prompt` used when speculative prompt hidden states are needed but the request is not a real embedding request
- prompt-token output marking still tied to `slot.need_embd()` so MTP gets per-token rows
- batch-wide `llama_set_embeddings(ctx_tgt, ...)` aggregated only from real embedding requests through `task->need_embd()`

So the current branch still does two things at once:

- it restores recognition of speculative MTP prompt batches after the upstream signaling change
- it keeps speculative prefill bounded without forcing the whole target batch into full embeddings mode

