# Stage 35 focused build retry 2026-07-08

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Status

Verdict: BLOCKED.

Owner: Developer

No merge commit was created. No push, PR, or reviewer response was made.

## Source and worktree checks

| Check | Command | Output |
| --- | --- | --- |
| Open merge | `git rev-parse --verify MERGE_HEAD` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Local source ref | `git rev-parse origin/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Remote source branch | `git ls-remote origin refs/heads/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe refs/heads/upstream_master` |
| Unresolved paths | `git diff --name-only --diff-filter=U` | `<none>` |

Source/worktree verdict: PASS. The open no-commit merge, local source ref, and
remote `upstream_master` branch all matched. No unresolved paths existed.

## Focused build retry

Build tree: `build-cuda`

| Attempt | Command | Duration | Result |
| --- | --- | --- | --- |
| Combined focused build | `cmake --build build-cuda --config Release --target llama-server test-cache-controller -j 8` | 557.9 seconds | FAIL: exit `1`; no timeout. |
| Fallback focused build | `cmake --build build-cuda --config Release --target test-cache-controller -j 4` | 2.0 seconds | FAIL: exit `1`; no timeout. |

Combined build output ended with:

```text
ggml-cuda.dir\Release\argsort.obj : fatal error LNK1136: invalid or corrupt file [D:\source\llama.cpp-jet\build-cuda\ggml\src\ggml-cuda\ggml-cuda.vcxproj]
```

Fallback build output ended with the same error:

```text
ggml-cuda.dir\Release\argsort.obj : fatal error LNK1136: invalid or corrupt file [D:\source\llama.cpp-jet\build-cuda\ggml\src\ggml-cuda\ggml-cuda.vcxproj]
```

No focused test command was run because `test-cache-controller` did not build.

## Process cleanup

| Point | Process check | Result |
| --- | --- | --- |
| After combined build failure | `Get-Process` for `cmake`, `MSBuild`, `cl`, `link`, `ninja`, `devenv` | Found leftover `MSBuild` processes: `4032`, `13504`, `21616`, `24412`, `32484`, `36044`, `37060`. |
| Combined cleanup | `Stop-Process -Force` on leftover build processes, then recheck | PASS: no listed build processes remained. |
| After fallback build failure | same process query | Found leftover `MSBuild` processes: `17992`, `34136`, `37380`. |
| Fallback cleanup | `Stop-Process -Force` on leftover build processes, then recheck | PASS: no listed build processes remained. |

No timeout occurred in either attempt.

## Source-ref recheck after build retry

| Check | Command | Output |
| --- | --- | --- |
| Open merge | `git rev-parse --verify MERGE_HEAD` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Local source ref | `git rev-parse origin/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Remote source branch | `git ls-remote origin refs/heads/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe refs/heads/upstream_master` |
| Unresolved paths | `git diff --name-only --diff-filter=U` | `<none>` |

Recheck verdict: PASS. Source freshness and merge state stayed valid.

## Blocker

The existing `build-cuda` tree contains a corrupt CUDA object:
`build-cuda\ggml\src\ggml-cuda\ggml-cuda.dir\Release\argsort.obj`. Both
requested build attempts stopped at MSVC link error `LNK1136`.

## Handoff

Next owner: Manager / Architect.

Next gate: review-routing decision for the open no-commit merge. A clean or
object-pruned build retry may be needed before implementation review can close.
