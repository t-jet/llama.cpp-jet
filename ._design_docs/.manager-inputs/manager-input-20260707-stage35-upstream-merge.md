# MANAGER INPUTS - NOT AN APPROVED DESIGN

Date: 2026-07-07
Stage: 35
Title: Upstream merge cycle after Stage 34 closure
Branch: work-branch
Current gate: Design
Next owner: Architect

## User directive

"Add new stage to merge upstream changes using the Upstream merge guide."

## Intake status

Stage 34 is closed with Manager closure PASS on 2026-07-07. No Stage 35
design, implementation plan, pre-merge report, merge log, test plan update, or
test report exists at intake.

The active gate is Design. The Architect must create the Stage 35 operational
design before any Developer pre-merge analysis or merge execution starts.

Local read-only intake checks:

- `git status --short`: clean.
- Current branch: `work-branch`.
- Upstream-cycle ref available locally: `remotes/origin/upstream_master`.
- Git remotes: `origin` points to `https://github.com/t-jet/llama.cpp-jet.git`.

## Source authority

- User directive dated 2026-07-07.
- `._design_docs/upstream-merge-guide.md`
- `._design_docs/upstream-merge-guide/part-01-procedure.md`
- `._design_docs/upstream-merge-guide/part-02-conflict-patterns.md`
- `._design_docs/upstream-merge-guide/part-03-coverage-and-evidence.md`
- `._design_docs/upstream-merge-guide/part-04-edge-cases.md`
- `._design_docs/cache-handling-phase34-implementation/part-21-manager-closure-20260707.md`
- `._design_docs/cache-handling-phase34-design.md`
- `._design_docs/cache-handling-phase34-implementation.md`
- `._design_docs/document-index.md`

## Manager decisions recorded at intake

| ID | Decision |
| --- | --- |
| D35-INTAKE-01 | Open Stage 35 as the next upstream merge cycle after Stage 34 closure. |
| D35-INTAKE-02 | Use `._design_docs/upstream-merge-guide.md` as the binding procedure for pre-merge analysis, Manager review, merge execution, rework planning, regression scope, merge log, and closure. |
| D35-INTAKE-03 | Treat Stage 34 closure as the immediate prior-stage baseline. Stage 35 design must also preserve the durable contracts from earlier closed stages and the architecture. |
| D35-INTAKE-04 | Use `origin/upstream_master` as the initial upstream-cycle reference candidate because that is the locally available upstream tracking ref. The Stage 35 design or Manager design gate must confirm the final upstream reference policy. Developer must verify the chosen ref against the actual upstream `master` tip before opening the commit range. |
| D35-INTAKE-05 | No merge execution, conflict resolution, code changes, commits, pushes, PRs, or reviewer responses are authorized by this intake. |

## Required design scope

The Stage 35 design must adapt the upstream merge guide to this cycle. It must
record:

- Prior-stage closure baseline, starting with Stage 34 Manager closure PASS,
  including I-34-01 idempotent save and I-34-02 slow read outside the lock.
- Affected prior-stage contracts and architecture invariants the merge must
  preserve.
- File-glob groups for upstream commit filtering, including server cache,
  server context, branch graph, chat/template, speculative/MTP, HTTP route,
  metrics, cold-store, checkpoint, test harness, and coverage surfaces touched
  by local staged work.
- Upstream reference policy, including whether `origin/upstream_master` remains
  the source ref and how staleness against upstream `master` is handled.
- Pre-merge report requirements, per-commit triage decisions, and Manager
  decision points for REWORK-REQUIRED, DEFER, REVERT, and known gaps.
- Conflict policy for local feature paths and legacy/default paths.
- Rework routing when an upstream commit invalidates a prior-stage contract.
- Regression scope and closure-contract evidence, including clean build,
  focused cache tests, public metrics shape, coverage rows, HTTP probes, and
  any Stage 34 agentic replay rows touched by the merge.
- Merge log and closure requirements.

## Blockers and constraints

- Stage 35 cannot leave Design until the Architect writes a reviewable design
  and an independent design review passes.
- The final upstream reference path is not closed by this intake; it must be
  confirmed by the Stage 35 design or Manager design gate.
- Developer pre-merge analysis cannot start until the Manager design gate
  passes.
- Merge execution cannot start until pre-merge analysis is written, reviewed,
  and approved per the upstream merge guide.
- A stale upstream reference is a Manager decision point, not an unrecorded
  assumption.
- Any upstream change that weakens a closed prior-stage contract is a rework
  candidate, not a silent integration.

## Acceptance target for design gate

Design gate can pass only when the Stage 35 design gives the Developer enough
information to produce the pre-merge analysis without inventing contract lists,
file-glob filters, upstream reference policy, conflict rules, regression scope,
or evidence format.
