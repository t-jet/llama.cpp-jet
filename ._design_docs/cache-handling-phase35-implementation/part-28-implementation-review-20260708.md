# Stage 35 implementation review 2026-07-08

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Verdict

REWORK.

The open no-commit merge still needs a source-fix pass before Manager can
advance it. Focused build and cache tests passed after Part 27, but the router
sleep-state merge resolution drops required local sleep/resume behavior when a
child process registers router state callbacks.

No production code was edited in this review.

## Scope reviewed

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase35-design.md`
- `._design_docs/cache-handling-phase35-implementation.md`
- Parts 22, 25, 26, and 27 under
  `._design_docs/cache-handling-phase35-implementation/`
- Current staged and unstaged source diff for:
  `tools/server/server-context.cpp`,
  `tools/server/server-context.h`,
  `tools/server/server-cache-hybrid.cpp`,
  `tools/server/server-common.cpp`,
  `tools/server/server-common.h`,
  and upstream split files around schema, stream, task, and router/model state.

## Blocking finding

### F35-IMPL-01: router callback override drops sleep/resume lifecycle

`tools/server/server-context.cpp:1098` installs the normal queue sleep handler
that calls `handle_sleeping_state(sleeping)`. That handler destroys the model on
sleep and reloads it on wake at `tools/server/server-context.cpp:531-539`.

Part 27's restored router callback path then calls
`queue_tasks.on_sleeping_state(...)` again in
`tools/server/server-context.cpp:3774-3780`. Because `server_queue` stores one
`callback_sleeping_state` function, the second registration replaces the first
one. In router child mode, where `server.cpp:587-591` calls
`ctx_server.set_state_callback(...)`, idle sleep no longer reaches
`handle_sleeping_state`. The child can report `SERVER_STATE_SLEEPING` to the
router, but the local model unload/reload path is bypassed.

This violates Stage 35 route/session lifecycle preservation and the upstream
server split interaction for router child state updates. It also makes Part 27
evidence insufficient: `test_router_props` only proves the router props route
starts, not that a child entering and leaving sleep still runs the local
sleep/resume lifecycle while notifying the router.

Required correction:

- Compose the router state callback with the existing sleep handler instead of
  replacing it. The sleep transition must still call `handle_sleeping_state`
  with its current exception handling, and router notification must be emitted
  from the same transition.
- On sleep entry, notify the router of `SERVER_STATE_SLEEPING` only after local
  sleep handling succeeds, or document and handle the failure path.
- On wake, preserve the reload path and make the router-visible state match the
  child state. If the existing ready notification from `load_model` is used for
  wake, keep that behavior explicit in code or evidence.
- Add focused evidence that enters the child sleep callback path with
  `set_state_callback` registered. A unit-level hook is acceptable if it proves
  the composed handler calls both local sleep handling and router notification.

## Non-blocking decisions

- Stage 25 transaction entry points remain present. `tx_save`, `tx_load`,
  `tx_restore`, and `tx_apply_restore` still take the cache-state lock at their
  transaction boundaries in `server-cache-hybrid.cpp`.
- Stage 34 idempotent save and Path B behavior are preserved in the reviewed
  code shape. `tx_save` keeps first-pass hot dedupe before slow reads, slow
  target/draft reads outside `cache_state_mutex_`, second-pass dedupe after the
  reads, and cold re-materialization in place.
- Checkpoint user-boundary rebasing is plausible: completion parsing now fills
  `task.params.message_spans` from tokenized `message_delimiters`, then
  checkpoint gating uses `last_user_message_pos()`. No blocker found there.
- Schema parser merge is correct at compile level: completion parsing now calls
  `server_schema::eval_llama_cmpl_schema` and includes `server-schema.h`.
- MTMD `process_chunk` restoration is correct at compile level: declaration and
  definition are restored in `server-common.h/.cpp`, and the prompt loop calls
  it for media chunks.
- Model identity merge is correct: removed `common_params_model::name` uses are
  replaced with `get_name()` in model fallback naming and hybrid draft-source
  namespace construction.

## Evidence review

Accepted evidence:

- Part 27 source-ref checks: open `MERGE_HEAD`, `origin/upstream_master`, and
  remote `refs/heads/upstream_master` match
  `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`.
- Focused build: `llama-server` and `test-cache-controller` build.
- Focused cache tests: direct `test-cache-controller` passed 149 tests, and
  `ctest -C Release -R cache` passed 1/1.

Evidence gap:

- Router evidence does not exercise child sleep-state callback composition.
  `test_router_props` is too shallow for F35-IMPL-01.

## Handoff

Next owner: Developer.

Next gate: source-fix rework for F35-IMPL-01, followed by Architect
implementation re-review. Merge commit, push, PR, and reviewer response remain
blocked.
