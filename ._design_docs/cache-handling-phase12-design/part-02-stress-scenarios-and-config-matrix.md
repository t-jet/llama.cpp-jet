# Stage 12 design: stress scenarios, configuration matrix, and long-run checks -- Part 2

Source: [../cache-handling-phase12-design.md](../cache-handling-phase12-design.md)

## Stress evidence rules

Stress rows prove that hybrid mode stays bounded and correct under
pressure. Every row records the command family, prompt generator, model
fixture, cache flags, resource samples, metric snapshots, and final
verdict.

Stress evidence must include:

- clean build and binary timestamp
- git commit and dirty worktree state
- model identity without leaking local paths in public summaries
- exact server flags
- request count, concurrency, prompt mix, and random seed
- metrics snapshots before warmup, after warmup, during load, and after
  cooldown
- process memory, Windows handle count or file descriptor count, CPU,
  disk I/O, and server liveness samples
- final `PASS`, `FAIL`, `SKIP`, and `BLOCKED` counts

## Required stress scenarios

| ID | Scenario | Required configuration shape | PASS condition |
| --- | --- | --- | --- |
| S12-S01 | Budget exhaustion | Hybrid mode, tiny `--cache-ram`, cold path disabled and enabled variants | Requests complete, payload bytes stay bounded after legal evictions, eviction counters increase, no crash, no corrupt restore. |
| S12-S02 | Concurrent multi-slot access | Hybrid mode, `--parallel` at 4 and 8 where model and host allow | No deadlock, no lost request accounting, no cross-slot state corruption, hit/miss totals match request totals after accepted startup exclusions. |
| S12-S03 | Large branch forests | Hybrid mode, varied prompt prefixes, long descendant chains, metadata pressure | Branch metadata remains bounded, pruning and metadata-only retention counters move as expected, no invalid cross-namespace restore. |
| S12-S04 | Prompt storms | Hybrid mode, high request rate, many near-duplicate prompts and some exact repeats | Server remains responsive, diagnostics stay bounded, hit rate reflects repeat mix, no unbounded log or metric label growth. |
| S12-S05 | Mixed workload profiles | Plain-transformer, checkpoint-dependent when fixture exists, target-plus-draft when fixture exists | Namespace separation holds, checkpoint and exact-blob rows behave by profile, unsupported shapes fail explicitly or fall back safely. |
| S12-S06 | Cold queue pressure | Hybrid mode with cold path and small hot budget | Demotion and promotion fall back safely on queue pressure, async miss behavior is visible, no partial paired transition. |
| S12-S07 | Protected-root pressure | Hybrid mode, protected roots plus budget pressure | Protected roots get higher retention priority but do not bypass byte accounting; oversize protected entries fail explicitly. |
| S12-S08 | Integrity failure under load | Hybrid mode with fault-injection or controlled cold corruption precondition | Descriptor and cold-store failures reject before live mutation, bounded diagnostics record the failure, load continues safely. |

Rows S12-S05 and S12-S08 may use focused or fixture-specific evidence for
preconditions public HTTP cannot create. Operator-facing claims still
need public metrics or logs when the live server can expose them.

S12-S05 and any other draft or MTP stress row are blocked while the Stage
11 cap-fix cycle remains open on HEAD `02db7a768`. Execution may include
them only after T-MTP-FIX-01 passes and cap-fix T114/T114a are resolved,
or after Manager approves a narrower Stage 12 scope before execution
opens that excludes draft/MTP/cap-fix/coverage rows from required
coverage.

## Configuration matrix

The QA or implementation plan expands this matrix into concrete rows.
The matrix is intentionally bounded so execution is realistic.

| Dimension | Required values | Notes |
| --- | --- | --- |
| Cache mode | legacy, hybrid | Legacy is the control for comparison and regression checks. |
| Hot budget | small, medium, large | Use integer MiB values. Small must force eviction; medium should retain a working set; large should avoid ordinary eviction. |
| Cold path | off, on | Cold-on rows use a safe temporary root with enough disk space. |
| Slot count | 1, 2, 4, 8 where host allows | If 8 cannot start because of model or memory limits, record `BLOCKED` with host limit. |
| Model size | small local fixture, larger local fixture if available | Each run records quantization and context support. |
| Context length | short, medium, near configured limit | Near-limit rows must not exceed server safety checks. |
| Draft presence | none; separate draft and MTP only after cap-fix closure or Manager narrowing | Unsupported draft rows are explicit `BLOCKED` or expected fallback, not silent omissions. While cap-fix T-MTP-FIX-01 plus T114/T114a are open, draft/MTP values are blocked unless Manager excludes them before execution opens. |
| Workload profile | plain-transformer, checkpoint-dependent, target-plus-draft | Profile must be confirmed by fixture capability or focused preflight evidence. |
| Prompt mix | exact repeats, near duplicates, unique prompts, long prefixes | Prompt text is not copied into public summaries. Store generator seed and class instead. |
| Run length | 30 minutes, 2 hours, 6 hours | Six-hour row is the production-like long-run check. |

The plan may reduce combinations by pairwise coverage, but it must keep
each required value present in at least one stress or benchmark row. Any
omitted value needs a Manager-approved reason before execution opens.
Manager-approved narrowing for the open Stage 11 cap-fix cycle must name
the omitted draft/MTP/cap-fix/coverage values and update closure
prerequisites before execution starts.

## Long-run checks

Stage 12 requires one production-like long run and one shorter
reproducibility run.

| ID | Run | Minimum duration | Required checks |
| --- | --- | --- | --- |
| S12-L01 | Production-like hybrid long run | 6 hours | Memory stability, handle or file descriptor stability, metric counter monotonicity, cold-store file count stability, hit/miss plausibility, latency drift, server liveness. |
| S12-L02 | Reproducibility run | 30 minutes | Same seed and fixture as one benchmark row; confirms metric and latency shape is repeatable within recorded tolerance. |
| S12-L03 | Legacy control long run | 2 hours | Legacy mode remains stable and does not show cache-related metric or public surface changes. |

### Resource stability thresholds

The QA plan may tune numeric thresholds before execution opens, but it
must record them before the first run. Default thresholds:

- process working set growth after warmup: less than 10% over 6 hours
- Windows handle or file descriptor growth after warmup: less than 5%
- cold-store file count after cooldown: no orphan growth outside
  expected resident cold descriptors
- metric counter stability: counters are monotonic where expected and
  never reset while the process stays alive
- latency drift: p95 restore or generation latency does not grow by more
  than 20% after warmup without a recorded workload cause

Any crash, hang, deadlock, data corruption, unsafe restore, unbounded log
growth, or unbounded metric label growth is a blocking failure.

## Correctness checks during stress

Each stress row needs a correctness gate:

- deterministic prompt generator and expected response classifier where
  exact text comparison is reliable
- fallback-safe response validation where exact text comparison is not
  stable
- cache metric sanity checks: hits plus misses match accepted requests
  after documented exclusions
- namespace checks for mixed model, draft, or workload rows
- no partial target/draft restore, demotion, promotion, or eviction
- no prompt text, marker text, local path, checksum, payload bytes, or
  serialized state in public metrics or bounded diagnostics

Performance degradation alone is not a correctness failure. Correctness
failure blocks benchmark claims even when throughput improves.
