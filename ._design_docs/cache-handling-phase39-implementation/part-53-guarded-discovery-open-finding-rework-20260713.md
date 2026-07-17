# Part 53: guarded discovery open-finding rework

Date: 2026-07-13
Status: PARTIAL - VERIFICATION REQUIRED
Scope: F39-GDIR-01, F39-GDIR-03, and F39-GDIR-04 from Architect Part 52

## Production changes

- Cold cleanup now advances the guarded generation when it removes byte-map
  rows or descriptors. Forest metadata pruning advances it in both update and
  admission paths.
- Normal slot-reference acquisition now takes `cache_state_mutex_` and advances
  the same generation owner. Startup orphan cleanup, recovered transaction
  cleanup, transaction rollback recovery, and transaction cleanup also advance
  generation.
- Guarded inventory integrity now rejects a missing cold payload file without
  narrowing the production cold selector.
- Payload-budget eviction retains lookup entries and branch metadata. The
  token-budget loop still performs full entry removal so it makes progress.
- A guarded test-only environment fault can fail after normal `tx_update()`;
  this exercises terminal post-mutation response handling.

## Test and driver changes

- Route tests now delete and restore a real cold file for integrity retry,
  remove an actual checkpoint row, overlap discovery with a processing
  completion, test non-loopback startup separately from a wrong token, and
  inject a failure after production pressure.
- The generation matrix now checks full demotion rollback, forest pruning, and
  startup orphan recovery/cleanup. TP-39-02/03/04 controller cases check exact
  tuples, victim order, descriptor states, accounting, topology, and pruning.
- `Assert-Tp3902`, `Assert-Tp3903`, and `Assert-Tp3904` now consume saved
  before/after metrics and cold inventories. They check exact decision and
  transaction deltas, fixed log tuples, tied victim order, files/tombstones,
  byte and quarantine accounting, retained topology, zero pruning, measured
  size predicates, and no partial pair.

## Evidence

- ON Release controller and server build completed before the last retention
  and assertion edits: `._test_output/stage39-dev-part53/build-on3.log`.
- Controller suite passed before the new row-specific assertions:
  `controller2.log`.
- PowerShell 5 and 7 metric self-tests passed after the driver assertion
  implementation.
- A later controller run exposed that immediate payload pressure removed a
  lookup entry. The production path was corrected, but Manager stopped further
  runs before rebuild and verification.
- Three whitespace-only blank lines in `server-cache-hybrid.cpp` were
  normalized. Coverage was not run; QA retains coverage ownership.

## Open verification

Rebuild ON and OFF after the final edits. Run the full controller suite, all 13
route tests, guarded driver smoke, and PowerShell 5/7 self-tests. Confirm
TP-39-02 uses a cold budget that fits the incoming object while requiring both
victims. Then run `git diff --check`. Fresh Architect review remains blocked
until these commands pass.
