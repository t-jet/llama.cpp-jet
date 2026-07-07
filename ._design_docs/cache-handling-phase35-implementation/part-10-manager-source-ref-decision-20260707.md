# Stage 35 Manager source-ref decision 2026-07-07

Verdict: REFRESH AND REDO PRE-MERGE ANALYSIS.

## Inputs

- [Implementation preflight](part-09-implementation-preflight-20260707.md)
- [Implementation plan](part-06-merge-rework-implementation-plan-20260707.md)
- [Manager implementation-plan gate](part-08-manager-implementation-plan-gate-20260707.md)
- [Stage 35 design](../cache-handling-phase35-design.md)

## Decision

Developer preflight stopped before merge because the live source-ref state no
longer matched the approved plan:

- accepted plan tip: `108f186d1701d56133a0239dd6754c8814374cbf`
- local `origin/upstream_master`: `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`
- actual upstream `master`: `6c487e2f79dea747d70325250121e750ed364b2b`

Manager selects refresh-and-redo. Pinning a known-gap path is rejected because
Stage 35 is an upstream merge cycle and the newer upstream commits have not
been triaged.

## Authorized next work

Developer may refresh the source ref against actual upstream `master` and redo
pre-merge analysis for the new range.

Allowed:

- fetch or otherwise refresh the chosen source ref to actual upstream `master`
- rerun source-ref, merge-base, count, filter, and per-commit triage checks
- write a replacement pre-merge analysis part and update entry/index docs

Still blocked:

- merge execution
- conflict resolution
- production code changes
- regression runs
- commits, pushes, PRs, and reviewer responses

The current dirty worktree contains only planning documents and agent memory
from the blocked preflight. Manager grants the same planning-only dirty-tree
exception used earlier. The real merge must still start from a clean tree after
the refreshed analysis passes review and Manager approval.

## Handoff

Next owner: Developer.

Next gate: refreshed pre-merge analysis, then Architect review.
