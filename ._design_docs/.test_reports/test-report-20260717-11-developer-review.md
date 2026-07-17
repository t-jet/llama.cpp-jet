# Developer review: test-report-20260717-11

Date: 2026-07-17
Reviewer: Developer agent
Input report: `._design_docs/.test_reports/test-report-20260717-11.md`
Evidence root: `._test_output/test-report-20260717-11/`
Verdict: REWORK REQUIRED

## Scope reviewed

- Manager rerun gate:
  `._design_docs/cache-handling-phase39-implementation/part-191-manager-d39-qa11-rerun-gate-20260717.md`
- QA report:
  `._design_docs/.test_reports/test-report-20260717-11.md`
- Canonical TP-39-03 evidence:
  `._test_output/test-report-20260717-11/TP-39-03-node/`
- Live driver:
  `._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1`
  around `Assert-Tp3903`
- Product metric accounting:
  `tools/server/server-cache-hybrid.cpp` and
  `tools/server/server-context.cpp`

## Classification

The D39-QA-11 failure is a driver assertion bug. It is not a product accounting
bug, execution blocker, or design mismatch.

Product state and product metrics agree with the current TP-39-03 contract:

- `control-linked-proof-response.json` proves two same-owner hot descriptors
  before apply: payload `1` exact and payload `2` checkpoint.
- `control-apply-response.json` has `consumed=true` and
  `pressure_completed=true`.
- Terminal proof records exact payload `1` as `cold`, checkpoint payload `2` as
  `evicted`, and no checkpoint cold file.
- `control-apply-window.log` records
  `retained_cold/cold_room payload_id=1`, one `commit/none`, then
  `evicted/both_filled payload_id=2`.
- `control-cold-files-after.csv` contains exactly `1.cold` plus
  `ownership.claims`.

The metric deltas match those facts:

| Metric | Delta | Why it is expected |
| --- | ---: | --- |
| `llamacpp:cache_evicted_payload_descriptors{mode="hybrid"}` | `+1` | checkpoint descriptor `2` becomes evicted |
| `llamacpp:cache_payload_evictions_total{mode="hybrid"}` | `+1` | checkpoint payload is capacity-evicted |
| `llamacpp:cache_hot_payload_descriptors{mode="hybrid"}` | `-2` | exact leaves hot for cold and checkpoint leaves hot for evicted |
| `llamacpp:cache_cold_payload_count{mode="hybrid"}` | `+1` | exact payload `1` becomes the single cold payload |

The driver still expects hot descriptor delta `-1` and cold payload count delta
`0` at `stage39-two-layer-pressure.ps1:1157-1160`. That expectation fits an
older one-descriptor tombstone check, not the natural same-owner TP-39-03
transition now required by the test plan: exact-first demotion fills cold, then
checkpoint pressure evicts because the cold exact sibling is excluded by owner.

Product metric definitions support the observed deltas. `get_stats()` counts
descriptor residency from `payload_descriptors`; `server-context.cpp` exports
`cache_hot_payload_descriptors`, `cache_evicted_payload_descriptors`, and
`cache_cold_payload_count` from those stats. A cold exact descriptor therefore
must decrease hot descriptors and increase cold payload count.

## Findings

| ID | Finding | Classification | Owner | Required correction |
| --- | --- | --- | --- | --- |
| F39-QA11-01 | `Assert-Tp3903` rejects the valid TP-39-03 descriptor and residency deltas. It expects hot descriptors `-1` and cold payload count `0`, but the live same-owner proof correctly produces hot descriptors `-2` and cold payload count `+1`. | Driver assertion bug | Developer | Update the TP-39-03 driver assertion to require the tuple set produced by the current contract: evicted descriptors `+1`, payload evictions `+1`, hot descriptors `-2`, and cold payload count `+1`. Keep exact terminal topology, cold-file, decision, transaction, and leak checks unchanged. |
| F39-QA11-02 | Coverage blocks remain unrun because D39-QA-11 stopped before full `Assert-Tp3903` PASS. | Blocked by driver assertion | QA after Developer fix and review | Repeat the D39-QA order after the driver fix review. Run coverage only after the canonical TP-39-03 node reaches full `Assert-Tp3903` PASS. |

## Correction scope

Owner: Developer.

Permitted driver-only correction:

- Update `stage39-two-layer-pressure.ps1` TP-39-03 descriptor/residency delta
  assertion.
- Add pure PowerShell 7 and Windows PowerShell 5 coverage for the corrected
  TP-39-03 deltas, including negatives for stale hot `-1` and cold `0`
  expectations.
- Preserve TP-39-02 and TP-39-04 expectations unless their own authorized
  evidence requires a separate change.

Out of scope:

- Product cache code changes.
- Fixture, workload, seam, budget, threshold, route, stage-plan, or coverage
  policy changes.
- Reclassifying the observed exact-cold/checkpoint-evicted terminal state.

## Retest scope

Developer fix evidence required before QA rerun:

- PowerShell 7 parser PASS.
- Windows PowerShell 5 parser PASS.
- PowerShell 7 `-MetricValidationSelfTest` PASS.
- Windows PowerShell 5 `-MetricValidationSelfTest` PASS.
- Focused pure proof that TP-39-03 accepts `+1/+1/-2/+1` and rejects the stale
  `+1/+1/-1/0` expectation.

QA retest after Developer and Architect review:

- Repeat Manager Part 191's D39-QA-11 order.
- Use a fresh clean Release seam-ON build of the full D39-QA target set.
- Run PowerShell 7 and Windows PowerShell 5 parser/pure checks.
- Run one canonical TP-39-03 node.
- Run the four Parts 149 and 155 coverage blocks only after full
  `Assert-Tp3903` PASS.

## Handoff

Next durable implementation record:
`._design_docs/cache-handling-phase39-implementation/part-192-developer-d39-qa11-results-review-20260717.md`.

No code was changed in this review session.
