VERDICT: REWORK

# Part 56: Architect guarded discovery final re-review

Date: 2026-07-13
Scope: open Part 52 findings against Parts 53-55, current code, tests, driver,
and saved execution artifacts

## Result

F39-GDIR-03 passes. F39-GDIR-01 is partial and F39-GDIR-04 still needs
rework. The model-backed TP-39-02 workload is valid and passes, but Part 43's
complete generation matrix and exact driver assertion map are not implemented
yet. Coverage remains a QA-only gate because no new runner defect was found.

## Finding status

| Finding | Status | Evidence and next owner |
| --- | --- | --- |
| F39-GDIR-01 | PARTIAL | Cleanup, pruning, normal slot acquisition, recovery, and rollback now call the locked generation owner. The matrix at `test-cache-controller.cpp:4692-4756` executes slot acquire/release, one rollback, metadata pruning, and startup orphan cleanup. It still combines recovery with orphan cleanup and does not independently execute normal `update()` cold cleanup, committed transaction recovery, or committed transaction cleanup. Part 15 and test-plan Part 43 require every mutation family to execute independently. Next owner: Developer, add focused generation assertions for those three paths and stale the pre-mutation snapshot after each. |
| F39-GDIR-03 | PASS | The controller suite passes and its TP-39-02/03/04 tests assert production outcomes, descriptors, accounting, topology, pruning, and exact metric deltas. The model-backed route suite passes all 13 required tests, including real-file integrity retry, exact-set rejection, live completion overlap, process binding, non-loopback startup failure, and terminal post-transaction failure. Next owner: none for implementation; QA retains rerun evidence. |
| F39-GDIR-04 | REWORK | `Assert-Tp3902` now proves the measured three-object shape and the saved TP-39-02 smoke passes one decision and one commit. However, `Assert-Tp3903` and `Assert-Tp3904` do not assert the exact cold-transaction delta required by Part 43. Common accounting at driver lines 159-179 accepts descriptor bytes smaller than total inventoried file bytes, and no row asserts the public evicted-descriptor tombstone delta. Log checks prove only that a tuple appears somewhere in the full server log; they do not bind an exact apply-window count or incoming payload/transaction identity. Next owner: Developer, make TP-39-02/03/04 assert exact transaction deltas, descriptor tombstones, final cold-plus-quarantine byte reconciliation, and apply-window log identity/count; then run PowerShell 5/7 self-tests plus TP-39-02/03/04 guarded smokes. |

## TP-39-02 evidence and isolation

Part 55's final Qwen3-0.6B run is model-backed. Saved discovery contains one
8,947,296-byte hot incoming object and two smaller cold victims. Apply removes
both victim files, writes `3.cold`, preserves three entries and three branch
nodes, leaves pruning and quarantine at zero, and advances generation 50 to 65.
The driver exits 0 with `Outcome: PASS`.

The guarded environment flags are set only for guarded scenarios and removed
in `finally` at driver lines 533-537. The OFF binary route-absence test and
runtime-OFF route test pass. Advisory: cleanup removes caller-supplied prior
values instead of restoring them; this does not invalidate the isolated saved
run, but the driver should preserve prior environment values when next edited.

## Execution classification

- ON/OFF builds, controller suite, 13 route tests, and PowerShell 5/7 parse and
  self-tests pass in Part 54/55 artifacts.
- One controller run ended in the known Stage 23 `0xC0000005` after all Stage
  39 rows passed. The immediate clean rerun passed. Keep both artifacts; this
  remains a QA stability risk, not a new Stage 39 defect.
- TP-39-03 and TP-39-04 have implementation assertions and controller coverage,
  but their driver assertions are not closure-ready for the reasons above.
- Canonical PowerShell 5/7 coverage success and forced-failure runs, final
  artifacts, and the 80 percent result remain QA work after implementation
  re-review passes.

## Handoff

REWORK. Developer owns the remaining F39-GDIR-01 generation cases and
F39-GDIR-04 assertion corrections. Return to fresh Architect re-review. QA then
owns TP-39-02/03/04 execution, canonical coverage, and transient-AV retention.
Manager gate and Stage 39 closure remain blocked.
