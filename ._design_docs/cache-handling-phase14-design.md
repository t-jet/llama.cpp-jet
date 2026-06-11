# Stage 14 design: post-Stage-12/13 upstream integration

Status: Design gate PASS, 2026-06-11
Date: 2026-06-11
Stage: 14 (Post-Stage-12/13 upstream integration)
Prerequisite Stages: 1-13 (CLOSED)

## Scope

Stage 14 re-syncs the fork with `upstream_master` after Stage 12 stress
validation and Stage 13 endpoint compatibility corrections are merged.
It is a second upstream merge cycle. The procedure is the
`upstream-merge-guide.md`; this design records the Stage 14 operational
contract: the prerequisite list, the prior-stage contracts the merge
must preserve (including the new Stage 12 and Stage 13 contracts), and
the rework workflow that opens a stage-N part file when an upstream
change invalidates a closed prior stage.

This design covers the Stage 14 operational contract only. It does not
approve implementation planning, code work, merge execution, test
execution, regression reruns, commits, PR text, or reviewer responses.

## Prerequisites

- Stage 1: Hybrid cache controller and non-destructive exact saves/loads (CLOSED)
- Stage 2: Compatibility namespace and task metadata transport (CLOSED)
- Stage 3: Exact blob cache and usage tracking (CLOSED)
- Stage 4: Byte-accounted hot payload LRU with protected roots (CLOSED)
- Stage 5: Payload descriptor separation and target/draft pairing (CLOSED)
- Stage 6: Cold payload storage and asynchronous I/O (CLOSED)
- Stage 7: Branch forest, namespace validation, slot references, metadata accounting, and global hot-payload LRU (CLOSED)
- Stage 8: Metadata-only nodes, re-materialization, mismatch handling, equivalent-branch deduplication, and cold cleanup safety (CLOSED)
- Stage 9: Checkpoint integration and workload profiles (CLOSED)
- Stage 10: Observability, security review, hardening, benchmarks, stress tests, deterministic testing, 80% hybrid path coverage, and operator documentation (CLOSED)
- Stage 11: Upstream merge integration (CLOSED; cap-fix cycle CLOSED 2026-06-07 on `0c3c5b240` with `6e3aa045c` and `02db7a768` recorded in the Stage 11 merge log; `test-stage10-policy-lru` pre-existing semantic bug is out of Stage 11 cap-fix scope and is not part of the Stage 14 prerequisite list)
- Stage 12: Stress testing and benchmarking (CLOSED 2026-06-07)
- Stage 13: Endpoint compatibility corrections (CLOSED 2026-06-10)

## Assumptions

- All prior stages 1-13 are closed with no open product bug, no
  outstanding QA harness blocker, no environment blocker, and no
  accepted public-evidence limit at the time the merge begins.
- The fork uses `origin/upstream_master` (a remote-tracking ref) as
  the merge source. The local default branch is the integration
  branch. The Developer verifies `origin/upstream_master` is current
  against the actual upstream `master` before opening the commit
  range. A stale `origin/upstream_master` ref is recorded as a known
  gap.
- The Developer is the owner of the merge command family, the
  rework Stage N workflow when a prior stage is invalidated, and
  the regression rerun.
- The Manager is the owner of the rework-trigger decision and the
  known-gap acceptance decision.
- The architecture scope and exit criteria for Stage 14 are fixed
  by the architecture and are not redefined in this design. The
  design records the operational contract that lets the merge and
  rework proceed.

## Manager decisions (recorded verbatim, not re-debated)

- D1 (2026-06-04, revised 2026-06-11): Upstream reference is the
  remote-tracking ref `origin/upstream_master`. The Developer
  operates against `origin/upstream_master` directly. No local
  `upstream_master` tracking branch is required. The remote ref
  was last fetched 2026-06-04 per the original D1 record. No
  `upstream` remote is required. The Developer verifies the
  remote ref tip is current against the actual upstream `master`
  via `git ls-remote https://github.com/ggml-org/llama.cpp.git master`
  (or the GitHub REST API endpoint) before the merge opens. A
  stale remote ref is a known gap recorded in the merge log, not
  a blocker that halts the cycle. The local-tracking-branch
  alternative documented in upstream-merge-guide.md remains
  available for future cycles if a later Manager decision revises
  this one.

## Non-goals

- Rewriting the architecture, the requirements, or the prior stage
  designs as part of the merge. A change to a prior-stage design is
  the affected stage's rework, not a Stage 14 design change.
- Changing the default cache path, the public CLI surface, or the
  public Prometheus metric set.
- Resolving conflicts by silently dropping upstream changes.
- Treating a failure to pass upstream tests as a Stage 14 closure
  contract on its own. Stage 14 closure is governed by the prior-stage
  contracts the architecture lists, not by upstream CI.
- Resuming the synthetic Stage 12 V2/V3/non-MTP matrix expansion
  during or before Stage 14. The 2026-06-09 close-at-current-progress
  decision remains in force.
- Fixing the `test-stage10-policy-lru` pre-existing semantic bug. It
  is out of Stage 14 scope and is tracked separately.

## Contents

- [Part 1: Scope, prerequisites, and upstream reference](cache-handling-phase14-design/part-01-scope-prerequisites-and-upstream-reference.md)
- [Part 2: Pre-merge analysis method and triage matrix](cache-handling-phase14-design/part-02-pre-merge-analysis.md)
- [Part 3: Merge execution plan and conflict resolution](cache-handling-phase14-design/part-03-merge-execution-plan.md)
- [Part 4: Rework assessment process](cache-handling-phase14-design/part-04-rework-assessment-process.md)
- [Part 5: Regression test reruns and evidence](cache-handling-phase14-design/part-05-regression-test-reruns-and-evidence.md)
- [Part 6: Merge log, constraints, observability, testability, and risks](cache-handling-phase14-design/part-06-merge-log-constraints-and-traceability.md)
- [Part 6a: Exclusions, requirement traceability, and handoff](cache-handling-phase14-design/part-06a-exclusions-traceability-and-handoff.md)
- [Part 7: Design review gate 01](cache-handling-phase14-design/part-07-design-review-gate-01.md)

Part 6 is split into Part 6 and Part 6a to keep each part file
under the 300-line cap. The split is mechanical, not a content
division.

## Current gate

Stage 14 design gate PASS, 2026-06-11. The independent design review
returned 0 BLOCKING, 3 non-blocking (N1, N2, N3), and 4 INFO findings.
The non-blocking findings (semantic-duplicate/divergent-fix-path
naming, upstream-merge-guide Part 4 label, CUDA fallback row
naming) are carry-forward observations for implementation planning
and are not rework. Implementation planning is the next gate; the
Developer is the next owner. The merge itself, regression reruns,
and QA execution remain closed until implementation planning passes.

## Stage gate

| Gate | Status |
| --- | --- |
| Stage 12 closure prerequisite | PASS, 2026-06-07 |
| Stage 13 closure prerequisite | PASS, 2026-06-10 |
| D1 upstream reference decision recorded | PASS, 2026-06-04 |
| Stage 14 design authoring | PASS, 2026-06-11 |
| Stage 14 independent design review | PASS, 2026-06-11 |
| Stage 14 manager design gate | PASS, 2026-06-11 |
| Stage 14 implementation planning | NOT STARTED |
| Stage 14 implementation | NOT STARTED |
| Stage 14 QA execution | NOT STARTED |

## Handoff

This design is the Stage 14 design deliverable. It is ready for
independent Architect design review and then Manager design-gate
review. The next gate after Manager approval is implementation
planning; the next owner is the Developer. Implementation work, the
merge itself, regression reruns, and QA execution are not authorized
by this design.
