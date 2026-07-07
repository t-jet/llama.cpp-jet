VERDICT: PASS

# Stage 35 refreshed pre-merge analysis review 2026-07-07

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md) and [part 11](part-11-refreshed-pre-merge-analysis-20260707.md)

## Scope

Review type: independent Architect review of the refreshed Stage 35 pre-merge
analysis after source refresh to `6c487e2f79dea747d70325250121e750ed364b2b`.

Subject reviewed:

- Refreshed pre-merge analysis part 11.
- Stage 35 design entry, design rework parts 04-06, and Manager rework gate
  part 08.
- Stage 35 implementation entry and parts 01-05 and 09-11 as needed.
- Upstream merge guide entry and parts 01-04.

No merge, fetch, conflict resolution, production code change, regression run,
commit, push, PR, or reviewer response was performed during this review.

## Evidence checked

| Check | Review evidence | Result |
| --- | --- | --- |
| Local tip | `git rev-parse HEAD` -> `344f5c5e243b9500bf4da60709aa12a39d8a6c5a` | PASS |
| Source ref | `git rev-parse origin/upstream_master` -> `6c487e2f79dea747d70325250121e750ed364b2b` | PASS |
| Actual upstream master | `git ls-remote https://github.com/ggml-org/llama.cpp.git refs/heads/master` -> `6c487e2f79dea747d70325250121e750ed364b2b` | PASS |
| Merge base | Part 11 reports `18ef86ecec723361362a332a79b4d913fd724d40`; no contrary evidence found | PASS |
| Refreshed range count | `git rev-list --count HEAD..origin/upstream_master` -> `312` | PASS |
| Prior prefix count | `git rev-list --count HEAD..108f186d1701d56133a0239dd6754c8814374cbf` -> `308` | PASS |
| Prior tip ancestry | `git merge-base --is-ancestor 108f186d1701d56133a0239dd6754c8814374cbf origin/upstream_master` -> exit `0` | PASS |
| Delta count | `git rev-list --count 108f186d1701d56133a0239dd6754c8814374cbf..origin/upstream_master` -> `4` | PASS |
| Delta commits | `024c46ae4e37`, `33ca0dcb9d78`, `c1a411fb1b55`, `6c487e2f79de` | PASS |
| Delta filters | `024c46ae4e37` and `6c487e2f79de` match Stage 35 filters; HIP build flag and `<fstream>` include do not | PASS |
| Filtered count | Prior accepted filtered count `89` plus two included delta rows -> `91` | PASS |
| Delta decision counts | Parsed part 11 new triage rows -> `1 INTEGRATE`, `1 REWORK-REQUIRED` | PASS |
| Refreshed aggregate | Prior `13/67/9/0/0` plus delta `0/1/1/0/0` -> `13/68/10/0/0` | PASS |
| Dirty planning exception | Part 10 grants planning-only dirty exception; part 11 and entry keep merge blocked | PASS |

## Delta row review

`024c46ae4e37` is reviewable enough to join the existing MTP/KV/speculative
rework track. Its diff changes DSV4 KV graph/cache handling across
`src/llama-graph.cpp`, `src/llama-impl.h`, `src/llama-kv-cache.cpp`, and
`src/models/deepseek4.cpp`. It follows the accepted DeepSeek V4 rework row and
touches the same protected Stage 5, Stage 9, Stage 25, and architecture MTP/KV
contracts. A separate rework track is not needed unless Manager wants finer
tracking.

`6c487e2f79de` can remain INTEGRATE. It changes upstream
`server_prompt_cache::alloc` and `server_prompt_cache::update` in
`tools/server/server-task.cpp` so `--cache-ram` is a stricter prompt-cache
limit. The change is server prompt-cache behavior, not a direct hybrid-cache
transaction, namespace, checkpoint-admission, or target/draft pair-state change.
The INTEGRATE decision is acceptable if Developer performs the focused scan
part 11 names: hybrid mode remains opt-in, hybrid cache policy remains owned by
`hybrid_cache_controller`, checkpoint evidence stays intact, and route/session
evidence still passes.

## Consistency review

Part 11 is consistent with the Stage 35 design and upstream merge guide: the
source ref was refreshed by Manager decision, the refreshed report reopens
analysis for the changed range, and merge execution remains blocked.

Design rework parts 04-06 and Manager gate part 08 still describe the original
9 rework rows at tip `108f186d1701`. Part 11 correctly treats the new DSV4 KV
row as a Manager decision before merge execution. If Manager accepts this
review, the next gate should record that the MTP/KV/speculative track now has
five rows, including `024c46ae4e37`.

Implementation plan part 06 is now historical for the old `67 INTEGRATE` and
`9 REWORK-REQUIRED` counts. It remains valid as a process plan, but the next
Manager approval or Developer preflight must use the refreshed `68 INTEGRATE`
and `10 REWORK-REQUIRED` counts from part 11 and this review.

The implementation entry and index now link this review and keep merge
execution blocked pending Manager approval and a later clean-tree gate.

## Findings

Blocking findings: 0.

Non-blocking findings: 0.

Informational findings: 0.

## Decision

Refreshed pre-merge analysis review gate: PASS.

Accepted refreshed counts: 312 total commits, 91 filtered rows, 13 NO-OP,
68 INTEGRATE, 10 REWORK-REQUIRED, 0 DEFER, 0 REVERT.

Next owner: Manager.

Next gate: Manager refreshed pre-merge approval.

Required Manager decisions:

- Accept or reject the refreshed aggregate counts.
- Add `024c46ae4e37` to the MTP/KV/speculative rework scope, or open a separate
  DeepSeek V4 KV rework if Manager wants separate routing.
- Keep `6c487e2f79de` as INTEGRATE with focused prompt-cache/hybrid opt-in
  scans, or escalate it to route/session rework.
- Confirm the planning-only dirty exception still applies until the next
  clean-tree gate.

Merge execution, conflict resolution, regression runs, commits, pushes, PRs,
and reviewer responses remain blocked.
