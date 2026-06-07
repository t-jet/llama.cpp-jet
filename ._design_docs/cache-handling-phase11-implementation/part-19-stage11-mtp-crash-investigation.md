# Stage 11 Follow-up: MTP draft-context server crash investigation

Investigation of the MTP draft-context server crash reported on `cache-optimization-caveman` HEAD `02db7a768`, follow-up to Stage 11 closure on commit `6e3aa045c`. Read-only investigation. No code edits, no commits, no builds, no test runs.

## 1. Crash point

**Crash line:** `model_log.txt:20394`

**Crash text:** `D:\source\llama.cpp-jet\src\llama-context.cpp:2152: GGML_ASSERT(n_outputs_max <= cparams.n_outputs_max) failed`

**Crash site:** `src/llama-context.cpp:2152` inside `llama_context::output_reserve(int32_t n_outputs)` (defined at line 2013). The assertion checks `n_outputs_max = std::max<int64_t>(n_outputs, n_seq_max())` against `cparams.n_outputs_max` (set at line 186 from `params.n_outputs_max`, defaulting to `cparams.n_batch` if zero).

**Last 30 log lines (lines 20365-20394):**

```text
0.38.075.460 I slot update_slots: id  0 | task 0 | new prompt, n_ctx_slot = 140032, n_keep = 0, task.n_tokens = 17
0.38.075.470 D res          send: sending result for task id = 0
0.38.075.470 D res          send: task id = 0 pushed to result queue
0.38.075.476 I slot update_slots: id  0 | task 0 | cached n_tokens = 0, memory_seq_rm [0, end)
0.38.075.556 D srv          stop: all tasks already finished, no need to cancel
0.38.075.567 I srv  log_server_r: done request: POST /v1/chat/completions 127.0.0.1 200
0.38.075.570 D srv  log_server_r: request:  {"messages":[{"role":"user","content":"What is your problem?"}],"stream":true,...}
0.38.075.571 D srv  log_server_r: response:
0.38.075.671 D slot update_slots: id  0 | task 0 | main/do_checkpoint = no, pos_min = -1, pos_max = -1
0.38.075.675 D srv  update_slots: decoding batch, n_tokens = 13
0.38.075.676 D set_adapters_lora: adapters = 0000000000000000
0.38.075.677 D adapters_lora_are_same: adapters = 0000000000000000
0.38.075.678 D set_embeddings: value = 0
0.38.075.685 D srv   operator (): http: streamed chunk: data: {"choices":[{"finish_reason":null,"index":0,"delta":{"role":"assistant","content":null}}],...,"prompt_progress":{"total":17,"cache":0,"processed":0,"time_ms":0}}
D:\source\llama.cpp-jet\src\llama-context.cpp:2152: GGML_ASSERT(n_outputs_max <= cparams.n_outputs_max) failed
```

**Crash context:** The first user prompt ("What is your problem?") was accepted, the prompt was processed (`task.n_tokens = 17`, no cache hit), the first streamed chunk was sent (role delta with no content), then the next decode step crashes when the llama_decode path calls `output_reserve(13)` against a context whose `cparams.n_outputs_max` is too small. The 13-token decode batch is 4 less than the 17-token prompt, which is consistent with the MTP verify step pre-removing `1 + n_max = 4` tokens before the residual decode.

## 2. Branch check result

**`fix_mtp_server_instability` branch:** EXISTS. Local and remote (`remotes/origin/fix_mtp_server_instability`).

**Commits on the branch (4 substantive + 1 indent fix):**

| SHA | Subject |
| --- | --- |
| a4303153f | fix: correct indentation in MTP pre-norm embedding setup |
| de97acb49 | feat: improve error handling in server context task processing |
| 920419bff | feat: enhance MTP context memory overhead handling during fitting |
| db44b011e | fix: enhance embedding condition checks in server context |
| f5014e1a7 | Refactor common initialization and speculative context handling |
| 1ba584045 | feat: enhance MTP context memory management and checkpoint handling |

**Merge status:** `git merge-base --is-ancestor a4303153 02db7a768` returned 0. The branch tip is an ancestor of the current HEAD via the merge of `cache-optimization-stage11-merge` into `cache-optimization` (commit `3c5ddd962`).

**Conclusion:** The user hypothesis is incorrect. The branch was never "lost" in the upstream merge; all of its substantive commits are present in current HEAD. The crash is not a regression from a dropped fix_mtp commit.

## 3. Fixes checklist

Statuses are based on `Select-String` grep over the working tree on HEAD `02db7a768`.

| ID | Fix | File | Status | Evidence grep line |
| --- | --- | --- | --- | --- |
| A | MTP draft-context overhead during `-fit` | `common/fit.cpp`, `common/fit.h`, `common/common.cpp` | **PRESENT** | `common\fit.cpp:766:std::vector<size_t> common_get_mtp_ctx_memory_overhead(`; `common\fit.h:35:std::vector<size_t> common_get_mtp_ctx_memory_overhead(`; `common\common.cpp:1193: std::vector<size_t> fit_targets = params.fit_params_target;`; `common\common.cpp:1208: const auto mtp_overhead = common_get_mtp_ctx_memory_overhead(` |
| B | Harden `prompt_save` (byte-count check, discard on failure) | `tools/server/server-context.cpp` | **PRESENT** | `server-context.cpp:417:    bool prompt_save(server_prompt_cache & prompt_cache, bool move_metadata = false)`; `server-context.cpp:436: prompt_cache.discard(cur);` (line 444 also) |
| C | Slot handoff: move prompt metadata, not clone | `tools/server/server-context.cpp` | **PRESENT** | `server-context.cpp:417:` has `bool move_metadata = false` parameter; `server-context.cpp:6754: return const_cast<server_slot &>(slot).prompt_save(*cache, true);` |
| D | Fail-soft checkpoint export helpers | `tools/server/server-context.cpp` | **PRESENT** | `server-context.cpp:367: bool checkpoint_update_tgt(common_prompt_checkpoint & ckpt, llama_state_seq_flags flags) const`; `server-context.cpp:392: bool checkpoint_update_dft(...)`; bad_alloc catch at `server-context.cpp:376` and `:401` |
| E | Skip invalid checkpoints (disable after first failure) | `tools/server/server-context.cpp` | **PRESENT** | `server-context.cpp:291:    bool checkpoints_enabled = true;`; `server-context.cpp:352: void disable_checkpoints(...)`; `server-context.cpp:2583: slot.disable_checkpoints("checkpoint export failure");` |
| F | Byte-budget checkpoint trimming | `tools/server/server-context.cpp` | **PRESENT** | `server-context.cpp:325: size_t trim_checkpoints_for_allocation(...)`; `server-context.cpp:2569: slot.trim_checkpoints_for_allocation(` |
| G | Speculative checkpoint degrades gracefully | `tools/server/server-context.cpp` | **PRESENT** | `server-context.cpp:3063: if (!slot.checkpoint_update_dft(slot.spec_ckpt, ...))`; speculative path returns failure rather than aborting |
| H | Adapt speculative prompt to current upstream (need_embd + pre_norm + masked + n_batch_prompt) | `tools/server/server-context.cpp`, `common/speculative.cpp`, `src/llama-context.cpp` | **PRESENT** | `common\speculative.cpp:491-492: llama_set_embeddings_nextn(ctx_tgt, true, /*masked*/ true); llama_set_embeddings_nextn(ctx_dft, true, /*masked*/ true);` |
| I | Disable pipeline parallelism for `LLAMA_CONTEXT_TYPE_MTP` | `src/llama-context.cpp` | **PRESENT** | `src\llama-context.cpp:343: cparams.ctx_type != LLAMA_CONTEXT_TYPE_MTP &&` (inside the `bool pipeline_parallel` initialization) |
| J | Remove the response-queue `waiting_task_ids.size()` logging race | `tools/server/server-queue.cpp` | **PRESENT** | `server-queue.cpp:229:` `server-queue.cpp:235:` `server-queue.cpp:244:` `server-queue.cpp:256:` `server-queue.cpp:266:` `server-queue.cpp:289:` `server-queue.cpp:320:` (all `std::unique_lock<std::mutex> lock(mutex_results);` immediately before the `RES_DBG(... waiting_task_ids.size() ...)` log) |
| K | Runtime exception barrier around main queue callbacks | `tools/server/server-context.cpp` | **PRESENT** | `server-context.cpp:1190:` `try {` ... `:1224:} catch (const std::exception & e) {`; also `:1398` `:1545` `:1562` `:1579` `:1614` `:1629` `:1942` (all paired `try { ... } catch (const std::bad_alloc & e) { ... } catch (const std::exception & e) { ... }`) |
| L | Reset cached state in GGML meta-buffer reset path | `ggml/src/ggml-backend-meta.cpp` | **MISSING** | Body of `ggml_backend_meta_buffer_reset` read in full 2026-06-06 at `ggml-backend-meta.cpp:1469-1475`: casts `buf_ctx`, then loops over `buf_ctx->bufs` and calls `ggml_backend_buffer_reset` on each child via `ggml_backend_meta_buffer_simple_buffer`. Does NOT clear `split_state_cache`, does NOT clear `simple_tensors`, and does NOT call `ggml_reset(ctx)` per child context. Fix-mtp version (`a4303153`, body confirmed via `git show a4303153:ggml/src/ggml-backend-meta.cpp`) actively clears `buf_ctx->split_state_cache` and `buf_ctx->simple_tensors`, then iterates `buf_ctx->buf_configs` calling `ggml_reset(ctx)` and `ggml_backend_buffer_reset(buf)` per child. Current upstream's only stale-cache defense is the lazy memcmp invalidation at `ggml-backend-meta.cpp:1054-1057` inside `ggml_backend_meta_get_split_state`, which fires only on re-query with changed byte-state; the `e0f3f868b` merge comment claimed a `ggml_backend_meta_graph_compute` clear, but the actual clear is in the get-state path, not the compute path. The two reset bodies are not equivalent (active reset-time clear + per-child `ggml_reset` are both missing in current), so fix L is MISSING. Re-apply from `a4303153` in a future implementation gate per the user preservation policy. |
| M | Cache admission + eviction (oversized state rejected, final oversized entry can be evicted) | `tools/server/server-task.cpp` | **PRESENT** | `server-task.cpp:2029: const size_t estimated_size = prompt.size() + state_size_tgt + state_size_dft;`; `server-task.cpp:2031: if (limit_size > 0 && estimated_size > limit_size) {` |
| N | `n_outputs_max` cap from upstream PR #23861 + PR #23988 (speculative fix) | `tools/server/server-context.cpp` | **PRESENT** | `server-context.cpp:204: static uint32_t server_n_outputs_max(const common_params & params) {` returning `min(n_batch, n_parallel * (1 + common_speculative_n_max(&params.speculative)))`; `server-context.cpp:1109: params_base.n_outputs_max = server_n_outputs_max(params_base);`; `server-context.cpp:1175: params_dft.n_outputs_max = params_base.n_parallel;`; `server-context.cpp:1308: cparams_mtp.n_outputs_max = params_base.n_parallel;` |

**Summary:** 13 PRESENT, 1 MISSING, 0 PARTIAL (fix L body fully read 2026-06-06; not present in current, re-apply from `a4303153` in a future implementation gate per the user preservation policy).

## 4. Upstream-merge cross-check

### `6e3aa045c` - Stage 11 closure (T114a product-only coverage)

- Files touched: `tools/server/server-cache-hybrid.h` only (9 insertions, 14 deletions).
- No overlap with the fix-doc file set (`common/fit.*`, `common/common.cpp`, `tools/server/server-context.cpp`, `tools/server/server-task.*`, `tools/server/server-queue.cpp`, `common/speculative.cpp`, `src/llama-context.cpp`, `ggml/src/ggml-backend-meta.cpp`).
- Verdict: this commit could not have overwritten or restored any of the fix_mtp changes.

### `602f3e3f0` - remove duplicate definitions from real merge of upstream_master

- Files touched: `tools/server/server-context.cpp` (17 deletions).
- Removed the byte-identical upstream `server_n_outputs_max` body (PR #23861, line-modified by PR #23988) at lines 219-232 of the upstream side and the `near_prompt_end` declaration at line 3653 (PR #22929).
- Kept the cache-side `server_n_outputs_max` (added by fix_mtp commit `1ba584045`) and the cache-side `near_prompt_end`.
- The kept cache-side formula at `server-context.cpp:204` matches the upstream's post-`5dcb711666` formula (`min(n_batch, n_parallel * (1 + common_speculative_n_max(&params.speculative)))`).
- Verdict: this commit preserved all the fix_mtp changes; the `cparams_mtp.n_outputs_max = params_base.n_parallel;` line at `server-context.cpp:1308` is still present.

### `e0f3f868b` - Stage 11 real merge: cache-optimization <- upstream_master

- Files touched: `common/fit.h` (118 +/-), `ggml/src/ggml-backend-meta.cpp` (12 +/-), `tools/server/server-context.cpp` (54 insertions).
- Conflict resolution explicitly:
  - `common/fit.h`: take upstream (already adds `common_get_device_memory_data`); re-add Stage 11 `common_get_mtp_ctx_memory_overhead` declaration after `common_fit_params`; drop duplicate `#include <vector>`.
  - `common/speculative.cpp`: take upstream rename `pre_norm -> nextn`; re-apply Stage 11 fix to flip `ctx_tgt` masked flag to `true`.
  - `ggml/src/ggml-backend-meta.cpp`: take upstream reset path verbatim (Stage 6/9 comment was meta-rationale only).
- Verdict: the merge re-applied the fit declaration and the MTP target masked-row fix. The reset path was taken upstream-verbatim, which is the cause of fix L being MISSING (the fix-mtp body in `a4303153` actively clears `split_state_cache`/`simple_tensors` and calls `ggml_reset(ctx)` per child; the upstream body in `e0f3f868b` does neither).

## 5. Crash-to-fix-gap mapping

**Crash:** `output_reserve(13)` against `cparams.n_outputs_max=4` in the target context.

**Mapping:** The crash does NOT align with any missing fix from the A-N checklist. All 13 fix_mtp-described changes (A through M plus the upstream-derived cap N) are present in current HEAD. The crash is consistent with a **newly-introduced mismatch in decode-batch sizing** that the existing fixes do not cover. Specifically:

- The upstream `server_n_outputs_max` cap returns 4 for `n_parallel=1`, `n_max=3` (formula `1 + n_max = 4`), and the target context is initialized with `params_base.n_outputs_max = 4` at `server-context.cpp:1109`.
- The cache-optimization stage 11 work is responsible for the decode-batch building in `tools/server/server-context.cpp` `update_slots()`. The log shows `decoding batch, n_tokens = 13` (line 20377), and 13 > 4 fails the `output_reserve` assertion.
- The 13-token batch (one less than the 17-token prompt) is consistent with the MTP verify path pre-removing the 4 verification tokens and forwarding the remaining 13 to `llama_decode` in a single call, which exceeds the cap that PR #23861 introduced.

**Verdict:** the gap is in the **cache-optimization decode-batch builder** (Stage 11 work, files in `tools/server/server-cache-hybrid.h` and the speculative batching calls in `server-context.cpp` around `update_slots`), not in the fix_mtp branch. The user's hypothesis ("fixes were lost during the upstream merge") is not supported.

## 6. Recommended next gate

**Design gate** (re-open): the Stage 11 design assumed that the `n_outputs_max` cap introduced by upstream PR #23861 was a per-context ceiling that the speculative decode-batch builder had to respect, but the design and the implementation did not add an explicit verification that the per-iteration decode batch stays below the cap. Owner: Architect.

## 7. Risks and open questions

- **R1:** the upstream `n_outputs_max` cap semantics may be sized for the main target decode only, not for a MTP verify-then-decode loop that buffers more than `1 + n_max` tokens. Need to confirm whether the cache-optimization decode-batch builder intentionally batches multiple MTP verify passes in one `llama_decode` call, and whether that batching is required for the prompt-cache reuse path.
- **R2:** the upstream PR #23861 may have been tested only with prompt-side `n_outputs_max = n_batch` and decode-side `n_outputs_max = 4`; the MTP target path (`llama_set_embeddings_nextn(ctx_tgt, true, true)`) may still rely on per-token output rows that the current cap under-counts.
- **R3:** the fix L (meta-buffer reset) is MISSING: body of `ggml_backend_meta_buffer_reset` read in full 2026-06-06 at `ggml-backend-meta.cpp:1469-1475`. Current upstream body (taken at `e0f3f868b`) loops over `buf_ctx->bufs` and calls `ggml_backend_buffer_reset` per child; it does NOT clear `split_state_cache`, does NOT clear `simple_tensors`, and does NOT call `ggml_reset(ctx)` per child context. The fix-mtp body in `a4303153` actively clears `split_state_cache` and `simple_tensors` and iterates `buf_ctx->buf_configs` calling `ggml_reset(ctx)` per child. The upstream's only stale-cache defense is the lazy memcmp invalidation at `ggml-backend-meta.cpp:1054-1057` inside `ggml_backend_meta_get_split_state`. The two bodies are not equivalent. Re-apply from `a4303153` in a future implementation gate per the user preservation policy; this is now an explicit follow-up for the next gate, not a durable-doc-only decision.
- **OQ1:** is the 13-token decode batch the first call into the target context after the prompt processing, or a follow-up speculative verify call?
- **OQ2:** what is `cparams.n_outputs_max` for the MTP draft context at runtime? The init code sets it to `n_parallel = 1`, but the MTP draft code in `common/speculative.cpp` may call `llama_decode` with batches of size up to `1 + n_max = 4`, which would already exceed the cap. The current log line `decoding batch, n_tokens = 13` does not show which context.
- **OQ3:** does the cache-optimization `update_slots` path construct the decode batch from the full prompt minus the verification prefix (17 - 4 = 13) and call `llama_decode` once on the residual 13? If yes, the fix is to either bump the target cap to `1 + n_max + (prompt - 1 - n_max)` (i.e. `prompt - n_max`) for the MTP path, or to chunk the residual into batches of `1 + n_max`.
- **OQ4:** the user prompted the server with the simplest possible 4-token user message, but the chat template plus the jinja `<|im_start|>` markers plus reasoning prefill produced a 17-token prompt. The crash happens on a follow-up decode of 13 tokens. A controlled reproduction with the same command line is required to confirm the crash is reproducible from a clean state and not from a prior cache state.

## Investigation commands run

```powershell
# Crash line and tail
Select-String -Path 'd:\source\llama.cpp-jet\._analysis\model_log.txt' -Pattern 'GGML_ASSERT|cparams.n_outputs_max' | Select-Object -First 10
Get-Content 'd:\source\llama.cpp-jet\._analysis\model_log.txt' -Tail 30

# Branch + merge-base
git -C 'd:\source\llama.cpp-jet' branch -a | Select-String -Pattern 'fix_mtp|fix-mtp|mtp_instab|server_instab'
git -C 'd:\source\llama.cpp-jet' log --all --oneline | Select-String -Pattern 'fix_mtp|fix-mtp|mtp_instab|server_instab' | Select-Object -First 20
git -C 'd:\source\llama.cpp-jet' merge-base --is-ancestor a4303153 02db7a768

# Upstream merge commits
git -C 'd:\source\llama.cpp-jet' show --stat 6e3aa045c
git -C 'd:\source\llama.cpp-jet' show --stat 602f3e3f0
git -C 'd:\source\llama.cpp-jet' show --stat e0f3f868b

# Source-state greps
Select-String -Path 'd:\source\llama.cpp-jet\common\fit.cpp','d:\source\llama.cpp-jet\common\fit.h','d:\source\llama.cpp-jet\common\common.cpp' -Pattern 'common_get_mtp_ctx_memory_overhead'
Select-String -Path 'd:\source\llama.cpp-jet\common\common.cpp' -Pattern 'fit_params_target|LLAMA_CONTEXT_TYPE_MTP'
Select-String -Path 'd:\source\llama.cpp-jet\tools\server\server-context.cpp' -Pattern 'prompt_save|llama_state_seq_get_data_ext|discard|server_n_outputs_max|near_prompt_end'
Select-String -Path 'd:\source\llama.cpp-jet\tools\server\server-task.cpp','d:\source\llama.cpp-jet\tools\server\server-task.h' -Pattern 'prompt_save|checkpoint|bad_alloc|discard'
Select-String -Path 'd:\source\llama.cpp-jet\tools\server\server-context.cpp' -Pattern 'checkpoints_enabled|trim_checkpoints_for_allocation|disable_checkpoints|checkpoint_update_tgt|checkpoint_update_dft'
Select-String -Path 'd:\source\llama.cpp-jet\tools\server\server-queue.cpp','d:\source\llama.cpp-jet\tools\server\server-context.cpp' -Pattern 'try \{|catch \(const std::|catch \(std::|mutex_results'
Select-String -Path 'd:\source\llama.cpp-jet\common\speculative.cpp' -Pattern 'ctx_tgt|masked|LLAMA_CONTEXT_TYPE_MTP|pre_norm'
Select-String -Path 'd:\source\llama.cpp-jet\src\llama-context.cpp' -Pattern 'LLAMA_CONTEXT_TYPE_MTP|pipeline_parallelism|n_outputs_max'
Select-String -Path 'd:\source\llama.cpp-jet\ggml\src\ggml-backend-meta.cpp' -Pattern 'ggml_backend_meta_buffer_reset|split_state|tensor_state|child_buffer'
```
