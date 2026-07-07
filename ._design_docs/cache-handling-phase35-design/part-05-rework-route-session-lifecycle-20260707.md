# Stage 35 rework: route and session lifecycle routing

Source: [../cache-handling-phase35-design.md](../cache-handling-phase35-design.md)

## Status

Status: REWORK DESIGN READY FOR REVIEW, 2026-07-07
Owner: Architect
Track: route/session lifecycle
Gate: merge execution blocked until this part passes independent review and
Manager gate.

This part routes the Manager-approved pre-merge REWORK-REQUIRED rows for router
model management, child process lifecycle, model download process split, and
SSE replay/session behavior.

## Upstream SHA rows

| SHA | Subject | Pre-merge row decision | Files or surfaces named by analysis |
| --- | --- | --- | --- |
| `4b4d13ae721e` | `server: (router) add model management API (#23976)` | REWORK-REQUIRED | `tools/server/server-http.*`, `server-models.*`, `server-queue.*`, `server-task.h`, router tests, server docs |
| `2b686a9120e2` | `server: refactor child --> router communication (#24821)` | REWORK-REQUIRED | `common/arg.cpp`, `tools/server/server-context.*`, `server-models.*`, `server.cpp` |
| `721354fbdfb7` | `server: (router) move model downloading to dedicated process (#24834)` | REWORK-REQUIRED | `common/arg.*`, `tools/server/server-context.*`, `server-models.*`, `server.cpp`, router tests |
| `1a87dcdc452d` | `server + ui: SSE Replay Buffer (#23226)` | REWORK-REQUIRED | `tools/server/server-context.cpp`, `server-http.*`, `server-models.*`, `server-stream.*`, UI stream resume code and tests |

Source tip for the accepted pre-merge analysis:
`origin/upstream_master` at `108f186d1701d56133a0239dd6754c8814374cbf`.

## Affected contract owners

| Owner | Contract that must survive |
| --- | --- |
| Stage 13 | Public route schemas stay compatible; request bodies do not need cache-specific fields; endpoint adapters feed shared internal metadata. |
| Architecture part 3 and part 8 | Public endpoint compatibility and Stage 13 corrections remain binding across native, OpenAI-compatible, Anthropic-compatible, metrics, health, and slots routes. |
| Stage 25 | Slot lifecycle calls into cache transactions, but `cache_state_mutex_` does not guard server slots or child process lifecycle. |
| Stage 31/32 | Namespace excludes prompt-local request/session fields; public metric labels stay bounded. |
| Stage 34 | Branch/session identity is evidence and ranking metadata, not namespace proof; replay fixture remains generic and redacted by default. |
| Upstream merge guide | Router/session behavior changes that break prior-stage route evidence are rework candidates, not silent integrations. |

## Risk

The router rows can change how requests reach `server_context`, how models are
loaded, and how streamed responses resume. These are cache-adjacent because
Stage 13 attaches metadata before task creation, Stage 34 relies on session and
branch evidence, and Stage 25 assumes slot ownership is separate from cache
transaction ownership.

The main risk is routing cache policy through new public APIs or session fields.
Another risk is lifecycle drift: child/router process changes may make the old
server start, smoke, and replay evidence commands invalid even if cache code is
unchanged. SSE replay can also look like Stage 34 replay evidence while actually
being a transport resume buffer with different semantics.

## Required analysis before merge

Developer must complete this analysis before running any merge command:

| Analysis item | Required result |
| --- | --- |
| Route inventory | List added, removed, renamed, or behavior-changed server routes and whether each can create prompt state. |
| Task construction trace | For each affected route, trace request parse -> prompt preparation -> `PreparedPromptMetadata` -> `server_task` -> cache planning. |
| Public schema check | Prove no cache-specific request or response field is required for public compatibility. |
| Namespace check | Prove router model id, session id, stream id, request id, and SSE replay id do not enter namespace unless they change model/template/runtime ABI. |
| Process lifecycle check | Record how router child, model download process, and model management API start and stop relative to `server_context` and slot ownership. |
| SSE semantics check | Distinguish upstream SSE replay buffer transport resume from Stage 34 agentic transcript replay and branch/session evidence. |
| Evidence command check | Update or confirm public HTTP probe, route smoke, and replay harness commands before regression. |

If route or lifecycle behavior cannot be traced through metadata construction,
the affected row remains REWORK-REQUIRED.

## Allowed integration conditions

Integration is allowed only when all conditions hold:

- The rework design review and Manager gate pass for this part.
- Public endpoint schemas remain compatible with Stage 13, or a durable Stage
  13 correction explicitly approves the change.
- Cache enablement remains command-line selected; request bodies do not gain
  mandatory cache controls.
- New router/session identifiers are evidence or diagnostics unless they are
  real compatibility inputs.
- The cache controller still owns policy; route handlers do not rank cache
  candidates or inspect descriptor formats.
- Router child and download process changes do not make cache transactions
  depend on process lifecycle locks.
- SSE replay buffer integration does not replace Stage 34 replay evidence and
  does not store raw prompts by default.
- Updated smoke commands are documented before regression starts.

## Regression evidence required after closed rework

Minimum expanded evidence for this track:

- Clean build and focused server/router test output.
- Public HTTP probes for native `/completion`, OpenAI-compatible chat,
  embeddings where exposed, metrics, health, and slots or model-management
  routes touched by upstream.
- Route metadata trace evidence showing equivalent prompts enter the same
  namespace across compatible routes.
- Metrics shape check: bounded labels, unique HELP/TYPE blocks, and no
  prompt-local session labels.
- Server lifecycle evidence: start, model load/download path, child/router
  shutdown, and no stale child process after test cleanup.
- Stage 34 replay or synthetic agentic row when branch/session or stream resume
  surfaces changed.
- Fresh upstream staleness check at regression time.

## Durable doc updates if behavior changes

If merge analysis changes behavior, update the owning durable doc before merge
execution:

| Behavior change | Durable doc that must change |
| --- | --- |
| Public route family added, removed, or schema changed | `cache-handling-phase13-design/part-01-route-scope-and-endpoint-contract.md` |
| Metadata construction or parity rule changes | `cache-handling-phase13-design/part-02-metadata-construction-and-parity-rules.md` |
| Endpoint architecture correction changes | `cache-handling-architecture/part-08-stage-13-endpoint-compatibility-corrections.md` |
| Namespace treatment of model/session/router fields changes | `cache-handling-phase31-design.md` or Stage 32 implementation doc, as owner of the namespace fix-loop closure |
| Branch/session evidence or replay semantics change | `cache-handling-phase34-design.md` or a new Stage 34 design part |
| Slot/cache lifecycle boundary changes | `cache-handling-phase25-design/part-02-atomic-transaction-protocol.md` |

## Handoff

Next owner: independent Architect review, then Manager gate.

Handoff state: RE-REVIEW REQUIRED. Merge execution, regression runs, commits,
pushes, PRs, and reviewer responses remain unauthorized.
