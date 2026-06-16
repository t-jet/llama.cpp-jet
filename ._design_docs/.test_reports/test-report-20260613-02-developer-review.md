# Stage 15 test-results review (B05/B06 structural probe, fresh)

Source reports:

- [./test-report-20260612-01.md](./test-report-20260612-01.md) (sub-session 1, non-long-running)
- [./stage15-benchmark-20260613-02.md](./stage15-benchmark-20260613-02.md) (B05/B06 structural probe)
- Prior review (superseded for B02, B05, B06): [./test-report-20260612-01-developer-review.md](./test-report-20260612-01-developer-review.md)
- Source plan: [../cache-handling-test-plan/part-25-stage15-full-test-suite-validation.md](../cache-handling-test-plan/part-25-stage15-full-test-suite-validation.md)
- Bug-fix loop: [../cache-handling-phase15-design/part-04-bug-fix-loop.md](../cache-handling-phase15-design/part-04-bug-fix-loop.md)

Date: 2026-06-13
Reviewer session: Developer (Stage 15 test-results review, fresh session). Reviewer did not author the test reports or the benchmark report.

## Status

Verdict: REWORK.

Counts:

| Class | Count | Notes |
| --- | --- | --- |
| BLOCKING | 0 | No product bugs and no closure-contract regressions. |
| Non-blocking | 3 | B02, B05, B06, all BLOCKED-structural-not-infra, all share one root cause. |
| INFO | 5 | S01..S08 deferred, L01..L03 deferred, 1 pre-existing test-stage10-policy-lru, 4 out-of-scope E13 rows (E13-01c, E13-07, E13-08, E13-10). |

Reason for REWORK: three benchmark rows (B02, B05, B06) are BLOCKED-structural-not-infra with a single shared root cause (MTP save path does not emit checkpoint boundary metadata), and the closure path is blocked on a Manager plan-change decision per the bug-fix loop termination rule B. Sub-session 1 is READY for Manager closure. Stress rows S01..S08 and longrun rows L01..L03 are still deferred and the Manager must decide the S/L deferral handling. No product bug, no closure-contract regression (T114, T114a, T115, T121 all PASS), and no test-harness regression is associated with the deferral or the B02/B05/B06 classification.

## Reclassification summary

The prior review classified B02 as BLOCKED-environment and B05/B06 as BLOCKED-workload. The 20260613-02 benchmark report provides hard evidence that supersedes both:

- B02: the metric path is exposed via /metrics (cache_checkpoint_hits_total, cache_checkpoint_admissions_total, cache_checkpoint_admission_failures_total, cache_checkpoint_restores_total - all four are present at /metrics per T121 in the 20260612-01 report and re-confirmed in 20260613-02 metrics-end.txt). The metric value is 0, not because the counter is missing, but because the MTP save path skips checkpoint admission. Reclassify BLOCKED-environment -> BLOCKED-structural-not-infra.
- B05, B06: the 20260613-01 "task 27 tokens vs entry 30 tokens" length-mismatch hypothesis is REFUTED by two independent length-matched runs (b56 36=36 and rerun30 29=29, both 0 successful restores with LCP prefix 100% match). The cause is the MTP save path storing regular entries instead of checkpoints. Reclassify BLOCKED-workload -> BLOCKED-structural-not-infra.

All three rows now share a single root cause and a single Manager plan-level decision.

## Per-row classification

### Sub-session 1 (C-ctest, C-pytest, C-public-http, C-regression, C-closure)

Same as prior review. Sub-session 1 has 0 product bugs and 0 FAIL rows. The single ctest BLOCKED row is pre-existing test-stage10-policy-lru, unchanged from 2026-06-12. The 4 E13 BLOCKED rows are out-of-scope per Stage 13. The pytest XFAIL row is an expected per-row contract outcome. T114 (0.8992), T114a (0.8284), T115 (dedup rule met), T121 (4 cache_checkpoint_* rows present, 1 non-zero) all PASS. No re-evaluation needed; the prior review table stands.

### C-bench (B01..B08) - reclassification only

| Row | Prior review verdict | New verdict | Evidence for reclassification |
| --- | --- | --- | --- |
| B01 exact-blob hit rate | PASS-observed-zero | PASS-observed-zero (unchanged) | 20260613-02 does not re-evaluate B01; prior rationale stands. |
| B02 checkpoint hit rate | BLOCKED-environment | BLOCKED-structural-not-infra | cache_checkpoint_hits_total=0 at /metrics (path exposed, value 0). 20260613-02 metrics-end.txt: "Final /metrics: llamacpp_cache_entries=1, llamacpp_cache_tokens=29, llamacpp_cache_hits_total=0, llamacpp_cache_misses_total=51, llamacpp_cache_hot_payload_descriptors=1". T121 in 20260612-01 already showed the four cache_checkpoint_* rows. Metric exposure is fine; the value is 0 because the MTP save path skips checkpoint admission. |
| B03 cold transition frequency | PASS-observed-zero | PASS-observed-zero (unchanged) | 20260613-02 does not re-evaluate B03; prior rationale stands. |
| B04 end-to-end token throughput | PASS | PASS (unchanged) | 20260613-02 does not re-evaluate B04; prior rationale stands. |
| B05 restore latency p50 | BLOCKED-workload | BLOCKED-structural-not-infra | 50/50 length-matched 29=29 restores failed with LCP prefix=100% match. 0 successful restore in 50 iterations. Save log: "checkpoint admission skipped (missing checkpoint boundary metadata)". 1 cache_checkpoint_admission_failures, 0 cache_checkpoint_admissions. |
| B06 restore latency p99 | BLOCKED-workload | BLOCKED-structural-not-infra | Same as B05. Independent 36=36 b56 run reaches the same conclusion (50/50 LCP-found, 0 exact-match, 0 restore). |
| B07 total cache hits + misses | PASS | PASS (unchanged) | 20260613-02 does not re-evaluate B07; prior rationale stands. |
| B08 per-request CPU time | PASS | PASS (unchanged) | 20260613-02 does not re-evaluate B08; prior rationale stands. |

## Product bugs found

0 (zero) product bugs.

Sub-session 1: 0 product bugs. The single ctest BLOCKED row is pre-existing and per part-25 does not block Stage 15 closure. The 4 E13 BLOCKED rows are out-of-scope per Stage 13 agreement. The pytest XFAIL row is an expected per-row contract outcome.

C-bench: 0 product bugs. B02 is BLOCKED-structural-not-infra (metric path exposed, value 0 for structural reason). B05, B06 are BLOCKED-structural-not-infra (length-mismatch hypothesis refuted; cause is MTP save path not emitting checkpoint boundary metadata). The structural pattern is consistent across b56 and rerun30 on the same build (13d3cd863), so it is not a regression introduced in this sub-session.

## Closure contract re-verification

| Item | Threshold | Observed | Verdict | Evidence |
| --- | --- | --- | --- | --- |
| T114 combined rate | >= 0.80 | 0.8992 (6217/6914) | PASS | 20260612-01 C-closure T114 |
| T114a product-only rate | >= 0.70 | 0.8284 (2544/3071) | PASS | 20260612-01 C-closure T114a |
| T115 per-file aggregation | dedup rule met | 19 files, each once | PASS | 20260612-01 C-closure T115 |
| T121 cache_checkpoint_* rows | 4 rows present | 4 rows present, 1 non-zero (admission_failures) | PASS | 20260612-01 C-closure T121; re-confirmed in 20260613-02 |
| E13-01..E13-16 | 14 PASS or BLOCKED-out-of-scope | 14 PASS, 4 BLOCKED-out-of-scope | PASS | 20260612-01 C-public-http |
| MTMD placeholder path | PASS | T121 row exposure confirms MTP path | PASS | 20260612-01 C-closure T121 |
| Diagnostic-source namespace isolation | PASS | E13-13 PASS, log lines 1314 and 1501 | PASS | 20260612-01 C-public-http E13-13 |
| Bounded cache metadata format | PASS | E13-14 PASS, leak scan clean | PASS | 20260612-01 C-public-http E13-14 |

## Stress and longrun deferral

S01..S08 and L01..L03 were not run in this session. Reason unchanged from prior review: stress and longrun sub-sessions were not opened before context limits. The deferral is a scope limitation, not a product bug. Per the part-25 execution order:

- C-stress: per-row driver under ._design_docs/cache-handling-test-scripts/stress/stress_s12_sXX_*.ps1.
- C-longrun: kickoff driver kickoff-v2-stress-longrun.ps1 plus per-row driver under ._design_docs/cache-handling-test-scripts/longrun/longrun_s12_lXX_*.ps1. The 6-hour L01 row runs to completion or cap-exit per design part-03.

Until the rows are re-run, the closure-contract rows S01..S08 and L01..L03 cannot be marked PASS at the Stage 15 level. The Manager must decide the S/L deferral handling.

## Manager decision section

The Stage 15 closure path is blocked on two Manager plan-change decisions per the bug-fix loop termination rule B (part-04).

### Decision 1: B02, B05, B06 classification

Recommended closure text (verbatim, copy into the test plan or the Manager status):

> Stage 15 B02, B05, B06: BLOCKED-structural-not-infra. The MTP fixture's
> hybrid cache save path produces entries without checkpoint boundary
> metadata, so the stored entry is never a checkpoint and the
> exact-blob restore check rejects every subsequent identical request.
> The 20260613-01 length-mismatch hypothesis is refuted by the b56 36=36
> run and the 20260613-02 rerun30 29=29 run. Decision: reclassify B02,
> B05, B06 to NOT-IN-SCOPE for the MTP fixture. The Stage 15 part-25
> test plan records that B02, B05, B06 require a fixture that admits
> checkpoints via the natural save path. Future stage to exercise B05,
> B06 on the V2 separate-draft fixture (Qwen3-8B + Qwen3-0.6B draft)
> which had 95/96 and 23/24 hits in V2. B02 (checkpoint hit rate) will
> be re-measured on the same future fixture.

Alternative: Manager may select Option 2 (Developer task to make the MTP save path emit checkpoint boundary metadata, requires Architect design review and a Stage 16 or backport decision) or Option 3 (drop B05/B06 from the Stage 15 matrix, violates the Stage 12 design part 3 acceptance rule and is least preferred). The reclassify option is recommended because it preserves the bench artifact's coverage intent and aligns with the V2 separate-draft fixture's prior 95/96 hit rate.

### Decision 2: S/L deferral handling

Recommended closure text (verbatim, copy into the test plan or the Manager status):

> Stage 15 C-stress (S01..S08) and C-longrun (L01..L03) were not run in
> this session due to conversation context limits. Decision: mark
> S01..S08 and L01..L03 as DEFERRED-OUT-OF-SCOPE-FOR-SESSION and close
> Stage 15 with the in-scope rows only. Future stage to run the stress
> and longrun rows in a fresh session per the part-25 execution order.
> The closure contract for the in-scope rows (T114, T114a, T115, T121,
> E13-01..E13-16, B01..B04, B07, B08) is met. The closure path for the
> deferred rows is owned by the next stage's test plan, not by Stage 15.

Alternative: Manager may re-open C-stress and C-longrun in a fresh QA session and produce a new test report at the same D5 path with the next suffix, then re-run this review. The defer option is recommended because no product bug is suspected on the S/L rows and the prior stage agreement treats S/L deferral as a scope limitation, not a closure blocker.

### Dependency note

The two decisions are independent. The Manager may approve Decision 1 (reclassify B02/B05/B06) and Decision 2 (defer S/L) in the same gate decision, or split them.

## Recommended next action

REWORK: closure requires Manager decisions 1 and 2 above. Developer review is complete; sub-session 1, the C-closure contracts, and the C-bench rows other than B02/B05/B06 are all PASS. The stage cannot be closed until the Manager records both plan-change decisions per the bug-fix loop termination rule B.

## Handoff state

| Field | Value |
| --- | --- |
| Review verdict | REWORK |
| Reason | B02/B05/B06 BLOCKED-structural-not-infra (shared root cause, Manager decision 1) + S/L deferred (Manager decision 2) |
| Next gate | Manager test-results gate decision (B02/B05/B06 reclassify + S/L defer) |
| Next owner | Manager |
| BLOCKING count | 0 |
| Non-blocking count | 3 (B02, B05, B06) |
| INFO count | 5 (S01..S08 deferred, L01..L03 deferred, 1 pre-existing test-stage10-policy-lru, 4 out-of-scope E13 rows) |
| Product bug count | 0 |
| Files modified by this review | this file only; no edits to the test report, the benchmark report, the implementation log, the design docs, or any other file |
| Supersedes | prior review B02, B05, B06 classifications; all other prior review rows stand |
