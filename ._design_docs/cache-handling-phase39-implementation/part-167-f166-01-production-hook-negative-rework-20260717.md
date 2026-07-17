# Part 167: F166-01 production-hook negative rework

Date: 2026-07-17
Status: ACCEPTED BY ARCHITECT PART 168
Scope: guarded seam controller only

## Change

The three later-work negatives no longer increment observation counters from
the prepared-baseline helper. After midpoint latches the abort and `tx_update()`
returns, a seam-only dispatcher calls the selected production helper under the
controller lock:

- `mark_payload_kind_evicted(entry, payload_kind::checkpoint)`
- `evict_until_within_budget()`
- `record_branch_metadata_pressure()`

Each helper records its own post-baseline event and returns at its existing
post-abort guard. The terminal proof now exposes the three component deltas as
well as their `later_work_delta` sum.

The controller matrix requires the selected component to equal one, both
siblings to equal zero, the sum to equal one, and the common terminal predicate
to reject the proof. It also checks the midpoint mismatch, hot checkpoint,
zero topology deltas, and empty diagnostic deltas. These checks prevent setup
work or product mutation from satisfying the negative. The positive signed-LRU
case still requires generation span one and later work zero.

## Evidence

| Check | Result |
| --- | --- |
| Seam-ON Release `test-cache-controller` build | PASS, exit 0 |
| Seam-ON Release `test-cache-controller.exe` | PASS, exit 0; all tests passed |

PowerShell files did not change, so their parser and pure checks were not rerun.
No model, coverage, fixture, plan, product policy, commit, push, or PR action ran.
Part 168 accepts the correction and closes F166-01. Manager authorization is
required before canonical TP-39-03; coverage remains blocked until it passes.
