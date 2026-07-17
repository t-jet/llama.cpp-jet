VERDICT: REWORK

# Part 26: independent TP-39-03 measured-budget review

Date: 2026-07-13
Scope: design Part 25 and implementation Part 68 against D39-EXEC-07 and Part 67

## Decision

Parts 25 and 68 correctly separate measurement from canonical execution. Their
integer formulas, request order, isolation, and fail-closed canonical preflight
match D39-EXEC-07. Two input-provenance gaps block the gate.

## Checks

| Check | Result | Evidence |
| --- | --- | --- |
| Measurement scope | PASS | Measurement proves tokens, sizes, RSS, and checkpoint capability; an empty cold set is allowed and apply is forbidden. |
| Startup formula | PASS WITH BLOCKER | `ceil(max(x_s, x_i) / U) + 1` gives at least one full MiB of margin and the explicit sum inequality rejects a two-pair fit, but only if all four inputs are complete-pair measurements. |
| 166 MiB arithmetic | PASS AS TARGET-ONLY EXAMPLE | For 172,761,412 and 171,777,772 bytes, the formula gives 166 MiB, or 174,063,616 bytes, and this is below 344,539,184 bytes. Part 67 does not prove these are complete target/draft-pair bytes. |
| Cold budget | PASS WITH BLOCKER | The same checked formula and inequalities are sound for exact immutable serialized pair sizes. Part 67 has no such values. |
| Request order | PASS | Measurement uses source, incoming, source filler, incoming filler. Canonical uses source then incoming and discovers before filler or apply. |
| Fresh isolation | PASS | Each pass uses a different process and empty cold root; measurement identities and authorization state cannot cross into canonical. |
| Canonical preflight | PASS | Source demotion, hot incoming residency, exactly one compatible cold checkpoint, collision rejection, snapshot binding, and the four lowered apply inequalities remain mandatory. |

## Blocking findings

### F39-MBR-01: resident inputs are not complete-pair evidence

Part 67's discovery artifact reports both cited hot rows as
`payload_kind:"exact_blob"`, `pair_state:"target_only"`. Parts 25 and 68 call
the values complete target/draft-pair inputs and use them for the 166 MiB
example. That provenance does not satisfy D39-EXEC-07.

Correction must define the exact aggregation unit for `R_s` and `R_i`, then
record every target and draft component that belongs to that unit. If
`target_only` is intended to count as complete for this runtime, the durable
correction must state why that is compatible with D39-EXEC-07 and bind the
accepted pair-state rule. The 166 MiB example may remain only after its input
classification is proved; otherwise recalculate it from corrected values.

### F39-MBR-02: serialized inputs have no executable measurement path

The same Part 67 artifact reports `serialized_cold_bytes:null` for both hot
rows, and the cold root contains no payload file. Current discovery populates
serialized bytes from the cold-byte map only after a cold object exists.
Part 68 limits the change to driver measurement but does not name a path that
can produce exact immutable `S_s` and `S_i` while the 2048 MiB measurement
keeps both rows hot.

Correction must name an executable, non-estimated source for both serialized
complete-pair sizes. It must state whether this is a non-publishing preparation,
a guarded measurement response, or another reviewed mechanism; define failure
and cleanup; prove no cold admission or apply is being inferred; and add focused
evidence for target/draft aggregation, exact byte provenance, overflow, missing
components, and partial preparation. A checkpoint-state log size is still
invalid.

## Required rework

1. Correct Parts 25 and 68 for F39-MBR-01 and F39-MBR-02.
2. Keep the existing formulas, four startup inequalities, request order, fresh
   isolation, and canonical preflight unless corrected measurements require a
   recalculated example.
3. Update any driver-only scope claim if the chosen serialized-size mechanism
   needs guarded product or route code.
4. Return the corrected documents for fresh independent Architect re-review.

## Handoff

Manager gate is not ready. Developer owns documentation correction only. Code,
tests, builds, model execution, coverage, commit, and push remain blocked.
