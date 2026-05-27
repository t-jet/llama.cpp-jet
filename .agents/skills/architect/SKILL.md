---
name: architect
description: 'Design and review staged cache work in llama.cpp-jet. Use for architecture governance, stage design, design review, implementation review, code review, and documentation corrections driven by document-index.md.'
argument-hint: 'Stage, document, or change set to design or review'
---

# Architect role

Use this skill when the task is to define stage scope, review a design against architecture, review an implementation against design, or decide whether a fix belongs in persistent documentation.

## Primary inputs

- Stage goal and acceptance target
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-architecture.md`
- `._design_docs/cache-handling-requirements.md`
- Current stage design and implementation documents
- Relevant code and tests

## Documentation contract

- Start from `document-index.md` and use it to find the right phase or stage documents.
- When a document grows past 300 lines, split it into part files under a same-name directory.
- Keep the entry document as the navigation page with top-level context and links to parts.
- Update `document-index.md` whenever a document is added or materially changed.
- Keep persistent docs self-contained. If a bug fix changes durable behavior, copy the result into the design or implementation docs instead of relying on a test report.

## Document naming and placement conventions

- Keep architecture, design, implementation, and test-planning documents under `._design_docs/`, and use `._design_docs/document-index.md` as the entry point for locating them.
- Use `cache-handling-phaseN-design.md` as the stage design entry document and place its part files under `._design_docs/cache-handling-phaseN-design/` as `part-XX-<slug>.md`.
- Keep architecture and requirements in stable topic-level entry documents such as `cache-handling-architecture.md` and `cache-handling-requirements.md`.
- When a design or implementation entry document exceeds 300 lines, keep the entry file as overview plus table of contents, create a same-name directory, and continue the content in numbered part files.
- Put implementation review outputs, corrective actions, and verification notes in the implementation document tree, not in separate ad hoc review documents. Recent naming patterns include `part-09-review-*.md`, `part-13-corrective-actions.md`, and `verification-summary.md`.
- If review work starts from a test or fix report, keep the review notes in that report while the report is active, but copy any durable architectural or design outcome into the persistent phase design or implementation docs.
- Do not make persistent design or implementation docs reference a specific `test-report-*.md` or `*-fixes.md` file as required context.

## Procedure

1. Read architecture, requirements, prior-stage implementation status, and the current stage documents from `document-index.md`.
2. Confirm stage boundaries, prerequisites, non-goals, and inherited constraints from earlier stages.
3. If the stage design is missing or stale, create or update the stage design entry doc and its part files. For the cache workflow, the stable set has been overview and objectives, component design, implementation steps, test specifications, metrics and observability, and acceptance criteria.
4. Review the design against architecture and requirements. Record mismatches, missing cases, and the review verdict in repo docs, not only in chat.
5. Review implementation docs and code against the approved design. If corrections are needed, add a review section or corrective-actions part to the implementation log and make the required changes explicit.
6. Check bug-fix reports against architecture, design, and implementation. If a fix changed actual system behavior, update the persistent docs so the repo stays consistent after the report ages out.
7. Decide handoff status: ready for implementation, ready for QA, blocked by prerequisite gaps, or correction loop required.

## Decision points

- If earlier stages are incomplete or inconsistent with architecture, surface the gap and either block the stage or add a documented prerequisite or enhancement path.
- If review findings affect runtime behavior, compatibility, metrics, or observability, require a correction before sign-off.
- If the issue is only a one-off execution artifact, keep it in the test report.
- If the issue changes long-term behavior or process, update the design or implementation docs.

## Acceptance checklists

| Activity | Verify | Activity is complete when |
| --- | --- | --- |
| Design authoring or design correction | Scope, prerequisites, assumptions, interfaces, constraints, observability, and testability are documented. | Design docs are reviewable, indexed when needed, and free of hidden decisions. |
| Design review | Architecture and requirements traceability, prerequisite gaps, contradictions, risks, and findings are explicit. | Review is recorded with either a pass verdict or a concrete rework list. |
| Implementation review or code review | Design conformance, code correctness, doc-code consistency, and correction ownership are explicit. | Review ends in pass or rework with no ambiguous findings. |
| Durable documentation alignment | Persistent docs reflect shipped behavior, durable fixes are not stranded in test reports, and index or split rules are satisfied. | Design and implementation docs match reality and the next handoff is explicit. |

## Required outputs

- Stage design or design corrections
- Review notes written into the relevant repo document
- Explicit correction list with acceptance checks
- Updated `document-index.md` entry when docs changed

## Completion checks

- Architecture, requirements, design, implementation, and code say the same thing about the feature.
- Review findings live in repo docs and are traceable to concrete files or behaviors.
- No modified document violates the 300-line split rule.
- The next owner has a clear handoff state and no hidden assumptions.