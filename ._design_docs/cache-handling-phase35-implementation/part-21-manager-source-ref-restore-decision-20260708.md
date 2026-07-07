# Stage 35 Manager source-ref correction 2026-07-08

Verdict: PASS. Restart merge execution against `upstream_master`.

## User correction

The user corrected the source branch:

```text
upstream not in the master branch, it's in the upstream_master
```

This supersedes the earlier GitHub-`master` source comparison used in parts 16
through 20. Stage 35 must use `origin/upstream_master`.

## Actions

- Aborted the wrong-source no-commit merge against
  `MERGE_HEAD=bec4772f6a2527d371557b5d2032641e5ff7619c`.
- Force-refreshed `origin/upstream_master` from the `upstream_master` branch:

```text
git fetch origin +upstream_master:refs/remotes/origin/upstream_master
```

## Evidence

| Check | Result |
| --- | --- |
| Remote source branch | `git ls-remote origin refs/heads/upstream_master` -> `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Local source ref | `git rev-parse origin/upstream_master` -> `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Merge state | `MERGE_HEAD` absent after abort. |

## Decision

| ID | Decision |
| --- | --- |
| D35-SOURCE-06 | Treat the part 20 merge as wrong-source evidence only. It does not close the implementation gate. |
| D35-SOURCE-07 | Use `origin/upstream_master=47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` as the Stage 35 source ref. |
| D35-SOURCE-08 | Developer must restart merge/rework implementation execution from a clean tree against `origin/upstream_master`. |
| D35-SOURCE-09 | Commits, pushes, PRs, and reviewer responses remain blocked unless separately requested. |

## Handoff

Next owner: Developer.

Next gate: restart merge/rework implementation execution against
`origin/upstream_master`.
