# Stage 12 implementation plan review

- Review ID: part-02-implementation-plan-review
- Date: 2026-06-07
- Reviewer: Architect agent (fresh session)
- Source plan: ._design_docs/cache-handling-phase12-implementation/part-01-implementation-plan.md
- Source design: ._design_docs/cache-handling-phase12-design.md + parts 01-09

## 1. Scope and references

This review checks the Stage 12 implementation plan against the closed
design (Manager design gate PASS, Architect design re-review PASS, and
cap-fix closure PASS 2026-06-07) without re-opening design questions.

Files reviewed:

- ._design_docs/cache-handling-phase12-design.md
- ._design_docs/cache-handling-phase12-design/part-01 to part-09
- ._design_docs/cache-handling-phase12-implementation.md
- ._design_docs/cache-handling-phase12-implementation/part-01-implementation-plan.md
- ._design_docs/cache-handling-phase11-implementation/part-29-cap-fix-closure-decision.md
- ._design_docs/cache-handling-test-scripts/README.md
- ._design_docs/cache-handling-test-scripts/run_coverage.ps1
- ._design_docs/document-index.md

## 2. Design-to-plan coverage check

| Design item id | Source | Plan row id | Status | Note |
| --- | --- | --- | --- | --- |
| S12-S01 Budget exhaustion | part-02 | S12-S01 row in stress map | covered | script, fixture, config, duration, evidence dir present |
| S12-S02 Concurrent multi-slot | part-02 | S12-S02 row | covered | parallel 4 and 8 with explicit BLOCKED rule for 8 |
| S12-S03 Large branch forests | part-02 | S12-S03 row | covered | fixed seed, varied prefix, 30 min |
| S12-S04 Prompt storms | part-02 | S12-S04 row | covered | near-duplicate and exact-repeat mix, 30 min |
| S12-S05 Mixed workload profiles | part-02 | S12-S05 row | covered | fixture-conditional profiles with BLOCKED rule |
| S12-S06 Cold queue pressure | part-02 | S12-S06 row | covered | cold path, small hot budget, 30 min |
| S12-S07 Protected-root pressure | part-02 | S12-S07 row | covered | protected roots plus budget pressure |
| S12-S08 Integrity failure under load | part-02 | S12-S08 row | covered | fault-injection precondition + live load |
| S12-B01 Exact-blob hit rate | part-03 | S12-B01 row in bench map | covered | legacy row mandatory; tuning row 1 |
| S12-B02 Checkpoint hit rate | part-03 | S12-B02 row | covered | BLOCKED rule for missing checkpoint fixture |
| S12-B03 Cold transition frequency | part-03 | S12-B03 row | covered | legacy row mandatory |
| S12-B04 End-to-end token throughput | part-03 | S12-B04 row | covered | hybrid and legacy rows at matched slot/ctx |
| S12-B05 Restore latency | part-03 | S12-B05 row | covered (partial) | legacy row recorded as N/A; see Section 3 |
| S12-B06 Prompt-storm efficiency | part-03 | S12-B06 row | covered | legacy row mandatory |
| S12-B07 Mixed-profile comparison | part-03 | S12-B07 row | covered | profile-by-profile legacy row |
| S12-B08 Large-forest lookup cost | part-03 | S12-B08 row | covered (partial) | legacy row recorded as N/A; see Section 3 |
| S12-L01 Production-like hybrid 6h | part-02 long-run | S12-L01 row | covered | 6h, 60s sampler, full monitor list |
| S12-L02 Reproducibility 30m | part-02 long-run | S12-L02 row | covered | 30m, 30s sampler |
| S12-L03 Legacy control 2h | part-02 long-run | S12-L03 row | covered | 2h, 60s sampler |
| Config matrix (10 dimensions) | part-02 | Configuration matrix section | covered | all 10 dimensions present, draft presence held out of scope by plan choice |
| Build config baseline | part-29 | Build configuration baseline paragraph | covered | build-cov BUILD_SHARED_LIBS=OFF /Zi /Ob1 /O2 /EHsc /DEBUG:FULL GGML_CUDA=OFF |
| Focused ctest preflight targets | part-01 preflight list | Focused ctest preflight list in plan | covered | 8 named targets, matches design list |
| Evidence format | part-04 | Evidence format section | covered | stress dir tree, bench dir tree, baseline JSON shape, tuning report skeleton |
| Cap-fix closure reference | part-09 | Accepted design baseline, scope-of-this-plan | covered | T114=0.9276, T114a=0.8418 cited |
| T114/T114a/T115/T121 closure contracts stay current | part-04 traceability | Binding constraints section | covered | explicit carry-forward statement |
| Risks table | part-04 risks | Risks table | covered | 8 risks with mitigation columns, host-specific concerns named |
| Handoff to test plan | part-04 handoff | Handoff to test plan section | covered | lists scenario IDs, baseline JSON shape, thresholds, fixture inventory, BLOCKED rules, cap-fix status, evidence-source classification |

No design-to-plan gaps blocking. Two legacy-row treatments on S12-B05
and S12-B08 are recorded as partial because the design calls for
"nearest legacy throughput and latency row" even on hybrid-only
scenarios. See Section 3.

## 3. Plan-internal issues

| Issue id | Severity | Location | Description | Recommendation |
| --- | --- | --- | --- | --- |
| S12-PLAN-01 | non-blocking | Benchmark map rows S12-B05 and S12-B08 | Plan records legacy row as N/A. Design part-03 says "Even then, the nearest legacy throughput and latency row is included for comparison" for hybrid-only scenarios. | QA test plan should record nearest legacy throughput and latency comparison for B05 (restore latency) and B08 (large-forest lookup) so the design's "Even then" rule is met. No rework of the implementation plan. |
| S12-PLAN-02 | non-blocking | S12-S02 row | Plan says "extends existing stress_tests.ps1 S02". The existing script is the public `stress_tests.ps1` in the test-scripts dir; the new file is a new script that reuses the same scenario shape, not an in-place edit. | Naming is clear. No change needed. QA may want a one-line note in the README that the new `stress-concurrent-multislot.ps1` supersedes the S02 scenario in `stress_tests.ps1` for Stage 12. |
| S12-PLAN-03 | non-blocking | Configuration matrix, draft presence row | Plan keeps draft and MTP rows out of scope by plan choice, citing closed cap-fix. | Already documented as plan choice, not a blocker. QA planning may open draft/MTP rows separately if evidence is needed. |
| S12-PLAN-04 | non-blocking | Handoff to test plan, last bullet | Plan lists evidence-source classification rules but does not name the specific public Prometheus metrics for the eight metric groups from design part-04. | QA test plan owns the row-by-row evidence-source mapping. Implementation plan correctly defers. No change. |

No blocking plan-internal issues.

## 4. Configuration matrix conformance

Cited baseline from part-29 cap-fix closure decision:

- build-cov with BUILD_SHARED_LIBS=OFF
- /Zi /Ob1 /O2 /EHsc
- /DEBUG:FULL
- GGML_CUDA=OFF

Plan "Build configuration baseline" paragraph cites the same flags
verbatim. No deviation.

Plan "Server flags per row" paragraph covers the design's matrix
dimensions:

- cache mode: hybrid for in-scope rows, legacy for regression control
- hot budget: small, medium, large, integer MiB
- cold path: off or on with safe temporary root
- slot count: 1, 2, 4, 8 with BLOCKED for 8 if host cannot start
- context length: short, medium, near configured limit
- draft presence: none for in-scope rows; cap-fix closed
- workload profile: plain-transformer default; checkpoint-dependent and
  target-plus-draft only when fixture is present
- prompt mix: exact repeats, near duplicates, unique prompts, long
  prefixes
- run length: stress 30 min, benchmarks warmup plus measurement window,
  long-run 6h, 2h, 30m

All 10 dimensions from design part-02 config matrix are present in the
plan. No deviation.

## 5. Evidence format check

Per-scenario stress evidence directory in the plan matches design
part-04 evidence rules:

- server.out.log, server.err.log
- metrics-before.txt, metrics-during.txt, metrics-after.txt
- resource-samples.csv
- precondition.log when a focused binary sets up a precondition
- evidence-summary.md filled by the script

Per-benchmark evidence directory in the plan matches design part-04
evidence rules:

- server.out.log, server.err.log
- metrics-before.txt, metrics-during.txt, metrics-after.txt
- k6-results.json and k6-stdout.txt for B01 and B06
- load-tool-output.txt for non-k6 load tool rows
- baseline.json per row
- legacy-baseline.json when a legacy row exists
- evidence-summary.md filled by the script

Baseline JSON shape in the plan covers all required baseline fields
from design part-03 (commit SHA, build type, binary timestamp, host
hardware, model fixture, slot count, context length, draft mode,
server flags, prompt generator seed, warmup window, measurement
window, request count, throughput, p50/p95/p99 latency, exact-hit
rate, checkpoint-hit rate, restore latency by payload kind, demotion
and promotion counts, eviction count, working set and handle samples,
correctness_verdict field).

Tuning report skeleton in the plan names the seven sections from
design part-03 tuning report: hot budget, cold store, slot count,
context length, draft and MTP, workload profile, bottlenecks.

Consistent. No deviation.

## 6. Risks and prerequisites

Risks table in the plan covers the design's 8 risks plus one
host-specific addition:

- Local host cannot start --parallel 8
- Six-hour long-run cannot fit in a single execution window
- Qwen3-8B fixture cannot load with the in-scope --ctx-size
- Cold-store path permission or disk space fails
- test-stage10-policy-lru pre-existing semantic bug
- Draft and MTP rows were gated on cap-fix closure
- Multi-hour metrics and resource samples grow large
- Public metrics cannot expose a focused precondition

Each risk carries a concrete trigger, impact, and mitigation column
matching the design's single-column style.

Prerequisites section in the plan lists:

- k6 at D:\app\k6\k6.exe
- OpenCppCoverage at D:\app\OpenCppCoverage\OpenCppCoverage.exe
  (used only by run_coverage.ps1, not consumed by new scripts)
- existing pytest and tools/server/tests/unit infrastructure
- model fixtures: Qwen3-0.6B-Q8_0.gguf default, Qwen3-8B larger,
  Qwen3-0.6B separate draft
- build-cov reconfigured with BUILD_SHARED_LIBS=OFF per part-29
- disk: scratch root >= 5 GB, evidence dir >= 20 GB for 6h samples
- local Windows MSVC, no CUDA

Coverage script run_coverage.ps1 reviewed: it is unchanged by Stage 12
and only used for T114/T114a refresh. The plan correctly states the
script is not modified and the new stress/benchmark scripts do not
consume it.

Test scripts dir layout: existing scripts (execute_tests.ps1,
run_benchmark_k6.ps1, run_cache_integration.ps1, run_coverage.ps1,
run_stage4_h30_h37.ps1, stress_tests.ps1) remain. New Stage 12
scripts and drivers go under the same dir. Path layout is
consistent.

## 7. Verdict

PASS. The implementation plan covers every stress scenario (S12-S01
through S12-S08), every benchmark scenario (S12-B01 through S12-B08),
and every long-run check (S12-L01 through S12-L03) from the closed
design. Configuration matrix matches design part-02 and respects the
part-29 cap-fix build-cov baseline. Evidence format matches design
part-04. Risk table covers host-specific concerns including k6
availability, model fixtures, multi-hour wall clock, draft/MTP scope
choice, and test-stage10-policy-lru pre-existing bug. Ordering is
sensible, with explicit parallelization notes and preflight sequencing.
Handoff to the QA test plan names the scenario IDs, baseline JSON
shape, threshold tuning, fixture inventory, BLOCKED rules, cap-fix
status, and evidence-source classification rules. The plan contains no
test cases, no pass/fail criteria, no pass/fail verdicts, and no
authorization for code, builds, tests, commits, PR text, or reviewer
responses. Four non-blocking observations are recorded in Section 3
for the QA test plan to address (legacy-row N/A treatment on B05 and
B08, draft/MTP scope choice, stress_tests.ps1 S02 supersession, and
per-row metric name mapping).

## 8. Manager handoff line

Manager: Stage 12 implementation plan review PASS. Output at
._design_docs/cache-handling-phase12-implementation/part-02-implementation-plan-review.md.
Plan is ready for Manager implementation-plan gate. Four non-blocking
observations carried into the QA test plan: S12-PLAN-01 (B05/B08
nearest legacy throughput/latency), S12-PLAN-02 (stress_tests.ps1 S02
supersession note), S12-PLAN-03 (draft/MTP scope choice by plan), and
S12-PLAN-04 (per-row public metric name mapping). No code, tests,
commits, PR text, or reviewer responses are authorized by this
review. Next gate after Manager implementation-plan gate: Developer
implementation per plan, then QA test planning, then QA execution.
