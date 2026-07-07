VERDICT: REWORK

# Stage 35 pre-merge analysis review 2026-07-07

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md) and [part 01](part-01-pre-merge-analysis-20260707.md)

## Scope

Review type: Architect implementation-planning gate review.

Subject reviewed:

- Stage 35 design entry and Manager design gate.
- Stage 35 implementation entry.
- Developer pre-merge analysis part 01.
- Upstream merge guide parts 01-04.

No merge, fetch, conflict resolution, code change, regression run, commit, push,
PR, or reviewer response was performed.

## Evidence checked

| Check | Review evidence | Result |
| --- | --- | --- |
| Local source ref | `git rev-parse origin/upstream_master` -> `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` | Matches part 01 |
| Local source tip log | `git log -1 --format="%H %ai %s" origin/upstream_master` -> `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe 2026-07-07 16:07:46 +0800 [SYCL] support op col2im_1d (#25264)` | Matches part 01 |
| Merge base | `git merge-base HEAD origin/upstream_master` -> `18ef86ecec723361362a332a79b4d913fd724d40` | Matches part 01 |
| Total range count | `git rev-list --count HEAD..origin/upstream_master` -> `307` | Matches part 01 |
| Filtered table count | Parsed per-commit table rows -> `89` | Matches part 01 |
| Aggregate counts | Parsed decisions -> `NO-OP=13`, `INTEGRATE=67`, `REWORK-REQUIRED=9` | Matches part 01 |
| Actual upstream master | `git ls-remote https://github.com/ggml-org/llama.cpp.git master` -> `108f186d1701d56133a0239dd6754c8814374cbf` | Does not match part 01 |

## Gate checklist

| Required item | Status | Notes |
| --- | --- | --- |
| Required sections present | PASS | Metadata, upstream verification, commit range, triage table, aggregate summary, expected files, Manager decisions, and open questions are present. |
| Command evidence present | REWORK | Evidence is present, but the upstream remote tip is now different from the recorded source ref. |
| Staleness verdict | REWORK | Part 01 says current; review evidence shows `origin/upstream_master` is behind actual upstream `master`. |
| Commit range and counts | PASS | Local range count is 307. Parsed table count is 89. |
| Filtered commit table | PASS | Each parsed commit row has one decision and a reason/owner cell. |
| Aggregate counts | PASS | Table aggregate matches parsed decisions: 13 + 67 + 9 = 89. |
| Triage decisions | PASS-WITH-REVIEW-RISK | Reasons generally cite contracts, surfaces, paths, or evidence areas. Rework grouping still needs Manager decision. |
| Manager decisions requested | PASS | Dirty worktree, rework threshold, router/SSE, checkpoint placement, and MTP/KV scope are requested. |
| Open questions | PASS | Four open questions are recorded and map to touched surfaces. |
| Doc consistency | REWORK | Implementation entry says 6 REWORK candidates while part 01 says 9. |
| Merge authorization | PASS | Both entry and part 01 keep merge execution unauthorized. |

## Findings

### F35-PLAN-01: upstream staleness verdict is no longer true

Severity: BLOCKING

The Stage 35 design requires Developer to compare `origin/upstream_master`
against actual upstream `master`; if the ref is stale, Developer stops before
commit triage and asks Manager to choose refresh or known-gap handling. Guide
part 1 section 2 and part 4 section 7 say the same for the direct
remote-tracking ref path.

Part 01 records `origin/upstream_master` and actual upstream `master` as
`47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`. Review-time `ls-remote` returned
`108f186d1701d56133a0239dd6754c8814374cbf` for actual upstream `master`.

Impact: the 307-commit range and 89-row triage table are no longer complete for
the current upstream tip. The implementation-planning gate cannot pass on a
stale range.

Required correction:

- Stop merge execution.
- Ask Manager to choose refresh-and-redo or known-gap handling for the missing
  upstream commits.
- If Manager chooses refresh, rerun the pre-merge analysis and send it back for
  Architect review.
- If Manager chooses known-gap handling, record the missing upstream SHAs,
  subjects, and filter matches before the gate can proceed.

### F35-PLAN-02: implementation entry contradicts the reviewed part on rework count

Severity: BLOCKING

The implementation entry requests Manager confirmation for "the 6
REWORK-REQUIRED candidates." Part 01 records 9 REWORK-REQUIRED rows, and the
aggregate table also says 9. The parsed triage table confirms 9.

This contradicts the Stage 35 design's requirement for aggregate counts and
Manager decisions requested. It also risks Manager approval on the wrong rework
threshold.

Required correction:

- Update the implementation entry and any handoff text so the rework count is
  consistent with the reviewed triage table, or rewrite the triage table and
  aggregate summary if 6 was intended.
- Keep the Manager decision request aligned with the corrected count.

### F35-PLAN-03: dirty worktree exception remains unresolved

Severity: BLOCKING FOR MANAGER APPROVAL

Part 01 records a dirty worktree at analysis open. Stage 35 design says dirty
state blocks the cycle unless Manager records an exception. Upstream merge
guide part 4 section 11 says uncommitted edits at cycle open are a blocker.

The report correctly asks Manager to decide this, but the gate cannot be
approved until Manager records the exception or requires cleanup before merge
execution.

Required correction:

- Manager records an explicit planning-only dirty-worktree exception, or
  Developer repeats the analysis from an acceptable clean state.
- No merge execution starts while this remains open.

## Non-blocking observations

- The filtered count, aggregate count, and per-row decision count are internally
  consistent inside part 01.
- The per-commit reasons are terse, but most cite a protected contract, route,
  metric, prompt, MTP/KV, checkpoint, or test surface instead of only repeating
  the subject.
- The report does not execute the merge or authorize regression work.

## Decision

Implementation-planning gate state: REWORK.

Next owner: Manager for staleness and dirty-worktree decisions, then Developer
for corrected pre-merge analysis or known-gap update.

Next Architect action: re-review after the corrected analysis and implementation
entry agree on staleness, range, counts, and Manager decision requests.
