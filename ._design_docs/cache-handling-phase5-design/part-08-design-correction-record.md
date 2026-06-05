# Phase 5 design: payload-metadata separation and target/draft pairing - Part 8: Design correction record

Source: [../cache-handling-phase5-design.md](../cache-handling-phase5-design.md)

## Correction scope

Correction date: May 27, 2026

This record addresses the blocking finding from [Part 7](part-07-independent-design-review.md): `target_and_draft` restore claimed atomic behavior but did not define the recovery contract when target restore succeeded and draft restore failed.

No code was reviewed or changed. No implementation plan was created.

## Design changes

Updated design parts:

- [Part 3](part-03-save-restore-eviction-and-pairing-behavior.md) now defines the transactional restore contract.
- [Part 4](part-04-validation-diagnostics-and-observability.md) now names the restore failure phases, fallback behavior, diagnostics, and metrics.
- [Part 5](part-05-testability-and-requirement-traceability.md) now requires failure-injection tests for draft failure after target success and related no-hit accounting.
- [Part 6](part-06-exclusions-risks-and-review-readiness.md) now records the corrected gate status.

## Corrected restore contract

For `target_and_draft`, restore is one transaction. Descriptor validation and payload validation must finish before any live slot mutation. The restore applier must then use scratch staging or an equivalent pre-restore live-slot snapshot.

If target apply succeeds and draft apply fails, the live slot must end in its pre-restore state. The controller must reject the cache hit, emit restore failure and fallback diagnostics or metrics, and run the slower fallback path. It must not leave a target-restored and draft-old pair, refresh recency, update usage, or count an exact-blob hit.

`target_only` uses the same transaction boundary with only the target side required.

## Re-review checklist

Independent re-review should confirm:

- every restore failure point has one documented fallback state
- draft failure after target success cannot leave a half-restored live slot
- metrics and diagnostics identify the failing transaction phase
- tests can inject validation failure, target apply failure, draft apply failure, and commit failure
- no implementation plan or code requirement is embedded beyond the behavior and test contract

## Handoff

State: ready for independent re-review.

Implementation handoff remains closed until the independent re-review accepts this correction and the manager opens implementation planning.
