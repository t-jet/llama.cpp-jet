---
name: manager
description: 'Drive staged cache delivery in llama.cpp-jet. Use for work handoff, stage sequencing, review gating, fix-review loops, QA coordination, documentation enforcement, and making sure each stage follows document-index.md.'
argument-hint: 'Stage or feature to drive through the workflow'
---

# Manager role

Use this skill when the task is to move a feature through the repo's stage-by-stage workflow, verify each gate, reconstruct current progress from the available documentation, and hand work to architect, developer, and QA without skipping required documentation or review loops.

## Progress reconstruction rule

Before choosing any gate, inspect the available documentation and derive the current state from evidence already present in the repo. Do not assume the workflow starts from design.

- Start with `._design_docs/document-index.md` and locate the stage design, implementation log, test plan, test reports, and any fixes report for the active stage.
- Read the most recent durable documents first: stage design entry doc, stage implementation entry doc, implementation review parts, corrective-action parts, verification summaries, test plan, latest full test report, and latest `*-fixes.md` file if one exists.
- Use the latest documented evidence to determine which gates are already complete, which gate is currently open, and which gate failed most recently.
- Resume from the earliest still-open or failed gate after the most recently completed gate.
- If the documentation shows an active bug-fix loop, do not restart from design, implementation planning, or initial implementation unless the documents explicitly show those gates were invalidated.
- If the documentation is contradictory, incomplete, or stale, treat progress reconstruction as blocked and resolve that ambiguity before delegating further work.

## Core workflow

Follow this control algorithm. One handoff advances one gate only. Every review session and every correction session must be separate fresh agent sessions. Do not advance while the current gate is still open.

```text
1. Manager: Open the stage.
	- Inspect the available documentation and reconstruct the current stage state.
	- Identify the stage goal, current phase, current gate, most recent completed
	 gate, expected deliverable, source documents, open blockers, and current owner.
   - Check the Stage intake checklist.
   - IF the Stage intake checklist fails THEN stop, gather the missing inputs,
	 and restart step 1.
	- IF the current gate is already later than design THEN jump directly to that
	 gate's loop instead of restarting from the beginning.

2. IF there is no approved design OR the active gate is design THEN run the design loop:
   REPEAT
	 2.1 Architect: Create or correct the design in a fresh session.
	 2.2 Manager: Check the Design checklist.
	 2.3 IF the Design checklist fails THEN continue the loop with a new
		 Architect correction session.
	 2.4 Architect: Review the design in a different fresh session and produce
		 a design review report.
	 2.5 Manager: Check the Design review checklist.
	 2.6 IF the design review passes THEN exit the design loop.
	 2.7 ELSE Architect: Fix the design in a new fresh session using the latest
		 design review report, then continue the loop.
   UNTIL the design review passes.

3. IF there is no approved implementation plan OR the active gate is
   implementation planning THEN run the implementation-planning loop:
   REPEAT
	 3.1 Developer: Create or correct the implementation plan in a fresh session.
	 3.2 Manager: Check the Implementation planning checklist.
	 3.3 IF the Implementation planning checklist fails THEN continue the loop
		 with a new Developer correction session.
	 3.4 Architect: Review the implementation plan in a different fresh session
		 and produce an implementation-plan review report.
	 3.5 Manager: Check the Implementation planning checklist and the latest
		 review result together.
	 3.6 IF the implementation-plan review passes THEN exit the
		 implementation-planning loop.
	 3.7 ELSE Developer: Fix the implementation plan in a new fresh session
		 using the latest implementation-plan review report, then continue the loop.
   UNTIL the implementation-plan review passes.

4. IF there is no approved implementation OR the active gate is implementation
   THEN run the implementation loop:
   REPEAT
	 4.1 Developer: Implement or correct the code and implementation documents
		 in a fresh session.
	 4.2 Manager: Check the Implementation checklist.
	 4.3 IF the Implementation checklist fails THEN continue the loop with a new
		 Developer correction session.
	 4.4 Architect: Review the implementation in a different fresh session and
		 produce an implementation review report.
	 4.5 Manager: Check the Implementation review checklist.
	 4.6 IF the implementation review passes THEN exit the implementation loop.
	 4.7 ELSE Developer: Fix the implementation in a new fresh session using
		 the latest implementation review report, then continue the loop.
   UNTIL the implementation review passes.

5. IF there is no approved test plan OR the active gate is test planning THEN
   run the test-planning loop:
   REPEAT
	 5.1 QA: Create or correct the test plan and automation in a fresh session.
	 5.2 Manager: Check the Test planning checklist.
	 5.3 IF the Test planning checklist fails THEN continue the loop with a new
		 QA correction session.
	 5.4 QA: Review the test plan in a different fresh session and produce a
		 test-plan review report.
	 5.5 Manager: Check the Test-plan review checklist.
	 5.6 IF the test-plan review passes THEN exit the test-planning loop.
	 5.7 ELSE QA: Fix the test plan and automation in a new fresh session using
		 the latest test-plan review report, then continue the loop.
   UNTIL the test-plan review passes.

6. QA: Run the full test suite defined by the active test plan in a fresh
   session and produce a full test report.
   6.1 Manager: Check the Test execution checklist.
   6.2 IF the execution is invalid, incomplete, or unsupported by a full test
	   report THEN repeat step 6 in a new QA session.
   6.3 ELSE continue.

7. Developer: Review the full test report in a fresh session.
   7.1 Manager: Check the Test-results review checklist.
   7.2 IF the Test-results review checklist fails THEN repeat step 7 in a new
	   Developer session.
   7.3 IF the developer reports no product bugs and no unresolved execution
	   blockers THEN go to step 9.
   7.4 ELSE go to step 8.

8. Run the bug-fix loop:
   REPEAT
	 8.1 Developer: Fix the reported product bugs in a fresh session and
		 produce or update the fix report.
	 8.2 Manager: Check the Bug fixing checklist.
	 8.3 IF the Bug fixing checklist fails THEN continue the loop with a new
		 Developer correction session.
	 8.4 Architect: Review the fixes in a different fresh session and produce
		 a bug-fix review report.
	 8.5 Manager: Check the Implementation review checklist for the fix set.
	 8.6 IF the architect is not satisfied THEN Developer: fix the
		 implementation again in a new fresh session using the latest bug-fix
		 review report, then continue the loop.
	 8.7 QA: Run the full test suite again in a fresh session and produce a new
		 full test report.
	 8.8 Manager: Check the Test execution checklist.
	 8.9 IF the rerun is invalid, incomplete, or unsupported by a full test
		 report THEN repeat step 8.7 in a new QA session.
	 8.10 Developer: Review the new full test report in a fresh session.
	 8.11 Manager: Check the Test-results review checklist.
	 8.12 IF the Test-results review checklist fails THEN repeat step 8.10 in a
		  new Developer session.
	 8.13 IF the developer still reports product bugs THEN continue the loop.
	 8.14 ELSE exit the bug-fix loop.
   UNTIL the architect is satisfied and the full rerun is clean.

9. Manager: Attempt stage closure.
   - Check the Stage closure checklist.
   - IF the Stage closure checklist fails THEN route the work back to the
	 failed gate and resume from that gate's loop in a fresh session.
   - ELSE close the stage and declare the next owner, next gate, or terminal state.
```

## How to determine the current gate

Apply these rules in order and stop at the first matching state.

1. If stage-intake information is missing or contradictory, the current gate is Stage intake.
2. If no approved stage design exists, or the latest design review is failing, the current gate is Design or Design review.
3. If design is approved but no approved implementation plan exists, or the latest implementation-plan review is failing, the current gate is Implementation planning or Implementation-plan review.
4. If implementation planning is approved but the implementation log or latest implementation review shows open corrections, the current gate is Implementation or Implementation review.
5. If implementation is approved but the test plan or latest test-plan review shows open corrections, the current gate is Test planning or Test-plan review.
6. If the latest required full test report is missing, invalid, partial, or stale relative to the latest implementation or fix set, the current gate is Test execution.
7. If the latest full test report exists and shows failures that have not yet been triaged by the developer, the current gate is Test-results review.
8. If a `*-fixes.md` file exists for the active test report and it shows unresolved implementation corrections, unresolved architect review findings, or unresolved rerun failures, the current gate is inside the Bug-fix loop.
9. If the latest full rerun is clean and the documents are aligned, the current gate is Stage closure.

## Required documents by gate

| Gate | Minimum documents to check or update |
| --- | --- |
| Design | `._design_docs/document-index.md`, architecture, requirements, current stage design entry doc and part files |
| Design review | Stage design doc, design review report, any prerequisite gap notes from earlier stages |
| Implementation planning | Stage design doc, `cache-handling-phaseN-implementation.md` or equivalent implementation log, implementation plan part |
| Implementation-plan review | Implementation plan, implementation-plan review report, and any returned correction notes |
| Implementation | Implementation log, code changes, unit or regression test evidence, and correction records when needed |
| Implementation review | Implementation log, code changes, implementation review report, and corrective-action parts when needed |
| Test planning | `cache-handling-test-plan.md`, relevant part files, scripts under `cache-handling-test-scripts/`, and script `README.md` |
| Test-plan review | Test plan, automation changes, and test-plan review report |
| Test execution | Fresh `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`, clean-build evidence, run evidence, and a full test report |
| Test-results review | Latest full test report, result classification, and explicit ownership for each finding |
| Bug-fix loop | Fix report, architect bug-fix review report, rerun full test report, developer test-results review, and updated persistent design or implementation docs if behavior changed |
| Stage closure | Current design, implementation log, test plan, latest full test report, and updated `document-index.md` entries when docs changed |

## Documentation rules to enforce

- Start from `document-index.md` and keep it current whenever docs are created or materially changed.
- Split any document that exceeds 300 lines into part files under a same-name directory.
- Keep design and implementation documents self-contained. Do not leave durable behavior changes stranded in test reports.
- Keep the test plan generic. Do not reference a specific test run in the plan.
- Use a new `test-report-YYYYMMDD-NN.md` file for each execution session.
- Require plain ASCII status labels and no unicode icons in test plans, reports, scripts, or output.
- Require a clean build before every test session.

## Document naming and placement conventions

- Keep stage workflow documents under `._design_docs/`. Treat `._design_docs/document-index.md` as the navigation root and update it whenever documents are added or materially changed.
- Use entry-document names by role: `cache-handling-phaseN-design.md` for stage design, `cache-handling-phaseN-implementation.md` for the implementation log, and `cache-handling-test-plan.md` for the shared test plan.
- Keep architecture and requirements as topic-level entry documents such as `cache-handling-architecture.md` and `cache-handling-requirements.md`.
- When an entry document exceeds 300 lines, keep the entry file as the overview and table of contents, create a same-name directory, and place part files there as `part-XX-<slug>.md`.
- Place design parts under `._design_docs/cache-handling-phaseN-design/part-XX-<slug>.md`.
- Place implementation steps, review parts, corrective actions, production-fix parts, and verification summaries under `._design_docs/cache-handling-phaseN-implementation/`. Recent sessions used names such as `part-09-review-executive-summary.md`, `part-13-corrective-actions.md`, `part-15-production-integration-fixes-part1.md`, and `verification-summary.md`.
- Place review results that affect stage delivery inside the stage implementation document tree as additional part files, not as ad hoc standalone review documents elsewhere.
- Keep test planning and automation together: `._design_docs/cache-handling-test-plan.md`, part files under `._design_docs/cache-handling-test-plan/`, and automation assets under `._design_docs/cache-handling-test-scripts/` with a maintained `README.md`.
- Store each test execution session report in `._design_docs/.test_reports/` as `test-report-YYYYMMDD-NN.md`.
- Store bug-fix work for a specific test execution beside that report as `test-report-YYYYMMDD-NN-fixes.md`.
- In a `*-fixes.md` file, append planning notes, progress logs, review results, implementation or testing evidence, and correction history as new sections in the same file.
- If bug fixing changes durable design or implementation behavior, copy the result back into the phase design or implementation docs and keep those persistent docs self-contained. Do not make persistent docs depend on a specific test report or fixes report.

## Gate acceptance checklists

| Step | Verify | Step is complete when |
| --- | --- | --- |
| Stage intake | Goal, active stage, current gate, most recent completed gate, source docs, blockers, and current owner are explicit. | Exactly one active gate is selected from the documented evidence and the next responsible role is clear. |
| Design | Scope, prerequisites, assumptions, interfaces, constraints, observability, and testability are documented. | Design docs are reviewable, indexed when needed, and free of hidden decisions. |
| Design review | Architecture and requirements traceability, prerequisite gaps, contradictions, risks, and findings are explicit. | Review is recorded with either a pass verdict or a concrete rework list. |
| Implementation planning | Approved design baseline, ordered steps, affected code, tests, docs, evidence plan, and known risks are explicit. | A developer can execute the plan without inventing missing decisions. |
| Implementation | Work matches the approved plan, changed files map to planned steps, evidence is real, and related docs stay in sync. | Code, tests, and implementation docs describe the same state and unresolved items are explicit. |
| Implementation review | Design conformance, code correctness, doc-code consistency, and correction ownership are explicit. | Review ends in pass or rework with no ambiguous findings. |
| Test planning | Implemented scope, positive and negative coverage, observability checks, clean-build rules, and reusable automation are covered. | Test plan, scripts, and README are aligned and ready for execution review. |
| Test-plan review | Scope is current, wording is generic, stale content is removed, and evidence format is clear. | No blocking coverage or process gaps remain. |
| Test execution | Clean build, fresh session report, environment, run evidence, and reproducible failures are captured. | Executed items have clear pass, fail, skip, or blocked outcomes with usable evidence. |
| Test-results review | Every failure is classified, each finding has an owner, and retest scope is explicit. | No finding is untriaged and the next action is assigned. |
| Bug fixing | Root cause, fix scope, regression protection, durable doc updates, and fix evidence are explicit. | The change is ready for review and retest without hidden follow-up work. |
| Stage closure | Design, implementation, test plan, reports, and index agree on current state. | Gate is closed with an explicit pass decision and the next owner or terminal state is named. |

## Decision points

- Missing documentation is a blocker, not a follow-up.
- A review with open findings does not count as gate completion.
- A passed build without documented evidence does not count as gate completion.
- A bug fix that changed product behavior must update persistent design or implementation docs before the stage can close.
- If the workflow needs stricter enforcement than a skill can provide, replace this role with a custom agent that emits formal gate outputs.

## Completion checks

- Every gate has an owner, evidence, and an explicit pass or fail state.
- Review loops are closed in repo docs, not only in chat summaries.
- The implementation log, test plan, test reports, and document index agree on the current state.
- The stage is ready for the next owner with no missing documents and no unresolved review findings.