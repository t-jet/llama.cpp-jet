# Stage 11 design: pre-merge analysis method and triage matrix -- Part 2

Source: [../cache-handling-phase11-design.md](../cache-handling-phase11-design.md)

## Goal

The pre-merge analysis is a written audit of every upstream commit in the
merge range that could touch the hybrid cache, checkpoint, speculative
decoding, server context, slot, or HTTP layers. The audit produces a
triage decision for each commit and a list of follow-up items the merge
must complete before the integration branch can pass Stage 11 closure.

## Commit-set selection rule

The pre-merge analysis covers a defined subset of upstream commits. The
selection rule is deterministic so the same upstream state always produces
the same commit set.

1. Start with the upstream commits that are reachable from the upstream
   `master` tip but not from the local fork point. This is the natural
   commit range for the merge.
2. Filter the range to commits whose change set touches at least one of
   the file-glob groups listed below. A commit is in scope if any of its
   changed paths matches a glob in any group, or if its commit message
   references a relevant subsystem even when the path filter does not
   match.
3. Exclude commits that touch only tests, documentation, build, or CI
   configuration for the affected file-glob groups, unless the commit
   also changes a runtime path that any prior-stage contract governs.
4. Exclude merge commits and pure version bumps unless they affect a
   runtime path that any prior-stage contract governs.
5. Record the resulting commit set in the pre-merge report before the
   triage starts.

### File-glob groups for scope selection

| Group | Glob pattern | Why the group matters |
| --- | --- | --- |
| Cache controller and modes | `tools/server/server-cache-*` and `tools/server/server-prompt-cache.*` | Direct hybrid controller code and legacy adapter code. |
| Cache policy | `tools/server/server-cache-policy-*` | Hot payload LRU and protected-root behavior. |
| Cold store | `tools/server/server-cache-store-*` | Cold store integrity, root containment, and async I/O. |
| Branch graph | `tools/server/server-cache-graph.*` and `tools/server/server-cache-io-worker.*` | Shared branch forest, lookup, traversal, and worker behavior. |
| Speculative decoding | `common/speculative.*`, `common/sampling-ext.*`, `tools/server/server-speculative.*` | Runtime shape that drives pair state and namespace identity. |
| Server context and slot | `tools/server/server-context.*`, `tools/server/server-slot.*`, `tools/server/server-task.*`, `tools/server/server-queue.*`, `tools/server/server-chunk.*` | Mode dispatch, slot lifecycle, task transport, queueing, and chunked prompt handling. |
| HTTP and routes | `tools/server/server-routes.*`, `tools/server/server-utils.*`, `tools/server/server-http.*` | Request marker validation, route-level sanitization, and public metrics endpoint. |
| Metrics and observability | `tools/server/server-common.*`, `tools/server/server-httplog.*` | Public Prometheus endpoint, structured logs, and any cache counter wiring. |
| Common argument parsing | `common/arg.*`, `common/common.*` | CLI flags, draft model wiring, and MTP context wiring. |
| Sampling and grammar | `common/sampling.*`, `common/grammar-parser.*` | Only when the commit also changes a path the cache layer reads from. |

A commit that matches a glob group in the file list of the commit but
whose change set is limited to whitespace, comments, or generated code is
still in scope. The triage decides whether the change has runtime impact.
A commit that does not match a glob group is out of scope and does not
need a triage row.

## Triage matrix

Each in-scope commit receives exactly one triage decision. The matrix
below names the decision, the merge action, and the rework path it implies.

| Decision | Merge action | Rework path |
| --- | --- | --- |
| NO-OP | Integrate the upstream commit on the integration branch without further action. Record a one-line reason that cites the prior-stage contract it leaves untouched. | None. |
| INTEGRATE | Integrate the upstream commit and apply any local adjustment needed to keep the prior-stage contracts intact. Record the adjustment and the contract it preserves. | None, unless the integration surfaces a contract gap that the Manager escalates to a rework. |
| REWORK-REQUIRED | Do not integrate the upstream commit as-is. Open a Stage N rework for the affected prior stage, apply the rework through the standard stage workflow, then integrate the upstream commit on the integrated tree. | Stage N rework (Design, Implementation, Test, Closure). The rework is recorded in the affected stage's implementation log. |
| DEFER | Skip the upstream commit for this Stage 11 cycle. Record the reason, the impact, and the conditions that would lift the deferral. | None. The deferred commits appear in the merge log and may be revisited in a later Stage 11 cycle. |
| REVERT | Integrate the upstream commit, then revert it on the integration branch because the commit breaks a prior-stage contract and a working local fix is already in place. Record the local fix and the contract it preserves. | None for the revert. The local fix carries its own review and evidence in the stage that owns it. |

The Developer assigns the decision. The Architect reviews the assignments
in the pre-merge report. The Manager is the only agent who can change a
NO-OP, INTEGRATE, or DEFER decision into a REWORK-REQUIRED decision.

A commit may move between decisions as the merge progresses. The merge log
records the final decision, not the original assignment, with the date
when the decision changed.

## Pre-merge analysis artifact format

The pre-merge analysis is a durable artifact. The Developer owns the
artifact and the Architect reviews it. The artifact is a separate
pre-merge report, not a part file of this design. The design does not
prescribe the report's exact layout; it prescribes the required sections
and the minimum content per section.

### Required sections

1. Cover and metadata
   - Upstream remote name, upstream ref, fork point SHA, and integration
     branch name
   - Date the analysis was opened and date it was closed
   - Owner (Developer) and reviewer (Architect)
2. Commit range
   - The range expression used to enumerate the commits
   - The total commit count in the range
   - The filtered commit count after applying the file-glob filter
3. Per-commit triage table
   - Upstream SHA
   - Upstream commit subject
   - File-glob group(s) matched
   - Affected prior-stage contract(s) from Part 1
   - Triage decision
   - One-line reason
   - Follow-up owner when the decision is REWORK-REQUIRED, DEFER, or
     REVERT
4. Aggregate summary
   - Counts of NO-OP, INTEGRATE, REWORK-REQUIRED, DEFER, and REVERT
     decisions
   - The set of prior stages that are touched by at least one commit,
     with the count of reworks expected
   - The list of files in the local repo that the merge is expected to
     touch, derived from the per-commit triage table
5. Open questions
   - Any commit where the triage decision is uncertain and needs an
     Architect or Manager decision
   - Any contract gap the analysis surfaced but did not close

The Developer does not start the merge until the Architect records a
review verdict on the pre-merge report. The pre-merge report is the
handoff from pre-merge analysis to merge execution.

## Source of truth for triage reasons

A triage reason cites the prior-stage contract from Part 1 that the
upstream commit leaves untouched, modifies, or breaks. Reasons that
only restate the commit subject are not acceptable. A reason that does
not name a contract, a path, or a test surface fails the Architect
review and is sent back to the Developer for a rewrite.

The Architect may add a triage correction as a non-blocking observation
when the decision is right but the reason is weak. The Manager may
escalate a correction to a rework if the reason reveals a contract gap
the prior stage designs did not record.
