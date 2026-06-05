# Stage 8 test-plan review - 2026-06-01

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

Reviewer: QA agent
Verdict: PASS

## Scope reviewed

This was an independent review of the Stage 8 metadata-only re-materialization
test plan. QA execution is not open yet.

Documents reviewed:

- [document-index.md](../document-index.md)
- [cache-handling-test-plan.md](../cache-handling-test-plan.md)
- [Part 10: Stage 8 metadata-only re-materialization](part-10-stage8-metadata-only-rematerialization.md)
- Related plan parts 1, 2, 5, 6, and 9
- [Stage 8 design](../cache-handling-phase8-design.md) and Parts 1 through 5
- [Stage 8 implementation](../cache-handling-phase8-implementation.md)
- [Stage 8 architect implementation re-review](../cache-handling-phase8-implementation/part-10-architect-implementation-re-review-20260601.md)

## Verdict

PASS. The Stage 8 test plan is current, generic, executable, and aligned with
the accepted implementation scope.

The plan covers metadata-only retention, re-materialization, mismatch handling,
equivalent branch deduplication, branch metadata admission rejection, cold
cleanup ownership, Stage 8 metrics labels, Stage 4-7 regression, clean-build
rules, report evidence, and the Windows preload workaround limits.

## Findings

No blocking findings.

Review findings:

- Stage 8 exclusions are correct. Checkpoint-first restore, public
  metadata-budget flags, public `/cache/stats` success, public branch metadata
  request controls, separate public budget flags, cross-restart branch graph
  restore, and tolerant namespace matching remain future-stage scope.
- Stale Stage 8 exclusion text was removed or narrowed. Part 9 still excludes
  metadata-only behavior only inside the Stage 7 row set and points Stage 8
  acceptance to Part 10.
- Evidence classification is clear. Focused Stage 8 and controller tests are
  required for internal graph states. Public HTTP is limited to model-backed
  regression, public surface checks, and metrics snapshots. Python metric-shape
  evidence can cover Prometheus names and labels only.
- Re-materialization rows cannot pass from metric presence alone. The plan
  requires the selected metadata-only node, validation result, restore source,
  and post-operation metadata or payload state.
- Branch metadata pressure and cold cleanup rows correctly require focused,
  stats-capable, or fault-injection evidence when public HTTP cannot create the
  precondition.
- Clean-build rules are explicit and include `llama-server`,
  `test-cache-controller`, `test-step12-branch-graph`, and
  `test-step13-stage8`.
- `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` is limited to Windows startup,
  public surface, and Prometheus metric-label evidence. The plan forbids using
  it for model-backed save, restore, hit, miss, eviction, or
  re-materialization behavior.
- The plan does not contain run-specific execution results. It directs
  execution evidence to a fresh `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`
  file.
- The reviewed markdown files are under 300 lines and use ASCII status labels.

## Checklist result

| Check | Result |
| --- | --- |
| Scope matches accepted Stage 8 implementation re-review | PASS |
| Metadata-only retention and topology preservation are covered | PASS |
| Re-materialization success, failure, and source selection are covered | PASS |
| Token or checksum mismatch and mismatch-parent selection are covered | PASS |
| Equivalent same-namespace deduplication and cross-namespace rejection are covered | PASS |
| Branch metadata admission rejection is covered | PASS |
| Cold cleanup ownership and shared-owner blocking are covered | PASS |
| Stage 8 metrics names and labels are listed | PASS |
| Stage 4-7 regression remains in scope | PASS |
| Clean build and stale-binary rejection rules are present | PASS |
| Report format and evidence-source mapping are clear | PASS |
| Windows preload workaround limits are explicit | PASS |
| Future-stage exclusions remain correct | PASS |
| Plan is generic and does not depend on a specific run | PASS |
| Markdown line-count and ASCII checks pass | PASS |

## Handoff

Status: READY for manager review of the Stage 8 QA plan gate.

Manager can open QA execution after accepting this test-plan review.
