# Stage 8 implementation plan - Part 1

Source: [../cache-handling-phase8-implementation.md](../cache-handling-phase8-implementation.md)

## Status

Planning date: May 31, 2026
Plan state: approved by Architect re-review and Manager implementation-plan gate.
Implementation state: open.

The original single-file plan exceeded the 300-line document rule. The plan is
now split into this overview plus the linked step files below.

## Accepted design baseline

Implement Stage 8 against the accepted design in
[cache-handling-phase8-design.md](../cache-handling-phase8-design.md), Parts
01 through 05. The independent design review is
[design-review-gate-01.md](../cache-handling-phase8-design/design-review-gate-01.md),
verdict PASS with advisory findings 8-01 through 8-05.

Binding decisions from the design:

- Payload eviction and branch pruning are separate lifecycle events.
- A metadata-only node keeps topology, token spans, checksum spans, usage,
  protection state, and metadata accounting after payload bytes are gone.
- Re-materialization validates request tokens against retained metadata before
  replay. Validation mismatch is prompt divergence.
- Mismatch-parent selection uses deterministic tie-breaking.
- Equivalent-branch identity ignores payload residency.
- Branch metadata pruning cannot break retained descendant traversal.
- Cold cleanup proves descriptor ownership before deletion.
- Forest mutations hold the forest mutex. Slot references block eviction and
  pruning.

## Advisory finding resolutions

| ID | Resolution |
| --- | --- |
| 8-01 | Stage 8 uses the existing `server_slot`; re-materialization plans are control data, not a replacement slot type. |
| 8-02 | Draft payloads use the same hot, cold, and branch metadata budgets as target payloads. |
| 8-03 | Re-materialization plans are ephemeral. Stage 8 does not add a durable session store. |
| 8-04 | New metrics keep the existing `cache_` prefix and do not remove Stage 4-7 names. |
| 8-05 | The controller owns branch node references; the scheduler keeps calling restore and save entry points. |

## Split plan files

- [Part 1A: Steps 8.1 through 8.5](part-01a-plan-steps-8-1-to-8-5.md)
- [Part 1B: Steps 8.6 through 8.13](part-01b-plan-steps-8-6-to-8-13.md)

## Dependency order

1. Forest extensions: payload eviction, pruning, equivalent lookup, and
   deterministic ranking.
2. Re-materialization: planning, validation, save, and mismatch handling.
3. Deduplication admission and metadata budget enforcement.
4. Cold cleanup safety.
5. Metrics, diagnostics, build wiring, regression evidence, and handoff docs.
