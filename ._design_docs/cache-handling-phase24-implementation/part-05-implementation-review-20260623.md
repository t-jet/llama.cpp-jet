# Stage 24 implementation review 2026-06-23

Status: REWORK
Date: 2026-06-23
Reviewer: Architect
Subject:

- `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`
- `._design_docs/cache-handling-phase24-implementation.md`
- `._design_docs/cache-handling-phase24-implementation/part-04-runner-implementation-evidence-20260623.md`

Scope: Stage 24 runner and durable implementation evidence only. Product code,
public API schemas, public metric names, model fixtures, Stage 23 evidence, and
Stage 23 runner behavior were not approved or changed by this review.

## Verdict

REWORK.

The runner follows several approved Stage 24 decisions: it uses
`/v1/chat/completions`, keeps `native-legacy` and `hybrid-stage24`, sets S02 to
`--parallel 4`, sets S03 to `--parallel 2`, keeps native free of hybrid flags,
and adds the required hybrid cache, cold path, and redacted evidence flags.
Dry-run and smoke artifacts also show the intended row and variant shape.

Implementation review cannot pass because the runner does not enforce three
approved evidence and safety contracts, and the implementation evidence cites a
durable report file that is not present on disk.

## Review coverage

Reviewed against:

- Stage 24 design: `._design_docs/cache-handling-phase24-design.md`
- Manager design gate: `._design_docs/cache-handling-phase24-design/part-02-manager-design-gate-20260623.md`
- Implementation plan and plan re-review:
  `._design_docs/cache-handling-phase24-implementation.md` and
  `part-02-implementation-plan-re-review-20260623.md`
- Manager implementation-plan gate:
  `part-03-manager-implementation-plan-gate-20260623.md`
- Runner evidence:
  `part-04-runner-implementation-evidence-20260623.md`
- Test output convention:
  `._design_docs/cache-handling-test-plan/part-24-test-output-folder-convention.md`
- Stage 17 evidence rules:
  `._design_docs/cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md`
- Active report whitelist: `._design_docs/.test_reports/.gitignore`

Checks performed:

- Parser/static route scan of the runner.
- Dry-run artifact inspection under
  `._test_output/stage24-chat-s02-s03-20260623-correction-dryrun/`.
- Smoke artifact inspection under
  `._test_output/stage24-chat-s02-s03-20260623-correction-smoke2/`,
  `._test_output/stage24-chat-s02-smoke-20260623-final/`, and
  `._test_output/stage24-chat-s03-smoke-20260623-final/`.
- Direct search for `test-report-20260623*.md` under the repository and
  `.test_reports/`.
- Git status and diff-name checks for product code, public schemas, metrics,
  fixtures, Stage 23 evidence, and Stage 23 runner files.

## Findings

### BLOCKING

| ID | Finding | Evidence | Required correction |
| --- | --- | --- | --- |
| B-24-IMPL-01 | S03 unsafe-prefix evidence is hard-coded instead of computed from request results. The approved plan requires near-prefix requests to be counted as safe misses unless exact chat-boundary identity proves a restore. The runner always writes `near_prefix_cache_n_nonzero = 0` and `no-unsafe-prefix-restore-detected` in `New-Comparison`, without reading the S03 `near-prefix` request records. A live unsafe prefix restore could pass the comparison JSON. | `stage24-chat-s02-s03-comparison.ps1` lines 810-815 hard-code `unsafe_prefix_restore_check`. The smoke `requests.jsonl` happens to show near-prefix `cache_n = 0`, but the runner did not derive the comparison verdict from that data. | Compute class-level S03 request stats from `requests.jsonl`. Fail the row if any `near-prefix` request has `cache_n > 0` without explicit exact-boundary proof. Write the computed counts into `comparison.json` and the durable report. |
| B-24-IMPL-02 | Cleanup safety is not enforced. The approved plan says the runner must prove port cleanup after each leg and classify cleanup failure as `BLOCKED-runner-cleanup` instead of killing unrelated processes or silently continuing. The runner calls `Wait-PortFree` in `finally` and discards the result. | `stage24-chat-s02-s03-comparison.ps1` line 769 casts `Wait-PortFree` to `[void]`; no summary, comparison, or failure path records cleanup failure. | Preserve cleanup result in the leg summary. If the owned process cannot be stopped or the port is not free after the timeout, classify the leg or row as `BLOCKED-runner-cleanup` while preserving any existing `FAIL` state. Do not kill unrelated processes. |
| B-24-IMPL-03 | Durable report evidence is not verifiable. Part 04 claims a final raw-content check on `test-report-20260623-correction-smoke2.md`, but no `test-report-20260623*.md` file exists under the repo or `.test_reports/`. Because the report artifact is absent, the claimed final report coverage and redacted evidence check cannot be reviewed. | `part-04-runner-implementation-evidence-20260623.md` lines 169-170 cite the report check. `Get-ChildItem -Recurse -Filter test-report-20260623*.md` found no matching file. `git status -- ._design_docs/.test_reports` found no Stage 24 report. | Rerun or reconstruct the implementation smoke evidence with a real durable report under `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`. Preserve the report file, rerun final leak scan over that report plus row artifacts, and update part 04 with the exact path and check result. |
| B-24-IMPL-04 | `-ReportPath` is not constrained to the whitelisted durable report location. The default path is acceptable, but a caller can pass any path or filename. That can recreate the report-placement blocker closed during implementation-plan re-review. | `stage24-chat-s02-s03-comparison.ps1` lines 850 and 857 set and resolve `ReportPath`; no check enforces `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`. The active `.gitignore` only guarantees durability for whitelisted names. | Validate `ReportPath` after resolution. Accept only a file directly under `._design_docs/.test_reports/` whose name matches `test-report-\d{8}-\d{2}.md`, unless Manager first approves a whitelist change. |

### Non-blocking

None.

### INFO

| ID | Observation | Evidence | Follow-up |
| --- | --- | --- | --- |
| I-24-IMPL-01 | Route and variant flag shape are mostly correct. | Static scan found only `$Route = '/v1/chat/completions'`; dry-run plan shows S02/S03 rows, `native-legacy` and `hybrid-stage24`, S02 `--parallel 4`, S03 `--parallel 2`, native without hybrid flags, and hybrid with redacted evidence plus cold flags. | Keep these checks in the correction evidence. |
| I-24-IMPL-02 | PASS, FAIL, and BLOCKED are preserved by the current comparison ordering. | `New-Comparison` keeps FAIL ahead of BLOCKED. The 60 second S02 hybrid smoke remains `FAIL-http-request`; the later 3 second correction smoke does not reclassify it. | Manager should decide whether the 60 second S02 failure needs a product bug triage after runner corrections land. |
| I-24-IMPL-03 | Redacted evidence field presence was available in the correction smoke. | Both hybrid correction-smoke summaries report records with `namespace_hash`, `profile`, `pair_state`, `token_count`, `boundary_count`, `lookup_outcome`, and `prefix_candidate`. | Keep this check after the durable report rerun. |
| I-24-IMPL-04 | Review found no product-code or Stage 23 scope drift. | `git status --short -- ._design_docs .agents/skills/self-improvement/assets/architect.md` shows Stage 24 docs/script plus pre-existing docs and memory changes. `git diff --name-only -- .` lists only tracked docs and memory files. No `tools/server`, public schema, metric source, model fixture, Stage 23 report, or Stage 23 runner path appeared in the reviewed changes. | Recheck after Developer correction. |

## Required corrections

Developer should correct the runner and evidence before Manager opens test
planning:

1. Compute S03 near-prefix restore evidence from request records and fail unsafe
   restores.
2. Enforce cleanup proof and record `BLOCKED-runner-cleanup` when cleanup cannot
   be proved.
3. Validate `ReportPath` against the whitelisted durable report convention.
4. Produce a new implementation evidence update with a real durable report file
   under `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` and a final
   leak scan that covers that report.
5. Preserve the earlier 60 second S02 hybrid `FAIL-http-request` evidence until
   Manager or Architect explicitly classifies it.

## Handoff

Handoff state: Developer correction required.

Manager should not open Stage 24 test planning yet. After Developer correction,
Architect should re-review the runner contract, corrected evidence, durable
report path, and cleanup behavior before QA planning opens.
