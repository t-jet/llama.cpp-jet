# Stage 35 merge/rework implementation blocked

Date: 2026-07-07
Owner: Developer
Branch: `work-branch`
Mode: no-commit merge preparation
Verdict: BLOCKED

## Scope

This part records the partial Stage 35 merge/rework implementation after
refreshed pre-merge approval. A real two-parent merge was opened with
`--no-ff --no-commit`, textual conflicts were resolved, and semantic scans were
run. The implementation gate stopped before regression closure because the
source ref became stale during the session.

No commit, push, PR, or reviewer response was created.

## Preflight

Preflight passed before opening the merge:

- `git status --short`: clean.
- `git rev-parse HEAD`: `429a4fbce248d6d586669e022f63c1e27cb64f29`.
- `git log -1 HEAD`: `docs: refresh Stage 35 premerge gate`.
- `git rev-parse origin/upstream_master`: `6c487e2f79dea747d70325250121e750ed364b2b`.
- `git log -1 origin/upstream_master`: `server: enforce prompt cache RAM limit (#25070)`.
- `git merge-base HEAD origin/upstream_master`: `18ef86ecec723361362a332a79b4d913fd724d40`.
- `git rev-list --count HEAD..origin/upstream_master`: `312`.
- `git ls-remote https://github.com/ggml-org/llama.cpp.git refs/heads/master`:
  `6c487e2f79dea747d70325250121e750ed364b2b`.

## Merge command

Command run:

```text
git merge --no-ff --no-commit origin/upstream_master
```

The command opened a merge state with
`MERGE_HEAD=6c487e2f79dea747d70325250121e750ed364b2b`.

Textual conflicts were reported in six files:

- `common/common.cpp`
- `common/fit.h`
- `tools/server/CMakeLists.txt`
- `tools/server/server-common.h`
- `tools/server/server-context.cpp`
- `tools/server/server-task.cpp`

## Conflict resolutions

Manual conflict resolutions applied:

- `common/common.cpp`: kept the Stage 34 MTP no-draft fit headroom block and
  merged the upstream fit-parameter shape.
- `common/fit.h`: kept upstream device-memory data types and retained the local
  `common_get_mtp_ctx_memory_overhead` declaration.
- `tools/server/CMakeLists.txt`: kept local cache sources and added upstream
  `server-schema` sources; upstream `server-stream` sources remained present.
- `tools/server/server-common.h`: kept `cache_token_ids()` and upstream
  `find_next_media_chunk()`.
- `tools/server/server-task.cpp`: combined the local prompt-cache allocation
  guard with upstream RAM-limit eviction for `--cache-ram`.
- `tools/server/server-context.h`: restored deprecated
  `json_webui_settings` beside upstream `json_ui_settings` for local route
  compatibility.
- `tools/server/server-context.cpp`: merged upstream server state, schema, and
  stream APIs with local hybrid-cache route, checkpoint, session, and metadata
  contracts.

## Rework track analysis

MTP/KV/speculative rows reviewed:

- `88a39274ecf8`: EAGLE3 model-backed speculative support remains a runtime
  draft-context concern. The hybrid cache pair-state stays binary by target
  plus draft payload presence.
- `d789527482d9`: Step 3.5 and Step 3.7 MTP support does not require a third
  pair state. Compatibility remains keyed through existing model/runtime
  discriminators.
- `d1b34251bc57`: DFlash speculative changes are model/runtime shape changes,
  not cache ownership changes.
- `8c146a836630`: DeepSeek V4 KV and ISWA behavior remains covered by
  descriptor metadata validation and compatibility checks.
- `024c46ae4e37`: DeepSeek V4 quantized-KV compatibility joins this track.
  It is treated as KV-layout compatibility input, not a separate cache mode.

Route/session lifecycle rows reviewed:

- `4b4d13ae721e`
- `2b686a9120e2`
- `721354fbdfb7`
- `1a87dcdc452d`

The upstream model-management, download, SSE, server-state, and stream-resume
surfaces were treated as transport and lifecycle changes. Cache mode remains
CLI-selected. Conversation and stream-session ids were not added to prepared
prompt metadata or hybrid cache namespace identity.

Checkpoint placement row reviewed:

- `73618f27a801`: upstream `message_spans` were integrated into checkpoint
  placement by assigning `task.params.message_spans` and using
  `common_chat_msg_spans` user-message helpers. Local Stage 9 prompt-span
  metadata remains in `cache_metadata_from_chat_messages`.

Focused INTEGRATE scan:

- `6c487e2f79de`: upstream strict prompt-cache RAM enforcement was merged into
  `server_prompt_cache::alloc`. Local hybrid cache logic remains opt-in and
  independent.

## Semantic scan evidence

Scans completed after conflict resolution:

- Scoped conflict-marker scan on the six conflicted files: clean.
- Stale local/upstream symbol scan for `params_from_json_cmpl`,
  `n_before_user`, `on_sleeping_changed`, and `SERVER_STATE_LOADING_MODEL`:
  clean.
- Public metric label scan for `namespace="all"` under `tools/server`,
  `common`, `src`, and `tests`: clean.
- Anchor scan confirmed `tx_save`, `tx_restore`, `tx_apply_restore`,
  `cache_state_mutex_`, `llama_state_seq_get_data_ext`, `target_and_draft`,
  `target_only`, `message_spans`, stream APIs, and
  `server_prompt_cache::alloc/update`.

`git diff --diff-filter=U --name-only` returned no unmerged paths after
manual resolution and staging.

## Build and test evidence

Focused build attempts were feasible but did not complete in the available
window:

- `cmake --build build-cuda --config Release --target server-context`
  timed out at 120 seconds with no useful compiler output.
- `cmake --build build-cuda --config Release --target server-context -- /m:4`
  timed out at 300 seconds with no useful compiler output.
- `cmake --build build-cuda --config Release --target test-cache-controller -- /m:1 /v:minimal`
  timed out at 300 seconds with no useful compiler output.

After each timeout, remaining child build processes were stopped. A later
process check found no `cmake`, `MSBuild`, `cl`, `link`, or `ninja` processes.

## Stop condition

The source ref became stale after the merge was opened:

- `HEAD`: `429a4fbce248d6d586669e022f63c1e27cb64f29`.
- `MERGE_HEAD`: `6c487e2f79dea747d70325250121e750ed364b2b`.
- `origin/upstream_master`: `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`.
- Actual upstream `master`:
  `f5525f7e7a7e7cbecd386144299493ea40499bd3`.

Per the approved stop conditions, implementation evidence stopped here. The
merge state remains open and unresolved only in the sense that it is not
committed; there are no textual conflict paths left.

## Current state

Current working tree state is a no-commit merge preparation with upstream
changes staged, manual conflict resolutions staged, and this evidence file
added. The implementation gate is blocked on a Manager source-ref decision.

Next gate options:

- Refresh and redo from the actual upstream `master` tip.
- Approve a pinned known-gap path for the opened `MERGE_HEAD`.
- Decide whether to keep or abort the current partial merge state before the
  next Developer implementation session.
