# Phase 5 implementation log: payload-metadata separation and target/draft pairing

Status: Stage 5 closed  
Planning date: May 27, 2026  
Design document: [cache-handling-phase5-design.md](cache-handling-phase5-design.md)  
Architecture document: [cache-handling-architecture.md](cache-handling-architecture.md)  
Requirements document: [cache-handling-requirements.md](cache-handling-requirements.md)

## Scope

This log tracks Stage 5 implementation planning and later implementation evidence for payload descriptor separation, hot payload byte ownership, descriptor validation, and target/draft pair enforcement.

This entry records the executable plan opened after the Stage 5 design gate passed independent re-review and manager approval, followed by implementation evidence and review results.

## Contents

Read the planning part before changing cache code.

- [Part 1: Implementation plan](cache-handling-phase5-implementation/part-01-implementation-plan.md)
- [Part 2: Independent implementation-plan review](cache-handling-phase5-implementation/part-02-independent-implementation-plan-review.md)
- [Part 3: Implementation-plan re-review](cache-handling-phase5-implementation/part-03-implementation-plan-re-review.md)
- [Part 4: Implementation-plan second re-review](cache-handling-phase5-implementation/part-04-implementation-plan-second-re-review.md)
- [Part 5: Manager implementation-plan gate](cache-handling-phase5-implementation/part-05-manager-implementation-plan-gate.md)
- [Part 6: Implementation evidence](cache-handling-phase5-implementation/part-06-implementation-evidence.md)
- [Part 7: Implementation review](cache-handling-phase5-implementation/part-07-implementation-review.md)
- [Part 8: Review-fix evidence](cache-handling-phase5-implementation/part-08-review-fix-evidence.md)
- [Part 9: Implementation re-review](cache-handling-phase5-implementation/part-09-implementation-re-review.md)
- [Part 10: Test-hook review](cache-handling-phase5-implementation/part-10-implementation-test-hook-review.md)
- [Part 11: Stage closure decision](cache-handling-phase5-implementation/part-11-stage-closure-decision.md)
- [Part 12: Draft-context compatibility review](cache-handling-phase5-implementation/part-12-draft-context-compatibility-review.md)
- [Part 13: BUG-001 startup fix review](cache-handling-phase5-implementation/part-13-bug-001-startup-fix-review.md)
- [Part 14: Final documentation reconciliation](cache-handling-phase5-implementation/part-14-final-documentation-reconciliation.md)
- [Part 15: BUG-002 MTP restore timing fix](cache-handling-phase5-implementation/part-15-bug-002-mtp-restore-timing.md)
- [Part 16: BUG-002 restore timing implementation review](cache-handling-phase5-implementation/part-16-bug-002-implementation-review.md)

## Current status

Stage 5 design re-review passed on May 27, 2026. The accepted baseline is the corrected design in [Phase 5 design Part 9](cache-handling-phase5-design/part-09-independent-design-re-review.md): target-plus-draft restore is one transaction, descriptor and payload validation happen before live mutation, and a failed target, draft, commit, or rollback path must not report a cache hit or refresh recency.

The manager design gate in [Phase 5 design Part 10](cache-handling-phase5-design/part-10-manager-design-gate.md) accepts the design and opens implementation planning. Code work remains closed until the implementation plan passes independent review and manager approval.

No code has been changed for Stage 5 in this planning task. The current hybrid implementation still stores exact blob bytes directly in `hybrid_cache_entry::data`, and the implementation plan starts from that state.

The independent implementation-plan review in [Part 2](cache-handling-phase5-implementation/part-02-independent-implementation-plan-review.md) returned REWORK. The plan content matches the approved design, but the document set did not record the manager gate approval required by the Phase 5 design before implementation planning opens. That missing gate record is now added in [Phase 5 design Part 10](cache-handling-phase5-design/part-10-manager-design-gate.md).

The implementation-plan re-review in [Part 3](cache-handling-phase5-implementation/part-03-implementation-plan-re-review.md) returned REWORK because [Phase 5 design Part 6](cache-handling-phase5-design/part-06-exclusions-risks-and-review-readiness.md) still had stale pre-gate wording. That wording now points to the manager gate in [Phase 5 design Part 10](cache-handling-phase5-design/part-10-manager-design-gate.md).

The second implementation-plan re-review in [Part 4](cache-handling-phase5-implementation/part-04-implementation-plan-second-re-review.md) returned PASS. The Part 2 missing manager gate blocker and the Part 3 stale Part 6 wording blocker are both resolved. No new content-level implementation-plan blocker was found.

The manager implementation-plan gate in [Part 5](cache-handling-phase5-implementation/part-05-manager-implementation-plan-gate.md) returned PASS and opened Developer implementation work for the accepted plan.

Implementation evidence is recorded in [Part 6](cache-handling-phase5-implementation/part-06-implementation-evidence.md). The code now has descriptor-owned exact blob payloads, hot payload records, descriptor validation, target/draft pair validation, restore rollback handling, Stage 5 stats and Prometheus metrics, and focused controller and metrics-shape tests.

The implementation review in [Part 7](cache-handling-phase5-implementation/part-07-implementation-review.md) returned REWORK. The documented rollback limitation was a blocking design-conformance issue because the accepted Stage 5 design requires exact pre-restore rollback or scratch staging before fallback. Production rollback now restores serialized pre-images when available and clears a target or draft sequence when that side had no serialized pre-restore bytes. It checks the clear path before applying target bytes, so an unsupported empty-side rollback fails before payload restore. The fix evidence is in [Part 8](cache-handling-phase5-implementation/part-08-review-fix-evidence.md).

The implementation re-review in [Part 9](cache-handling-phase5-implementation/part-09-implementation-re-review.md) returned PASS. The reviewer accepted `llama_memory_seq_rm(..., seq_id, -1, -1)` as an exact empty-side rollback primitive for the supported memory backends, verified that unsupported clear paths fail before payload apply, and found no remaining half-restored target/draft rollback blocker.

After QA report `test-report-20260528-02.md` blocked Stage 5 on missing focused evidence, Developer added descriptor fault-injection and rollback/clear preflight coverage. The independent test-hook review in [Part 10](cache-handling-phase5-implementation/part-10-implementation-test-hook-review.md) returned PASS.

QA rerun `test-report-20260528-03.md` returned PASS with one fixture SKIP. The 12 blocked rows from `test-report-20260528-02.md` are reconciled as passing focused or fault-injection evidence in the rerun. H43 remains skipped only because no external public target-plus-draft draft-model fixture was configured.

The manager closure decision in [Part 11](cache-handling-phase5-implementation/part-11-stage-closure-decision.md) closes Stage 5. No unresolved review finding, product bug, or QA blocker remains for the implemented scope.

The draft-context compatibility review in [Part 12](cache-handling-phase5-implementation/part-12-draft-context-compatibility-review.md) returned PASS. The compatibility key now distinguishes no draft, normal separate draft model, target-derived MTP, and separate-model MTP modes without changing speculative decoding semantics, legacy behavior, or public API shape.

QA report `test-report-20260528-06.md` passed the accepted compatibility-key coverage and public target-only plus normal separate-draft cache probes, but blocked both public MTP probes before `/health`. Developer triage in [test-report-20260528-06-fixes.md](.test_reports/test-report-20260528-06-fixes.md) classified target-derived MTP as a model-capability blocker for the local Qwen3-8B target. The separate-model MTP access violation was a narrow startup null-check bug in the draft-context creation path, not a cache restore bug; startup now returns a normal model-loading error when the requested draft MTP context cannot be created. Verification rebuilt `llama-server`, confirmed separate-model MTP exits cleanly with code `1`, and confirmed normal separate draft-model startup still reaches `/health`.

The independent BUG-001 review in [Part 13](cache-handling-phase5-implementation/part-13-bug-001-startup-fix-review.md) returned PASS. The null-check fix is limited to the separate draft-model startup path after `llama_init_from_model`; it prevents the null dereference before `common_context_can_seq_rm()` without changing cache semantics. Public MTP cache rows remain blocked for the local Qwen3 models because both MTP startup modes fail before `/health` with models that do not provide the required MTP layers.

QA rerun `test-report-20260528-07.md` confirmed the final state: clean build passed, normal separate draft-model startup still reached `/health`, H53 and H54 failed cleanly before `/health` because the local models lack MTP layers, and the prior H54 access violation did not reproduce. The final reconciliation in [Part 14](cache-handling-phase5-implementation/part-14-final-documentation-reconciliation.md) preserves the closure classification: compatibility-key update accepted, BUG-001 fix accepted, public MTP cache coverage blocked on an MTP-capable fixture, and normal `--model-draft` / `--spec-draft-model` coverage available with Qwen3-8B plus Qwen3-0.6B.

QA rerun `test-report-20260528-08.md` used the Qwen3.5 MTP fixture and unblocked H53/H54 startup, but exposed BUG-002: hybrid metrics counted a successful restore while public responses still reported `timings.cache_n=0`. The fix in [Part 15](cache-handling-phase5-implementation/part-15-bug-002-mtp-restore-timing.md) carries successful exact hybrid restores into prompt reuse and avoids replay fallback over the restored exact state. Developer rerun evidence shows H53 request 2 with `cache_n=11`, H54 request 2 with `cache_n=12`, one hit, one miss, and zero restore or fallback failures in both modes.

The independent BUG-002 implementation review in [Part 16](cache-handling-phase5-implementation/part-16-bug-002-implementation-review.md) returned PASS. The review found the restore marker scoped to successful exact hybrid restores, cleared on slot reset and prompt clear, and safe across failed restore, legacy mode, cache-disabled startup, prompt misses, and normal separate draft mode. No correction is required before QA rerun.

QA confirmation rerun `test-report-20260528-09.md` passed H53 and H54 with the Qwen3.5 MTP fixture. H53 request 2 reported `cache_n=11`; H54 request 2 reported `cache_n=12`. Both runs had one hit, one miss, one hot payload descriptor, and zero restore failures, descriptor validation failures, pairing violations, or fallback restores.

## Handoff state

State: Stage 5 closed with BUG-002 QA confirmation passed for public H53/H54 acceptance.

Current owner: none.

Residual follow-up: none for H53/H54 with the Qwen3.5 MTP fixture. Runs that select Qwen3-only models without MTP layers should still classify public MTP rows as fixture-blocked.
