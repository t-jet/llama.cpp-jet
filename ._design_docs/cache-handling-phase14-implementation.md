# Stage 14 implementation log: post-Stage-12/13 upstream integration

Status: Implementation-plan gate PASS, 2026-06-11; Step 1 pre-merge analysis IN PROGRESS
Date: 2026-06-11
Stage: 14 (Post-Stage-12/13 upstream integration)
Prerequisite Stages: 1-13 (CLOSED)
Implementation state: not started
QA execution state: not started

## Design baseline

[cache-handling-phase14-design.md](cache-handling-phase14-design.md) (entry),
parts 01 through 07. Manager design gate PASS 2026-06-11.
Independent Architect design review PASS 2026-06-11 (0 BLOCKING,
3 non-blocking observations N1, N2, N3; 4 INFO notes). The three
non-blocking observations are advisory and are tracked in the
implementation log "Open Manager decisions" section.

## Architecture baseline

[cache-handling-architecture.md](cache-handling-architecture.md)
(Stage 14 section in Part 5, Stage 14 endpoint test coverage in
Part 8). The architecture defines Stage 14 scope and exit
criteria. The implementation does not redefine scope.

## Procedure baseline

[upstream-merge-guide.md](upstream-merge-guide.md) (entry), parts 01
through 04. The implementation plan references the guide for
procedure and does not duplicate it. Stage 11 implementation
log is the structural template for the pre-merge report, the
Architect pre-merge review, the merge log, and the test report.

## Manager plan-change decisions

- D1 (2026-06-04, revised 2026-06-11, carry-forward verbatim
  from design Part 1): upstream reference is the remote-
  tracking ref `origin/upstream_master`. The Developer
  operates against `origin/upstream_master` directly. No
  local `upstream_master` tracking branch is required. The
  remote ref was last fetched 2026-06-04 per the original
  D1 record. No `upstream` remote is required. The Developer
  verifies the remote ref tip is current against the actual
  upstream `master` via `git ls-remote
  https://github.com/ggml-org/llama.cpp.git master` (or the
  GitHub REST API endpoint) before the merge opens. A stale
  remote ref is a known gap recorded in the merge log, not
  a blocker that halts the cycle.

- D2 (carry-forward from design Part 1 non-goals): the
  `test-stage10-policy-lru` pre-existing semantic bug is out
  of Stage 14 scope. It is tracked separately. The merge does
  not require its fix and does not let the fix gate the cycle.

- D3 (carry-forward from design Part 1 non-goals): the
  2026-06-09 close-at-current-progress decision keeps the
  synthetic Stage 12 V2/V3/non-MTP matrix expansion paused.
  Lifting the pause requires a separate Manager decision
  outside the Stage 14 cycle.

## Manager decisions log

The Manager records per-decision outcomes here. The Developer
records the chosen path in the merge log "Cover and metadata"
section when Step 3 opens.

- (RESOLVED 2026-06-11) D4: the local `upstream_master`
  tracking branch is not required for Stage 14. The Manager
  selected Path C: the cycle operates against
  `origin/upstream_master` directly. No local branch is
  created. The Developer surfaces the remote ref tip and
  the gap to the actual upstream `master` in the pre-merge
  report "Upstream reference verification" section.

- (RESOLVED 2026-06-11) D5: worktree was dirty at cycle
  open. The Developer committed the working tree state with
  a single D5 commit before opening the pre-merge analysis,
  per the Manager record on 2026-06-11. The D5 commit SHA is
  `25d6a2a467da8a67953c45787eb89376c3e565cd`, short SHA
  `25d6a2a46`, subject `Stage 14 design + impl plan: Path C
  direct-ref upstream integration`. The commit bundles the
  Stage 14 design entry plus 8 parts, the Stage 14
  implementation entry plus 5 parts (including the new
  Architect plan-review gate-01 part-05), 3 self-improvement
  memory updates (architect, developer, manager), the
  `document-index.md` Stage 14 row, and the entry doc status
  line update. The part-05 architecture whitespace noise is
  included in the bundle. The D5 commit record is in the
  pre-merge report "D5 record" section. `git status --short`
  is empty after the D5 commit (clean tree).

- (RESOLVED 2026-06-11) D6: the `origin` remote URL is the local jet fork, not upstream `ggml-org/llama.cpp`. The gap between `origin/upstream_master` and the actual upstream `master` tip is 0 after the Step 1 fetch refresh. The Developer uses `origin/upstream_master` as the upstream reference per Path C; the gap is recorded as 0 in the pre-merge report D6 section.

- (RESOLVED 2026-06-11) D7: fork point SHA recovered via `git merge-base master origin/upstream_master` = `6ddc9430b145f61a0c1733b9d79c99c0ebdedf50`. Recorded in the pre-merge report cover section.

- (OPEN 2026-06-11) D12: D1 reference SHA `db94854ff56549f62b84d2f31608259a9e5e0e9f` (2026-06-04 historical anchor) is stale; current `origin/upstream_master` tip is `18ef86ecec723361362a332a79b4d913fd724d40` (refreshed 2026-06-11). D6 gap = 0 so the D1 SHA is informational only. Recommended default: leave D1 SHA as historical anchor; annotate the refresh in plan part-01 and part-04. Manager decides the doc correction path.

## Scope

Stage 14 re-syncs the fork with `origin/upstream_master`
after Stage 12 stress validation and Stage 13 endpoint
compatibility corrections are merged. It is a second upstream merge cycle.
The procedure is the upstream-merge-guide; this
implementation log records the Stage 14 ordered steps, the
evidence plan, the risks, the known decisions, and the
prerequisites. The plan is operational only.

This plan does not authorize code work, merge execution, test
execution, regression reruns, commits, PR text, or reviewer
responses.

## Carry-forward contracts from prior stages

The merge and any rework must keep every prior-stage contract
listed in design Part 1 intact. The Architect groups the
contracts into 36 rows including the post-Stage-11 Stage 12
and Stage 13 rows. The plan confirms and preserves every row.
A contract an upstream change would weaken is a rework
candidate, not a silent integration. The full per-row table
remains the authoritative source in the design Part 1.

The plan carries the post-Stage-11 contracts as closure
contracts:

- Public endpoint parity rows E13-01 through E13-16 PASS on
  the merged tree.
- MTMD placeholder path preserved.
- Diagnostic-source namespace isolation rule preserved.
- Bounded `cache metadata:` format at task launch preserved
  in `{source, method, degraded, tokens, boundaries}` shape.
- T114 combined coverage floor 0.80.
- T114a product-only coverage floor 0.70.
- T115 per-file aggregation rule.
- T121 public checkpoint admission row exposed.
- Stage 12 stress harness outputs S01..S08 and L01..L03.
- Stage 12 benchmark outputs B01..B08.

## Contents

- [Part 1: Implementation plan, ordered steps, and gates](cache-handling-phase14-implementation/part-01-implementation-plan.md)
- [Part 2: Evidence plan and risks](cache-handling-phase14-implementation/part-02-evidence-plan-and-risks.md)
- [Part 3: Known decisions for Manager](cache-handling-phase14-implementation/part-03-known-decisions.md)
- [Part 4: Prerequisites and host tooling](cache-handling-phase14-implementation/part-04-prerequisites.md)

Cycle-scoped test reports (pre-merge reports, test reports, fixes reports) under `._design_docs/.test_reports/` are exempt from the 300-line document size rule. These are one-shot artifacts anchored to a specific cycle date and are not durable design docs. The 300-line cap applies primarily to durable design docs, implementation logs, and test plans. This exception follows the Stage 11 precedent referenced in `upstream-merge-guide.md` Part 1.

## Current gate

Manager design-gate decision PASS 2026-06-11. Independent
Architect design review PASS 2026-06-11. Implementation
planning is the next gate. The next owner is the
Architect for implementation-plan review, then the Manager
for implementation-plan gate. The merge itself, the rework
Stage N work, the regression reruns, the merge log, the
test plan, the implementation review, the test report, and
the QA execution remain closed until the implementation-plan
review and the Manager implementation-plan gate both pass.

## Handoff

The Stage 14 implementation plan is on disk. The next owner
after Manager implementation-plan gate is the Developer, for
the pre-merge analysis (Step 1). The pre-merge analysis does
not start until the implementation-plan gate PASSES.
