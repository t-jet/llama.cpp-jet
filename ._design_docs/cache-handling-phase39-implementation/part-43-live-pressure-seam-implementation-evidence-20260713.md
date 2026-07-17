# Part 43: live pressure seam implementation evidence

Date: 2026-07-13
Status: SUPERSEDED BY PART 49
Authority: D39-EXEC-02, design Part 11, implementation Part 39

## Implemented

- Added default-OFF `LLAMA_STAGE39_LIVE_TEST_SEAM` compilation. Guarded
  controller and route symbols are absent from OFF compilation.
- Added runtime opt-in and token checks. Startup rejects non-loopback hosts,
  router mode, non-hybrid mode, disabled metrics, non-positive budgets,
  parallel execution, and tokens shorter than 32 characters.
- Added one completion-admission mutex around completion launch and control.
  Control checks idle slots while holding the same mutex.
- Added strict request parsing, constant-time token comparison, separate exact
  hot and cold set validation, ownership and residency checks, unique payload,
  owner, and hot-order checks, setup-only rank and budget mutation, terminal
  one-shot state, and normal `tx_update()` dispatch.
- Replaced the coverage merge tail with absolute no-argument `whoami.exe` and
  made a nonzero merge exit throw before XML parsing.
- Added a guarded Release controller test for retryable duplicate rejection,
  successful pressure, response shape, and terminal reuse rejection.

## Evidence

- ON configure, controller build, and server build: exit 0.
- Release `test-cache-controller.exe`: exit 0, all tests passed.
- OFF configure and `server-context` build: exit 0.
- Invalid short-token startup probe: exit 1 with bounded rejection before model
  load.
- PowerShell 7 and Windows PowerShell 5 script parse checks: PASS.
- Literal forced-merge fixture: exit 23.
- Scoped `git diff --check`: PASS.

One earlier combined build overlapped a worker left by a timed command and hit
`baichuan.obj: Permission denied`. After stopping only workers for the new ON
tree, serial controller and server builds passed. This was build contention.

## Blocking interface gap

TP-39-02 through TP-39-04 cannot yet use the route. The request must name exact
live payload and owner IDs, but the approved interface provides only the
mutating POST. Existing public metrics do not expose those IDs. The driver
cannot construct the first valid request without guessing. Logs are not a
complete, stable owner inventory and cannot prove omitted or extra candidates.

Corrected design Part 15 keeps the one-route surface and tags it with
non-mutating `discover` plus snapshot-bound `apply`. It now separates pure hot
enumeration from the production blocked-ref metric wrapper. Its cold inventory
matches production exactly: cold residency plus incoming-owner exclusion, with
descriptor and owner integrity checked separately by the seam. It also defines
one locked generation owner across entries, descriptors, residency, ranks,
forest slot references, completion dispatch, save/restore, recovery, rollback,
budgets, and control setup. This implementation predates that correction and
does not satisfy it.

## Coverage status

The source correction and exit-23 fixture probe pass. Full canonical success
and forced-failure runs were not repeated because fresh all-target coverage
trees were outside this proportional correction run. QA still owns the 80
percent verdict after the interface gap and Architect review close.

## Handoff

Implementation review Part 44 records REWORK. Design Part 15 and implementation
Parts 45-46 now correct design-review findings F39-GDR-01 through F39-GDR-03 and
are ready for fresh independent Architect re-review. Code, route tests, live
driver work, and QA remain blocked until independent PASS and a later Manager
correction gate.

Part 49 records the D39-EXEC-03 implementation rework and current open evidence.

D39-EXEC-07 and design Part 25 supersede TP-39-03 measurement reachability:
measurement need not contain a cold set. Canonical startup uses exact measured
pair sizes so source then incoming admission creates the cold candidate before
discovery. This historical part does not authorize that driver change.
