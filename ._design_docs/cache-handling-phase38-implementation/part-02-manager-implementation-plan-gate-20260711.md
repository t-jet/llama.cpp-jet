# Stage 38 Manager implementation-plan gate

Date: 2026-07-11
Owner: Manager
Verdict: PASS

## Inputs reviewed

- Approved design baseline:
  `._design_docs/cache-handling-phase38-design.md`
- Manager design gate:
  `._design_docs/cache-handling-phase38-design/part-07-manager-design-gate-20260711.md`
- Developer implementation plan:
  `._design_docs/cache-handling-phase38-implementation.md`
- Independent implementation-plan review:
  `._design_docs/cache-handling-phase38-implementation/part-01-implementation-plan-review-20260711.md`

## Gate checklist

| Check | Result | Evidence |
| --- | --- | --- |
| Approved design baseline is explicit | PASS | Implementation plan cites Manager design gate constraints. |
| Ordered steps are explicit | PASS | Plan lists cold-budget tracing/fix, prefix candidate selection, checkpoint gating, apply/suffix processing, observability, and tests. |
| Affected code and tests are explicit | PASS | Plan names server cache, context, slot, task, and controller-test anchors. |
| Evidence plan is explicit | PASS | Plan records focused build/test commands, clean-build rule, live chat evidence, and gauge evidence. |
| Known risks are explicit | PASS | Plan records fail-safe recompute, exact-restore priority, isolated metric fix, legacy exclusion, and rollback controls. |
| Independent review passed | PASS | Part 1 records Architect implementation-plan review PASS with no required corrections. |

## Manager decision

D38-PLAN-01: Manager accepts the Stage 38 implementation plan.

Developer may implement the approved Stage 38 scope:

- safe strict-prefix/checkpoint partial restore for `/v1/chat/completions` and
  shared cache-controller paths used by it;
- cold-budget gauge correction for the 2048 MiB negative value.

Binding constraints remain:

- `/completion` prefix restore remains out of scope and must recompute;
- public prompt-token totals remain full request length;
- only cache-specific fields report restored prefix length;
- checkpoint-dependent profile restores require checkpoint-safe points;
- no commit or push is authorized.

## Handoff

Implementation-plan gate is closed PASS.

Next owner: Developer.

Next gate: implementation.
