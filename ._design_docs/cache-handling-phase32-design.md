# Stage 32 design: post-Stage-31 live comparison rerun

Status: design gate PASS; ready for Developer planning and QA execution
Date: 2026-06-29
Stage: 32 (Stage 31 follow-up and live comparison rerun)
Owner: Architect
Current gate: design complete
Branch: work-branch
Review: [independent design review 2026-06-30](./cache-handling-phase32-design/part-01-design-review-20260630.md): PASS.

## Goal

Stage 32 reruns the model-backed legacy-vs-hybrid comparison on the current
tree after Stage 31 fixed namespace compatibility and public metric shape.

The stage answers one question: do the Stage 31 fixes produce live comparison
evidence that hybrid mode reuses cache state, keeps namespace and Prometheus
cardinality bounded, preserves correctness, and stays within the Stage 30
performance envelope?

## Baseline

Binding baseline:

- Stage 31 Manager closure PASS on 2026-06-29.
- Stage 31 focused QA PASS: clean Release configure, clean Release
  `test-cache-controller` build, direct run, `ctest -R cache`, namespace
  stability, bounded metric labels, single HELP/TYPE checks, and Stage 30
  wording correction.
- Stage 31 Developer review PASS: no product bug remains from the focused
  evidence, and live Stage 30 rerun was advisory for Stage 31 closure.

Stage 30 live baseline:

- Cold cycle 1 completed both modes.
- Legacy cold leg took 27.6 min.
- Hybrid cold leg took 31.3 min.
- Hybrid used 161 MiB hot RAM vs legacy 423 MiB, a 62% reduction.
- Throughput was effectively tied: hybrid within 0.1% on prompt throughput.
- Output equivalence was byte-identical.
- Hybrid wrote 2.0 GiB cold payloads across 26 payloads with 0 failures.
- Hybrid reported 0 cache hits, 200 misses, about 163 namespaces, and raw
  namespace labels before Stage 31 fixed namespace and metric shape.

## Scope decisions

In scope:

- Rerun the Stage 29/30 comparison driver on the current fixed tree.
- Prove non-zero hybrid cache reuse in live traffic.
- Prove namespace count is bounded in live `/metrics`.
- Prove public Prometheus labels stay bounded.
- Prove each emitted cache metric has one HELP block and one TYPE block.
- Re-check correctness, hot RAM, cold-store validity, and performance.
- Record a failure path if live evidence still shows zero hits or high
  namespace cardinality.

Non-goals:

- Debug-only build repair for the known const-mutex compile issue at
  `server-cache-hybrid.cpp:4601`. Stage 31 and Stage 32 use clean Release
  evidence.
- Cleaning pre-existing Release `%zu` warnings in later
  `tests/test-cache-controller.cpp` code outside the Stage 31 changes.
- Rewriting the Stage 29 driver unless a small evidence extraction patch is
  needed for Stage 32 reporting.
- Changing cache production behavior before the live rerun produces a new
  failure or Developer planning identifies a missing evidence hook.
- Treating response caching as the target. The target is KV-cache reuse through
  `cache_n`, cache hit counters, branch namespace state, and cold/hot payload
  metrics.

## Rerun plan

Use the existing Stage 29/30 driver:

- Script: `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`
- Workload lib:
  `._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`
- Route: `/v1/chat/completions`
- Modes: `legacy` and `hybrid`
- Sequential execution only. Do not run both servers concurrently.
- Same port for each leg after process cleanup and VRAM cooldown.
- Same generated workload JSONL for both modes.
- Only cache mode and hybrid cold-path flags may differ between modes.

Required run shape:

- `ContextSize=4096`
- `Parallel=2`
- `Seed=42`
- `RequestCount=200`, matching the Stage 30 completed cold-cycle evidence
- `SizeClass=2k` through the existing workload builder
- `OutputEquivalencePrompts=5`
- `Cycles=3` warm cycles after the cold-start cycle, unless Manager explicitly
  approves a shorter smoke run before the full run
- Clean, unique `RunId` and `RunRoot`, for example
  `stage32-cache-modes-20260629-01`
- Fresh `CacheColdPath`, empty before the run

The driver already records:

- `workload.jsonl`
- `equivalence-prompts.jsonl`
- per-leg `metrics-before.txt`
- per-leg `metrics-after.txt`
- per-leg `requests.jsonl`
- `summary.json`
- output-equivalence decoded files and `diff.txt`

Developer planning may add post-processing only if it does not change request
traffic. Acceptable additions are summary extraction for namespace count,
HELP/TYPE counts, bounded-label checks, p50/p99 timing, and per-class
`cache_n` aggregation.

## Evidence requirements

Non-zero hybrid cache reuse:

- Hybrid `requests.jsonl` must contain at least one row with `cache_hit=true`.
- Hybrid `requests.jsonl` must contain at least one row with `cache_n > 0`.
- Hybrid `summary.json` or metrics delta must show
  `llamacpp:cache_hits_total` increased during at least one completed hybrid
  leg.
- Exact-repeat rows are the primary acceptance source. Near-prefix rows may
  count only when `cache_n > 0` proves restored prompt tokens.
- Report per-class counts for `exact`, `near_prefix`, and `new_branch`.

Bounded namespace count:

- Hybrid `metrics-after.txt` must include
  `llamacpp:cache_namespace_count{mode="hybrid",scope="all"}` or the
  Stage 31 bounded equivalent.
- For one model/config/profile run, live namespace count should stay small,
  normally 1. A count above 4 is a FAIL unless the report explains a real
  runtime-compatibility split such as profile or draft-mode change.
- Raw namespace IDs must not appear as public Prometheus labels.

Bounded Prometheus labels:

- Cache metrics may use bounded labels such as `mode`, `scope`, `method`, or
  bounded reason enums.
- Cache metrics must not expose raw namespace IDs, prompt hashes, request IDs,
  file paths, or free-form prompt metadata as labels.
- The report must grep the hybrid `metrics-after.txt` and list any unbounded
  label names or state `none found`.

Single HELP/TYPE blocks:

- For each cache metric name present in `metrics-after.txt`, the report must
  count HELP and TYPE lines.
- Each metric name must have at most one HELP line and at most one TYPE line.
- Any duplicate HELP or TYPE block is a FAIL.

Correctness and cold-store:

- Output equivalence must pass with empty `diff.txt`.
- Hybrid cold path must record non-zero cold payload bytes and payload count
  when demotion occurs.
- Cold-store failure counters must not increase.
- Server stderr must not show crashes, SEH dumps, or request-processing errors.

## Performance acceptance

Stage 32 compares against the Stage 30 cold-cycle baseline, not a synthetic
unit-test threshold.

PASS if all are true:

- Output equivalence PASS.
- Hybrid hot RAM remains lower than legacy hot RAM on the completed comparison
  legs. Target: at least 40% lower hot RAM; Stage 30 achieved 62%.
- Hybrid prompt throughput is no worse than 10% below legacy on comparable
  completed legs.
- Hybrid token generation throughput is no worse than 10% below legacy on
  comparable completed legs.
- Hybrid cold-store failures remain zero.
- Non-zero hybrid reuse evidence exists.
- Namespace and Prometheus checks pass.

PARTIAL if correctness and bounded-memory checks pass but the full warm-cycle
set does not finish inside the approved wall-clock budget. A PARTIAL result
must still include completed-leg evidence and explain which rows remain open.

FAIL if correctness fails, hybrid reuse remains zero on completed exact-repeat
traffic, namespace cardinality is high without a compatibility explanation,
public labels are unbounded, HELP/TYPE blocks duplicate, or hybrid throughput
regresses by more than 10% without an accepted environmental cause.

## Wall-clock and cleanup rules

Stage 30 proved the 60-90 min cap was too short:

- Cold legacy: 27.6 min.
- Cold hybrid: 31.3 min.
- Warm-cycle-1 legacy was still running when the 86 min run was killed.

Stage 32 full run budget:

- Reserve 150 min for the full 4-cycle comparison.
- Allow Manager to extend to 180 min if warm-cycle-1 still makes progress and
  all artifacts are being written.
- Do not kill a leg unless wall-clock budget expires, the server stops making
  progress, or required cleanup cannot be guaranteed.

Cleanup rules:

- Stop each server process before the next leg.
- Wait for VRAM baseline using the existing driver helper.
- Use a fresh cold path and capture `du` or equivalent size proof after hybrid
  legs.
- Preserve partial artifacts if the run is killed.

## Clean build and stale-binary rules

Before live execution:

- Configure a clean Release build.
- Build `llama-server` Release from the current tree.
- Build and run the Stage 31-focused `test-cache-controller` target or record
  a fresh carry-forward if Manager explicitly accepts the Stage 31 binary.
- Capture binary path, size, timestamp, git HEAD, dirty status, and
  `CMakeCache.txt` CUDA proof when using CUDA.
- The `llama-server.exe` timestamp must be newer than the Stage 31 source
  changes being validated, or the run is BLOCKED-stale-binary.

Debug builds are not required. Release warnings that match the known `%zu`
test warnings are advisory only unless they become errors or touch Stage 32
evidence extraction code.

## Failure handling

If live hybrid reuse is still zero:

- Mark the Stage 32 comparison FAIL, not PASS-with-advisory.
- Preserve `workload.jsonl`, hybrid `requests.jsonl`, metrics snapshots, server
  logs, and cold-path file listing.
- Classify whether exact-repeat rows were present and whether their rendered
  token vectors matched.
- Open a focused Developer correction loop against save/restore parity,
  `cache_n` timing propagation, branch lookup, or workload construction.

If namespace cardinality is high:

- Mark FAIL unless each namespace maps to a documented compatibility split.
- Preserve the bounded JSON/debug stats that still contain raw namespace IDs.
- Compare runtime compatibility inputs across requests.
- Do not reintroduce raw namespace IDs as Prometheus labels to debug the issue.

If HELP/TYPE or label checks fail:

- Mark FAIL-metric-shape.
- Fix public metric emission before any performance verdict is accepted.

If performance regresses:

- Keep correctness artifacts.
- Compare completed legs only.
- Check stale binary, CUDA proof, VRAM baseline, server stderr, and host load
  before assigning product blame.
- If the regression remains above 10%, require Developer analysis before
  Manager closure.

## Implementation and test-plan expectations

Developer plan must:

- Reuse the Stage 29/30 driver unless a narrow evidence extractor is needed.
- List exact command lines and output paths.
- Include stale-binary checks and clean Release build proof.
- Define post-processing for cache reuse, namespace count, label bounds,
  HELP/TYPE counts, hot RAM, cold bytes, p50/p99 timing, and summary status.
- Keep any script change separate from product-code changes.
- Avoid product-code edits unless Stage 32 evidence fails and Manager opens a
  correction loop.

QA report must:

- Use a fresh Stage 32 report path under `._design_docs/.test_reports/`.
- Record PASS/PARTIAL/FAIL rows for correctness, reuse, namespace bounds,
  Prometheus shape, cold-store validity, performance, cleanup, and hygiene.
- Include completed-leg artifact paths.
- Preserve partial-run evidence if wall-clock expires.

## Acceptance criteria

Design gate passes when this document gives Developer and QA enough detail to
run Stage 32 without changing production code first: Stage 31 baseline, scope
decisions, driver reuse, live evidence requirements, performance thresholds,
wall-clock budget, clean-build rules, and failure handling are all explicit.

## Handoff

Next owner: Developer.

Next gate: implementation/test execution planning for Stage 32 live comparison.
No code implementation is approved by this design except narrow evidence
extraction around the existing comparison artifacts. Product-code changes need
a new correction decision after Stage 32 evidence shows a live failure.
