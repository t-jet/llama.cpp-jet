# Part 57: generation and driver assertion fixes

Date: 2026-07-13
Status: READY FOR FRESH ARCHITECT RE-REVIEW
Scope: F39-GDIR-01 and F39-GDIR-04 from Architect Part 56

## Generation coverage

Three named Release controller tests now execute the missing production paths:

- `test_stage39_live_pressure_normal_cold_cleanup_generation` creates one
  unreferenced cold descriptor and file, calls normal `tx_update()`, and checks
  that cleanup removes both while generation advances.
- `test_stage39_live_pressure_committed_recovery_generation` starts a controller
  over a committed manifest and checks reconstructed cold descriptor accounting
  plus generation advancement.
- `test_stage39_live_pressure_committed_cleanup_generation` starts over a fresh
  committed manifest and checks another startup removes committed replay state,
  retains the ownership claim, and records the separate cleanup generation.

The added getter observes generation only. Tests execute `tx_update()` and the
normal controller startup recovery/cleanup path; no debug helper substitutes for
those mutations.

## Driver assertions

`stage39-two-layer-pressure.ps1` now applies these exact gates:

- every guarded row has one total decision delta and one exact expected tuple;
- TP-39-02 has one total transaction delta, exactly `commit/none`; TP-39-03 and
  TP-39-04 require zero transaction-family delta;
- TP-39-02 requires two new evicted-descriptor tombstones, two payload
  evictions, one hot-descriptor removal, and the exact cold-count change;
- TP-39-03 and TP-39-04 each require one tombstone, one payload eviction, one
  hot-descriptor removal, and zero cold-count change;
- descriptor and payload cold bytes must equal final `.cold` file bytes, with
  zero final quarantine bytes; ownership claim files are not payload bytes;
- apply-window logs contain exactly one decision for the incoming payload.
  TP-39-02 also contains exactly one identified positive transaction ID;
- TP-39-02 request order must equal the tied-rank payload-ID victim order;
- all rows retain exact entry and branch counts and zero pruning delta. Final
  inventories plus tombstone deltas prove pair atomicity.

The driver records `control-apply-window.log`. Empty stdout or stderr before an
apply is normalized to an empty string, so byte-window capture works on both
PowerShell versions.

## Verification

| Check | Result | Artifact |
| --- | --- | --- |
| Seam-ON Release controller build | PASS, exit 0 | `._test_output/stage39-part57-build.log` |
| Full Release controller suite | PASS, exit 0 | `._test_output/stage39-part57-controller-final.log` |
| Guarded route suite | PASS, 13 tests | `._test_output/stage39-part57-route-tests.log` |
| PowerShell 7 parse and self-test | PASS, exit 0 | console evidence |
| Windows PowerShell 5 self-test | PASS, exit 0 | console evidence |
| Model-backed TP-39-02 smoke | PASS, exit 0 | `._test_output/stage39-part57-tp3902-final/` |

The first cleanup test draft drove a pre-existing unsafe setup combination and
crashed before its assertion. The final test uses an isolated unreferenced cold
descriptor, rebuilds cleanly, and the full suite passes. The first corrected
smoke found a null empty-log string in the new apply-window code; normalization
fixed it, and the one requested clean rerun passed.

TP-39-03 and TP-39-04 model smokes were not run in this bounded correction.
Their exact assertion logic is covered by PowerShell 5 and 7 self-tests; QA owns
model-backed execution after Architect re-review.

## Handoff

F39-GDIR-01 and F39-GDIR-04 are ready for fresh Architect re-review. QA still
owns TP-39-03/04 model execution and canonical coverage. No product behavior,
public surface, coverage denominator, commit, or push changed.
