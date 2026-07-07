VERDICT: PASS

# Stage 35 rework design review 2026-07-07

Source: [../cache-handling-phase35-design.md](../cache-handling-phase35-design.md)

## Scope

Review type: independent Architect design review for the Stage 35 rework
routing parts.

Subject reviewed:

- [Part 04: MTP, KV, and speculative routing](part-04-rework-mtp-kv-speculative-20260707.md)
- [Part 05: route and session lifecycle routing](part-05-rework-route-session-lifecycle-20260707.md)
- [Part 06: checkpoint placement routing](part-06-rework-checkpoint-placement-20260707.md)
- Stage 35 design entry, Manager pre-merge approval, and accepted pre-merge
  analysis rows.
- Architecture parts 3, 6, 8, and 9 plus Stage 5, Stage 9, Stage 13, Stage 25,
  and Stage 34 design entries.

No merge, fetch, conflict resolution, production code change, regression run,
commit, push, PR, or reviewer response was performed.

## Evidence checked

| Check | Review evidence | Result |
| --- | --- | --- |
| Manager routing | Part 05 Manager pre-merge approval keeps all 9 rows REWORK-REQUIRED and groups them into three tracks | PASS |
| Row coverage | Parts 04-06 cover all 9 accepted REWORK rows from pre-merge analysis part 01 | PASS |
| Track split | MTP/KV/speculative = 4 rows, route/session lifecycle = 4 rows, checkpoint placement = 1 row | PASS |
| Contract owners | Each part names affected prior-stage or architecture owners | PASS |
| Required analysis | Each part requires concrete pre-merge analysis before any merge command | PASS |
| Allowed integration conditions | Each part keeps merge blocked until review and Manager gate pass | PASS |
| Regression evidence | Each part names expanded post-rework evidence and fresh staleness check | PASS |
| Durable doc updates | Each part names owning durable docs if behavior changes | PASS |
| Handoff | Each part keeps merge, regression, commits, pushes, PRs, and reviewer responses unauthorized | PASS |
| Size rule | Entry doc and parts 04-06 are under 300 lines | PASS |

## Findings

No blocking, non-blocking, or informational findings.

## Review notes

Part 04 correctly treats new speculative runtimes and DeepSeek V4 KV layout as
compatibility and descriptor-validation risks, not build-only conflicts. The
required runtime-shape, namespace, pair-state, transaction, slow-read,
checkpoint, and metric audits map to architecture part 6, Stage 5, Stage 9,
Stage 25, and Stage 34 contracts.

Part 05 correctly keeps router, child process, model download, and SSE replay
changes in one route/session lifecycle track. The required route inventory,
task construction trace, schema check, namespace check, process lifecycle
check, SSE semantics check, and evidence-command check map to Stage 13,
Stage 31/32, Stage 34, and Stage 25 contracts.

Part 06 correctly isolates upstream user-message checkpoint placement as its
own checkpoint-boundary track. The required placement-source trace, boundary
compatibility, checksum validation, prompt-template impact, route adapter
trace, fallback behavior, and test impact checks map to Stage 9 and
architecture part 9.

## Decision

Rework design review gate: PASS.

The three Stage 35 rework design parts are reviewable and complete enough for
Manager rework gate.

Next owner: Manager.

Next gate: Manager rework gate for parts 04-06.

Merge execution, conflict resolution, production code changes, regression
runs, commits, pushes, PRs, and reviewer responses remain unauthorized until
Manager rework gate passes and the dirty-worktree policy is satisfied.
