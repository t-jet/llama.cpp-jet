---
name: qa
description: 'Plan, review, automate, and execute cache tests in llama.cpp-jet. Use for test planning, test plan review, test automation, test execution, clean-build validation, and test reports tied to document-index.md.'
argument-hint: 'Stage, test scope, or report to work on'
---

# QA role

Use this skill when the task is to create or review a test plan, extend test automation, execute a test session, or turn failures into a reproducible handoff for development.

## Primary inputs

- `._design_docs/document-index.md`
- Architecture, requirements, and stage design or implementation docs referenced by the index
- `._design_docs/cache-handling-test-plan.md`
- `._design_docs/cache-handling-test-scripts/README.md`
- Existing scripts under `._design_docs/cache-handling-test-scripts/`
- The latest relevant implementation log or fix report

## Documentation contract

- Keep the test plan generic. Do not tie it to a specific test run.
- Use `document-index.md` to describe how to find current implementation state instead of baking in stale status notes.
- Remove non-relevant test sections instead of hiding them behind exclusions or ignored output.
- When a new test run starts, create a fresh report in `._design_docs/.test_reports/` named `test-report-YYYYMMDD-NN.md`.
- Use plain ASCII labels such as `PASS`, `FAIL`, `SKIP`, and `BLOCKED`. Do not use unicode icons in test plans, scripts, reports, or output.
- When documentation changes, update `document-index.md` and any related script README.

## Document naming and placement conventions

- Keep the shared test plan at `._design_docs/cache-handling-test-plan.md`.
- When the test plan grows past 300 lines, keep the entry file as overview plus links, create `._design_docs/cache-handling-test-plan/`, and continue the content in `part-XX-<slug>.md` files.
- Keep reusable test automation under `._design_docs/cache-handling-test-scripts/` and maintain a colocated `README.md` that explains how the scripts fit the plan.
- Store test execution outputs under `._design_docs/.test_reports/`.
- Name each execution-session report `test-report-YYYYMMDD-NN.md`.
- Name the paired bug-fix and retest work file `test-report-YYYYMMDD-NN-fixes.md` and keep it beside the triggering test report.
- In a `*-fixes.md` file, append planning notes, progress logs, review comments, implementation or test evidence, and rerun history as new sections in that same file.
- Keep the test plan generic and durable; do not turn a specific session report into part of the plan.
- If QA work changes the long-lived test plan, script layout, or script maintenance guidance, update `._design_docs/document-index.md` and the relevant script `README.md`.

## Procedure

1. Read the stage design, implementation status, architecture constraints, and current test plan from `document-index.md`.
2. For new coverage, update `cache-handling-test-plan.md` and its part files. Extend related scripts and `cache-handling-test-scripts/README.md` when functionality changes.
3. Keep the plan aligned with the implemented scope, negative scenarios, metrics, concurrency behavior, and stress coverage that actually matter for the current stage.
4. For cache-capacity or eviction cases, measure actual entry sizes, calculate `--cache-ram` from those measurements, keep prompts short and predictable, and document the assumptions behind the test design.
5. Before execution, do a clean build and verify that the binary is fresh. Treat this as mandatory for every test session.
6. Create a new session report in `._design_docs/.test_reports/`. Plan the run there, then log evidence, results, and bugs as the session progresses.
7. Reuse and evolve the PowerShell scripts under `cache-handling-test-scripts/` rather than rebuilding the test harness from scratch.
8. If failures are harness issues, fix the plan, scripts, or README and rerun. If failures are product bugs, leave a reproducible report with evidence for development.

## Decision points

- If the plan still reflects older feature status, replace the stale statements with index-driven guidance.
- If a scenario is no longer relevant, remove it instead of papering over it with exclusions.
- If the cache budget is too small to hold even one realistic entry, redesign the test instead of treating the resulting noise as a valid failure.
- If a run used a stale binary or skipped the clean build, discard the results and rerun.

## Acceptance checklists

| Activity | Verify | Activity is complete when |
| --- | --- | --- |
| Test planning | Implemented scope, positive and negative coverage, observability checks, clean-build rules, and reusable automation are covered. | Test plan, scripts, and README are aligned and ready for execution review. |
| Test-plan review | Scope is current, wording is generic, stale content is removed, and evidence format is clear. | No blocking coverage or process gaps remain. |
| Test automation update | Script behavior matches the plan, evidence output is usable, maintenance docs are current, and automation avoids stale assumptions. | Automation and README support the planned runs without ad hoc manual reconstruction. |
| Test execution | Clean build, fresh session report, environment, run evidence, and reproducible failures are captured. | Executed items have clear pass, fail, skip, or blocked outcomes with usable evidence. |

## Required outputs

- Updated test plan and part files when scope changes
- Updated test scripts and script README when automation changes
- One new test report per execution session
- Reproducible bug evidence or clear pass results

## Completion checks

- The test plan reflects current implemented scope and stays generic.
- A clean build was performed before execution.
- Test evidence, bugs, and reruns are logged in the per-session report.
- Any automation changes are captured in the scripts and README, not only in chat.