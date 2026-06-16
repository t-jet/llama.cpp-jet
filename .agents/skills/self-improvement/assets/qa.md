# QA improvement memory

## Improvement: reissue partial report for truncated prior sub-session

Condition:
- A prior sub-session is described as started, started-then-truncated, or returned without producing the expected output files (JSON, CSV, log, k6, baseline.json), and the state check confirms no output exists on disk

Action:
- Do reissue a PARTIAL durable report at the path the brief specifies. Mark every row with verdict `BLOCKED-prior-sub-session-truncated` and evidence `prior sub-session did not produce extractable output`. Record the prior sub-session start time, the current time, and the wall-clock delta. Recommend a re-run in a fresh sub-session and defer the per-metric and legacy comparison columns to the next re-issue. Do not fabricate values or attempt to back-fill from a different tree.

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
- Writing or running inline PowerShell QA helpers, artifact helpers, or one-off rerun blocks that pass CLI arguments to server process

Action:
- Don't use parameter or variable names that collide with PowerShell automatic variables such as `Args`, including lowercase `$args`. Use explicit names like `ServerArgs`. Preserve discarded harness logs if collision starts wrong mode or router mode. Rerun before classifying product behavior.

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

## Improvement: block unavailable mandatory endpoint rows

Condition:
- Reviewing QA plans for endpoint compatibility where design names route families, aliases, fixtures, or build features as part of the acceptance contract

Action:
- Treat missing in-scope routes, route registration, build support, tools, or fixtures as `BLOCKED` with exact prerequisite evidence. Don't allow `SKIP` unless the row is explicitly out of current scope by design or Manager decision.

## Improvement: reconcile gate status across reviewed docs

Condition:
- QA planning or test-plan review includes doc hygiene checks and one of reviewed gate documents has stale stage status

Action:
- Update stale gate status when within requested documentation scope. Cite source gate that proves current state. Record hygiene correction in the plan/review handoff instead of leaving conflicting readiness signals for next owner.

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

## Improvement: enforce CUDA-only verdict evidence when requested

Condition:
- User or gate states all tests must run on CUDA, never CPU

Action:
- Verify `GGML_CUDA:BOOL=ON` in the active build directory before build, helper, or endpoint probes. If any CPU build or probe already ran in the same session, mark those artifacts discarded setup evidence and do not use them for verdicts. Require fresh CUDA binary timestamps for every row before recording PASS or FAIL; otherwise mark rows BLOCKED with exact CUDA build/process evidence.

## Improvement: distinguish Release-build coverage gap from Start-Process bug

Condition:
- `run_coverage.ps1` (or direct `OpenCppCoverage.exe` invocation) produces 112-byte or otherwise header-only `.cov` file and merged Cobertura XML reports `0 / 0` lines (or coverage rate is 0%) even though test binary ran to completion and printed PASS summary

Action:
- First check `CMAKE_CXX_FLAGS_RELEASE` in build's `CMakeCache.txt` for presence of `/Zi` or `/DEBUG:FULL`; Release build without debug symbols is most common cause of header-only `.cov` output and is distinct from `Start-Process -ArgumentList` colon-prefixed-export joining bug.
- Classify T114/T114a as `BLOCKED` (not `FAIL`) when build is Release without `/Zi`. Cite exact `CMAKE_CXX_FLAGS_RELEASE` line and 112-byte `.cov` size as evidence. Don't try to redesign coverage denominator or merge logic to compensate.
- Pair BLOCKED with Developer handoff scoping coverage-eligible rebuild (e.g. `RelWithDebInfo` with `/Zi /Ob1 /O2 /EHsc /DEBUG:FULL`, or add `/Zi /DEBUG` to Release flags) so next session can run coverage against patched code.
- Cite prior-run numbers from build with debug symbols (e.g. `test-report-20260604-06.md` T114=0.8553, T114a=0.7035) as reference baseline and note which source files patch touched so reviewer can confirm prior numbers are still representative.

## Improvement: verify cited source contains the cited text

Condition:
- Reviewing a test plan (or any QA-authored doc) that cites a specific line range in another document as the verbatim source for a quoted block

Action:
- Don't trust the citation without verification. Open the cited document at the cited line range and confirm the quoted text actually appears there. If the cited source lacks the text but the content matches a different doc (e.g. design instead of tracker), record the citation drift as an INFO finding and note which doc actually holds the text. Do not block the review if the substance is correct and the drift is pre-existing and inherited from an already-approved upstream doc (e.g. design gate already PASSED). When the cited line number itself is off by 1 (e.g. tracker line 42 cited but Stage 15 row is at line 41), record the line number drift in the same INFO finding.

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

## Improvement: avoid piping PowerShell control blocks

Condition:
- Writing inline PowerShell QA commands that collect conditional, foreach, or if/else output before saving evidence

Action:
- Don't pipe a closing `}` from an `if` or `foreach` block directly into `Tee-Object` or `Set-Content`; PowerShell can parse it as an empty pipe element and skip the evidence step. Assign output to an array or list first, then write the variable to disk.

## Improvement: reconcile verified state with actual file state

Condition:
- QA sub-session task instruction cites a verified state with specific file values (mtime, counts, line content) and a targeted grep on the actual file shows those values are stale or incorrect

Action:
- Do not blindly apply edits that would either fail (string not found) or corrupt (overwriting correct values with wrong ones). Use targeted Select-String to verify the current file state, then add a sub-session entry documenting the actual file state, the discrepancy with the verified state, and the reason no edits were applied. Hand off to the next sub-session with the corrected state. The verified state is a hint, not ground truth; the file on disk is authoritative.

## Improvement: re-evaluate stale review reports

Condition:
- QA planning review finds an existing untracked or pre-existing review report for the same gate

Action:
- Re-evaluate each prior finding against the current user acceptance checklist and current source docs before preserving it. Rewrite stale report content, blocker IDs, and required-change text so they reflect the active gate, not an earlier reviewer's stricter or different handoff criteria. Remove stale allowances such as `BLOCKED or SKIP` when the current correction requires one exact verdict. If a re-review changes the verdict to PASS, mark prior blockers as `RESOLVED` or historical so the report cannot be read as still blocking.
- When adding a separate re-review report, keep the original REWORK record and the new PASS re-review record distinct in parent lists and `document-index.md`; don't let one index entry conflate original findings with current readiness.


## Improvement: /slots save needs filename in body, not just ?action=save

Condition:
- Probing E13-10 /slots save with `POST /slots/0?action=save` and empty `{}` body

Action:
- Send `{"filename":"<name>.slot"}` in the body. Without `filename`, server returns 500 with `key 'filename' not found`. With filename, save returns `id_slot,filename,n_saved,n_written,timings`. Use the same filename in the restore body. Don't classify 500-with-empty-body as a product schema bug.

## Improvement: scope E13-14 leak scan to SRV_DBG line, not all log lines

Condition:
- E13-14 degraded-fallback probe must verify no prompt/marker/tool-arg leak, and server is started with `--log-verbosity 5`

Action:
- Scope the leak scan to the SRV_DBG `cache metadata: source=... method=... degraded=... tokens=... boundaries=...` line family. The pre-existing `log_server_r: request:` and `log_server_r: response:` lines at verbosity 5 echo the full request and response bodies (including any secret/marker/tool-arg inserted in the probe). That is a pre-existing debug log, not a Stage 13 regression. Mark the diagnostic line clean and note the pre-existing log behavior in the report so the next session does not misclassify the request log as a Stage 13 leak.

## Improvement: do not call GetResponseStream on PowerShell HttpRequestException

Condition:
- Writing PowerShell probe script that captures `Invoke-RestMethod` failure details

Action:
- Don't call `$_.Exception.Response.GetResponseStream()` to read the error body. PowerShell wraps the response in a different exception type that does not expose `GetResponseStream`. Just store `$_.Exception.Message` into separate log artifacts via `Out-File` after the call. The error body line is also already visible at the end of `$_.ToString()`. If the response body is needed, send a follow-up request or use a different approach. Classify any 4xx/5xx by status code only when message body is not needed.

## Improvement: rerun aliases after crash-contaminated endpoint probes

Condition:
- Endpoint execution runs multiple route aliases or related media routes through one server process, and an earlier request crashes or aborts the server before later aliases complete

Action:
- Do not classify later aliases from connection-refused or connection-reset artifacts caused by the earlier crash. Start a fresh server and run each alias first in isolation. Mark alias verdicts only from independent process evidence, while preserving the contaminated sequence as setup or crash lineage.

## Improvement: resize audio context before endpoint verdict

Condition:
- Audio transcription endpoint rerun has a valid CUDA audio fixture and server reaches readiness, but the response is `exceed_context_size_error` before the old abort/reset behavior can be judged

Action:
- Treat the small-context attempt as harness setup evidence. Increase `--ctx-size` enough for the reported `n_prompt_tokens`, rerun each route in a fresh process, and base PASS/FAIL on the larger-context route evidence while preserving the undersized attempt.


## Improvement: \/quit\ does not exist on this build, fall back gracefully

Condition:
- QA probe assumes a public POST \/quit\ endpoint exists on \llama-server\ for graceful shutdown before reading \stderr\ log file (to avoid Windows log flush loss from abrupt kill)

Action:
- Don't trust \/quit\ is registered on the current \llama-server\ build. Send the request and capture status first. If 404, fall back to \	askkill /pid\ (no \/F\). If the process was started with \-NoNewWindow\ and is detached, \	askkill /pid\ may not exit the process within 5-10s; record the fallback and use \Stop-Process -Id <pid> -Force\ only after confirming the log file already contains the full request phase (line count, last line content, or both diagnostic lines present for E13-14). The kill mechanism does not lose evidence when the log was complete before the kill. Cite \/quit\ 404 response and force fallback in the test report's process inventory so the next session knows the endpoint is not available and the kill chain.


## Improvement: .test_reports .gitignore ignores new test reports when ! rules precede * rule

Condition:
- Creating a new 	est-report-YYYYMMDD-NN.md in ._design_docs/.test_reports/ and git add rejects the file with "The following paths are ignored by one of your .gitignore files"

Action:
- The current .gitignore at ._design_docs/.test_reports/.gitignore has !test-report-*.md (and three other ! re-include rules) BEFORE the trailing * ignore rule, which causes the * to win (last matching rule wins in gitignore). New test reports cannot be committed without git add -f. Existing tracked test reports were added before the .gitignore change took effect and remain tracked. Don't add the file with -f in the QA session; record the pre-existing gitignore ordering issue in the test report under a handoff or "pre-existing known issues" section, cite git check-ignore -v evidence, and hand off to the Manager to fix the .gitignore ordering (! rules must appear AFTER * to re-include). Verify file content with git diff --check --no-index /dev/null <file> and LF-only byte check before final handoff.

## Improvement: extract B-row values from llama-server /metrics in 5-minute focused re-run

Condition:
- A focused benchmark re-run has a strict time budget (5 min) and the test plan names metric families like `cache_exact_blob_hits_total`, `cache_checkpoint_hits_total`, `cache_cold_transitions_total`, token throughput, restore latency, total hits+misses, and per-request CPU time

Action:
- Do start llama-server with the MTP fixture, hybrid cache mode, and `--metrics`; issue 5-10 chat-completion requests with a shared prefix; capture `/metrics` once before and once after; map the brief's metric names to actual counters by grep on `/metrics` raw text. The build exposes `llamacpp_cache_hits_total`, `llamacpp_cache_misses_total`, `llamacpp_cache_payload_demotions_total`, `llamacpp_cache_payload_promotions_total`, `llamacpp_cache_payload_cold_evictions_total`, `llamacpp:tokens_predicted_total`, `llamacpp:tokens_predicted_seconds_total`, and `llamacpp_cache_promotion_latency_bucket_*`; per-request `total time` and `eval time` come from `slot print_timing` in server stderr, not from /metrics. Classify restore latency p50/p99 as `BLOCKED-no-successful-restores` when zero successful restores occurred, and require a follow-up workload with repeated identical prompts to clear the row.
- Don't trust the test plan's metric names verbatim; verify the actual counter name and document the mapping in the report. Don't fabricate values for restore latency rows when the workload produced zero successful restores; mark BLOCKED with the exact log line family that proves the absence.

## Improvement: reclassify prior BLOCKED with new hard evidence, do not trust infra-resolved claims

Condition:

- A prior QA sub-session marked rows BLOCKED for an environment reason (no metric exposed, no successful restores, no fixture, no tool) and a follow-up re-run is launched with the claim that the blocker is now resolved

Action:

- Do not trust the infra-resolved claim. Run the re-run on the same fixture/build and capture hard evidence: counter names from /metrics, save/restore log line counts, response-body cache_n values, and per-request timings. When the prior BLOCKED reason was factually wrong (e.g. cache_checkpoint_* rows ARE in /metrics), cite the prior report's error and reclassify to PASS-observed-zero with the four-row presence plus a non-zero admission_failures counter as evidence the path is exercised. When the workload produces 0 successful restores even after expanding to 50 identical /completion requests, do not soften the verdict to PASS; mark BLOCKED-no-successful-restores with the new structural evidence (entry length vs task length, LCP-found-match count vs exact-match-found count, sim_best=1.000 distribution) and recommend a Manager plan-level decision (V2 fixture swap, MTP probe with checkpoint-admitting workload, or NOT-IN-SCOPE reclassification). Cite both /metrics raw text and server stderr log line counts so the next session can verify.

## Improvement: separate length-mismatch from checkpoint-admission with token-count probes

Condition:
- A prior QA report classifies B05/B06 as BLOCKED-no-successful-restores citing a token-length mismatch between the stored entry and the request task (e.g. `entry 30 tokens, task 27 tokens, prefix 27`) and the user asks for a focused rerun that matches the suggested token count (e.g. 30-token prompt) to clear the blocker

Action:
- Do not assume the prior report's structural cause is correct. Run at least two length-matched probes at different token counts (e.g. 29 and 36) using the same fixture and server flags. Build the prompt via `/tokenize` iteratively, send a warmup with `n_predict=0` and `cache_prompt:true`, then run 50 identical requests. If both length-matched probes still produce 0 successful restores AND the LCP log line shows `task N tokens, entry N tokens, prefix N` (perfect prefix match) on every restore attempt, the length-mismatch hypothesis is REFUTED. The real cause is almost always the save path producing entries without checkpoint boundary metadata, which makes the stored entry a regular (non-checkpoint) entry and causes the exact-blob restore check to reject every identical request. Cite the `checkpoint admission skipped (missing checkpoint boundary metadata)` warning from server stderr, the 0 `cache_checkpoint_admissions_total` metric, the 1 `cache_checkpoint_admission_failures_total` metric, and the LCP-found-match count vs no-exact-match count in the report. Reclassify BLOCKED-structural-not-infra (not BLOCKED-no-successful-restores, since the cause is now known) and propose a Manager plan-level decision (reclassify to NOT-IN-SCOPE for the MTP fixture, or Developer task to add checkpoint boundary metadata to the save path). Don't soften the verdict to PASS on the basis of length-matched probe data alone; the absence of a successful restore is the evidence, not the length match. The BPE tokenizer may not land exactly on the suggested token count (e.g. 30 unreachable; 29 closest); record the actual token count and continue.
- Don't claim the prior report was wrong without the second independent probe. One length-matched probe at one token count could in theory hit a BPE edge case. Two probes at different token counts that both fail with the same structural pattern is strong evidence.


## Improvement: llama.cpp /completion timings JSON does not expose total_ms

Condition:
- A bench report or harness collects per-request latency for B05/B06 and the task brief names a 	otal_duration_ms field name to read from the server's 	imings JSON

Action:
- Don't trust that the /completion response has a 	imings.total_ms field. The current llama.cpp server exposes only prompt_ms and predicted_ms in the timings struct, and 	otal_ms is absent (or zero if deserialized as a default). Compute 	otal_ms = prompt_ms + predicted_ms in the harness or recompute step, and label the per-request column explicitly as "total_ms (prompt+predicted)" so the next session does not chase a phantom missing field. Cite the prior smoke-test summary (where total_ms was 0 across all rows) as evidence of the missing field, not as a product bug.

## Improvement: git diff --check skips untracked new files; use --no-index

Condition:
- Task brief requires running git diff --check <new-untracked-md-path> and reporting the exit code, and the file was just created with create_file

Action:
- Don't trust exit 0 from git diff --check <untracked-path> as proof the file is whitespace-clean. Untracked files are not inspected by plain git diff --check, so even a CRLF-only new file returns exit 0. After the file is LF-only, run git diff --check --no-index /dev/null <path> to inspect the actual content; zero lines of warning output and exit 1 (differ) is the clean state. Combine with byte-level CR count check via [System.IO.File]::ReadAllBytes to be certain.
