# Stage 38 Manager design gate

Date: 2026-07-11
Owner: Manager
Verdict: PASS

## Inputs reviewed

- Stage intake:
  `._design_docs/.manager-inputs/manager-input-20260711-stage38-prefix-checkpoint-partial-restore.md`
- Design entry:
  `._design_docs/cache-handling-phase38-design.md`
- Design parts 1 through 3:
  prefix/checkpoint partial restore, cold-budget gauge fix, observability and
  tests
- Independent design review:
  `._design_docs/cache-handling-phase38-design/part-04-design-review-20260711.md`
- Design correction:
  `._design_docs/cache-handling-phase38-design/part-05-design-correction-20260711.md`
- Independent design re-review:
  `._design_docs/cache-handling-phase38-design/part-06-design-re-review-20260711.md`

## Gate checklist

| Check | Result | Evidence |
| --- | --- | --- |
| Scope covers user directives | PASS | Design covers safe chat strict-prefix/checkpoint partial restore and D36-FU-01 cold-budget gauge fix. |
| Prerequisites and assumptions explicit | PASS | Entry document records Stage 35, Stage 36, Stage 17, architecture, and Stage 25 prerequisites. |
| Interfaces and constraints explicit | PASS | Entry and parts define restore plan fields, slot cache accounting, suffix processing, metrics, cold-budget stats, and exclusions. |
| Observability and testability explicit | PASS | Part 3 records bounded metrics, token reporting, and TP-38 rows including gauge boundary values. |
| Review findings closed | PASS | Part 6 records F38-DESIGN-01 and F38-DESIGN-02 closed with no new blocking contradictions. |
| Documentation hygiene | PASS | Stage 38 docs are indexed, under the 300-line cap, ASCII, and `git diff --check` clean at gate time. |

## Manager decision

D38-DESIGN-01: Manager accepts the corrected Stage 38 design.

The approved baseline includes both scoped fixes:

- safe strict-prefix/checkpoint partial restore for `/v1/chat/completions` and
  shared cache-controller paths used by it;
- cold-budget gauge correction so a 2048 MiB hybrid cold budget reports
  `2147483648` bytes, not `-2147483648`.

The approved baseline also carries these binding constraints:

- `/completion` prefix restore is out of scope for Stage 38 and must recompute
  with a bounded unsafe or fallback reason;
- public prompt-token totals remain the full request prompt length;
- only cache-specific fields report the restored prefix length;
- checkpoint-dependent, SWA, recurrent, RS-limited, target-plus-draft, and MTP
  paths restore only from checkpoint-safe points.

## Handoff

Design gate is closed PASS.

Next owner: Developer.

Next gate: implementation planning.
