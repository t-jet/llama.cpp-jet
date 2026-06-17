# Stage 17 manager design gate

Source: [../cache-handling-phase17-design.md](../cache-handling-phase17-design.md)
Date: 2026-06-17
Reviewer: Manager agent
Verdict: PASS

## Design review evidence

The independent design review is recorded in
[part-05-design-review-gate-01.md](part-05-design-review-gate-01.md).
Verdict: PASS. No blocking findings were raised.

Non-blocking findings:

- N17-01: choose the final cold-budget CLI name and prompt evidence file
  shape before code work starts.
- N17-02: keep prefix restore out of Stage 17 code scope unless Manager opens
  a separate approved scope change.

## Manager decisions

| ID | Decision | Reason |
| --- | --- | --- |
| D17-01 | Stage 17 implementation planning must use `--cache-cold-max-mib` as the cold payload budget option. | The design fixes the option semantics, and no conflicting local convention was found during design review. |
| D17-02 | Prompt evidence records use JSONL as the default durable format: one record per restore lookup. Raw mode may reference a separate raw prompt file by relative file name only. | JSONL supports long runs and append-only evidence without forcing many small files. |
| D17-03 | Prefix restore remains deferred. Stage 17 code may detect prefix candidates and classify them as `unsafe_prefix_rejected`, but must not apply prefix restore. | The design intentionally keeps correctness ahead of hit rate until full prefix validation has a separate approved scope. |

## Manager gate checks

| Check | Result | Notes |
| --- | --- | --- |
| Design docs are reviewable and indexed | PASS | Entry doc, four design parts, design review, and this gate record exist. `document-index.md` references the Stage 17 design. |
| Scope, prerequisites, assumptions, interfaces, constraints, observability, and testability are documented | PASS | Parts 1-4 cover restore misses, prompt evidence, exact/prefix policy, checkpoint admission, cold budget, observability, QA hooks, acceptance, and traceability. |
| Architecture and requirements traceability is explicit | PASS | Part 4 maps the design to requirements R4a through R133, with constrained prefix-restore scope called out. |
| Prerequisite gaps, contradictions, and risks are explicit | PASS | Stage 16 evidence is treated as scope input, not a reopened Stage 16 gate. The review found no contradictions. |
| Review is recorded with a pass verdict | PASS | Part 5 records PASS with no blocking findings. |
| Non-blocking findings are actionable and assigned | PASS | D17-01 through D17-03 resolve N17-01 and N17-02 for implementation planning. |

## Advisory carry-forward

The implementation plan must address:

- the `--cache-cold-max-mib` CLI wiring and validation path
- JSONL prompt evidence records for raw and redacted evidence modes
- explicit exclusion of prefix restore code, except bounded
  `unsafe_prefix_rejected` classification
- focused tests and QA handoff rows for the synthetic, stress-longrun, and
  heavy manual tiers

## Decision

The Stage 17 design is approved. The Manager design gate is PASS.

## Handoff

Next gate: implementation planning (Developer).

The implementation plan must use the approved Stage 17 design baseline and
carry D17-01 through D17-03 into the plan. Implementation remains closed until
the implementation plan passes independent Architect review and Manager
approval.
