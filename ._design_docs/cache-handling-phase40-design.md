# Stage 40 design: upstream merge cycle after Stage 39 closure

Status: Design gate PASS (Manager 2026-08-26)
Date: 2026-08-26
Stage: 40 (Upstream merge cycle)
Owner: Manager
Current gate: Implementation planning
Branch: work-branch

## Scope

Stage 40 defines the operational contract for the next upstream merge cycle
after Stage 39 closure (D40-INTAKE-01), with the upstream merge guide as the
binding procedure (D40-INTAKE-02). It names the prior-stage contracts from
Stages 36, 38, and 39 the merge must preserve and gives the Developer enough to
write the pre-merge analysis without inventing filters, contract lists, or
upstream-reference policy. Stage 39 closure is the immediate prior-stage
baseline and subsumes Stages 36-38; Stages 36-39 contracts are in scope for
triage and rework analysis (D40-INTAKE-03).

## Exclusions

- No merge, conflict resolution, production change, test, commit, push, or PR
  is authorized by this document.
- Upstream CI, upstream tests, and upstream lint are not cycle evidence (guide
  part 4 section 8); local tests are not replaced (section 9); no history
  rewrite (section 10).
- No new file-glob group enters the cycle unless the Architect adds it during
  review and the Manager approves it.

## Manager decisions recorded at intake

| ID | Decision |
| --- | --- |
| D40-INTAKE-01 | Open Stage 40 as the next upstream merge cycle after Stage 39 closure. |
| D40-INTAKE-02 | Use `upstream-merge-guide.md` as the binding procedure. |
| D40-INTAKE-03 | Stage 39 closure is the immediate prior-stage baseline; Stages 36-39 contracts in scope. |
| D40-INTAKE-04 | Use `origin/upstream_master` as the upstream-cycle reference (direct remote-tracking ref path). |
| D40-INTAKE-05 | Stale working-tree items are not a design-gate blocker; resolve before merge execution. |
| D40-INTAKE-06 | Guide part-04 section 14 (cycle reuse across stages) applies. |

## Review status

- Authored 2026-08-26. Status: Design gate - awaiting Architect review.
- The design review and Manager design gate parts are created by separate
  sessions; this session authors neither. This design is not approved.

## Prerequisites

| Prerequisite | Required state before Developer pre-merge analysis |
| --- | --- |
| Stage 39 closure | PASS per [part 205](cache-handling-phase39-implementation/part-205-manager-closure-20260717.md), closed 2026-07-17. |
| Stages 36-39 contracts | Binding for pre-merge triage and rework analysis (D40-INTAKE-03). |
| Upstream procedure | Developer follows guide parts 01-04 and this design; part-04 section 14 applies (D40-INTAKE-06). |
| Working tree | Clean at pre-merge open; stale items (`.github/agents/manager.agent.md`, `._design_docs/side_input/`) resolve before merge execution (D40-INTAKE-05). |
| Upstream reference | `origin/upstream_master` ref confirmed at design gate (D40-INTAKE-04). |
| Prior-stage closure contracts | Test, metric, coverage, endpoint, cold-store, checkpoint, branch, retention, partial-restore, replay contracts from closed stages remain binding. |

## Upstream reference policy

Reference is the direct remote-tracking ref `origin/upstream_master`
(D40-INTAKE-04), per Stage 35 precedent and D35-INTAKE-04. No separate
`upstream` remote exists. Git state at authoring (2026-08-26):

- Tip: `fc35562ba46fbbf8e30cac85edbb39642c37d248` (2026-08-26, "cuda: unblock
  mmq for MoE on sm_60 (#26264)").
- Fork point: `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` (Stage 35 fork point).
- HEAD: `e9d67a2fb6ad6b186a52b6b35f20d7c9e325c047` (2026-07-21, "rewrite
  architecture document").
- Commits behind: 732. Commits ahead: 113.

Required policy:

- Developer records `git rev-parse origin/upstream_master`,
  `git log -1 --format='%H %ai %s' origin/upstream_master`, merge base, commit
  count, and `git remote -v` in the pre-merge report.
- Developer compares the ref against actual upstream `master` via
  `git ls-remote https://github.com/ggml-org/llama.cpp.git master` or the REST
  API.
- If stale, Developer stops before triage and asks Manager to choose: refresh
  via `git fetch` (guide part-04 section 7b) and redo, or merge with the gap
  recorded as a known gap.
- If the source ref changes after analysis review, the analysis reopens and
  Architect re-reviews it.
- Regression repeats the staleness check; a gap at regression time is a Manager
  decision, not an implied pass.

## Affected prior-stage contracts

The merge must preserve at least these durable contracts. Any change that
weakens one is at least REWORK-REQUIRED unless Manager records DEFER, REVERT,
or known-gap handling with the contract named.

| Contract owner | Contract to preserve |
| --- | --- |
| Architecture | Hybrid stays opt-in; legacy/default behavior unchanged when hybrid disabled. |
| Architecture / Stage 25 | Cache mutations use `tx_restore`, `tx_apply_restore`, `tx_save`, `tx_load`. |
| I-25-01 | Cache-state mutation atomic inside each transaction. |
| I-25-02 | Others observe old or new state, never half-admitted descriptors or payloads. |
| I-25-03 | Cold-store updates durable within the committing transaction. |
| Stage 5 | Target/draft pair-state semantics and MTP namespace isolation intact. |
| Stage 6 / cold | Descriptor versioning, checksum validation, root containment, atomic write/rename. |
| Stage 7/8 | Branch forest topology, metadata-only nodes, equivalent-branch dedupe, re-materialization valid. |
| Stage 9 | Checkpoint payload lifecycle and workload-profile selection intact. |
| Stage 13 | OpenAI/Anthropic/native-completion/embedding/metrics/health/slots route compatibility intact. |
| Architecture part 9 | Chat-path prompt-span boundary invariant intact for checkpoint admission. |
| Stage 31/32 | Compatibility namespace excludes prompt-local fields; public metric labels bounded and unique. |
| Stage 34 | Branch/session evidence outside namespace; replay fixture generic and redacted by default. |
| I-34-01 | Equivalent payload-bearing saves idempotent; `use_count` increments; slow read skipped. |
| I-34-02 | Slow `tx_save` target/draft reads outside `cache_state_mutex_`; second-pass dedupe. |

### Stages 36-39 contracts

Contracts added after the Stage 35 fork point, in scope for triage and rework
analysis (D40-INTAKE-03).

| Contract owner | Contract to preserve |
| --- | --- |
| Stage 36 | Tight duplicate workload lineage (48 rows, 8 bursts, 6 repeats) is the acceptance shape for positive hybrid hits. |
| Stage 36 | Hybrid hit evidence: 40 hits and 8 misses in both hybrid legs; output equivalence diff empty. |
| Stage 36 | Hot bytes at least 40 percent below comparable legacy (measured 66.54); throughput within 10 percent of legacy. |
| Stage 36 | Metrics hygiene: bounded labels, no raw namespace label, unique HELP/TYPE; cold-store failure counters zero. |
| Stage 36 | D36-FU-01 cold-budget gauge defect closed by Stage 38; gauge contract survives. |
| Stage 38 | Chat strict-prefix/checkpoint partial restore only at checkpoint-safe points with span and checksum validation. |
| Stage 38 | Unsafe, non-chat, unsupported prefix candidates fall back to recompute; `/completion` restore recompute-only. |
| Stage 38 | Public `usage.prompt_tokens` full length; `cached_tokens`, `timings.cache_n`, slot cache fields report restored prefix. |
| Stage 38 | `cache_cold_budget_bytes{mode="hybrid"}` reports `2147483648` for 2048 MiB; 64-bit value without narrowing. |
| Stage 38 | Restore planning and cold promotion under the cache mutex; live slot apply outside it. |
| Stage 39 | Two-layer retention: discard reusable payload bytes only after both enabled hot and cold capacities are filled. |
| Stage 39 | Payload eviction versus branch pruning (ADR-009); capacity predicates per enabled layer. |
| Stage 39 | Payload-byte eviction, descriptor tombstones, lookup-entry removal, branch pruning are separate actions with fixed public reasons. |
| Stage 39 | Exact-blob and checkpoint payloads, atomic target/draft pairs; terminal generation and HMAC freeze after full `tx_update()`. |
| Stage 39 | Canonical TP-39-03: natural same-owner pair, exact preflight, two no-skip route nodes, fail-closed caps. |
| Stage 39 | Coverage floor 0.8486 (`10936 / 12887`) on approved denominator, PowerShell 7 and 5, fail-closed forced blocks. |
| Stage 39 | VS2022 conformance: VS2026 evidence needs a VS2022 conformance rerun (SAD authorizes VS2022 baseline). |

## File-glob commit filters

Developer applies these groups to the upstream commit range. A commit is in
scope when it touches one group or its message names the subsystem. Stage 35
groups are reused, extended with the Stages 36-39 surfaces.

| Group | Globs |
| --- | --- |
| Server cache | `tools/server/server-cache-*`, `tools/server/*cache*`, `tests/test-cache-*` |
| Server context and slot lifecycle | `tools/server/server-context.*`, `tools/server/server-slot.*`, `tools/server/server-task.*` |
| Branch graph and residency | `tools/server/server-cache-graph.*`, `tools/server/server-cache-policy.*`, `tools/server/server-cache-store.*`, `tools/server/server-cache-io.*` |
| Chat/template metadata | `common/chat.*`, `common/jinja/**`, `tools/server/*chat*`, `tools/server/*template*`, `common/*template*` |
| Speculative and MTP | `common/speculative.*`, `tools/server/*spec*`, `tools/server/*draft*`, all `src/llama*` runtime files when the diff mentions draft, MTP, SWA, KV, checkpoint, or slot state |
| HTTP routes and adapters | `tools/server/server.cpp`, `tools/server/server-*.cpp`, `tools/server/server-*.h`, `tools/server/README*.md` when route behavior changes |
| Metrics and logs | `tools/server/*metrics*`, `tools/server/server-context.*`, `tools/server/server-cache-hybrid.*`, any file adding cache metric or log fields |
| Cold store and filesystem | `tools/server/server-cache-store.*`, `tools/server/server-cache-io.*`, filesystem helpers, path normalization, serialization |
| Checkpoint and KV state | `common/*checkpoint*`, `src/*checkpoint*`, `tools/server/*checkpoint*`, `src/*kv*`, `tools/server/*kv*`, all `src/llama*` runtime files when the diff mentions KV, checkpoint, MTP, draft, SWA, or slot state |
| Prefix/checkpoint partial restore | `tools/server/server-cache-controller.*`, `tools/server/server-cache-policy.*`, restore planning and validation, checkpoint span/checksum, `tools/server/*prefix*`, `tools/server/*restore*` |
| Two-layer payload retention | `tools/server/server-cache-hybrid.*`, `tools/server/server-cache-policy.*`, cold store and descriptor paths, retention/tombstone/reason-taxonomy files |
| Cold-budget gauge and stats | `tools/server/server-context.*`, server stats JSON, metrics exporter, 64-bit stats field for `cache_cold_budget_bytes` |
| Hybrid hit/performance driver lineage | `._design_docs/cache-handling-test-scripts/**`, `compare-legacy-vs-hybrid*` driver and workload scripts, test-plan part 41 lineage |
| Test harness and fixtures | `tests/**`, `examples/**`, `scripts/**`, `._test_models/**`, `tools/server/tests/**` when they affect cache evidence |
| Coverage and report tooling | coverage scripts, OpenCppCoverage wrappers, `.test_reports/**` templates or generators, T114/T114a/T115 row emitters, coverage denominator sources |
| Build and platform | `CMakeLists.txt`, `cmake/**`, `scripts/**`, `.github/**` only when affecting local build/test/coverage commands |

Pure docs, CI, and upstream tests are excluded unless they change runtime
contracts, local evidence commands, or a test row Stage 40 must cite.

## Pre-merge analysis contract

Developer writes a durable Stage 40 pre-merge report before any merge command:

- metadata (branch, source ref, fork point, local tip, dates, owner, reviewer,
  approver); upstream reference verification commands and outputs
- commit range expression, total count, filtered count, date range
- per-commit triage table (SHA, subject, file-glob groups, affected contracts,
  decision, reason, follow-up owner)
- aggregate NO-OP, INTEGRATE, REWORK-REQUIRED, DEFER, REVERT counts
- expected touched local files from triage
- closure contracts per guide part 3, including the Stage 39 coverage floor and
  VS2022 conformance gap handling
- Manager decisions requested: staleness, ref policy, gaps, coverage drops,
  metric renames, rework threshold, VS2022 disposition
- open questions blocking merge execution

Architect reviews the report before Manager approval. Merge execution remains
closed until both reviews pass.

## Triage and conflict policy

Triage uses the guide decisions: NO-OP, INTEGRATE, REWORK-REQUIRED, DEFER,
REVERT. Reasons must cite a prior-stage contract, path, or test surface;
restating the commit subject fails review.

- Local-first for hybrid mode, cache internals, branch graph, cold store,
  checkpoint payloads, two-layer retention, partial restore, cold-budget gauge,
  Stage 34 replay evidence, and local feature paths unless an approved
  REWORK-REQUIRED plan says otherwise.
- Upstream-first for legacy/default paths unless local code keeps hybrid gated
  away from legacy behavior.
- No blind `--ours`/`--theirs` for mixed semantic regions.
- No deleting code, commenting out paths, or runtime no-ops without a merge-log
  entry naming the protected contract.
- Semantic duplicates, API renames, new struct fields, new enum/task values,
  stale defensive code, divergent fixes follow guide part 02.
- A behavior change in any function local cache code depends on is a semantic
  conflict even if the build passes.

## Rework routing

If an upstream commit invalidates a closed-stage contract, the owning stage gets
one rework part file in its design tree citing the SHA, the broken contract, the
required correction, and the closing evidence. Multiple commits breaking one
contract share a rework unless they create independent gaps.

Following Stage 35 precedent, reworks route into three tracks:

1. MTP/KV/speculative: draft, MTP, KV, SWA, namespace isolation, pair-state.
2. Route/session lifecycle: slot dispatch, stream resume, session routing,
   prefix/checkpoint partial-restore.
3. Checkpoint placement: checkpoint payload lifecycle, workload profiles,
   message-span boundaries, two-layer retention placement.

Rework cannot hide in the merge log alone; durable behavior changes land in the
owning design or architecture doc. QA does not start the Stage 40 regression
while any required rework is open.

## Regression and closure evidence

Minimum no-rework evidence:

- clean build evidence (directory, config, target set, command, timestamp)
- focused `ctest` cache regression output and raw log path
- public HTTP probes for touched route families
- public `/metrics` shape check: bounded labels, unique HELP/TYPE, hybrid
  counters including `cache_hits_total{mode="hybrid"}` and
  `cache_cold_budget_bytes{mode="hybrid"}` when touched
- focused coverage when feature-mode files change: combined block for combined
  threshold, product-only block for product-only, per-file table for T115;
  floor carries the Stage 39 0.8486 contract and the VS2022 note
- cold-store filesystem proof when cold-store or descriptor paths change
- checkpoint/MTP public admission rows when checkpoint, speculative, retention,
  or partial-restore paths change and a capable fixture exists
- positive hybrid hit / performance row when the driver lineage or retention/
  restore paths change, per the Stage 36 acceptance shape
- Stage 34 replay or synthetic agentic rows when branch/session/replay,
  concurrent save/restore, `tx_save`, or prefix-restore paths change
- stale-ref check repeated at regression time

Expanded evidence for each closed rework is named in the rework part file.

## Merge log and closure

The Developer merge log must record source ref, actual upstream tip, fork
point, final triage decisions, conflicts, semantic-conflict scans, reworks,
deferred commits, known gaps, regression evidence, staleness checks,
dirty-worktree resolution (D40-INTAKE-05), VS2022 gap handling, and handoff.
Architect reviews the merge log. Manager closes Stage 40 only after closure
evidence proves the preserved contracts or records accepted gaps with owners.

## Risks

| Risk | Mitigation |
| --- | --- |
| `origin/upstream_master` lags actual `master` | Fresh `ls-remote` check before range and at regression; Manager decides gap handling. |
| Refactor compiles but breaks cache, retention, or partial-restore semantics | File-glob triage, call-site grep, focused regression for touched contracts. |
| Metric or label rename breaks public evidence | Metric/field rename is a Manager decision; bounded public label shape preserved unless rework approves. |
| Upstream changes legacy cache defaults | Upstream-first only when legacy stays default-compatible and hybrid stays opt-in. |
| Concurrent save/restore reintroduces Stage 34 race defects | I-34-01/I-34-02 preservation contracts; Stage 34 rows rerun when touched. |
| Weakens two-layer retention or coverage floor | Rework candidate; Stage 39 0.8486 and TP-39-03 stay binding unless known-gap plan. |
| VS2022 conformance gap from VS2026 evidence | Known gap with follow-up owner if coverage tooling touched; Manager decides. |
| Stale working-tree items block execution | D40-INTAKE-05: not a design blocker; resolve before merge execution and record in log. |
| Coverage report cites wrong denominator | Cite markdown combined/product-only blocks, not XML root attributes. |

## Acceptance criteria

Stage 40 design can pass review when:

- source-ref policy, including staleness and the direct remote-tracking ref
  path, is explicit
- prior-stage and architecture contracts listed, including Stages 36, 38, 39
  and I-34-01/I-34-02
- file-glob filters cover cache, context, branch, chat/template, MTP, partial
  restore, retention, cold-budget gauge, driver lineage, HTTP, metrics,
  cold-store, checkpoint, test, and coverage
- pre-merge report sections and triage decisions defined
- conflict, rework, regression, and merge-log policies point to durable docs
- three rework tracks (MTP/KV/speculative, route/session lifecycle, checkpoint
  placement) specified
- merge execution stays blocked until pre-merge analysis review and Manager
  approval pass

## Handoff

Next owner: independent Architect design review, then Manager design gate. The
design review and Manager design gate parts come from those separate sessions.

Allowed next work: an independent Architect review of this design, then the
Manager design gate.

Merge execution, regression reruns, commits, pushes, PRs, and reviewer
responses remain unauthorized until the dirty-worktree policy is satisfied
(D40-INTAKE-05) and Developer implementation is explicitly opened.
