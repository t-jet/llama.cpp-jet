# Stage 32 implementation-plan review 2026-06-30

VERDICT: REWORK

## Scope and gate status

Review subject:

- `._design_docs/cache-handling-phase32-implementation.md`

Inputs checked:

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase32-design.md`
- `._design_docs/cache-handling-phase32-design/part-01-design-review-20260630.md`
- `._design_docs/.manager-inputs/manager-input-20260629-stage32-fix-stage31-and-rerun-comparison.md`
- `._design_docs/.test_reports/test-report-20260629-12-stage30-01.md`
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`
- `._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`
- Stage 31 closure and evidence docs referenced by the index.

Gate status: REWORK. The plan matches the approved run shape and driver API,
but QA still has to invent required stale-binary and post-processing decisions.
Stage 32 execution should not open until the findings below are corrected.

## Decisions

| Check | Decision |
| --- | --- |
| Approved design baseline | PASS. The plan uses the approved Stage 32 design and design-review PASS. |
| Driver API and run shape | PASS. The listed driver parameters exist: `RunId`, `ModelPath`, `RunRoot`, `ReportPath`, `CacheColdPath`, `LlamaServerPath`, `BasePort`, `ColdBudgetMiB`, `HotBudgetMiB`, `ContextSize`, `Parallel`, `Seed`, `RequestCount`, `Cycles`, and `OutputEquivalencePrompts`. `-Cycles 3` means three warm cycles after the driver's fixed cold cycle. |
| Workload library | PASS. `New-ComparisonWorkload` supports `SizeClass '2k'` and the driver hard-codes it for both workload and equivalence prompt generation. |
| Sequential execution | PASS. The driver starts one server process per leg, stops it, and waits for VRAM cooldown before the next leg. The plan also states not to run legacy and hybrid concurrently. |
| Clean build rule | PASS with one review note. The plan removes `build-cuda`, configures Release with `GGML_CUDA=ON`, and builds `llama-server` plus `test-cache-controller`. Build-log paths still need to be bound by Finding F32-PLAN-02. |
| CUDA proof | PASS. The plan checks `CMakeCache.txt` for `GGML_CUDA:BOOL=ON`, and the driver preflight has the same CUDA proof rule. |
| Non-goals | PASS. Debug-only const-mutex build repair, known Release `%zu` warnings, response caching, and product-code edits before failed live evidence stay out of scope. |
| Classification rules | PASS with dependency on F32-PLAN-02. PASS, PARTIAL, FAIL, and BLOCKED match the design, but some evidence predicates lack executable extraction commands. |

## Findings

### F32-PLAN-01: stale-binary proof has no source-file baseline

Severity: BLOCKING

Plan location: `cache-handling-phase32-implementation.md`, stale-binary proof
block.

Design requirement: `cache-handling-phase32-design.md` requires the
`llama-server.exe` timestamp to be newer than the Stage 31 source changes being
validated, otherwise the run is `BLOCKED-stale-binary`.

Problem: the plan captures `llama-server.exe` and `test-cache-controller.exe`
metadata, but it never lists the Stage 31 source files or runs a comparison
against their timestamps. QA would have to decide which files count as "Stage
31 source changes". That is a missing gate decision.

Required correction:

- Add an exact command that records and compares `LastWriteTimeUtc` for the
  Stage 31 source set:
  `tools/server/server-cache-hybrid.cpp`,
  `tools/server/server-cache-hybrid.h`,
  `tools/server/server-context.cpp`,
  `tools/server/server-context.h`, and `tests/test-cache-controller.cpp`.
- The command must fail or print `BLOCKED-stale-binary` if
  `llama-server.exe` is not newer than the newest production source in that
  set. The controller binary should be checked against
  `tests/test-cache-controller.cpp`.
- Record the output path for this proof under the Stage 32 run root or test
  report evidence directory.

### F32-PLAN-02: post-processing is not executable enough for QA

Severity: BLOCKING

Plan location: `cache-handling-phase32-implementation.md`, post-processing and
artifact collection sections.

Design requirement: the Stage 32 design says Developer planning must define
post-processing for cache reuse, namespace count, bounded labels, HELP/TYPE
counts, hot RAM, cold bytes, p50/p99 timing, and summary status.

Problem: the plan lists what to extract, but not exact commands, output paths,
or accepted regexes. The largest gaps are:

- bounded-label scan: no concrete pattern for raw namespace IDs, prompt hashes,
  request IDs, file paths, or free-form prompt metadata;
- HELP/TYPE count: no command that groups by cache metric name and reports
  duplicates;
- namespace count: plan names
  `llamacpp:cache_namespace_count{mode="hybrid",scope="all"}`, while the live
  Stage 31 metric writer emits `llamacpp:cache_namespace_count` through the
  normal `mode` label path and uses `scope="all"` on namespace node/root/byte
  aggregate metrics;
- p50/p99 timing and cache reuse by class: no command names which JSONL files
  are scanned, which fields are used, or where the result is written;
- build, controller, ctest, stale-binary, CUDA, and cleanup proof outputs are
  named as artifacts but do not have capture paths.

QA could run the comparison, but the report would depend on QA-authored
extraction logic. That is outside the approved handoff.

Required correction:

- Add a small set of exact PowerShell post-processing commands or a narrowly
  scoped evidence-only extractor command.
- Bind each extraction output to a path under
  `D:\source\llama.cpp-jet\_test_output\stage32-cache-modes-20260630-01`.
- Include commands for:
  cache-hit and `cache_n > 0` rows by class, hit deltas, namespace count,
  bounded-label scan, HELP/TYPE count, hot RAM comparison, cold path size and
  payload count, cold failure counters, p50/p99 timing if available, server
  error scan, port/process cleanup, and VRAM cooldown evidence.
- State the accepted namespace metric forms explicitly:
  `llamacpp:cache_namespace_count{mode="hybrid"}` for count, and
  `scope="all"` on aggregate namespace node/root/metadata-byte metrics.

## Non-blocking notes

- The model fixture path in the plan exists locally:
  `._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf`.
- The driver still writes a Stage 29-shaped report when `-ReportPath` is set.
  The Stage 32 QA report may use that file as a starting artifact, but the
  final Stage 32 report still needs the Stage 32 verdict rows required by the
  design.
- The plan correctly keeps product-code changes out of this stage unless live
  evidence fails and Manager opens a correction loop.

## Required corrections

1. Fix F32-PLAN-01 by adding executable stale-binary comparison proof.
2. Fix F32-PLAN-02 by adding exact post-processing and evidence-capture
   commands, with output paths.
3. Update the parent implementation entry status after the corrections.

## Handoff

State: REWORK.

Next owner: Developer.

Next gate: implementation-plan re-review after the stale-binary and
post-processing corrections are recorded. QA should not start the live
comparison from the current plan.
