---
name: self-improvement
description: 'Use when an agent must read its agent-specific improvement memory before starting work and update that memory after finishing a task or user request.'
argument-hint: 'Agent name or agent-specific memory workflow'
---

# Self-Improvement Memory

Use this skill when an agent must load its own improvement memory before doing task work and update that memory after the task or user request finishes.

## Memory Location

- Keep memory files in this skill's `assets/` directory.
- Use one markdown file per agent, named with the lowercase agent name.
- Current files for this repo are:
  - `assets/architect.md`
  - `assets/developer.md`
  - `assets/manager.md`
  - `assets/qa.md`
- If another agent uses this skill later, store its memory in `assets/<lowercase-agent-name>.md`.
- Do not use `/memories/` for this workflow. This skill keeps its records in local files under `.agents/skills/self-improvement/assets/`.

## Required Pre-Task Behavior

1. Determine the current agent name.
2. Read `assets/<lowercase-agent-name>.md` before any other task action, including planning, tool use, or replying to the user.
3. Find the `Condition` and `Action` entries that apply to the incoming task or request.
4. Follow those actions while doing the task.
5. If the file is missing, create it under `assets/` and continue with an empty improvement history.

## Required Post-Task Behavior

1. Run the post-task review after each task or user request ends, including full completion, partial completion, or blocked outcomes.
2. Convert the observed execution gap or reinforced success pattern into an improvement outcome.
3. Search the same memory file for a similar improvement.
4. Add, strengthen, replace, or skip the candidate according to the rules below.
5. Save the final result back to the same memory file before ending the session.

## Memory Entry Format

Use this structure for each stored improvement entry:

```text
## Improvement: short label

Condition:
- When [specific situation, trigger, pattern, or failure mode occurs]

Action:
- Do [specific corrective behaviour]
```

or:

```text
## Improvement: short label

Condition:
- When [specific situation, trigger, pattern, or failure mode occurs]

Action:
- Don't [specific behaviour to avoid]
```

## Post-Task Review Process

1. Confirm task completion.
2. Assess execution effectiveness against the goal, constraints, format, and quality bar.
3. Identify execution gaps or reinforced success patterns that should change future behavior.
4. Convert the result into a conditional, actionable improvement outcome.
5. Check the memory file for a similar existing improvement.
6. Update the file by adding, strengthening, replacing, or skipping the candidate.

## Memory Rules

### Do

- Store only improvement outcomes.
- Make every improvement conditional and actionable.
- Use clear `Do` or `Don't` actions.
- Check for similar existing improvements before adding a new one.
- Strengthen existing improvements when later tasks reinforce them.
- Prefer precise, enforceable instructions over broad guidance.
- Keep memory short and execution-focused.

### Don't

- Don't store task summaries.
- Don't store user requests or task intent.
- Don't store general context.
- Don't store vague lessons such as `be better` or `improve quality`.
- Don't create duplicate improvements with slightly different wording.
- Don't keep weak or obsolete improvements when a stronger version exists.

## Strengthening Rule

When a similar improvement already exists, rewrite it so it is more precise and easier to enforce.

### Weak version

```text
Condition:
- When responding to concise guidance tasks

Action:
- Do keep the response short
```

### Strengthened version

```text
Condition:
- When the task asks for short, concise, or guidance-style output

Action:
- Do produce a compact structure with only the essential process steps, do's, and don'ts; don't add extended explanation unless required
```

## Required Internal Post-Task Record

```text
Task completed:
- Yes / Partial / No

Effectiveness assessment:
- What execution issue, gap, or success pattern was observed

Improvement outcome candidate:
- Condition:
  - When...
- Action:
  - Do / Don't...

Similar memory check:
- Similar improvement found: Yes / No
- Existing improvement:
- Decision: Add new / Strengthen existing / Replace existing / No update

Memory update:
- Final improvement outcome stored:
  - Condition:
    - When...
  - Action:
    - Do / Don't...
```

## Example

```text
Task completed:
- Yes

Effectiveness assessment:
- The prior instruction incorrectly allowed memory to store task state and context. Memory should store only improvement outcomes.

Improvement outcome candidate:
- Condition:
  - When updating memory after task completion
- Action:
  - Do store only actionable improvement outcomes with a condition and a do/don't action

Similar memory check:
- Similar improvement found: Yes
- Existing improvement:
  - Carry forward relevant task context after completion
- Decision:
  - Replace existing because it conflicts with the new memory constraint

Memory update:
- Final improvement outcome stored:
  - Condition:
    - When updating memory after task completion
  - Action:
    - Do store only actionable improvement outcomes; don't store task history, user intent, general context, or preferences unless reformulated as improvement outcomes
```
