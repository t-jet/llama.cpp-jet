# Stage 35 F35-IMPL-01 implementation re-review 2026-07-08

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Verdict

PASS.

F35-IMPL-01 is closed for the focused implementation scope. The rework composes
router child state notification with the local sleep handler instead of
replacing it, and the current source preserves the prior local sleep destroy and
wake reload behavior.

No production code was edited in this review.

## Scope reviewed

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase35-implementation.md`
- [Part 28: implementation review](part-28-implementation-review-20260708.md)
- [Part 29: F35-IMPL-01 rework evidence](part-29-f35-impl-01-rework-evidence-20260708.md)
- Current source and test diff for:
  `tools/server/server-context.cpp`,
  `tools/server/server-context.h`,
  `tools/server/server-queue.h`,
  `tools/server/server.cpp`,
  `tools/server/server-models.cpp`,
  `tools/server/server-models.h`,
  `tools/server/server-cache-hybrid.cpp`,
  and `tests/test-cache-controller.cpp`.

## Review decisions

1. PASS: router callback composition.

   `server_context::set_state_callback` now only stores the router callback on
   `server_context_impl::callback_state`. It no longer calls
   `queue_tasks.on_sleeping_state`, so it does not overwrite the local handler
   installed by `server_context_impl::init()`.

2. PASS: local sleep destroy/reload behavior.

   The installed sleep handler still calls `handle_sleeping_state(sleeping)`.
   On sleep entry, that path logs the transition, calls `destroy()`, and sets
   `server_context_impl::sleeping = true`. On wake, it calls `load_model()` and
   aborts on reload failure before leaving the transition. The router callback
   is additional behavior, not a replacement for local lifecycle handling.

3. PASS: router notification order.

   On sleep entry, the handler calls `handle_sleeping_state(true)` first and
   emits `SERVER_STATE_SLEEPING` only after that local transition succeeds. If
   local sleep handling throws, the existing exception path terminates the queue
   and no sleeping notification is emitted for the failed transition. On wake,
   `handle_sleeping_state(false)` keeps the reload path; `load_model()` emits
   the existing loading and ready child-state notifications. This matches the
   Part 28 correction requirement that wake can use the load-model ready
   notification path.

4. PASS: test-only hooks are guarded.

   `debug_install_sleeping_state_handler_for_tests`,
   `debug_invoke_sleeping_state_for_tests`, and `debug_is_sleeping_for_tests`
   are all behind `LLAMA_SERVER_CACHE_TESTS`. The queue debug invoke hook is
   also guarded. `rg` found these hooks only in `tools/server` declarations and
   definitions plus the focused `test-cache-controller` regression.

5. PASS: focused evidence closes F35-IMPL-01.

   `test_stage35_state_callback_keeps_sleep_handler` registers a router state
   callback, installs the same sleep handler used by production, invokes the
   sleep transition, and asserts that the local sleeping flag is set before the
   router sees `sleeping`. This directly covers the Part 28 failure mode.

6. PASS: Stage 25 and Stage 34 cache invariants remain intact.

   No new cache-state mutation path was introduced by this rework. Current
   `tx_save` still has the first locked snapshot and hot dedupe pass, slow
   target/draft reads outside `cache_state_mutex_`, and the second locked
   dedupe/admit pass. Stage 25 transaction entry points still use the
   transaction mutex, and the Stage 34 idempotent save and Path B tests still
   pass.

## Verification run by Architect

| Check | Command | Result |
| --- | --- | --- |
| Focused build | `cmake --build build-cuda --config Release --target llama-server test-cache-controller -j 8` | PASS |
| Direct cache controller | `build-cuda\bin\Release\test-cache-controller.exe` | PASS, 150 tests |
| Cache ctest | `ctest -C Release -R cache --output-on-failure` from `build-cuda` | PASS, 1/1 |

## Notes

- The broader Stage 35 no-commit merge remains open and uncommitted.
- This PASS is scoped to F35-IMPL-01 and the touched cache-invariant surfaces
  named above. It is not a full Stage 35 regression or Manager closure.

## Handoff

Next owner: Manager.

Next gate: Manager implementation gate decision for the open no-commit Stage 35
merge. Commits, pushes, PRs, and reviewer responses remain blocked unless
separately requested.
