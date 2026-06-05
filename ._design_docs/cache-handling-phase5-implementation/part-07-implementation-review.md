# Phase 5 implementation: implementation review

Source: [../cache-handling-phase5-implementation.md](../cache-handling-phase5-implementation.md)

## Review scope

Review date: May 27, 2026

Reviewed baseline:

- [Phase 5 design entry](../cache-handling-phase5-design.md) and Parts 1-10
- [Phase 5 implementation entry](../cache-handling-phase5-implementation.md)
- [Part 1: Implementation plan](part-01-implementation-plan.md)
- [Part 4: Implementation-plan second re-review](part-04-implementation-plan-second-re-review.md)
- [Part 5: Manager implementation-plan gate](part-05-manager-implementation-plan-gate.md)
- [Part 6: Implementation evidence](part-06-implementation-evidence.md)

Reviewed code and tests:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

This was an implementation review only. No code fixes were made.

## Verdict

REWORK.

The implementation mostly follows the Stage 5 structure: payload descriptors are separate from hot payload records, descriptors have singular owner IDs, restore validation checks pair state and checksums, eviction removes paired payload bytes together, Stage 4 budget accounting still uses resident payload bytes, and the metrics shape exposes the new Stage 5 counters and gauges.

One blocking design-conformance issue remains in production restore rollback. The documented limitation for empty pre-restore sides is not acceptable under the approved design because the design requires either scratch staging or exact pre-restore snapshot rollback before fallback.

## Blocking finding

### Finding 1: production rollback is not exact when the pre-restore state has no serialized byte image

The accepted design requires exact rollback. Phase 5 design Part 3 says a live-apply implementation must snapshot the pre-restore live target and draft state before applying either side, restore that snapshot on target, draft, or commit failure, and leave the live slot in the exact pre-restore state. It also says a reset-to-empty fallback is not acceptable unless that was the pre-restore slot state or a later design proves the slower path starts that way.

The production restore path captures pre-restore serialized state only when `llama_state_seq_get_size_ext(...)` returns a positive size. The rollback lambda restores target or draft bytes only when the captured vector is non-empty:

- `tools/server/server-context.cpp:5424` through `tools/server/server-context.cpp:5441`
- `tools/server/server-context.cpp:5550` through `tools/server/server-context.cpp:5567`

If the pre-restore target side was empty, target restore can still apply cache bytes at `tools/server/server-context.cpp:5452` through `tools/server/server-context.cpp:5458`. If draft restore then fails at `tools/server/server-context.cpp:5480` through `tools/server/server-context.cpp:5486`, rollback restores slot metadata but has no target byte image to apply, so the target KV state may remain restored. The same pattern exists in `load_slot` at `tools/server/server-context.cpp:5577` through `tools/server/server-context.cpp:5610`.

This violates the approved contract in `._design_docs/cache-handling-phase5-design/part-03-save-restore-eviction-and-pairing-behavior.md:47` through `:55`, especially the requirements for equivalent pre-restore snapshot rollback and exact pre-restore state after draft failure. It also misses the test obligation in `._design_docs/cache-handling-phase5-design/part-05-testability-and-requirement-traceability.md:40` and `:55`, because the current focused test only proves a debug transaction counter path, not the production live-slot rollback behavior.

Required correction:

- Implement a production rollback path that can restore or clear each target/draft side to the exact pre-restore live state, including empty pre-restore sides, or switch production restore to true scratch staging.
- If the llama state API cannot express exact empty-state rollback, update the Stage 5 design and get it re-reviewed before claiming implementation conformance.
- Add a production-facing failure-injection test or live-slot probe that proves draft failure after target apply leaves no half-restored target/draft pair.
- Keep failed transaction paths from refreshing recency, usage, or hit metrics.

Acceptance check:

- A reviewer can trace every production restore failure point to exact pre-restore state recovery or an approved design exception.

## Non-blocking observations

- Descriptor ownership and validation are in place. `payload_descriptor` and `hot_payload_record` are distinct in `tools/server/server-cache-hybrid.h:75` through `:96`, and restore validation checks owner, version, kind, store reference, residency, pair state, sizes, and checksums in `tools/server/server-cache-hybrid.cpp:572` through `:642`.
- Target/draft pairing is enforced conservatively by runtime shape in `tools/server/server-cache-hybrid.cpp:553` through `:569`.
- Evicted descriptors are retained only as non-restorable diagnostics in `tools/server/server-cache-hybrid.cpp:528` through `:541`, which matches the Stage 5 boundary.
- The test suite covers descriptor creation, pair mismatch, checksum failure, evicted descriptor rejection, descriptor byte accounting, failure counters, and metrics shape. It does not close the production rollback blocker above.
- The implementation evidence correctly records the rollback limitation in Part 6. Documentation of the limitation is useful, but it does not waive the accepted design contract.

## Required corrections

- Fix the production rollback behavior or correct the durable design through the normal review loop.
- Add test evidence for the corrected production behavior.
- Update Part 6 evidence after the correction, including exact build and test commands and results.

## Handoff

State: rework required.

Next owner: Developer for correction, then Architect re-review. Stage 5 is not ready for QA sign-off while Finding 1 is open.
