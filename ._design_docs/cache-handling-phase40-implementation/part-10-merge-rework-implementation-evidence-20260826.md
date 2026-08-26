# Stage 40 merge/rework implementation evidence 2026-08-26

Owner: Developer. Stage: 40 upstream merge cycle. This part records the as-executed merge, conflict resolution, semantic scans, build evidence, and rework track status for the implementation gate.

## Merge command and result

```text
git merge --no-ff --no-commit origin/upstream_master
```

- Result: exit 1; automatic merge failed with 10 textual conflicts
- MERGE_HEAD: `fc35562ba46fbbf8e30cac85edbb39642c37d248`
- Merge state left open (no commit), no push, no PR, no history rewrite
- Index after resolution: 1799 files staged, 0 unmerged, 0 conflict markers

Detailed triage and conflict tables: part-20-merge-log-20260826.md.

## Source-ref recheck at merge time

| Check | Value |
| --- | --- |
| origin/upstream_master | `fc35562ba46fbbf8e30cac85edbb39642c37d248` (unchanged, approved) |
| Canonical upstream master | `4d19b287691e8f47fc303be420f630c40ec45684` |
| Drift | +1 commit, CI-only (`ci: Clean up UI builds from releases (#27706)`), NO-OP for cache/server contracts |
| Merge base | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Range count | 732 |

Gap handling: approved ref kept; the single post-approval commit matches the verified D40-PLAN-01 NO-OP class. Recorded as Manager-decision item for regression-time recheck.

## Conflict list (10 files)

| File | Type | Resolution | Prior-stage contract |
| --- | --- | --- | --- |
| `AGENTS.md` | content x3 | Keep both (fork agent rules + upstream guidelines) | Repo instructions |
| `README.md` | content | Keep both (fork section + upstream links) | Fork README |
| `common/common.cpp` | content | Upstream `common_fit_extra_model` fit call | Stage 5 MTP fit |
| `common/fit.h` | content | Union: upstream extra-model API + local MTP overhead helper | Stage 6/11 MTP fit |
| `tools/server/CMakeLists.txt` | content | Local hybrid sources + upstream server-mcp | Stage 25 build |
| `tools/server/server-common.cpp` | content x2 | Local `cache_token_ids()` + upstream serialize/deserialize + upstream mtmd_input_text | Stage 31/34 + MTMD |
| `tools/server/server-task.cpp` | content x4 | Local guards + `discard()` + upstream param rename | Stage 21 cache guards |
| `tools/server/server-task.h` | content | Local `discard()` + upstream param rename | Stage 21 |
| `tools/server/server.cpp` | content | Local crash-diag (D-EXEC-26-03) + upstream SIGPIPE + stream session | Stage 24/26 + stream |
| `tools/server/server-context.cpp` | content, whole-file | Local whole-file side (Stage 35 precedent) | Stages 5,9,13,25,31/32,34,39 |

Missing-file restoration: `tests/get-model.cpp` + `tests/get-model.h` restored from HEAD (auto-merge dropped them; CMake failed without them).

## Semantic conflict scans

All scans PASS:

- Conflict markers: 0 in code
- Duplicate static definitions: none in server-context.cpp
- Header method coverage: all server-context.h methods defined (update_meta inline in header)
- Stale upstream-only symbols: absent from local server-context.cpp
- Dropped local files: only get-model pair, restored
- Cross-file deps: server-mcp self-contained

## Build evidence

| Step | Command | Result |
| --- | --- | --- |
| Configure | `cmake -S . -B build-cuda` | PASS after restoring get-model helper (first run failed: 13 cache test targets referenced missing `tests/get-model.cpp`) |
| Focused build | `cmake --build build-cuda --config Release --target llama-server test-cache-controller` | PARTIAL (documented). Full-tree CUDA rebuild: merge touched ggml-cuda so the entire backend recompiles via nvcc. Observed progress through ggml-cuda sources (argsort, conv2d, fattn-tile, dsv4-hc, mmq, pad, ssm-conv, fattn-tile-instance-*, fattn-mma-f16-instance-*). llama-server and test-cache-controller binaries not relinked within the build window. ggml-cuda.lib still stale (07/28) at time of write. Build active and progressing, not failed. |

Final observed build state: MSBuild alive with nvcc cycling through ggml-cuda flash-attention instantiations (fattn-mma-f16-*). Build exceeded the 600s budget by a wide margin; per plan this is a recorded partial result. Full output was piped through Select-Object which buffered it; live progress verified via object-file timestamps and process inspection.

## Ctest cache result

Not run. Depends on `test-cache-controller` binary, which the focused build had not produced within the build window.

## Rework track status

| Track | Rows | Status |
| --- | --- | --- |
| Track 1 MTP/KV/spec | 88a3927, 8c146a83, d1b3425, d789527, f5014e1a | PARTIAL - local server-context.cpp preserves local MTP/KV pair-state wiring; upstream common/speculative + src context API auto-merged. Runtime shape verification pending. |
| Track 2 route/session | 1a87dcd, fbbf3ad | PARTIAL - local server-context.cpp retained for routes/hybrid; upstream server-stream/server-mcp auto-merged. Focused session/replay verification pending. |
| Track 3 checkpoint | 73618f2, f5ddcd1, f20469d, f6dcda3 | PARTIAL - local whole-file kept checkpoint/prompt-span placement; upstream checkpoint/message-span changes in other files not re-verified. |

All three tracks preserved structurally by the local-first whole-file resolution, but require focused verification (not silent integrations per the plan).

## Blockers / notes

- The open no-commit merge at MERGE_HEAD `fc35562ba` is the terminal state. It records the resolved merge under the no-commit constraint.
- Build exceeded 600s; per plan this is a recorded partial result, not a failure of the merge logic.
- VS2022 conformance gap from Stage 39 carried forward unchanged.
- Regression (ctest -R cache) and focused coverage are deferred until the focused build completes.

## Update note (post-log)

The background build was still compiling the ggml-cuda backend when this part was finalized (fattn-mma-f16 instantiation cycle). Final binary outcome, ctest -R cache, and focused coverage remain pending on that build. If the build completes, a follow-up session should append the llama-server/test-cache-controller relink evidence and run the cache ctest; if it never completes in-tree, the documented partial is the closure state for this gate.
