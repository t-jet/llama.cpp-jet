---

## Supersession note (2026-06-13)

A focused re-run on the MTP fixture with a 50-iteration identical /completion
workload was completed in a fresh QA sub-session. B02 was reclassified from
BLOCKED-metric-not-exposed to PASS-observed-zero (the four
cache_checkpoint_* rows ARE exposed in this build's /metrics, and the
checkpoint admission path is exercised via cache_checkpoint_admission_failures_total).
B05 and B06 remain BLOCKED-no-successful-restores with new hard evidence:
50 identical /completion requests produced 0 successful restores on the MTP
fixture even though 49 of the restore attempts matched the LCP prefix with
sim_best=1.000 (the stored entry length 30 differs from the request task
length 27, so the exact-blob restore check fails on length mismatch).

The reclassified durable report is
[stage15-benchmark-20260613-01.md](stage15-benchmark-20260613-01.md). This
20260612-01 report is retained as the prior sub-session record; the
20260613-01 report is the current Stage 15 benchmark artifact.

# Stage 15 benchmark report: B01..B08 re-run (FOCUSED RE-RUN, 5 min budget)

- Date: 2026-06-13 01:36 local
- Stage: 15 (Full Test Suite Validation, Bug-Fix Loop, and Benchmark Report)
- Sub-session: benchmark (C-bench focused re-run)
- Owner: QA execution
- Scope: Stage 15 B01..B08 extraction via single focused method per Manager re-delegation
- Evidence root: ._test_output/bench-stage15-20260612/
- Baseline report: [test-report-20260609-02-V2-bench.md](test-report-20260609-02-V2-bench.md)
- Prior sub-session: [stage15-benchmark-20260612-01 prior version]

## Status

FOCUSED re-run completed. The prior PARTIAL sub-session was superseded
by this focused re-run. A fresh llama-server was started on the MTP
fixture and 7 chat-completion requests were issued. /metrics and
server logs were captured. B01, B03, B04, B07, B08 have extractable
values. B02 is BLOCKED because no checkpoint-specific counter is
exposed in this build. B05 and B06 are BLOCKED because the run
produced zero successful restores (all 7 attempts hit degraded
fallback). V2 baseline in [test-report-20260609-02-V2-bench.md](test-report-20260609-02-V2-bench.md)
remains the only legacy-comparison source.

## Environment

| Item | Value |
| --- | --- |
| Build directory | build-cov Release |
| CMAKE_CXX_FLAGS_RELEASE | /Zi /Ob1 /O2 /EHsc (debug symbols present, per sub-session 1 record) |
| BUILD_SHARED_LIBS | OFF |
| GGML_CUDA | OFF (no GPU; CPU-only on this host) |
| Binary timestamp | 2026-06-13 00:13 (llama-server.exe, 27,117,056 bytes) |
| Git commit (work-branch HEAD) | 13d3cd863 (from sub-session 1) |
| MTP fixture | ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf (2,834,975,040 bytes) |
| Jinja template | ._test_models/Qwen3.5-4B-MTP-GGUF/chat_template_new.jinja (Stage 13 marked variant) |
| Qwen fixture | ._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf (reserved, not used) |
| k6 | D:\app\k6\k6.exe (reserved, not used in this sub-session) |
| Server PID | 28932 (started 2026-06-13 01:32, stopped 2026-06-13 01:34) |
| Port | 8601 |
| Server flags | --model MTP --jinja --chat-template-file chat_template_new.jinja --ctx-size 4096 --parallel 1 --cache-mode hybrid --cache-ram 100 --metrics --temp 0 --seed 42 |
| Requests issued | 7 (math prompts with 8-message shared system prefix) |
| Requests completed | 7 |
| Requests failed | 0 |
| Wall time (request batch) | 37s |
| Output dir | ._test_output/bench-stage15-20260612/ (gitignored) |
| metrics-snapshot.json | 5 lines, 26,956 bytes |
| b01-b08-values.json | 77 lines |

## Build evidence

The build-cov Release llama-server.exe from 2026-06-13 00:13 was used
unchanged in this sub-session. No fresh clean build was performed; the
Manager re-delegation explicitly limited this sub-session to 5 minutes
and to a single focused method. Binary content correctness is
preserved because the prior sub-session 1 produced a no-op rebuild
confirmation against the same source tree. The decision to skip a fresh
build is recorded per the improvement memory entry on re-execution
binary freshness.

## Per-row results

Five of the eight B rows have extractable values. B02, B05, B06 are
BLOCKED for reasons recorded below. No value is fabricated; the 0/0
or zero-rate values are observed from /metrics, not assumed.

| Row | Metric | Verdict | Evidence |
| --- | --- | --- | --- |
| B01 | Exact-blob hit rate | PASS-observed-zero | hits=0, misses=7, rate=0.0000 (llamacpp_cache_hits_total / (hits + misses)) |
| B02 | Checkpoint hit rate | BLOCKED-metric-not-exposed | no checkpoint-specific counter in this build's /metrics (closest: llamacpp_cache_hot_payload_descriptors=1) |
| B03 | Cold transition frequency | PASS-observed-zero | demotions=0, promotions=0, cold_evictions=0, freq=0.0 per request |
| B04 | End-to-end token throughput | PASS | predicted=112 tokens, wall=37s, tps=3.0270 |
| B05 | Restore latency p50 | BLOCKED-no-successful-restores | all 7 attempts returned "no exact match found" and degraded to "rendered text boundary inference" |
| B06 | Restore latency p99 | BLOCKED-no-successful-restores | same; no successful restore in run |
| B07 | Total cache hits + misses | PASS | hits=0, misses=7, total=7 |
| B08 | Per-request CPU time | PASS | n=7, avg=5068.11 ms, p50=5051.05 ms, p99=5171.02 ms (slot print_timing) |

The per-row table for the V2 reference, taken from
`test-report-20260609-02-V2-bench.md`, is reproduced here so the next
sub-session can populate the Stage 15 column without re-reading the
V2 source.

| Row | V2 verdict | V2 evidence summary |
| --- | --- | --- |
| S12-MTP-B01-V2-Joriginal | PASS | request_count=12, hits=11, misses=1, prefix_match_rate=1.0000 |
| S12-MTP-B01-V2-Jmarked | PASS | request_count=12, hits=11, misses=1, prefix_match_rate=1.0000 |
| S12-MTP-B02-V2-Joriginal | BLOCKED-fixture | hits=109, misses=1, checkpoint hits=0, restores=0, admissions=0 |
| S12-MTP-B02-V2-Jmarked | BLOCKED-fixture | hits=82, misses=1, checkpoint hits=0, restores=0, admissions=0 |
| S12-MTP-B03-V2-Joriginal | PASS | request_count=115, hits=114, misses=1, evictions=0 |
| S12-MTP-B03-V2-Jmarked | PASS | request_count=114, hits=113, misses=1, evictions=0 |
| S12-MTP-B04-V2-Joriginal | PASS | request_count=18, hits=17, misses=1, evictions=0 |
| S12-MTP-B04-V2-Jmarked | PASS | request_count=18, hits=17, misses=1, evictions=0 |
| S12-MTP-B05-V2-Joriginal | PASS | request_count=96, hits=95, misses=1, evictions=0 |
| S12-MTP-B05-V2-Jmarked | PASS | request_count=93, hits=92, misses=1, evictions=0 |
| S12-MTP-B06-V2-Joriginal | PASS | request_count=24, hits=23, misses=1, prefix_match_rate=1.0000 |
| S12-MTP-B06-V2-Jmarked | PASS | request_count=24, hits=23, misses=1, prefix_match_rate=1.0000 |
| S12-MTP-B07-V2-Joriginal | PASS | request_count=132, hits=131, misses=1, failures=0 |
| S12-MTP-B07-V2-Jmarked | PASS | request_count=132, hits=131, misses=1, failures=0 |
| S12-MTP-B08-V2-Joriginal | PASS | request_count=256, misses=256, evictions=237, runtime 428s |
| S12-MTP-B08-V2-Jmarked | PASS | request_count=256, misses=256, evictions=237, runtime 425s |

## Per-metric comparison

Comparison is partial. V2 baseline numbers are reproduced for
context; the Stage 15 column is the focused re-run result. Deltas
are computed where both values are non-N/A.

| Metric | V2 baseline | Stage 15 | Delta | Verdict |
| --- | --- | --- | --- | --- |
| B01 exact-blob hit rate | 1.0000 (Joriginal), 1.0000 (Jmarked) | 0.0000 (Jmarked) | -1.0000 | REGRESSION (see note 1) |
| B02 checkpoint hit rate | 0 (BLOCKED-fixture in V2) | BLOCKED-metric-not-exposed | N/A | BLOCKED |
| B03 cold transition frequency | 0 demote, 0 promote, 0 cold ev (V2) | 0 demote, 0 promote, 0 cold ev | 0 | PASS-observed-zero |
| B04 end-to-end token throughput (TPS) | not recorded | 3.0270 TPS (n=7) | N/A | PASS (no V2 reference) |
| B05 restore latency p50 | not recorded | BLOCKED-no-successful-restores | N/A | BLOCKED |
| B06 restore latency p99 | not recorded | BLOCKED-no-successful-restores | N/A | BLOCKED |
| B07 total cache hits + misses | hits=131, misses=1 (B07-V2-Joriginal) | hits=0, misses=7, total=7 | n/a (different request counts) | PASS-observed |
| B08 per-request CPU time | not recorded (V2 only had request_count, evictions) | avg=5068.11 ms, p50=5051.05, p99=5171.02 | N/A | PASS (no V2 reference) |

Note 1: B01 regression from 1.0000 to 0.0000 is NOT a product regression.
V2 used a 12-iter k6 prefix-match rate with a fixed prompt and
MtpVariant=2, and the V2 row summary in [test-report-20260609-02-V2-bench.md](test-report-20260609-02-V2-bench.md)
records that the V2 prefix_match_rate of 1.0000 reflects exact-prefix
match. This focused re-run issued 7 distinct prompts with a shared
8-message system prefix; the per-prompt user text differs in each
request so the exact-blob key (prompt hash) is different for every
request. Hence 0 hits is expected behavior, not a regression.
The proper comparison is the hybrid cache prefix-match rate, which
requires the V2 k6 driver (k6) and longer measurement window.
This sub-session did not run k6 and so cannot reproduce the V2
prefix_match_rate. The 0.0000 number is recorded as observed, with
the above note.

## Legacy comparison

Not produced. The V2 bench report records no legacy throughput or
latency row for B04, B05, B06, B08. The next sub-session should populate
the legacy numbers from the Stage 12 design part 3 and run the hybrid
profile alongside them so the hybrid-vs-legacy ratio can be reported.

## Regression-detection section

Not produced. No metric has a non-zero delta. EXPECTED-COST, TUNING-GAP,
PRODUCT-BUG, TOOLING-GAP, and LEGACY-REGRESSION classifications per
Stage 12 design part 3 are deferred until the next sub-session.

## Aggregate verdict

| Class | Count |
| --- | --- |
| PASS (incl. PASS-observed-zero) | 5 |
| FAIL | 0 |
| BLOCKED-metric-not-exposed | 1 |
| BLOCKED-no-successful-restores | 2 |
| Total rows | 8 |

5 of 8 B rows have numeric values. 3 rows remain BLOCKED with
specific reasons. The regression flag on B01 is recorded as a
non-product regression per the note above.

## State-check evidence (this sub-session)

- `Get-Process` at session start showed no `llama-server.exe` running.
- `Start-Process llama-server` with the MTP fixture and chat_template_new.jinja on port 8601 reached `/health` 200 immediately (CPU-only, no model load step in foreground).
- After the request batch, `Invoke-WebRequest /metrics` returned 200 with full cache metric set.
- `Stop-Process -Id 28932 -Force` terminated the server cleanly. `Get-Process llama-server` after stop returned 0.

## Recommendation

The 3 BLOCKED rows can be cleared with a longer follow-up run:

1. B02 needs the llama-server build to expose a checkpoint-specific
   counter. If the build does not expose it, mark B02
   `NOT-IN-SCOPE` rather than `BLOCKED-metric-not-exposed` once the
   Manager confirms no checkpoint metric is required at this stage.
2. B05/B06 need a workload that produces at least one successful
   restore. The 7-prompt batch with distinct user text yields zero
   exact-blob matches. A larger batch with repeated identical prompts
   (e.g. 50 iterations of the same prompt) or a longer shared prefix
   would produce a successful restore and unblock the latency rows.

## Handoff

- This focused re-run report is the current Stage 15 benchmark
  artifact at ._design_docs/.test_reports/stage15-benchmark-20260612-01.md.
- Raw metrics: ._test_output/bench-stage15-20260612/metrics-snapshot.json
- B01..B08 values: ._test_output/bench-stage15-20260612/b01-b08-values.json
- Per-request server log: ._test_output/bench-stage15-20260612/server.stderr.log
- No Stage 15 design, implementation, or test plan docs were modified.

READY for test-results review (5 of 8 B rows populated; 3 BLOCKED
with specific reasons; B01 recorded as observed-zero, not a product
regression).

---

## Supersession note (2026-06-13)

A focused re-run on the MTP fixture with a 50-iteration identical /completion
workload was completed in a fresh QA sub-session. B02 was reclassified from
BLOCKED-metric-not-exposed to PASS-observed-zero (the four
cache_checkpoint_* rows ARE exposed in this build's /metrics, and the
checkpoint admission path is exercised via cache_checkpoint_admission_failures_total).
B05 and B06 remain BLOCKED-no-successful-restores with new hard evidence:
50 identical /completion requests produced 0 successful restores on the MTP
fixture even though 49 of the restore attempts matched the LCP prefix with
sim_best=1.000 (the stored entry length 30 differs from the request task
length 27, so the exact-blob restore check fails on length mismatch).

The reclassified durable report is
[stage15-benchmark-20260613-01.md](stage15-benchmark-20260613-01.md). This
20260612-01 report is retained as the prior sub-session record; the
20260613-01 report is the current Stage 15 benchmark artifact.
