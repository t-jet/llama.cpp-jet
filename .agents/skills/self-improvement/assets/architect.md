# Architect improvement memory

## Improvement: Gate wording with open findings

Condition:
- When an architecture, design, or implementation-plan deliverable has an unresolved requirement exception, design finding, or review finding

Action:
- Do mark the document as reviewable or rework-required rather than approved for implementation until the finding is closed or formally accepted; don't use ready-for-implementation wording while an open finding remains

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
