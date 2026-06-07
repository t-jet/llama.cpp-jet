# Part 1: Procedure, prerequisites, and gates

Source: [../upstream-merge-guide.md](../upstream-merge-guide.md)

## 1. Prerequisites

The merge activity is gated on the prerequisites below. A prerequisite that is not met is a blocker, not a skip.

| Prerequisite | Owner | Status | Notes |
| --- | --- | --- | --- |
| Prior stage closure on disk with no open product bug, QA harness blocker, environment blocker, or accepted public-evidence limit | Manager | must be PASS at cycle open | The closure record is in the prior stage's implementation log. A prior stage that closed with a known gap remains closed; the known gap is a follow-up owner in the merge log, not a rework trigger. |
| Affected stage's design on disk and indexed in `document-index.md` | Architect | must exist | The affected stage's design names the prior-stage contracts the merge must preserve. A new feature added in this fork that has no design is opened through the standard stage intake before the merge cycle. |
| Upstream tracking branch current against the upstream remote | Developer | must be PASS at cycle open | The Developer runs the staleness check in section 2. A stale tracking branch is either fast-forwarded first, or merged with the gap and re-synced after. The choice is a Manager decision recorded in the merge log. |
| Host tooling and credentials | Developer | must be PASS at cycle open | Git on `PATH` with merge support, the upstream remote configured with read access, the local default branch at a clean tree, push access to the local default branch, and the local build/test/coverage/benchmark scripts available. |
| Any test plan or coverage script change required by the cycle's closure contracts | Developer | must be PASS at cycle open | The closure contracts are listed in part 3. A coverage script that does not emit the row the closure contract requires is a blocker, not a fallback. The Developer makes the change as a separate Developer gate before step 1 opens. |

## 2. Upstream reference verification

The Developer runs the verification commands below before opening the commit range. The commands and outputs are recorded in the pre-merge report "Upstream reference verification" section.

| Check | Command | Expected result |
| --- | --- | --- |
| Tracking branch tip | `git rev-parse TRACK` | A 40-char SHA. |
| Tracking branch tip subject and date | `git log -1 --format='%H %ai %s' TRACK` | Subject and date match the upstream remote's tip. |
| Merge base | `git merge-base LOCAL TRACK` | A 40-char SHA. The merge base is the fork point the commit range starts from. |
| Commit count in range | `git log --oneline LOCAL..TRACK` followed by `wc -l` | A non-negative integer. The cycle's range size. |
| Upstream remote tip | The upstream remote REST API or `git ls-remote REMOTE_URL REF` | A SHA the tracking branch is compared against. |
| Staleness | compare tracking tip to upstream remote tip | `ahead` (tracking ahead, no gap), `behind` (tracking behind, gap exists), or `diverged` (both have unique commits). |
| Remote configuration | `git remote -v` | The upstream remote is configured with read access. The fork's local credentials allow push to the local default branch. |

A tracking branch that lags behind the upstream remote by more commits than the local convention tolerates is a known gap. The Manager decides whether to fast-forward the tracking branch first or merge with the gap and re-sync after. The choice is recorded in the merge log "Decisions" section.

A change to the fork point after the pre-merge analysis closes reopens the pre-merge analysis. The Developer does not start the merge with a stale fork point.

## 3. Commit-set selection

The pre-merge analysis covers a defined subset of upstream commits. The selection rule is deterministic so the same upstream state always produces the same commit set.

1. Start with the upstream commits reachable from the tracking branch tip but not from the local fork point. This is the natural commit range for the merge.
2. Filter the range to commits whose change set touches at least one of the file-glob groups in the affected stage's design, or whose commit message references a relevant subsystem even when the path filter does not match.
3. Exclude commits that touch only tests, documentation, build, or CI configuration for the affected file-glob groups, unless the commit also changes a runtime path any prior-stage contract governs.
4. Exclude merge commits and pure version bumps unless they affect a runtime path any prior-stage contract governs.
5. Record the resulting commit set in the pre-merge report "Commit range" section before the triage starts.

The file-glob groups are stage-specific. The Architect reviews the groups at design time. A new file-glob group the Architect adds during the cycle is recorded in the pre-merge report "Open questions" section and is approved by the Manager.

## 4. Triage matrix

Each in-scope commit receives exactly one triage decision. The Developer assigns the decision. The Architect reviews the assignments. The Manager is the only agent who can change a NO-OP, INTEGRATE, or DEFER decision into a REWORK-REQUIRED decision.

| Decision | Merge action | Rework path |
| --- | --- | --- |
| NO-OP | Integrate the upstream commit on the integration branch without further action. Record a one-line reason that cites the prior-stage contract it leaves untouched. | None. |
| INTEGRATE | Integrate the upstream commit and apply any local adjustment needed to keep the prior-stage contracts intact. Record the adjustment and the contract it preserves. | None, unless the integration surfaces a contract gap the Manager escalates to a rework. |
| REWORK-REQUIRED | Do not integrate the upstream commit as-is. Open a rework for the affected prior stage, apply the rework through the standard stage workflow, then integrate the upstream commit on the integrated tree. | Stage N rework (Design, Implementation, Test, Closure). The rework is recorded in the affected stage's design and implementation logs. |
| DEFER | Skip the upstream commit for this cycle. Record the reason, the impact, and the conditions that would lift the deferral. | None. The deferred commits appear in the merge log and may be revisited in a later cycle. |
| REVERT | Integrate the upstream commit, then revert it on the integration branch because the commit breaks a prior-stage contract and a working local fix is already in place. Record the local fix and the contract it preserves. | None for the revert. The local fix carries its own review and evidence in the stage that owns it. |

A commit may move between decisions as the merge progresses. The merge log records the final decision, not the original assignment, with the date when the decision changed.

A triage reason cites the prior-stage contract the upstream commit leaves untouched, modifies, or breaks. Reasons that only restate the commit subject are not acceptable. A reason that does not name a contract, a path, or a test surface fails the Architect review and is sent back to the Developer for a rewrite.

## 5. Pre-merge analysis artifact

The pre-merge analysis is a durable artifact. The Developer owns the artifact. The Architect reviews it. The artifact is a separate pre-merge report, not a part file of this guide. The guide prescribes the required sections; the report's exact layout is the Developer's choice.

Required sections:

- Cover and metadata: upstream remote name, upstream tracking ref, fork point SHA, integration branch name, date the analysis opened, date the analysis closed, owner, reviewer, approver.
- Upstream reference verification: the commands and outputs from section 2.
- Commit range: the range expression, the total commit count, the filtered commit count after applying the file-glob filter, the date range.
- Per-commit triage table: upstream SHA, upstream commit subject, file-glob groups matched, affected prior-stage contracts, triage decision, one-line reason, follow-up owner for REWORK-REQUIRED, DEFER, or REVERT.
- Aggregate summary: counts of NO-OP, INTEGRATE, REWORK-REQUIRED, DEFER, and REVERT. The set of prior stages touched by at least one commit, with the count of reworks expected. The list of files in the local repo that the merge is expected to touch, derived from the per-commit triage table.
- Manager decisions requested: any decision the Architect cannot make, including fork point, rework threshold, known gap, mapping for a metric or field rename, extension of the upstream commit range, and any other open question.
- Open questions: any commit where the triage decision is uncertain, and any contract gap the analysis surfaced but did not close.

The Developer does not start the merge until the Architect records a review verdict on the pre-merge report. The pre-merge report is the handoff from pre-merge analysis to merge execution.

## 6. Merge execution

The merge is a single integration event. The Developer opens a working state, runs the merge, resolves conflicts, and verifies the merged tree before closing the integration branch.

Merge command family, in order:

1. Confirm the working tree is clean and the local default branch is checked out at the fork point.
2. Fetch the upstream ref and tags recorded in the pre-merge analysis.
3. Re-confirm the commit range against the fetched upstream ref. If the range changed since the pre-merge analysis, reopen the pre-merge analysis and stop. The Architect re-reviews the report before the merge restarts.
4. Run the merge into the local default branch. The merge tool choice is recorded in the merge log. A fast-forward is acceptable only when the pre-merge analysis lists no INTEGRATE or REWORK-REQUIRED decisions, because a fast-forward would skip the local adjustments those decisions require. A `--no-ff` merge commit is required otherwise. The merge is a real two-parent merge; the parent SHAs are verified with `git rev-list --parents -n 1 <merge-sha>`.
5. Resolve conflicts that the merge tool surfaces. The conflict resolution policy is in part 2.
6. Run the local build command family.
7. Run the local regression ctest command family.
8. Re-run the focused exporter coverage command family when the pre-merge analysis lists at least one REWORK-REQUIRED or INTEGRATE decision that touched a hybrid-mode or feature-mode source file.
9. Update the merge log with the merge command, the conflict list, the resolution list, the build result, the test result, and the date.

The Developer does not push the integration branch to a remote, open a PR, or close the cycle until step 9 is complete and the regression evidence in part 3 is on disk.

A failed merge is closed with a reverse merge, an explicit `git reset` to the fork point, or a new merge attempt from the fork point. The chosen approach is recorded in the merge log. History rewrites are not permitted.

## 7. Per-rework planning

For each REWORK-REQUIRED entry, the Architect opens a rework part file in the affected stage's design directory. The rework part file references the current design entry doc, the current implementation log entry doc, the prior-stage contract the rework preserves, the upstream change that triggered the rework, and the contract gap the rework must close.

The rework follows the standard stage workflow (Design, Implementation, Test, Closure) but is limited to the contract gap. A broader redesign opens as a new stage through the standard stage intake.

The Developer writes a rework implementation plan in the affected stage's implementation log. The rework plan follows the same shape as the original stage plan but its steps are limited to the contract gap the rework must close.

When more than one upstream change maps to the same prior stage, the Architect opens a single rework for that stage. The rework part file lists every upstream change in its scope, and the rework implementation plan addresses the combined contract gap. A second rework for the same stage opens only when a later cycle surfaces a new contract gap that the first rework did not close.

## 8. Regression test scope

QA re-runs the minimum regression scope for the no-rework case, narrowed to the test plan parts whose prior-stage contract touched a path the merge changed. The minimum scope per cycle is the test plan parts the prior-stage contracts name, plus the closure contracts from part 3.

For each closed rework, the regression scope is expanded by the rework part file's added evidence. The rework part file may add a focused test function, a focused exporter check, a public HTTP probe, or a coverage row that did not exist before.

QA does not start the regression rerun until every open rework for the cycle has closed. A rework that is still open at the time of the regression is a blocker for the regression rerun, not a known gap.

The Developer does not invent new evidence formats that the prior stages did not use. The cycle's evidence uses the same artifact shape as the prior stage evidence, with any coverage citation rules from part 3.

## 9. Merge log and cycle closure

The Developer writes the merge log with the required sections from part 2 of the affected stage's design. The Architect reviews the merge log. The Manager closes the cycle in the affected stage's implementation log.

The merge log records the final triage decision per in-scope commit, the conflict list with resolution policy applied, the deferred upstream commits, the known gaps, the reworks opened, the regression evidence with verdicts and citations, and the closure status with the architecture exit criteria the integration branch has met on the date the merge log was last updated.

The closure confirms the integration branch satisfies the architecture exit criteria and the prior-stage closure contracts. The next stage or the next cycle opens through the standard stage intake or the next cycle's prerequisite check.

## 10. Decision points

The Architect and the Manager make the decision points below. The Developer records the decisions in the merge log.

- Stale tracking branch: fast-forward first, or merge with the gap and re-sync after. Manager.
- Rework trigger: change a NO-OP, INTEGRATE, or DEFER into REWORK-REQUIRED. Manager.
- Known gap with follow-up plan: a DEFER decision is acceptable when the gap does not weaken a prior-stage contract. Manager.
- Metric or field rename: rework, known gap with a documented mapping, or silent integration. Manager.
- Coverage drop below the closure contract floor: rework, known gap, or follow-up plan. Manager.

The Architect does not have authority to make any of the above decisions alone. The Developer does not have authority to make any of the above decisions alone. The decisions are recorded in the merge log "Decisions" section with the date, the agent, and the prior-stage contract the decision protects.
