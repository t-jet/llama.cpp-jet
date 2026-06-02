# Stage 9 manager test-plan gate - 2026-06-01

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

Reviewer: Manager agent
Verdict: ACCEPT TEST PLAN

## Review evidence

The independent QA test-plan review is recorded in
[stage-9-test-plan-review-20260601.md](stage-9-test-plan-review-20260601.md),
verdict PASS. No blocking findings were raised.

## Manager gate checks

| Check | Result | Notes |
| --- | --- | --- |
| Implemented scope is current | PASS | Part 11 follows the accepted Stage 9 implementation re-review PASS and carries the model-backed evidence limit forward. |
| Positive and negative coverage is explicit | PASS | Q90-Q112 cover workload profiles, checkpoint admission, restore ranking, boundary validation, cold promotion, budget behavior, metrics, fixture handling, and Stage 4-8 regression. |
| Evidence sources are mapped | PASS | Focused controller, metrics, branch graph, Stage 8, public HTTP, and model-backed fixture evidence are separated by row capability. |
| Clean-build rules are explicit | PASS | Part 11 requires a fresh build of `llama-server`, `test-cache-controller`, `test-step10-metrics`, `test-step12-branch-graph`, and `test-step13-stage8`. |
| Report rules are explicit | PASS | Execution evidence must go in a fresh `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` file. |
| Known limits are not hidden | PASS | Q103 and public `/metrics` rows are fixture-dependent. Substitute focused evidence is allowed only when the fixture is unavailable and the report states that clearly. |

## Decision

The Stage 9 test plan is accepted. QA execution is open.

## Handoff

Next gate: Test execution (QA).

QA must run the Stage 9 suite from a clean build and produce a fresh full test
report. The report must state whether a checkpoint-dependent model fixture was
available for Q103 and must not mark Q103 `PASS` without model-backed evidence.
