# Stage 35 merge/rework implementation plan 2026-07-07

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Status

Status: IMPLEMENTATION PLAN READY FOR REVIEW, 2026-07-07
Owner: Developer
Gate: implementation planning only
Source ref: `origin/upstream_master`
Accepted source tip: `108f186d1701d56133a0239dd6754c8814374cbf`
Accepted range: `HEAD..origin/upstream_master`

This plan covers merge and rework execution after the implementation-plan gate.
It does not perform or authorize a merge. No production code, regression run,
commit, push, PR, or reviewer response is part of this planning session.

## Entry gates before merge execution

| Gate | Required action | Stop condition |
| --- | --- | --- |
| Source ref and staleness | Re-run `git rev-parse origin/upstream_master`, `git log -1 --format='%H %ai %s' origin/upstream_master`, `git merge-base HEAD origin/upstream_master`, `git rev-list --count HEAD..origin/upstream_master`, `git remote -v`, and `git ls-remote https://github.com/ggml-org/llama.cpp.git master`. | Any SHA, count, or fork point differs from accepted pre-merge analysis without Manager approval. |
| Dirty worktree | Record `git status --short`. The real merge requires a clean-enough tree under guide part 04 section 11. Planning docs may stay dirty only by Manager exception. | Any uncommitted non-planning edit remains, or cleanup would require a commit without explicit human approval. |
| AGENTS.md rule | Do not commit cleanup, merge results, or doc updates unless the human gives explicit approval for that specific commit. | Any step depends on an unapproved commit, push, PR, or reviewer response. |
| Rework readiness | Confirm design parts 04-06, design review part 07, and Manager rework gate part 08 are still current. | Any rework gate reopens, or a new upstream row enters one track. |

## Ordered execution phases

| Phase | Work | Output |
| --- | --- | --- |
| 1. Preflight | Run source/staleness checks, dirty-tree gate, and source-tip comparison. | Merge log preflight section with commands and outputs. |
| 2. Track analysis | Complete the three required per-track analyses below before any merge command. | Analysis appendix in the merge log; unresolved rows remain blocked. |
| 3. Merge setup | After Manager approval, run the guide-approved real two-parent merge path. Fast-forward is not allowed because 67 INTEGRATE and 9 REWORK rows need local review. | Merge command, parent SHAs, conflict list. |
| 4. Textual conflict resolution | Resolve by hand. Local-first for hybrid/cache contracts; upstream-first for legacy/default paths. | Conflict table with policy, local adjustment, preserved contract, and test. |
| 5. Semantic conflict scans | Run scans listed below across expected touched files and any merge-conflict files. | Duplicate, rename, enum, struct, helper, behavior-change scan notes. |
| 6. Rework closure | Apply approved local adjustments for the three rework tracks. Escalate any behavior change to durable docs first. | Rework evidence entries and changed-file list. |
| 7. Regression package | Run only after all rework is closed and Manager clears dirty/staleness state. | Build, ctest, HTTP, metrics, coverage, checkpoint/MTP, replay, and staleness evidence. |
| 8. Merge log handoff | Write final merge log and update implementation entry. | Architect review handoff; Manager closure remains later gate. |

## Triage handling

The accepted pre-merge analysis has 89 filtered rows: 13 NO-OP, 67 INTEGRATE,
and 9 REWORK-REQUIRED.

| Decision | Execution handling |
| --- | --- |
| 13 NO-OP | Integrate as part of the upstream merge. Do not add local code for these rows unless conflict scans prove they touched a protected contract. Keep one-line reasons in the merge log. |
| 67 INTEGRATE | Integrate with focused conflict scans for the named surface. For each local adjustment, cite the prior-stage contract and evidence row. Escalate to Manager if the row starts to weaken a contract. |
| 9 REWORK-REQUIRED | Keep in one of the three tracks below. Do not downgrade before the required analysis proves compatibility and Manager accepts the result. |
| 0 DEFER / 0 REVERT | Keep zero unless Manager records a new decision. Any new DEFER or REVERT needs impact, owner, and follow-up in the merge log. |

## Required track analysis before merge

### MTP, KV, and speculative

Rows: `88a39274ecf8`, `d789527482d9`, `d1b34251bc57`, `8c146a836630`.

Required analysis before merge:

- Inventory each runtime shape: no draft, separate draft, target-derived MTP,
  or separate-model MTP.
- List new compatibility-key inputs: speculative mode, KV layout, SWA/ISWA,
  model architecture, draft identity, and context type.
- Map each runtime to binary `target_only` or `target_and_draft`; do not add a
  third pair state.
- Trace save, restore, promotion, demotion, eviction, and checkpoint admission
  to Stage 25 transaction ownership.
- Confirm slow target/draft reads stay outside `cache_state_mutex_` and retain
  I-34-02 second-pass dedupe.
- Confirm MTP and DeepSeek KV checkpoints validate token span, checksum,
  workload profile, namespace, and pair state before descriptor attachment.
- Classify speculative metrics as additive, renamed, or incompatible with
  bounded label policy.

### Route and session lifecycle

Rows: `4b4d13ae721e`, `2b686a9120e2`, `721354fbdfb7`, `1a87dcdc452d`.

Required analysis before merge:

- Inventory added, removed, renamed, and behavior-changed routes, including
  model management and SSE/load-progress surfaces.
- Trace request parse to prompt preparation, `PreparedPromptMetadata`,
  `server_task`, and cache planning for each route that can create prompt state.
- Prove public schemas do not require cache-specific request or response fields.
- Prove model id, session id, stream id, request id, and SSE replay id stay out
  of namespace unless they change model/template/runtime ABI.
- Record router child, model download process, model management API, server
  context, and slot ownership lifecycle boundaries.
- Separate upstream SSE transport replay from Stage 34 transcript replay and
  branch/session evidence.
- Confirm or update public HTTP, route smoke, and replay harness commands before
  regression starts.

### Checkpoint placement

Row: `73618f27a801`.

Required analysis before merge:

- Identify whether upstream placement uses tokenized metadata, raw text search,
  role markers, or parser events.
- Compare user-message checkpoints to prompt-span boundaries at
  `[0, message_token_end]`.
- Prove token-span and checksum validation happens before descriptor attachment.
- Record chat-template rendering or user-message detection changes that move
  token ends.
- Trace OpenAI-compatible chat prompt preparation into `PreparedPromptMetadata`.
- Define bounded diagnostics for unsafe or missing boundary metadata.
- Identify unit, chat-template, checkpoint, and MTP rows that must rerun or be
  amended.

## Semantic conflict scans

Run these after textual conflicts are resolved and before regression:

- Conflict marker check: `rg '<<<<<<<|=======|>>>>>>>'`.
- Duplicate definition scan for expected touched C++ files, with manual scope
  review for true file-scope duplicates.
- Old/new symbol grep for public API, enum, struct-field, task-type, metric, and
  diagnostic renames.
- Switch audit for new enum values and task types.
- Struct construction audit for added fields in server tasks, metadata,
  speculative context, KV cache, checkpoint, and route schemas.
- Helper overlap audit for new upstream helpers that duplicate local cache,
  route, prompt, or metric helpers.
- Behavior-change call-site grep for functions used by cache, checkpoint,
  route metadata, speculative setup, and slot lifecycle.
- Public metric scan for bounded labels and unique HELP/TYPE blocks.

## Durable doc update triggers

Before merge execution continues, update the owning durable docs if analysis
changes any of these behaviors:

| Trigger | Owning docs |
| --- | --- |
| New speculative discriminator, draft mode, pair rule, or descriptor field | Architecture part 6; Stage 5 parts 02-03 |
| Checkpoint placement, descriptor admission, metric, or diagnostic rule changes | Stage 9 parts 02-04; architecture part 9 |
| Route family, public schema, metadata parity, or endpoint architecture changes | Stage 13 parts 01-02; architecture part 8 |
| Namespace treatment for model, session, router, or request fields changes | Stage 31 design or Stage 32 implementation owner docs |
| Branch/session evidence, transcript replay, idempotent save, or slow-read placement changes | Stage 34 design part 04 or a new Stage 34 part |
| Transaction boundary, lock ownership, or slot/cache lifecycle boundary changes | Stage 25 parts 02-03 |
| New architecture invariant | `cache-handling-architecture.md` or a new architecture part |

## Regression and evidence matrix

| Surface | Evidence after merge/rework |
| --- | --- |
| Source freshness | Repeat staleness commands at regression time; Manager decides any new gap. |
| Build | Clean build with directory, configuration, targets, command, and timestamp. |
| Cache core | Focused `ctest -R cache` with raw log path. |
| MTP/KV/speculative | Pair-state mismatch, MTP namespace isolation, target/draft eviction unit tests, public MTP probe when fixture exists, checkpoint-capable admission or bounded unsupported reason. |
| Routes/session | Public HTTP probes for native completion, OpenAI chat, embeddings when exposed, metrics, health, slots, and model-management routes touched by upstream. |
| Checkpoint placement | Unit test for chat prompt-span boundaries, positive admission validation, negative shifted-boundary rejection, public chat probe when fixture exists. |
| Metrics | Bounded labels, unique HELP/TYPE blocks, hybrid counters, checkpoint counters, and no prompt-local session labels. |
| Cold store and filesystem | Descriptor root containment, checksum, atomic write/rename, and cold file proof when cold paths changed. |
| Stage 34 replay | Replay or synthetic agentic rows when branch/session, stream resume, `tx_save`, save/restore, or slow-read paths changed. |
| Coverage | Focused coverage if feature-mode files changed; cite markdown combined, product-only, and per-file blocks, not XML root attributes. |

## Stop conditions and rollback

Stop before merge if the source ref is stale, the fork point changed, the dirty
tree cannot be cleaned without unapproved commit/discard/stash, or any required
track analysis cannot prove compatibility.

Stop during conflict resolution if a protected contract would change without an
approved durable doc update and Manager decision.

Stop before regression if any rework track remains open, metrics shape is
ambiguous, a fixture gap lacks Manager approval, or semantic scans are
incomplete.

Rollback for failed merge follows upstream guide part 04: reverse merge,
explicit reset to fork point, or a new merge attempt from fork point. The chosen
path must be recorded in the merge log and must not rewrite history silently.

No commit, push, PR, reviewer response, destructive cleanup, or production-code
change is allowed without the next approved gate and explicit human approval
where AGENTS.md requires it.

## Handoff

Next owner: Architect.

Next gate: implementation-plan review.

Merge execution, conflict resolution, production code changes, regression runs,
commits, pushes, PRs, and reviewer responses remain blocked.
