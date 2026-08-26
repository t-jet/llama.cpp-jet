# Stage 40 merge log 2026-08-26

## Source-ref recheck at merge time

| Check | Command | Output |
| --- | --- | --- |
| Branch | `git rev-parse --abbrev-ref HEAD` | `work-branch` |
| Local tip | `git rev-parse HEAD` | `e9d67a2fb6ad6b186a52b6b35f20d7c9e325c047` |
| Approved source ref | `git rev-parse origin/upstream_master` | `fc35562ba46fbbf8e30cac85edbb39642c37d248` |
| Merge base | `git merge-base HEAD origin/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Range count | `git rev-list --count HEAD..origin/upstream_master` | `732` |

Freshness at merge time: canonical upstream (`git ls-remote https://github.com/ggml-org/llama.cpp.git master`) is now `4d19b287691e8f47fc303be420f630c40ec45684`, one commit past the approved `fc35562ba`. That one commit is `ci: Clean up UI builds from releases (#27706)` - CI-only workflow change, no cache/server contract impact. Same NO-OP class as the verified D40-PLAN-01 gap. Approved ref kept. No stop required; gap recorded.

Note: `git ls-remote upstream master` fails because the fork has a single remote `origin`; the local tracking branch `origin/upstream_master` is intentionally pinned at the approved SHA (fetch is rejected as non-fast-forward). The pin is by design; the ref was not moved.

## Merge command and result

```text
git merge --no-ff --no-commit origin/upstream_master
```

- Result: exit 1 (textual conflicts), automatic merge failed as expected
- MERGE_HEAD: `fc35562ba46fbbf8e30cac85edbb39642c37d248`
- Open merge state: retained (no commit), per no-commit constraint
- Index: 1799 files staged after resolution; 0 unmerged files remaining; 0 conflict markers in code

## Textual conflicts resolved (10 files)

| File | Type | Resolution | Prior-stage contract preserved |
| --- | --- | --- | --- |
| `AGENTS.md` | content, 3 regions | Keep local agent instructions + upstream project guidelines (both) | Repo instructions (fork + upstream) |
| `README.md` | content | Keep local fork section + upstream links | Fork README identity |
| `common/common.cpp` | content | Take upstream `common_fit_extra_model extra` fit call (params.fit_params_target.data(), has_draft\|spec_mtp ? &extra : nullptr) | Stage 5 MTP fit headroom; upstream extra-model API (merged fit.cpp requires it) |
| `common/fit.h` | content | Combined: upstream `common_fit_extra_model` + upstream `common_fit_params` signature + local `common_get_mtp_ctx_memory_overhead` decl | Stage 6/11 MTP fit memory helper + upstream fit API |
| `tools/server/CMakeLists.txt` | content | Keep local hybrid cache sources + add upstream `server-mcp.*` | Stage 25 cache controller build + upstream MCP |
| `tools/server/server-common.cpp` | content, 2 regions | Keep local `cache_token_ids()`; take upstream `serialize()/deserialize()`; upstream mtmd_input_text text+len | Stage 31/34 cache identity + upstream MTMD state |
| `tools/server/server-task.cpp` | content, 4 regions | Keep local alloc guards + `discard()`; upstream param rename ctx_tgt/ctx_dft; keep local defensive empty checks | Stage 21 prompt-cache guards + legacy prompt cache stability |
| `tools/server/server-task.h` | content | Keep local `discard()`; upstream param rename | Stage 21 prompt-cache + upstream current names |
| `tools/server/server.cpp` | content | Keep local Windows crash-diag (D-EXEC-26-03) + upstream SIGPIPE/SIG_IGN + `server_stream_session_manager_start()` | Stage 24/26 crash diagnostics + upstream stream session |
| `tools/server/server-context.cpp` | content, whole-file | Local whole-file side (Stage 35 precedent: "Chose local whole-file side because the conflict covered the whole file"). Upstream route/session/schema evolution carried by other auto-merged files (server-stream, server-schema, server-common, server-queue, server-mcp). | Stage 5 MTP/pair-state, Stage 9 checkpoint, Stage 13 routes, Stage 25 tx contracts, Stage 31/32 metrics, Stage 34 replay + slow-read, Stage 39 retention. |

## Missing-file restoration (semantic fix)

The auto-merge dropped the local test helper `tests/get-model.cpp` and `tests/get-model.h` (upstream does not have them; they are local-only and were not carried into the index). Restored from HEAD:

```sh
git checkout HEAD -- tests/get-model.cpp tests/get-model.h
```

Without this, CMake configure failed: "No SOURCES given to target: test-step10-metrics" and 13 local cache test targets referenced the missing source.

## Semantic conflict scans

| Scan | Command | Result |
| --- | --- | --- |
| Conflict markers | `git grep -n -E "^(<<<<<<<\|>>>>>>>)" -- common/* tools/server/* src/* tests/*` | PASS: 0 matches |
| Duplicate static defs | statics in server-context.cpp grouped by name | PASS: no duplicates |
| Header method coverage | every server-context.h method found defined in server-context.cpp | PASS: load_model, start_loop, terminate, get_*, set_state_callback, debug_*, init_routes, get_model_info all defined; update_meta is inline in header |
| Stale-symbol scan | upstream-only helpers absent from local server-context.cpp | PASS: no `common_speculative_init_from_params`, `server_output_limits`, `serialize/deserialize`, `spec_is_replay`, `inp_embd` in local side |
| Dropped local files | `git ls-tree HEAD` vs `git ls-files` diff | 2 restored (get-model.cpp, get-model.h); none other lost |
| Cross-file deps | server-mcp.cpp self-contained (no server_context dep) | PASS |

## Rework track status

| Track | Rows | Status | Basis |
| --- | --- | --- | --- |
| Track 1 MTP/KV/spec | 88a3927, 8c146a83, d1b3425, d789527, f5014e1a | PARTIAL | Local server-context.cpp retains local MTP/KV pair-state wiring; upstream speculative/context API auto-merged into the common and src trees. Full rework closure (runtime MTP/KV shape verification) not completed this session. |
| Track 2 route/session | 1a87dcd, fbbf3ad | PARTIAL | Local server-context.cpp retained for route/hybrid; upstream stream/mcp files auto-merged. Focused route/session rework verification not completed. |
| Track 3 checkpoint | 73618f2, f5ddcd1, f20469d, f6dcda3 | PARTIAL | Local whole-file kept checkpoint placement/prompt-span contracts; upstream `message_spans`/checkpoint changes in other files not re-verified this session. |

All three tracks need focused verification before they can be called PASS; the local-first whole-file resolution preserves the contracts structurally, but per the plan these are not silent integrations.

## Build evidence

- Configure: `cmake -S . -B build-cuda` - SUCCESS (after restoring get-model helper)
- Focused build: `cmake --build build-cuda --config Release --target llama-server test-cache-controller`
- Status: IN PROGRESS / PARTIAL at the time of this log. Full-tree CUDA rebuild (merge touched ggml/*) compiling; llama-server and test-cache-controller targets not yet reached within the 600s budget.
- See part-10 for final build state.

## Deferred / known gaps

- Full clean build of llama-server + test-cache-controller not completed (CUDA rebuild in progress, >600s).
- ctest cache regression not run (depends on test-cache-controller binary).
- Focused coverage not run (part of post-build regression, was optional "if time permits").
- Stage 39 VS2022 conformance gap carried forward (unchanged).
- Recheck of canonical upstream staleness at regression time pending (Manager decision on the `4d19b287` CI-only gap).

## Handoff

Next gate: Manager / QA. Next owner: QA regression after the focused build completes, then Architect merge-log review. Rework tracks need either fresh Developer sessions or plan-approved downgrade to INTEGRATE with focused verification.

The open no-commit merge is preserved at MERGE_HEAD `fc35562ba`. No commit, no push, no PR was performed.
