# Stage 35 merge/rework implementation evidence upstream_master 2026-07-08

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Status

Verdict: PARTIAL / BLOCKED.

Owner: Developer

No merge commit was created. No push, PR, or reviewer response was made.

## Preflight

| Check | Command | Output |
| --- | --- | --- |
| Worktree before merge | `git status --short` | `<clean>` |
| Local tip | `git log -1 --format="%H %ai %s" HEAD` | `ecd9e0fd97366b9901eebc36f1920375256541df 2026-07-08 00:40:15 +0300 docs: correct Stage 35 upstream source` |
| `MERGE_HEAD` | filesystem check | absent |
| Source ref | `git rev-parse origin/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Remote source branch | `git ls-remote origin refs/heads/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe refs/heads/upstream_master` |
| Source detail | `git log -1 --format="%H %ai %s" origin/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe 2026-07-07 16:07:46 +0800 [SYCL] support op col2im_1d (#25264)` |
| Merge base | `git merge-base HEAD origin/upstream_master` | `18ef86ecec723361362a332a79b4d913fd724d40` |
| Range count | `git rev-list --count "HEAD..origin/upstream_master"` | `307` |
| Remote config | `git remote -v` | `origin https://github.com/t-jet/llama.cpp-jet.git` fetch/push |

Preflight verdict: PASS. The local source ref matched the remote
`upstream_master` branch at the user-corrected source SHA.

## Merge command

Command:

```text
git merge --no-ff --no-commit origin/upstream_master
```

Result: exit `1` with textual conflicts. `MERGE_HEAD` became
`47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`.

## Conflicts resolved

| File | Resolution | Contract preserved |
| --- | --- | --- |
| `common/common.cpp` | Kept local MTP no-draft fit-margin overhead logic; did not take the upstream trace-only replacement. | Stage 5/34 MTP context headroom and draft-context pairing. |
| `common/fit.h` | Started from the local MTP header and added upstream `common_device_memory_data` / `common_device_memory_data_vec` API expected by merged `fit.cpp`. | Local MTP fit support plus upstream memory-data API. |
| `tools/server/CMakeLists.txt` | Kept local cache sources and added upstream `server-schema.*`; upstream `server-stream.*` was already present above the conflict. | Stage 25 cache-controller build plus upstream route/schema additions. |
| `tools/server/server-common.h` | Kept local `cache_token_ids()` and added upstream `find_next_media_chunk()`. | Stage 31/34 cache identity and upstream MTMD media traversal. |
| `tools/server/server-context.cpp` | Took the local whole-file side because the conflict covered the full file and local cache contracts live there; upstream route/session files remain integrated elsewhere. | Stage 25 transactions, Stage 9 checkpoint placement, Stage 31/32 metrics, Stage 34 replay and slow-read rules. |

## Semantic scans

| Scan | Command | Result |
| --- | --- | --- |
| Conflict markers | `rg -n "^(<<<<<<<\|=======\|>>>>>>>)" common tools/server src tests include` | PASS: no matches. |
| Public metric `namespace="all"` | `rg -n 'namespace="all"' tools/server common src tests include` | PASS: no matches. |
| Cache transactions | `rg -n "tx_restore\|tx_apply_restore\|tx_save\|tx_load\|cache_state_mutex_\|try_restore_from_cache\|restore-apply" tools/server src common tests` | PASS: Stage 25/34 anchors present in cache code and tests. |
| Target/draft and speculative anchors | `rg -n "target_and_draft\|target_only\|pair_state\|DRAFT_MTP\|draft\|MTP\|mtp\|common_speculative_init\|init_speculative\|speculative_init" common tools/server src tests include` | PASS: pair-state, MTP, draft, and speculative helper anchors present. |
| Message spans and checkpoints | `rg -n "prompt_span\|message.*span\|checkpoint\|PreparedPromptMetadata\|prepared_prompt_metadata\|MESSAGE_END\|create_checkpoint\|checkpoint_update" common tools/server src tests include` | PASS: prompt-span, checkpoint, metadata, and validation anchors present. |
| Route/session/stream anchors | `rg -n "server_stream\|stream resume\|resume\|replay\|session\|branch\|models\|model management\|progress\|load_progress\|post_responses\|SERVER_TASK_TYPE\|find_next_media_chunk\|cache_token_ids" tools/server common src tests include` | PASS: upstream stream/model/progress anchors and local cache identity anchors present. |

## Build and test evidence

| Attempt | Command | Result |
| --- | --- | --- |
| Focused server/cache build | `cmake --build build-cuda --config Release --target llama-server test-cache-controller -j 8` | BLOCKED: timed out after 608 seconds. |
| Cleanup check 1 | `Get-Process` for `cmake`, `MSBuild`, `cl`, `link`, `ninja`, `devenv` | Found leftover `cmake`, `MSBuild`, and `cl` processes. |
| Cleanup action | `Stop-Process -Force` on leftover build processes | Completed. |
| Cleanup check 2 | same process query after stop | PASS: no `cmake`, `MSBuild`, `cl`, `link`, `ninja`, or `devenv` remained. |

No focused tests were run because the focused build target did not finish.

## Source-ref recheck

| Check | Command | Output |
| --- | --- | --- |
| Source ref after work | `git rev-parse origin/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Remote source branch after work | `git ls-remote origin refs/heads/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe refs/heads/upstream_master` |
| Open merge | `git rev-parse --verify MERGE_HEAD` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |

Source-ref recheck verdict: PASS. The open no-commit merge and remote source
branch both name the corrected `upstream_master` SHA.

## Changed files in this part

Conflict resolutions touched:

- `common/common.cpp`
- `common/fit.h`
- `tools/server/CMakeLists.txt`
- `tools/server/server-common.h`
- `tools/server/server-context.cpp`

Durable evidence updates touched:

- `._design_docs/cache-handling-phase35-implementation/part-22-merge-rework-implementation-evidence-upstream-master-20260708.md`
- `._design_docs/cache-handling-phase35-implementation.md`
- `._design_docs/document-index.md`

## Blockers

Focused build evidence is incomplete because the build timed out. The worktree
contains an open no-commit merge with staged conflict resolutions. Source
freshness is not blocked.

## Handoff

Next owner: Manager / Architect.

Next gate: decide whether to accept the partial implementation evidence for
review or authorize a longer focused build/test retry on the open no-commit
merge.
