# Stage 35 Manager rework gate 2026-07-07

## Inputs reviewed

- [Stage 35 design](../cache-handling-phase35-design.md)
- [Manager pre-merge approval](../cache-handling-phase35-implementation/part-05-manager-premerge-approval-20260707.md)
- [MTP/KV/speculative rework design](part-04-rework-mtp-kv-speculative-20260707.md)
- [Route/session lifecycle rework design](part-05-rework-route-session-lifecycle-20260707.md)
- [Checkpoint placement rework design](part-06-rework-checkpoint-placement-20260707.md)
- [Rework design review](part-07-rework-design-review-20260707.md)

## Decision

D35-REWORK-GATE-01: Accept the rework design review PASS. Parts 04-06 have
0 open review findings and satisfy the Manager-approved routing from
D35-PREMERGE-07.

D35-REWORK-GATE-02: Keep all 9 upstream rows in rework scope. None are
downgraded to normal INTEGRATE before Developer performs the required
per-track analysis.

D35-REWORK-GATE-03: Developer implementation planning is opened for the Stage
35 merge/rework execution plan. The plan must cover:

- per-track analysis required by parts 04-06 before any merge command;
- merge sequencing and conflict policy from the upstream merge guide;
- dirty-worktree cleanup gate and the AGENTS.md commit-approval rule;
- expected source files and semantic conflict scans from pre-merge analysis;
- test, regression, and evidence mapping for all three rework tracks;
- durable doc update triggers if merge analysis changes behavior.

D35-REWORK-GATE-04: Merge execution remains blocked. The next Developer
deliverable is an implementation plan only. The Developer must not run
`git merge`, conflict resolution, production code changes, regression runs,
commits, pushes, PRs, or reviewer responses in the planning session.

D35-REWORK-GATE-05: The dirty worktree remains acceptable only for planning
docs. A real merge still requires a clean-enough worktree under the upstream
merge guide and explicit human approval before any commit that would clean the
planning docs.

## Handoff

Next owner: Developer.

Next gate: implementation planning.

Expected deliverable:

- Stage 35 implementation plan in the implementation tree, covering the three
  accepted rework tracks and the remaining 67 INTEGRATE rows.

Merge execution, conflict resolution, production code changes, regression
runs, commits, pushes, PRs, and reviewer responses remain unauthorized.
