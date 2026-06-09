# Stage 9 implementation log: checkpoint integration and workload profiles

Status: CLOSED
Planning date: 2026-06-01
Design document: [cache-handling-phase9-design.md](cache-handling-phase9-design.md)
Architecture document: [cache-handling-architecture.md](cache-handling-architecture.md)
Requirements document: [cache-handling-requirements.md](cache-handling-requirements.md)

## Scope

This log records the Stage 9 implementation plan and future implementation
evidence for checkpoint payloads as branch-node payloads and workload-profile
aware restore planning.

Stage 9 implementation has correction passes after Architect review. Part 5
records the first code and test evidence. Part 6 records the first required
corrections. Part 7 records the first Developer rework. Part 8 records the
Architect re-review REWORK verdict. Part 9 records the cold-checkpoint restore
corrections and metric evidence added for that rework. Part 10 records the
Architect implementation re-review PASS. Part 11 reviews QA report
20260601-05 and records the test-results gate decision. Part 12 records the
Q112 re-materialization fix. Part 13 records the Architect bug-fix review PASS.
Part 14 reviews QA rerun report 20260601-06 and classifies the remaining
Q102/Q103 public evidence blockers as accepted limits. Part 15 records a
follow-up public probe that solves checkpoint admission with a test-side custom
chat template and narrows the remaining blocker to checkpoint state restore.
Part 16 records the product fix for checkpoint restore apply flags and restored
token accounting. Part 17 records the Architect bug-fix review PASS. Part 18
reviews QA report 20260602-01 and closes the public Q102/Q103 checkpoint
restore evidence. Part 19 records the Manager closure decision.
Part 20 records the 2026-06-09 degraded/non-native boundary fallback fix
found during Stage 12 B02.

## Contents

- [Part 1: Implementation plan](cache-handling-phase9-implementation/part-01-implementation-plan.md)
- [Part 2: Evidence plan and risks](cache-handling-phase9-implementation/part-02-evidence-plan-and-risks.md)
- [Part 3: Architect plan review gate](cache-handling-phase9-implementation/part-03-architect-plan-review-gate.md)
- [Part 4: Manager implementation-plan gate](cache-handling-phase9-implementation/part-04-manager-implementation-plan-gate.md)
- [Part 5: Implementation evidence 2026-06-01](cache-handling-phase9-implementation/part-05-implementation-evidence-20260601.md)
- [Part 6: Architect implementation review 2026-06-01](cache-handling-phase9-implementation/part-06-architect-implementation-review-20260601.md)
- [Part 7: Implementation review corrections 2026-06-01](cache-handling-phase9-implementation/part-07-implementation-review-corrections-20260601.md)
- [Part 8: Architect implementation re-review 2026-06-01](cache-handling-phase9-implementation/part-08-architect-implementation-re-review-20260601.md)
- [Part 9: Cold checkpoint restore corrections 2026-06-01](cache-handling-phase9-implementation/part-09-cold-checkpoint-restore-corrections-20260601.md)
- [Part 10: Architect implementation re-review 2026-06-01](cache-handling-phase9-implementation/part-10-architect-implementation-re-review-20260601.md)
- [Part 11: Test-results review 2026-06-01](cache-handling-phase9-implementation/part-11-test-results-review-20260601.md)
- [Part 12: Q112 re-materialization fix 2026-06-01](cache-handling-phase9-implementation/part-12-q112-rematerialization-fix-20260601.md)
- [Part 13: Q112 bug-fix review 2026-06-01](cache-handling-phase9-implementation/part-13-q112-bug-fix-review-20260601.md)
- [Part 14: Test-results rerun review 2026-06-01](cache-handling-phase9-implementation/part-14-test-results-review-rerun-20260601.md)
- [Part 15: Public checkpoint admission follow-up 2026-06-02](cache-handling-phase9-implementation/part-15-public-checkpoint-admission-follow-up-20260602.md)
- [Part 16: Public checkpoint restore fix 2026-06-02](cache-handling-phase9-implementation/part-16-public-checkpoint-restore-fix-20260602.md)
- [Part 17: Public checkpoint restore fix review 2026-06-02](cache-handling-phase9-implementation/part-17-public-checkpoint-restore-fix-review-20260602.md)
- [Part 18: Test-results review 2026-06-02](cache-handling-phase9-implementation/part-18-test-results-review-20260602.md)
- [Part 19: Manager closure decision 2026-06-02](cache-handling-phase9-implementation/part-19-manager-closure-decision-20260602.md)
- [Part 20: Degraded boundary fallback 2026-06-09](cache-handling-phase9-implementation/part-20-degraded-boundary-fallback-20260609.md)

## Current gate

The accepted design baseline is
[cache-handling-phase9-design.md](cache-handling-phase9-design.md), Parts 01
through 05. The independent design review is
[design-review-gate-01.md](cache-handling-phase9-design/design-review-gate-01.md),
verdict PASS with advisory findings 9-01 through 9-03.

The manager design gate is PASS in
[part-06-manager-design-gate.md](cache-handling-phase9-design/part-06-manager-design-gate.md).

Implementation planning is drafted in Part 1 and Part 2. The independent
Architect plan review is PASS in Part 3. The Manager implementation-plan gate
is PASS in Part 4. The first implementation review is REWORK in Part 6. The
first Developer correction pass is recorded in Part 7. The Architect re-review
is REWORK in Part 8. The S9-IMPL-06 and S9-IMPL-07 correction evidence is
recorded in Part 9. The Architect implementation re-review is PASS in Part 10.

## Advisory findings from design review

| ID | Finding | Plan resolution |
| --- | --- | --- |
| 9-01 | Runtime profile detection sources and unknown-mode tests need detail. | Part 1 names concrete runtime sources and negative tests. |
| 9-02 | Checkpoint admission transaction boundaries need detail. | Part 1 defines pre-attach validation, attach, rollback, and cleanup order. |
| 9-03 | Model-backed checkpoint evidence may need a fallback path. | Part 2 names the fixture search and focused substitute evidence path. |

## Stage gate

Status: Q112 bug fix implemented after QA report 20260601-05. Part 8 closed
S9-IMPL-01 through S9-IMPL-04, recorded partial coverage improvement for
S9-IMPL-05, and blocked QA planning on S9-IMPL-06. Part 9 records the
Developer fix for cold checkpoint descriptor selection and the added restore
metric evidence requested by S9-IMPL-07. Part 10 closes S9-IMPL-06 and
S9-IMPL-07 for implementation review.

Part 11 classifies Q112 as a product bug in Stage 8 target/draft
re-materialization under Stage 9 code. Q100 is blocked by that abort. Q103 and
Q102 are QA probe limitations because the public MTP run did not admit a
checkpoint before checking restore metrics. Q109 is an expected skip because a
fixture was available.

Part 12 records the Q112 product fix and focused evidence. Part 13 records the
Architect bug-fix review PASS.

Part 14 reviews QA rerun report 20260601-06. Q112 and Q100 are closed by rerun
evidence. Q102 and Q103 remain blocked only because the public MTP probe created
live context checkpoints but did not admit a checkpoint; admission failed with
missing matching checkpoint boundary metadata, so public checkpoint restore and
hit evidence could not be produced. Q109 remains an expected skip because a
fixture was available. No product bug remains from the rerun. Next owner is
Manager for Stage 9 closure policy.

Part 15 follows up on the Manager closure question. A test-side custom chat
template can align public prepared boundaries with the runtime checkpoint span
and produces checkpoint admission with the Qwen3.5 MTP fixture. The repeated
request then selects the checkpoint payload but fails target-state restore. The
gate is narrowed to Developer investigation of checkpoint restore apply flags
before QA rerun.

Part 16 implements that narrow restore fix. Hybrid checkpoint payload restore now
uses `LLAMA_STATE_SEQ_FLAGS_PARTIAL_ONLY`, matching live checkpoint export, and
restored prompt/cache accounting uses the checkpoint descriptor span instead of
the full cache entry length. Focused `test-cache-controller` evidence passes.
Part 17 records the Architect bug-fix review PASS.

Part 18 reviews QA report 20260602-01. The public custom-template MTP rerun
passes Q102 and Q103 with checkpoint admission, successful checkpoint restore,
checkpoint hit labels, and draft activity. Focused regression rows Q110-Q112
also pass. No Stage 9 product bug, QA harness blocker, environment blocker, or
accepted public-evidence limit remains open from the focused rerun. Next owner
is Manager for Stage 9 closure review or closure decision.

Part 19 records the Manager closure decision. Stage 9 is closed. Next owner is
Manager or user for the next stage intake.

Part 20 records a post-closure correction found by Stage 12 B02. Native
checkpoint boundary mismatches still reject admission. Non-native or degraded
metadata without a matching checkpoint span can use token-span checksum
fallback, and the final B02 V1 rerun records checkpoint admissions, hits, and
restores with zero admission failures.
