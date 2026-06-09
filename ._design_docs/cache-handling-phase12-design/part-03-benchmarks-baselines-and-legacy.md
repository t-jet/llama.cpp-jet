# Stage 12 design: benchmark scenarios, baseline, tuning report, and legacy comparison -- Part 3

Source: [../cache-handling-phase12-design.md](../cache-handling-phase12-design.md)

## Benchmark evidence rules

Benchmarks compare hybrid mode to the legacy path on the same commit,
host, build configuration, model fixture, context length, request mix,
and load tool version. The report records absolute numbers and the
hybrid-vs-legacy ratio.

Every benchmark row records:

- hardware summary: CPU, RAM, storage type, OS, and relevant power mode
- build type and compiler
- model fixture, quantization, context length, slot count, and draft mode
- server flags for legacy and hybrid runs
- warmup window and measurement window
- request count, request mix, concurrency, and seed
- correctness gate result before performance verdict
- evidence source for each metric: public Prometheus, structured log,
  direct stats, load-tool output, or focused harness
- raw artifact paths in the test report

## Required benchmark scenarios

| ID | Scenario | Measurement | PASS condition |
| --- | --- | --- | --- |
| S12-B01 | Exact-blob hit rate | Hit rate on exact repeated prompts after warmup | Hybrid records measurable exact hits and no correctness regression. |
| S12-B02 | Checkpoint hit rate | Checkpoint hit and restore rows on checkpoint-capable fixture | Hybrid records checkpoint activity for capable profiles, or the row is `BLOCKED` with missing fixture. |
| S12-B03 | Cold transition frequency | Demotions, promotions, async misses, cold latency | Transitions are bounded, paired, and explained by hot-budget pressure. |
| S12-B04 | End-to-end token throughput | Tokens per second and request latency for legacy and hybrid | Hybrid shows measurable gain on at least one target workload and no unexplained legacy regression. |
| S12-B05 | Restore latency | p50, p95, p99 restore latency by payload kind and residency | Restore latency is recorded with correctness evidence and no unbounded tail growth. |
| S12-B06 | Prompt-storm efficiency | Throughput, hit rate, eviction churn, and diagnostics under high repeat pressure | Hybrid improves repeat-heavy workload behavior or records bottleneck cause. |
| S12-B07 | Mixed-profile comparison | Throughput and restore behavior by profile | Plain-transformer and checkpoint-dependent rows follow Stage 9 strategy rules. |
| S12-B08 | Large-forest lookup cost | Branch lookup latency or request latency as forest grows | Lookup cost remains bounded enough for operator use, or bottleneck is documented with tuning advice. |

Rows S12-B02 and S12-B07 require suitable fixtures. Missing fixtures are
setup blockers unless the Manager narrows the matrix before execution
opens.

Rows that measure separate draft, MTP, target-plus-draft, or cap-fix
coverage-sensitive behavior are additionally blocked by the open Stage 11
cap-fix cycle on HEAD `02db7a768`. They cannot be planned or executed
until T-MTP-FIX-01 passes and cap-fix T114/T114a are resolved, unless
Manager approves a narrower Stage 12 scope before execution opens.

## Baseline report

The Stage 12 report must include a baseline section with stable numbers
future stages can compare against.

Required baseline fields:

- commit SHA and dirty worktree state
- architecture and design baseline links
- build command and binary timestamp
- host hardware and OS
- model fixture names, quantization, and context support
- cache flags for each row
- prompt generator, request mix, seed, and concurrency
- legacy and hybrid throughput
- legacy and hybrid p50, p95, and p99 request latency
- exact-hit rate and checkpoint-hit rate where applicable
- restore latency by payload kind and residency where observable
- cold demotion and promotion counts
- eviction count and protected-root decision count
- working set, handle or file descriptor, and disk usage samples
- correctness verdict

Baselines are not promises that every future run must match exactly.
They are regression detection anchors. The report must state allowed
variance or require future runs to explain variance.

## Tuning report

Stage 12 also produces a bottleneck and tuning report for operators.
The report does not prescribe new code. It records observed behavior and
safe operator choices.

Required tuning sections:

1. Hot budget guidance
   - Describe the smallest budget that avoids constant eviction for each
     measured workload.
   - Record when protected roots increase pressure.
2. Cold store guidance
   - Record when cold storage helps, when it adds latency, and what disk
     behavior was observed.
3. Slot count guidance
   - Record throughput and p95 latency by slot count.
   - Identify the point where contention outweighs reuse.
4. Context length guidance
   - Record when longer context improves reuse and when it increases
     restore or serialization cost.
5. Draft and MTP guidance
   - Record which draft modes are supported by the fixture and how they
     affect namespace reuse, but only if cap-fix evidence is closed or
     Manager-approved narrowing keeps these rows out of required scope.
6. Workload profile guidance
   - Explain plain-transformer, checkpoint-dependent, and target-plus-
     draft results separately.
7. Bottlenecks
   - Record CPU, memory, disk, cold I/O, branch lookup, queue pressure,
     or metric-export bottlenecks with evidence.

The tuning report must avoid unmeasured claims. If a scenario was not
run, it is named as not measured.

## Legacy comparison

Legacy mode is the control, not a secondary note. Every benchmark family
must include a legacy row unless the scenario depends on a hybrid-only
feature such as cold demotion or checkpoint branch reuse. Even then, the
nearest legacy throughput and latency row is included for comparison.

Legacy comparison checks:

- default mode without `--cache-mode hybrid` still starts and serves the
  workload
- legacy public `/metrics` and `/health` shape remains compatible with
  prior reports
- legacy throughput and latency are not worse than the Stage 11 baseline
  by more than the recorded variance without a Manager decision
- hybrid-only metrics do not appear as active legacy behavior
- legacy run has no hybrid cold-store side effects
- draft/MTP legacy comparisons are included only after cap-fix closure
  or Manager-approved narrowing documents their exclusion

Any legacy correctness failure, crash, public surface regression, or
unexplained major performance regression blocks Stage 12 closure.

## Measuring gains

Hybrid mode must show measurable gain on at least one configured target
workload. Acceptable gain forms:

- higher tokens per second on repeat-heavy prompts
- lower p95 request latency after warmup on exact-repeat prompts
- lower restore cost than recompute for suitable payloads
- checkpoint reuse on checkpoint-dependent workloads where fixture
  support exists
- bounded cold transitions that preserve memory under pressure while
  later requests benefit from promotion

The report must not claim a gain from cache hits alone. It must pair hit
or checkpoint counters with end-to-end throughput, request latency, or
restore latency.

## Regression handling

If a benchmark shows regression, the report classifies it:

| Classification | Meaning | Required action |
| --- | --- | --- |
| EXPECTED-COST | Hybrid work adds cost for a workload not meant to benefit | Record workload and tuning guidance. Manager may accept. |
| TUNING-GAP | Better flags or budget would likely fix the result | Add rerun recommendation and operator note. |
| PRODUCT-BUG | Correctness, safety, or boundedness broke | Open bug-fix loop. Stage cannot close. |
| TOOLING-GAP | Load tool, model fixture, or sampler invalidated the number | Rerun or record `BLOCKED`; do not use as baseline. |
| LEGACY-REGRESSION | Legacy path changed or slowed without explanation | Block closure until Manager decision and fix path. |

Regression classification belongs in the Stage 12 report, not in this
design.
