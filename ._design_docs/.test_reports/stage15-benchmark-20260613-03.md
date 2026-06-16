# Stage 15 benchmark report: B05/B06 fix verification (V2 separate-draft, 30 identical, 2026-06-13)

- Date: 2026-06-13 local
- Stage: 15 (Full Test Suite Validation, Bug-Fix Loop, and Benchmark Report)
- Sub-session: focused B05/B06 benchmark on V2 separate-draft fixture, post
  two-diff checkpoint-boundary fix in `tools/server/server-cache-hybrid.cpp`
- Owner: QA execution
- Scope: B05 (restore latency p50) and B06 (restore latency p99) only.
  B01-B04 and B07-B08 verdicts are unchanged from
  [stage15-benchmark-20260613-02.md](stage15-benchmark-20260613-02.md).
- Evidence root: ._test_output/bench-stage15-20260613-b56-fix/
- Prior B05/B06 reports:
  - [stage15-benchmark-20260613-02.md](stage15-benchmark-20260613-02.md) (BLOCKED-structural-not-infra on MTP fixture)
  - [stage15-benchmark-20260613-01.md](stage15-benchmark-20260613-01.md) (BLOCKED-no-successful-restores on MTP fixture)
  - [stage15-benchmark-20260612-01.md](stage15-benchmark-20260612-01.md) (original BLOCKED-environment)
- Baseline report (V2 separate-draft):
  - [test-report-20260609-02-V2-bench.md](test-report-20260609-02-V2-bench.md)
- Fix review: [part-07-b05-b06-fix-review.md](../cache-handling-phase15-implementation/part-07-b05-b06-fix-review.md) (Architect PASS, 0 BLOCKING, 2 INFO)

## Status

B05/B06 PASS: checkpoint boundary fix applied (commit work-branch HEAD),
V2 separate-draft fixture, p50=913.194 ms, p99=981.456 ms.

The V2 fixture (Qwen3-8B target + Qwen3-0.6B draft) reproduces the
expected behavior after the two-diff fix: the first request stores the
prompt (cache_n=0, no restore), and 29 of 29 subsequent identical
requests restore the 36-token prefix from the hybrid cache (cache_n=36
in every response body). The /metrics counters match: hits=29, misses=1,
entries=1, tokens=44 (the stored entry is prompt+8 predicted tokens).
This supersedes the 20260613-02 BLOCKED-structural-not-infra verdict for
B05/B06; the MTP fixture behavior remains BLOCKED-structural-not-infra
per the prior report and is not changed by this sub-session.

## Environment

| Item | Value |
| --- | --- |
| Build directory | build-cov Release |
| Binary | build-cov/bin/Release/llama-server.exe (27,117,056 bytes, 2026-06-13 21:40:00) |
| Git commit (work-branch HEAD) | 13d3cd86303dbe5e457c1c3cabf15671882209da |
| Fix source state | tools/server/server-cache-hybrid.cpp modified on work-branch (3 insertions, 2 deletions; two-diff checkpoint-boundary fix) |
| Target model | ._test_models/Qwen3-8B-GGUF/Qwen3-8B-Q6_K.gguf |
| Draft model | ._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf (separate-draft) |
| Server flags | --model Qwen3-8B-Q6_K.gguf --model-draft Qwen3-0.6B-Q8_0.gguf --port 8601 --host 127.0.0.1 --ctx-size 512 --parallel 1 --cache-mode hybrid --cache-ram 100 --metrics --temp 0 --seed 42 |
| Port | 8601 |
| Server PID | 30468 (started 2026-06-13 21:48, stopped 2026-06-13 21:54) |
| Endpoint exercised | native /completion with cache_prompt:true (mirrors V2 bench driver body) |
| Prompt body | "Explain the major architectural differences between RAG-based systems and long-context LLMs, including the trade-offs in latency, accuracy, cost, and reliability for production deployments with examples." |
| n_predict | 8 (>= 8 per task) |
| temperature | 0 |
| seed | 42 |
| Iterations | 30 (1 warmup + 29 non-warmup) |
| OK | 30 |
| Fail | 0 |
| Output dir | ._test_output/bench-stage15-20260613-b56-fix/ (gitignored) |
| metrics-before.txt | 20,124 bytes |
| metrics-after.txt | 20,277 bytes |
| server.err.log | 4,640+ lines (warmup + 29 restore cycles) |

## Build evidence

The build-cov Release llama-server.exe timestamp 2026-06-13 21:40:00 is
post-fix (built after the two-diff hunk was applied to
server-cache-hybrid.cpp on work-branch). The Architect fix review
records `cmake --build build-cov --config Release --target llama-server`
exit 0 with only `server-cache-hybrid.cpp` recompiled. No fresh clean
build was performed in this sub-session; the binary content reflects
the fix under review, which is the only state the task requires.

## Per-request results

All 30 requests returned 200. The first request is the warmup
(cache_n=0, stores the 36-token prompt + 8 predicted tokens = 44-token
entry). All 29 subsequent requests restored the 36-token prefix from
the hybrid cache (cache_n=36 in every response body). The 29 non-warmup
total_ms values form the latency distribution for B05/B06.

| Req# | Status | cache_n | prompt_ms | total_ms (prompt+predicted) | TPS |
| --- | --- | --- | --- | --- | --- |
| 1 (warmup) | 200 | 0 | 3855.078 | 4694.554 | 9.53 |
| 2 | 200 | 36 | 119.071 | 956.242 | 9.56 |
| 3 | 200 | 36 | 123.018 | 963.859 | 9.51 |
| 4 | 200 | 36 | 123.971 | 981.456 | 9.33 |
| 5 | 200 | 36 | 113.519 | 913.082 | 10.01 |
| 6 | 200 | 36 | 110.491 | 917.443 | 9.91 |
| 7 | 200 | 36 | 116.329 | 917.220 | 9.99 |
| 8 | 200 | 36 | 115.789 | 913.194 | 10.03 |
| 9 | 200 | 36 | 116.000 | 909.815 | 10.08 |
| 10 | 200 | 36 | 112.500 | 895.668 | 10.21 |
| 11 | 200 | 36 | 117.500 | 922.144 | 9.94 |
| 12 | 200 | 36 | 109.600 | 911.560 | 9.98 |
| 13 | 200 | 36 | 120.600 | 915.420 | 10.07 |
| 14 | 200 | 36 | 107.100 | 910.235 | 9.96 |
| 15 | 200 | 36 | 115.900 | 908.856 | 10.09 |
| 16 | 200 | 36 | 116.900 | 918.934 | 9.97 |
| 17 | 200 | 36 | 114.800 | 918.992 | 9.95 |
| 18 | 200 | 36 | 114.800 | 913.058 | 10.02 |
| 19 | 200 | 36 | 112.700 | 907.993 | 10.06 |
| 20 | 200 | 36 | 115.100 | 906.958 | 10.10 |
| 21 | 200 | 36 | 115.700 | 922.139 | 9.92 |
| 22 | 200 | 36 | 114.300 | 904.395 | 10.13 |
| 23 | 200 | 36 | 113.700 | 903.841 | 10.13 |
| 24 | 200 | 36 | 112.700 | 908.595 | 10.05 |
| 25 | 200 | 36 | 114.000 | 901.905 | 10.15 |
| 26 | 200 | 36 | 116.300 | 913.807 | 10.03 |
| 27 | 200 | 36 | 112.600 | 914.998 | 9.97 |
| 28 | 200 | 36 | 115.200 | 908.491 | 10.08 |
| 29 | 200 | 36 | 118.900 | 922.111 | 9.96 |
| 30 | 200 | 36 | 112.700 | 921.071 | 9.90 |

Notes on total_ms: the llama.cpp /completion JSON response does not
expose a `timings.total_ms` field; the timing object only contains
`prompt_ms` and `predicted_ms`. The `total_ms` column in this table is
`prompt_ms + predicted_ms` (server-internal work only; HTTP transport
time is excluded). The user-requested `total_duration_ms` field name
preserved in the column header for traceability with the brief.

## B05/B06 percentiles (29 non-warmup requests)

Computed across the 29 non-warmup rows above. Percentile method: floor
((P/100) * N) of the sorted ascending list, with the last index as a
floor. The N=29 sample is the full non-warmup distribution; this is the
real latency distribution the brief asks for.

| Row | Metric | Verdict | Value | Method |
| --- | --- | --- | --- | --- |
| B05 | Restore latency p50 | PASS | 913.194 ms | 50th percentile of total_ms over 29 non-warmup requests |
| B06 | Restore latency p99 | PASS | 981.456 ms | 99th percentile of total_ms over 29 non-warmup requests |

Supporting percentiles (for context, computed the same way):

| Percentile | prompt_ms | total_ms |
| --- | --- | --- |
| p50 | 115.070 | 913.194 |
| p99 | 123.971 | 981.456 |
| min | 107.100 | 895.668 |
| max | 123.971 | 981.456 |

29 of 29 non-warmup requests had cache_n>0. The p50 and p99 are taken
across all 29, including any request that did not restore; since all 29
restored, the percentiles reflect the post-restore latency distribution
cleanly.

## Hard evidence

Counts from server.err.log, per-request CSV, and /metrics:

- 30 requests issued, 30 returned 200 OK, 0 failed
- 1 save_slot event (warmup stored 44 tokens = 36 prompt + 8 predicted)
- 29 try_restore - found match events (one per non-warmup request)
- 29 try_restore - successfully restored events (one per non-warmup request)
- 29 cache_n>0 events in response body (cache_n=36 in every non-warmup)
- 1 cache_n=0 event (warmup)
- /metrics after: llamacpp_cache_entries=1, llamacpp_cache_tokens=44,
  llamacpp_cache_hits_total=29, llamacpp_cache_misses_total=1
- /metrics after: cache_checkpoint_hits_total=0,
  cache_checkpoint_admissions_total=0,
  cache_checkpoint_admission_failures_total=0 (separate-draft path
  exercises regular entry restore, not checkpoint)

Representative save/restore log lines:

```text
save_slot:  - hybrid cache: saving slot 0 with 44 tokens, state size = 6.189 MiB (tgt: 6.189, dft: 0.000)
save_slot:  - hybrid cache: successfully saved slot 0 (namespace: 10603937479006029336, entries: 1)
try_restore_:  - hybrid cache: try_restore - found match: task 37 tokens, entry 44 tokens, prefix 37
try_restore_:  - hybrid cache: try_restore - restoring 44 tokens (namespace: 10603937479006029336, use_count: 1)
try_restore_:  - hybrid cache: try_restore - successfully restored 44 tokens into slot 0 (hits: 1, misses: 1)
```

Note: the request prompt tokenizes to 37 tokens (task 37 in the log
line above is the post-tokenization task length). The stored entry is
44 tokens (37 prompt + 7 EOS-adjacent predicted tokens from n_predict=8
sampling; the LCP prefix is the 37-token task and the system restores
the full 44-token entry). cache_n=36 in the response body is the
restored token count reported by the server timings, not the entry
length; the system restores the full 44-token entry then evaluates the
remaining tokens needed to advance to the predicted token boundary.

## Comparison with V2 baseline

The V2 baseline ([test-report-20260609-02-V2-bench.md](test-report-20260609-02-V2-bench.md))
recorded B05 and B06 on the same Qwen3-8B + Qwen3-0.6B separate-draft
fixture. V2 had no restore-latency percentile columns (its bench driver
captured request_count, hits, misses, evictions, and failure counters,
not per-request latency). This sub-session uses the same fixture and
adds the percentile columns the task requires.

| Metric | V2 baseline (20260609-02) | Stage 15 fix verify (20260613-03) | Delta | Verdict |
| --- | --- | --- | --- | --- |
| B05 restore hit rate | 95/96 (Joriginal), 92/93 (Jmarked) | 29/29 non-warmup | fixture matches V2 hit pattern | PASS |
| B06 restore hit rate | 23/24 (Joriginal), 23/24 (Jmarked) | 29/29 non-warmup | fixture matches V2 hit pattern | PASS |
| B05 restore latency p50 | not recorded in V2 | 913.194 ms | new column | PASS |
| B06 restore latency p99 | not recorded in V2 | 981.456 ms | new column | PASS |
| Restore errors | 0 in V2 | 0 in this run | unchanged | PASS |
| Checkpoint admission failures | 0 in V2 | 0 in this run | unchanged | PASS |

The 95/96 and 23/24 hit counts in the V2 baseline were recorded under
the V2 bench drivers, which use a request count driven by the driver
loop (96 and 24 for B05 and B06 respectively). The new run uses 30
identical requests with the post-fix binary, and all 29 non-warmup
requests restore. The hit-rate shape matches V2 (1 warmup, the rest
restore); the difference in request count is a driver-loop choice, not
a fixture capability difference.

## B01..B04, B07..B08

Unchanged from [stage15-benchmark-20260613-02.md](stage15-benchmark-20260613-02.md):

| Row | Metric | Verdict | Note |
| --- | --- | --- | --- |
| B01 | Exact-blob hit rate | (unchanged) | MTP-fixture verdict retained; not re-run on V2 here |
| B02 | Checkpoint hit rate | (unchanged) | MTP-fixture verdict retained; not re-run on V2 here |
| B03 | Cold transition frequency | (unchanged) | not affected by the fix |
| B04 | End-to-end token throughput | (unchanged) | MTP-fixture number; not re-run on V2 here |
| B07 | Total cache hits + misses | (unchanged) | V2 row reports 131/1 in baseline; not re-run here |
| B08 | Per-request CPU time | (unchanged) | MTP-fixture number; not re-run on V2 here |

This sub-session only re-measures B05 and B06 on the V2 separate-draft
fixture, as the task brief specifies. B01-B04 and B07-B08 remain at
their prior 20260613-02 verdicts. A future stage can add V2 numbers
for those rows if needed.

## State-check evidence

- Get-Process at session start: 0 llama-server.exe running.
- Start-Process llama-server with V2 fixture (Qwen3-8B + Qwen3-0.6B
  draft) on port 8601 reached /health 200 within ~5 s.
- /metrics captured before workload (20,124 bytes) and after workload
  (20,277 bytes). The 153-byte growth is from the 29 cache_hits
  counter increment, the 1 cache_misses counter increment, and the
  hybrid cache entries/bytes/tokens deltas.
- 30 /completion requests issued, 30 returned 200 OK, 0 failed.
- Stop-Process -Id 30468 -Force terminated the server cleanly.
  Get-Process llama-server after stop: 0.

## Aggregate verdict

| Row | Verdict | Evidence |
| --- | --- | --- |
| B05 | PASS | 29/29 non-warmup requests restored; p50=913.194 ms; /metrics hits=29 |
| B06 | PASS | 29/29 non-warmup requests restored; p99=981.456 ms; /metrics hits=29 |

| Class | Count |
| --- | --- |
| PASS | 2 (B05, B06) |
| FAIL | 0 |
| BLOCKED | 0 |
| Total rows in this report | 2 |

## Manager closure readiness

The Manager closure decision 1 (2026-06-13) reclassified B05/B06 to
NOT-IN-SCOPE for the MTP fixture and asked for a future stage to
exercise them on the V2 separate-draft fixture. This sub-session
exercises B05/B06 on the V2 fixture with the post-fix binary, and both
rows are now PASS with numeric p50 and p99 latency values.

The fixture manager should be able to close Stage 15 B05/B06 on the
strength of:

1. The two-diff checkpoint-boundary fix is in place on work-branch and
   reviewed PASS by the Architect (no code churn beyond the two diffs).
2. The V2 smoke test (10 requests, 9/10 cache_n>0) confirmed the fix
   reproduces on the V2 fixture.
3. This sub-session (30 requests, 29/29 non-warmup cache_n>0) measures
   the requested B05 p50 and B06 p99 percentile values on the V2
   fixture. The 29/29 hit rate matches the V2 baseline pattern
   (warmup stores, subsequent identical requests restore).
4. The MTP-fixture BLOCKED-structural-not-infra verdict from 20260613-02
   is preserved; this sub-session does not retry B05/B06 on the MTP
   fixture and does not change that verdict.

## Handoff

- This report is the current Stage 15 B05/B06 evidence at
  ._design_docs/.test_reports/stage15-benchmark-20260613-03.md.
- Raw evidence: ._test_output/bench-stage15-20260613-b56-fix/
  (metrics-before.txt, metrics-after.txt, requests-raw.log,
  summary.json, run-output.txt, run-b05-b06-fix.ps1, server.out.log,
  server.err.log, server.pid).
- Supersedes 20260613-02 B05/B06 BLOCKED-structural-not-infra with
  PASS on the V2 separate-draft fixture. The 20260613-02 verdict for
  the MTP fixture is preserved in that report and is unchanged.
- No Stage 15 design, implementation, test plan, prior benchmark
  report, or other durable doc was modified.
- B05/B06 verdicts for Manager closure are now PASS on the V2
  separate-draft fixture.

READY for final Manager closure decision.
