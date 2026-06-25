# Stage 24 implementation: chat-completion S02/S03 cache comparison

Status: closed; Manager gate decision D-CLOSURE-24-01 2026-06-25
Date: 2026-06-25
Stage: 24 (Chat-Completion S02/S03 Cache Comparison)
Owner: Manager (closure) and Architect (closure sweep)
Source design: [cache-handling-phase24-design.md](cache-handling-phase24-design.md)
Scope: implementation log for the Stage 24 runner and evidence work.
Current gate: terminal (Stage 24 closed)

## Contents

- [Part 1: implementation-plan review 2026-06-23](cache-handling-phase24-implementation/part-01-implementation-plan-review-20260623.md)
- [Part 2: implementation-plan re-review 2026-06-23](cache-handling-phase24-implementation/part-02-implementation-plan-re-review-20260623.md)
- [Part 3: Manager implementation-plan gate 2026-06-23](cache-handling-phase24-implementation/part-03-manager-implementation-plan-gate-20260623.md)
- [Part 4: runner implementation evidence 2026-06-23](cache-handling-phase24-implementation/part-04-runner-implementation-evidence-20260623.md)
- [Part 5: implementation review 2026-06-23](cache-handling-phase24-implementation/part-05-implementation-review-20260623.md)
- [Part 6: implementation-review correction evidence 2026-06-23](cache-handling-phase24-implementation/part-06-implementation-review-correction-evidence-20260623.md)
- [Part 7: implementation re-review 2026-06-23](cache-handling-phase24-implementation/part-07-implementation-re-review-20260623.md)
- [Part 8: Manager implementation gate 2026-06-23](cache-handling-phase24-implementation/part-08-manager-implementation-gate-20260623.md)
- [Part 9: CUDA requirement correction 2026-06-24](cache-handling-phase24-implementation/part-09-cuda-requirement-correction-20260624.md)
- [Part 10: pre-rerun investigation and fixes 2026-06-24](cache-handling-phase24-implementation/part-10-pre-rerun-fixes-20260624.md)
- [Part 11: implementation correction review 2026-06-24](cache-handling-phase24-implementation/part-11-implementation-correction-review-20260624.md)
- [Part 12: dry-run hang fix 2026-06-24](cache-handling-phase24-implementation/part-12-dry-run-hang-fix-20260624.md)
- [Part 13: dry-run hang fix review 2026-06-24](cache-handling-phase24-implementation/part-13-dry-run-hang-fix-review-20260624.md)
- [Part 14: build-path gate and report 03 runner fix 2026-06-24](cache-handling-phase24-implementation/part-14-build-path-and-report03-runner-fix-20260624.md)
- [Part 15: report 03 runner fix review 2026-06-24](cache-handling-phase24-implementation/part-15-report03-runner-fix-review-20260624.md)
- [Part 16: Manager closure 2026-06-25](cache-handling-phase24-implementation/part-16-manager-closure-20260625.md)

## Purpose

This log tracks Stage 24 implementation planning and later runner evidence for
the focused chat-completion comparison. This planning step authorizes no runner,
test-script, product, public API, public metric, fixture, or test execution code
changes.

## Manager intake

Stage 24 was opened to implement the Architect proposal from Stage 23 L02
analysis: rerun the comparison through `/v1/chat/completions`, then compare
native and hybrid cache variants using S02 and S03 workload intent from Stage
23.

## Approved baseline

Inputs reviewed: [document index](document-index.md), [Stage 24 design](cache-handling-phase24-design.md), [design review](cache-handling-phase24-design/part-01-design-review-20260623.md), [Manager gate](cache-handling-phase24-design/part-02-manager-design-gate-20260623.md), [chat-path invariant](cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md), [Stage 17 evidence plan](cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md), [Stage 12 stress definitions](cache-handling-test-plan/part-18-stage12-stress-benchmarks.md), [Stage 12 automation notes](cache-handling-test-plan/part-19-stage12-test-automation.md), and [test output convention](cache-handling-test-plan/part-24-test-output-folder-convention.md).

Manager decisions from the design gate are binding:

- D24-DESIGN-01: accept the Stage 24 design review PASS.
- D24-DESIGN-02: implementation planning is open, and Developer must produce an
  implementation plan before runner, script, test, or product code changes.
- D24-DESIGN-03: preserve the combined focused runner, `native-legacy` and
  `hybrid-stage24` variant names, `/v1/chat/completions` for both variants,
  S02 `--parallel 4`, S03 Qwen3.5 MTP fixture, 10 minute default leg cap,
  redacted hybrid evidence, and no Stage 23 evidence reopening unless Manager
  records a change first.

## Implementation scope

Planned runner file: `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`.
Planned documentation and report files: this log, `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`, and `._test_output/stage24-chat-s02-s03-YYYYMMDD-NN/`.
The durable report must use a title such as "Stage 24 chat S02/S03 comparison"
and identify `RunId = stage24-chat-s02-s03-YYYYMMDD-NN` in its contents. The
stage-specific `RunId` remains the non-durable output identity, not the durable
report filename.

No product code change is expected. The implementation must not edit
`tools/server/*`, public API schemas, public metric names, model fixtures, Stage
23 closed reports, or Stage 23 runner behavior. If implementation discovers a
product defect, stop after preserving evidence and open a reviewed bug-fix loop
instead of patching product code under Stage 24 runner scope.

## Command interface

The focused runner should expose these concepts, using the design names unless a
script-level reason requires a clearer PowerShell spelling:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  ._design_docs\cache-handling-test-scripts\stage24-chat-s02-s03-comparison.ps1 `
  -RunId stage24-chat-s02-s03-YYYYMMDD-NN `
  -RowsToRun S02-chat,S03-chat `
  -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
  -RunRoot ._test_output\stage24-chat-s02-s03-YYYYMMDD-NN `
  -ReportPath ._design_docs\.test_reports\test-report-YYYYMMDD-NN.md `
  -CacheColdPath D:\tmp\cache-cold-stage24 `
  -BasePort 8900 `
  -LegDurationMin 10 `
  -ColdBudgetMiB 512 `
  -DryRun
```

Live execution removes `-DryRun`. Optional implementation parameters may include
`-LlamaServerPath`, `-ContextSize`, `-MaxTokens`, `-Seed`, and `-SmokeSeconds`.
Defaults must match the Stage 24 design, except for the B-24-IP-01 durable
report filename correction. `-ReportPath`, if exposed, must default to the
whitelisted durable path
`._design_docs\.test_reports\test-report-YYYYMMDD-NN.md`; it must not default to
`stage24-chat-s02-s03-YYYYMMDD-NN.md`.

Dry-run must print or write a machine-checkable plan with row, variant, route,
port, model path, cold path, run root, report path, leg cap, server flags, and
request class counts. It must not start `llama-server`, write prompt evidence,
send HTTP requests, or mutate Stage 23 artifacts.

Live flow per leg: validate binary freshness, model path, output directories,
disk headroom, and base port availability; build the static row/variant plan;
clean only owned row/variant output and cold paths; start one server process;
wait for health; collect `metrics-before.txt`; run chat requests; collect
`metrics-after.txt`; write summaries; stop the process; verify the port is free;
then build per-row comparison JSON and append the durable Markdown report.

## Row and variant model

- `S02-chat`: four-worker concurrent chat-completion workload. Required server
  slot setting is `--parallel 4`. Optional `--parallel 8` may be a separate
  follow-up only with Manager approval.
- `S03-chat`: fixed-seed branch-forest workload using exact-repeat,
  near-prefix, and new-branch classes. Required server slot setting is
  `--parallel 2`; default `DistinctPrefixes` is 64 and seed is 42 unless
  Manager lowers it before execution.
- `native-legacy`: current default cache path, no `--cache-mode hybrid`, metrics
  enabled, no Stage 17 prompt evidence or cold-store flags.
- `hybrid-stage24`: `--cache-mode hybrid`, `--cache-ram 512`,
  `--cache-cold-path`, `--cache-cold-max-mib 512`,
  `--cache-prompt-evidence redacted`, `--cache-prompt-evidence-dir`, and metrics
  enabled.

Rows run serially by default. Use base port 8900 for the first server and advance
by 10 for the next row if the runner ever keeps two variant servers alive at
once. Before each live leg, remove only the owned output subdirectory and the
owned cold path for that leg. After each leg, stop the process, wait for exit,
free the port, and fail the leg as `BLOCKED-runner-cleanup` if cleanup cannot be
proved without killing unrelated processes.

## Request generation

All requests must use `/v1/chat/completions`. The runner should build request
bodies from structured `messages` arrays and send them with `temperature = 0`,
deterministic `seed`, bounded `max_tokens`, and the same body sequence for both
variants of the same row.

`S02-chat` should prebuild a small set of worker-specific chat histories with
stable system and user messages. The live loop dispatches them concurrently
across four workers, records worker id and request id, and checks that request
counts, status codes, token counts, `cache_n`, and timing records are complete.

`S03-chat` should generate deterministic chat histories for `exact-repeat`
(identical messages after initial save), `near-prefix` (shared prefix text or
early turns, but different boundary), and `new-branch` (distinct branch roots
from fixed seed and branch index). Near-prefix requests must count as safe
misses unless exact chat-boundary identity proves a restore.

Durable reports must store request ids, class names, hashes, token counts,
bounded labels, and timings only. Raw message content and full request bodies
stay out of durable Markdown and redacted evidence checks.

## Metrics and aggregation

The runner should parse Prometheus text into metric-family samples and compute
before/after deltas for `cache_restore_misses_total`,
`cache_prefix_candidates_total`, `cache_prompt_evidence_records_total`,
`cache_cold_bytes`, `cache_cold_budget_bytes`,
`cache_cold_demotions_skipped_total`, `cache_cold_evictions_total`,
`cache_checkpoint_admissions_by_shape_total`,
`cache_checkpoint_admissions_total`, and
`cache_checkpoint_admission_failures_total`.

Missing metric families must not be invented. If logs, JSONL, or filesystem byte
counts prove the same contract, record the substitute source and keep the metric
gap visible. Otherwise classify the evidence item as
`BLOCKED-metric-unavailable`.

Timing aggregation must compute count, min, median, p95, max, and sum for prompt
time and total time per row/variant. `cache_n` aggregation must record count,
sum, max, nonzero count, nonzero rate, and per-request values in non-durable
JSONL. Token aggregation must record prompt, generated, and total token sums.

Per-leg `summary.json` schema: `run_id`, `row_id`, `variant`, `route`,
`model_path_hash`, `server_flags`, `request_counts`, `status_counts`,
`error_counts`, `token_totals`, `cache_n`, `timing`, `metric_deltas`,
`cold_budget`, `prompt_evidence`, `leak_scan`, `verdict`,
`failure_classification`, and `evidence_paths`.

Per-row `comparison.json` schema: `run_id`, `row_id`, `variants`,
`request_shape_hash_match`, `native_summary`, `hybrid_summary`, `timing_delta`,
`cache_n_delta`, `metric_delta_comparison`, `chat_metadata_evidence`,
`unsafe_prefix_restore_check`, `cold_budget_check`, `verdict`,
`failure_classification`, and `interpretation`.

Durable Markdown report `test-report-YYYYMMDD-NN.md` must summarize those JSON
files, identify the Stage 24 chat S02/S03 comparison and `RunId`, and not
duplicate raw request bodies or full logs.

## Redaction and leak scan

Hybrid legs must write redacted prompt-evidence JSONL. The runner must verify
that evidence records include bounded fields needed for review, such as
`namespace_hash`, `profile`, `pair_state`, `token_count`, `boundary_count`,
`lookup_outcome`, and prefix-candidate state when emitted.

Leak scan must cover the durable report, `requests.jsonl`, `summary.json`,
`comparison.json`, redacted evidence JSONL, and server logs. The scan should use
known generated message strings and forbidden field names to catch raw prompt
text, raw message content, raw paths inside prompt evidence, raw namespace ids,
raw descriptor ids, and full request JSON bodies. A prompt leak from product
output is `FAIL`; a prompt leak from runner-authored durable artifacts is
`FAIL-runner-contract`; missing leak-scan output is
`BLOCKED-evidence-missing`.

## Failure classification

`PASS` requires both variants to use `/v1/chat/completions`, complete their
request set, produce required summaries and comparison JSON, and avoid request
accounting loss. Hybrid must also emit chat metadata containing
`source=openai-chat` and `method=rendered-text-boundary-inference`, write
redacted evidence, pass leak scan, prove cold bytes stay within budget, and
classify exact, miss, and near-prefix outcomes safely.

`FAIL` covers valid-setup product crashes, repeated HTTP 500 after health,
corrupt restore, unsafe prefix restore, cross-slot state corruption, raw prompt
leak in product redacted output, contradictory checkpoint admission metrics, cold
write failure without bounded handling, or unbounded cold growth.

`BLOCKED` covers missing fixture, stale binary, port collision after one setup
retry, disk shortage, server never healthy, missing evidence, missing required
metric without substitute evidence, host capacity limit, or runner contract
violation. Runner contract blocks should be fixed in runner scope before QA live
execution, not treated as product bugs.

## Validation plan before implementation review

Implementation review should receive real runner evidence:

- Dry-run transcript or side log proving rows, variants, route, ports, flags,
  output paths, request class counts, and no product code changes.
- Static or parser check proving every request target is
  `/v1/chat/completions` and no `/completion` fallback exists in the runner.
- Script-level tests or direct function checks for Prometheus parsing, timing
  median/p95/max aggregation, `cache_n` aggregation, metric-unavailable
  classification, comparison JSON shape, and leak-scan failure.
- A 60 second smoke that writes both variant `summary.json` files and
  per-row `comparison.json`. Smoke is review evidence only; it cannot close the
  final Stage 24 acceptance row.
- Hygiene checks: line count under 300 for modified docs, ASCII text, no trailing
  whitespace, durable report under `.test_reports/` only as whitelisted Markdown
  `test-report-YYYYMMDD-NN.md`, and raw outputs under `._test_output/`.

No clean build or full live comparison is required during implementation
planning. Runner implementation should still validate binary freshness before
any smoke or live command.

## Documentation and index needs

`document-index.md` has been updated for this planning correction and re-review
state. If implementation creates a new part file, README, or durable test-plan
part, update the index in that same session.

The existing cache test plan may need a Stage 24 part before QA execution if the
Manager requires a separate QA test-plan gate. If so, the part should reference
this implementation plan, preserve the Stage 24 design decisions, and keep the
execution report under `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`
with raw artifacts under `._test_output/`.

## Risks and review evidence required

- Qwen3.5 MTP may not load with S02 `--parallel 4`; classify as
  `BLOCKED-host-capacity` only after startup evidence is preserved.
- Native and hybrid timing deltas may reflect cache behavior rather than route
  performance. Report deltas as comparison data unless request counts and token
  totals match closely.
- Chat metadata may be absent. Do not substitute `/completion` fallback
  metadata.
- Exact hits in S03 may be low. Safe bounded misses are acceptable if
  near-prefix rejection and no unsafe restore are proved.
- Evidence volume can grow quickly. Keep raw logs and request JSONL in
  `._test_output/`, and keep durable reports to summaries and bounded snippets.

Implementation review needs a changed-file list proving runner/docs scope,
dry-run and static route evidence, parser/aggregation/leak-scan checks, smoke
evidence with both variants and comparison JSON, and explicit classification of
any BLOCKED setup condition as runner, host, fixture, or product.

## Handoff

Current owner: user (commit decision per AGENTS.md and D-CLOSURE-24-01).

Parts 9-11 record the CUDA correction, S02 transport-loss fix, S03
unsafe-prefix runner fix, and Architect PASS. Parts 12-13 record the
dry-run hang fix and Architect PASS. Part 14 records the build-path
gate, report 03 runner-contract block, and runner-only `$Matches`
collision fix. Part 15 records Architect PASS for that fix. Part 16
records the Manager closure per D-CLOSURE-24-01 with per-row final
classification, all Manager decisions verbatim, code change summary,
and follow-up tasks. Stage 24 is closed with documented structural
blocker under D-EXEC-24-03; user approval is required for commit.
