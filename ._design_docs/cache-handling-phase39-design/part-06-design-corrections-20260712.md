# Part 6: design corrections

Date: 2026-07-12
Status: READY FOR ARCHITECT RE-REVIEW

## Resolution map

| Finding | Resolution | Acceptance check |
| --- | --- | --- |
| F39-AR2-01 | Part 2 fixes hot zero to existing `--cache-ram 0` behavior: prompt cache disabled, no cold-only mode. | TP-39-05 covers startup and zero Stage 39 events. |
| F39-AR2-02 | Part 2 defines immutable `prepared_cold_object`, exact closed-file length, checked arithmetic, format overhead, and cleanup ownership. | TP-39-13 covers exact fit, one byte over, overhead, and overflow. |
| F39-AR2-03 | Part 2 defines same-directory victim quarantine, manifest, commit marker, reverse rollback, idempotent crash recovery, and post-commit cleanup accounting. | TP-39-14 injects failure after every mutation and crash boundary. |
| F39-AR2-04 | Part 3 fixes two public metric families, bounded label values, log schemas, per-row evidence surfaces, and required evidence columns. | Each TP-39 row names public or focused evidence; live rows require `/metrics`. |

## Advisory closure

- Multi-victim ordering uses current rank then payload ID; failure is injected at
  every victim position.
- Cold room-making evicts bytes and leaves descriptor tombstones. It never
  deletes lookup entries or branch nodes.
- TP-39-02 now says cold pressure with eligible victims. `both_filled` is reserved
  for eviction after no eligible plan fits.
- Quarantined and corrupt-victim bytes count against cold budget until verified,
  deterministic cleanup completes. Unknown manifest state disables mutation.

## Gate

All Part 5 blocking and advisory findings have concrete design decisions and
tests. Architect re-review is next. Manager gate and Developer planning remain
blocked until PASS.
