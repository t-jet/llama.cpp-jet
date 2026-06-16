# Stage 15 test-results review

Source: [./test-report-20260612-01.md](./test-report-20260612-01.md)
Date: 2026-06-12
Reviewer session: Developer (Stage 15 test-results review, fresh session). Reviewer did not author the test reports.

## Status

Verdict: DEFER.

Counts:

| Class | Count | Notes |
| --- | --- | --- |
| BLOCKING | 0 | No product bugs and no closure-contract regressions. |
| Non-blocking | 3 | B02 BLOCKED-environment, B05 and B06 BLOCKED-workload. |
| INFO | 5 | S01..S08 deferred, L01..L03 deferred, 1 pre-existing test-stage10-policy-lru, 4 out-of-scope E13 rows (E13-01c, E13-07, E13-08, E13-10). |

Reason for DEFER: stress rows S01..S08 and longrun rows L01..L03 were not run in this session because the conversation context reached its limit. The user can re-run those rows in a future session. No product bug, no closure-contract regression, and no test-harness regression is associated with the deferral.

## Per-row classification

### Sub-session 1 (non-long-running categories)

#### C-ctest (W1)

| Row | QA verdict | Developer classification |
| --- | --- | --- |
| 67 unique ctest executables (test-stage10-policy-lru is the one pre-existing block; appears twice in the QA table) | 66 PASS, 1 BLOCKED-pre-existing, 0 FAIL | PASS for the 66 rows. The single BLOCKED-pre-existing row is `test-stage10-policy-lru` with STATUS_STACK_BUFFER_OVERRUN (exit 0xc0000409). Pre-existing Stage 10 semantic bug, unchanged from the 2026-06-12 comprehensive fix. Per part-25, does not block Stage 15 closure. No product regression on the current tree (work-branch HEAD 13d3cd863). |

#### C-pytest (W2)

| Row | QA verdict | Developer classification |
| --- | --- | --- |
| test_invalid_cache_mode_is_rejected | PASS | PASS, no product bug. |
| test_cache_metrics_default_legacy | PASS | PASS, no product bug. |
| test_hybrid_cache_metrics_and_repeated_restore | XFAIL | XFAIL per the test plan C01/C02 fixture contract. Expected. Not a product bug. |
| test_hybrid_cache_restore_without_request_cache_prompt_reports_cache_n | PASS | PASS, no product bug. |

#### C-public-http (W3)

| Row | QA verdict | Developer classification |
| --- | --- | --- |
| E13-01a, 01b, 01d, 02, 03, 04, 05, 06, 09, 11, 12, 13, 14, 15, 16 | 15 PASS | PASS, no product bug. E13-14 bounded `cache metadata:` line and E13-13 `diagnostic_source` namespace isolation verified at log lines 1314 and 1501 of `qwen-hybrid-main-server.err.log`. Leak scan clean. |
| E13-01c | BLOCKED-fixture | BLOCKED-out-of-scope. Qwen3-0.6B has no mmproj; multimodal fixtures exist but server was started without `--mmproj`. Per Stage 13 agreement, acceptable. |
| E13-07 | BLOCKED-fixture | BLOCKED-out-of-scope. 501 not_supported_error: text-only model. Acceptable. |
| E13-08 | BLOCKED-fixture | BLOCKED-out-of-scope. Same as E13-07. Acceptable. |
| E13-10 | BLOCKED-setup | BLOCKED-out-of-scope. Server not started with `--slot-save-path`; save/restore/erase cannot be exercised. Schemas unchanged (no FAIL). |

#### C-regression (W4)

| Row | QA verdict | Developer classification |
| --- | --- | --- |
| R10..R23, H30..H74 in-scope rows | covered by ctest and pytest | PASS, no new regression introduced. R10..R23 covered by Step 1..13 ctest binaries. H30..H74 in-scope rows covered by the same ctest binaries. H35, H36, H37 remain BLOCKED-protected-evidence; covered by `test-cache-controller.cpp` per part-03. |

#### C-closure (W5)

| Row | QA verdict | Developer classification |
| --- | --- | --- |
| T114 combined line rate 0.8992 (6217/6914) | PASS | PASS. >= 0.80 threshold met. |
| T114a product-only line rate 0.8284 (2544/3071) | PASS | PASS. >= 0.70 threshold met. |
| T115 per-file aggregation | PASS | PASS. Deduped by basename + line, 19 files each appear once. |
| T121 four `cache_checkpoint_*` rows exposed | PASS | PASS. Four rows present, 1 non-zero (admission_failures). MTP fixture loaded successfully. |

### Benchmark sub-session (B01..B08)

| Row | QA verdict | Developer classification |
| --- | --- | --- |
| B01 exact-blob hit rate | PASS-observed-zero (0.0000) | PASS. Observed zero, not a regression. V2 used 12-iter k6 prefix-match rate with a fixed prompt; this focused re-run issued 7 distinct prompts with shared 8-message system prefix. The per-prompt user text differs in each request, so the exact-blob key (prompt hash) is different for every request. 0 hits is expected workload behavior, not a product bug. |
| B02 checkpoint hit rate | BLOCKED-metric-not-exposed | BLOCKED-environment. No checkpoint-specific counter is exposed in this build's /metrics. Closest observed counter: `llamacpp_cache_hot_payload_descriptors=1`. Build/configuration limitation, not a product defect. |
| B03 cold transition frequency | PASS-observed-zero (0) | PASS. demotions=0, promotions=0, cold_evictions=0. Matches V2 baseline (0 demote, 0 promote, 0 cold ev). |
| B04 end-to-end token throughput | PASS (3.0270 TPS) | PASS. n=7, predicted=112 tokens, wall=37s. No V2 reference for direct comparison. |
| B05 restore latency p50 | BLOCKED-no-successful-restores | BLOCKED-workload. All 7 attempts returned "no exact match found" and degraded to "rendered text boundary inference". Workload limitation (distinct prompts), not a product defect. |
| B06 restore latency p99 | BLOCKED-no-successful-restores | BLOCKED-workload. Same as B05. |
| B07 total cache hits + misses | PASS (hits=0, misses=7, total=7) | PASS. Total 7 (0 hits, 7 misses) recorded. |
| B08 per-request CPU time | PASS (avg 5068.11ms, p50 5051.05ms, p99 5171.02ms) | PASS. n=7. No V2 reference for direct comparison. |

## Product bugs found

None.

Sub-session 1: 0 product bugs. The single ctest BLOCKED row is pre-existing and per part-25 does not block Stage 15 closure. The 4 E13 BLOCKED rows are out-of-scope per Stage 13 agreement. The pytest XFAIL row is an expected per-row contract outcome.

Benchmark: 0 product bugs. The 3 BLOCKED rows are environment or workload limitations:

- B02: build does not expose a checkpoint-specific counter.
- B05, B06: the 7-prompt batch with distinct user text yields zero exact-blob matches, so no successful restore is recorded.

B01 delta vs V2: -1.0000 explained by workload difference. V2 used a fixed prompt with MtpVariant=2 and reported `prefix_match_rate=1.0000` (exact-prefix match). This focused re-run issued 7 distinct prompts whose exact-blob key (prompt hash) differs in every request. The hybrid cache prefix-match rate requires the V2 k6 driver and a longer measurement window, which the 5-minute focused re-run did not produce. 0 hits is expected workload behavior, not a product regression.

## Closure contract re-verification

| Item | Threshold | Observed | Verdict | Evidence |
| --- | --- | --- | --- | --- |
| W1 ctest coverage | 0 FAIL | 66 PASS, 1 BLOCKED-pre-existing | PASS | `test-report-20260612-01.md` C-ctest table |
| W2 pytest coverage | 0 FAIL | 3 PASS, 1 XFAIL | PASS | `test-report-20260612-01.md` C-pytest table |
| W3 public-http coverage | 0 FAIL | 14 PASS, 4 BLOCKED-out-of-scope | PASS | `test-report-20260612-01.md` C-public-http table |
| W4 regression coverage | covered | covered by ctest and pytest | PASS | `test-report-20260612-01.md` C-regression section |
| W5 closure contracts | T114, T114a, T115, T121 PASS | T114 0.8992, T114a 0.8284, T115 PASS, T121 PASS | PASS | `test-report-20260612-01.md` C-closure section |
| AA1 T114 combined rate | >= 0.80 | 0.8992 | PASS | T114 row in C-closure |
| AA2 T114a product-only rate | >= 0.70 | 0.8284 | PASS | T114a row in C-closure |
| AA3 T115 per-file aggregation | dedup rule met | 19 files, each once | PASS | T115 row in C-closure |
| AA4 T121 four `cache_checkpoint_*` rows | 4 rows present | 4 rows present, 1 non-zero | PASS | T121 row in C-closure |
| AA5 E13-01..E13-16 | 14 PASS or BLOCKED-out-of-scope | 14 PASS, 4 BLOCKED-out-of-scope | PASS | C-public-http table |
| AA6 MTMD placeholder path | PASS | T121 row exposure confirms MTP path | PASS | T121 row in C-closure |
| AA7 diagnostic-source namespace isolation | PASS | C-public-http E13-13 PASS | PASS | C-public-http E13-13 row |
| AA8 bounded `cache metadata:` format | PASS | C-public-http E13-14 PASS, leak scan clean | PASS | C-public-http E13-14 row, log lines 1314 and 1501 |

## Stress and longrun deferral

S01..S08 and L01..L03 were not run in this session. Reason: conversation context limit reached before the stress and longrun sub-sessions could open. The deferral is a scope limitation, not a product bug. The user can re-run the rows in a future session per the part-25 execution order:

- C-stress: per-row driver under `._design_docs/cache-handling-test-scripts/stress/stress_s12_sXX_*.ps1`.
- C-longrun: kickoff driver `kickoff-v2-stress-longrun.ps1` plus per-row driver under `._design_docs/cache-handling-test-scripts/longrun/longrun_s12_lXX_*.ps1`. The 6-hour L01 row runs to completion or cap-exit per design part-03.

Until the rows are re-run in a future session, the closure-contract rows S01..S08 and L01..L03 cannot be marked PASS at the Stage 15 level. The DEFER verdict is consistent with the part-04 bug-fix loop termination rule A: closure is not at issue here, but the row matrix for S01..S08 and L01..L03 is incomplete. The Manager may open a plan-change decision in a future session to either:

- Re-run the rows in a fresh session and produce a new test report at the same D5 path with the next suffix.
- Mark S01..S08 and L01..L03 as `DEFERRED-OUT-OF-SCOPE-FOR-SESSION` and close Stage 15 with the in-scope rows only.

This Developer review does not select between the two options; that is a Manager plan-change decision per the bug-fix loop termination rule B.

## Recommended next action

DEFER: stress rows S01..S08 and longrun rows L01..L03 were not run in this session due to conversation context limits. No product bugs found and no closure-contract regressions. The user can re-run the stress and longrun rows in a future session per the part-25 execution order. Sub-session 1 and the benchmark sub-session are READY for Manager closure once the S/L deferral is decided.

## Handoff state

| Field | Value |
| --- | --- |
| Review verdict | DEFER |
| Reason | Stress (S01..S08) and longrun (L01..L03) deferred, no product bugs |
| Next gate | Manager test-results gate decision (DEFER handling) |
| Next owner | Manager |
| BLOCKING count | 0 |
| Non-blocking count | 3 (B02, B05, B06) |
| INFO count | 5 (S01..S08 deferred, L01..L03 deferred, 1 pre-existing test-stage10-policy-lru, 4 out-of-scope E13 rows) |
| Product bug count | 0 |
| Files modified by this review | this file only; no edits to the test report, the benchmark report, the implementation log, the design docs, or any other file |
