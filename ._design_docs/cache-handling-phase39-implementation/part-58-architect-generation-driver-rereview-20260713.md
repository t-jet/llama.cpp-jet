VERDICT: REWORK

# Part 58: Architect generation and driver re-review

Date: 2026-07-13
Scope: Part 56 F39-GDIR-01 and F39-GDIR-04 against Part 57, current tests,
driver, and saved evidence

## Result

Part 57 improves both findings but does not close them. The three added
generation tests reach production mutation paths, and the TP-39-02 model smoke
passes the corrected exact deltas. One generation assertion targets the wrong
file, and the TP-39-03 driver precondition contradicts the approved row and the
controller validation. TP-39-04 also omits its positive-startup-budget proof.

## Finding status

| Finding | Status | Evidence and required correction |
| --- | --- | --- |
| F39-GDIR-01 | REWORK | The new tests call normal `tx_update()` and controller startup recovery/cleanup; they do not replace mutations with debug helpers. However, `test_stage39_live_pressure_normal_cold_cleanup_generation` writes payload 39010 (`9862.cold`) and asserts absence of `9852.cold`, so its file-removal assertion cannot prove the production cleanup removed the prepared file. None of the three tests submits a captured pre-mutation snapshot after the path, as Part 56 required. Correct the filename assertion from the payload ID, stale a captured request for the normal cleanup path, and add direct before/after generation evidence that separates committed reconstruction from committed replay cleanup. |
| F39-GDIR-04 | REWORK | TP-39-02 is closure-ready: the saved model run has one exact `retained_cold/cold_room_made` decision for payload 3, one identified `commit/none` transaction, two victim tombstones, two payload evictions, one incoming cold file, reconciled final `.cold` bytes, zero quarantine, retained entries/branches, and zero pruning. TP-39-03 is not executable under its own driver contract: lines 351-353 require the selected pair to exceed the lowered hot budget, while Part 39, Part 43, and controller apply validation require that pair to fit hot alone and only aggregate hot bytes exceed the budget. `Assert-Tp3903` also does not prove existing cold bytes plus the measured serialized pair exceed cold capacity. TP-39-04 checks lowered budgets but not that both positive startup budgets exceeded the measured pair before admission. Correct these preconditions and assertions, then run model-backed TP-39-03 and TP-39-04 smokes. |

## Retained evidence and gate ownership

The Release controller log ends after all guarded generation and TP tests pass.
The route suite remains 13/13 PASS. PowerShell 5 and 7 self-tests cover metric
and log helper logic, but they return before scenario preflight and cannot prove
the contradictory TP-39-03 model path.

The earlier post-test `0xC0000005` did not recur in Part 57's clean controller
run. Keep the failing and passing artifacts for QA stability review; it is not a
new Stage 39 product finding. Canonical PowerShell 5/7 coverage success and
forced-failure runs, final coverage artifacts, and the 80 percent result remain
QA-only. TP-39-03/04 model execution is not QA-only until the driver corrections
above pass implementation review.

## Handoff

REWORK. Next owner: Developer for F39-GDIR-01 and F39-GDIR-04 corrections plus
TP-39-03/04 model smokes. Return to fresh Architect re-review. QA follows only
after implementation PASS; Manager gate and Stage 39 closure remain blocked.
