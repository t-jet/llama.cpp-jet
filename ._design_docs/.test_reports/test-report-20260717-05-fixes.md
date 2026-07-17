# Stage 39 D39-QA-05 fixes

Date: 2026-07-17
Status: ARCHITECT PASS; MANAGER RERUN GATE NEXT
Source: `test-report-20260717-05.md` and its Developer review

## Plan

1. Replace the generation-span proxy for `later_work_delta` with guarded
   observations at the forbidden later-kind, post-abort pressure, and
   post-abort diagnostic boundaries.
2. Add controller negatives for each boundary and a successful TP-39-03
   regression that keeps the generation span separate from later-work evidence.
3. Build and run only the focused seam controller and PowerShell 7/5 parser and
   pure checks.

Product pressure behavior, driver assertions, fixtures, plans, budgets, and
thresholds remain unchanged. Model and coverage execution stay blocked.

## Implementation

`server-cache-hybrid.cpp` now counts three guarded events. A checkpoint-kind
entry after the abort latch, a pressure entry after the latch, or a diagnostic
entry after the latch increments its matching counter and returns. The baseline
captures all three counters. Terminal `later_work_delta` is their summed
observed delta. It no longer uses
`final_generation - common_sync_generation`.

`test-cache-controller.cpp` adds one negative per boundary. Each probe produces
`later_work_delta=1`, and the shared terminal matrix rejects the proof. The
successful signed-LRU test requires a generation span of exactly one and
`later_work_delta=0`.

## Evidence

| Check | Result |
| --- | --- |
| Seam-ON Release `test-cache-controller` build | PASS, exit 0 |
| `test-cache-controller.exe` | PASS, exit 0; all tests passed |
| PowerShell 7 parser API | PASS, zero errors |
| Windows PowerShell 5 parser API | PASS, zero errors |
| PowerShell 7 pure self-test | PASS, exit 0 |
| Windows PowerShell 5 pure self-test | PASS, exit 0 |

No model, coverage, fixture, plan, threshold, commit, push, or PR action ran.
Architect review is recorded below. A Manager gate is still required before
one canonical TP-39-03 rerun; coverage remains closed until that rerun passes.

## Architect fix review

Part 166 records `VERDICT: REWORK` with one blocker, F166-01. Production hooks,
baseline/sum semantics, lock ownership, legal LRU separation, and default-OFF
behavior are correct. The three new negatives inject counter members directly
from the baseline helper instead of traversing the named production boundaries,
then assert only the aggregate. Developer must drive each actual helper after
the latch and prove exactly one component delta, zero sibling deltas, aggregate
one, and terminal rejection. Model and coverage execution remain blocked.

## F166-01 developer rework

Part 167 replaces the three direct counter mutations with calls to the actual
production helpers after the prepared baseline and midpoint abort latch. Each
negative proves its named component delta is one, sibling deltas are zero,
their aggregate is one, terminal validation rejects the proof, and no topology,
checkpoint residency, or diagnostic mutation leaks from the hook call.

The seam-ON Release controller target rebuilt successfully and its executable
passed all tests. PowerShell files did not change, so PowerShell checks were not
rerun. At that point, model and coverage execution remained blocked pending
Architect review; Part 168 records the completed review below.

## Architect F166-01 re-review

Part 168 records `VERDICT: PASS`. Static trace confirms every negative calls
its named production helper after baseline capture, `tx_update()`, and the
midpoint abort latch. Each case proves selected component one, siblings zero,
aggregate one, terminal rejection, and no unrelated mutation or diagnostic
leakage. The positive signed-LRU case keeps generation span one and later work
zero.

Three mutation builds removed the checkpoint, pressure, and diagnostic hook
increments one at a time. Each build succeeded and each controller run failed
with `0xC0000409`. Restoring all hooks rebuilt cleanly and the controller passed
with exit 0. Manager may authorize one canonical TP-39-03 rerun. Coverage stays
blocked until that rerun passes.
