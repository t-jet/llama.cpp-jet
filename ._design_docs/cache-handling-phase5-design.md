# Phase 5 design: payload-metadata separation and target/draft pairing

Status: Design gate accepted; implementation planning open  
Date: May 27, 2026  
Architecture document: [cache-handling-architecture.md](cache-handling-architecture.md)  
Requirements document: [cache-handling-requirements.md](cache-handling-requirements.md)  
Stage definition: [Stage 5: Payload-Metadata Separation](cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md#stage-5-payload-metadata-separation)

## Scope

Phase 5 defines the descriptor and pairing contract for hybrid cache payloads. It separates cache metadata from serialized payload bytes for exact full-state blobs and creates the rules that keep target and draft state together during save, restore, validation, and eviction.

The design stays at the Stage 5 gate. It does not add cold storage, asynchronous I/O, branch graph nodes, metadata-only nodes, checkpoint-first restore planning, or an implementation plan. Those remain later-stage work.

## Contents

This document is split into smaller part files. Read the parts in order when reviewing the Stage 5 design.

- [Part 1: Scope, prerequisites, and assumptions](./cache-handling-phase5-design/part-01-scope-prerequisites-and-assumptions.md)
- [Part 2: Interfaces, components, and data model](./cache-handling-phase5-design/part-02-interfaces-components-and-data-model.md)
- [Part 3: Save, restore, eviction, and pairing behavior](./cache-handling-phase5-design/part-03-save-restore-eviction-and-pairing-behavior.md)
- [Part 4: Validation, diagnostics, and observability](./cache-handling-phase5-design/part-04-validation-diagnostics-and-observability.md)
- [Part 5: Testability and requirement traceability](./cache-handling-phase5-design/part-05-testability-and-requirement-traceability.md)
- [Part 6: Exclusions, risks, and review readiness](./cache-handling-phase5-design/part-06-exclusions-risks-and-review-readiness.md)
- [Part 7: Independent design review](./cache-handling-phase5-design/part-07-independent-design-review.md)
- [Part 8: Design correction record](./cache-handling-phase5-design/part-08-design-correction-record.md)
- [Part 9: Independent design re-review](./cache-handling-phase5-design/part-09-independent-design-re-review.md)
- [Part 10: Manager design gate](./cache-handling-phase5-design/part-10-manager-design-gate.md)

## Stage gate

The Stage 5 design gate is accepted. The independent design review in Part 7 returned REWORK. The restore-atomicity correction is recorded in Parts 3, 4, 5, 6, and 8. The independent re-review in Part 9 returned PASS for the corrected target-plus-draft transactional restore behavior.

The manager gate decision in Part 10 opens implementation planning. Code work remains closed until the implementation plan passes independent review and manager approval.
