# Test plan part 31: Stage 26 metrics alignment and Stage 24/25 carry-over

Status: closed; final report -01; D-CLOSURE-26-01
Date: 2026-06-26
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Branch: work-branch
Owner: QA (execution) and Architect (closure sweep)
Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)
Scope: validation surface for Stage 26 cold-store accounting unit
tests, fixture assertions (SEH activation, label uniqueness, metric
format, runner scrape), and Stage 24 S02/S03 rerun.

## References

Design:

- [Stage 26 design](../cache-handling-phase26-design.md)
- [Stage 26 design part 7](../cache-handling-phase26-design/part-07-test-plan.md)

Implementation:

- [Stage 26 implementation](../cache-handling-phase26-implementation.md)
- [Stage 26 implementation part 6](../cache-handling-phase26-implementation/part-06-implementation-evidence-20260625.md)
- [Stage 26 implementation part 7](../cache-handling-phase26-implementation/part-07-architect-implementation-review-20260626.md)
- [Stage 26 Manager closure part 8](../cache-handling-phase26-implementation/part-08-manager-closure-20260626.md)

Prior plan rules:

- [Part 7: test report quality and templates](./part-07-test-report-quality-and-templates.md)
- [Part 24: test output folder convention](./part-24-test-output-folder-convention.md)
- [Part 29: Stage 24 chat S02/S03 comparison](./part-29-stage24-chat-s02-s03-comparison.md)
- [Part 30: Stage 25 atomic transactional](./part-30-stage25-atomic-transactional.md)

Final report:

- [test-report-20260626-01.md](../.test_reports/test-report-20260626-01.md)

## Binding decisions

- D-EXEC-26-01: SEH handler + crash-dump infrastructure VERIFIED via
  TA-26-FA-01 smoke trigger (223 KB minidump at
  `D:\tmp\test-crash-dump\llama-server-19360-20260626-003941.dmp`).
  Runner-script gap: `stage24-chat-s02-s03-comparison.ps1` lines 933-934
  do not pass `--crash-dump-dir`; one-line fix carried forward.
- D-EXEC-26-02: R26-OBS-01 demote queue saturation (32/32) is
  observation, not product bug. Promote to Stage 27 demote-throughput
  investigation under concurrent hybrid workload.
- D-EXEC-24-03 (carry-over): silent server crash reproduces at request
  258 `s03-exact-0-1` (vs Stage 24 -06's req 281 `s03-new-6-0`; Stage
  25 -01's req 258 `s03-exact-0-1`). Cache state at death 637 tokens /
  502 MiB (was 4073 tokens / 505 MiB in -06). New: `demotion queue full
  (32/32)` warnings present. Stage 26 SEH handler NOT triggered because
  runner omits `--crash-dump-dir` (D-EXEC-26-01). Still
  BLOCKED-structural-not-infra; not a Stage 26 regression.
- D-CLOSURE-26-01: close Stage 26. 12 test rows (10 PASS / 1 PARTIAL /
  1 REPRODUCED / 1 DELTA-RECORDED) per final report
  test-report-20260626-01.md. 0 new Stage 26 product bugs. Code
  UNCOMMITTED per AGENTS.md; user approval required for commit.

## Scope and exclusions

In scope:

- Cold-store per-id accounting unit tests (TP-26-UT-01..05).
- Fixture assertions: SEH activation (TA-26-FA-01), label uniqueness
  (TA-26-FA-02), metrics format compliance (TA-26-FA-03), runner
  MetricNames scrape (TA-26-FA-04).
- Stage 24 S02/S03 rerun (TP-26-IT-01): native-legacy and
  hybrid-stage24 legs under the post-fix binary.
- D-EXEC-24-03 reproduction check (TP-26-IT-02).
- Cross-stage latency delta (TP-26-PF-01).

Out of scope:

- Product code changes (developer-owned in Stage 26).
- Stage 24 runner script edits (D-EXEC-26-01 carries the runner-flag
  fix as a follow-up for the next rerun).
- Tracker, document-index, and report body edits.
- New CLI flags beyond `--crash-dump-dir` (already approved).
- New metric names beyond the rename map in part-02.

## Test ID summary

| ID | Category | Description | Final verdict |
| --- | --- | --- | --- |
| TP-26-UT-01 | Cold-store unit | `cold_metric_tracks_per_id_bytes` | PASS |
| TP-26-UT-02 | Cold-store unit | `cold_metric_decrements_on_evict` | PASS |
| TP-26-UT-03 | Cold-store unit | `cold_metric_decrements_on_cleanup` | PASS |
| TP-26-UT-04 | Cold-store unit | `cold_metric_no_double_count_on_redemote` | PASS |
| TP-26-UT-05 | Cold-store unit | `cold_payload_files_count_matches_disk` | PASS |
| TA-26-FA-01 | Fixture assertion | SEH activation smoke trigger | PASS |
| TA-26-FA-02 | Fixture assertion | Label uniqueness check | PASS |
| TA-26-FA-03 | Fixture assertion | Metric format compliance check | PASS |
| TA-26-FA-04 | Fixture assertion | Runner MetricNames scrape | PASS |
| TP-26-IT-01 | Integration | Stage 24 rerun (S02 + S03) | PARTIAL |
| TP-26-IT-02 | Integration | D-EXEC-24-03 reproduction | REPRODUCED |
| TP-26-PF-01 | Performance | Cross-stage latency (PF-03) | DELTA-RECORDED |

Final counts: 10 PASS, 1 PARTIAL, 1 REPRODUCED, 1 DELTA-RECORDED.

## Evidence paths

- Per-leg `requests.jsonl`, `summary.json`, `metrics-after.txt`,
  `server.err.log` under `._test_output/stage26-rerun-20260626-01/`.
- Per-row `comparison.json` per S02/S03 row.
- Run root: `._test_output/stage26-rerun-20260626-01/`.
- Durable report: `._design_docs/.test_reports/test-report-20260626-01.md`.
- SEH minidump evidence: `D:\tmp\test-crash-dump\llama-server-19360-20260626-003941.dmp`
  (223276 bytes; TA-26-FA-01 smoke trigger).

## Risks

| ID | Risk | Mitigation |
| --- | --- | --- |
| R-26-TP-01 | Stale CUDA Release binary masks cold-store or metrics fixes. | Clean `build-cuda` build mandatory before execution; record binary mtime and size in report. |
| R-26-TP-02 | D-EXEC-24-03 silent crash reproduces without SEH dump. | TA-26-FA-01 verifies SEH infra separately via smoke trigger; runner-flag fix carried forward as D-EXEC-26-01 follow-up. |
| R-26-TP-03 | PF-03 cross-stage latency comparison has no numeric Stage 24 -06 baseline. | Treat TP-26-PF-01 as DELTA-RECORDED, not closed; record hybrid-vs-native median deltas for future comparison. |
| R-26-TP-04 | R26-OBS-01 demote queue saturation warnings present in both hybrid legs. | Observation, not blocker; Stage 26 cold-store accounting correctly reports 0 when no demotion succeeds. |

## Handoff

Plan closed with final report
[test-report-20260626-01.md](../.test_reports/test-report-20260626-01.md).
Closure accepted per D-CLOSURE-26-01 on 2026-06-26. Per-row final
classification: 10 PASS / 1 PARTIAL (TP-26-IT-01) / 1 REPRODUCED
(TP-26-IT-02) / 1 DELTA-RECORDED (TP-26-PF-01). Code changes
UNCOMMITTED per AGENTS.md; user approval required for commit.
Follow-ups:

- (D-EXEC-26-01) stage24 runner add `--crash-dump-dir` flag (one-line
  fix)
- (D-EXEC-26-02) demote queue saturation R26-OBS-01 to Stage 27
- (D-EXEC-24-03 carry) rerun S03 hybrid with `--crash-dump-dir`,
  load minidump, capture stack at chat-format normalization
- (D-EXEC-24-03 carry) widen scope to S02 hybrid earlier-crash
  observation
- (D-EXEC-24-03 carry) cold-store metric vs filesystem drift
  observation
- (PF-03 carry) Stage 24 -06 hybrid median baseline never recorded;
  future Stage 24 reruns must emit per-request hybrid medians to
  close PF-03 within 25%

This file uses LF line endings, plain ASCII labels, no BOM, no
trailing whitespace, and stays under the 300-line durable-doc cap.
