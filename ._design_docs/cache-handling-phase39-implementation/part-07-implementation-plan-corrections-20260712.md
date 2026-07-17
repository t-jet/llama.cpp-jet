# Part 7: implementation-plan corrections, iteration 3

Date: 2026-07-12
Status: READY FOR FRESH ARCHITECT RE-REVIEW

## Correction

F39-IPR-03 is corrected in Part 1. Committed manifests now carry the complete
incoming descriptor image, stable owning entry ID, exact/checkpoint owner link,
payload kind and pair state, victim descriptor tombstones, and checked before,
victim, and after logical-byte values. Fresh-controller recovery no longer
depends on state from the committing process.

Part 1 replaces the ambiguous apply call with
`reconstruct_committed_transaction()`. It defines validation, reconstruction,
idempotence, conflicts, missing-owner handling, cleanup order, claimed-path
protection, and the boundary between recovered ownership rows and live lookup
entries. Unappliable records preserve files and disable cold mutation.

TP-39-14e and TP-39-14f destroy the committing controller and construct new
controllers. They cover pre-commit states and post-commit reconstruction of
incoming ownership, exact/checkpoint links, multiple victim tombstones, per-ID
and total logical bytes, cleanup, and repeated-startup idempotence.

## Gate

No code changed. Code and Manager implementation-plan gate remain blocked.
Request a fresh independent Architect plan re-review of F39-IPR-03.
