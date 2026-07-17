# Part 161: TP-39-03 signed LRU evidence fix

Date: 2026-07-17
Status: READY FOR ARCHITECT REVIEW
Authority: Developer review Part 160 and `test-report-20260717-04-developer-review.md`

## Scope

This correction changes guarded test evidence and its driver assertions. It
does not change eviction policy, retention behavior, workload, fixture,
budgets, caps, plan, or coverage threshold.

## Implementation

- `server-cache-hybrid.cpp` serializes the four terminal topology deltas with
  signed subtraction. A source LRU transition from one membership to zero now
  produces `-1`.
- Terminal proof resident accounting identifies live-reference entries without
  adding them to the hot-policy candidate set. It records their owner, links,
  reference count, resident bytes, total resident bytes, and applied budget.
- `stage39-two-layer-pressure.ps1` expects source membership `0` and delta
  `-1`. It keeps exact source descriptor/file reconciliation and retained
  entry, branch, and owner checks. One different-owner referenced entry must
  explain every remaining resident byte above the lowered budget.
- `test-cache-controller.cpp` adds a successful natural TP-39-03 regression
  that requires a signed JSON integer `-1`, zero membership, retained topology,
  and exact cold evidence. Pure PowerShell negatives reject the old retained-
  LRU assumptions, unsigned wrap, and unexplained resident accounting.

## Focused evidence

| Command scope | Result |
| --- | --- |
| Build seam-ON `test-cache-controller` only | PASS |
| Run focused controller binary | PASS; all tests passed |
| PowerShell 7 and 5 parser APIs | PASS; zero errors |
| PowerShell 7 and 5 `-MetricValidationSelfTest` | PASS |

No model or coverage command ran. Fix report
`test-report-20260717-04-fixes.md` contains the paired evidence. Next gate is
fresh independent Architect review.
