# Part 192: Developer D39-QA-11 results review

Date: 2026-07-17
Status: REWORK REQUIRED
Input report: `../.test_reports/test-report-20260717-11.md`
Developer review: `../.test_reports/test-report-20260717-11-developer-review.md`

## Scope

Manager Part 191 authorized D39-QA-11: fresh clean Release seam-ON full target
build, PowerShell 7 and Windows PowerShell 5 parser and pure checks, one
canonical TP-39-03 node, then four coverage blocks only after full
`Assert-Tp3903` PASS.

QA completed the build and shell gates. The canonical TP-39-03 node failed in
`Assert-Tp3903` after the guarded apply completed. Coverage did not run. This
part records Developer classification only. No product code, driver code,
fixture, workload, budget, threshold, seam, coverage policy, commit, push, PR,
or reviewer response was changed.

## Evidence reviewed

- `._design_docs/cache-handling-phase39-implementation/part-191-manager-d39-qa11-rerun-gate-20260717.md`
- `._design_docs/.test_reports/test-report-20260717-11.md`
- `._test_output/test-report-20260717-11/setup/`
- `._test_output/test-report-20260717-11/parser-pure/`
- `._test_output/test-report-20260717-11/TP-39-03-node/`
- `._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1`
  around `Assert-Tp3903`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `._design_docs/cache-handling-test-plan/part-43-stage39-two-layer-retention.md`

## Classification

F39-QA11-01 is a driver assertion bug.

The product reached the canonical TP-39-03 state:

- guarded apply consumed the request and completed pressure;
- exact descriptor `1` ended cold;
- checkpoint descriptor `2` ended evicted;
- final cold inventory contains one exact `.cold` file;
- apply-window logs recorded one `retained_cold/cold_room`, one `commit/none`,
  and one `evicted/both_filled`;
- terminal proof recorded the same decisions and final topology.

The failing assertion is `stage39-two-layer-pressure.ps1:1157-1160`. The live
metrics are:

```text
llamacpp:cache_evicted_payload_descriptors{mode="hybrid"}  +1
llamacpp:cache_payload_evictions_total{mode="hybrid"}      +1
llamacpp:cache_hot_payload_descriptors{mode="hybrid"}      -2
llamacpp:cache_cold_payload_count{mode="hybrid"}           +1
```

Those deltas are internally consistent. Before apply, proof rows show two hot
same-owner descriptors: exact payload `1` and checkpoint payload `2`. After
apply, exact `1` leaves hot and becomes cold; checkpoint `2` leaves hot and
becomes evicted. Product metrics count descriptor residency from
`payload_descriptors`, so hot must drop by two and cold payload count must rise
by one.

This is not a product accounting bug, because the metric definitions and the
terminal proof agree. It is not an execution blocker, because the server ran,
applied the request, emitted logs and metrics, and cleaned up. It is not a
design mismatch, because the current TP-39-03 test plan requires natural
same-owner exact-first demotion followed by checkpoint `both_filled` eviction.

## Required correction

Owner: Developer.

Correct only the PowerShell driver assertion path:

1. Update the TP-39-03 descriptor/residency delta assertion to require:
   - evicted payload descriptors `+1`;
   - payload evictions `+1`;
   - hot payload descriptors `-2`;
   - cold payload count `+1`.
2. Add pure coverage in `-MetricValidationSelfTest` for the corrected TP-39-03
   deltas.
3. Add negatives that reject the stale hot `-1` and cold `0` expectation.
4. Preserve existing TP-39-03 decision, transaction, terminal proof, cold-file,
   topology, and secret-leak assertions.

Product cache code, fixture, workload, seam, budget, threshold, route behavior,
stage plan, and coverage policy stay out of scope.

## Retest scope

Developer fix evidence before QA rerun:

- PowerShell 7 parser PASS.
- Windows PowerShell 5 parser PASS.
- PowerShell 7 `-MetricValidationSelfTest` PASS.
- Windows PowerShell 5 `-MetricValidationSelfTest` PASS.
- Focused pure proof that TP-39-03 accepts `+1/+1/-2/+1` and rejects
  `+1/+1/-1/0`.

QA retest after Developer fix review:

- Repeat Manager Part 191's D39-QA-11 order.
- Start from a fresh clean Release seam-ON full target build.
- Run PowerShell 7 and Windows PowerShell 5 parser/pure gates.
- Run one canonical TP-39-03 node.
- Run the four Parts 149 and 155 coverage blocks only after full
  `Assert-Tp3903` PASS.

## Handoff

Next owner: Developer for the driver-only descriptor/residency delta correction.

Coverage remains blocked until canonical TP-39-03 reaches full
`Assert-Tp3903` PASS under the Manager-authorized order.
