# Stage 35 Manager pre-merge decisions 2026-07-07

## Inputs reviewed

- [Pre-merge analysis part 01](part-01-pre-merge-analysis-20260707.md)
- [Architect pre-merge analysis review part 02](part-02-pre-merge-analysis-review-20260707.md)
- [Stage 35 design](../cache-handling-phase35-design.md)
- [Manager design gate](../cache-handling-phase35-design/part-03-manager-design-gate-20260707.md)

## Decisions

D35-PREMERGE-01: Refresh the Stage 35 source ref and redo pre-merge analysis.
Actual upstream `master` advanced from `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`
to `108f186d1701d56133a0239dd6754c8814374cbf` during the first review. The
Manager chooses the refresh-and-redo path, not known-gap handling.

Refresh command used:

```text
git fetch https://github.com/ggml-org/llama.cpp.git master:refs/remotes/origin/upstream_master
```

Post-refresh check:

```text
git rev-parse origin/upstream_master
108f186d1701d56133a0239dd6754c8814374cbf

git ls-remote https://github.com/ggml-org/llama.cpp.git master
108f186d1701d56133a0239dd6754c8814374cbf refs/heads/master
```

D35-PREMERGE-02: Accept the dirty worktree only for planning-document work in
this Manager session. The dirty paths are Stage 35 docs and agent memory files
created or updated by the gate sessions. This exception does not authorize merge
execution.

D35-PREMERGE-03: Merge execution remains blocked until the worktree is clean by
the upstream merge guide standard. Because AGENTS.md forbids commits without
explicit human approval, the Manager must stop for approval before any commit
that would clean the Stage 35 planning docs, and must not start the merge while
these planning docs are uncommitted.

## Required correction

Developer must update the Stage 35 implementation entry and pre-merge analysis
for the refreshed `origin/upstream_master` tip, fix the REWORK count mismatch,
and keep merge execution unauthorized.

