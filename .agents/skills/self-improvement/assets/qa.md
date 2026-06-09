# QA improvement memory

## Improvement: scan split-plan siblings

Condition:
- Updating split QA plan with part files

Action:
- Scan whole part directory for stale duplicate or unlinked files, not only files linked by entry document. Remove obsolete duplicates rather than leaving conflicting test guidance beside active plan.

## Improvement: verify automation coverage claims

Condition:
- Reviewing QA plan that claims scripted coverage for named test IDs, broad scenario ranges, or negative-test ranges

Action:
- Search runner scripts and focused test sources for those exact IDs or required behaviors. Compare implemented assertions with plan. Split public-harness coverage from acceptance rows needing focused, draft-fixture, stats-capable, or fault-injection evidence. Map every PASS claim to specific test names or source lines. Update runner PASS/BLOCKED logic only when current task requires automation changes.

## Improvement: reconcile runner summaries with evidence

Condition:
- Test runner emits conflicting console output, exit codes, generated reports, skip/fail summaries, blank/UNKNOWN rows, or inflated totals

Action:
- Inspect generated report and raw logs. Rerun narrow direct checks for disputed cases or truncated startup logs when possible. Count only real test rows. Base final PASS/FAIL/SKIP/BLOCKED counts on verified evidence rather than runner exit code or summary alone.

## Improvement: suppress PowerShell helper output

Condition:
- Adding or editing PowerShell QA harness functions that build result arrays or markdown reports

Action:
- Suppress non-result command output from cleanup helpers and HTTP request helpers with assignment, filtering, or `[void]`; otherwise stray return values can become blank or malformed report rows.

## Improvement: validate generated markdown reports

Condition:
- PowerShell QA runner generates markdown with fenced command or evidence blocks

Action:
- Inspect generated report before accepting run. Use markdown fences PowerShell will not escape inside expandable strings, such as tildes or doubled backticks.

## Improvement: keep report suffixes chronological

Condition:
- Creating fresh per-session QA report in directory that already has same-day reports

Action:
- Assign next suffix after highest existing same-day report, not first missing gap, so newest report is also lexically latest handoff artifact.

## Improvement: check async test timing after fixing disabled assertions

Condition:
- TEST_ASSERT or similar fix re-enables previously disabled assertions in async tests that call process_completions after demote_payload or promote_payload

Action:
- Verify each async test includes sleep_for before process_completions. Previously masked race conditions become visible when assertions start working. Run both Debug and Release to confirm failure is not configuration-specific. Classify failure as test bug, not product bug, and hand off to Developer for targeted sleep_for addition.

## Improvement: reserve report artifacts under final suffix

Condition:
- QA execution session will create ad hoc artifact directories and may also run scripts that generate their own reports

Action:
- Decide final session report suffix before collecting ad hoc artifacts. Store artifacts under path named for that final report so evidence links do not point at different report number.

## Improvement: separate plan updates from product handoffs

Condition:
- QA planning task uncovers product-code prerequisite or incompatibility that would block planned rows

Action:
- Leave product code untouched. Make planned expectation explicit. Record Developer handoff with verified source evidence instead of weakening or omitting blocked QA scenario.

## Improvement: classify startup-only mode failures

Condition:
- Public model-mode QA row cannot reach `/health` before cache behavior is observable

Action:
- Classify row as `BLOCKED` for cache acceptance. Preserve startup logs and exit codes. Create separate bug handoff when process crashes or exits without clear unsupported-mode diagnostic.

## Improvement: discard stale harness flag failures

Condition:
- QA execution uses plan default server flags and startup fails before model loading with invalid-argument error

Action:
- Treat that attempt as harness setup error. Remove or correct only unsupported flag. Rerun same row. Base row outcome on rerun rather than stale default failure.

## Improvement: avoid automatic-variable names in PowerShell harnesses

Condition:
- Writing or running inline PowerShell QA helpers that pass CLI arguments to server process

Action:
- Don't use parameter or variable names that collide with PowerShell automatic variables such as `Args`. Use explicit names like `ServerArgs`. Preserve discarded harness logs if collision starts wrong mode. Rerun before classifying product behavior.

## Improvement: verify Release-mode assertions in focused C++ tests

Condition:
- Running focused C++ tests in Release configuration where `NDEBUG` is defined

Action:
- Check that `#undef NDEBUG` appears before `#include <cassert>` in every test file, not after. If assertions are silently disabled, Release-only crash may mask real product bug or test infrastructure bug. Run Debug build as cross-check. Classify Release-only crashes as test infrastructure defects requiring Developer investigation before marking test step as PASS.

## Improvement: verify markdown constraints after QA doc edits

Condition:
- Editing reusable QA markdown that must stay under repo line-count, ASCII, and whitespace rules

Action:
- Check initial line counts before editing near-limit QA docs. Keep additions within remaining line budget. Rerun line-count, ASCII-byte, whitespace, link, and diff-shape checks on every touched markdown file before final handoff, including new untracked part files that `git diff --check` will not inspect. Preserve existing line endings where practical; if tool changes them, normalize deliberately and rerun `git diff --check`.

## Improvement: separate own QA edits from dirty sources

Condition:
- QA review task uses or indexes documents that are already modified or untracked in working tree

Action:
- Check `git status --short` for reviewed and edited paths. Distinguish pre-existing plan/source changes from files changed in review. Report only review-owned edits as own handoff changes.

## Improvement: wait for model-specific readiness in public probes

Condition:
- Public HTTP harness starts `llama-server` with secondary model resources such as draft, MTP, multimodal, or adapter fixtures

Action:
- Treat `/health` as process readiness only. Wait for model-specific log marker when build emits one, or make first behavior request guarded readiness/admission probe. Require direct secondary-resource evidence such as `draft_n > 0` before accepting later restore or hit claims. Preserve marker-less setup attempts separately from product evidence. Keep startup log verbosity low unless diagnostics require it.

## Improvement: classify available fixture no-evidence runs

Condition:
- Suitable model-backed fixture is available and public probe starts successfully but expected cache-specific counters, timings, or checkpoint rows remain at zero or placeholder values

Action:
- Classify fixture row as FAIL rather than fixture-unavailable BLOCKED/SKIP. Preserve request, response, metrics, and startup artifacts. Separately note any focused substitute evidence that still passed.

## Improvement: prove public checkpoint admission before restore claims

Condition:
- Public checkpoint-dependent probe or regression row needs long prompt, small batch size, checkpoint-capable fixture, or boundary metadata to exercise checkpoint restore or public checkpoint metrics

Action:
- First prove request fits context and increments accepted checkpoint admission. If run only creates live checkpoints, lacks fixture attempt, fails admission, or returns request-shape error, preserve as setup or blocker evidence and classify public checkpoint restore/hit/metrics rows as BLOCKED/SKIP even when focused checkpoint substitute evidence passes.

## Improvement: check coverage denominator composition before redesigning

Condition:
- Coverage run reports combined rate far below threshold (e.g., 21% vs 80%)

Action:
- Inspect denominator file list and compute each file's share of total valid lines. If non-target file accounts for more than 20% of total valid lines and receives less than 10% coverage from focused tests, it is misclassified and must be removed from denominator before concluding approach is broken.
- Use OpenCppCoverage binary `.cov` export per run and merge with `--input_coverage` for union coverage; summing separate Cobertura XML line counts across test runs double-counts shared code and does not produce union coverage.
- Include server HTTP probe in coverage measurement when target files contain server integration paths that focused tests cannot reach.

## Improvement: load required memory before status updates

Condition:
- Task requires self-improvement memory to be read before any other action

Action:
- Read skill and agent memory before sending any acknowledgement, skill announcement, status update, task analysis, or parallel tool call. Treat every user-visible reply and all task-specific file inspection as task action.

## Improvement: keep evidence blockers out of reusable plans

Condition:
- Creating or updating reusable QA plans after implementation evidence reports local tool, dependency, fixture, coverage, or benchmark blockers

Action:
- Carry those blockers forward as setup and evidence requirements for future execution report. Don't convert missing tools, dependencies, model fixtures, coverage output, or benchmark output into accepted skips in long-lived test plan.

## Improvement: reconcile gate status across reviewed docs

Condition:
- QA test-plan review includes doc hygiene checks and one of reviewed gate documents has stale stage status

Action:
- Update stale gate status when within requested documentation scope. Cite source gate that proves current state. Record hygiene correction in review report instead of leaving conflicting readiness signals for next owner.

## Improvement: verify create_file path against near-duplicate dir names

Condition:
- Using `create_file` on path under dot-prefixed dir in workspace that also has non-dot-prefixed sibling

Action:
- Don't trust silent creation in expected path; PowerShell tools resolve unprefixed name to sibling dir. After `create_file`, verify with `Get-ChildItem -Path` using full dot-prefix. If file landed in sibling, `Move-Item -Force` it back.

## Improvement: avoid markdown lint breakage from long shell commands in table cells

Condition:
- QA report places long shell command containing unescaped `|` (pipe) alternation or shell metacharacters into markdown table cell

Action:
- Put verbatim long commands in fenced code block under `### Long-form commands` subsection. Keep only short summaries in table cells; markdown table parsers count unescaped `|` as column separators and emit MD056/MD060 lint errors, while MD012 catches resulting blank-line clutter.
- Check generated report with `get_errors` for touched markdown files before handoff. Fix MD024 duplicate headings by making heading text unique per section.

## Improvement: use absolute paths for PowerShell log output when Push-Location changes CWD

Condition:
- PowerShell QA harness captures command output to log file via `Out-File -FilePath` or `Tee-Object` and uses `Push-Location` / `Set-Location` to change working directory before running binary

Action:
- Use absolute path for log file (e.g., `D:\...\._design_docs\.test_reports\foo.log`) rather than relative path. Relative paths resolve against new CWD after `Push-Location`, causing file to be written under non-existent subdir and producing path-not-found error while underlying command still runs.

## Improvement: detect custom test framework before applying gtest filter

Condition:
- QA task instruction references gtest filter flag (e.g., `--gtest_filter='*substring*'`) for focused test run

Action:
- Inspect test source file (e.g., `grep main()` and check for `TEST(` / `TEST_F(` macros) before running with gtest filter. If runner is custom printf/assert harness with own `main()` that calls each test function sequentially, gtest filter is silently ignored and full suite runs anyway. Run full binary, capture full output, and grep log for focused test names to extract per-test verdicts.

## Improvement: re-execution session binary freshness vs content correctness

Condition:
- QA test plan's Section 2 freshness check (e.g., `if ($BuildAge.TotalMinutes -gt 10) { throw }`) would fail at re-execution time because source files are unchanged since prior canonical build cited by plan

Action:
- Don't abort run on stale binary timestamp alone. Verify content correctness by checking corresponding `.obj` file timestamp matches cited canonical build log. Document in test report that no-op rebuild confirmed content correctness from prior cited build. Leave freshness-check policy decision to Developer/Manager and record override with evidence (obj timestamp + producer log path).

## Improvement: distinguish pre-existing from new observability lines in function body

Condition:
- Test plan's observability check requires that fix adds zero new `GGML_LOG` / `GGML_ASSERT` / `SRV_DBG` lines, and function being checked already contains pre-existing assert on its first body line

Action:
- Run both function-body regex scan AND `git show HEAD -- <file> | Select-String <pattern>` to confirm zero diff hits. Report function-body hits as "1 pre-existing (unchanged at HEAD)" and diff hits as "0 added". Cite producer log (e.g., `part-25 ## Diff evidence`: 19 insertions, 0 deletions) as authoritative source.

## Improvement: clean-build before any test on a new merge tree

Condition:
- QA session must run closure contracts on freshly-produced real two-parent merge commit, especially when prior closures were based on single-parent commit or non-merged tree

Action:
- Do full clean build (reconfigure, remove coverage dir, rebuild every target test plan needs) as very first action, before any ctest, pytest, HTTP probe, coverage run, k6 run, or closure-contract measurement. Don't accept prior Developer's incremental `cmake --build` pass as clean build. Don't trust prior closure numbers measured on different tree.
- When clean build fails on semantic conflict git's 3-way merge did not flag (e.g. duplicate `const bool` declaration added by both parents in same lexical scope), report entire session as BLOCKED with build defect as reason for every row. Don't classify any closure contract row as PASS or FAIL by reference to prior-run numbers. Don't reclassify prior "tooling limitation" closure as current verdict.
- Pair BLOCKED report with Developer fixes file quoting exact error code and lines, identifying which parent commits added duplicate content, and scoping one-line fix. Don't modify durable docs, closure record, implementation log, or `document-index.md` in QA session.

## Improvement: regenerate buggy parser output in same session as parent report

Condition:
- Downstream artifact (e.g. `evidence-summary.md`, `coverage-report.md`, or similar) has parser/aggregation bug that main QA report cites

Action:
- Regenerate buggy artifact in same QA session and add `## Correction` section at top noting original parsing bug and regeneration context. Cite parent report and fixes handoff so lineage is clear in artifacts bundle.

## Improvement: run_coverage.ps1 may fail to produce .cov files via Start-Process

Condition:
- Running `run_coverage.ps1` (or any wrapper calling `OpenCppCoverage.exe` via `Start-Process -ArgumentList $argArray`) and Phase 1 reports `no .cov file produced (exit 0)` for every focused test binary even though test binary ran successfully

Action:
- Don't classify T114/T114a as FAIL based on empty `coverage-merged.xml`. Reproduce per-test `.cov` files with direct invocation passing `--export_type binary:D:\path\file.cov` argument as single string, or run OpenCppCoverage with merged `& $OcPath $argList` form. Bug is in how script's `Start-Process -ArgumentList` array joins colon-prefixed export values; manual form works. Cite both script's empty XML and manually-produced `coverage-report.md` in report so next session can see script bug and validated numbers.
- Pair run with separate follow-up handoff scoping one-line fix to script (e.g. join `--export_type` value into single argument before passing to Start-Process), so next session can either patch script or run manual form.

## Improvement: dedupe OpenCppCoverage merged Cobertura XML by (file, line)

Condition:
- Parsing `OpenCppCoverage.exe --input_coverage A.cov --input_coverage B.cov ... --export_type cobertura:out.xml` output to compute union line coverage

Action:
- Don't assume merged Cobertura XML contains single `<class>` per source file; merge step emits one `<class>` block per input `.cov` file for same source path. Without deduplication, `combined_covered` and `combined_valid` will be roughly N times true value (where N is number of input `.cov` files), yielding falsely-low union rate. Correct parser walks every `<class>` block, groups by basename, and for each (basename, line number) takes max `hits` across duplicates. `combined_covered` then counts lines where max hits > 0; `combined_valid` counts unique line numbers.
- Verify per-file line rate in parsed report against known-good prior run before accepting numbers; if rates diverge by more than 1%, dedup step is wrong.

## Improvement: verify working tree after `git rm -r` and handle mixed tracked/untracked artifact folders

Condition:
- Removing set of artifact folders from repo and some are git-tracked while others are untracked (e.g. generated in current session and never committed)

Action:
- Run `git ls-files` per folder first to classify tracked vs untracked. Use `git rm -r` for tracked folders and `Remove-Item -Recurse -Force` for untracked ones, rather than assuming one tool covers both.
- Verify with `Get-ChildItem -Directory` and `git status --short` after `git rm -r --quiet` exits 0 that both working tree is empty and index shows expected staged-deletion count (lines beginning with `D`); on Windows + PowerShell index can be updated while files linger on disk, so trust `Get-ChildItem` and `git status`, not just exit code.
- Keep all `.md` test reports in `._design_docs/.test_reports/` intact during cleanup. Only remove `-artifacts`, `-developer-artifacts`, and ad-hoc evidence folders (such as `coverage-run/`). Verify `.md` count before and after to confirm no report was lost.

## Improvement: add CUDA bin DLLs to PATH for GGML_CUDA=ON test runs

Condition:
- Running focused C++ test binary built in `GGML_CUDA=ON` build directory (e.g. `build-cuda`, `build-cuda-test`) and binary exits immediately with `0xC0000135` (STATUS_DLL_NOT_FOUND) or returns non-numeric exit code

Action:
- Check binary's DLL dependencies with `dumpbin /dependents <test.exe>` before assuming build or assertion failure; CUDA-linked test binaries depend on `cublas64_13.dll` (CUDA 13.x) or `cublas64_12.dll` (CUDA 12.x) which are not in default `PATH`.
- Prepend CUDA toolkit `bin\x64\` directory to `PATH` (e.g. `$env:PATH = 'D:\app\cuda_13_2\bin\x64;' + $env:PATH`) before invoking test binary; same fix that makes `llama-server.exe` start in CUDA build.
- Record PATH prefix in test report's environment section so next session does not waste time on same DLL diagnostic.

## Improvement: distinguish Release-build coverage gap from Start-Process bug

Condition:
- `run_coverage.ps1` (or direct `OpenCppCoverage.exe` invocation) produces 112-byte or otherwise header-only `.cov` file and merged Cobertura XML reports `0 / 0` lines (or coverage rate is 0%) even though test binary ran to completion and printed PASS summary

Action:
- First check `CMAKE_CXX_FLAGS_RELEASE` in build's `CMakeCache.txt` for presence of `/Zi` or `/DEBUG:FULL`; Release build without debug symbols is most common cause of header-only `.cov` output and is distinct from `Start-Process -ArgumentList` colon-prefixed-export joining bug.
- Classify T114/T114a as `BLOCKED` (not `FAIL`) when build is Release without `/Zi`. Cite exact `CMAKE_CXX_FLAGS_RELEASE` line and 112-byte `.cov` size as evidence. Don't try to redesign coverage denominator or merge logic to compensate.
- Pair BLOCKED with Developer handoff scoping coverage-eligible rebuild (e.g. `RelWithDebInfo` with `/Zi /Ob1 /O2 /EHsc /DEBUG:FULL`, or add `/Zi /DEBUG` to Release flags) so next session can run coverage against patched code.
- Cite prior-run numbers from build with debug symbols (e.g. `test-report-20260604-06.md` T114=0.8553, T114a=0.7035) as reference baseline and note which source files patch touched so reviewer can confirm prior numbers are still representative.

## Improvement: rewrite new markdown with LF endings before git diff --check

Condition:
- QA task creates new markdown file in `._design_docs/...` (or any path `git diff --check` will inspect) using `create_file` or any tool that writes through host PowerShell/Windows file I/O

Action:
- Don't trust file as-written; Windows `create_file` writes CRLF line endings (CR plus LF, bytes 0x0D 0x0A) by default. `git diff --check` flags CR (0x0D) on every line as trailing whitespace, so clean new file fails check with exit 2 and "trailing whitespace" message on every line.
- Rewrite file with LF-only line endings immediately after creation by reading with `[System.IO.File]::ReadAllText` and writing with `[System.IO.File]::WriteAllText` after replacing CR-LF with LF. Verify CR count is 0 and rerun `git diff --check` for exit 0.
- Don't trust `Get-Content` line lengths for this check; PowerShell normalizes on read and hides CR. Read raw bytes with `[System.IO.File]::ReadAllBytes` to confirm.

## Improvement: check which focused test binaries the cmake build target list produces

Condition:
- Test plan's Section 2 `cmake --build` target list names only `llama-server` and one focused test binary (e.g. `test-cache-controller`) and downstream `run_coverage.ps1` Phase 1 step requires 9 focused test binaries from same build directory

Action:
- Don't assume build directory contains all 9 focused test binaries. Check `Get-ChildItem <build>\bin\<Config>\test-*.exe` before running coverage script and classify any missing binary as setup gap, not coverage failure.
- Record in test report's coverage section exactly which binaries were present and which were SKIPPED by script, and whether HTTP probe was skipped (model missing or `-SkipServerProbe`). Don't hide setup gap behind generic BLOCKED verdict.
- Separate per-binary coverage gap (missing `.exe` files) from Release-without-`/Zi` coverage gap; they are independent setup defects and each needs own Developer handoff if both are present.

## Improvement: derive in-flight ETA from cap=NNNs in side log, not from hard-coded default

Condition:
- QA sub-session polls a v3 sequential stress/longrun row that is IN-FLIGHT and the polling block computes ETA cap exit as `start_ts.AddSeconds(<hard-coded default>)` (e.g., 1805) when the side log line for the row already records the authoritative cap, e.g. `start S12-MTP-S01-V1-Jmarked port=8601 cap=2100s`

Action:
- Don't hard-code the cap seconds. Parse `cap=(\d+)s` from the latest `start <row>` line in the side log and compute `start_ts + cap_sec` for ETA. Hard-coded defaults (1805, 1800, 30*60, 35*60) drift from the actual driver cap and produce wrong ETAs in the report. The side log cap is authoritative.
- If the regex match fails, fall back to `now + conservative_remaining` and flag the discrepancy in the sub-session, not silently. Cite the source line in the sub-session so the next QA session can verify the cap value matches the driver.

## Improvement: never use PowerShell -replace with backtick-r or backtick-n in replacement string

Condition:
- QA session needs to remove or add line breaks in a markdown file using PowerShell -replace operator and the replacement string contains `r or `n (or any backtick escape)

Action:
- Do not put `r or `n in the -replace replacement string. The PowerShell -replace operator processes `r as backslash+CR and `n as backslash+LF in the output, leaving the leading and trailing backtick characters in the file. The result is a markdown file with literal backslash chars mixed with CRLF. Confirmed in session 20260608-V1: file grew by 5 bytes, cr=0 became cr=2, and the section break at the substituted position produced bad text. Use [System.IO.File]::ReadAllBytes + a for loop to find and remove the bad bytes directly, or build the replacement using [char]13 + [char]10 concat with [string]::Replace (literal .NET string method) which does not interpret backticks at all.
- Sanity check: after any -replace on a markdown file, run [System.IO.File]::ReadAllBytes and count [char]13 and [char]92 (backslash) occurrences; non-zero values for either mean the replacement introduced escape characters. Restore the file from a fresh Get-Content if either value is greater than 0 in a file that should be LF-only with no backslashes.

## Improvement: reconcile verified state with actual file state

Condition:
- QA sub-session task instruction cites a verified state with specific file values (mtime, counts, line content) and a targeted grep on the actual file shows those values are stale or incorrect

Action:
- Do not blindly apply edits that would either fail (string not found) or corrupt (overwriting correct values with wrong ones). Use targeted Select-String to verify the current file state, then add a sub-session entry documenting the actual file state, the discrepancy with the verified state, and the reason no edits were applied. Hand off to the next sub-session with the corrected state. The verified state is a hint, not ground truth; the file on disk is authoritative.
