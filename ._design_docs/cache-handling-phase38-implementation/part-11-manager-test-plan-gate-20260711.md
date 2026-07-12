# Stage 38 Manager test-plan gate

Source: [../cache-handling-phase38-implementation.md](../cache-handling-phase38-implementation.md)

Date: 2026-07-11
Owner: Manager
Gate: Test planning

## Decision

VERDICT: PASS

Architect test-plan re-review
[part 10](part-10-test-plan-re-review-20260711.md) returned PASS after QA
corrected all blocking findings from the first test-plan review
([part 09](part-09-test-plan-review-20260711.md)).

## Gate evidence checked

| Item | Result | Evidence |
| --- | --- | --- |
| Current Stage 38 scope | PASS | Part 42 covers chat strict-prefix partial restore and D36-FU-01 cold-budget gauge only. `/completion` strict-prefix restore remains recompute-only. |
| F38-TP-01 closed | PASS | Stage 38 script extracts `timings.cache_n`, requires it equals `usage.prompt_tokens_details.cached_tokens`, and reports both values; part 10 CLOSED. |
| F38-TP-02 closed | PASS | Stage 38 script proves full public `usage.prompt_tokens` through `/apply-template` plus `/tokenize`; part 42, README, and part 08 match this evidence strength; part 10 CLOSED. |
| F38-TP-03 closed | PASS | Script README `Last updated` is `2026-07-11`; part 10 CLOSED. |
| TP-38 row coverage | PASS | TP-38-PR-01 through TP-38-PR-10 and TP-38-MET-01/02 have named focused or live evidence paths. |
| Clean-build and stale-binary rule | PASS | Part 42 requires a clean Release build; script refuses stale `llama-server.exe` older than 10 minutes. |
| Evidence format | PASS | Script writes plain `PASS`, `FAIL`, and `BLOCKED` rows plus raw request, response, metrics, template, and tokenization artifacts under non-durable run root. |
| ASCII/status hygiene | PASS | Stage 38 additions use plain ASCII status labels and no unicode status icons. |
| Review loop | PASS | Initial REWORK in part 9, QA correction in part 8, Architect re-review PASS in part 10. |
| No commits, pushes, staging, reverts | PASS | All Stage 38 work remains uncommitted per repo instruction. |

## Authorized QA execution scope

QA may start a fresh execution session. Minimum evidence:

- clean Release configure/build for `llama-server` and `test-cache-controller`;
- focused controller execution for all Stage 38 unit rows;
- `ctest --test-dir build -C Release -R cache --output-on-failure`;
- Python cache-mode metric/schema regression if required by the active plan;
- model-backed Stage 38 script:

```powershell
pwsh -NoProfile -File ._design_docs\cache-handling-test-scripts\stage38-prefix-restore-and-cold-budget.ps1 `
    -ModelPath <GGUF path> `
    -LlamaServerPath build\bin\Release\llama-server.exe `
    -RunRoot ._test_output\stage38-prefix-restore-YYYYMMDD-NN `
    -ReportPath ._design_docs\.test_reports\test-report-YYYYMMDD-NN-stage38.md `
    -ColdBudgetMiB 2048
```

The full report must record dirty working-tree status, build commands, binary
paths and timestamps, model path, exact commands, per-row outcomes, raw artifact
locations, and any `PASS`, `FAIL`, `SKIP`, or `BLOCKED` counts.

## Next gate

Test-planning loop exits. Next gate is **Test execution**.

Next owner: **QA**. QA must run the full Stage 38 test suite in a fresh session
and create a new report under `._design_docs/.test_reports/`.
