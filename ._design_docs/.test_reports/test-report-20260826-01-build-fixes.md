# Test report 2026-08-26-01: Stage 40 open merge build fixes

Date: 2026-08-26
Stage: 40 (Upstream merge cycle)
Owner: Developer (build-fix session)
Trigger: QA test-execution gate BLOCKED on build - merged tree does not compile (~30 errors).
Merge state: open no-commit merge, MERGE_HEAD fc35562ba46fbbf8e30cac85edbb39642c37d248, HEAD e9d67a2fb6ad6b186a52b6b35f20d7c9e325c047.

## Result

| Check | Result |
| --- | --- |
| `cmake --build build-cuda --config Release --target llama-server test-cache-controller` | PASS (exit 0) |
| `ctest -C Release -R cache` | PASS 1/1 (test-cache-controller, 53.98 s) |
| `test-cache-controller.exe` direct | PASS, "All tests passed successfully!" |
| MERGE_HEAD intact | PASS |
| No commit, no push, no PR | PASS |

## Error categories fixed (9 brief categories + 3 additional)

| # | Location | Error | Root cause | Fix | Contract preserved |
| --- | --- | --- | --- | --- | --- |
| 1 | server-slot.h:224 | C2039 'data' not a member of 'server_prompt' | Upstream moved `server_prompt.data` + `size()` into `server_prompt_cache_state{ prompt, data }`. Local `prompt_save()` asserted on `prompt.data.size()`. | Removed the stale `GGML_ASSERT(prompt.data.size() == 0)`. The slot's `prompt` never owns data; the cache state does. | Stage 25 prompt-cache; upstream prompt cache wrapping authoritative |
| 2 | server-slot.h:284,286,676,680 | C3861 'common_context_seq_rm' not found | Upstream made `common_context_seq_rm/cp/add` static in common/common.cpp and moved callers to `slot.mem.*` (common_memory). Public `llama_memory_seq_*` API exists. | Replaced with `llama_memory_seq_rm(llama_get_memory(ctx), seq, p0, p1)` etc., preserving per-context (tgt/dft) semantics exactly. | Stage 5 MTP pair-state, Stage 25 tx contract, Stage 38 partial-restore |
| 3 | server-slot.h:677,681 | C3861 'common_context_seq_cp' not found | Same upstream removal. | `llama_memory_seq_cp(llama_get_memory(ctx), src, dst, p0, p1)` in `copy_state_to()`. | Stage 25 router/slot-state copy |
| 4 | server-slot.h:391,396 | C3861 'common_speculative_need_embd' / '_nextn' not found | Upstream made `common_speculative` fully opaque (pimpl); removed the `need_embd*` helpers. Upstream `need_embd()` is now `task->need_embd()` only. | Replaced `need_embd()`/`need_embd_nextn()` with `task->need_embd()`. `need_embd_nextn()` had zero callers in the merged tree, removed. | Upstream speculative API authoritative; no consumer of the removed method |
| 5 | server-queue.h:141 | C2064 callback not a function taking 1 arg | Upstream changed `callback_sleeping_state` from single `std::function<void(bool)>` to `std::vector<std::function<void(bool)>>`. The local cache-tests seam `debug_invoke_sleeping_state_for_tests()` still called it as a single cb. | Iterate the vector (same as upstream in server-queue.cpp). | LLAMA_SERVER_CACHE_TESTS seam; upstream multi-callback order |
| 6 | server-context.cpp:46 | C2371 'json' redefinition | Local whole-file side kept `using json = nlohmann::ordered_json;` while merged headers (server-common.h, server-task.h) now use `using json = common_json;` (pimpl wrapper in common/json.h). | Removed the local `using json` line; server-context.h already includes json.h. | Upstream common_json authoritative; local json call sites migrated (below) |
| 7 | server-context.cpp:347 | C2011 'server_metrics' redefinition | Both parents defined `server_metrics`: local whole-file side (flat fields) and upstream server-common.h (bucket-based). | Kept upstream server-common.h struct; removed local duplicate; migrated all local `metrics.*` call sites. | Upstream server_metrics authoritative; /metrics output preserved |
| 8 | server-context.cpp:494 | C2079 uses undefined 'server_metrics' | Follow-on of #7 (`metrics` member of impl referenced incomplete type after duplicate removal). | Resolved by #7. | - |
| 9 | server-context.cpp:1087 | C2664 on_new_task lambda | Upstream `on_new_task(std::function<bool(server_task&&, bool)>)`. Local lambda had 1 arg, void return. | Added `bool /* is_yielding */` param and `return true;` (never declines, matching prior behavior). | Task scheduling unchanged; queue yield protocol respected |
| 10 | server-context.cpp:2287-2306 | C2039 `server_task_result_metrics` member removals | Upstream split `/metrics` (server_task_result_metrics{metrics, n_processing_slots, n_tasks_deferred}) from `/slots` (server_task_result_slots{slots_data, n_idle_slots}) and moved `t_start`, slots_data, flat counters out. Local poured slots into the metrics task. | Split METRICS and SLOT_GET task handlers to match merged structs; METRICS carries `metrics` + n_processing_slots + n_tasks_deferred; SLOT_GET carries slots_data + n_idle_slots. | /metrics + /slots endpoints, upstream task-result shapes |
| 11 | server-context.cpp:4598-4643 | C2440 json initializer / missing members in /metrics render | Local rendered Prometheus inline from removed flat fields with nlohmann initializer syntax. | /metrics now uses `res_task->to_metrics()` for base metrics (keeps same metric names), then appends the local cache/checkpoint/stage10/31/39 Prometheus rows. t_start read from `res_task->metrics.t_start`. | Prometheus metric set and label shape preserved; cache rows untouched |
| 12 | server-context.cpp:4602,5093,5133,5139 | C2039 `__this`/flat members | Follow-on of #10 flat member removal at /metrics + /slots handlers. | /slots posts SLOT_GET, reads `server_task_result_slots`, returns `res_task->to_json()`. | /slots endpoint |
| 13 | server-context.cpp:4130 | C2660 `eval_llama_cmpl_schema` takes 5 args | Upstream dropped the `n_ctx` param. | Removed `meta->slot_n_ctx` from the call. | schema parsing, upstream signature |
| 14 | server-context.cpp:5448 | C2440 `json({"completion","multimodal"})` | common_json has no braced-list function-cast; use `json::array(...)`. | `json::array({"completion","multimodal"})` / `json::array({"completion"})`. | get_models response shape |
| 15 | server-context.cpp:5555 | C2440 `<function-style-cast>` initializer list | Local `/get_models` constructed `json models = {"models", {{...}}}` with ambiguous nested braced array. | Rebuilt with explicit `json::array({...})` for "models"/"data"/"tags"/"families" (upstream form). | get_models response shape |
| 16 | server-context.cpp:5624 | C2440 common_json to vector `llama_token` | common_json has no implicit conversion to `llama_tokens`. | `body.at("tokens").get<std::vector<int>>()` (llama_tokens is vector of int). | post_detokenize |
| 17 | server-context.cpp:5951 | C2440 common_json to int | No implicit numeric conversion. | `body.at("embd_normalize").get<int>()`. | post_embeddings |
| 18 | tests/test-cache-controller.cpp:1337 | C2039 'data' not a member of 'server_prompt' | Local unit test used BASE `server_prompt{ tokens, data, checkpoints }`. | Rewrote to `server_prompt_cache_state{ prompt, data }` + `server_prompt::clone()`. | Unit test coverage for prompt-cache state |
| 19 | tests/test-cache-controller.cpp:3819-3916 | C2440 common_json to size_t | common_json has no implicit numeric conversion. | Added `.get<size_t>()` to 5 `size_t x = stats["..."]` sites. | Stage 21/23 resident-byte invariant tests |

## Metrics increment conversion (contract note)

Local merged `metrics.*` call sites were migrated to upstream `server_metrics` API:

- `metrics.on_decoded(slots)` -> inline `n_decode++`, `n_busy_slots++` for processing slots, `n_tokens_max = max(...)`.
- `metrics.on_prompt_eval(slot)` -> `metrics.add_prompt(slot.n_prompt_tokens_processed, (uint64_t)(slot.t_prompt_processing * 1e3))` + n_tokens_max.
- `metrics.on_prediction(slot)` (x2) -> `metrics.predict/predict_bucket.add(stats.n_gen, stats.n_gen_steps(), stats.t_gen_us())` using `slot.get_timings()`; draft counters credited from `stats`.

The cumulative counters and the reset-bucket window semantics match the local flat behavior: the `/metrics` gauge rows (prompt_tokens_seconds, predicted_tokens_seconds) come from `prompt_bucket`/`predict_bucket`, which `reset_bucket()` clears on each scrape, identical to the old per-bucket fields.

## Evidence files

- `stage40-build-errors-01.txt` .. `-04.txt` (iteration logs)
- `stage40-build-tcc-01..03.txt`, `stage40-ctest-cache-01.txt`, `stage40-tcc-direct-01.txt`

## Handoff

Next gate: Architect re-review of build fixes, then QA re-execution of the Stage 40 test plan from a clean tree.
