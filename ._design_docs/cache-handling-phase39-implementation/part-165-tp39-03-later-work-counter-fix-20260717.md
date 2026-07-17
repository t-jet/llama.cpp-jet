# Part 165: TP-39-03 later-work counter fix

Date: 2026-07-17
Status: ARCHITECT PASS AFTER PART 167 REWORK; SEE PART 168
Scope: D39-QA-05 seam evidence only

## Change

The terminal proof no longer treats its post-sync generation span as later
work. Three default-OFF seam counters observe forbidden checkpoint-kind work,
pressure work after abort, and diagnostics after abort. The session snapshots
them before apply and emits their summed delta as `later_work_delta`.

The existing generation observations remain independent. Final generation is
still captured after `tx_update()`, retrieval still rejects stale state, and
the successful TP-39-03 controller path now proves both a one-generation LRU
removal span and zero later work.

Controller negatives inject each observed boundary after the baseline. Every
case emits a nonzero later-work delta and fails the shared terminal matrix.
Midpoint and step-2 fault matrices keep their zero assertions. The PowerShell
driver keeps its existing zero assertion.

## Evidence

- Seam-ON Release focused controller build: PASS.
- Focused controller executable: PASS, including all three new negatives and
  the successful signed-LRU separation check.
- PowerShell 7 and Windows PowerShell 5 parser APIs: PASS, zero errors.
- PowerShell 7 and Windows PowerShell 5 pure self-tests: PASS.

No production policy, route, fixture, plan, budget, threshold, model execution,
or coverage changed. Part 166 historically required production-boundary
negatives and component isolation; Parts 167-168 close that finding. Manager
authorization remains required before the canonical TP-39-03 rerun.
