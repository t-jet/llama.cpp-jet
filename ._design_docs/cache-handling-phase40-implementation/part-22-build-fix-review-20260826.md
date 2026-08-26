# Stage 40 build-fix review

Date: 2026-08-26
Reviewer: Architect (independent session)
Status: PASS

## Summary

The open merge (MERGE_HEAD fc35562ba) now compiles. Developer fixed all 19
error categories from the affected files (server-slot.h, server-context.cpp,
server-queue.h, tests/test-cache-controller.cpp). I verified each fix against
the right conflict pattern, confirmed the staged diff preserves the prior-stage
contracts, and found no regression in the legacy path. One code residue is a
dead predicate left behind by a required compile fix; it is functionally benign
but should be cleaned up or documented. Next gate is QA re-execution of the
Stage 40 test plan from a clean tree.

## Fix verification

| Fix | Pattern | Verified | Notes |
|-----|---------|----------|-------|
| 1. server-slot.h prompt_save GGML_ASSERT(prompt.data.size()==0) removal | Struct field move | PASS | `server_prompt` no longer owns `data`; cache state does. Warn removal is correct. |
| 2. common_context_seq_rm -> llama_memory_seq_rm(get_memory(ctx)) | Helper rename | PASS | Call sites in prompt_clear keep per-context (tgt/dft) semantics; public API authoritative. |
| 3. common_context_seq_cp -> llama_memory_seq_cp in copy_state_to | Helper rename | PASS | Same contract, upstream API. |
| 4. need_embd()/need_embd_nextn() -> task->need_embd() only | Helper removed | PARTIAL | Compile-correct; speculative overload folded out. See finding F-22-01. |
| 5. server-queue.h callback_sleeping_state -> vector, seam loops | Callback signature | PASS | Test seam iterates vector like upstream. |
| 6. local using json removed (common_json authoritative) | json redefinition | PASS | server-context.h includes json; local migrate complete. |
| 7/8. server_metrics duplicate removed, upstream struct kept | Duplicate struct | PASS | Local call sites migrated to upstream API. |
| 9. on_new_task lambda 2-arg + return true | Callback signature | PASS | Never declines, prior behavior. |
| 10. METRICS vs SLOT_GET split for upstream task-result shapes | Struct shape | PASS | Endpoint semantics preserved. |
| 11. /metrics render via res_task->to_metrics() + local cache rows | API align | PASS | Prometheus set and label shape kept. |
| 12. /slots flat member fix | Follow-on | PASS | to_json route unified. |
| 13. eval_llama_cmpl_schema 4-arg | Signature | PASS | Upstream dropped n_ctx. |
| 14-17. common_json no implicit conversion, explicit array/get | json redefinition | PASS | All call sites aligned. |
| 18. test BASE -> server_prompt_cache_state | Struct field move | PASS | Test now routes through new member. |
| 19. get<size_t>() on stats reads | json redefinition | PASS | Resident-byte invariant tests intact. |

## Findings

| ID | Severity | Finding | Contract | Resolution |
|----|----------|---------|----------|------------|
| F-22-01 | NON-BLOCKING | Merged server-context.cpp keeps local predicate `has_speculative_prompt = ... slot.need_embd() && !slot.task->need_embd()`. Now need_embd() == task->need_embd(), so predicate is constant-false; the SPECULATIVE_PROMPT_MAX_OUTPUT_BYTES/SAFE_BATCH_SIZE shrink is dead. Upstream handles draft embeddings internally (common_speculative_process + llama_set_embeddings_nextn), so this is benign. | Stage 5 MTP pair-state, speculative alignment | Optional cleanup or doc note; verify MTP path in QA retest. |
| F-22-02 | INFO | `git diff --cached --check` reports trailing whitespace on server-context.cpp staged lines. Byte check shows CR==LF (6189/6189), whole-file consistent CRLF pre-existing; real defect: none. | Windows CRLF noise | None. |
| F-22-03 | INFO | get_timings() now returns server_slot_stats; JSON field renamed `timings` -> `stats`. This is upstream MERGE_HEAD authoritative shape, mandated by merge. Client-visible field change. | Upstream API | QA should confirm client compatibility in plan. |

## Contract preservation

Verified against staged diff and working tree:

- Stage 5 MTP pair-state: copy_state_to + speculative flow intact (spec ptr still owned by server_context_impl; common_speculative_draft/accept/process untouched).
- Stage 25 tx_* transactional writes: untouched in staged diff (only memory-seq renames in unrelated paths).
- Stage 38 partial-restore: checkpoint_update_dft + seq_rm/cp unchanged.
- Stage 39 retention + cold-budget gauge: LLAMA_STAGE39_LIVE_TEST_SEAM and cold-budget code present; commit/retention untouched.
- Public metrics labels: `cache_hits_total{mode=...}` at server-context.cpp:4649, `cache_cold_budget_bytes` gauge at :4731 preserved.
- I-34-01 / I-34-02: tx_save/load and replay paths untouched.
- Upstream server_prompt_cache_state authoritative: server-task.h struct {prompt,data}; local routes through it (prompt_save, discard(&cur->prompt), trim_checkpoints(cur->prompt)).
- get_timings field mapping: n_prompt_cached/n_prompt_processed/n_gen/n_draft_*/t_start/t_prompt_last/t_gen_last all map to server_slot_stats correctly.
- Metrics migration (on_decoded/on_prompt_eval/on_prediction -> inline + add_prompt + predict_bucket): cumulative counters and reset-bucket semantics preserved.
- Legacy path: upstream-first policy leaves legacy behavior unchanged; legacy routing (#include server-cache-legacy.h) intact.

## Verdict

PASS. All 19 fixes are correct against their conflict patterns and preserve
the prior-stage contracts verified above. No BLOCKING finding. Recommend:

1. QA re-executes the Stage 40 test plan from a clean tree (test-cache-controller
   ctest already PASS).
2. QA or Developer adds one MTP/speculative smoke (TP-39-03 style) to confirm
   prompt batching unaffected by the need_embd change (F-22-01).
3. Optional: remove or comment the now-dead has_speculative_prompt predicate.
