# Stage 35 refreshed pre-merge analysis 2026-07-07

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Status

Verdict: REFRESHED ANALYSIS READY FOR ARCHITECT REVIEW.

Owner: Developer

Date: 2026-07-07

No merge command, conflict resolution, production code edit, regression run,
commit, push, PR, or reviewer response was performed.

## Metadata

| Field | Value |
| --- | --- |
| Branch | `work-branch` |
| Local tip | `344f5c5e243b9500bf4da60709aa12a39d8a6c5a` |
| Source ref | `origin/upstream_master` |
| Refreshed source tip | `6c487e2f79dea747d70325250121e750ed364b2b` |
| Actual upstream `master` | `6c487e2f79dea747d70325250121e750ed364b2b` |
| Fork point / merge base | `18ef86ecec723361362a332a79b4d913fd724d40` |
| Range | `HEAD..origin/upstream_master` |
| Prior accepted analysis tip | `108f186d1701d56133a0239dd6754c8814374cbf` |
| Prior accepted count | 308 |
| Refreshed count | 312 |
| Date range | 2026-06-11 to 2026-07-07 |
| Filtered count | 91 |
| Working tree | Dirty with planning docs and Developer memory; Manager planning-only exception applies per part 10. |

## Source-ref refresh

| Command | Result |
| --- | --- |
| `git status --short` | Existing dirty planning state: `M ._design_docs/cache-handling-phase35-implementation.md`; `M ._design_docs/document-index.md`; `M .agents/skills/self-improvement/assets/developer.md`; `?? ._design_docs/cache-handling-phase35-implementation/part-09-implementation-preflight-20260707.md`; `?? ._design_docs/cache-handling-phase35-implementation/part-10-manager-source-ref-decision-20260707.md`. |
| `git rev-parse HEAD` | `344f5c5e243b9500bf4da60709aa12a39d8a6c5a` |
| `git rev-parse origin/upstream_master` before fetch | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| `git ls-remote https://github.com/ggml-org/llama.cpp.git master` before fetch | `6c487e2f79dea747d70325250121e750ed364b2b refs/heads/master` |
| `git fetch https://github.com/ggml-org/llama.cpp.git master:refs/remotes/origin/upstream_master` | Fast-forwarded `origin/upstream_master` from `47e1de77a` to `6c487e2f7`; fetched tags `b9895` and `b9897`. |
| `git rev-parse origin/upstream_master` after fetch | `6c487e2f79dea747d70325250121e750ed364b2b` |
| `git log -1 --format="%H %ai %s" origin/upstream_master` | `6c487e2f79dea747d70325250121e750ed364b2b 2026-07-07 10:24:35 -0300 server: enforce prompt cache RAM limit (#25070)` |
| `git ls-remote https://github.com/ggml-org/llama.cpp.git master` after fetch | `6c487e2f79dea747d70325250121e750ed364b2b refs/heads/master` |

Staleness verdict: current. The refreshed source ref equals actual upstream
`master`.

## Verification checks

| Check | Command | Output |
| --- | --- | --- |
| Local tip detail | `git log -1 --format="%H %ai %s" HEAD` | `344f5c5e243b9500bf4da60709aa12a39d8a6c5a 2026-07-07 16:52:22 +0300 docs: advance Stage 35 planning gates` |
| Merge base | `git merge-base HEAD origin/upstream_master` | `18ef86ecec723361362a332a79b4d913fd724d40` |
| Refreshed count | `git rev-list --count HEAD..origin/upstream_master` | `312` |
| Actual upstream | `git ls-remote https://github.com/ggml-org/llama.cpp.git master` | `6c487e2f79dea747d70325250121e750ed364b2b refs/heads/master` |
| Remote config | `git remote -v` | `origin https://github.com/t-jet/llama.cpp-jet.git (fetch)`; `origin https://github.com/t-jet/llama.cpp-jet.git (push)` |
| Date first | `git log --reverse --format="%ai" HEAD..origin/upstream_master | Select-Object -First 1` | `2026-06-11 09:43:04 -0400` |
| Date last | `git log --reverse --format="%ai" HEAD..origin/upstream_master | Select-Object -Last 1` | `2026-07-07 10:24:35 -0300` |

## Prefix proof

The prior accepted analysis range is still a prefix of the refreshed range.

| Check | Command | Output |
| --- | --- | --- |
| Prior tip is ancestor | `git merge-base --is-ancestor 108f186d1701d56133a0239dd6754c8814374cbf origin/upstream_master` | exit `0` |
| Prior count | `git rev-list --count HEAD..108f186d1701d56133a0239dd6754c8814374cbf` | `308` |
| Refreshed count | `git rev-list --count HEAD..origin/upstream_master` | `312` |
| Delta count | `git rev-list --count "108f186d1701d56133a0239dd6754c8814374cbf..origin/upstream_master"` | `4` |
| Prefix compare | PowerShell compared `git rev-list --reverse HEAD..108f186d1701...` with the first 308 SHAs of `HEAD..origin/upstream_master` | `prior_prefix=True` |

Part 01 per-commit rows remain unchanged for the first 308 commits. This report
adds only the four new upstream commits after `108f186d1701`.

## Delta filter

| SHA | Subject | Files | Stage 35 result |
| --- | --- | --- | --- |
| `024c46ae4e37` | `llama: fix quantized kv-cache for dsv4 (#25202)` | `src/llama-graph.cpp`; `src/llama-impl.h`; `src/llama-kv-cache.cpp`; `src/models/deepseek4.cpp` | Included: KV/checkpoint and DeepSeek V4. |
| `33ca0dcb9d78` | `ggml-hip : add -fno-finite-math-only alongside -ffast-math (#25373)` | `ggml/src/ggml-hip/CMakeLists.txt` | Excluded: backend build flag, no local evidence command change. |
| `c1a411fb1b55` | `common : add missing <fstream> include in common.h (#25220)` | `common/common.h` | Excluded: compile include fix, no cache, route, template, KV, metric, or evidence contract touched. |
| `6c487e2f79de` | `server: enforce prompt cache RAM limit (#25070)` | `tools/server/server-task.cpp` | Included: server prompt-cache behavior. |

## New triage rows

| SHA | Subject | Groups | Contracts | Decision | Reason / owner |
| --- | --- | --- | --- | --- | --- |
| `024c46ae4e37` | quantized KV cache for DSV4 | KV, spec | Checkpoint/KV, Stage 5, Stage 9 | REWORK-REQUIRED | Changes DSV4 KV graph/cache handling and follows the prior DeepSeek V4 row; add to the MTP/KV/speculative rework scope before merge. Architect/Manager. |
| `6c487e2f79de` | prompt cache RAM hard limit | Server cache, task | Server prompt cache, route/session evidence | INTEGRATE | Changes `server_prompt_cache::alloc` eviction/admission semantics; integrate with focused scan that hybrid opt-in cache policy and checkpoint evidence stay intact. Developer. |

No prior row changed decision.

## Aggregate summary

| Decision | Prior count | Delta | Refreshed count |
| --- | ---: | ---: | ---: |
| NO-OP | 13 | 0 | 13 |
| INTEGRATE | 67 | +1 | 68 |
| REWORK-REQUIRED | 9 | +1 | 10 |
| DEFER | 0 | 0 | 0 |
| REVERT | 0 | 0 | 0 |

Filtered commits: 91 of 312. Delta excluded commits: 2.

Prior-stage surfaces touched remain: Stage 5 target/draft MTP, Stage 9
checkpoint admission, Stage 13 route compatibility, Stage 25 transaction
assumptions, Stage 31/32 metric/namespace shape, Stage 34 branch/session
replay evidence, and architecture part 9 prompt-span boundary. The new DSV4 KV
row extends the existing MTP/KV rework track. The new prompt-cache RAM row adds
a server prompt-cache scan to the integrate set.

## Expected touched local files and dirs

Part 01 expected files still apply. Add or recheck these delta paths:

- `src/llama-graph.cpp`
- `src/llama-impl.h`
- `src/llama-kv-cache.cpp`
- `src/models/deepseek4.cpp`
- `tools/server/server-task.cpp`

## Manager decisions requested

- Confirm the refreshed aggregate count: 13 NO-OP, 68 INTEGRATE, 10
  REWORK-REQUIRED, 0 DEFER, 0 REVERT.
- Confirm `024c46ae4e37` joins the existing MTP/KV/speculative rework track
  rather than opening a separate DeepSeek V4 rework.
- Confirm `6c487e2f79de` stays INTEGRATE with focused server prompt-cache and
  hybrid opt-in scans, or escalate it to a route/session rework.
- Confirm the planning-only dirty exception remains acceptable until the next
  clean-tree gate.

## Open questions

- Does strict upstream prompt-cache RAM eviction need a Stage 35 route/session
  rework, or is focused integration evidence enough because hybrid mode has its
  own cache policy?
- Should the DSV4 quantized KV fix be cited in the existing DeepSeek V4
  REWORK-REQUIRED row from part 01, or listed as a separate rework trigger in
  the MTP/KV design part?

## Handoff

Next owner: Architect.

Next gate: refreshed pre-merge analysis review.

Merge execution, conflict resolution, regression runs, commits, pushes, PRs,
and reviewer responses remain blocked.
