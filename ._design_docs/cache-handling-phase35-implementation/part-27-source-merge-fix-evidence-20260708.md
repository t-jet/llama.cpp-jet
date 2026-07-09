# Stage 35 source merge fix evidence 2026-07-08

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Status

Verdict: PASS for source-level merge compile fixes and focused cache/router
checks.

Owner: Developer

No merge commit was created. No push, PR, or reviewer response was made.

## Scope

This pass fixed the real source-level merge errors exposed in
[part 25](part-25-clean-build-retry-20260708.md). The open no-commit merge
remained against `MERGE_HEAD=47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`.

Changed production source:

- `tools/server/server-context.cpp`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-common.cpp`
- `tools/server/server-common.h`

## Fix summary

| Area | Resolution |
| --- | --- |
| Duplicate `server_state` enum | Removed the stale local enum from `server-context.cpp`; kept the upstream enum in `server-context.h`. |
| State callback merge split | Restored `server_context_impl::callback_state`, `set_state_callback`, loading notifications, sleeping notification, and ready notification so router-child state updates still compile and run. |
| Device memory fields | Updated `common_device_memory_data` users from old `dmd[j].mb.*` members to current flat fields `model`, `context`, and `compute`. |
| Model naming | Replaced removed `common_params_model::name` use with `get_name()` in server model-name fallback and hybrid draft-source namespace construction. |
| UI params | Replaced removed `webui_*` params with current `ui`, `ui_config_json`, and `ui_mcp_proxy` fields while keeping deprecated response keys mapped to the new values. |
| Completion schema | Switched completion task parsing to `server_schema::eval_llama_cmpl_schema` and included `server-schema.h`. |
| Checkpoint user boundary | Rebased Stage 34 checkpoint gating from removed `task_params::n_before_user` onto upstream `task_params::message_spans.last_user_message_pos()`. |
| MTMD media chunks | Restored the real `server_tokens::process_chunk` declaration and definition from the local lineage, needed by the merged prompt loop. |
| Token probabilities | Updated `get_token_probabilities` call to the current three-argument signature. |

Hybrid cache behavior is preserved: Stage 25 transaction entry points remain in
use, Stage 34 idempotent save and Path B tests still pass, and the hybrid draft
namespace still includes model source identity through `common_params_model`.

## Build evidence

Command:

```text
cmake --build build-cuda --config Release --target llama-server test-cache-controller -j 8
```

Result: PASS.

Evidence:

- `build-cuda/stage35-sourcefix-build3-stdout.log`
- `build-cuda/stage35-sourcefix-build3-exit.txt` (`BUILD_EXIT=0`)

Notes:

- `llama-server.exe` built successfully.
- `test-cache-controller.exe` built successfully.
- Warnings were limited to pre-existing MSVC warnings:
  `RtlCaptureStackBackTrace` linkage in `server.cpp` and `%zu` format warnings
  in `tests/test-cache-controller.cpp`.

## Focused test evidence

| Check | Command | Result |
| --- | --- | --- |
| Direct cache controller | `build-cuda\bin\Release\test-cache-controller.exe` | PASS: 149 tests passed. |
| Cache ctest | `ctest -C Release -R cache --output-on-failure` from `build-cuda` | PASS: 1/1 tests passed. |
| Router props smoke | `LLAMA_SERVER_BIN_PATH=<abs llama-server.exe> LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1 pytest -q tools/server/tests/unit/test_router.py::test_router_props` | PASS: 1 passed. |

Evidence:

- `build-cuda/stage35-sourcefix-test-cache-controller.log`
- `build-cuda/stage35-sourcefix-test-cache-controller-exit.txt`
- `build-cuda/stage35-sourcefix-ctest-cache.log`
- `build-cuda/stage35-sourcefix-ctest-cache-exit.txt`
- `build-cuda/stage35-sourcefix-pytest-router-props.log`
- `build-cuda/stage35-sourcefix-pytest-router-props-exit.txt`

The pytest run emitted environment warnings from `requests` dependency versions
and `pytest_asyncio` loop-scope defaults. The test itself passed.

## Post-checks

| Check | Output |
| --- | --- |
| `git rev-parse --verify MERGE_HEAD` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| `git rev-parse origin/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| `git ls-remote origin refs/heads/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe refs/heads/upstream_master` |
| Unresolved paths | none |
| Conflict-marker scan | no merge markers in touched server files; only separator comments matched `====` in `server-cache-hybrid.cpp`. |
| Build workers | leftover MSBuild workers were stopped; recheck found none. |

## Handoff

The Part 25 source compile blocker is resolved. The merge is still open and
uncommitted. Next gate is Architect implementation review or Manager direction
on broader Stage 35 regression scope. Commits, pushes, PRs, and reviewer
responses remain blocked unless explicitly requested.
