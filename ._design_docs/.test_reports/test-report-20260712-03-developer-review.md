# Stage 39 Developer review of QA report 20260712-03

Date: 2026-07-12
Verdict: REWORK REQUIRED
Source: `test-report-20260712-03.md`

## Decision

QA recorded 11 PASS, 1 FAIL, and 3 BLOCKED rows. TP-39-15 exposes a product
exporter defect. TP-39-02 through TP-39-04 remain blocked by live workload
control. The Stage 10 binary has a stale serialized-size assertion. Coverage is
blocked by OpenCppCoverage producing no smoke artifact.

No evidence in this run shows that the Stage 39 retention policy selected the
wrong result for a workload that met TP-39-03 or TP-39-04 preconditions. Those
workloads did not reach the required candidate states.

## Findings

| Finding | Class | Evidence | Owner | Required action |
| --- | --- | --- | --- | --- |
| F39-QA3-01 | Product bug | `live-standard/metrics-after.txt` contains `cache_two_layer_decisions_total{mode="hybrid",mode="hybrid",...}`. `server-context.cpp` writes the outer mode and also passes row `mode` as a label. The same code pattern is used for cold-transaction rows. | Developer | Remove the duplicate label at the exporter boundary without changing the bounded internal tuple. Add focused exporter coverage for both Stage 39 families and a live scrape assertion that each label name occurs once. |
| F39-QA3-02 | Test defect | `test-step10-metrics.exe` fails only at `tests/test-step10-metrics.cpp:176`, which requires exactly 125 cold bytes after demotion. Stage 39 cold accounting uses committed serialized bytes, including storage overhead; controller accounting tests already assert exact serialized sizes. No product gauge mismatch was captured. | Developer | Replace the stale payload-only constant with the exact committed serialized size derived from the cold-store contract. Keep count, descriptor, and demotion assertions. |
| F39-QA3-03 | Test workload gap | TP-39-02 has focused multi-victim proof but no live equal-rank tuple, payload-ID order, or before/after victim inventory. | QA, after Developer runner support if needed | Add a deterministic live setup that creates at least two equal-rank eligible cold victims and records IDs, ranks, files, tombstones, and committed incoming object. |
| F39-QA3-04 | Test workload gap | TP-39-03 emitted 17 `retained_cold/cold_room_made` decisions. Eligible victims existed, so the run never established the required no-eligible-victim state. | QA, after Developer runner support | Add workload control that fills both positive layers and makes every cold resident ineligible for reclamation. Record candidate/victim eligibility and reconcile bytes before requiring one `evicted/both_filled`. |
| F39-QA3-05 | Test workload gap | TP-39-04 also emitted `retained_cold/cold_room_made`. Although the measured pair exceeded both configured budgets, the pressured candidate was not the measured oversized pair. | QA, after Developer runner support | Bind the measured pair to the candidate that enters production hot pressure. Record its payload ID and measured resident/serialized bytes, then require one `evicted/oversized_both` and no partial pair. |
| F39-QA3-06 | Infrastructure/tooling blocker | OpenCppCoverage returned exit 0 for the first smoke target but produced no `.cov`. `coverage-console.log` stopped at target 1 and `coverage/01-test-cache-controller.log` contains only `exit: 0`. The script correctly failed closed; no percentage exists. | Developer for diagnostic capture; QA/environment owner for executable/tool repair | Preserve the full OpenCppCoverage command, stdout/stderr, tool version, output path, and post-run file inventory. Prove one smoke `.cov` exists before running the full coverage set. |

## Retest gate

Developer first fixes F39-QA3-01 and F39-QA3-02 and supplies any runner seams
needed by F39-QA3-03 through F39-QA3-05. Architect reviews those code and test
changes before QA reruns.

QA retest must include:

1. Clean Release build of all 11 required focused targets.
2. Direct execution of all 11 focused binaries, including a passing
   `test-step10-metrics.exe` and exporter regression for both Stage 39 families.
3. `ctest -C Release -R cache`.
4. Focused live reruns for TP-39-02, TP-39-03, TP-39-04, and TP-39-15 with the
   inventories and candidate identity described above.
5. One OpenCppCoverage smoke run that creates a readable `.cov`, followed by the
   full fail-closed coverage run. Changed-line coverage must be at least 80%.

Stage 39 stays open. Manager closure is blocked until all 15 rows pass, the
Stage 10 binary passes, and coverage reaches the required threshold.
