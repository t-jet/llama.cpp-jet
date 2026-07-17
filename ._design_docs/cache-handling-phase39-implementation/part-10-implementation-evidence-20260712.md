# Part 10: implementation evidence

Date: 2026-07-12
Status: PARTIAL

## Completed

The hot-pressure path no longer skips cold demotion when resident hot bytes are
already above budget. `mark_payload_kind_evicted()` now calls
`tx_demote_payload()` first whenever cold storage is configured and the payload
is hot. Successful demotion releases hot bytes and retains the descriptor,
entry, and branch metadata.

The focused regression creates eight 100-byte payloads with a 200-byte hot
budget and a 1000-byte cold budget. It verifies six cold demotions, zero payload
evictions, eight retained entries, and hot residency at or below budget.

The synchronous demotion path no longer applies the retired async outstanding
demotion reserve. A focused case now verifies that a 300-byte payload can leave
a 200-byte hot layer for a 1000-byte cold layer without payload eviction. The
test cold-store hook now wires the synchronous I/O helper; without that wiring,
Release assertions hid failed demotions. Stage 39 checks use explicit aborting
checks so they remain active under `NDEBUG`.

Changed files:

- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- `tests/test-cache-controller.cpp`

## Evidence

- Release `test-cache-controller` build: PASS.
- `build/bin/Release/test-cache-controller.exe`: PASS, including
  `test_stage39_over_budget_demotion_precedes_eviction`.
- `ctest --test-dir build -C Release -R cache --output-on-failure`: 1/1 PASS.
- `git diff --check`: PASS before this evidence update.

Continuation evidence:

- Release `test-cache-controller` build: PASS.
- `build/bin/Release/test-cache-controller.exe`: PASS, including both Stage 39
  focused cases.

## Remaining plan work

This pass does not complete the approved transaction and recovery contract.
Prepared-object admission, victim quarantine, durable manifests, startup
recovery, fixed Stage 39 decision and transaction metrics, live tests,
failure-boundary tests, and focused coverage remain open. Architect
implementation review must not start until those items are implemented and
verified.
