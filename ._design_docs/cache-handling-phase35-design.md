# Stage 35 design: upstream merge cycle after Stage 34 closure

Status: Design gate PASS; pre-merge rework design authored for review, 2026-07-07
Date: 2026-07-07
Stage: 35 (Upstream merge cycle)
Owner: Architect
Current gate: Rework design review / Manager rework gate
Branch: work-branch

## Scope

Stage 35 defines the operational contract for the next upstream merge cycle
after Stage 34 closure. The binding procedure is
[upstream-merge-guide.md](upstream-merge-guide.md). This design adapts that
procedure to the current cache work, names the prior-stage contracts that must
survive the merge, and gives the Developer enough information to write the
pre-merge analysis without inventing filters, contract lists, evidence rows, or
upstream-reference policy.

This design does not authorize a merge, conflict resolution, production code
changes, test execution, commits, pushes, PRs, or reviewer responses.

## Review status

- [Design review 2026-07-07](cache-handling-phase35-design/part-01-design-review-20260707.md): REWORK, F35-DESIGN-01.
- [Design re-review 2026-07-07](cache-handling-phase35-design/part-02-design-re-review-20260707.md): PASS, 0 findings.
- [Manager design gate 2026-07-07](cache-handling-phase35-design/part-03-manager-design-gate-20260707.md): PASS.
- [MTP/KV/speculative rework design 2026-07-07](cache-handling-phase35-design/part-04-rework-mtp-kv-speculative-20260707.md): ready for review; merge execution blocked.
- [Route/session lifecycle rework design 2026-07-07](cache-handling-phase35-design/part-05-rework-route-session-lifecycle-20260707.md): ready for review; merge execution blocked.
- [Checkpoint placement rework design 2026-07-07](cache-handling-phase35-design/part-06-rework-checkpoint-placement-20260707.md): ready for review; merge execution blocked.

## Prerequisites

| Prerequisite | Required state before Developer pre-merge analysis |
| --- | --- |
| Stage 34 closure | PASS per [part 21](cache-handling-phase34-implementation/part-21-manager-closure-20260707.md). |
| Stage 34 reopen contracts | I-34-01 and I-34-02 are binding merge-preservation contracts. |
| Upstream procedure | Developer must follow the guide parts 01-04 and this design. |
| Working tree | Clean at pre-merge analysis open; dirty state blocks the cycle unless Manager records an exception. |
| Upstream reference | Final source ref must be confirmed by Manager at design gate before Developer opens the commit range. |
| Prior-stage closure contracts | Test, metric, coverage, endpoint, cold-store, checkpoint, branch, and replay contracts from closed stages remain binding. |

## Upstream reference policy

The initial candidate is `origin/upstream_master`, because Manager intake found
that ref locally and recorded no separate `upstream` remote. Stage 35 uses the
direct remote-tracking ref path unless the Manager design gate changes it.

Required policy:

- Developer records `git rev-parse origin/upstream_master`,
  `git log -1 --format='%H %ai %s' origin/upstream_master`, merge base, commit
  count, and `git remote -v` in the pre-merge report.
- Developer compares `origin/upstream_master` against the actual upstream
  `master` tip with `git ls-remote https://github.com/ggml-org/llama.cpp.git master`
  or the GitHub REST API.
- If `origin/upstream_master` is stale, Developer stops before commit triage and
  asks Manager to choose: fetch and redo analysis on the refreshed ref, or keep
  the gap and record missing upstream SHAs as a known gap.
- If the source ref changes after pre-merge analysis review, the analysis
  reopens and Architect re-reviews it.
- Regression evidence must repeat the staleness check. A new gap at regression
  time is a Manager decision point, not an implied pass.

## Affected prior-stage contracts

The merge must preserve at least these durable contracts:

| Contract owner | Contract to preserve |
| --- | --- |
| Architecture | Hybrid mode stays opt-in; legacy/default behavior stays unchanged when hybrid is disabled. |
| Architecture / Stage 25 | Cache mutations use `tx_restore`, `tx_apply_restore`, `tx_save`, and `tx_load` under the Stage 25 transaction model. |
| I-25-01 | Cache-state mutation remains atomic inside each transaction. |
| I-25-02 | Other transactions observe either old or new cache state, never half-admitted descriptors or payloads. |
| I-25-03 | Cold-store updates are durable within the transaction that commits them. |
| Stage 5 | Target/draft pair-state semantics and MTP namespace isolation remain intact. |
| Stage 6 / cold layer | Descriptor versioning, checksum validation, root containment, and atomic write/rename remain intact. |
| Stage 7/8 | Branch forest topology, metadata-only nodes, equivalent-branch dedupe, and re-materialization stay valid. |
| Stage 9 | Checkpoint payload lifecycle and workload-profile selection remain intact. |
| Stage 13 | OpenAI-compatible, Anthropic-compatible, native completion, embedding, metrics, health, and slots route compatibility remain intact. |
| Architecture part 9 | Chat-path prompt-span boundary invariant remains intact for checkpoint admission. |
| Stage 31/32 | Compatibility namespace excludes prompt-local fields; public metric labels remain bounded and unique. |
| Stage 34 | Branch/session evidence stays outside namespace; replay fixture remains generic and redacted by default. |
| I-34-01 | Equivalent payload-bearing saves are idempotent: no duplicate entry, `use_count` increments, slow read skipped. |
| I-34-02 | Slow `tx_save` target/draft reads stay outside `cache_state_mutex_`; second-pass dedupe prevents duplicate entries. |

Any upstream change that weakens one of these rows is at least
REWORK-REQUIRED unless Manager explicitly records DEFER, REVERT, or known-gap
handling with the protected contract named.

## File-glob commit filters

Developer applies these groups to the upstream commit range. A commit is in
scope when it touches one group or its message names a matching subsystem.

| Group | Globs |
| --- | --- |
| Server cache | `tools/server/server-cache-*`, `tools/server/*cache*`, `tests/test-cache-*` |
| Server context and slot lifecycle | `tools/server/server-context.*`, `tools/server/server-slot.*`, `tools/server/server-task.*` |
| Branch graph and residency | `tools/server/server-cache-graph.*`, `tools/server/server-cache-policy.*`, `tools/server/server-cache-store.*`, `tools/server/server-cache-io.*` |
| Chat/template metadata | `common/chat.*`, `common/jinja/**`, `tools/server/*chat*`, `tools/server/*template*`, `common/*template*` |
| Speculative and MTP | `common/speculative.*`, `tools/server/*spec*`, `tools/server/*draft*`, all `src/llama*` runtime files including `src/llama.cpp`, `src/llama-*.cpp`, and `src/llama-*.h` when the diff mentions draft, MTP, SWA, KV, checkpoint, or slot state |
| HTTP routes and adapters | `tools/server/server.cpp`, `tools/server/server-*.cpp`, `tools/server/server-*.h`, `tools/server/README*.md` when route behavior changes |
| Metrics and logs | `tools/server/*metrics*`, `tools/server/server-context.*`, `tools/server/server-cache-hybrid.*`, any file adding `write_cache_metric` or cache log fields |
| Cold store and filesystem | `tools/server/server-cache-store.*`, `tools/server/server-cache-io.*`, filesystem helpers, path normalization, descriptor serialization |
| Checkpoint and KV state | `common/*checkpoint*`, `src/*checkpoint*`, `tools/server/*checkpoint*`, `src/*kv*`, `tools/server/*kv*`, plus all `src/llama*` runtime files including `src/llama.cpp`, `src/llama-*.cpp`, and `src/llama-*.h` when the diff mentions KV, checkpoint, MTP, draft, SWA, or slot state |
| Test harness and fixtures | `tests/**`, `examples/**`, `scripts/**`, `._test_models/**`, `tools/server/tests/**` when they affect cache evidence |
| Coverage and report tooling | coverage scripts, OpenCppCoverage wrappers, `.test_reports/**` templates or generators, files emitting T114/T114a/T115 style rows |
| Build and platform | `CMakeLists.txt`, `cmake/**`, `scripts/**`, `.github/**` only when the diff affects local build/test commands or coverage evidence |

Pure docs, CI, or upstream tests are excluded unless they change runtime
contracts, local evidence commands, or a test row Stage 35 must cite.

## Pre-merge analysis contract

Developer writes a durable Stage 35 pre-merge report before any merge command.
It must include:

- metadata: branch, source ref, fork point, local tip, dates, owner, reviewer,
  and Manager approver
- upstream reference verification commands and outputs
- commit range expression, total count, filtered count, and date range
- per-commit triage table with upstream SHA, subject, matched file-glob groups,
  affected contracts, decision, reason, and follow-up owner
- aggregate counts for NO-OP, INTEGRATE, REWORK-REQUIRED, DEFER, and REVERT
- expected touched local files derived from triage
- Manager decisions requested, including staleness, ref policy, gaps,
  coverage drops, metric/field renames, or rework threshold
- open questions that block merge execution

Architect reviews the report before Manager approval. Merge execution remains
closed until both reviews pass.

## Triage and conflict policy

Triage decisions use the guide definitions: NO-OP, INTEGRATE,
REWORK-REQUIRED, DEFER, and REVERT. Reasons must cite a prior-stage contract,
file path, or test surface. A reason that restates only the commit subject fails
review.

Conflict resolution rules:

- Local-first for hybrid mode, cache internals, branch graph, cold store,
  checkpoint payloads, Stage 34 replay evidence, and any local feature path
  unless an approved REWORK-REQUIRED plan says otherwise.
- Upstream-first for legacy/default paths unless the local code is needed to
  keep hybrid gated away from legacy behavior.
- No blind `--ours` or `--theirs` for mixed semantic regions.
- No deleting code, commenting out paths, or inserting runtime no-ops without a
  merge-log entry naming the protected contract.
- Semantic duplicates, public API renames, new struct fields, new enum/task
  values, stale local defensive code, and divergent fixes follow guide part 02.
- A behavior change in any function local cache code depends on is treated as a
  semantic conflict even if the build passes.

## Rework routing

If an upstream commit invalidates a closed-stage contract, the affected stage
gets one rework part file in that stage's design tree. The part cites the
upstream SHA, the broken contract, the required correction, and the evidence
needed to close it. Multiple upstream commits that break the same stage
contract should share one rework unless they create independent gaps.

Rework cannot be hidden in the Stage 35 merge log alone. Durable behavior
changes must land in the owning stage design or architecture document. QA does
not start the Stage 35 regression rerun while any required rework is open.

## Regression and closure evidence

Minimum no-rework evidence:

- clean build evidence with build directory, configuration, target set, command,
  and timestamp
- focused `ctest` cache regression output and raw log path
- public HTTP probes for touched route families
- public `/metrics` shape check: bounded labels, unique HELP/TYPE blocks, and
  relevant hybrid counters
- focused coverage report when feature-mode source files changed, using the
  combined result block for the combined threshold, product-only result block
  for product-only threshold, and per-file table for T115-style aggregation
- cold-store filesystem proof when cold-store or descriptor paths changed
- checkpoint/MTP public admission rows when checkpoint or speculative paths
  changed and a capable fixture is available
- Stage 34 replay or synthetic agentic rows when branch/session/replay,
  concurrent save/restore, or `tx_save` paths changed
- stale-ref check repeated at regression time

Expanded evidence is required for each closed rework and must be named in the
rework part file.

## Merge log and closure

The Developer merge log must record source ref, actual upstream tip, fork point,
final triage decisions, conflicts, semantic-conflict scans, reworks, deferred
commits, known gaps, regression evidence, staleness checks, and handoff state.
Architect reviews the merge log. Manager closes Stage 35 only after closure
evidence proves the preserved contracts or records accepted gaps with owners.

## Risks

| Risk | Mitigation |
| --- | --- |
| `origin/upstream_master` lags actual upstream `master` | Fresh `ls-remote` comparison before range and again at regression time; Manager decides gap handling. |
| Upstream refactor compiles but breaks local cache semantics | File-glob triage plus call-site grep and focused regression for touched contracts. |
| Metric or label rename breaks public evidence | Treat metric/field rename as Manager decision; preserve bounded public label shape unless rework approves a change. |
| Upstream changes legacy cache defaults | Upstream-first applies only when legacy behavior stays default-compatible and hybrid remains opt-in. |
| Concurrent save/restore changes reintroduce Stage 34 race defects | I-34-01/I-34-02 are explicit preservation contracts; Stage 34 rows rerun when touched. |
| Coverage report cites wrong denominator | Test report must cite markdown combined/product-only blocks, not XML root attributes. |

## Acceptance criteria

Stage 35 design can pass review when:

- source-ref policy, including staleness handling, is explicit
- prior-stage and architecture contracts are listed, including I-34-01 and I-34-02
- file-glob filters cover cache, context, branch, chat/template, MTP, HTTP,
  metrics, cold-store, checkpoint, test, and coverage surfaces
- pre-merge report sections and triage decisions are defined
- conflict, rework, regression, and merge-log policies point to durable docs
- merge execution remains blocked until pre-merge analysis review and Manager
  approval pass

## Handoff

Next owner: independent Architect review for parts 04-06, then Manager gate.

Next gate: rework design review / Manager rework gate.

Allowed next work: review and gate the three rework design parts.

Merge execution, regression reruns, commits, pushes, PRs, and reviewer
responses remain unauthorized until all three rework parts pass review and
Manager gate.
