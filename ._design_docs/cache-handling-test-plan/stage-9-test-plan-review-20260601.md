# Stage 9 test-plan review - 2026-06-01

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

Reviewer: QA agent
Verdict: PASS

## Scope reviewed

This was an independent review of the Stage 9 checkpoint integration and
workload profile test plan. QA execution is not open yet.

Documents reviewed:

- [document-index.md](../document-index.md)
- [cache-handling-test-plan.md](../cache-handling-test-plan.md)
- [Part 11: Stage 9 checkpoint integration](part-11-stage9-checkpoint-integration.md)
- [cache-handling-test-scripts/README.md](../cache-handling-test-scripts/README.md)
- [Stage 9 design](../cache-handling-phase9-design.md) and Parts 1 through 5
- [Stage 9 implementation](../cache-handling-phase9-implementation.md)
- [Stage 9 cold checkpoint restore corrections](../cache-handling-phase9-implementation/part-09-cold-checkpoint-restore-corrections-20260601.md)
- [Stage 9 architect implementation re-review](../cache-handling-phase9-implementation/part-10-architect-implementation-re-review-20260601.md)

## Verdict

PASS. The Stage 9 test plan is current, generic, and aligned with the accepted
implementation scope and evidence limits.

The plan covers workload profile detection, namespace isolation, checkpoint
descriptor admission, rollback and replacement, checkpoint-first and exact-first
ranking, cold checkpoint promotion, target/draft checkpoint validation,
checkpoint budget behavior, cleanup ownership, public boundary propagation,
metrics evidence, model-backed fixture handling, and Stage 4-8 regression.

## Findings

No blocking findings.

Review findings:

- Scope matches the accepted Stage 9 implementation re-review. S9-IMPL-06 and
  S9-IMPL-07 are reflected through cold checkpoint promotion rows and restore
  metric label expectations.
- Evidence classification is clear. `test-cache-controller` covers controller
  preconditions, `test-step10-metrics` covers Prometheus shape, branch graph and
  Stage 8 targets cover regression rows where mapped, and public HTTP is limited
  to rows it can actually prove.
- Model-backed checkpoint-dependent HTTP remains a known evidence limit. Q103
  can pass only with a suitable SWA, recurrent, hybrid, or MTP fixture; otherwise
  the report must mark it `BLOCKED` or `SKIP` by local fixture policy and cite
  substitute focused evidence.
- Public `/metrics` evidence is handled correctly. Q102 asks for a live scrape
  when a fixture can exercise it, while focused metrics evidence remains an
  acceptable substitute for metric shape when no model-backed fixture exists.
- Positive, negative, public, focused, metrics, fixture/substitute, and Stage 4-8
  regression coverage are all present in Q90-Q112.
- Clean-build and stale-binary rules are explicit. Stage 9 execution requires a
  fresh build of `llama-server`, `test-cache-controller`, `test-step10-metrics`,
  `test-step12-branch-graph`, and `test-step13-stage8`.
- `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` is limited to startup, public surface,
  and metric-shape rows. The plan and README both forbid using it as evidence for
  model-backed checkpoint save, restore, hit, miss, promotion, demotion,
  eviction, or boundary propagation.
- The scripts README matches the plan. It states that the main runner has no
  dedicated Stage 9 matrix yet and that Q103 cannot pass without a
  checkpoint-dependent model fixture.
- The plan does not include run-specific results. It directs execution evidence
  to a fresh `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` file.
- The reviewed markdown files are under 300 lines and use ASCII status labels.

## Checklist result

| Check | Result |
| --- | --- |
| Scope matches accepted Stage 9 implementation re-review | PASS |
| Positive checkpoint and workload profile rows are covered | PASS |
| Negative descriptor, boundary, promotion, and leak rows are covered | PASS |
| Public boundary and public `/metrics` evidence limits are explicit | PASS |
| Focused controller and metrics evidence sources are mapped | PASS |
| Fixture-unavailable substitute evidence is handled | PASS |
| Stage 4-8 regression remains in scope | PASS |
| Clean build and stale-binary rejection rules are present | PASS |
| Report format and evidence-source mapping are clear | PASS |
| Wording is generic and not tied to a specific run | PASS |
| Scripts README guidance matches the plan | PASS |
| Markdown line-count and ASCII checks pass | PASS |

## Next action

Next owner: Manager.

Handoff state: READY for manager review of the Stage 9 QA plan gate.
