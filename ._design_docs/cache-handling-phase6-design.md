# Phase 6 design: cold layer and asynchronous I/O

Status: Draft
Date: May 30, 2026
Architecture document: [cache-handling-architecture.md](cache-handling-architecture.md)
Requirements document: [cache-handling-requirements.md](cache-handling-requirements.md)
Stage definition: [Stage 6: Cold Layer and Asynchronous I/O](cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md#stage-6-cold-layer-and-asynchronous-io)

## Scope

Phase 6 adds cold payload storage and an asynchronous I/O worker on top of the descriptor and pairing contract delivered by Stage 5. Payloads that are evicted from hot RAM can be written to a versioned filesystem store and restored on demand. The cold layer is disabled unless an explicit configuration option provides a store root. All cold I/O runs outside the `server_context` thread.

The design stays at the Stage 6 gate. It does not include an implementation plan, code changes, test scripts, or branch graph topology. Those remain later-stage or separate-phase work.

## Contents

This document is split into smaller part files. Read the parts in order when reviewing the Stage 6 design.

- [Part 1: Scope, prerequisites, and assumptions](./cache-handling-phase6-design/part-01-scope-prerequisites-and-assumptions.md)
- [Part 2: Interfaces, components, and data model](./cache-handling-phase6-design/part-02-interfaces-components-and-data-model.md)
- [Part 3: Promotion, demotion, and persistence behavior](./cache-handling-phase6-design/part-03-promotion-demotion-and-persistence-behavior.md)
- [Part 4: Async I/O worker design](./cache-handling-phase6-design/part-04-async-io-worker-design.md)
- [Part 5: Validation, diagnostics, and observability](./cache-handling-phase6-design/part-05-validation-diagnostics-and-observability.md)
- [Part 6: Testability and requirement traceability](./cache-handling-phase6-design/part-06-testability-and-requirement-traceability.md)
- [Part 7: Exclusions, risks, and review readiness](./cache-handling-phase6-design/part-07-exclusions-risks-and-review-readiness.md)
- [Part 8: Independent design review](./cache-handling-phase6-design/part-08-independent-design-review.md)
- [Part 9: Manager design gate](./cache-handling-phase6-design/part-09-manager-design-gate.md)

## Stage gate

Status: Design gate accepted; implementation planning open.

Independent design review in [Part 8](./cache-handling-phase6-design/part-08-independent-design-review.md) returned PASS. No blocking findings. Five non-blocking observations (NB-1 through NB-5) are recorded in Part 8 for the implementation plan to address.

Manager design gate in [Part 9](./cache-handling-phase6-design/part-09-manager-design-gate.md) accepts the design and opens implementation planning. Code work remains closed until the implementation plan passes independent Architect review and manager approval.
