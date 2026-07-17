# Stage 39 Developer results review

Date: 2026-07-12
Reviewed report: `test-report-20260712-02.md`
Verdict: REWORK REQUIRED

## Evidence checked

The QA totals are correct: 7 PASS, 0 FAIL, 8 BLOCKED, 0 SKIP. The cited
artifact tree exists. Fresh `llama-server` and `test-cache-controller` builds,
the controller run, `ctest -R cache`, and the three accepted live scenarios
support the report's PASS rows. This review also checked Part 43, the Stage 39
test sources, `build.log`, coverage logs, live state files, and driver output.

No observed result establishes a Stage 39 product defect. Closure is blocked by
test automation, workload selection, and coverage tooling.

## Triage

| Item | Classification | Finding | Owner | Exact retest scope |
| --- | --- | --- | --- | --- |
| TP-39-02 | Test automation gap | Existing transaction tests do not map equal-rank payload-ID tie-breaking to the full room-making contract and live tuple. | Developer: add focused assertions and mapping. QA: execute. | Named focused tie-break test plus live `retained_cold/cold_room_made`; verify victim order, tombstones, incoming commit, accounting, and zero topology loss. |
| TP-39-03 | Workload mismatch | Focused reason selection passes, but no live workload reaches positive hot and cold budgets with no eligible cold victim. | QA automation | Rerun one measured both-filled workload; prove resident pair size, both budgets, eligibility calculation, `evicted/both_filled`, bounded bytes, and retained topology. |
| TP-39-04 | Workload mismatch | The 8/16 MiB run fitted cold; the 1/1 MiB rerun admitted no Stage 39 candidate. Neither run exercised oversized-both. | QA automation | Choose budgets from measured resident and immutable serialized pair sizes. Require both positive budgets below the same pair, `evicted/oversized_both`, no partial pair, and bounded gauges. |
| TP-39-07 | Test automation gap | Target/draft helpers exist, but no named row proves atomic commit, restore, rollback, and eviction together. | Developer | Add or map named focused target/draft cases for all four transitions; rerun `test-cache-controller` and preserve assertion-level row mapping. |
| TP-39-08 | Test automation gap | No Stage 39 mapped case independently pressures exact-blob and checkpoint descriptors on one entry. | Developer | Named focused test for each descriptor pressure path; verify ranking, surviving owners, independent accounting, and zero pruning. |
| TP-39-09 | Test automation gap | Older protected-root tests exist, but no Stage 39 mapped pressure case proves root/descendant ownership and cleanup. | Developer | Named focused protected-root/live-descendant case; verify ordering, valid descendant restore, ownership-safe cleanup, no entry removal, and zero pruning. |
| TP-39-10 | Test automation gap | Existing concurrency tests are not mapped to concurrent Stage 39 cold transactions and final decision cardinality. | Developer | Named production-path concurrent-slot transaction test; verify deterministic totals, no partial visibility/deadlock, and exactly one decision row per candidate. |
| TP-39-11 | Test automation gap | Canonical driver has no legacy scenario or equivalent captured run. | QA automation | Add legacy-mode scenario and rerun equivalent requests; compare responses/cache behavior and prove zero delta or absence for both Stage 39 metric families. |
| Required-target build | Test automation gap | `test-step6-demotion-protocol.cpp` still calls removed `process_completions` and debug worker APIs. This is stale test code, not product compilation evidence. | Developer | Update every stale call in the required target set, then clean Release-build all Part 43 focused targets plus `llama-server`; rerun focused binaries and `ctest -R cache`. |
| Changed-line coverage | Test automation gap + infra/tooling | Coverage script expected binaries the clean build did not produce, used a relative model path from the wrong process directory, and got no `.cov` even from exit-0 binaries. `test-step10-metrics` also exited 1. No percentage exists. | Developer: correct target/path mapping. QA/tooling owner: validate OpenCppCoverage and execute. | Clean-build the complete corrected coverage target list; run every target successfully; start profiled server with an absolute fixture path; prove `.cov` creation with one smoke binary before full merge; generate changed-line report for Stage 39 hybrid files and require at least 80%. |

## Gate

REWORK REQUIRED. No production-code fix is assigned from this report. Developer
owns focused-test mapping, stale required targets, and coverage-script target/path
corrections. QA owns measured live workloads and final execution. Coverage
tooling must produce a smoke `.cov` before another full coverage run.

Return to fresh QA only after all eight blocked rows have executable evidence,
the full required-target build is clean, and coverage automation can produce a
report. QA must then rerun TP-39-01 through TP-39-15 because build and automation
changes affect the common evidence baseline, with focused attention on TP-39-02
through TP-39-04 and TP-39-07 through TP-39-11.
