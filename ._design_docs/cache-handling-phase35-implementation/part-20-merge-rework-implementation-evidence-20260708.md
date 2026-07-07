# Stage 35 merge/rework implementation evidence 2026-07-08

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Status

Verdict: PARTIAL / BLOCKED.

Owner: Developer

No merge commit was created. No push, PR, or reviewer response was made.

## Preflight

| Check | Command | Output |
| --- | --- | --- |
| Worktree before merge | `git status --short` | `<clean>` |
| Local tip | `git log -1 --format="%H %ai %s" HEAD` | `a5945e6c2b05354a38687e20a18794f45b26669b 2026-07-08 00:13:35 +0300 docs: pass Stage 35 clean-tree gate` |
| `MERGE_HEAD` | `git rev-parse --verify MERGE_HEAD` | exit `128`, `fatal: Needed a single revision` |
| Source ref | `git rev-parse origin/upstream_master` | `bec4772f6a2527d371557b5d2032641e5ff7619c` |
| Source detail | `git log -1 --format="%H %ai %s" origin/upstream_master` | `bec4772f6a2527d371557b5d2032641e5ff7619c 2026-07-07 12:05:47 -0700 Add Q2_0 quantization: type definition and CPU backend (#24448)` |
| Merge base | `git merge-base HEAD origin/upstream_master` | `18ef86ecec723361362a332a79b4d913fd724d40` |
| Range count | `git rev-list --count "HEAD..origin/upstream_master"` | `317` |
| Actual upstream | `git ls-remote https://github.com/ggml-org/llama.cpp.git refs/heads/master` | `bec4772f6a2527d371557b5d2032641e5ff7619c refs/heads/master` |

Preflight verdict: PASS. Source ref matched actual upstream and the approved
317-commit range before the merge command.

## Merge command

Command:

```text
git merge --no-ff --no-commit origin/upstream_master
```

Result: exit `1` with textual conflicts. `MERGE_HEAD` became
`bec4772f6a2527d371557b5d2032641e5ff7619c`.

## Conflicts resolved

| File | Resolution | Contract preserved |
| --- | --- | --- |
| `common/common.cpp` | Kept local MTP no-draft fit-margin overhead logic; dropped upstream trace-only replacement. | Stage 5/34 MTP context headroom and draft-context pairing. |
| `common/fit.h` | Combined upstream `common_device_memory_data` public API with local `common_get_mtp_ctx_memory_overhead`. | MTP fit support and upstream memory data API. |
| `tools/server/CMakeLists.txt` | Kept local cache sources and added upstream `server-schema.*`; upstream `server-stream.*` was already present before the conflict hunk. | Stage 25 cache controller build plus route/session additions. |
| `tools/server/server-common.h` | Kept local `cache_token_ids()` and upstream `find_next_media_chunk()`. | Stage 31/34 cache identity and upstream MTMD media traversal. |
| `tools/server/server-context.cpp` | Chose local whole-file side because the conflict covered the whole file. Upstream route/session files remain integrated elsewhere. | Stage 25 transactions, Stage 9 checkpoint placement, Stage 31/32 metrics, Stage 34 replay and slow-read rules. |
| `tools/server/server-task.cpp` | Combined local over-limit skip with upstream pre-allocation eviction; removed redundant empty checks inside non-empty loops. | Legacy prompt cache stability and upstream allocation guard. |

## Required semantic scans

| Scan | Command | Result |
| --- | --- | --- |
| Conflict markers | `rg -n "^(<<<<<<<|=======|>>>>>>>)" common tools/server src tests include` | PASS: no matches. |
| Public metric `namespace="all"` | `rg -n 'namespace="all"' tools/server common src tests include` | PASS: no matches. |
| Cache transaction anchors | `rg -n "tx_restore|tx_apply_restore|tx_save|tx_load|cache_state_mutex_|try_restore_from_cache|restore-apply" tools/server src common tests` | PASS: Stage 25/34 anchors remain in cache code and tests. |
| Target/draft pairing and speculative helpers | `rg -n "target_and_draft|target_only|pair_state|DRAFT_MTP|draft|MTP|mtp|init_speculative|speculative_init|common_speculative" ...` | PASS: `common_speculative_init_from_params`, `common_speculative_init`, MTP, and pair-state anchors present. |
| Message spans and checkpoints | `rg -n "prompt_span|message.*span|checkpoint|PreparedPromptMetadata|prepared_prompt_metadata|MESSAGE_END|create_checkpoint|checkpoint_update" ...` | PASS: chat metadata, prompt spans, checkpoint admission, and validation anchors present. |
| Route/session/stream anchors | `rg -n "server_stream|stream resume|resume|replay|session|branch|models|model management|progress|load_progress|post_responses|SERVER_TASK_TYPE|find_next_media_chunk|cache_token_ids" ...` | PASS: upstream stream/model/progress anchors and local cache identity anchors present. |

## Build and test evidence

| Attempt | Command | Result |
| --- | --- | --- |
| Focused server/cache build | `cmake --build build-cuda --config Release --target llama-server test-cache-controller -j 8` | BLOCKED: timed out after 604 seconds. |
| Focused cache test build | `cmake --build build-cuda --config Release --target test-cache-controller -j 4` | BLOCKED: timed out after 304 seconds. |
| Cleanup check 1 | `Get-Process` for `cmake`, `MSBuild`, `cl`, `link`, `ninja`, `devenv` | Found leftover `cmake`, `MSBuild`, and `cl`; stopped them. |
| Cleanup check 2 | same process query after second stop | PASS: no `cmake`, `MSBuild`, `cl`, `link`, `ninja`, or `devenv` remained. |

No focused tests were run because the focused build target did not finish.

## Source-ref blocker

After conflict resolution, semantic scans, and timed-out build attempts, the
freshness check no longer matched the preflight:

| Check | Command | Output |
| --- | --- | --- |
| Source ref after work | `git rev-parse origin/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Actual upstream after work | `git ls-remote https://github.com/ggml-org/llama.cpp.git refs/heads/master` | `bec4772f6a2527d371557b5d2032641e5ff7619c refs/heads/master` |
| Range count after work | `git rev-list --count "HEAD..origin/upstream_master"` | `307` |
| Open merge | `git rev-parse --verify MERGE_HEAD` | `bec4772f6a2527d371557b5d2032641e5ff7619c` |

Blocker: an open no-commit merge exists against `MERGE_HEAD=bec4772f6a25`, but
`origin/upstream_master` now resolves to stale `47e1de77aa0f`. Per the Stage 35
source-ref rule, implementation-gate closure cannot proceed on this state.

## Changed files in this part

Conflict resolutions touched:

- `common/common.cpp`
- `common/fit.h`
- `tools/server/CMakeLists.txt`
- `tools/server/server-common.h`
- `tools/server/server-context.cpp`
- `tools/server/server-task.cpp`

Durable evidence updates touched:

- `._design_docs/cache-handling-phase35-implementation/part-20-merge-rework-implementation-evidence-20260708.md`
- `._design_docs/cache-handling-phase35-implementation.md`
- `._design_docs/document-index.md`

## Handoff

Next owner: Manager.

Next gate: source-ref and open no-commit merge decision.

Recommended decision point: either authorize abort-and-refresh-redo again, or
record a pinned-source exception for the current open merge. Until then, no
more build/test evidence, merge commit, push, PR, or reviewer response should
occur.
