# Stage 35 Manager source-ref and partial-merge decision 2026-07-07

Verdict: REFRESH AND REDO FROM ACTUAL UPSTREAM MASTER.

## Inputs

- [Merge/rework implementation blocked](part-14-merge-rework-implementation-blocked-20260707.md)
- [Refreshed pre-merge approval](part-13-manager-refreshed-premerge-approval-20260707.md)
- [Implementation plan](part-06-merge-rework-implementation-plan-20260707.md)
- [Stage 35 design](../cache-handling-phase35-design.md)
- [Upstream merge guide, part 1](../upstream-merge-guide/part-01-procedure.md)

## Current source state

Local verification after part 14 found:

- `HEAD`: `429a4fbce248d6d586669e022f63c1e27cb64f29`
- `MERGE_HEAD`: `6c487e2f79dea747d70325250121e750ed364b2b`
- `origin/upstream_master`: `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`
- actual upstream `master`: `bec4772f6a2527d371557b5d2032641e5ff7619c`

The open merge state is not a completed integration. It has no merge commit,
and no regression gate passed after conflict resolution.

## Decision

| ID | Decision |
| --- | --- |
| D35-SOURCE-02 | Reject the pinned known-gap path for `MERGE_HEAD=6c487e2f79de`. Stage 35 is an upstream merge cycle, and two newer upstream tips have appeared since that merge was opened. |
| D35-SOURCE-03 | Refresh and redo pre-merge analysis against actual upstream `master` at `bec4772f6a2527d371557b5d2032641e5ff7619c`. |
| D35-SOURCE-04 | Close the current open no-commit merge state before redo. Developer may run `git merge --abort` because part 14 preserves the partial merge evidence and no merge commit exists. If abort fails, Developer stops and records the exact failure instead of using a reset. |
| D35-SOURCE-05 | The refreshed analysis must re-check the full source-ref state, range count, file-glob filter, per-commit triage, aggregate counts, and whether the already routed rework tracks need new rows. |

## Authorized next work

Developer may:

- verify no untracked user files would be lost by aborting the open merge
- abort the open no-commit merge
- refresh the chosen source ref to actual upstream `master`
- redo source-ref verification, range count, filter, and triage
- write the next refreshed pre-merge analysis part
- update the Stage 35 implementation entry and document index

Still blocked:

- merge execution
- conflict resolution for the new source tip
- production code changes
- regression runs
- commits, pushes, PRs, and reviewer responses

## Handoff

Next owner: Developer.

Next gate: refreshed pre-merge analysis, then Architect review.
