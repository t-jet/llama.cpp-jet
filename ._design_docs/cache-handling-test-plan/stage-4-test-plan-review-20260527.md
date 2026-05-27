# Stage 4 test-plan review: 2026-05-27

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Scope

Gate: Test-plan review.

Reviewed:

- `._design_docs/cache-handling-test-plan.md`
- `._design_docs/cache-handling-test-plan/part-01-implemented-scope-and-exclusions.md`
- `._design_docs/cache-handling-test-plan/part-02-current-automated-coverage.md`
- `._design_docs/cache-handling-test-plan/part-03-integration-test-matrix.md`
- `._design_docs/cache-handling-test-plan/part-04-edge-and-negative-scenarios.md`
- `._design_docs/cache-handling-test-plan/part-05-runner-and-evidence-format.md`
- `._design_docs/cache-handling-test-plan/part-06-stress-tests-and-acceptance.md`
- `._design_docs/cache-handling-test-plan/part-07-test-report-quality-and-templates.md`
- `._design_docs/cache-handling-test-scripts/README.md`
- `._design_docs/cache-handling-test-scripts/execute_tests.ps1`
- `._design_docs/cache-handling-test-scripts/run_cache_integration.ps1`
- Stage 4 design and implementation docs listed from `._design_docs/document-index.md`

Full integration tests were not run. This review used document inspection, script inspection, line-count checks, ASCII checks, and PowerShell parser checks.

## Verdict

PASS.

The Stage 4 test plan is generic, current after the corrections below, executable, and within the document size rules. It requires a clean build, uses fresh `test-report-YYYYMMDD-NN.md` reports, uses ASCII status labels, and covers the Stage 4 acceptance areas: resident payload budgeting, deterministic LRU recency, successful and failed restore recency, equivalent refresh budget enforcement, protected priority and fallback, protected admission rejection, metrics, legacy compatibility, and evidence format.

## Findings

### F1: Scripted Stage 4 coverage was overstated

Status: fixed during review.

`part-06-stress-tests-and-acceptance.md` said the implemented test suite covered H30-H39, but `execute_tests.ps1` does not contain H30-H39 test IDs. That could let a future execution report mark Stage 4 `PASS` from unrelated H-series requests.

Corrections made:

- `part-06-stress-tests-and-acceptance.md` now distinguishes current scripted coverage from the Stage 4 acceptance matrix.
- `part-06-stress-tests-and-acceptance.md` now says H30-H39 require the Stage 4 evidence from Part 5 before a report may mark them `PASS`.
- `cache-handling-test-scripts/README.md` now says the runner does not implement the full H30-H39 matrix.

### F2: Model override status was stale

Status: fixed during review.

`part-06-stress-tests-and-acceptance.md` listed environment model override as a future enhancement, but `run_cache_integration.ps1` already uses `LLAMA_CACHE_TEST_MODEL` when `-Model` is not provided. `part-05-runner-and-evidence-format.md` also described `$Model` as hardcoded.

Corrections made:

- Removed the stale future-enhancement bullet.
- Updated the runner configuration text to document the `-Model`, `LLAMA_CACHE_TEST_MODEL`, and fallback path order.

## Coverage check

PASS:

- Generic plan wording: the plan points to `document-index.md` for current implementation state and does not depend on a specific prior run.
- Document size: entry file and part files are all under 300 lines.
- ASCII status labels: plan, README, and reviewed scripts use `PASS`, `FAIL`, `SKIP`, and `BLOCKED`; no unicode status icons were found.
- Clean build rule: the plan requires a clean build before execution; the runner also rejects missing or stale binaries older than 10 minutes.
- Fresh report rule: the runner creates the next available `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`.
- Stage 4 budget design: the plan requires measured resident payload size and integer MiB `--cache-ram` budgets.
- Stage 4 matrix: H30-H39 cover resident payload bytes, LRU, restore recency, failed restore recency, equivalent refresh, protected priority, protected fallback, protected rejection, metrics, and legacy compatibility.
- Evidence format: Part 5 and Part 7 require command, request, response, metric, log, environment, build, model, and result evidence.
- Script syntax: `execute_tests.ps1` and `run_cache_integration.ps1` parse successfully.

Residual note:

- Full H30-H39 automation is still incomplete. This is not a test-plan review blocker after the correction because the plan now requires focused/manual or stats-capable evidence before those rows can pass.

## Commands run

```powershell
Get-Content -Raw .agents/skills/self-improvement/SKILL.md
Get-Content -Raw .agents/skills/self-improvement/assets/qa.md
Get-Content -Raw .agents/skills/qa/SKILL.md
Get-Content -Raw .agents/skills/humanizer/SKILL.md
Get-Content -Raw ._design_docs/document-index.md
rg --files ._design_docs | rg "(stage-4|Stage-4|cache-handling-test-plan|cache-handling-test-scripts|implementation|design)"
Get-ChildItem -Force ._design_docs/cache-handling-test-plan
Get-ChildItem -Force ._design_docs/cache-handling-test-scripts
Get-Content -Raw ._design_docs/cache-handling-test-plan.md
Get-Content -Raw ._design_docs/cache-handling-test-scripts/README.md
Get-Content -Raw ._design_docs/cache-handling-phase4-design.md
Get-Content -Raw ._design_docs/cache-handling-phase4-implementation.md
Get-Content -Raw ._design_docs/cache-handling-test-plan/part-01-implemented-scope-and-exclusions.md
Get-Content -Raw ._design_docs/cache-handling-test-plan/part-02-current-automated-coverage.md
Get-Content -Raw ._design_docs/cache-handling-test-plan/part-03-integration-test-matrix.md
Get-Content -Raw ._design_docs/cache-handling-test-plan/part-04-edge-and-negative-scenarios.md
Get-Content -Raw ._design_docs/cache-handling-test-plan/part-05-runner-and-evidence-format.md
Get-Content -Raw ._design_docs/cache-handling-test-plan/part-06-stress-tests-and-acceptance.md
Get-Content -Raw ._design_docs/cache-handling-test-plan/part-07-test-report-quality-and-templates.md
Get-Content -Raw ._design_docs/cache-handling-phase4-design/part-02-policy-and-interfaces.md
Get-Content -Raw ._design_docs/cache-handling-phase4-design/part-03-protected-root-budget-behavior.md
Get-Content -Raw ._design_docs/cache-handling-phase4-design/part-04-observability-and-metrics.md
Get-Content -Raw ._design_docs/cache-handling-phase4-design/part-05-testability-and-requirement-traceability.md
Get-Content -Raw ._design_docs/cache-handling-phase4-implementation/part-06-review-fixes.md
Get-Content -Raw ._design_docs/cache-handling-phase4-implementation/part-07-implementation-re-review.md
Select-String -Path ._design_docs/cache-handling-test-scripts/execute_tests.ps1 -Pattern "param|LLAMA_CACHE_TEST_MODEL|SkipBuild|IncludeDraft|IncludeStress|test-report|LastWriteTime|cache-ram|H30|H31|H32|H33|H34|H35|H36|H37|H38|H39|protected|payload|restore_failures" -Context 1,2
Select-String -Path ._design_docs/cache-handling-test-scripts/run_cache_integration.ps1 -Pattern "param|LLAMA_CACHE_TEST_MODEL|test-report|LastWriteTime|cache-ram|protected|payload|Get-CacheMetrics|llamacpp_cache" -Context 1,2
[System.Management.Automation.Language.Parser]::ParseFile(...)
rg -n "[unicode/status search and test-plan terms]" ._design_docs/cache-handling-test-plan.md ._design_docs/cache-handling-test-plan ._design_docs/cache-handling-test-scripts/README.md ._design_docs/cache-handling-test-scripts/execute_tests.ps1 ._design_docs/cache-handling-test-scripts/run_cache_integration.ps1
rg -n "# Test H3[0-9]|TestId ""H3[0-9]""|H3[0-9]" ._design_docs/cache-handling-test-scripts/execute_tests.ps1 ._design_docs/cache-handling-test-plan ._design_docs/cache-handling-test-scripts/README.md
git status --short
```

Two exploratory `rg` commands had quoting mistakes and returned regex parse errors before the corrected searches above were run. No integration tests were run.

## Changed paths

- `._design_docs/cache-handling-test-plan.md`
- `._design_docs/cache-handling-test-plan/part-05-runner-and-evidence-format.md`
- `._design_docs/cache-handling-test-plan/part-06-stress-tests-and-acceptance.md`
- `._design_docs/cache-handling-test-plan/stage-4-test-plan-review-20260527.md`
- `._design_docs/cache-handling-test-scripts/README.md`

## Handoff

Status: ready.

Next QA execution should start with a clean build, create a fresh `test-report-YYYYMMDD-NN.md`, and treat H30-H39 as passing only when the report contains the required Stage 4 evidence.
