# QA improvement memory

## Improvement: scan split-plan siblings

Condition:
- When updating a split QA plan with part files

Action:
- Do scan the whole part directory for stale duplicate or unlinked files, not only the files linked by the entry document; remove obsolete duplicates rather than leaving conflicting test guidance beside the active plan.

## Improvement: verify automation coverage claims

Condition:
- When reviewing a QA plan that claims scripted coverage for named test IDs, broad scenario ranges, or negative-test ranges

Action:
- Do search the runner scripts and focused test sources for those exact IDs or required behaviors, compare the implemented assertions with the plan, and split public-harness coverage from acceptance rows that need focused, draft-fixture, stats-capable, or fault-injection evidence; map every PASS claim to specific test names or source lines, and update runner PASS/BLOCKED logic only when the current task requires automation changes.

## Improvement: reconcile runner summaries with evidence

Condition:
- When a test runner emits conflicting console output, exit codes, generated reports, skip/fail summaries, blank/UNKNOWN rows, or inflated totals

Action:
- Do inspect the generated report and raw logs, rerun narrow direct checks for disputed cases or truncated startup logs when possible, count only real test rows, and base final PASS/FAIL/SKIP/BLOCKED counts on verified evidence rather than the runner exit code or summary alone.

## Improvement: suppress PowerShell helper output

Condition:
- When adding or editing PowerShell QA harness functions that build result arrays or markdown reports

Action:
- Do suppress non-result command output from cleanup helpers and HTTP request helpers with assignment, filtering, or `[void]`; otherwise stray return values can become blank or malformed report rows.

## Improvement: validate generated markdown reports

Condition:
- When a PowerShell QA runner generates markdown with fenced command or evidence blocks

Action:
- Do inspect the generated report before accepting the run, and use markdown fences that PowerShell will not escape inside expandable strings, such as tildes or doubled backticks.

## Improvement: keep report suffixes chronological

Condition:
- When creating a fresh per-session QA report in a directory that already has same-day reports

Action:
- Do assign the next suffix after the highest existing same-day report, not the first missing gap, so the newest report is also the lexically latest handoff artifact.

## Improvement: check async test timing after fixing disabled assertions

Condition:
- When a TEST_ASSERT or similar fix re-enables previously disabled assertions in async tests that call process_completions after demote_payload or promote_payload

Action:
- Do verify that each async test includes a sleep_for before process_completions; previously masked race conditions become visible when assertions start working; run both Debug and Release to confirm the failure is not configuration-specific; classify the failure as a test bug, not a product bug, and hand off to Developer for a targeted sleep_for addition.

## Improvement: reserve report artifacts under final suffix

Condition:
- When a QA execution session will create ad hoc artifact directories and may also run scripts that generate their own reports

Action:
- Do decide the final session report suffix before collecting ad hoc artifacts, and store those artifacts under a path named for that final report so evidence links do not point at a different report number.

## Improvement: separate plan updates from product handoffs

Condition:
- When a QA planning task uncovers a product-code prerequisite or incompatibility that would block planned rows

Action:
- Do leave product code untouched, make the planned expectation explicit, and record a Developer handoff with the verified source evidence instead of weakening or omitting the blocked QA scenario.

## Improvement: classify startup-only mode failures

Condition:
- When a public model-mode QA row cannot reach `/health` before cache behavior is observable

Action:
- Do classify the row as `BLOCKED` for cache acceptance, preserve startup logs and exit codes, and create a separate bug handoff when the process crashes or exits without a clear unsupported-mode diagnostic.

## Improvement: discard stale harness flag failures

Condition:
- When a QA execution uses plan default server flags and startup fails before model loading with an invalid-argument error

Action:
- Do treat that attempt as a harness setup error, remove or correct only the unsupported flag, rerun the same row, and base the row outcome on the rerun rather than the stale default failure.

## Improvement: avoid automatic-variable names in PowerShell harnesses

Condition:
- When writing or running inline PowerShell QA helpers that pass CLI arguments to a server process

Action:
- Don't use parameter or variable names that collide with PowerShell automatic variables such as `Args`; use explicit names like `ServerArgs`, preserve the discarded harness logs if a collision starts the wrong mode, and rerun before classifying product behavior.

## Improvement: verify Release-mode assertions in focused C++ tests

Condition:

- When running focused C++ tests in Release configuration where `NDEBUG` is defined

Action:

- Do check that `#undef NDEBUG` appears before `#include <cassert>` in every test file, not after; if assertions are silently disabled, a Release-only crash may mask a real product bug or test infrastructure bug; run the Debug build as a cross-check and classify Release-only crashes as test infrastructure defects requiring Developer investigation before marking the test step as PASS.

## Improvement: verify markdown constraints after QA doc edits

Condition:
- When editing reusable QA markdown that must stay under repository line-count, ASCII, and whitespace rules

Action:
- Do check initial line counts before editing near-limit QA docs, keep additions within the remaining line budget, then rerun line-count, ASCII-byte, whitespace, link, and diff-shape checks on every touched markdown file before final handoff, including new untracked part files that `git diff --check` will not inspect; preserve existing line endings where practical, and if a tool changes them, normalize deliberately and rerun `git diff --check`.

## Improvement: separate own QA edits from dirty sources

Condition:
- When a QA review task uses or indexes documents that are already modified or untracked in the working tree

Action:
- Do check `git status --short` for the reviewed and edited paths, distinguish pre-existing plan/source changes from files changed in the review, and report only the review-owned edits as your own handoff changes.

## Improvement: wait for model-specific readiness in public probes

Condition:
- When a public HTTP harness starts `llama-server` with secondary model resources such as draft, MTP, multimodal, or adapter fixtures

Action:
- Do treat `/health` as process readiness only; wait for a model-specific log marker when the build emits one, or make the first behavior request a guarded readiness/admission probe and require direct secondary-resource evidence such as `draft_n > 0` before accepting later restore or hit claims; preserve marker-less setup attempts separately from product evidence, and keep startup log verbosity low unless diagnostics require it.

## Improvement: classify available fixture no-evidence runs

Condition:
- When a suitable model-backed fixture is available and the public probe starts successfully but the expected cache-specific counters, timings, or checkpoint rows remain at zero or placeholder values

Action:
- Do classify the fixture row as FAIL rather than fixture-unavailable BLOCKED/SKIP, preserve request, response, metrics, and startup artifacts, and separately note any focused substitute evidence that still passed.

## Improvement: prove public checkpoint admission before restore claims

Condition:
- When a public checkpoint-dependent probe or regression row needs a long prompt, small batch size, checkpoint-capable fixture, or boundary metadata to exercise checkpoint restore or public checkpoint metrics

Action:
- Do first prove the request fits the context and increments accepted checkpoint admission; if the run only creates live checkpoints, lacks a fixture attempt, fails admission, or returns a request-shape error, preserve it as setup or blocker evidence and classify public checkpoint restore/hit/metrics rows as BLOCKED/SKIP even when focused checkpoint substitute evidence passes.

## Improvement: check coverage denominator composition before redesigning

Condition:
- When a coverage run reports a combined rate far below the threshold (e.g., 21% vs 80%)

Action:
- Do inspect the denominator file list and compute each file's share of total valid lines; if a non-target file accounts for more than 20% of total valid lines and receives less than 10% coverage from focused tests, it is misclassified and must be removed from the denominator before concluding the approach is broken.
- Do use OpenCppCoverage binary `.cov` export per run and merge with `--input_coverage` for union coverage; summing separate Cobertura XML line counts across test runs double-counts shared code and does not produce union coverage.
- Do include the server HTTP probe in the coverage measurement when target files contain server integration paths that focused tests cannot reach.

## Improvement: load required memory before status updates

Condition:
- When a task requires self-improvement memory to be read before any other action

Action:
- Do read the skill and agent memory before sending any acknowledgement, skill announcement, status update, task analysis, or parallel tool call; treat every user-visible reply and all task-specific file inspection as task action.

## Improvement: keep evidence blockers out of reusable plans

Condition:
- When creating or updating reusable QA plans after implementation evidence reports local tool, dependency, fixture, coverage, or benchmark blockers

Action:
- Do carry those blockers forward as setup and evidence requirements for the future execution report; don't convert missing tools, dependencies, model fixtures, coverage output, or benchmark output into accepted skips in the long-lived test plan.

## Improvement: reconcile gate status across reviewed docs

Condition:
- When a QA test-plan review includes doc hygiene checks and one of the reviewed gate documents has stale stage status

Action:
- Do update the stale gate status when it is within the requested documentation scope, cite the source gate that proves the current state, and record the hygiene correction in the review report instead of leaving conflicting readiness signals for the next owner.

## Improvement: verify create_file path against near-duplicate dir names

Condition:
- When using `create_file` on a path under a dot-prefixed dir in a workspace that also has a non-dot-prefixed sibling

Action:
- Don't trust the silent creation in the expected path; PowerShell tools resolve the unprefixed name to the sibling dir. After `create_file`, verify with `Get-ChildItem -Path` using the full dot-prefix; if the file landed in the sibling, `Move-Item -Force` it back.

## Improvement: avoid markdown lint breakage from long shell commands in table cells

Condition:
- When a QA report places a long shell command containing unescaped `|` (pipe) alternation or shell metacharacters into a markdown table cell

Action:

- Do put verbatim long commands in a fenced code block under a `### Long-form commands` subsection, and keep only short summaries in the table cells; markdown table parsers count unescaped `|` as column separators and emit MD056/MD060 lint errors, while MD012 catches the resulting blank-line clutter.
- Do check the generated report with `get_errors` for the touched markdown files before handoff, and fix MD024 duplicate headings by making the heading text unique per section.

## Improvement: regenerate buggy parser output in the same session as the parent report

Condition:

- When a downstream artifact (such as `evidence-summary.md`, `coverage-report.md`, or similar) has a parser/aggregation bug that the main QA report cites

Action:

- Do regenerate the buggy artifact in the same QA session and add a `## Correction` section at the top noting the original parsing bug and the regeneration context; cite the parent report and the fixes handoff so the lineage is clear in the artifacts bundle.

## Improvement: verify working tree after `git rm -r` and handle mixed tracked/untracked artifact folders

Condition:

- When removing a set of artifact folders from the repo and some are git-tracked while others are untracked (e.g. generated in the current session and never committed)

Action:

- Do run `git ls-files` per folder first to classify tracked vs untracked; use `git rm -r` for tracked folders and `Remove-Item -Recurse -Force` for untracked ones, rather than assuming one tool covers both.
- Do verify with `Get-ChildItem -Directory` and `git status --short` after `git rm -r --quiet` exits 0 that both the working tree is empty and the index shows the expected staged-deletion count (lines beginning with `D`); on Windows + PowerShell the index can be updated while files linger on disk, so trust `Get-ChildItem` and `git status`, not just the exit code.
- Do keep all `.md` test reports in `._design_docs/.test_reports/` intact during cleanup; only remove the `-artifacts`, `-developer-artifacts`, and ad-hoc evidence folders (such as `coverage-run/`), and verify the `.md` count before and after to confirm no report was lost.
