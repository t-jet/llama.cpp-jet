# Stage 35 Manager pre-merge approval 2026-07-07

Verdict: PASS for pre-merge analysis; merge execution still blocked.

## Inputs reviewed

- [Stage 35 design](../cache-handling-phase35-design.md)
- [Manager design gate](../cache-handling-phase35-design/part-03-manager-design-gate-20260707.md)
- [Pre-merge analysis part 01](part-01-pre-merge-analysis-20260707.md)
- [Architect review part 02](part-02-pre-merge-analysis-review-20260707.md)
- [Manager pre-merge decisions part 03](part-03-manager-premerge-decisions-20260707.md)
- [Architect re-review part 04](part-04-pre-merge-analysis-re-review-20260707.md)

## Decision

D35-PREMERGE-04: The corrected pre-merge analysis is accepted for the current
source ref `origin/upstream_master` at
`108f186d1701d56133a0239dd6754c8814374cbf`.

D35-PREMERGE-05: The Stage 35 range is `HEAD..origin/upstream_master`, 308
commits total, 89 filtered commits, with final pre-merge decision counts:
13 NO-OP, 67 INTEGRATE, 9 REWORK-REQUIRED, 0 DEFER, 0 REVERT.

D35-PREMERGE-06: Keep all 9 REWORK-REQUIRED rows as rework-required before
merge execution. None are downgraded to INTEGRATE at this gate.

D35-PREMERGE-07: Group the 9 rows into three rework tracks:

| Track | Rows | Owning contract family |
| --- | --- | --- |
| MTP/KV/speculative | `88a39274ecf8`, `d789527482d9`, `d1b34251bc57`, `8c146a836630` | Stage 5 target/draft pairing, Stage 9 checkpoint/KV admission, Stage 25 transactions, architecture MTP/KV invariants |
| Route/session lifecycle | `4b4d13ae721e`, `2b686a9120e2`, `721354fbdfb7`, `1a87dcdc452d` | Stage 13 route compatibility, Stage 34 branch/session replay evidence, server lifecycle evidence |
| Checkpoint placement | `73618f27a801` | Stage 9 checkpoint placement and architecture part 9 chat-path prompt-span boundary |

D35-PREMERGE-08: Architect opens rework design parts before merge execution.
The parts may live in the Stage 35 design tree as cycle-level rework-routing
documents, but each part must name the affected closed-stage contract owner and
the durable stage or architecture document that needs follow-up if merge
analysis proves behavior must change.

D35-PREMERGE-09: Merge execution remains blocked until all three rework design
parts pass review and Manager gate, and until the worktree is clean enough for a
real merge under the upstream merge guide.

D35-PREMERGE-10: No commit is authorized by this decision. AGENTS.md still
requires explicit human approval before any commit, including a planning-doc
commit that would clean the worktree before merge execution.

## Handoff

Next owner: Architect.

Next gate: rework design for the three Stage 35 tracks.

Expected deliverables:

- MTP/KV/speculative rework design part.
- Route/session lifecycle rework design part.
- Checkpoint placement rework design part.
- Independent rework design review or reviews.

Merge execution, conflict resolution, production code changes, regression runs,
commits, pushes, PRs, and reviewer responses remain unauthorized.

