# Part 5: independent Architect design review

Date: 2026-07-12
Status: REWORK REQUIRED

## Review scope

This fresh review covers the Stage 39 Manager intake, design entry, Parts 1-3,
cache requirements, ADR-009, and the production pressure, demotion, and cold
room-making paths in `server-cache-hybrid.cpp`. It does not rely on Part 4's
verdict.

## Traceability result

| Area | Sources | Result |
| --- | --- | --- |
| Byte pressure | R21, R57a, R57c; I-39-01, I-39-05 | Rework: serialized-size plan is not executable as written. |
| Demotion before eviction | R38, R38a, R57b; Parts 1-2 | Covered in intent; failure and commit protocol need correction. |
| Payload versus topology | R38a-c, R55a, R79a-b; ADR-009 | Covered. Payload pressure does not authorize entry or branch removal. |
| Pair atomicity | R37; Stage 25 transaction contract; I-39-04 | Rework: rollback lacks a recoverable victim-delete protocol. |
| Diagnostics | R61, R65-R67; Part 3 | Rework: evidence surface and fixed taxonomy are not selected. |
| Compatibility | I-39-06; TP-39-11 | Covered. |

## Blocking findings

### F39-AR2-01: hot-zero policy remains an implementation choice

Part 2 says to reject a zero hot budget if the existing startup contract treats
zero as invalid, otherwise use cold-only admission. These outcomes change
configuration validity and runtime residency. Design review cannot pass that
choice to Developer.

Required correction: select one behavior from verified parser/controller
semantics, state it in Parts 1-2, and make TP-39-05 assert the selected startup
and runtime result. Also define whether a positive cold layer with hot disabled
is inside the Stage 39 guarantee.

### F39-AR2-02: exact cold size is required before it exists

Part 2 requires a plan containing exact serialized size before the cold object
is written. Current production code plans with `target.size() + draft.size()`;
actual stored bytes are tracked only after a write. The design does not name a
serialization or staging operation that produces the exact size without making
the object visible. This leaves I-39-05 and overflow-safe budget admission
unimplementable without Developer invention.

Required correction: define the prepare artifact and API boundary. State when
serialization occurs, how its exact byte length is measured, where temporary
bytes live, how pair bytes and format overhead are counted, and how the artifact
is discarded on every failure. Add boundary tests for exact fit, one byte over,
format overhead, and arithmetic overflow.

### F39-AR2-03: rollback cannot restore deleted cold victims

Part 2 writes the incoming object, then deletes planned victims, then permits a
descriptor or accounting commit failure to restore the exact pre-apply state.
Once a victim file is deleted, no documented backup, reversible rename, or
reconstruction source restores it. Existing `cold_budget_make_room()` deletes
victim files before demotion and cannot roll them back. The stated transaction
therefore contradicts I-39-04 and its own rollback proof requirement.

Required correction: specify a concrete reversible commit protocol. It must name
staging names, visibility point, reversible victim quarantine or equivalent,
descriptor/accounting apply order, rollback order, crash recovery, and cleanup.
State the live state after failure at each fallible step. Add failure injection
after every mutation, including each victim operation in a multi-victim plan.

### F39-AR2-04: observability contract is not testable

Part 3 allows either bounded labels or internal counters, but requires a live
server workload and agreement on a reason taxonomy. It does not list canonical
reason values, metric families, or which evidence surface proves each acceptance
condition. An internal counter cannot support the live public-metrics path unless
a test-only accessor is explicitly assigned, and R61 requires exposed
diagnostics or metrics.

Required correction: provide a fixed result/reason table mapped to existing or
new metric families and logs. For every TP-39 row, name the evidence surface.
Keep capacity, disabled-layer, oversized, I/O, integrity, and rollback outcomes
distinct. Bound all public labels.

## Non-blocking risks and edge cases

- Cold room-making can require several victims. Tie ordering and partial failure
  behavior need deterministic tests in the corrected commit protocol.
- Part 1 says cold room-making deletes descriptors, while ADR-009 describes
  payload eviction as clearing a descriptor. Use one lifecycle term and state
  whether the descriptor record remains as an evicted tombstone.
- TP-39-02's phrase "both filled" is misleading because room-making succeeds.
  Rename it to cold pressure with eligible victims; reserve both-filled eviction
  for the no-eligible-victim case.
- Missing or corrupt victim handling must say whether quarantine bytes continue
  to count against the cold budget until deterministic cleanup completes.

## Verdict

REWORK REQUIRED. Findings F39-AR2-01 through F39-AR2-04 block Manager design
gate PASS and Developer planning. Architect re-review is required after Parts
1-3 resolve them.
