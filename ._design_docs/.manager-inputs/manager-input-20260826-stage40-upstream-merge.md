# MANAGER INPUTS - NOT AN APPROVED DESIGN

Date: 2026-08-26
Stage: 40
Title: Upstream merge cycle after Stage 39 closure
Branch: work-branch
Current gate: Design
Next owner: Architect

## User directive

Autonomous work: user unreviewable. Manager decisions made per upstream-merge-guide.md precedent (Stage 35 pattern).

## Intake status

Stage 39 is closed with Manager closure PASS on 2026-07-17. No Stage 40
design, implementation plan, pre-merge report, merge log, test plan update, or
test report exists at intake.

The active gate is Design. The Architect must create the Stage 40 operational
design before any Developer pre-merge analysis or merge execution starts.

Local read-only intake checks (2026-08-26):

- `git status --short`: `M .github/agents/manager.agent.md`, `?? ._design_docs/side_input/`. Near-clean.
- Current branch: `work-branch`.
- Upstream-cycle ref available locally: `refs/remotes/origin/upstream_master`.
- Upstream ref tip: `fc35562ba46fbbf8e30cac85edbb39642c37d248` (2026-08-26 12:35:54 +0200, "cuda: unblock mmq for MoE on sm_60 (#26264)").
- Git remotes: `origin` points to `https://github.com/t-jet/llama.cpp-jet.git`. No separate `upstream` remote.
- HEAD: `e9d67a2fb6ad6b186a52b6b35f20d7c9e325c047` (2026-07-21, "rewrite architecture document").
- Stage 35 merge base (fork point): `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`.
- Commits behind upstream since fork point: 732.
- Commits ahead on work-branch: 113.
- Fetch method: `git fetch https://github.com/ggml-org/llama.cpp.git master:refs/remotes/origin/upstream_master`.
- Prior-stage design docs on disk: Stage 35 design (upstream merge), Stages 36-39 design (cache features).
- Prior-stage test plan part for upstream merge regression: `._design_docs/cache-handling-test-plan/part-40-stage35-upstream-merge-regression.md` (Stage 35's, can be adapted).
- Upstream merge guide: `._design_docs/upstream-merge-guide.md` + parts 01-04.

## Manager decisions recorded at intake

| ID | Decision |
| --- | --- |
| D40-INTAKE-01 | Open Stage 40 as the next upstream merge cycle after Stage 39 closure. |
| D40-INTAKE-02 | Use `._design_docs/upstream-merge-guide.md` as the binding procedure for pre-merge analysis, Manager review, merge execution, rework planning, regression scope, merge log, and closure. |
| D40-INTAKE-03 | Treat Stage 39 closure as the immediate prior-stage baseline (which subsumes Stages 36-38). Stage 40 design must also preserve the durable contracts from earlier closed stages and the architecture. Prior-stage contracts from Stages 36-39 are in scope for pre-merge triage and rework analysis. |
| D40-INTAKE-04 | Use `origin/upstream_master` as the upstream-cycle reference (direct remote-tracking ref path, per Stage 35 precedent and Manager design gate D35-INTAKE-04). Developer must verify the chosen ref against the actual upstream `master` tip before opening the commit range. |
| D40-INTAKE-05 | The stale working-tree items (`.github/agents/manager.agent.md`, `._design_docs/side_input/`) are not a blocker for the design gate. They must be resolved before merge execution. |
| D40-INTAKE-06 | The upstream merge guide part-04 (edge cases) section 14 (cycle reuse across stages) applies: Stage 40 is a new cycle that reuses the approved procedure from the upstream-merge-guide. The affected stage's design (Stage 40 design) must name the prior-stage contracts. |

## Source authority

- `._design_docs/upstream-merge-guide.md`
- `._design_docs/upstream-merge-guide/part-01-procedure.md`
- `._design_docs/upstream-merge-guide/part-02-conflict-patterns.md`
- `._design_docs/upstream-merge-guide/part-03-coverage-and-evidence.md`
- `._design_docs/upstream-merge-guide/part-04-edge-cases.md`
- `._design_docs/cache-handling-phase35-design.md` (precedent pattern)
- `._design_docs/cache-handling-phase35-implementation/part-34-manager-closure-20260709.md`
- `._design_docs/cache-handling-phase39-implementation/part-205-manager-closure-20260717.md`
- `._design_docs/cache-handling-stage-tracker.md`
- `._design_docs/document-index.md`