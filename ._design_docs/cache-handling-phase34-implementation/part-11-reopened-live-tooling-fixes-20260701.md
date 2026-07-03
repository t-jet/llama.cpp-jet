# Stage 34 reopened live-tooling fixes 2026-07-01

Status: Developer tooling fix complete; Stage 34 remains open
Owner: Developer
Scope: reopened live replay tooling only

## Trigger

Stage 34 was reopened after live replay evidence showed two tooling gaps:

- response failures and null response bodies collapsed into plain `cache_n=0`
- a 100 MiB live run predicted exact hits even when large prompt saves exceeded
  the configured hot budget

This part records the narrow tool fixes. No production code changed, and this
does not close Stage 34.

## Fixes

Changed files:

- `._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1`
- `._design_docs/cache-handling-test-scripts/analyze-stage34-expected-hits.ps1`
- `._design_docs/cache-handling-test-scripts/lib/stage34-result-analyzer.ps1`
- `tests/test-stage34-result-analyzer.py`

Behavior changes:

- replay responses now carry `replay_order` and `completion_order`; concurrent
  output is written in replay order while preserving completion order evidence
- concurrent job waits use a bounded throttle of at least one and pass an array
  of jobs to `Wait-Job`
- result joining reports `http_status`, `response_present`, and `error`, and
  separates `FAIL-http`, `FAIL-null-response`, and `FAIL-cache-miss`
- expected-hit analysis accepts `-EstimatedPayloadMiBPerToken`; when the
  estimated payload exceeds `-HotBudgetMiB`, exact duplicates are classified as
  `EXPECTED-HOT-BUDGET-SAVE-REJECTED` instead of expected hits
- replay runner passes `-HotBudgetMiB`, `-ColdBudgetMiB`, and
  `-EstimatedPayloadMiBPerToken` through to expected-hit analysis and records
  them in `summary.json`

## Evidence

Commands run:

```powershell
python -m pytest tests/test-stage34-result-analyzer.py -q
```

Result: 4 passed in 0.27s.

```powershell
pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1 -Mode dry-run -OutputDir _test_output/stage34-reopen-developer-dry-run
```

Result: 6 replay events, 1 expected hit row, 0 errors.

```powershell
pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1 -Mode dry-run -OutputDir _test_output/stage34-reopen-budget-smoke -HotBudgetMiB 100 -EstimatedPayloadMiBPerToken 200
```

Result: 6 replay events, 0 expected hit rows, and row 3 carries
`EXPECTED-HOT-BUDGET-SAVE-REJECTED`.

```powershell
pwsh -NoProfile -Command <synthetic Join-Stage34ReplayResults smoke>
```

Result: one row `PASS` with `cache_n=9`; one row `FAIL-null-response` with
`http_status=200` and `response_present=false`.

```powershell
git diff --check -- ._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1 ._design_docs/cache-handling-test-scripts/analyze-stage34-expected-hits.ps1 ._design_docs/cache-handling-test-scripts/lib/stage34-result-analyzer.ps1 tests/test-stage34-result-analyzer.py
```

Result: exit code 0, no output. These Stage 34 script/test paths are currently
untracked, so a direct trailing-whitespace scan was also run and found no hits.

## Remaining state

No product bug was found. The fixed bugs are test-tooling issues in live replay
classification and result evidence.

Stage 34 remains reopened for Manager-owned live execution and review.
