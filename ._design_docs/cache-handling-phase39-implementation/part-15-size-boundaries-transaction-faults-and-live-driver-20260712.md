# Part 15: size boundaries, transaction faults, and live driver

Date: 2026-07-12
Status: PARTIAL

## Production and test work

Cold admission now checks the sum of descriptor-owned cold bytes and quarantine
bytes before subtracting victims or comparing capacity. Overflow removes the
staged object, keeps the hot payload, and records `retained_hot/size_overflow`.

`test_stage39_serialized_size_boundaries` covers exact fit, one byte over,
serialized header overhead, and checked-add overflow through the controller.

The cold store now has test-only mutation faults for manifest write, victim
quarantine, incoming publish, commit marker, and cleanup. Controller tests seed
a cold victim, inject rollback-boundary faults, and verify the incoming hot
payload and prior cold owner remain.

`stage39-two-layer-pressure.ps1` starts a fresh hybrid server, applies bounded
request pressure, captures metrics, requires both Stage 39 metric families,
scans fatal signatures, and writes a JSON summary. No model run occurred here.

## Verification

- Release `test-cache-controller` and `llama-server` build: PASS.
- Release controller executable: PASS, `All tests passed successfully!`.
- Release cache ctest: PASS, 1/1.
- PowerShell parser check for the Stage 39 live driver: PASS.
- Existing C4477 warnings at test lines 6178, 6191, and 6299 remain.

## Remaining TP-39-14 work

Implementation-ready is not declared. Fresh-controller pre-commit and
post-commit recovery still needs controller-state reconstruction assertions.
The matrix also needs descriptor-apply and per-victim-unlink seams,
destroy/reconstruct idempotence, multi-victim failure at every position, and
conflicting-state, missing-owner, and claimed-path fail-safe rows. Focused
changed-line coverage remains a QA-owned gate.
