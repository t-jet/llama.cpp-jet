# Phase 5 design: payload-metadata separation and target/draft pairing - Part 9: Independent design re-review

Source: [../cache-handling-phase5-design.md](../cache-handling-phase5-design.md)

## Review scope

Review date: May 27, 2026

Reviewed documents:

- [Phase 5 design entry](../cache-handling-phase5-design.md)
- [Part 1: Scope, prerequisites, and assumptions](part-01-scope-prerequisites-and-assumptions.md)
- [Part 2: Interfaces, components, and data model](part-02-interfaces-components-and-data-model.md)
- [Part 3: Save, restore, eviction, and pairing behavior](part-03-save-restore-eviction-and-pairing-behavior.md)
- [Part 4: Validation, diagnostics, and observability](part-04-validation-diagnostics-and-observability.md)
- [Part 5: Testability and requirement traceability](part-05-testability-and-requirement-traceability.md)
- [Part 6: Exclusions, risks, and review readiness](part-06-exclusions-risks-and-review-readiness.md)
- [Part 7: Independent design review](part-07-independent-design-review.md)
- [Part 8: Design correction record](part-08-design-correction-record.md)
- [Architecture entry](../cache-handling-architecture.md) and Stage 5 architecture text
- [Requirements entry](../cache-handling-requirements.md) and requirements R9, R10, R13, R34-R36, R90-R92, R104, and R105

This was a design re-review only. No code was reviewed or changed, and no implementation plan was created.

## Verdict

PASS.

The blocking Part 7 finding is resolved. The corrected design now defines `target_and_draft` restore as one transaction, requires descriptor and payload validation before live mutation, and requires either scratch staging or a pre-restore live-slot snapshot. If target apply succeeds and draft apply fails, the live slot must return to its pre-restore state before fallback. The design also rejects hit accounting, usage refresh, and recency refresh for the failed candidate.

## Blocking finding closure

Finding 1 from Part 7 is closed.

Closure basis:

- Part 3 defines pre-apply validation before staging.
- Part 3 requires scratch staging or a pre-restore live-slot snapshot before any live mutation.
- Part 3 states that draft apply failure after target apply success leaves the live slot in the exact pre-restore state.
- Part 3 gives `target_only` restore the same transaction boundary with only the target side required.
- Part 4 identifies target apply, draft apply, commit, and rollback failure phases for diagnostics and metrics.
- Part 5 requires failure-injection tests for validation failure, target failure, draft failure after target success, commit failure, fallback reporting, and no-hit accounting.

These changes satisfy the Part 7 acceptance check: a later implementation plan can point to one documented recovery behavior for validation failure, target apply failure, draft apply failure, and commit failure.

## Contradiction and scope check

No new contradiction was found.

The correction stays within Stage 5. It does not introduce cold storage, asynchronous I/O, branch graph behavior, checkpoint payload admission, CLI changes, code changes, or an implementation plan. The fallback text remains compatible with R34, R35, R90, and R91 because failed restore attempts must preserve inference correctness and use the slower path instead of exposing a half-restored slot.

The correction does not weaken Stage 4 behavior. Eviction still uses resident-byte accounting and keeps target and draft bytes as one unit.

## Testability check

No blocking testability gap remains at design level.

Part 5 now requires observable seams for restore applier failures and live-slot state probes or snapshots. The required test cases cover the failure that caused the original block: draft apply failure after target apply success must leave the live slot in its pre-restore state, report fallback, avoid exact-hit accounting, and avoid usage or recency refresh.

## Handoff

State: ready for manager gate review.

Implementation handoff is still closed until the manager accepts the design gate and explicitly opens implementation planning.
