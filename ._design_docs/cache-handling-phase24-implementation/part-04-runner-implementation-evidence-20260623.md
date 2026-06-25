# Stage 24 runner implementation evidence 2026-06-23

Status: implementation evidence captured; implementation review ready
Date: 2026-06-23
Owner: Developer
Scope: Stage 24 runner and docs only.

## Files changed

- `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`
- `._design_docs/cache-handling-phase24-implementation.md`
- `._design_docs/cache-handling-phase24-implementation/part-04-runner-implementation-evidence-20260623.md`

No product code, public API/schema, public metric names, model fixtures, Stage 23
reports, or Stage 23 runner behavior were edited.

## Runner behavior implemented

The new runner is a focused Stage 24 harness for `S02-chat` and `S03-chat`.
It compares `native-legacy` and `hybrid-stage24` legs through
`/v1/chat/completions` only.

Exposed parameters:

- `RunId`, `RowsToRun`, `ModelPath`, `RunRoot`, `ReportPath`
- `CacheColdPath`, `BasePort`, `LegDurationMin`, `ColdBudgetMiB`
- `DryRun`, `SmokeSeconds`, `LlamaServerPath`, `ContextSize`, `MaxTokens`,
  `Seed`, `DistinctPrefixes`, and `ServerStartupTimeoutS`

Defaults follow the approved plan: `RunId` uses
`stage24-chat-s02-s03-YYYYMMDD-NN`, `RunRoot` uses `._test_output/<RunId>/`,
and `ReportPath` uses the whitelisted
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` form. Dry-run writes
`dry-run-plan.json` and starts no server.

Per-leg artifacts:

- `launch.log`
- `server.out.log` and `server.err.log` when the server starts
- `metrics-before.txt` and `metrics-after.txt`
- `requests.jsonl`
- `summary.json`

Per-row artifact:

- `comparison.json`

The durable report omits raw prompt text and request bodies. Raw request JSONL
and logs stay under `._test_output/`.

## Contract details

- S02 uses `--parallel 4`.
- S03 uses `--parallel 2`, `DistinctPrefixes = 64`, and seed 42 by default.
- Native omits `--cache-mode hybrid` and Stage 17 cold/evidence flags.
- Hybrid includes `--cache-mode hybrid`, `--cache-ram 512`,
  `--cache-cold-path`, `--cache-cold-max-mib 512`,
  `--cache-prompt-evidence redacted`, and
  `--cache-prompt-evidence-dir`.
- Prometheus text parsing records before/after/delta per required family and
  marks missing families as `BLOCKED-metric-unavailable`.
- Cold-byte fallback uses cold-path byte count when cold metrics are missing.
- Leak scan writes the durable report first, scans report plus requests,
  summaries, comparisons, evidence, and logs, then rewrites only bounded
  leak-scan status into summaries, comparisons, and the report. A final scan
  covers the final report content. It checks generated prompt strings plus
  forbidden raw-field names.
- Comparison classification now preserves `PASS`, `FAIL`, and `BLOCKED`
  separately instead of softening leg failures into blocked rows.

## Verification

Static parser check:

```powershell
[System.Management.Automation.Language.Parser]::ParseFile(...)
```

Result: `PARSE OK`.

Route/static check:

```powershell
Select-String stage24-chat-s02-s03-comparison.ps1 -Pattern '/completion|/v1/chat/completions'
```

Result: only the `$Route = '/v1/chat/completions'` assignment matched. No
`/completion` fallback exists in the runner.

Dry-run command:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File `
  ._design_docs\cache-handling-test-scripts\stage24-chat-s02-s03-comparison.ps1 `
  -RunId stage24-chat-s02-s03-20260623-dev `
  -ReportPath ._design_docs\.test_reports\test-report-20260623-dev.md `
  -RunRoot ._test_output\stage24-chat-s02-s03-20260623-dev `
  -CacheColdPath D:\tmp\cache-cold-stage24-dev `
  -DryRun
```

Machine-check summary from `dry-run-plan.json`:

- route: `/v1/chat/completions`
- rows: `S02-chat,S03-chat`
- variants: `native-legacy,hybrid-stage24`
- row ports: `8900,8910`
- S02 parallel: `4`
- S03 parallel: `2`
- S03 distinct prefixes: `64`
- native hybrid flags present: `false`
- hybrid redacted evidence flags present: `true`

Live smoke evidence:

- `stage24-chat-s02-smoke-20260623-final`, S02 only, `SmokeSeconds 60`,
  exited 0 and wrote both leg summaries plus `S02-chat/comparison.json`.
  Native passed with 256 HTTP 200 responses. Hybrid emitted redacted evidence
  and clean leak scan but hit repeated request connection closures after 17
  HTTP 200 responses, so the row is preserved as `FAIL-http-request`.
- `stage24-chat-s03-smoke-20260623-final`, S03 only, `SmokeSeconds 60`,
  exited 0 and wrote both leg summaries plus `S03-chat/comparison.json`.
  Native passed with 181 HTTP 200 responses. Hybrid passed with 111 HTTP 200
  responses, redacted evidence present, cold budget PASS, and leak scan PASS.

These smoke runs are implementation evidence only. They do not close final
Stage 24 acceptance.

## Implementation correction

Manager implementation-check blocker: the first runner version built the leak
scan artifact list with `ReportPath`, but called `Invoke-LeakScan` before
`Write-Report`. When the durable report did not exist yet, report Markdown was
not covered by leak-scan evidence.

Correction applied:

- The runner now writes an initial durable report after all row comparisons are
  available.
- It runs per-row leak scans over the report, request JSONL, summaries,
  comparison JSON, redacted evidence, and logs.
- It writes bounded leak status into `summary.json`, `comparison.json`, and the
  durable report.
- It runs a final scan over the final durable report plus all row artifacts.
  If that final scan fails, it preserves existing `FAIL` or `BLOCKED` row state
  and only upgrades passing rows to `FAIL-runner-contract`.
- The report table now includes leak-scan status and correct relative evidence
  paths such as `S02-chat/comparison.json`.

Ordering proof:

- line 896: `Write-Report -Comparisons $comparisons.ToArray()`
- line 903: per-row `Invoke-LeakScan`
- line 917: final bounded report rewrite
- line 925: final `Invoke-LeakScan` over final report and all artifacts

Correction verification:

- Parser check: `PARSE OK`.
- Route scan: only `$Route = '/v1/chat/completions'` matched; no `/completion`
  fallback exists.
- Dry-run:
  `stage24-chat-s02-s03-20260623-correction-dryrun`, rows
  `S02-chat,S03-chat`, report path
  `._design_docs/.test_reports/test-report-20260623-correction-dryrun.md`,
  S02 `--parallel 4`, S03 `--parallel 2`, native without hybrid flags, hybrid
  with redacted evidence flags.
- Final report raw-content check on
  `test-report-20260623-correction-smoke2.md`: no generated prompt strings and
  no forbidden raw-field names matched.

Short correction smoke:

- RunId: `stage24-chat-s02-s03-20260623-correction-smoke2`.
- Scope: both rows, `SmokeSeconds 3`, `DistinctPrefixes 4` for speed. The
  default runner value remains `64`.
- S02 result: comparison `PASS`, leak scan `PASS`; native `PASS` with 12
  requests, hybrid `PASS` with 8 requests, redacted evidence available, cold
  budget `PASS`.
- S03 result: comparison `PASS`, leak scan `PASS`; native `PASS` with 9
  requests, hybrid `PASS` with 7 requests, redacted evidence available, cold
  budget `PASS`.
- Earlier 60 second smoke status remains visible: S02 hybrid had
  `FAIL-http-request` after repeated request connection closures, while S03
  passed. This correction does not reclassify that evidence.

## Handoff

Implementation review can check the runner contract, corrected leak-scan
ordering, dry-run evidence, parser evidence, and smoke artifacts. The S02 hybrid
60 second smoke failure is preserved for Manager/Architect disposition before QA
final execution; no product code was changed under this task.
