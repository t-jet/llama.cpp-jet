# Part 194: Architect D39-QA-11 descriptor delta fix review

Date: 2026-07-17
Status: PASS
Reviewed fix: `../.test_reports/test-report-20260717-11-fixes.md`
Reviewed implementation part: `part-193-d39-qa11-descriptor-delta-driver-fix-20260717.md`

## Scope

This review covers only the D39-QA-11 descriptor/residency delta driver fix for
TP-39-03. The review inputs were QA report 11, Developer review Part 192, the
fix report, Part 193, and
`../cache-handling-test-scripts/stage39-two-layer-pressure.ps1`.

Out of scope: product code, fixture, workload, budgets, thresholds, seam,
stage plan, coverage policy, model execution, and coverage execution.

## Verdict

PASS. The correction is driver-only and matches the current TP-39-03 contract.

`Assert-Tp3903` now requires:

| Metric | Required delta |
| --- | ---: |
| `llamacpp:cache_evicted_payload_descriptors{mode="hybrid"}` | `+1` |
| `llamacpp:cache_payload_evictions_total{mode="hybrid"}` | `+1` |
| `llamacpp:cache_hot_payload_descriptors{mode="hybrid"}` | `-2` |
| `llamacpp:cache_cold_payload_count{mode="hybrid"}` | `+1` |

Those deltas match the canonical same-owner sequence: exact payload leaves hot
and becomes cold; checkpoint payload leaves hot and becomes evicted.

## Review notes

- TP-39-03 decision, transaction, terminal proof, cold-file, topology, leak, and
  budget/workload assertions remain in place.
- Pure TP-39-03 fixture now models `+1/+1/-2/+1`.
- Pure negatives reject stale `+1/+1/-1/0`, wrong evicted descriptor count,
  wrong payload eviction count, malformed hot descriptor delta, and malformed
  cold payload count.
- TP-39-02 and TP-39-04 descriptor assertions were not changed by this fix.

The TP-39-02 hot descriptor `-1` and cold payload count `-1` are intended for
that row's different topology: one incoming hot descriptor demotes to cold while
two existing cold victims are evicted, so hot drops by one and cold count drops
by one net. TP-39-04 keeps the single hot oversized eviction path, so hot drops
by one and cold count stays zero.

## Evidence

Static review:

- `Assert-Tp3903` lines 1182-1185 require `+1/+1/-2/+1`.
- `Assert-Tp3902` lines 1138-1141 still require `+2/+2/-1/-1`.
- `Assert-Tp3904` lines 1209-1212 still require `+1/+1/-1/0`.
- `get_stats()` exports descriptor residency from `payload_descriptors`, and
  `server-context.cpp` exposes those counts as public metrics.

Local verification run by Architect:

| Check | Result |
| --- | --- |
| PowerShell 7 parser | PASS |
| Windows PowerShell 5 parser | PASS |
| PowerShell 7 `-MetricValidationSelfTest` | PASS |
| Windows PowerShell 5 `-MetricValidationSelfTest` | PASS |

No model-backed TP-39-03 run or coverage run was performed in this review.

## Handoff

F39-QA11-01 is closed. Manager may open the next D39-QA rerun gate using the
same sequence as Part 191: fresh clean Release seam-ON full target build,
PowerShell 7 and Windows PowerShell 5 parser/pure checks, one canonical
TP-39-03 node, then coverage only after full `Assert-Tp3903` PASS.
