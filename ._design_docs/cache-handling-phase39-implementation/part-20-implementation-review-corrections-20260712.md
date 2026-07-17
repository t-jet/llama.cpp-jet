# Part 20: implementation review corrections

Date: 2026-07-12
Status: READY FOR FRESH ARCHITECT IMPLEMENTATION RE-REVIEW

## Scope

This correction closes F39-IR-01 through F39-IR-03 from Part 19. It changes
only Stage 39 capacity-reason selection, cold-disabled observability, focused
production-path tests, and live-driver assertions.

## Corrections

### F39-IR-01

`tx_demote_payload()` now preserves the capacity subtype. A serialized pair
that exceeds the cold budget emits `oversized_both` only when its resident hot
pair also exceeds the positive hot budget. Failed cold room-making for any
other pair remains `both_filled`. `mark_payload_kind_evicted()` records that
typed reason instead of replacing every capacity result with `both_filled`.

The focused controller test drives both branches through normal admission
pressure and asserts one `evicted/oversized_both` row and one
`evicted/both_filled` row.

### F39-IR-02

Hot pressure with an unconfigured cold store or a zero cold budget now emits
one `bypassed/cold_disabled` decision before existing hot-only eviction. The
focused controller test checks the decision, eviction count, and released hot
bytes. `--cache-ram 0` remains unchanged: `server_context` does not construct a
prompt-cache controller, so no Stage 39 row can be emitted.

### F39-IR-03

`stage39-two-layer-pressure.ps1` now accepts `standard`, `oversized-both`,
`cold-disabled`, and `hot-zero` scenarios. Each added scenario checks its
public decision tuple. The hot-zero scenario requires both Stage 39 metric
families to remain absent. Model-backed execution remains QA-owned.

## Evidence

- Release build of `test-cache-controller`: PASS.
- Release `test-cache-controller.exe`: PASS, including both new production-path
  tests and all existing controller tests.
- Stage 39 PowerShell driver parser: PASS.
- Existing C4477 warnings at lines 6298, 6311, and 6419 predate this correction.

## Handoff

F39-IR-01 through F39-IR-03 are corrected. Next action is a fresh Architect
implementation re-review. Manager and QA gates remain closed until that review
passes.
