# QA improvement memory

## Improvement: distinguish Manager claim of N converted call sites from actual diff conversions

Condition:
- QA verifies a Manager claim that N call sites in a test file were converted from `assert(...)` to explicit `if (...) { fprintf + std::abort() }` pattern, and the verification list includes line numbers that mix function definitions with actual call sites

Action:
- Do run `git show HEAD:<file> | Select-String -Pattern '<func_name>\(' | Select-Object LineNumber, Line` to enumerate the call sites that existed at HEAD, then run the same `Select-String` against the working tree. Compare the diff (`git diff <file> | Select-String -Pattern '^[+-].*<func_name>\('`) to count actual conversions. A `+` prefix with new abort pattern and matching `-` prefix with old assert pattern is one conversion. Line numbers that point at the function definition (`static bool name(`) are not call sites and should be excluded from the count. If the working-tree `assert(...)` line is unchanged (no `+`/`-` prefix in diff), it was NOT converted despite any "reverted to assert() form" comment that says otherwise. The "reverted" wording is a misleading developer idiom when the line was never actually converted in the current tree. Report the actual conversion count vs the Manager's claimed count and explain the discrepancy in the verification report; do not silently accept the Manager's count.

## Improvement: distinguish BLOCKED-runner-cleanup from real product failure when leg completes

Condition:
- A Stage N runner script (e.g., `stage24-chat-s02-s03-comparison.ps1`) classifies a leg's verdict as `BLOCKED-runner-cleanup` while the leg's `summary.json` shows `state: completed-until-cap`, `status_counts: {200: N}`, `error_counts: {}`, `port_free: true`, and `server_exit_was_forced: false` (server_exit_code = -1 / `alive_or_unknown`)

Action:
- Do read the per-leg `summary.json` files directly, not the runner's row-level verdict. When `request_run.state == "completed-until-cap"` and `status_counts` is all 200 and `error_counts` is empty and `cleanup.port_free == true`, the leg PASSED end-to-end regardless of the runner's `BLOCKED-runner-cleanup` label. The runner bug is that it cannot query the exit code of a server still alive after the wall-clock cap and classifies that as `BLOCKED`. Record the actual per-leg outcome from `summary.json` (observed, status, errors, cache_n nonzero_rate, cap state) in the durable evidence file; cite the runner bug separately so the next session can fix the runner to either force-kill the server after the cap or treat `alive_or_unknown + port_free + all 200` as `PASS-completed-until-cap`.

## Improvement: distinguish D17-IP-* from Manager design-gate decisions in test-plan review

Condition:
- Reviewing a Stage N test plan that lists binding decisions with prefixes like `D17-IP-*` alongside design-gate decisions like `D17-*` (or analogous stage-scoped decision prefixes)

Action:
- Do treat the `D{N}-IP-*` (or `IP-*` stage-prefixed) decisions as implementation-plan binding rules, not Manager design-gate decisions; the `IP` prefix denotes implementation plan. When the test plan header groups them under "Manager decisions (binding)", record a non-blocking finding noting the label imprecision; the substance is correct (the plan honors all six) but the label should distinguish Manager-gate from implementation-plan decisions. Do not block the review on a label-only issue when the decisions are all honored in the rows.

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
- Search runner scripts and focused test sources for those exact IDs or required behaviors. Compare implemented assertions with plan. When a plan relies on wrapper dry-run or readiness output, compare the dry-run-validated flags and fixture paths with the actual live child-process argument list and row-script parameters; do not accept synthetic dry-run logging as proof of live execution behavior. Also compare required evidence filenames from the plan and wrapper row gates against what each row script can actually write, especially before/after metrics files. Split public-harness coverage from acceptance rows needing focused, draft-fixture, stats-capable, or fault-injection evidence. Map every PASS claim to specific test names or source lines. Update runner PASS/BLOCKED logic only when current task requires automation changes.

## Improvement: reconcile runner summaries with evidence

Condition:
- Test runner emits conflicting console output, exit codes, generated reports, skip/fail summaries, blank/UNKNOWN rows, inflated totals, or candidate PASS logic that is weaker than the current Manager/user acceptance gate

Action:
- Inspect generated report, raw logs, prompt-evidence JSONL, metrics, and the active gate wording. Rerun narrow direct checks for disputed cases or truncated startup logs when possible. Count only real test rows. Base final PASS/FAIL/SKIP/BLOCKED counts on verified evidence and the active gate, not on runner exit code or summary alone. If a runner PASS-candidate only proves a weaker rule, record that mismatch in the durable report and classify by the stricter gate, including named per-request requirements such as every exact repeat needing `cache_n > 0`. When the gate names forbidden warning or miss families, count them separately in server logs and JSONL; do not treat a clean runner summary as overriding non-zero forbidden-family evidence. For llama.cpp logs, count exact warning families or severity patterns, because many warnings use a single `W` field rather than the words `WARN` or `warning`.

## Improvement: do not rerun failed QA without new handoff

Condition:
- User asks to continue or manage the stage after QA already produced a fresh FAIL report and no new Developer fix, Manager exception, or changed test scope is present

Action:
- Do verify the latest report and relevant dirty paths, then keep the stage at bug handoff. If acting as Manager, update the implementation gate log, stage tracker, document index, and active fixes report so they point to the failed rerun and next Developer owner. Do not spend another model-backed run on the same binary and same acceptance gate unless a new handoff changes the expected evidence.

## Improvement: suppress PowerShell helper output

Condition:
- Adding or editing PowerShell QA harness functions or one-off wrappers that build result arrays, JSON summaries, or markdown reports

Action:
- Suppress non-result command output from cleanup helpers, HTTP request helpers, and command-log helpers with assignment, filtering, redirect-to-file, or `[void]`. Do not let `Tee-Object` pipeline output flow into a function or wrapper return value that is also being appended to a result array; otherwise build logs or native stderr records can pollute JSON summaries, blank report rows, or malformed markdown evidence even when the underlying command exit code is correct.

## Improvement: validate generated markdown reports

Condition:
- PowerShell QA runner generates markdown with fenced command or evidence blocks

Action:
- Inspect generated report before accepting run. Use markdown fences PowerShell will not escape inside expandable strings, such as tildes or doubled backticks. If the runner writes a minimal or preliminary durable report and QA later replaces it with the final Markdown, rerun leak and hygiene checks against the final file, not only the runner-written version.

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
- Decide final session report suffix before collecting ad hoc artifacts. Check the durable report path, the matching non-durable output root, and any matching cold root before writing the first artifact. If any matching root already exists, or if a failed bootstrap creates a partial empty output/cold root before preflight files are written, treat that suffix as used and advance to the next chronological suffix. Record the skipped suffix and reason in the durable report. Store artifacts under the final suffix so evidence links do not point at a different report number.

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
- Check initial line counts before editing near-limit QA docs, and draft new standalone QA docs or execution reports against an explicit line budget before the first validation pass. If a new file exceeds the cap, compact it immediately instead of splitting unless the remaining content truly needs a part file. Resolve every local markdown link from the edited file's own directory, not from the repo root or parent index; for files under `._design_docs/cache-handling-test-plan/`, sibling design docs usually resolve as `../cache-handling-*.md`, not `../../cache-handling-*.md`. Rerun line-count, ASCII-byte, LF/no-CR, BOM, whitespace, link, and diff-shape checks on every touched markdown file before final handoff, including fresh untracked reports and part files that `git diff --check` will not inspect. Preserve existing line endings where practical; if tool changes them, normalize deliberately and rerun `git diff --check`.

## Improvement: separate own QA edits from dirty sources

Condition:
- QA review task uses or indexes documents that are already modified or untracked in working tree

Action:
- Check `git status --short` for reviewed and edited paths before editing. If final `git diff` includes older dirty changes in the same files, separate them from the review-owned patch by comparing against the pre-edit status and the specific lines added during the session. Report only review-owned edits as own handoff changes, and note pre-existing dirty files only as context.

## Improvement: blank line between single-line label and following list

Condition:
- Authoring markdown in `._design_docs/...` with a section that uses a single-line label ending in a colon (e.g. `Design:`, `In scope:`, `Out of scope:`, `Implementation:`, `Prior test plan parts:`) followed by a bulleted list on the next line

Action:
- Do insert a blank line between the label line and the first list item. The pattern `Label:\n- item` triggers markdownlint MD032 "Lists should be surrounded by blank lines" on the first list item, even when the list itself is internally well-formed. The fix is `Label:\n\n- item`. Use a `multi_replace_string_in_file` to add the blank line after every such label; `get_errors` to confirm zero lint errors before handoff. Verified pattern in part-26 (`Inputs (read in order, all durable):` followed by blank line then list).

## Improvement: wait for model-specific readiness in public probes

Condition:
- Public HTTP harness starts `llama-server` with secondary model resources such as draft, MTP, multimodal, or adapter fixtures

Action:
- Treat `/health` as process readiness only. Wait for model-specific log marker when build emits one, or make first behavior request guarded readiness/admission probe. Require direct secondary-resource evidence such as `draft_n > 0` before accepting later restore or hit claims. Preserve marker-less setup attempts separately from product evidence. Keep startup log verbosity low unless diagnostics require it.

## Improvement: run config-validation tests via integration tier, not just unit tier, when side effects precede validation

Condition:
- Stage test plan has both a unit row and an integration row for the same config-validation rule (e.g. `cache_prompt_evidence = raw` requires `--log-prompts-dir`; `--cache-cold-max-mib` must be >= -1), and the validation lives in server-context.cpp or similar file inside load_model() after slot init

Action:
- Do not assume the unit-row PASS proves the config is rejected at startup. The integration row catches the case where validation runs after model warmup or slot init and a precondition crash (e.g. STATUS_STACK_BUFFER_OVERRUN) bypasses the validation. Map the integration-row verdict independently of the unit-row verdict; if integration crashes, the unit row is not evidence of clean rejection. Document the crash site in the test report's findings section with the exit code, the last log line, and the offset between the last log line and the validation block in source.

## Improvement: map focused test functions to test plan UT rows before PASS-classifying

Condition:
- A test plan's unit tier (TP-NN-UTx) lists N rows, and the focused test binary has fewer test functions, but the existing test functions cover multiple UT row assertions in aggregate

Action:
- Read the test source diff (`git diff HEAD tests/test-*.cpp`) and map each test function to the UT row assertions it covers. A test function with multiple asserts can cover multiple UT rows. PASS only the rows whose assertion is in the test function; mark uncovered rows BLOCKED-pending-test-code even if other rows in the same test function PASS. Do not collapse a multi-assert test function into a single PASS for one UT row when it covers assertions for several rows. The test plan's row contract is the source of truth; the test function's asserts are evidence per row.

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

## Improvement: verify runner script parameters before launch

Condition:
- Launching PowerShell QA runner or test harness script with command-line parameters, especially when script behavior or available parameters are not yet verified in current session

Action:
- Read the script's param block (first ~50-100 lines containing `[CmdletBinding()]` and `param()` declarations) before constructing launch command. Verify parameter names, mandatory flags, defaults, and validation attributes match the intended launch arguments. Do not infer parameter names solely from design docs or implementation logs; scripts may hardcode flags internally or use different parameter names than the conceptual design describes.

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

## Improvement: verify Select-String count for cross-line patterns

Condition:
- Reviewing a test plan row that expects a specific count from `Select-String` (or grep with default line-by-line behavior) for a string that spans multiple adjacent source lines (e.g. SRV_ERR on one line, throw on the next line, or two consecutive lines of a multi-line literal)

Action:
- Do not trust the count claim in the test plan row without running the actual `Select-String` command. By default `Select-String` returns one match per line containing the pattern, not one match per logical block; if the pattern appears on N adjacent lines (e.g. canonical check at lines 1419 and 1420 with the same substring in SRV_ERR and throw), the count is N, not 1. If the test plan row says "exactly 1 match" but the actual Select-String returns N matches, record a non-blocking finding noting the wording drift. Cite the actual count and lines in the finding. Do not block the review if the substance is correct (canonical block intact, duplicate gone) and the wording drift is inherited from an already-approved upstream doc. If the drift is fixable with a more specific pattern (e.g. one that matches only the throw line), suggest the fix as the recommended action; otherwise note that the count wording is imprecise but the row is still verifiable.

## Improvement: avoid `+ N` or `* N` at start of continuation line in parenthetical text

Condition:
- Authoring markdown test plan prose with a parenthetical that begins a continuation line with `+ N` (e.g. `(74 pre-Stage 17` on one line, `+ 15 Stage 17 test_stage17_* functions). Count the actual` on the next line)

Action:
- Do not put `+`, `*`, or `-` followed by a digit at the start of a continuation line inside a parenthetical. markdownlint MD004 interprets the leading `+ N` as a list marker that does not match the dash style used by surrounding lists, and reports `MD004/ul-style: Unordered list style [Expected: dash; Actual: plus]`. Reword the parenthetical to avoid the leading `+ N` pattern, e.g. `(74 pre-Stage 17 tests plus 15 Stage 17 test_stage17_* functions)` or split the parenthetical across fewer lines. The pattern is common when describing test counts like `(N existing + M new)` in a bullet list. Run `get_errors` on the touched markdown file before final handoff to confirm zero lint errors.

## Improvement: expand row count to honor post-design Manager amendments

Condition:
- Authoring a Stage N test plan from a design-proposal row list (e.g. 13 rows) when a post-design Manager plan-amendment gate decision (e.g. D{N}-IMPL-01) moves contract flags to additional locations (e.g. from compile flags to three linker flags) that the design proposal did not enumerate

Action:
- Do not silently drop the amendment's new contract locations from the row table. Add a focused row (or expand an existing row) to cover the new locations, document the row-count deviation from the design proposal in the test plan header, and cite the Manager plan-amendment gate decision as the reason. The row-count deviation is a non-blocking finding at test-plan review, not a blocker, because the alternative is a test plan that does not fully cover the binding decision. The amendment always post-dates the design proposal by definition; the test plan must reflect the post-amendment state, not the pre-amendment state.

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

## Improvement: git diff --check skips untracked markdown; use --no-index

Condition:
- Validating markdown QA artifacts or durable docs that are untracked, newly created, ignored, or otherwise absent from the tracked git diff

Action:
- Don't trust exit 0 from plain git diff --check as proof an untracked or ignored markdown file is whitespace-clean. Plain git diff --check does not inspect those paths, so a CRLF-only untracked file can still return exit 0. Run git diff --check --no-index /dev/null <path> for each untracked/ignored markdown artifact or durable doc; zero warning output with exit 1 (files differ) is the clean state. Combine this with byte-level CR and non-ASCII checks via [System.IO.File]::ReadAllBytes, and run normal git diff --check for tracked touched files.

## Improvement: avoid touching oversized auxiliary docs during scoped planning

Condition:
- A QA planning task says to update a script README or document index if needed, and the script README is already over the repository line cap before the task starts

Action:
- Do not make a small append to the oversized README unless the task explicitly requires README edits. Prefer updating the split test-plan part and document index, then state that the README was left unchanged because touching it would require a separate split/cleanup. If README content is essential for the gate, split it under the document-size rule instead of adding another over-cap edit.


## Improvement: PowerShell automatic variables block PID/args/Host reassignment

Condition:
- A QA session needs to store a server process PID (from Start-Process -PassThru) or pass CLI argument arrays in a variable named $PID or $args (lowercase or mixed case)

Action:
- Do not use $PID, $pid (case-insensitive automatic variable for current session process ID), $args, $input, $Host, $HOME, $PWD, or any other PowerShell automatic variable name. These are read-only or constant. `Stop-Process -Id $PID` for a server PID variable named $PID throws `WriteError: Cannot overwrite variable PID because it is read-only or constant.` Use explicit names like $ServerPid, $ServerArgs, $ServerHome. Per existing memory item `avoid automatic-variable names in PowerShell harnesses`, the same applies to $args for CLI argument arrays.

## Improvement: Test-Path inconsistency on dot-prefixed paths

Condition:
- A QA session accesses a dot-prefixed path like `D:\path\._test_output\foo\bar.log` and `Test-Path` returns `False` for an artifact that `Get-ChildItem` (or a previous `Start-Process -RedirectStandardOutput`) clearly produced. The `New-Item -ItemType Directory -Force -Path "._test_output\foo"` succeeded but `Test-Path` on the new dir returns `False` until the path is accessed again. `Get-ChildItem` of the parent dir shows the new dir IS present.

Action:
- Do not trust `Test-Path` alone for dot-prefixed paths on Windows + PowerShell. PowerShell path resolver may normalize the leading dot and resolve to a sibling `_test_output` (no dot) which is a different physical directory. Use `Get-ChildItem -LiteralPath "D:\path\._test_output" -Force | Where-Object { $_.Name -eq "foo" }` for canonical existence check. If a new file is needed, write it with `Out-File -FilePath $absolutePath` (where `$absolutePath` is built with `Join-Path` from `Get-Location`) and verify with `Get-ChildItem -LiteralPath $absolutePath` immediately after. Per existing memory item `verify create_file path against near-duplicate dir names`, the same applies: after `create_file` or `Out-File` to a dot-prefixed path, verify with `Get-ChildItem -LiteralPath` using the full absolute path, not `Test-Path`.

## Improvement: classify near-ready heavy startup timeouts as harness setup first

Condition:
- A model-backed heavy QA runner fails `/health` before any requests, but `server.err.log` shows the server is still progressing through model load or slot initialization near the runner readiness timeout

Action:
- Do not classify the run as cache product evidence. Preserve the failed runner attempt as setup evidence, then rerun the same fixture, flags, workload, and request schema with a longer readiness wait without editing the reusable runner. Base PASS/FAIL only on the request-phase run. If the longer-wait run still never reaches health or exits, report BLOCKED/FAIL-health with startup logs and do not infer cache behavior.

## Improvement: Manager decision D-NN-M reclassification may not need invocation when fix actually succeeds

Condition:
- A Manager reclassification decision (e.g., D-16-1: reclassify the n_tokens=11 MTP test case to expected-FAIL because the matching loop requires `token_end <= descriptor.token_span_end` and the system prompt-span at ~12 does not satisfy `<= 11`) is recorded in the test brief as "mandatory, apply if FAIL at n_tokens=11". The fix is applied and the actual evidence shows the user-message prompt-span boundary at exactly [0, 11] satisfies `<= 11` and the matching loop succeeds.

Action:
- Do not apply a Manager reclassification to a row that did not FAIL. Record explicitly in the test report D-NN-M application section: "no row FAILed at the reclassified position; reclassification not invoked; the actual evidence shows the fix succeeds at that position because the per-message prompt-span boundary at exactly [0, MTP n_tokens] satisfies the relaxed condition". Cite the specific boundary that satisfies the condition (e.g., user MESSAGE_END at [2, 11] with token_end=11, metadata="prompt"). This documents the Manager decision was preemptive and prevents the report from looking like it ignored a mandatory directive. If the fix had failed, document the reclassification in the verdict column and cross-reference the Manager decision row.
## Improvement: test-output folder name must match the test report ID

Condition:
- A QA test-execution session creates a subfolder under ._test_output/ to hold build logs, ctest output, and benchmark artifacts for a test run, and the run is associated with a durable test report file

Action:
- Do name the subfolder 	est-report-YYYYMMDD-NN-artifacts/ (or 	est-report-YYYYMMDD-NN-artifacts/<sub>/ for nested categories) where YYYYMMDD-NN matches the test report filename 	est-report-YYYYMMDD-NN.md. This is the part-24 convention: the same ID ties the report to its supporting artifacts
- Do not use generic suffixes like -rerun, -rerun2, -rerun3a, -retry, or -fix2; these break the convention and make it impossible to find the artifacts for a given report
- Do merge multiple intermediate folders from successive reruns into the same 	est-report-YYYYMMDD-NN-artifacts/ folder rather than creating -rerunN variants; the artifacts from rerun 1, rerun 2, and rerun 3 all support the same report
- Do not commit anything under ._test_output/ (it is gitignored); but do ensure the folder name on disk matches the report ID so a reader can find the artifacts
- When the second exec reuses the first exec's folder (because the build was not re-cleaned), record this explicitly in the second report's evidence column with a note like "shared with first exec"
- Don't reference old -rerun folder names in test-report evidence columns; update them when the convention is applied

## Improvement: avoid nested PowerShell backtick continuations in shell_command

Condition:
- Running a PowerShell script through `functions.shell_command` with an inner `powershell -Command "& script ..."` invocation that passes many parameters, especially array parameters such as `-RowsToRun @('S01',...)`

Action:
- Don't use multiline backtick continuations inside the nested `-Command` string. The outer shell or JSON escaping can drop the continuation and run the script without the intended parameters, then treat later parameter lines as separate commands. Use one single-line `-Command` with an explicit array literal, or write a short outer PowerShell block that invokes the script directly with native argument binding. If using `-File`, verify array parameters bind as separate elements rather than one CSV string.

## Improvement: check server implementation DLL mtime on Windows launcher builds

Condition:
- QA execution requires fresh `llama-server.exe` build evidence on Windows, and the CMake/MSBuild target emits a small launcher executable plus `llama-server-impl.dll`

Action:
- Do record mtimes for both `build-cov/bin/Release/llama-server.exe` and `build-cov/bin/Release/llama-server-impl.dll`. Treat the target build log plus current implementation DLL mtime as the freshness evidence when the launcher executable is up to date and does not relink. Do not reject an otherwise clean build solely because the launcher exe mtime did not change.

## Improvement: separate wrapper preflight timestamp from runner timestamp

Condition:
- A QA execution wrapper creates preflight artifacts under one timestamped directory and then calls a reusable runner that creates its own timestamped evidence directory under the same run root

Action:
- Do identify the runner's reported `evidence_path` and use that as the final request/metrics/log evidence path. Record the wrapper preflight directory separately for build and controller-test evidence. Do not scan server logs or metrics from the wrapper directory unless the runner actually wrote them there.

## Improvement: do not use LASTEXITCODE for PowerShell script return-object runners

Condition:
- A QA wrapper invokes a PowerShell runner that returns an object instead of calling an external executable, and the wrapper needs to decide whether the run command failed

Action:
- Don't classify the runner command from `$LASTEXITCODE`; it may retain a stale value or be empty because PowerShell script success does not set it. Use try/catch for invocation errors, then classify the run from the generated `summary.json`, request rows, logs, and gate evidence.

## Improvement: reject row_gate success when final row evidence is missing

Condition:
- A stress or longrun wrapper row emits `row_gate ... exitCode=0`, but the row server stopped during the request phase or before final scrape, and required files such as `metrics-after.txt`, `evidence-summary.md`, or `cap-exit.json` are missing

Action:
- Don't accept the row from wrapper exit code or row_gate alone. Wait until the row cap or wrapper completion if the child script swallows request errors, then classify from required-file presence, launch stderr, server liveness, and server log tail. If final `/metrics` fails with connection refused after request traffic, mark the row as FAIL/BLOCKED per the stricter acceptance gate and stop the matrix when the plan requires bug handoff.
- Do check the row script's actual evidence contract before treating a missing optional cap artifact as row failure. Some S/L row scripts complete a fixed-duration loop, scrape `metrics-after.txt`, write `evidence-summary.md`, and stop the server without producing `cap-exit.json`; in that shape, classify from the completed duration, wrapper exit, row gate, after metrics, logs, and prompt/cold evidence rather than failing solely on absent `cap-exit.json`.

## Improvement: require actual comparison artifacts for comparison rows

Condition:
- A QA execution row is named as a comparison row, legacy comparison, baseline comparison, or paired benchmark comparison, and the wrapper exits 0 with `row_gate` success

Action:
- Do inspect the child row script, live flags, `evidence-summary.md`, and row output for both comparison legs or a durable baseline/comparison artifact before passing the row. If the script runs only one mode, leaves the row summary at `PENDING`, or says QA must compare to a paired benchmark that was not produced, classify as `BLOCKED-runner-contract` even when metrics, redacted evidence, CUDA, and error scans are clean. Recover timing stats from logs if useful, but do not treat recovered timings as a substitute for the missing comparison contract.

## Improvement: verify workload identity for named workload rows

Condition:
- A QA execution row is named as a mixed workload, profile mix, prompt mix, exact/near/new split, pressure workload, or other workload-shape row, and the wrapper exits 0 with complete basic evidence

Action:
- Do inspect the child row script, `evidence-summary.md`, prompt evidence profiles, request bodies or labels, and metrics before passing the row. If the live run proves only a single repeated prompt or stale legacy-control workload instead of the named workload shape, classify it as `BLOCKED-runner-contract` even when the row ran for the full cap, `row_gate` and `batch_end` are present, scans are clean, and cold budget is within limit.



## Improvement: cache validation position matters for bounded-error exit

Condition:
- A test plan's integration row expects a ounded-error exit from a config-validation block in load_model() or similar, and the validation block is positioned AFTER the model load / warmup step

Action:
- Don't trust the design's claim that "the validation block rejects the configuration". The crash site can be in the warmup path itself, BEFORE the validation can throw. Reproduce the row empirically in the QA session, not by code inspection. If the server exits with  0xC0000409 STATUS_STACK_BUFFER_OVERRUN (or any non-bounded-error exit) instead of printing the validation's SRV_ERR / throw message, the validation block is unreachable and the row is FAIL even if the validation source is correct.
- Verify the validation block runs BEFORE the warmup step in the source. If it does not, record the structural finding (validation is positioned wrong) and route to Developer for a position fix.
- The design's "F-XX-IMPL-02" closure citing "this check at line N" must be verified empirically; the check at the cited line may not fire for the actual sub-case the row exercises (e.g. when a sibling check with stricter condition is the one that would fire, but a different invalid configuration hits the warmup path first).
- When a single test plan row produces a STATUS_STACK_BUFFER_OVERRUN and a sibling row with a different invalid config produces the same crash, both rows likely share a single root cause: a buffer overrun in the warmup path that fires before any validation block. Document the shared root cause once and link the second row as a sibling of the first.

## Improvement: verify CUDA before multi-hour GPU-expected rows

Condition:
- A model-backed QA execution session is expected to use NVIDIA/CUDA, especially long stress, longrun, heavy, or benchmark rows where CPU-only execution would waste the run window

Action:
- Do verify CUDA before live rows by checking `CMakeCache.txt` for `GGML_CUDA:BOOL=ON`, recording startup logs that show a CUDA/GPU backend, and capturing `nvidia-smi` with the `llama-server.exe` process using GPU memory. If any check shows CPU-only execution (`GGML_CUDA:BOOL=OFF`, CPU-only startup logs, or 0 MiB/no compute process in `nvidia-smi`), stop immediately, preserve evidence, and classify the run as `BLOCKED-invalid-CPU-only` rather than continuing the matrix.

## Improvement: enforce row cap over internal profile loops

Condition:
- A stress or longrun row script runs multiple internal profiles or subcases, and the active test plan defines a cap for the row rather than for each internal profile

Action:
- Do inspect the row script before or during execution to confirm whether `DurationMin` applies once per row or once per internal profile. If the script applies the duration to each profile and the total row runtime exceeds the plan cap, classify the session as `BLOCKED-runner-contract` even when each profile writes `metrics-after.txt` and `evidence-summary.md`. Preserve completed profile evidence, stop row-owned processes after capture, and hand off to Manager for cap interpretation or runner fix before opening the next row.

## Improvement: verify pressure rows actually create pressure

Condition:
- A stress or longrun row is named or specified as a pressure row, budget row, eviction row, queue row, demotion row, or cold-store row, especially when wrapper flags or row-local flags control the effective hot or cold budget

Action:
- Do inspect the live `evidence-summary.md`, server startup/state logs, resource samples, and after metrics to confirm both the effective budget and an observed pressure path. If a pressure row uses a row-only fixture substitution, verify both identities: the live server loads the pressure fixture and the durable report still records the primary stage fixture in notes. If duplicate flags leave the live server using a larger budget than the row's pressure setup (for example local `--cache-ram 16` or `--cache-ram 8` followed by wrapper `--cache-ram 512`), classify as `BLOCKED-runner-contract`. For protected-root pressure rows, require non-zero protected-root decision, demotion, eviction, protected payload byte, or equivalent stats-capable evidence; 0 protected-root metrics means the row did not prove the scenario. If the effective pressure budget is correct but metrics and artifacts still show 0 demotions, 0 skips, 0 evictions, 0 cold files, 0 resident entries, 0 protected-root pressure decisions, or otherwise no required pressure signal, also classify as `BLOCKED-runner-contract` rather than PASS even when wrapper exit, row_gate, evidence files, redacted evidence, and error scans are clean. Route to Manager for scope/runner disposition before the next row opens.

## Improvement: capture GPU process evidence during live rows

Condition:
- A QA execution row requires CUDA runtime evidence and the row is long enough to sample while `llama-server.exe` is still running

Action:
- Do start a timed `nvidia-smi` sampler or capture `nvidia-smi` after the wrapper side log reports the launched server PID, before waiting for the row to finish. Keep startup CUDA log lines as backend evidence, but do not rely on an after-live `nvidia-smi` sample for process GPU-memory proof because the row script may have already stopped the server.

## Improvement: persist background wrapper exit codes

Condition:
- A QA execution wrapper is launched with `Start-Process` or another background process so the session can poll side logs, sample GPU state, or collect live evidence while the row runs

Action:
- Do keep the returned process object or process id in the same PowerShell invocation that will wait for completion, call `WaitForExit()` before classifying the row, and write the wrapper `ExitCode` to a preflight artifact. If the wrapper is launched from a short `shell_command` and later polling happens in separate tool calls, create a watcher in that same launch command that waits and writes the exit artifact after the process exits. Do not rely only on `row_gate`, `batch_end`, wrapper `ok=True` side-log lines, or a later `Get-Process` absence when the active gate explicitly asks for wrapper exit 0; those lines can support the finding, but the OS exit code should be preserved as first-class evidence.

## Improvement: apply longrun resource thresholds after warmup

Condition:
- A longrun row evidence summary defines working-set or handle-count thresholds "after warmup", and early samples show one-time growth before the process plateaus

Action:
- Do calculate full-run and post-warmup windows separately before classifying the row. Use the row's snapshot cadence or first 30 minutes as the warmup boundary when the plan does not define a stricter one. Report the full-run growth as context, but base the stability verdict on the post-warmup window plus liveness, final metrics, error scans, and process status.

## Improvement: avoid colon-adjacent PowerShell interpolation in QA helpers

Condition:
- Writing one-off PowerShell analysis helpers that format strings containing a variable followed immediately by a colon, such as evidence scan labels, file counters, link-check diagnostics, or `path:line` output

Action:
- Do use the `-f` format operator or `${name}` braces instead of `"$name:..."`. PowerShell parses `$name:` as a scoped variable prefix and can fail before evidence or link analysis runs.

## Improvement: write QA step exit evidence immediately

Condition:
- Running PowerShell QA preflight, build, or test steps through helper functions that collect step results for a later summary file

Action:
- Do write each step's exit code, elapsed time, and log path to disk immediately after the step finishes, or use an explicit script-scoped collection. Do not rely on appending to an outer variable from inside a function unless the scope is explicit, because PowerShell can leave the final summary empty even when the commands ran correctly.

## Improvement: make durable QA review records discoverable

Condition:
- Creating a durable QA review record under `._design_docs/cache-handling-test-plan/` while the reviewed plan or index already has unrelated dirty changes

Action:
- Do add the minimal parent-plan and document-index links needed to make the new review record discoverable, but report those link edits separately from pre-existing dirty plan or index changes. Validate links from the edited files after adding the review record.

## Improvement: block on dry-run hangs before live execution

Condition:
- QA execution requires a dry-run gate before live rows, and the runner hangs or times out before writing its machine-readable plan artifact

Action:
- Do stop only the hung runner process, preserve the empty or partial dry-run logs, and classify the session as `BLOCKED-runner-contract` in a fresh durable report. Do not start live rows or duplicate live comparisons until Developer fixes the dry-run gate and the rerun proves route, flags, paths, and CUDA plan evidence.

## Improvement: classify hybrid crash by exact server.err.log end-state

Condition:
- QA rerun of a hybrid cache leg where the runner reports borted-server-unreachable-after-health after a single transport error, and the Server.err.log ends cleanly mid-request with no FATAL/panic/SEGV/OOM/exception line and cache state below budget

Action:

- Do classify this as a separate product bug from any warning-family cascade the prior fix targeted. Count exact warning families with `Select-String -Pattern` and compare counts row-by-row against the prior report to confirm whether the prior fix worked. Note the error-count hash and the exact failing `request_id` because deterministic fixtures produce identical hashes between runs and that is the strongest reproducibility signal. Cite the last cache-state line as evidence the cache did not pin above budget; pair the FAIL with a new product bug-handoff ID (e.g. `D-EXEC-24-02`) instead of closing the loop on the prior fix ID.

## Improvement: verify hybrid fix against multiple legs, not just the failing one

Condition:
- Developer patch targets a hybrid-cache warning cascade (e.g. demote_paylo / mark_payload demotion failed) on a row that previously aborted mid-leg

Action:

- Do verify the fix on the previously-failing leg AND the parallel leg that uses the same hybrid flags. If the cascade count drops to zero on both legs but the parallel leg still fails for a different reason (e.g. separate crash), record the fix as partial-PASS and open a new bug handoff for the remaining failure. Do not close the stage when the original failing row is still FAIL even if the warning cascade itself is gone.

## Improvement: distinguish last-OK from first-error when a server crash is silent

Condition:

- Stage rerun shows a hybrid leg server died mid-leg with no FATAL/OOM/SEGV/exception in server.err.log, and the prior run also died silently with a different first-failure request_id

Action:

- Do report BOTH `last_ok_request_id` and `first_error_request_id` in the durable report's bug section, not just the first error. A matching `last_ok_request_id` across runs (e.g. `s03-new-5` recurring in both -05 and -06 despite different first-failure points) is a stronger reproducibility signal than the first-error index, because the deterministic workload sends the same request sequence each leg and identical last-OK confirms the crash window is bounded. Cite cache state at death and the last log-line timestamp to bound the crash window. Pair the FAIL with a NEW bug handoff ID, not the prior ID, because the crash root cause is distinct from any warning cascade the prior fix targeted.


## Improvement: redirect runner output via *> instead of Tee-Object for long-running scripts

Condition:
- QA session launches a long-running runner script (10+ min per leg, 4+ legs) via & path\to\script.ps1 ... 2>&1 | Tee-Object -FilePath  and the live log file stays empty until the entire pipeline completes

Action:
- Do use file redirect *>  2>&1 (or >  2>&1) instead of Tee-Object -FilePath when the runner runs as a background async terminal. Tee-Object buffers output in the pipeline and only writes to the file when the upstream completes, so live-tail polling sees 0 bytes for the entire run. The redirect form flushes incrementally through PowerShell's file handle, making the live log readable from the first command output. Keep Tee-Object for short interactive runs where you also want the output in the terminal; switch to *> for long-running captures where live evidence matters more than synchronous stdout.

## Improvement: capture SEH dumps in runner by passing --crash-dump-dir

Condition:
- Stage 24+ rerun is expected to reproduce a silent server crash (D-EXEC-24-0X) and the test plan part-07 row TP-NN-IT-02 says "hybrid leg PASS or crash-with-dump"

Action:
- Do not assume the runner script passes --crash-dump-dir to llama-server.exe. Read stage24-chat-s02-s03-comparison.ps1 line 933-934 (the $args construction in Invoke-Leg); if --crash-dump-dir is not in the $LegPlan.server_flags array, the SEH filter is NOT installed and a real crash produces no minidump. Either (a) record in the report that the crash-without-dump classification is a runner-script gap, not a Stage N product defect, or (b) extend the runner's Get-ServerFlags to accept a -CrashDumpDir parameter and splice it into the flag list for crash-reproduction runs. Do not classify a silent crash as a regression without first checking whether the SEH filter was actually enabled in the launch.

## Improvement: normalize CRLF to LF on every new QA markdown file

Condition:
- QA session uses create_file to write a new markdown report under ._design_docs/... on Windows

Action:
- Do not trust git diff --check exit code on the freshly-written file. Windows create_file writes CRLF (CR + LF) by default, which git diff --check flags as trailing whitespace on every line (CR before LF). Rewrite the file with ReadAllText + Replace('
','
') + WriteAllText immediately after creation. Verify CR byte count is 0 via [System.IO.File]::ReadAllBytes and re-run git diff --check --no-index /dev/null D:\source\llama.cpp-jet\.agents\skills\self-improvement\assets\qa.md to confirm zero warnings. Do not rely on Get-Content for this verification because PowerShell normalizes line endings on read and hides CR.
## Improvement: validate mid-leg crash signature against pre-fix baseline before classifying fix as failed

Condition:
- QA execution rerun after Developer fix targets a mid-leg crash that produced a stable signature in prior runs (e.g. S03 hybrid dies at exactly request 258 with cache state 502.5 MiB / 637 tokens) and current run shows the same signature, but a different code path was the fix target

Action:
- Do compare the current crash signature (last OK request, first failed request, cache state at death, log tail, dump presence) against the pre-fix baseline before declaring the fix FAILED. If signatures match exactly across runs, the original bug is unaddressed; if signatures differ, the original bug is eliminated and a new bug is exposed. Cite both runs request indices and cache state in the report so Manager can distinguish "fix did not work" from "fix worked but exposed a separate bug". Don't accept STILL_REPRODUCED as the full verdict; name whether the fix removed the targeted crash path or left it intact.

## Improvement: verify runner-written minimal report before overwrite

Condition:
- QA execution run completes and runner auto-writes a minimal durable report at the whitelisted path (e.g. test-report-YYYYMMDD-NN.md with about 10 lines and just a summary table), but QA needs to write the full evidence report with per-leg details

Action:
- Do Remove-Item the minimal file before create_file, otherwise create_file fails with File already exists. Verify with Get-Content path | Measure-Object -Line first to confirm file size. After full report written, run get_errors on the markdown path to confirm zero lint errors (MD032 blank-lines-around-lists, MD040 fenced-code-language, MD037 no-space-in-emphasis from underscores in C symbols like exit and endthreadex, MD047 single-trailing-newline). Append a single trailing LF if ReadAllBytes shows last byte is not 0x0A.

## Improvement: verify driver Main dispatcher actually calls the implementation-phase functions

Condition:
- QA test plan or QA review of an Architect implementation review finds that a multi-phase driver script has all the per-phase functions implemented (Phase 0 / Phase 1 / Phase 2 / Phase 3 helpers) and the implementation review marks each step DONE, but the driver's Main / entry-point dispatcher does NOT actually call those functions on the full execution path (only via dedicated switches like -DryRun or -OutputEquivalenceOnly)

Action:
- Do read the Main function byte-by-byte and confirm that every phase helper invoked by the design is reachable from the full-execution code path, not just from a smoke-test switch. A Phase 2 cycle loop implemented as `Invoke-CycleLeg` that is never called from Main produces zero per-leg summary.json rows; the report emitter then writes an empty table. The "DONE" status from the implementation review is satisfied (function exists) but the contract is unmet (no rows). Record the gap as a BLOCKING finding in the QA test plan or review with the exact Main line range, the missing call sites, and a suggested Developer fix that extends Main to call the phase helpers in order. Cite the implementation review's DONE-by-function table row that missed the wiring gap. Do not trust a "DONE" status on a function alone when the dispatcher is silent on that function.

## Improvement: verify cited line range matches the actual content before quoting

Condition:
- QA author drafts a test plan or review that cites a specific line range (e.g. design part-03 L64-72 for output equivalence) and uses the cited content as evidence for a row contract

Action:
- Do not trust the line range without byte-level verification. Read the cited file at the cited line range and confirm the actual content matches the cited claim. Common drift: off-by-7 to off-by-15 lines because the cited range was eyeballed against a previous session's read or against a stale copy. Cross-check with `Get-Content path | Select-Object -Skip (start-1) -First (end-start+1)` or equivalent. If the cited content does not match, edit the row to cite the correct line range before handoff. Do not block the review on a citation drift when the substance is correct and the cited range is in the same neighborhood (within ~10 lines); record the drift as an INFO finding and update the citation. Do block when the cited content is in a different section entirely.


## Improvement: test-plan review verdict when underlying BLOCKING was fixed between authoring and review

Condition:
- A QA test-plan review session is run in a NEW fresh session (B) on a test plan authored in a prior session (A). The test plan's "Findings from prior review" section still documents a BLOCKING finding (e.g. F-01 driver contract defect) that was authored against pre-fix state. An intervening implementation-fix gate between session A and session B has resolved the BLOCKING and its review document verifies the resolution (e.g. part-08 impl-fix review PASS with byte-level verification of the driver Main dispatcher).

Action:
- Do not REWORK the test plan solely on the BLOCKING documentation in the "Findings from prior review" section. Read the implementation-fix review document and byte-level verify the driver or code in question in the current session. If the resolution is real, verdict PASS with a NON-BLOCKING finding that flags the historical documentation (e.g. F-RP-NN: "Findings from prior review" section describes pre-fix state; F-01 BLOCKING resolved per <fix-review-doc> PASS 2026-MM-DD; substance rows + PASS criteria remain executable post-fix). The test plan rows + PASS criteria are the binding contract, not the findings section. The findings section is context. Record any line-citation drifts in the findings section (e.g. cited impl log L244 vs actual content at L237) as NON-BLOCKING or INFO findings per the existing `verify cited line range matches the actual content before quoting`rule. Don't make the test-plan review session redo the work of the implementation-fix session; just verify the fix is real and continue.


## Improvement: PowerShell here-string backtick is the escape character, not literal

Condition:
- A QA session needs to append markdown content to a file (memory entry, test report, plan)
  using PowerShell here-string @"..."@ and the content contains literal backticks for inline
  code spans (for example the phrase verify cited inside backticks).

Action:
- Do not put literal backticks inside @"..."@. PowerShell treats the backtick as the escape
  character even in here-strings: a backtick followed by v becomes vertical tab (0x0B),
  a backtick followed by n becomes LF (0x0A), a backtick followed by t becomes tab (0x09),
  etc. The escape sequence consumes the backtick AND the next character, dropping both
  from output. Use single-quoted here-string at-bracket-quote-quote-bracket-at (no escapes)
  where backticks must be literal. If you must use double-quoted here-string, replace each
  single backtick with a doubled backtick to escape it as a literal backtick.
- After writing, verify the file with [System.IO.File]::ReadAllBytes and confirm:
  (1) zero 0x0B vertical tab bytes where backticks should be,
  (2) zero mid-line 0x0A LF bytes injected by backtick-n escape,
  (3) the backtick count matches what you intended.
- If 0x0B is found, fix byte-by-byte: locate the 0x0B, prepend a backtick (0x60), and
  reinsert the character that was eaten (often v, n, r, t, a, b, f, 0, or e depending
  on which escape was triggered).
- Run git diff --check after the fix. The original here-string escape can also introduce
  CR (0x0D) if a backtick-r was interpreted, so normalize CRLF to LF after every here-string
  append using [System.IO.File]::ReadAllText + replace CRLF with LF + WriteAllText with
  UTF8Encoding($false).

## Improvement: cross-check driver literal flag strings against server flag registry

Condition:
- QA session executes a driver script that constructs a server argument list using literal `--<flag>` strings (for example the Stage 29 driver `compare-legacy-vs-hybrid.ps1` L88 used `--cache-cold-dir` but the actual flag registered in `common/arg.cpp:1366` is `--cache-cold-path`), and a child-process launch fails with `error: invalid argument` before the driver can produce any per-leg evidence.

Action:
- Before launching the full driver path, extract every `--` literal from the driver's `Start-Process -ArgumentList` construction and cross-check it against the server's flag registry in `common/arg.cpp`. Run:

```powershell
$literals = Select-String -Path <driver.ps1> -Pattern '"--[a-z-]+"' -AllMatches |
    ForEach-Object { $_.Matches.Value } | Sort-Object -Unique
foreach ($lit in $literals) {
    $flag = $lit.Trim('"')
    $found = Select-String -Path 'common/arg.cpp' -Pattern ([regex]::Escape($flag))
    if (-not $found) { Write-Warning ("UNKNOWN FLAG: " + $flag) }
}
```

- Any unknown flag is a BLOCKING driver bug, not a harness setup gap. Do NOT try to rerun around it or patch the driver in QA session. Record the exact driver line, the expected flag per `common/arg.cpp`, and the one-line Developer fix in the durable report.
- Run the same cross-check for short flags (e.g. `-m`, `-c`, `-lv`) and env vars (`LLAMA_ARG_*`). The registry in `common/arg.cpp` lists both.
- This rule is the post-Stage-29 follow-up to the prior F-01 Main-dispatcher finding. The implementation review verified function definitions and parameter shapes but did not trace literal flag values to the child process. A stronger implementation review grep `--` literals in the driver and cross-check each against `common/arg.cpp` registration before approving the plan.
- Pair the cross-check with a direct server smoke test that boots the binary with the same flag list and confirms `/health` 200 within 60s. If the smoke passes but the driver fails, the bug is in the driver string construction, not the binary.

## Improvement: verify driver dot-sources cover transitive wrapper dependencies

Condition:
- QA reviews an implementation fix or plan that updates a driver script (e.g., `compare-legacy-vs-hybrid.ps1`) which dots a fixed set of lib helpers, and one of those helpers is itself a wrapper that calls functions defined in another lib helper the driver never dots (transitive dependency). The wrapper's header documents its required dot-source order, but the driver ignores it. The defect is latent until QA actually exercises the wrapper's call path: when a prior BLOCKING failure short-circuits before the wrapper is invoked, the dot-source gap stays hidden.

Action:
- Do enumerate the full set of lib helpers the driver dots, then for each direct helper, recursively resolve every function the helper calls (via `Select-String -Pattern '^[a-zA-Z]+\s+function\b'` or `grep -E '^\s*[a-zA-Z-]+\s*\(\s*\{?\s*\$'`) and verify the called function is defined in either (a) a lib helper the driver dots, (b) a lib helper the calling helper dots, or (c) a PowerShell built-in. When the wrapper header documents a required dot-source order (e.g., `. .\lib\agentic-prompt-generator.ps1` first), confirm the driver honours that order. Cross-check by extracting the wrapper's actual `New-ComparisonWorkload` body and verifying each called function name resolves to a definition in the union of dot-sourced libs. Treat any unresolved transitive call as a BLOCKING driver-contract gap and classify affected rows as `BLOCKED-driver-dot-source`, not `BLOCKED-prior-failure`, so the next session surfaces it instead of inheriting it.

## Improvement: verify partial-fix scope when Developer handoff says "fixed"

Condition:
- A Developer fix targets N call sites of a defect (e.g. wrapper MaxIterations plumbing across L107/L142 in wrapper and L147/L149 in driver), but live re-execution still fails because only N-1 of the call sites were plumbed correctly. The fix author may claim "fixed" based on AST parse or static reading, not based on running both call paths through the same wrapper default.

Action:
- Do re-execute every distinct call site path the defect could affect, not just the most-prominent one. When a fix touches a default value (e.g. wrapper `[int] $MaxIterations = 200`) and a per-call override (e.g. driver `-MaxIterations 50` for one specific call), invoke the wrapper with both values and confirm convergence at the wrapper's default `SizeClass`. The same exception trace at the unwired call site (e.g. driver L149 instead of L147) is the canonical signal that the fix was partial. Capture the unwired call site's exception in a control-case log alongside the working call site's successful output. Report the partial scope as a NEW BLOCKING (F-NEW-EXEC-NN) rather than re-classifying the original defect as still-open. Cite the exact line numbers of both the unwired call site and the wired call site so the next Developer handoff scopes the single missing line.

## Improvement: classify wrapper SizeClass vs server per-slot context as design BLOCKER before re-execution

Condition:
- A Stage N driver or wrapper emits prompts of size N tokens (e.g. 12k via `New-AgenticChatPrompt` with `SizeClass='12k'` -> `TargetTokens=12000`), but the server's per-slot context cap is M < N tokens because the model `n_ctx_seq=2048` is binding when `--parallel > 1` (server allocates `n_ctx / n_parallel` per slot). Phase 1 chat completion then returns `400 Bad Request: request (M' tokens) exceeds the available context size (M tokens)`. This is a pre-existing design mismatch that surfaces only when live execution reaches Phase 1 (after Phase 0.5 tokenize-only calls succeed because /tokenize does not require context fit).

Action:
- Do not trust the test plan's "Phase 1 PASS = byte-identical" contract without first verifying that the wrapper's prompt size fits in the server's actual per-slot context. Read the model file (`.gguf` metadata or `server.err.log: n_ctx_seq` line at session start) for `n_ctx_seq`; read the driver defaults for `-c` and `--parallel`; compute `per_slot_ctx = -c / --parallel`; compare against the wrapper's `SizeClassMap` Target values. If `per_slot_ctx < min(Target values)`, classify the affected rows (CC-01, PR-01..03, AG-01..04) as BLOCKED-context-mismatch at execution, not BLOCKED-driver-contract. Run a single diagnostic server with the driver defaults and `Invoke-WebRequest /props` or the n_ctx_seq line from `server.err.log` to confirm the cap empirically. Record both the model n_ctx_seq and the per-slot computation in the test report. Suggested Developer fix candidates: (a) add a smaller SizeClass to wrapper SizeClassMap and the Stage 20 lib ValidateSet, (b) reduce driver --parallel to 1, or (c) increase driver -c so per-slot context >= the largest SizeClass Target.

## Improvement: bytecode audit driver hashtable return through Start-Process -ArgumentList

Condition:
- A QA session re-executes a Stage N driver (e.g. Stage 29 `compare-legacy-vs-hybrid.ps1`) via `Start-Process -FilePath 'pwsh' -ArgumentList $argList -RedirectStandardOutput ... -RedirectStandardError ...`. The driver Main dispatcher receives a hashtable return from a helper function via `$wl = Invoke-HelperFn` then accesses `.workload` via `$wl.workload`. The driver writes the path via `Write-Output ("... at " + $wl.workload)`. The redirect captures `0x20 0x20 0x44 0x3A 0x5C ...` (2 leading spaces before `D:\`). Phase 2 / Phase 3 calls to `Get-Content -LiteralPath $wl.workload` then fail with `Cannot find drive. A drive with the name '  D' does not exist.` The bug is reproducible via Start-Process but NOT in a `pwsh -NoProfile -Command { ... }` isolated test (which produced a clean return with no leading whitespace).

Action:
- Do byte-level audit the redirect-captured stdout before classifying as BLOCKED-driver-contract. `Get-Content -Raw -Encoding Byte` the redirect file (e.g. `main.log`); in the byte array, locate the character after the format-string literal "at " (or wherever the bound variable should appear). If two `0x20` (space) bytes precede the drive letter `0x44 0x3A`, that is the canonical signature of this bug. The fix is one of: (a) replace the hashtable round-trip with two sibling string variables (`$wlPath = Join-Path $RunRoot 'workload.jsonl'` declared in Main), (b) post-process with `.Trim()` on the bound value before passing to subsequent calls, or (c) return the path as a `pscustomobject` instead of a hashtable. Because the bug only surfaces under Start-Process -ArgumentList, an isolated `pwsh -Command` test will not reproduce it. Pair the audit with `git show HEAD:<file>` to confirm the broken line is unmodified from the prior QA-fixing effort (i.e. not a regression from a recent fix). Record the bug as NEW BLOCKING with suggested Developer fix and cite the exact line + bytes (the 2 leading spaces between "at " and "D:").
- This is the post-Stage-29 follow-up to the existing "verify partial-fix scope" rule. The existing rule detects partial-fix scope (one of N call sites unwired); this rule detects format-string whitespace introduced by hashtable round-trips through Start-Process. Both manifest as `Write-Output` strings with extra bytes before the variable, but the partial-fix rule is "wrong value", while this rule is "correct value with leading padding".
- This is also distinct from the prior F-RP-NN / driver-dot-source rules: those rule about missing dot-source of transitive lib helpers; this rule is about a wholly-tied-together driver that reaches the cycle legs but fails on the path binding inside Main. Classification label: `BLOCKED-driver-hashtable-padding`. The QA session can route around this by authoring a non-durable QA-only wrapper under `_test_output/` that replicates the cycle flow inline and dot-sources the lib helpers directly, bypassing the buggy Main line.


## Improvement: distinguish Manager claim of fabrication from invocation-context-dependent bug

Condition:
- Manager or user reports a prior-session-claimed bug as "fabricated" with citation of a standalone pwsh -NoProfile -Command test that produced clean hashtable property access, but the durable report cited byte-level evidence (e.g., 3 spaces between "at" and "D:" in a Write-Output line)

Action:
- Do not treat the Manager "fabricated" claim as ground truth without verification. The Driver or helper may have an invocation-context-dependent bug that does NOT reproduce in pwsh -Command but DOES reproduce when the same script is invoked via Start-Process pwsh -File <script.ps1> -ArgumentList @(...). Read the actual main.log/main.err.log on disk with `[System.IO.File]::ReadAllBytes` and dump the relevant bytes; do not trust Get-Content (which strips CR characters). If the byte evidence on disk shows the alleged artefact (e.g., 0x20 0x20 0x20 between two characters), the bug is real but invocation-context-dependent; report it as RE-OPENED with byte-level evidence rather than dropping it. Run the canonical driver at least once in the new session to confirm reproducibility under the same invocation context. Cite both the Manager's verification (clean return under pwsh -Command) and the canonical-driver log bytes (real artefact under Start-Process invocation context) so the next Developer handoff can isolate the root cause rather than treating the finding as already-resolved.

## Improvement: classify rows as BLOCKED-driver-stopped-at-<phase> with real exit code and stderr

Condition:
- Brief directs QA to use ONLY the canonical driver and forbids qa-runner.ps1 or other bypass scripts; the canonical driver crashes mid-execution at a known code location (e.g., L174 Get-Content -LiteralPath) with a specific error message and exit code

Action:
- Do not attempt to fall back to qa-runner.ps1 or any other bypass script. Honor the BLOCKED-driver-stopped-at-<phase> classification for every per-row that depends on the crashed phase. Cite the actual exit code (run a second canonical-driver invocation with minimal -RequestCount to confirm), the actual last stderr line (read main.err.log directly), and the failing source line number with a code link to the canonical driver. Verify Phase 0/0.5/1 outputs are real (Test-Path their cited paths and report actual sizes), and verify per-leg evidence ABSENT (note which summary.json/metrics-after.txt/requests.jsonl files do NOT exist on disk). Reuse the Phase 0.5/1 outputs as PASS evidence where they exist; classify every per-request and aggregated row as BLOCKED-driver-stopped with the cited exit code and stderr. Reserve scope-deviation notes in the report only when budget forces -Cycles/-RequestCount downscoping from test plan spec.

## Improvement: end-to-end gitignore scope for in-tree build artifacts

Condition:
- Setting up a session root under `._test_output/`, capturing setup-env.json, or running tests that read in-tree build files (e.g., `build-cuda/CMakeCache.txt`)

Action:
- Do not try to read gitignored paths via `git show HEAD:<path>`. The path is gitignored because the build artifact belongs to the working tree, not git history. Read it directly with `Select-String -Path 'D:\source\llama.cpp-jet\build-cuda\CMakeCache.txt'` or `Get-Content` instead. Capture the resulting values (CMAKE_CXX_FLAGS_RELEASE, GGML_CUDA:BOOL, CMAKE_BUILD_TYPE) in setup-env.json under explicit fields with the actual file path in the field name or value. If you previously captured the field as 'NOT_FOUND' (because git show returned null), regenerate setup-env.json with corrected fields before citing it in the durable report.

## Improvement: pre-create cold path before launching llama-server in hybrid mode

Condition:
- QA execution runs a canonical driver that passes `--cache-cold-path <dir>` to llama-server for hybrid mode, but the driver does not pre-create the directory; the user brief specifies a non-default path that does not yet exist on disk; the first main run fails at server startup with stderr `cold store: configure failed: root path does not exist` and `/health` timeout within 30s

Action:
- Do pre-create the cold path directory before invoking the canonical driver (e.g., `New-Item -ItemType Directory -Force -Path $CacheColdPath | Out-Null`). This is a harness setup pre-condition, not a modification to driver or production code. Document the pre-creation in setup-env.json so subsequent sessions know the directory existed before the driver started. Also record the F-29-EXEC-19-style finding in the test report so a Developer can fix the driver to call `New-Item` itself.

## Improvement: handle dual dot-prefixed and non-dot-prefixed workspace paths

Condition:
- The user's brief specifies paths like `D:\source\llama.cpp-jet\_design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1` (non-dotted) but the actual on-disk location is `D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1` (dot-prefixed); `Test-Path -LiteralPath` returns False for the non-dotted path while the dotted path exists

Action:
- Do verify the on-disk path before running the driver. Use `Get-ChildItem -Path 'D:\source\llama.cpp-jet' -Force | Where-Object { $_.Name -like '*design_docs*' }` or `cmd /c "dir /B"` to enumerate the actual directory names; both `._design_docs` and `_design_docs` may exist as separate workspaces (one canonical, one from a prior fabricating session). Locate the actual scripts under the dotted path (canonical), then mirror the evidence artifacts to the non-dotted path the brief specifies so the report's citations resolve. Do not assume the brief's paths are correct; verify with `Test-Path -LiteralPath` before citing.

## Improvement: classify BLOCKED-driver-stopped-at-<phase> with byte-level evidence

Condition:
- A QA re-execution must produce a per-row classification even when the canonical driver fatally exits before completing all phases; the prior session's report cited files that did not exist on disk (fabricated); the brief explicitly demands `BLOCKED-driver-stopped-at-<phase>` classification citing exit code and last stderr line

Action:
- Do classify each row that depends on the crashed phase as `BLOCKED-driver-stopped-at-<phase>` with the row's evidence field citing (a) the exit code from `main.exit.txt`, (b) the last stdout line from `main.stdout.log`, (c) the last stderr line from `main.stderr.log` (if any), and (d) the source line of the failing statement in the driver. Use `Test-Path -LiteralPath` to verify every file path before citing it. Do not fabricate or back-fill evidence from a prior session's tree.

## Improvement: mirror run artifacts to brief-specified path for verifiable citations

Condition:
- The user brief specifies a run root or report path that differs from the canonical workspace path (e.g., non-dotted `_test_output/` vs dotted `._test_output/`), and the report's citations must resolve via `Test-Path` to satisfy binding integrity rules

Action:
- Do mirror the entire session's run artifacts to the brief-specified path using `robocopy` with `/E` after the main run completes. Use absolute source and destination paths. Verify with `Get-ChildItem <dst> -Recurse -Force` that the destination has the same files and sizes. Cite the brief-specified path in the durable report; also cite the canonical path as a mirror so future sessions can find evidence via either route.

## Improvement: normalize line endings to LF before claiming doc passes ASCII/LF contract

Condition:
- QA generates a markdown report via `create_file` or `replace_string_in_file` and needs to satisfy ASCII-only / LF-only / no-BOM / no-trailing-whitespace contract; the tool may insert CRLF on Windows

Action:
- Do verify line endings after every doc write with `[System.IO.File]::ReadAllBytes(<path>) | Where-Object { $_ -eq 0x0D } | Measure-Object`. If CR > 0, strip all 0x0D bytes via a `[System.Collections.Generic.List[byte]]` rewrite using `[System.IO.File]::OpenWrite` + `SetLength(0)` + `Write(bytes, 0, bytes.Length)`. Then ensure exactly one trailing LF (0x0A). Verify with `get_errors` to confirm zero markdown lint errors before handoff.

## Improvement: verify Developer fix actually fixes the root cause, not just rearranges code

Condition:
- A Developer fix is documented as DONE in an implementation log part file (e.g. part-22 S29-IMPL-FIX-07), the diff is on disk per git diff HEAD, and the dry-run preflight passes, but the actual driver run still reproduces the same bug with byte-identical output (e.g. 3 leading whitespace bytes 0x20 0x20 0x20 between concatenated string parts)

Action:
- Don't trust a Developer fix just because (a) the diff is on disk, (b) the dry-run preflight returns PASS, and (c) the implementation log marks it DONE. The fix may be insufficient if it changes the code shape without addressing the actual root cause (e.g. adding [string] cast does not strip whitespace from a hashtable property value).
- Run the actual driver end-to-end after every Developer fix, not just the dry-run gate. Capture stdout and inspect the first emitted line as raw bytes ([System.IO.File]::ReadAllBytes + hex dump) to confirm the bug is gone, not just moved.
- When the fix is insufficient, classify it as PARTIAL-fix-ineffective in the QA report and explicitly enumerate what was verified working (e.g. Edit 1 of 2) vs what did not resolve the bug (e.g. Edit 2 of 2). This lets the next Developer iterate on a known-scope sub-bug rather than restart the investigation.
- Cite the byte-identical reproduction (same hex bytes at same offset) to prove the bug is the same one across sessions, not a new variant. The driver line number where the fatal exit happens is a strong corroborator.

## Improvement: verify Developer fix actually fixes the root cause, not just rearranges code

Condition:
- A Developer fix is documented as DONE in an implementation log part file (e.g. part-22 S29-IMPL-FIX-07), the diff is on disk per git diff HEAD, and the dry-run preflight passes, but the actual driver run still reproduces the same bug with byte-identical output (e.g. 3 leading whitespace bytes 0x20 0x20 0x20 between concatenated string parts)

Action:
- Do not trust a Developer fix just because (a) the diff is on disk, (b) the dry-run preflight returns PASS, and (c) the implementation log marks it DONE. The fix may be insufficient if it changes the code shape without addressing the actual root cause (e.g. adding [string] cast does not strip whitespace from a hashtable property value).
- Do run the actual driver end-to-end after every Developer fix, not just the dry-run gate. Capture stdout and inspect the first emitted line as raw bytes ([System.IO.File]::ReadAllBytes + hex dump) to confirm the bug is gone, not just moved.
- When the fix is insufficient, classify it as PARTIAL-fix-ineffective in the QA report and explicitly enumerate what was verified working (e.g. Edit 1 of 2) vs what did not resolve the bug (e.g. Edit 2 of 2). This lets the next Developer iterate on a known-scope sub-bug rather than restart the investigation.
- Do cite the byte-identical reproduction (same hex bytes at same offset) to prove the bug is the same one across sessions, not a new variant. The driver line number where the fatal exit happens is a strong corroborator.
