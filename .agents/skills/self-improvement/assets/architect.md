# Architect improvement memory

## Improvement: Memory load before acknowledgement

Condition:
- When task instructions require reading self-improvement memory before any other task action, including tasks that start with AGENTS.md content, repository instructions, a long delegated-agent brief, or multiple required skills

Action:
- Do make the first assistant action a memory-reading tool call that reads only the self-improvement skill instructions and Architect memory before any acknowledgement, commentary update, skill-use announcement, plan, analysis, other skill reads, or non-memory tool use; don't announce skill use or start parallel task reads until that memory read is complete.

## Improvement: Gate wording with open findings

Condition:
- When an architecture, design, implementation-plan, implementation evidence, or re-review deliverable changes a gate state or closes an earlier finding, or when current entry docs still carry stale limitation, owner, or handoff wording

Action:
- Do check the live entry documents, current-status sections, and linked gate-status part files first, distinguish historical quoted findings from current contradictions, then keep durable gate-status locations in the same state, such as reviewable, rework-required, manager-gate-ready, planning-open, approval-pending, approved, ready-for-QA, or blocked; don't leave stale limitation, re-review-ready, handoff-closed, or ready-for-implementation wording after a finding has been closed or while an open finding remains

## Improvement: Changed paths for untracked review docs

Condition:
- When adding or updating review part files in a document tree that is untracked or only partly tracked by git

Action:
- Do track the paths edited during the task, verify their contents directly, separate task-local edits from pre-existing dirty paths, and report that task-local path list; don't rely on `git diff` or `git status` alone to prove what changed

## Improvement: Code-review findings tied to approved docs

Condition:
- When performing an implementation review against an approved staged design or implementation plan

Action:
- Do tie each blocking finding to both an exact code location and the specific approved design or plan requirement it violates; don't block sign-off on style or pre-existing behavior unless it affects the current stage gate

## Improvement: Skill path fallback

Condition:
- When a required repository skill is listed in the session but the first documented skill path cannot be read

Action:
- Do check the repository-local `.agents/skills/<skill>/SKILL.md` path before falling back to ad hoc behavior, and record the path issue only briefly

## Improvement: Scoped traceability for deferred requirements

Condition:
- When authoring a stage design for a subset of architecture requirements and the intake lists broad requirement ranges with later-stage subrequirements

Action:
- Do trace each relevant requirement or subrange as covered, constrained, or explicitly deferred in the persistent design; don't leave deferred subrequirements implied only by the scope section

## Improvement: Atomic-operation design reviews

Condition:
- When reviewing or correcting a design or implementation that claims an operation is atomic but the described steps mutate live state in sequence, or when implementation evidence documents a limitation against an approved atomicity contract

Action:
- Do require an explicit pre-apply validation, scratch-apply or exact rollback contract, fallback live-state outcome, diagnostics or metrics, and failure-injection tests before marking the design or implementation ready; don't accept goal-level wording such as "leave state valid" or a documented production limitation unless the durable design has an approved exception

## Improvement: Handoff prerequisites in plan reviews

Condition:
- When reviewing an implementation plan whose approved design or prior gate says planning or code work must wait for a manager handoff, gate approval, or other prerequisite decision

Action:
- Do verify that the prerequisite decision is recorded or linked in durable docs before returning PASS; don't treat a technically sound plan as approved when the document set still says the handoff is closed

## Improvement: Cross-part protocol consistency in multi-part design reviews

Condition:

- When a multi-part design specifies a step-by-step protocol in one part and failure-mode handling for those same steps in a separate part, and the two parts can produce conflicting state outcomes (for example, a transient state set before an enqueue attempt but the failure table implies the prior state must be preserved on queue-full)

Action:

- Do read both the protocol steps and the failure-handling table together, identify any case where the protocol mutates state before a fallible step and the failure table implies that mutation must be reverted, and record that as a non-blocking observation with a concrete implementation contract requirement; don't flag it as a blocking finding if the correct outcome is unambiguous across both parts

## Improvement: Dependency graph completeness in implementation plan reviews

Condition:

- When reviewing an implementation plan where later steps add member variables to a class and earlier-numbered steps add methods that use those same variables, but the dependency list on those method-adding steps does not reference the member-adding step

Action:

- Do trace each step's code changes to check that every member variable, function, or type referenced in the step's changes exists at the point that step's dependencies are satisfied; flag any case where a referenced symbol is only introduced in a later step as a blocking missing-dependency finding; don't assume numerical step order implies the correct dependency graph
