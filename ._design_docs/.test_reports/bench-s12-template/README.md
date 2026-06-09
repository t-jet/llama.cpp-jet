# Stage 12 benchmark evidence dir template

This template documents the layout that benchmark scripts
(.\bench_s12_bNN_*.ps1) populate when they run. The actual evidence
directory is created at run time under
.\_design_docs\.test_reports\bench-s12-bNN-{timestamp}\.

## Layout

```text
bench-s12-bNN-<timestamp>/
    <row>/                   Per-mode subdirectory: hybrid (and legacy
                             when the scenario requires a legacy row)
        evidence-summary.md  Per-row summary, written by the benchmark
                             driver via Write-BenchEvidence.ps1
        server.out.log       llama-server stdout
        server.err.log       llama-server stderr
        metrics-before.txt   /metrics snapshot before warmup
        metrics-during.txt   /metrics snapshot during measurement window
        metrics-after.txt    /metrics snapshot after run
        k6-results.json      k6 NDJSON (B01 and B06 only)
        k6-stdout.txt        k6 console output (B01 and B06 only)
        load-tool-output.txt non-k6 load tool rows
        baseline.json        Per-row structured snapshot (design part-04)
        legacy-baseline.json When the row has a legacy comparison
    tuning-report.md         Seven-section tuning report skeleton,
                             written by Write-TuningReport.ps1
```

## baseline.json shape

The baseline JSON includes the design part-04 fields:

- commit_sha, dirty_worktree, build_type, binary_timestamp
- host_hardware, model_fixture, slot_count, ctx_size, draft_mode
- server_flags, prompt_seed, warmup_window, measurement_window
- request_count, throughput_tps
- p50_latency_ms, p95_latency_ms, p99_latency_ms
- exact_hit_rate, checkpoint_hit_rate
- restore_latency_by_kind
- demotion_count, promotion_count, eviction_count
- workingset_samples, handle_samples
- correctness_verdict

Stub rows set commit_sha and build_type to STUB, request_count to 0,
and correctness_verdict to BLOCKED. Read with Read-BaselineJson.ps1.

## legacy-baseline.json

Recorded when a scenario requires a legacy comparison. S12-B05 and
S12-B08 record N/A (legacy has no hybrid restore path or hybrid
forest path). The QA test plan may extend these with a "nearest
legacy throughput and latency" row per design part-03.

## tuning-report.md

Seven sections from design part-03:

1. Hot budget guidance
2. Cold store guidance
3. Slot count guidance
4. Context length guidance
5. Draft and MTP guidance
6. Workload profile guidance
7. Bottlenecks

The driver writes the section titles and TBD rows. QA fills the
values from the baseline.json files and the k6 or load-tool outputs.

## Stub evidence

When a fixture or k6 binary is missing, the driver writes STUB
markers and records `Verdict: BLOCKED`. The baseline.json still
captures the planned flags, build type, and slot count so QA can
record fixture absence rather than skipping silently.

## Owner

QA execution consumes this template. Developer implementation only
writes the template plus the per-row driver. Read-BaselineJson.ps1
loads the JSON shape into a hashtable for downstream comparison.
