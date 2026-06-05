---
name: developer
description: 'Plan and implement staged cache work in llama.cpp-jet. Use for implementation planning, code changes, unit test development, review fixes, bug fixing, and keeping implementation logs aligned with document-index.md.'
argument-hint: 'Stage, feature, or bug set to implement'
---

# Developer role

Use this skill when the task is to plan a stage implementation, apply code changes, add unit or regression tests, or fix bugs found by QA.

## Primary inputs

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-architecture.md`
- `._design_docs/cache-handling-requirements.md`
- Approved stage design document
- Current implementation log and review findings
- Test plan and latest relevant test report when the work is bug-driven

## Documentation contract

- Start implementation from the approved design and keep the implementation log current as work progresses.
- The implementation log must contain the plan, step-by-step progress, file references, change descriptions, and test evidence.
- After each planned step completes, update the implementation log before moving on.
- Add the implementation document to `document-index.md` if it is new, and keep its description current when the scope changes.
- For bug-fix work, use a fix report under `._design_docs/.test_reports/` to plan the work and capture evidence, then fold durable behavior changes back into persistent docs.

## Document naming and placement conventions

- Keep implementation logs under `._design_docs/` with entry names in the form `cache-handling-phaseN-implementation.md`.
- When the implementation log grows past 300 lines, keep the entry file as the overview and links page, create `._design_docs/cache-handling-phaseN-implementation/`, and continue with `part-XX-<slug>.md` files.
- Put implementation-step parts, review parts, corrective actions, production-fix parts, and verification summaries inside the stage implementation directory. Recent naming patterns include `part-01-implementation-plan.md`, `part-10-review-critical-gap-and-compliance.md`, `part-13-corrective-actions.md`, and `part-15-production-integration-fixes-part1.md`.
- Keep bug-fix working documents under `._design_docs/.test_reports/` beside the triggering test report, using the paired name `test-report-YYYYMMDD-NN-fixes.md`.
- In a `*-fixes.md` file, add planning, progress, review outcomes, implementation evidence, and retest evidence as new sections in the same file rather than scattering that history across extra documents.
- If a fix changes durable implementation behavior, update the stage implementation log and, when needed, the stage design docs so the persistent documents stay self-contained.
- When implementation docs or fix work create new durable documents or materially change existing ones, update `._design_docs/document-index.md`.

## Procedure

1. Read the stage design, architecture, requirements, previous review findings, and current implementation log.
2. Break the work into stage steps and write or update the implementation plan part before editing code.
3. Implement one step at a time. After each step, update the implementation log, list changed files, describe the behavior change, and capture build or test evidence.
4. Extend unit tests or focused regression tests with the code change. The recurring expectation from recent sessions has been at least 80 percent unit test coverage for the affected work.
5. Run the relevant builds and tests. Capture real evidence, not assumptions, in the implementation log or fix report.
6. If a review section or bug report already exists, turn it into a concrete corrective-action list, apply fixes, and document each completed action.
7. If QA failures come from test harness issues, update the test scripts, test plan, or README as needed, then rerun.
8. Before handoff, make sure code, tests, implementation docs, and the document index are all in sync.

## Decision points

- Missing or contradictory design is a blocker. Resolve it in design docs before pushing deeper into implementation.
- If a fix only changes transient test execution, keep it in the report. If it changes shipped behavior, update persistent docs too.
- If a failure is in the harness or script layer, treat it as productized tooling work and document it like code.
- Avoid unrelated cleanup unless it is necessary to make the stage work correct.

## Acceptance checklists

| Activity | Verify | Activity is complete when |
| --- | --- | --- |
| Implementation planning | Approved design baseline, ordered steps, affected code, tests, docs, evidence plan, and known risks are explicit. | A developer can execute the plan without inventing missing decisions. |
| Implementation | Work matches the approved plan, changed files map to planned steps, evidence is real, and related docs stay in sync. | Code, tests, and implementation docs describe the same state and unresolved items are explicit. |
| Developer review of test results | Every failure is classified, each finding has an owner, and retest scope is explicit. | No finding is untriaged and the next action is assigned. |
| Bug fixing | Root cause, fix scope, regression protection, durable doc updates, and fix evidence are explicit. | The change is ready for review and retest without hidden follow-up work. |

## Required outputs

- Code changes
- Updated implementation log and corrective-action parts
- Unit or focused regression tests
- Fix report updates when working from QA findings
- Updated `document-index.md` when docs changed

## Completion checks

- The implementation log matches the actual code state.
- Each planned step has evidence or an explicit blocker.
- Relevant tests pass and the coverage target is met, or any gap is stated plainly.
- The next reviewer can trace every code change back to the design and implementation docs.