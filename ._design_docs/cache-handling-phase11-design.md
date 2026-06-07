# Stage 11 design: upstream merge integration

Status: Design authoring in progress
Date: 2026-06-04
Stage: 11 (Upstream merge integration)
Prerequisite Stage: 10 (Observability, security review, and hardening) -- CLOSED

## Scope

Stage 11 re-syncs the fork with `upstream_master` and reworks prior stages when
upstream cache, checkpoint, or speculative decoding changes invalidate them.
The architecture defines the scope as a fixed set of deliverables and exit
criteria; this design records how the merge and rework activity will be
planned, executed, and audited.

This design covers the Stage 11 operational contract only. It does not
approve implementation planning, code work, merge execution, test execution,
commits, PR text, or reviewer responses.

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

## Assumptions

- Stage 10 closure leaves no open product bug, QA harness blocker, environment blocker, or accepted public-evidence limit at the time the merge begins.
- The fork tracks `upstream_master` as the merge source and the local default branch as the integration branch.
- The Developer is the owner of the merge command family, the rework Stage N workflow when a prior stage is invalidated, and the regression rerun.
- The Manager is the owner of the rework-trigger decision and the known-gap acceptance decision.

## Non-goals

- Rewriting the architecture, the requirements, or the prior stage designs
- Changing the default cache path
- Adding a new CLI flag, public metric, or operator surface that was not already approved in a prior stage design
- Resolving conflicts by silently dropping upstream changes
- Replacing local fork tests with upstream tests without an Architect review of the replacement
- Treating a failure to pass upstream tests as a Stage 11 closure contract on its own; Stage 11 closure is governed by the prior-stage contracts the architecture lists, not by upstream CI

## Contents

- [Part 1: Scope, prerequisites, and upstream reference](cache-handling-phase11-design/part-01-scope-prerequisites-and-upstream-reference.md)
- [Part 2: Pre-merge analysis method and triage matrix](cache-handling-phase11-design/part-02-pre-merge-analysis.md)
- [Part 3: Merge execution plan and conflict resolution](cache-handling-phase11-design/part-03-merge-execution-plan.md)
- [Part 4: Rework assessment process](cache-handling-phase11-design/part-04-rework-assessment-process.md)
- [Part 5: Regression test reruns and evidence](cache-handling-phase11-design/part-05-regression-test-reruns-and-evidence.md)
- [Part 6: Merge log, constraints, observability, testability, risks, exclusions, traceability, and handoff](cache-handling-phase11-design/part-06-merge-log-constraints-and-traceability.md)
- [Part 7: Design review gate 01](cache-handling-phase11-design/part-07-design-review-gate-01.md)
- [Part 8: Speculative decode-batch sizing under the upstream `n_outputs_max` cap (post-closure follow-up)](cache-handling-phase11-design/part-08-n-outputs-max-cap-followup.md)

## Post-closure follow-up

Part 8 is a follow-up design correction recorded after the Stage 11
design gate closed. The Stage 11 implementation log carries the
investigation of the MTP draft-context server crash on
`cache-optimization-caveman` HEAD `02db7a768` in
[cache-handling-phase11-implementation/part-19-stage11-mtp-crash-investigation.md](cache-handling-phase11-implementation/part-19-stage11-mtp-crash-investigation.md).
Part 8 records the design correction. The architecture-level invariant
the correction implements is in
[cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md](cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md).
Part 8 does not reopen the Stage 11 design gate. It opens a new
design review gate and a new Manager design gate, both scoped to the
follow-up correction only.

## Current gate

The Stage 10 closure record is the prerequisite baseline. Stage 11 design
authoring is in progress; the independent design review and Manager design
gate are not started. Implementation planning, implementation, and QA
execution remain closed. The post-closure follow-up (Part 8) is the
new follow-up design deliverable. Its independent design review and
Manager design gate are not started.

## Advisory findings from design review

| ID | Finding | Plan resolution |
| --- | --- | --- |
| -- | -- | -- |

## Stage gate

| Gate | Status |
| --- | --- |
| Stage 10 closure prerequisite | PASS |
| Stage 11 design authoring | IN PROGRESS |
| Stage 11 independent design review | NOT STARTED |
| Stage 11 manager design gate | NOT STARTED |
| Stage 11 implementation planning | NOT STARTED |
| Stage 11 implementation | NOT STARTED |
| Stage 11 QA execution | NOT STARTED |

## Handoff

This design is the Stage 11 design deliverable. It is ready for independent
Architect design review and then Manager design-gate review. The next gate
after Manager approval is implementation planning; the next owner is the
Developer. Implementation work, the merge itself, regression reruns, and
QA execution are not authorized by this design.
