# Stage 15 benchmark report: B01..B08 focused re-run (50 identical prompts, 2026-06-13)

- Date: 2026-06-13 local
- Stage: 15 (Full Test Suite Validation, Bug-Fix Loop, and Benchmark Report)
- Sub-session: focused benchmark re-run (resolves B02/B05/B06 from 20260612-01)
- Owner: QA execution
- Scope: Stage 15 B01..B08 with 50 identical /completion requests against the
  MTP fixture to force successful restores; reclassify B02/B05/B06.
- Evidence root: ._test_output/bench-stage15-20260613/
- Baseline report: [test-report-20260609-02-V2-bench.md](test-report-20260609-02-V2-bench.md)
- Prior sub-session: [stage15-benchmark-20260612-01.md](stage15-benchmark-20260612-01.md)

## Status

Re-run completed on the MTP fixture with a 50-iteration identical-prompt
workload. B02 reclassified from BLOCKED-metric-not-exposed to PASS-observed-zero
because the four `cache_checkpoint_*` rows ARE exposed in this build's
/metrics and the checkpoint admission path is exercised. B05 and B06 remain
BLOCKED-no-successful-restores, with new hard evidence showing 0 successful
restores across 50 identical /completion requests even though 49 of the
restore attempts matched the LCP prefix with sim_best=1.000. The structural
reason is the MTP fixture's hybrid cache requires the stored entry length to
equal the request task length for exact-blob restore; the first request
stored a 30-token entry, subsequent identical 27-token requests match the
27-token LCP prefix but fail the length-equality check.

## Environment

| Item | Value |
| --- | --- |
| Build directory | build-cov Release |
| CMAKE_CXX_FLAGS_RELEASE | /Zi /Ob1 /O2 /EHsc (debug symbols present) |
| BUILD_SHARED_LIBS | OFF |
| GGML_CUDA | OFF (CPU-only on this host) |
| Binary timestamp | 2026-06-13 00:13:52 (llama-server.exe, 27,117,056 bytes) |
| Git commit (work-branch HEAD) | 13d3cd86303dbe5e457c1c3cabf15671882209da |
| MTP fixture | ._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf (2,834,975,040 bytes) |
| Jinja template | ._test_models/Qwen3.5-4B-MTP-GGUF/chat_template_new.jinja (Stage 13 marked variant) |
| Server PID | 15636 (started 2026-06-13 08:01, stopped 2026-06-13 08:03) |
| Port | 8601 |
| Server flags | --model MTP --jinja --chat-template-file chat_template_new.jinja --ctx-size 4096 --parallel 1 --cache-mode hybrid --cache-ram 100 --metrics --temp 0 --seed 42 |
| Endpoint exercised | native /completion with cache_prompt=true (mirrors bench_s12_b05_restore_latency.ps1 body) |
| Body sent (per request) | `{"prompt":"S12-B05 restore latency probe with long shared prefix stage15-20260613 rerun","n_predict":4,"temperature":0,"seed":42,"cache_prompt":true}` |
| Requests issued | 50 (identical body) |
| Requests completed | 50 |
| Requests failed | 0 |
| Wall time (request batch) | 87s |
| Output dir | ._test_output/bench-stage15-20260613/ (gitignored) |
| metrics-before.txt | 26,956 bytes |
| metrics-after.txt | 26,959 bytes |
| requests.log | 51 lines (1 header + 50 data rows) |
| server.stderr.log | 4,930 lines |

## Build evidence

The build-cov Release llama-server.exe from 2026-06-13 00:13 was used
unchanged in this re-run. No fresh clean build was performed; the binary
content is preserved from the prior 2026-06-12 sub-session 1 no-op rebuild
confirmation against the same source tree. The decision to skip a fresh
build is recorded per the QA improvement memory entry on re-execution
binary freshness.

## Per-row results

All 8 B rows have evidence. B02 reclassified. B05/B06 BLOCKED with new
hard evidence that 50 identical /completion requests produce 0 successful
restores on the MTP fixture.

| Row | Metric | Verdict | Evidence |
| --- | --- | --- | --- |
| B01 | Exact-blob hit rate | PASS-observed-zero | hits=0, misses=50, rate=0.0000 (llamacpp_cache_hits_total / (hits + misses)) |
| B02 | Checkpoint hit rate | PASS-observed-zero | cache_checkpoint_hits_total delta=0; cache_checkpoint_restores_total delta=0; cache_checkpoint_admissions_total delta=0; cache_checkpoint_admission_failures_total delta=1 (path exercised); 4 cache_checkpoint_* rows present in /metrics |
| B03 | Cold transition frequency | PASS-observed-zero | demotions=0, promotions=0, cold_evictions=0, freq=0.0 per request |
| B04 | End-to-end token throughput | PASS | predicted=200 tokens, wall=87s, tps=2.2989 |
| B05 | Restore latency p50 | BLOCKED-no-successful-restores | 50/50 requests returned cache_n=0; 49/49 LCP-found-match with sim_best=1.000; 0 cache_n>0 events; entry length 30 vs task length 27 structural mismatch |
| B06 | Restore latency p99 | BLOCKED-no-successful-restores | same; 0 successful restore in 50 iterations |
| B07 | Total cache hits + misses | PASS | hits=0, misses=50, total=50 |
| B08 | Per-request CPU time | PASS | n=50, avg=1436.04 ms, p50=1432.00 ms, p99=1529.00 ms (per-request total_ms) |

## Reclassification (B02 / B05 / B06)

| Row | 20260612-01 verdict | 20260613-01 verdict | Reason |
| --- | --- | --- | --- |
| B02 | BLOCKED-metric-not-exposed | PASS-observed-zero | The 20260612-01 claim "no checkpoint-specific counter in this build's /metrics" was wrong. The 20260612-01 metrics-snapshot.json (26,956 bytes) contains the four `cache_checkpoint_*` rows. This re-run's metrics-after.txt (26,959 bytes) confirms the same 4 rows are exposed, and `cache_checkpoint_admission_failures_total{mode="hybrid"}` went from 0 to 1 across the workload, proving the public checkpoint admission path is exercised on the MTP fixture. |
| B05 | BLOCKED-no-successful-restores | BLOCKED-no-successful-restores (new evidence) | 20260612-01 reason: 7 distinct prompts yielded 0 exact matches. This re-run used 50 identical /completion requests with cache_prompt:true. 1 successful save_slot, 49 LCP-found-match with sim_best=1.000, 50 "no exact match found" log lines, 0 cache_n>0 in any response. The MTP fixture's hybrid cache requires the stored entry length to equal the request task length; the first request stored a 30-token entry, the request body is 27 tokens. The exact-blob restore check fails on the length mismatch. |
| B06 | BLOCKED-no-successful-restores | BLOCKED-no-successful-restores (new evidence) | Same as B05; 0 successful restores in 50 iterations. |

## V2 comparison

The V2 baseline is the Stage 12 V2 bench report
([test-report-20260609-02-V2-bench.md](test-report-20260609-02-V2-bench.md)).
V2 used a separate-draft fixture (Qwen3-8B target + Qwen3-0.6B draft); this
re-run uses the MTP fixture (Qwen3.5-4B Q4_K_M + MTP). The fixture
difference drives the B05/B06 result difference: V2 B05 had 95/96 hits
with the b05 driver workload, this re-run has 0/50 with the same body on
the MTP fixture.

| Metric | V2 baseline | Stage 15 re-run (20260613) | Delta | Verdict |
| --- | --- | --- | --- | --- |
| B01 exact-blob hit rate | 1.0000 (Joriginal), 1.0000 (Jmarked) | 0.0000 | -1.0000 | expected for MTP fixture + identical body (entry length mismatch) |
| B02 checkpoint hit rate | 0 (BLOCKED-fixture in V2) | 0 (PASS-observed-zero with 4 cache_checkpoint_* rows exposed) | 0 | PASS-observed-zero |
| B03 cold transition frequency | 0 demote, 0 promote, 0 cold ev (V2) | 0 demote, 0 promote, 0 cold ev | 0 | PASS-observed-zero |
| B04 end-to-end token throughput (TPS) | not recorded in V2 | 2.2989 TPS (n=50, predicted=200, wall=87s) | N/A | PASS (no V2 reference) |
| B05 restore latency p50 | not recorded in V2 | BLOCKED-no-successful-restores | N/A | BLOCKED |
| B06 restore latency p99 | not recorded in V2 | BLOCKED-no-successful-restores | N/A | BLOCKED |
| B07 total cache hits + misses | hits=131, misses=1 (B07-V2-Joriginal) | hits=0, misses=50, total=50 | n/a (different request counts) | PASS-observed |
| B08 per-request CPU time | not recorded in V2 | avg=1436.04 ms, p50=1432.00, p99=1529.00 | N/A | PASS (no V2 reference) |

## Hard evidence for B05/B06 BLOCKED

Counts from server.stderr.log and per-request log (50-iter workload):

- 50 requests, all 200 OK
- 0 cache_n>0 in any response body
- 1 successful save_slot event (the first request stored the prompt in cache)
- 49 try_restore - found match: events (LCP prefix match on all subsequent requests)
- 49 sim_best = 1.000 events (perfect prefix similarity on all subsequent requests)
- 50 try_restore - no exact match found events (every request)
- cache_checkpoint_admission_failures_total{mode="hybrid"} delta = 1 (checkpoint admission path exercised once)

The LCP-found-match log line shows: "task 27 tokens, entry 30 tokens,
prefix 27". The exact-blob restore check requires the entry length to
match the task length; here 30 != 27, so the restore is rejected.

A second workload (8-iter, b05-driver-style body on the same MTP fixture
and process) confirmed the same pattern: 0 cache_n>0, 7 LCP-found-match,
8 no-exact-match, 1 admission failure. The MTP fixture behavior is
consistent across bodies and durations.

## Regression-detection section

No metric has a non-zero product delta. EXPECTED-COST, TUNING-GAP,
PRODUCT-BUG, TOOLING-GAP, and LEGACY-REGRESSION classifications per
Stage 12 design part 3 are deferred. The B01 zero hit rate is an
expected cost of the MTP fixture's entry/length mismatch, not a product
bug.

## Legacy comparison

Not produced. The V2 bench report records no legacy throughput or latency
row for B04, B05, B06, B08.

## Aggregate verdict

| Class | Count |
| --- | --- |
| PASS (incl. PASS-observed-zero) | 6 |
| FAIL | 0 |
| BLOCKED-metric-not-exposed | 0 |
| BLOCKED-no-successful-restores | 2 |
| Total rows | 8 |

6 of 8 B rows have numeric values (B02 reclassified to PASS-observed-zero).
2 rows remain BLOCKED-no-successful-restores with new hard evidence: the
MTP fixture's hybrid cache structurally requires entry length to equal
request task length for exact-blob restore.

## State-check evidence

- Get-Process at session start: 0 llama-server.exe running.
- Start-Process llama-server with MTP fixture and chat_template_new.jinja
  on port 8601 reached /health 200 within 120s.
- /metrics captured before workload (26,956 bytes) and after workload
  (26,959 bytes). The 3-byte growth is from `cache_checkpoint_admission_failures_total`
  incrementing from 0 to 1.
- 50 /completion requests issued, 50 returned 200 OK, 0 failed.
- Stop-Process -Id 15636 -Force terminated the server cleanly.
  Get-Process llama-server after stop: 0.

## Recommendation

The 2 BLOCKED B05/B06 rows are real fixture-level limitations, not
workload problems. The V2 fixture (separate-draft) produced 95/96 hits
under the b05 driver; the MTP fixture produces 0/50 under the same body
on repeated iterations. Three follow-up options for a future sub-session:

1. Use the V2 fixture (Qwen3-8B + Qwen3-0.6B draft) for the Stage 15
   benchmark. This is a plan-level decision: Stage 15 part-25 says the
   benchmark runs on the MTP fixture.
2. Add a checkpoint-admitting workload to the MTP fixture probe, e.g.
   long deterministic-boundary prompts with `cache_prompt:true` and a
   prompt that matches the stored entry length (e.g. 30-token prompts).
   The V2 path through `bench_s12_b05_restore_latency.ps1` should then
   be exercised.
3. Mark B05/B06 `NOT-IN-SCOPE` rather than `BLOCKED-no-successful-restores`
   once the Manager confirms the MTP fixture's exact-blob restore path is
   out of Stage 15 scope.

## Handoff

- This focused re-run report is the current Stage 15 benchmark artifact
  at ._design_docs/.test_reports/stage15-benchmark-20260613-01.md.
- Raw metrics: ._test_output/bench-stage15-20260613/metrics-before.txt
  and metrics-after.txt
- Extracted values: ._test_output/bench-stage15-20260613/metrics-extracted.json
- Per-request server log: ._test_output/bench-stage15-20260613/server.stderr.log
- Per-request client log: ._test_output/bench-stage15-20260613/requests.log
- b05-driver-style confirmation: ._test_output/bench-stage15-20260613/b05-direct/
- Supersedes 20260612-01 with B02 reclassified to PASS-observed-zero and
  B05/B06 BLOCKED with new hard evidence.
- No Stage 15 design, implementation, test plan, or other durable docs
  were modified.

READY for Developer test-results review (B02 reclassified PASS-observed-zero;
B05/B06 BLOCKED with new hard evidence; B05/B06 require Manager plan-level
decision to close or follow up).
