# Stage 40 implementation review

Date: 2026-08-26
Reviewer: Architect (independent session)
Status: **REWORK** 

## Summary

Ten textual conflict resolutions follow policy correctly (local-first for hybrid/cache, upstream-first for legacy). Semantic scans cover standard categories but miss one critical cross-file type compatibility check. A **BLOCKING** compile error exists: upstream removed `struct result_timings` from `server-task.h` (replaced with `server_slot_stats`) but local-only `server-slot.h` still returns `result_timings` from `get_timings()`. The struct has no definition in the staged image. Initial targeted cmake build on a full-tree CUDA rebuild would not have caught this until server-slot.h gets compiled. The staged diff of `server-context.cpp` (0 lines) and `server-task.h` (struct removed) independently confirm the gap.

## Conflict verification

| File | Resolution policy | Verified | Notes |
|------|------------------|----------|-------|
| AGENTS.md | Keep both (fork+upstream) | PASS | 3 regions, correct per policy |
| README.md | Keep both (fork+links) | PASS | Non-code, no contract impact |
| common/common.cpp | Upstream-first (extra-model fit) | PASS | Takes upstream new API; local MTP fit compat via fit.h union |
| common/fit.h | Union (upstream API + local helper) | PASS | Both declarations present in staged |
| tools/server/CMakeLists.txt | Local hybrid + upstream server-mcp | PASS | local cache sources + upstream server-mcp.cpp/.h added |
| tools/server/server-common.cpp | Local cache API + upstream serialize/mtmd | PASS | cache_token_ids() local kept; serialize/deserialize + mtmd_input_text upstream |
| tools/server/server-task.cpp | Local guards+discard + upstream rename | PASS | alloc() return type changed to `server_prompt_cache_state*` (upstream) |
| tools/server/server-task.h | Local discard + upstream enum/rename | PASS | discard() header present; SERVER_TASK_TYPE_SLOT_GET added upstream |
| tools/server/server.cpp | Local crash-diag + upstream SIGPIPE + stream | PASS | llama_server_terminate(), SIGPIPE, stream session all present |
| tools/server/server-context.cpp | Local whole-file (Stage 35 precedent) | PASS | 0-line staged diff confirms local side kept |

## Findings

| ID | Type | Finding | Severity | Contract | Resolution |
|----|------|---------|----------|----------|------------|
| F1 | Cross-file type compat | Upstream removed `struct result_timings` from `server-task.h` (replaced with `server_slot_stats`). Local-only `server-slot.h` (0 staged diff) uses `result_timings` as return type of `get_timings()` and local variable. Type has no definition in staged tools/server/ tree. Will not compile. | **BLOCKING** | Stage 31/34 metrics, Stage 39 retention | Update server-slot.h `get_timings()` to return `server_slot_stats` or re-add `struct result_timings` to a shared header. |
| F2 | Semantic scan gap | Merge log runs 7 scan categories but no cross-file type compatibility scan. F1 would have been caught by checking that every type used in a local-only file exists in the merged upstream tree. | NON-BLOCKING | Procedure | Add cross-file type audit to semantic scan checklist for future merges. |
| F3 | Rework track classification | All 3 tracks marked PARTIAL with justification "structurally preserved by local-first resolution." This is correct per plan because focused verification is deferred. However the plan's Phase 6 (rework closure) was never reached before build. | NON-BLOCKING | Plan procedure | Acceptable as deferred per plan. Document that Phase 6 activities are truly pending, not silently waived. |
| F4 | Build partial state | Focused build timed out at 600s on full CUDA ggml-cuda rebuild. This is unavoidable with a full-tree merge touching ggml backends. Does not block review because F1 would prevent compile anyway. | INFO | Build gate | Acceptable timeout; no action needed. F1 supersedes build completeness. |
| F5 | result_timings usage depth | HEAD `server-context.cpp` has NO references to `result_timings` or field-level timings access. The only consumer is `server-slot.h::get_timings()`. Fix scope is limited to that one function and one header. | INFO | N/A | Narrow fix scope is positive for rework cost. |
| F6 | json.h migration | Upstream changes `using json = nlohmann::ordered_json` to `using json = common_json` (json.h wrapper). Multiple files updated. No cross-file inconsistency detected via spot check. | INFO | Upstream compatibility | Monitor if downstream code uses `nlohmann::ordered_json` directly. |

## Verdict

**Status: REWORK** -- 1 BLOCKING finding prevents compile.

**Finding count:** 1 BLOCKING / 2 NON-BLOCKING / 3 INFO

### Key findings

1. **BLOCKING F1**: `struct result_timings` removed from `server-task.h` by upstream merge, but local-only `server-slot.h` uses it. Will not compile. Fix: update `get_timings()` to use `server_slot_stats` or re-add the struct.
2. **NON-BLOCKING F2**: Semantic scans lack cross-file type coverage. Add to future merge procedure.
3. **NON-BLOCKING F3**: Rework tracks correctly PARTIAL but Phase 6 closure truly pending.

### Required corrections

- F1: Fix `tools/server/server-slot.h::get_timings()` signature and body to use `server_slot_stats` type, or define `result_timings` as type alias in a shared header. The fix scope is one function in one header; `server_slot_stats` has compatible fields (`n_prompt_cached` -> `cache_n`, `t_prompt_last`/`t_gen_last` timestamps cover the elapsed-time calculation, `n_draft_tokens`/`n_draft_accepted` map directly). Alternatively re-add `struct result_timings` in `server-task.h` and create a conversion function if the timestamps need translation.
- F2: Add "cross-file type compatibility -- every type used in local-only files must exist in merged tree" to semantic scan checklist.
- F3: No code fix needed. Note for handoff that rework verification remains pending.

### Next gate

Manager -> Developer (fix F1). After F1 fix, re-run merge semantic scan including the new cross-file type category, then targeted build of server files (not full CUDA rebuild). Then return to Architect for re-review.
