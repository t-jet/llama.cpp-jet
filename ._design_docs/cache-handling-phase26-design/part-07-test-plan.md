# Part 7: Test plan

Status: design draft
Date: 2026-06-25
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Author: Architect
Scope: tests for carry-over fixes, metrics alignment, and Stage 24
rerun.

## Test row categories

This stage produces three classes of tests:

1. Unit tests (TP-26-UT-*) for the cold-store metric accounting fix
   (part-04).
2. Fixture assertions (TA-26-FA-*) for metrics format and label
   uniqueness in `stage24-chat-s02-s03-comparison.ps1`.
3. Integration rows (TP-26-IT-*) that mirror Stage 24 S02/S03 cases
   and verify the rerun evidence.

## Unit tests (TP-26-UT-*)

| ID | Test name | Source fixture | Asserts |
| --- | --- | --- | --- |
| TP-26-UT-01 | `cold_metric_tracks_per_id_bytes` | synthetic demote + evict | `n_cold_payload_bytes` == sum of per-id write sizes |
| TP-26-UT-02 | `cold_metric_decrements_on_evict` | synthetic demote + evict | `n_cold_payload_bytes` returns to zero after every descriptor evicted |
| TP-26-UT-03 | `cold_metric_decrements_on_cleanup` | synthetic demote + cold cleanup | `n_cold_payload_bytes` matches on-disk bytes after cleanup |
| TP-26-UT-04 | `cold_metric_no_double_count_on_redemote` | demote + evict + demote same id | `n_cold_payload_bytes` tracks latest write size, not cumulative |
| TP-26-UT-05 | `cold_payload_files_count_matches_disk` | synthetic demote + cold cleanup | `n_cold_payload_count` == readdir count |

Total: 5 unit tests; target count 132 + 5 = 137.

## Fixture assertions (TA-26-FA-*)

| ID | Check | Source | Asserts |
| --- | --- | --- | --- |
| TA-26-FA-01 | `metrics_format_pass` | runner post-leg | grep `^llamacpp_` (underscore) in `metrics-after.txt` returns 0 matches |
| TA-26-FA-02 | `metrics_format_pass` | runner post-leg | grep `^llamacpp:` (colon) in `metrics-after.txt` returns >= 1 match |
| TA-26-FA-03 | `label_uniqueness_pass` | runner post-leg | grep `,mode=".*",mode="` returns 0 matches |
| TA-26-FA-04 | `cold_store_drift_ratio` | runner post-leg | filesystem / metric, recorded as `cold_store_drift_ratio` |

The runner emits these as boolean or numeric fields in the leg
summary JSON. The runner classifies the leg PASS only when all
boolean fields are true.

## Integration rows (TP-26-IT-*)

| ID | Test | Source | Verdict criteria |
| --- | --- | --- | --- |
| TP-26-IT-01 | S02-chat native rerun | part-05 command | native leg PASS; no regression |
| TP-26-IT-02 | S02-chat hybrid rerun | part-05 command | hybrid leg PASS or crash-with-dump; if PASS, Stage 25 follow-up (e) closed |
| TP-26-IT-03 | S03-chat native rerun | part-05 command | native leg PASS; no regression |
| TP-26-IT-04 | S03-chat hybrid rerun | part-05 command | hybrid leg PASS or crash-with-dump; crash dump loaded and stack captured if crash |

For PF-03 closure, the runner emits a per-leg latency comparison
table. PF-03 is closed when rerun latency is within 25% of Stage 24
-06 baseline on hybrid legs.

## Tests NOT in scope

- No new stress / benchmark tests. Stage 20 stress and Stage 21
  heavy-tier coverage stays as-is.
- No new prompt-set generator. Reuses Stage 24 runner's existing
  S02 / S03 prompt sets.
- No new model fixture. Reuses Qwen3.5-4B-MTP fixture.
- No new coverage tool. Reuses the existing coverage methodology
  (no coverage in Stage 26; cold-store unit tests cover the
  accounting fix).

## Evidence contract

The implementation plan produces a `tests/test-cache-controller.cpp`
delta with the 5 new unit tests. The runner script delta produces
the new fixture assertions. The Stage 24 rerun produces a
`test-report-20260626-NN.md` with the per-row verdicts and the
PF-03 latency comparison.

Per D-CLOSURE-24-01 and AGENTS.md, all code changes are
UNCOMMITTED pending user approval. The Stage 24 rerun binary is
the post-fix binary; the user owns the commit decision per the
prior closures.

## Handoff

Part-07 is reviewable. The test plan summary table maps each design
goal (parts 03, 04, 02, 05) to a test class. Implementation planning
expands each row into the standard test-plan format with pre-state,
test body, and expected outcome.
