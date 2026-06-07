# Upstream merge guide

Status: New guide, draft 1.
Goal: provide a generic, reusable procedure for re-syncing this fork with the upstream project and reworking any prior feature when the upstream changes invalidate it. The guide is independent of the feature set: it applies to the cache, the checkpoint layer, speculative decoding, the server context, the slot lifecycle, the HTTP layer, and any future feature layer that this fork adds on top of upstream.
Scope: operational. The guide records how to plan, execute, audit, and close an upstream merge. It does not approve specific feature changes. A new upstream merge cycle opens a new implementation log that points to this guide for procedure and to the affected stage's design for feature-specific contracts.

## When to use this guide

Open an upstream merge cycle when any of the following is true.

- The fork has fallen behind upstream by enough commits that the divergence risks a hard conflict, an integration defect, or a missing upstream security or stability fix.
- Upstream renamed a public API, a CLI flag, a Prometheus metric, or a bounded diagnostic field that this fork uses.
- Upstream added a feature, struct field, enum value, or task type that this fork's prior features depend on.
- Upstream changed behavior this fork's prior features assume (cache replacement, KV-cache type, slot dispatch, request transport, sampling, grammar, speculative control flow).
- Upstream closed a defect that this fork also addressed locally, and the upstream fix differs from the local fix.
- A production crash, an MTP/route/HTTP regression, or a public metric change is traced to an upstream drift.

The guide is read top to bottom on the first cycle. On later cycles, the Architect and the Developer read only the part they own (Architect: parts 1, 2, 4; Developer: parts 1, 2, 3, 4 as needed; QA: part 3).

## Procedure at a glance

The procedure is six ordered steps. Steps 1 through 6 do not start until the prerequisite gates from the affected stage's design and this guide's prereq section close.

1. Pre-merge analysis. The Developer enumerates the upstream commit range, applies the file-glob filter, opens a per-commit triage table, and records the aggregate summary. The Architect reviews. The Manager approves.
2. Manager review of the pre-merge analysis. The Manager can change NO-OP, INTEGRATE, or DEFER into REWORK-REQUIRED. The change is recorded with the date and the prior-stage contract it protects.
3. Merge execution. The Developer runs a real two-parent merge. Conflicts are resolved per the local-first-for-hybrid / upstream-first-for-legacy policy. Semantic duplicates and divergent fix paths are handled per part 2.
4. Per-rework planning. For every REWORK-REQUIRED entry, the Architect opens a rework part file in the affected stage's design tree. The rework follows the standard stage workflow but is scoped to the contract gap.
5. Regression test scope. QA re-runs the minimum regression scope on the test plan parts whose prior-stage contract the merge touched. The expanded scope is added for any closed rework. The coverage, evidence, and citation rules in part 3 apply.
6. Merge log and stage closure. The Developer writes the merge log with the required sections. The Architect reviews. The Manager closes the merge cycle in the implementation log.

A rework that grows beyond a contract gap opens as a new stage through the standard stage intake. A bug or invariant that surfaces after closure opens a new part file in the stage's design tree; the design gate does not reopen.

## Contents

- [Part 1: Procedure, prerequisites, and gates](upstream-merge-guide/part-01-procedure.md)
- [Part 2: Conflict patterns and resolution playbook](upstream-merge-guide/part-02-conflict-patterns.md)
- [Part 3: Coverage, evidence, and closure contracts](upstream-merge-guide/part-03-coverage-and-evidence.md)
- [Part 4: Edge cases, advanced variants, and post-closure follow-ups](upstream-merge-guide/part-04-edge-cases.md)

## Conventions used in the guide

- The fork's local default branch is the integration branch. A working branch may sit on top of the local default branch during rework, but the merge is recorded on the local default branch.
- The upstream reference is a local tracking branch (e.g., `upstream_master`) configured against the upstream remote (e.g., `https://github.com/ggml-org/llama.cpp.git`). The Developer verifies the tracking branch is current against the upstream remote before opening the commit range. A stale tracking branch is recorded as a known gap.
- A "prior-stage contract" is any behavior, surface, or invariant the prior stage designs and the architecture record as durable. The guide references the contract owner (the stage or the architecture) rather than the file path.
- A "closure contract" is a metric, coverage floor, evidence row, or test that the prior stages and the test plan name as required for stage closure. Closure contracts survive the merge. A closure contract that an upstream change would weaken is a rework candidate.

## Boundary with stage designs

The guide is a procedure document. The stage designs are feature documents. The procedure does not change feature behavior. The features do not change the procedure. A feature-specific rule (e.g., the speculative mode namespace isolation rule, the cold store root containment rule, the public Prometheus metric set) lives in the architecture or the stage design, not in this guide.

When the Architect opens a rework for a stage, the rework part file references this guide for the procedure and the stage design for the contract gap. The rework evidence lives in the stage's implementation log, not in the merge log.

## What this guide is not

- The guide does not approve specific upstream merges. A specific merge opens a new implementation log that points to this guide for procedure and to the affected stage's design for the prior-stage contract list.
- The guide does not replace the architecture or the prior stage designs. The architecture owns the durable invariants. The stage designs own the prior-stage contracts. The guide owns the operational layer.
- The guide does not adopt upstream CI as a closure contract. The closure contract is the prior-stage contracts, not the upstream project's CI matrix.
- The guide does not authorize silent integration. Every triage decision is recorded in the pre-merge report. Every conflict is recorded in the merge log. Every rework is recorded in the stage's design tree.
- The guide does not authorize history rewrites. A failed merge is closed with a reverse merge, an explicit `git reset` to the fork point, or a new merge attempt from the fork point.

## Handoff

This guide is the procedure the next upstream merge cycle reads. The next cycle opens a new implementation log that records the cycle-specific decisions, conflicts, reworks, and closure. The implementation log links to this guide for the procedure and to the affected stage's design for the prior-stage contract list.

The guide itself is not gated. It is durable procedure. A correction to the guide is itself a part-file edit, not a stage gate. A correction to the architecture or to a prior stage design follows the standard stage workflow.
