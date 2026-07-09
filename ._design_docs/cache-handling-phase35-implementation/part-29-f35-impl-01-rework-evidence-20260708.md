# Stage 35 F35-IMPL-01 rework evidence 2026-07-08

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Status

Verdict: PASS for Developer source-fix rework.

Owner: Developer

No merge commit was created. No push, PR, or reviewer response was made.

## Scope

This pass fixes F35-IMPL-01 from
[part 28](part-28-implementation-review-20260708.md). The open no-commit merge
remained against `MERGE_HEAD=47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`.

Changed files:

- `tools/server/server-context.cpp`
- `tools/server/server-context.h`
- `tools/server/server-queue.h`
- `tests/test-cache-controller.cpp`

## Fix summary

`server_context::set_state_callback` now only stores the router state callback.
The sleep-state transition stays in the existing queue sleep handler installed
by `server_context_impl::init()`.

That handler calls `handle_sleeping_state(sleeping)` first. On sleep entry, it
then emits `SERVER_STATE_SLEEPING` to the router callback. If the local sleep
handler throws, the existing exception path terminates the queue and no router
sleep notification is emitted from that failed transition. On wake,
`handle_sleeping_state(false)` still reloads the model through `load_model`;
that path keeps the existing loading and ready notifications.

The test-only hooks are guarded by `LLAMA_SERVER_CACHE_TESTS`. They let
`test-cache-controller` invoke the same sleep callback without loading a model.

## Focused regression

Added `test_stage35_state_callback_keeps_sleep_handler` to
`tests/test-cache-controller.cpp`.

The test registers `set_state_callback`, installs the production sleep handler
through the test hook, invokes sleep entry, and asserts:

- local `server_context_impl::sleeping` becomes true;
- router callback receives exactly one `sleeping` state;
- router callback observes the local sleeping flag already set, proving local
  sleep handling ran before notification.

## Build and test evidence

| Check | Command | Result |
| --- | --- | --- |
| Focused build | `cmake --build build-cuda --config Release --target llama-server test-cache-controller -j 8` | PASS, exit 0 |
| Direct cache controller | `build-cuda\bin\Release\test-cache-controller.exe` | PASS, 150 tests |
| Cache ctest | `ctest -C Release -R cache --output-on-failure` from `build-cuda` | PASS, 1/1 |

Evidence files:

- `build-cuda/stage35-f35-impl-01-build.log`
- `build-cuda/stage35-f35-impl-01-build-exit.txt`
- `build-cuda/stage35-f35-impl-01-test-cache-controller.log`
- `build-cuda/stage35-f35-impl-01-test-cache-controller-exit.txt`
- `build-cuda/stage35-f35-impl-01-ctest-cache.log`
- `build-cuda/stage35-f35-impl-01-ctest-cache-exit.txt`

Relevant direct-test log lines:

- `test-cache-controller: Stage 35 router state callback keeps sleep handler...`
- `PASSED`
- `All tests passed successfully!`
- `Total: 150 tests`

## Source-ref check

| Check | Output |
| --- | --- |
| `git rev-parse --verify MERGE_HEAD` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| `git rev-parse origin/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| `git ls-remote origin refs/heads/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe refs/heads/upstream_master` |

## Handoff

F35-IMPL-01 is ready for Architect implementation re-review. The merge remains
open and uncommitted. Commits, pushes, PRs, and reviewer responses remain
blocked unless separately requested.
