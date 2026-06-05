# Phase 5 implementation: final documentation reconciliation

Source: [../cache-handling-phase5-implementation.md](../cache-handling-phase5-implementation.md)

## Scope

Reconciliation date: May 28, 2026

This note closes the post-Stage-5 documentation pass after the draft-mode compatibility update, BUG-001 startup fix review, and QA rerun. It records the durable state so later readers do not need to reconstruct it from transient test reports.

Reviewed durable inputs:

- [Architecture Part 6](../cache-handling-architecture/part-06-stage-5-draft-context-modes-and-pairing.md)
- [Phase 5 implementation entry](../cache-handling-phase5-implementation.md)
- [Part 12: Draft-context compatibility review](part-12-draft-context-compatibility-review.md)
- [Part 13: BUG-001 startup fix review](part-13-bug-001-startup-fix-review.md)
- [Cache handling test plan](../cache-handling-test-plan.md)
- [Test script README](../cache-handling-test-scripts/README.md)

## Final state

Stage 5 remains closed.

The compatibility-key update is accepted. The cache namespace now separates no draft, normal separate draft model, target-derived MTP, and separate-model MTP runtime shapes. Pair state remains binary: no draft context uses `target_only`, and any active model-backed draft context uses `target_and_draft`.

The BUG-001 startup fix is accepted. The separate draft-model MTP startup path now handles failed draft-context creation as a normal model-loading error instead of dereferencing a null context. The fix does not change hybrid cache save, restore, pairing, rollback, metrics, or legacy behavior.

Public MTP cache coverage remains `BLOCKED` for the local Qwen3 model suite. The Qwen3-8B target and Qwen3-0.6B draft files used in this workspace do not provide the MTP layers needed to create either H53 target-derived MTP or H54 separate-model MTP contexts. Both rows fail before `/health`, so they cannot produce public save/restore evidence.

Normal separate draft-model coverage is available with the local Qwen3 fixtures. Qwen3-8B as target and Qwen3-0.6B as draft reached `/health` and produced public hybrid restore evidence through both `--model-draft` and `--spec-draft-model`.

## Documentation corrections

The test plan and script README should treat unsupported local MTP public rows as `BLOCKED`, not `SKIP`, when the Stage 5 acceptance row is in scope and the selected model or model pair cannot create the required MTP context. `SKIP` remains appropriate only for rows that are explicitly outside a session's selected scope.

The durable docs should not claim public MTP save/restore coverage until QA has an MTP-capable target model or draft pair and can show `/health`, repeated completion, `timings.cache_n > 0`, and matching cache metrics for the MTP runtime being tested.

## Handoff

State: closed.

Next owner: none for Stage 5 closure. Future QA work may add public H53/H54 evidence after an MTP-capable fixture is available.

## Qwen3.5 MTP follow-up

QA reran H53 and H54 in [test-report-20260528-08](../.test_reports/test-report-20260528-08.md) with the Qwen3.5 MTP fixture. Startup is no longer blocked: target-derived MTP and separate-model MTP both reached `/health`.

The rows still do not pass public cache acceptance. In both modes, the repeated request left `timings.cache_n=0` even though hybrid metrics reported one hit, one miss, one hot payload descriptor, and no restore or descriptor failures. Treat this as BUG-002 for Developer triage, not as the old missing-fixture blocker.

## BUG-002 QA confirmation

QA reran H53 and H54 after the BUG-002 fix in [test-report-20260528-09](../.test_reports/test-report-20260528-09.md). Both rows now pass with the Qwen3.5 fixture.

H53 target-derived MTP reached `/health`, missed once, then restored the repeated public request with `timings.cache_n=11`, one hit, one miss, one hot payload descriptor, and zero restore failures, descriptor validation failures, pairing violations, or fallback restores.

H54 separate-model MTP reached `/health`, missed once, then restored the repeated public request with `timings.cache_n=12`, one hit, one miss, one hot payload descriptor, and the same zero failure counters.

Durable state: public MTP cache coverage is no longer blocked when the Qwen3.5 MTP fixture is available. The older Qwen3-only fixture blocker still applies to runs that select models without MTP layers.
