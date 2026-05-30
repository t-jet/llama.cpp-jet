# Phase 6 implementation log: cold layer and asynchronous I/O

Status: Implementation planning in progress
Planning date: May 30, 2026
Design document: [cache-handling-phase6-design.md](cache-handling-phase6-design.md)
Architecture document: [cache-handling-architecture.md](cache-handling-architecture.md)
Requirements document: [cache-handling-requirements.md](cache-handling-requirements.md)

## Scope

This log tracks Stage 6 implementation planning and evidence for cold payload storage and the
asynchronous I/O worker.

Stage 6 adds two new modules (`server_cache_store_cold` and `server_cache_io_worker`) to the Stage
5 hybrid cache and wires them into `hybrid_cache_controller`. Payloads evicted from hot RAM can be
written to a versioned filesystem store and restored on demand. The cold layer is disabled unless
the operator provides `--cache-cold-path`. When unconfigured, the server behaves identically to
Stage 5.

The plan starts from the approved Stage 6 design gate decision in
[Part 9](cache-handling-phase6-design/part-09-manager-design-gate.md) of the design document set
and the accepted baseline design in Parts 1 through 7 of the same document set.

## Contents

Read the implementation plan before changing any cache code.

- [Part 1: Implementation plan (steps 1-5, design baseline, NB resolutions, store_ref decision)](cache-handling-phase6-implementation/part-01-implementation-plan.md)
- [Part 2: Implementation plan continued (steps 6-12, known risks, evidence plan)](cache-handling-phase6-implementation/part-02-implementation-plan-continued.md)
- [Part 3: Independent plan review](cache-handling-phase6-implementation/part-03-independent-plan-review.md)

## Stage gate

Status: REWORK required. Independent Architect review returned REWORK on May 30, 2026.
One blocking finding (BF-1: Steps 6 and 7 missing dependency on Step 8). Code work remains
closed until the plan is corrected and re-reviewed.

Review: [Part 3: Independent plan review](cache-handling-phase6-implementation/part-03-independent-plan-review.md)

Gate reference: Manager design gate in
[cache-handling-phase6-design/part-09-manager-design-gate.md](cache-handling-phase6-design/part-09-manager-design-gate.md).
