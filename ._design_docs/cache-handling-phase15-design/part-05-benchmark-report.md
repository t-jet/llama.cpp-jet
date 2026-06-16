# Stage 15 design: benchmark report -- Part 5

Source: [../cache-handling-phase15-design.md](../cache-handling-phase15-design.md)

## Required sections

The benchmark report file is
`._design_docs/.test_reports/stage15-benchmark-20260612-01.md` per
D4. The required sections, in order:

1. Header: date, owner, scope (Stage 15 B01..B08 re-run), evidence
   root path, baseline report path
   (`._design_docs/.test_reports/test-report-20260609-02-V2-bench.md`).
2. Build evidence: clean build, binary timestamp, binary path.
3. Per-row table with the same shape as the V2 bench report: row
   id, verdict, evidence path, and the per-row metric numbers.
4. Per-metric comparison: each of the B01..B08 metrics is listed
   once with the V2 bench baseline, the Stage 15 number, the
   delta, and the regression classification.
5. Legacy comparison: a row per benchmark family that includes a
   legacy number, the hybrid number, the hybrid-vs-legacy ratio,
   and any legacy regression flag.
6. Regression-detection section: each metric with a non-zero
   delta gets a `EXPECTED-COST`, `TUNING-GAP`, `PRODUCT-BUG`,
   `TOOLING-GAP`, or `LEGACY-REGRESSION` classification per the
   Stage 12 design Part 3. The classification is the input to the
   bug-fix loop when the verdict is `PRODUCT-BUG` or
   `LEGACY-REGRESSION`.
7. Summary: PASS, FAIL, BLOCKED counts and any cap-exit
   references.
8. Handoff: next owner (Manager for closure decision) and the
   pointer back to the Stage 15 design Part 4 if the bug-fix
   loop must run.

## Required metrics

The eight metrics from the Stage 12 design Part 3
([part-03 of Stage 12 design](../cache-handling-phase12-design/part-03-benchmarks-baselines-and-legacy.md)):

| Metric | Source row | Required evidence |
| --- | --- | --- |
| Exact-blob hit rate | S12-B01 | Hybrid hit count, miss count, prefix match rate, request count, no correctness regression. |
| Checkpoint hit rate | S12-B02 | Checkpoint hit and restore counts on the Qwen3-8B + Qwen3-0.6B draft fixture; row is `BLOCKED-fixture` if the fixture cannot admit checkpoints. |
| Cold transition frequency | S12-B03 | Demotion count, promotion count, async miss count, cold latency. |
| End-to-end token throughput | S12-B04 | Tokens per second and request latency for legacy and hybrid at matched slot and ctx. |
| Restore latency | S12-B05 | p50, p95, p99 restore latency by payload kind and residency, hybrid only. |
| Prompt-storm efficiency | S12-B06 | Throughput, hit rate, eviction churn, diagnostics under high repeat pressure. |
| Mixed-profile comparison | S12-B07 | Three profile sub-runs (plain, checkpoint-dependent, target-plus-draft). |
| Large-forest lookup cost | S12-B08 | Branch lookup latency or request latency as forest grows. |

Each metric's source row also names the PASS condition. The
report records the PASS condition met or unmet, not just the
number.

## Differences from the Stage 12 V2 bench

The Stage 12 V2 bench report
(`._design_docs/.test_reports/test-report-20260609-02-V2-bench.md`)
records 14 PASS, 2 BLOCKED-fixture (B02), 0 FAIL, 0 product bugs.
Stage 15 differs from V2 in three ways:

1. Scope: Stage 15 covers B01..B08 on the current tree. V2 covered
   the same B01..B08 set with the V2 jinja variant. The
   regression-detection section compares the same metric across
   the two reports, not the jinja variant.
2. Tree state: Stage 15 runs on the current `work-branch` head,
   not on the Stage 12 closure head. The header records the
   commit SHA and the dirty worktree state.
3. Bug-fix loop integration: V2 had no bug-fix loop in scope. If
   the Stage 15 benchmark surfaces a `PRODUCT-BUG` or
   `LEGACY-REGRESSION` classification, the row opens a bug-fix
   loop iteration per part-4 of this design. The bug-fix loop
   closes the bug or escalates, then the benchmark report is
   re-issued with the post-fix numbers.

## Format and storage

The benchmark report is a single markdown file under
`._design_docs/.test_reports/`. It uses the same per-row table
format as the V2 bench report and the same per-row evidence
directory structure. The evidence root is
`._design_docs/.test_reports/bench-stage15-YYYYMMDD/`.

The benchmark report is durable. The Manager references it from
the closure entry in the implementation log, and the document
index gains a row in the "Cache implementation, verification,
and tests" section that points to the report.

## Handoff to closure

The benchmark report is the last durable artifact the QA owner
produces in Stage 15. After the report is filed, the next owner
is the Manager, who reads the report together with the QA test
report, the bug-fix loop evidence (if any), and the
closure-contract rows from part-7 of this design. The Manager
records the stage 15 closure decision in the implementation log.
