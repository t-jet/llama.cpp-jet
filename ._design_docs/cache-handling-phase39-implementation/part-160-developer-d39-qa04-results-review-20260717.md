# Part 160: Developer D39-QA-04 results review

Date: 2026-07-17
Status: REWORK REQUIRED
Scope: QA report 20260717-04, TP-39-03, and deferred coverage

## Verdict

Full review:
`../.test_reports/test-report-20260717-04-developer-review.md`

TP-39-03 exposed a guarded proof and driver mismatch, not a product retention
bug. Production correctly retained the exact descriptor cold, evicted the
checkpoint with `both_filled`, committed once, retained two entries and two
nodes, and pruned nothing.

`evict_entry_by_id()` intentionally removes the source from the hot-policy LRU
after demotion while preserving lookup and branch metadata. The proof subtracts
unsigned membership counts, encoding the valid `1 -> 0` transition as UINT64
maximum. The driver instead requires `1` and delta `0`.

The over-budget warning belongs to the second, active-slot-referenced entry.
That entry is absent from the production candidate set and remains hot after
the released source completes pressure. Its payload bytes reconcile with the
warning; this is not leaked source residency or failed checkpoint eviction.

## Correction and retest

Developer owns a seam/driver-only correction: signed topology deltas, terminal
source membership `0`, delta `-1`, and pure negative coverage for wrong or
wrapped values. Add an exact active-reference accounting assertion for the
remaining resident bytes. Production eviction, retention, fixture, workload,
budgets, caps, plan, and thresholds stay unchanged.

Fresh Architect review follows. Manager must authorize one canonical TP-39-03
rerun. Only full PASS opens the four deferred Part 149 coverage blocks. No fix,
build, model, test, or coverage command ran here.
