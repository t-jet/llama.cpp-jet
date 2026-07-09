# Stage 35 clean object-pruned build retry 2026-07-08

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Status

Verdict: BLOCKED.

Owner: Developer

No merge commit was created. No production source was edited as part of the
merge resolution. No push, PR, or reviewer response was made.

## Pre-checks

| Check | Command | Output |
| --- | --- | --- |
| Branch | `git branch --show-current` | `work-branch` |
| Open merge | `git rev-parse --verify MERGE_HEAD` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Local source ref | `git rev-parse origin/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Unresolved paths | `git diff --name-only --diff-filter=U` | `<none>` |
| Staged file count | `git diff --cached --name-only \| Measure-Object -Line` | `734` |

Pre-check verdict: PASS. Branch is `work-branch`; `MERGE_HEAD`, local
`origin/upstream_master` match; no unresolved conflicts; 734 staged files.

## Object prune

The Part 24 blocker was a corrupt CUDA object:
`build-cuda\ggml\src\ggml-cuda\ggml-cuda.dir\Release\argsort.obj`
(`LNK1136: invalid or corrupt file`). Per "prefer clean builds" the whole
`ggml-cuda.dir` directory was pruned so all CUDA objects recompile.

| Action | Command | Result |
| --- | --- | --- |
| Confirm corrupt object | `Test-Path ...\ggml-cuda.dir\Release\argsort.obj` | `True` |
| Confirm dir exists | `Test-Path ...\ggml-cuda.dir` | `True` |
| Object count before | `(Get-ChildItem ...\Release\*.obj).Count` | `139` |
| Prune directory | `Remove-Item -Recurse -Force ...\ggml-cuda.dir` | `PRUNE_EXIT=True` |
| Confirm dir gone | `Test-Path ...\ggml-cuda.dir` | `False` |

The CMake project structure was left intact (only the `.obj` directory was
deleted, not `CMakeFiles`): `ggml-cuda.vcxproj`, `llama-server.vcxproj`, and
`CMakeCache.txt` all still existed, so no reconfigure was needed.

Pre-build process check (`Get-Process cmake,MSBuild,cl,link,ninja,devenv,
cudafe`): no leftover build processes.

## Focused build

Build tree: `build-cuda`. Command:

```text
cmake --build build-cuda --config Release --target llama-server test-cache-controller -j 8 *>&1 | Tee-Object -FilePath build-cuda\stage35-part25-build-stdout.log
```

The combined command was used per the shared-objects guidance (no parallel
MSBuild targets racing on shared objects). A single command was sufficient.

| Attempt | Duration | Exit | Result |
| --- | --- | --- | --- |
| Combined clean build | `00:22:10.5931650` (1330.6 s) | `1` | FAIL: compile errors in `server-context.cpp` and `server-cache-hybrid.cpp` |

CUDA verdict: PASS. The CUDA objects recompiled cleanly; the fresh
`argsort.obj` now exists and `ggml-cuda.dll` was relinked today (LastWriteTime
`2026-07-08 01:53:30`). The Part 24 `LNK1136` corrupt-object blocker is
resolved: the corruption was stale build state, not a source conflict.

Server verdict: FAIL. The build progressed past the CUDA link but stopped at
27 compile errors in the server target. The `test-cache-controller` target was
not reached (the combined build aborted at the `server-context.cpp` compile).

Final build log tail:

```text
  llama.vcxproj -> D:\source\llama.cpp-jet\build-cuda\bin\Release\llama.dll
  llama-common.vcxproj -> D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-common.dll
... server-context.cpp errors (see Blocker) ...
```

## Compile errors (root cause)

First error (the cascade trigger):

```text
D:\source\llama.cpp-jet\tools\server\server-context.cpp(334,6): error C2011:
  'server_state': 'enum' type redefinition
```

Root cause (read-only investigation, no edits made): the `server_state` enum is
defined twice after the merge resolution:

- `tools/server/server-context.h:62` - upstream version:
  `SERVER_STATE_DOWNLOADING, SERVER_STATE_LOADING, SERVER_STATE_READY,
  SERVER_STATE_SLEEPING`
- `tools/server/server-context.cpp:334` - local lineage version:
  `SERVER_STATE_LOADING_MODEL, SERVER_STATE_READY`

These are distinct enums from the two merge parents; the conflict resolution
kept both definitions instead of picking one. The C2011 then cascades into the
"not a member" / "must be initialized" errors that depend on the enum and the
referenced structs.

Full error distribution (27 `error C` lines, 24 distinct file:line sites):

- `server-context.cpp` - 26 errors across 23 distinct lines:
  `334`, `661`, `662`, `663`, `664`, `1029`, `1030`, `1129`, `1131`, `1686`,
  `3086`, `3099`, `3116` (x2), `3711`, `3773`, `3774`, `4114` (x2), `4123`,
  `5003` (x2), `5004` (x2), `5011` (x2)
- `server-cache-hybrid.cpp` - 1 error: `4270`
  (`'name': is not a member of 'common_params_model'`)

Representative downstream errors (struct field mismatches from the merge):

```text
server-cache-hybrid.cpp(4270,29): error C2039: 'name': is not a member of 'common_params_model'
server-context.cpp(662,59):       error C2039: 'mb':   is not a member of 'common_device_memory_data'
server-context.cpp(1131,31):      error C2039: 'webui_config_json': is not a member of 'common_params'
server-context.cpp(4114,40):      error C3861: 'params_from_json_cmpl': identifier not found
server-context.cpp(4123,29):      error C2039: 'n_before_user': is not a member of 'task_params'
server-context.cpp(5003,54):      error C2039: 'webui': is not a member of 'common_params'
server-context.cpp(5004,53):      error C2039: 'json_webui_settings': is not a member of 'server_context_meta'
server-context.cpp(5011,76):      error C2039: 'webui_mcp_proxy': is not a member of 'common_params'
```

Classification: source-level merge integration defects in
`tools/server/server-context.cpp` and `tools/server/server-cache-hybrid.cpp`.
The local-lineage bodies reference fields/enums that upstream renamed or
removed, and a duplicate enum definition survived the conflict resolution.
These are NOT build-object corruption. Per Stage 35 contract the Developer must
not edit production source as part of the merge resolution, so no fixes were
applied.

## Focused test

Not run. The build aborted at the `server-context.cpp` compile, so the
`test-cache-controller` target was never built in this run. The pre-existing
`build-cuda\bin\Release\test-cache-controller.exe` is STALE: binary timestamp
`2026-07-07 03:33:48`, source `tests/test-cache-controller.cpp` timestamp
`2026-07-07 12:50:38`. Running it would produce evidence from old code, so it
was not executed.

## Process cleanup

| Point | Process check | Result |
| --- | --- | --- |
| After build failure | `Get-Process cmake,MSBuild,cl,link,ninja,devenv,cudafe,c1xx` | Found leftover `MSBuild` PIDs: `9948`, `24648`, `26112`, `30676`, `32032`, `33068`, `36904`. |
| Cleanup | `Get-Process MSBuild,cmake,cl,link,ninja,c1xx \| Stop-Process -Force` | PASS: no listed build processes remained after recheck. |

## Post-checks / source-ref recheck

| Check | Command | Output |
| --- | --- | --- |
| Open merge | `git rev-parse --verify MERGE_HEAD` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Local source ref | `git rev-parse origin/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Remote source branch | `git ls-remote origin refs/heads/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe refs/heads/upstream_master` |
| Unresolved paths | `git diff --name-only --diff-filter=U` | `<none>` |

Recheck verdict: PASS. Source freshness and merge state stayed valid; the open
no-commit merge is unchanged; no new conflicts; leftover build processes gone.

## Result

Build result: FAIL. The clean object-pruned build resolved the Part 24 `LNK1136`
corrupt-object blocker (CUDA objects recompiled cleanly) but exposed real
source-level merge integration compile errors. 27 `error C` lines across 24
distinct file:line sites in `server-context.cpp` and `server-cache-hybrid.cpp`.

Verdict: BLOCKED. (Bar: PASS = clean build + focused test PASS; BLOCKED = build
still fails.) The blocker changed from corrupt build object to real source
merge defects.

Evidence files (in `build-cuda/`, untracked build artifacts, NOT source):

- `stage35-part25-build-stdout.log` - full build output (1,166,882 bytes)
- `stage35-part25-build-exit.txt` - `BUILD_EXIT=1`
- `stage35-part25-build-dur.txt` - `DURATION=00:22:10.5931650`

## Handoff

Next owner: Manager / Architect.

Next gate: review-routing decision. The CUDA-object blocker is closed; the open
question is now a real merge-resolution defect set (duplicate `server_state`
enum in `server-context.cpp` vs `server-context.h`, plus struct field
mismatches against renamed/removed upstream fields). Manager must decide
whether to authorize a Developer merge-resolution source-fix session for the
27 compile errors, or route the no-commit merge to Architect review with the
compile errors as a known blocker. Commit, push, PR, and reviewer response
remain blocked unless separately requested.
