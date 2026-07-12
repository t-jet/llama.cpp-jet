# QA improvement memory

## Improvement: distinguish Manager claim of N converted call sites from actual diff conversions

Condition:
- QA verifies a Manager claim that N call sites in a test file were converted from `assert(.)` to explicit `if (.) { fprintf + std::abort() }` pattern, and the verification list includes line numbers that mix function definitions with actual call sites

Action:
- Do run `git show HEAD:<file> | Select-String -Pattern '<func_name>\(' | Select-Object LineNumber, Line` to enumerate the call sites that existed at HEAD, then run the same `Select-String` against the working tree. Compare the diff (`git diff <file> | Select-String -Pattern '^[+-].*<func_name>\('`) to count actual conversions. A `+` prefix with new abort pattern and matching `-` prefix with old assert pattern is one conversion. Line numbers that point at the function definition (`static bool name(`) are not call sites and should be excluded from the count. If the working-tree `assert(.)` line is unchanged (no `+`/`-` prefix in diff), it was NOT converted despite any "reverted to assert() form" comment that says otherwise. The "reverted" wording is a misleading developer idiom when the line was never actually converted in the current tree. Report the actual conversion count vs the Manager's claimed count and explain the discrepancy in the verification report; do not silently accept the Manager's count.


## Improvement: Distinguish runner cleanup failures from completed product legs

Condition:

- When a runner classifies cleanup as blocked but the leg artifacts show the workload completed, status counts are good, errors are empty, and the server was stopped intentionally or is already free

Action:

- Classify the product leg from the completed artifacts, then record cleanup as a runner issue only if cleanup evidence is actually missing or harmful. Do not downgrade a completed workload solely because the runner used a conservative cleanup label.
## Improvement: distinguish decision id* from Manager design-gate decisions in test-plan review

Condition:
- Reviewing the stage N test plan that lists binding decisions with prefixes like `decision id*` alongside design-gate decisions like `D17-*` (or analogous stage-scoped decision prefixes)

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


## Improvement: materialize zero-result diagnostic artifacts

Condition:
- QA report cites diagnostic files for empty result sets, such as no forbidden log hits, no HELP/TYPE duplicates, or no metric-label findings

Action:
- Do explicitly create those files as zero-byte or valid empty JSON artifacts and verify `Test-Path` plus file length before citing them. PowerShell pipelines over empty arrays may skip `Set-Content`, leaving no file even though the summary count is zero. If the report says "empty", make the artifact truly empty or change the wording to cite the summary count instead.


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


## Improvement: verify markdown constraints after QA doc edits and fresh part files

Condition:
- Editing reusable QA markdown OR creating a fresh QA part file that must stay under repo line-count, ASCII, LF, and whitespace rules

Action:
- Do draft new standalone QA docs or execution reports against an explicit line budget before the first validation pass, targeting well under 300 with buffer. Measure the physical line count with `@(Get-Content <path>).Count`, not `Measure-Object -Line`; the latter undercounts blank lines on PowerShell and can report dozens of lines below reality (observed 189 reported vs 231 actual on a part-38 file). If a new file exceeds the cap, compact in place rather than splitting unless content truly needs another part. If an existing entry document is already at or over the cap, budget the entry edit before adding links and compact nearby overview text or blank lines in the same patch; do not leave the entry above the repo cap because the new part file is compliant. Verify byte-level hygiene on EVERY new file immediately after creation AND after any line-ending normalization: count CR bytes (target 0), bytes above 127 (target 0), BOM (target absent), trailing-whitespace lines (target 0), and resolve every local relative link from the edited file's own directory. The `create_file` tool writes CRLF endings on Windows even when the source content uses LF, and `git diff --check` does NOT inspect untracked files; a freshly created part file can ship CRLF with no warning. Normalize deliberately with `[System.IO.File]::WriteAllText($path, $content.Replace("`r`n", "`n"), [System.Text.UTF8Encoding]::new($false))` and re-verify CR=0 before the final report. For files under `._design_docs/cache-handling-test-plan/`, sibling design docs resolve as `../cache-handling-phase34-*.md` and test reports as `../.test_reports/*.md`, never `../../cache-handling-*.md`.


## Improvement: separate own QA edits from dirty sources

Condition:
- QA review task uses or indexes documents that are already modified or untracked in working tree

Action:
- Check `git status --short` for reviewed and edited paths before editing. If final `git diff` includes older dirty changes in the same files, separate them from the review-owned patch by comparing against the pre-edit status and the specific lines added during the session. When an index already contains uncommitted same-stage rows or linked part files, report only the row/file added in the current session as your change. Note pre-existing dirty files only as context.


## Improvement: blank line between single-line label and following list

Condition:
- Authoring markdown in `._design_docs/.` with a section that uses a single-line label ending in a colon (e.g. `Design:`, `In scope:`, `Out of scope:`, `Implementation:`, `Prior test plan parts:`) followed by a bulleted list on the next line

Action:
- Do insert a blank line between the label line and the first list item. The pattern `Label:\n- item` triggers markdownlint MD032 "Lists should be surrounded by blank lines" on the first list item, even when the list itself is internally well-formed. The fix is `Label:\n\n- item`. Use a `multi_replace_string_in_file` to add the blank line after every such label; `get_errors` to confirm zero lint errors before handoff. Verified pattern in part file (`Inputs (read in order, all durable):` followed by blank line then list).


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
- Suitable model-backed fixture is available and public probe starts successfully but expected cache-specific counters, timings, checkpoint rows, or strict-prefix acceptance rows remain at zero or placeholder values

Action:
- Classify fixture row as FAIL rather than fixture-unavailable BLOCKED/SKIP. Preserve request, response, metrics, and startup artifacts. Separately note any focused substitute evidence that still passed, but do not let focused PASS evidence override the required live model-backed acceptance row.


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


## Improvement: reconcile gate status and artifact roots across reviewed docs

Condition:
- QA planning or test-plan review includes doc hygiene checks, including re-review after REWORK, and one reviewed gate document has stale stage status or a command artifact root differs from the active convention

Action:
- Update stale gate status and mismatched command roots when file edits are in scope. In no-edit test-plan reviews, classify conflicting gate/readiness status or dotted-prefix command roots as review findings instead of silently tolerating them. Cite the source gate that proves current state and the executable command line that proves the path spelling. In REWORK re-reviews, verify each named correction directly in the current files before returning PASS, and record any remaining hygiene correction in the plan/review handoff so the next owner does not inherit conflicting readiness signals.


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
- Use absolute path for log file (e.g., `D:\.\._design_docs\.test_reports\foo.log`) rather than relative path. Relative paths resolve against new CWD after `Push-Location`, causing file to be written under non-existent subdir and producing path-not-found error while underlying command still runs.


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
- Run both function-body regex scan AND `git show HEAD -- <file> | Select-String <pattern>` to confirm zero diff hits. Report function-body hits as "1 pre-existing (unchanged at HEAD)" and diff hits as "0 added". Cite producer log (e.g., `part file ## Diff evidence`: 19 insertions, 0 deletions) as authoritative source.


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


## Improvement: Coverage wrapper may fail to produce `.cov` files via Start-Process

Condition:

- A coverage wrapper reports no `.cov` output even though focused test binaries exit successfully and the coverage tool starts

Action:

- Reproduce one focused test with direct coverage-tool invocation and a single export argument string before classifying the source row as failed. If direct invocation produces coverage, classify the wrapper path as defective and cite both wrapper output and direct-run evidence. Then run the required target set directly and classify the row by the direct markdown coverage evidence: if rates are below required floors, report `FAIL`, not `BLOCKED-wrapper`, because coverage was measurable and the wrapper defect did not hide the threshold result.
## Improvement: dedupe OpenCppCoverage merged Cobertura XML by (file, line)

Condition:
- Parsing `OpenCppCoverage.exe --input_coverage A.cov --input_coverage B.cov . --export_type cobertura:out.xml` output to compute union line coverage

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
- Check binary's DLL dependencies with `dumpbin /dependents <test.exe>` before assuming build or assertion failure; CUDA-linked test binaries depend on `cublastress row_13.dll` (CUDA 13.x) or `cublastress row_12.dll` (CUDA 12.x) which are not in default `PATH`.
- Prepend CUDA toolkit `bin\x64\` directory to `PATH` (e.g. `$env:PATH = 'D:\app\cuda_13_2\bin\x64;' + $env:PATH`) before invoking test binary; same fix that makes `llama-server.exe` start in CUDA build.
- Record PATH prefix in test report's environment section so next session does not waste time on same DLL diagnostic.


## Improvement: enforce CUDA-only verdict evidence when requested

Condition:
- User or gate states all tests must run on CUDA, never CPU

Action:
- Verify `GGML_CUDA:BOOL=ON` in the active build directory before build, helper, or endpoint probes. If any CPU build or probe already ran in the same session, mark those artifacts discarded setup evidence and do not use them for verdicts. Require fresh CUDA binary timestamps for every row before recording PASS or FAIL; otherwise mark rows BLOCKED with exact CUDA build/process evidence.


## Improvement: Distinguish Release-build coverage gaps from wrapper bugs

Condition:

- Coverage output is header-only, empty, or reports zero measurable lines while the tested binary itself passes

Action:

- Verify the build includes debug symbols before reviewing denominator math or wrapper behavior. If symbols are missing, classify the row as blocked on build configuration and cite the relevant build flag plus the empty coverage artifact. Only investigate wrapper invocation after a symbol-capable build is confirmed.
## Improvement: verify cited source contains the cited text

Condition:
- Reviewing a test plan (or any QA-authored doc) that cites a specific line range in another document as the verbatim source for a quoted block

Action:
- Don't trust the citation without verification. Open the cited document at the cited line range and confirm the quoted text actually appears there. If the cited source lacks the text but the content matches a different doc (e.g. design instead of tracker), record the citation drift as an INFO finding and note which doc actually holds the text. Do not block the review if the substance is correct and the drift is pre-existing and inherited from an already-approved upstream doc (e.g. design gate already PASSED). When the cited line number itself is off by 1 (e.g. tracker line 42 cited but the stage row is at line 41), record the line number drift in the same INFO finding.


## Improvement: verify Select-String count for cross-line patterns

Condition:
- Reviewing a test plan row that expects a specific count from `Select-String` (or grep with default line-by-line behavior) for a string that spans multiple adjacent source lines (e.g. SRV_ERR on one line, throw on the next line, or two consecutive lines of a multi-line literal)

Action:
- Do not trust the count claim in the test plan row without running the actual `Select-String` command. By default `Select-String` returns one match per line containing the pattern, not one match per logical block; if the pattern appears on N adjacent lines (e.g. canonical check at lines 1419 and 1420 with the same substring in SRV_ERR and throw), the count is N, not 1. If the test plan row says "exactly 1 match" but the actual Select-String returns N matches, record a non-blocking finding noting the wording drift. Cite the actual count and lines in the finding. Do not block the review if the substance is correct (canonical block intact, duplicate gone) and the wording drift is inherited from an already-approved upstream doc. If the drift is fixable with a more specific pattern (e.g. one that matches only the throw line), suggest the fix as the recommended action; otherwise note that the count wording is imprecise but the row is still verifiable.


## Improvement: Avoid marker-looking count continuations in markdown prose

Condition:

- Markdown prose starts a continuation line with `+ N`, `* N`, or `- N` inside a parenthetical or wrapped count expression

Action:

- Reword the parenthetical so marker-looking text is not at line start, or keep the count on one line. Run markdown diagnostics after the edit to confirm the wrapped prose is not parsed as a mismatched list marker.
## Improvement: expand row count to honor post-design Manager amendments

Condition:
- Authoring the stage N test plan from a design-proposal row list (e.g. 13 rows) when a post-design Manager plan-amendment gate decision (e.g. D{N}-IMPL-01) moves contract flags to additional locations (e.g. from compile flags to three linker flags) that the design proposal did not enumerate

Action:
- Do not silently drop the amendment's new contract locations from the row table. Add a focused row (or expand an existing row) to cover the new locations, document the row-count deviation from the design proposal in the test plan header, and cite the Manager plan-amendment gate decision as the reason. The row-count deviation is a non-blocking finding at test-plan review, not a blocker, because the alternative is a test plan that does not fully cover the binding decision. The amendment always post-dates the design proposal by definition; the test plan must reflect the post-amendment state, not the pre-amendment state.


## Improvement: rewrite new markdown with LF endings before git diff --check

Condition:
- QA task creates new markdown file in `._design_docs/.` (or any path `git diff --check` will inspect) using `create_file` or any tool that writes through host PowerShell/Windows file I/O

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


## Improvement: Derive in-flight ETA from side-log cap value

Condition:

- A long-running QA row is still in flight and the runner side log includes a per-row cap value

Action:

- Do parse the cap value and start time from the side log to compute ETA. Do not hard-code the default cap when the runner records a row-specific cap. Report both observed cap and computed cap-exit time in the handoff.


## Improvement: Avoid PowerShell `-replace` backtick line-ending escapes

Condition:

- Editing markdown with PowerShell `-replace` and replacement text contains backtick escape sequences for CR or LF

Action:

- Do not put escaped CR/LF sequences directly in the `-replace` replacement string. Build line endings with `[char]13`, `[char]10`, or use literal .NET string replacement. Verify bytes afterward for unexpected CR, LF, or backtick characters.
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
- Scope the leak scan to the SRV_DBG `cache metadata: source=. method=. degraded=. tokens=. boundaries=.` line family. The pre-existing `log_server_r: request:` and `log_server_r: response:` lines at verbosity 5 echo the full request and response bodies (including any secret/marker/tool-arg inserted in the probe). That is a pre-existing debug log, not a the stage regression. Mark the diagnostic line clean and note the pre-existing log behavior in the report so the next session does not misclassify the request log as a the stage leak.


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
- Don't trust \/quit\ is registered on the current \llama-server\ build. Send the request and capture status first. If 404, fall back to \taskkill /pid\ (no \/F\). If the process was started with \-NoNewWindow\ and is detached, \taskkill /pid\ may not exit the process within 5-10s; record the fallback and use \Stop-Process -Id <pid> -Force\ only after confirming the log file already contains the full request phase (line count, last line content, or both diagnostic lines present for E13-14). The kill mechanism does not lose evidence when the log was complete before the kill. Cite \/quit\ 404 response and force fallback in the test report's process inventory so the next session knows the endpoint is not available and the kill chain.


## Improvement: .test_reports .gitignore ignores new test reports when ! rules precede * rule

Condition:
- Creating a new test-report-YYYYMMDD-NN.md in ._design_docs/.test_reports/ and git add rejects the file with "The following paths are ignored by one of your .gitignore files"

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
- A prior QA report classifies benchmark rows as BLOCKED-no-successful-restores citing a token-length mismatch between the stored entry and the request task (e.g. `entry 30 tokens, task 27 tokens, prefix 27`) and the user asks for a focused rerun that matches the suggested token count (e.g. 30-token prompt) to clear the blocker

Action:
- Do not assume the prior report's structural cause is correct. Run at least two length-matched probes at different token counts (e.g. 29 and 36) using the same fixture and server flags. Build the prompt via `/tokenize` iteratively, send a warmup with `n_predict=0` and `cache_prompt:true`, then run 50 identical requests. If both length-matched probes still produce 0 successful restores AND the LCP log line shows `task N tokens, entry N tokens, prefix N` (perfect prefix match) on every restore attempt, the length-mismatch hypothesis is REFUTED. The real cause is almost always the save path producing entries without checkpoint boundary metadata, which makes the stored entry a regular (non-checkpoint) entry and causes the exact-blob restore check to reject every identical request. Cite the `checkpoint admission skipped (missing checkpoint boundary metadata)` warning from server stderr, the 0 `cache_checkpoint_admissions_total` metric, the 1 `cache_checkpoint_admission_failures_total` metric, and the LCP-found-match count vs no-exact-match count in the report. Reclassify BLOCKED-structural-not-infra (not BLOCKED-no-successful-restores, since the cause is now known) and propose a Manager plan-level decision (reclassify to NOT-IN-SCOPE for the MTP fixture, or Developer task to add checkpoint boundary metadata to the save path). Don't soften the verdict to PASS on the basis of length-matched probe data alone; the absence of a successful restore is the evidence, not the length match. The BPE tokenizer may not land exactly on the suggested token count (e.g. 30 unreachable; 29 closest); record the actual token count and continue.
- Don't claim the prior report was wrong without the second independent probe. One length-matched probe at one token count could in theory hit a BPE edge case. Two probes at different token counts that both fail with the same structural pattern is strong evidence.


## Improvement: llama.cpp /completion timings JSON does not expose total_ms

Condition:
- A bench report or harness collects per-request latency for benchmark rows and the task brief names a total_duration_ms field name to read from the server's timings JSON

Action:
- Don't trust that the /completion response has a timings.total_ms field. The current llama.cpp server exposes only prompt_ms and predicted_ms in the timings struct, and total_ms is absent (or zero if deserialized as a default). Compute total_ms = prompt_ms + predicted_ms in the harness or recompute step, and label the per-request column explicitly as "total_ms (prompt+predicted)" so the next session does not chase a phantom missing field. Cite the prior smoke-test summary (where total_ms was 0 across all rows) as evidence of the missing field, not as a product bug.


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


## Improvement: Preemptive Manager reclassification applies only to matching failures

Condition:

- A Manager decision pre-authorizes reclassification of a specific expected failure, but the executed row no longer fails in that way

Action:

- Do record that the reclassification was not invoked and cite evidence showing the row succeeded or failed differently. Do not apply an expected-fail decision to a passing row. If the matching failure occurs, document the reclassification in the verdict and link it to the Manager decision.


## Improvement: test-output folder name must match the test report ID

Condition:
- A QA test-execution session creates a subfolder under ._test_output/ to hold build logs, ctest output, and benchmark artifacts for a test run, and the run is associated with a durable test report file

Action:
- Do name the subfolder test-report-YYYYMMDD-NN-artifacts/ (or test-report-YYYYMMDD-NN-artifacts/<sub>/ for nested categories) where YYYYMMDD-NN matches the test report filename test-report-YYYYMMDD-NN.md. This is the part file convention: the same ID ties the report to its supporting artifacts
- Do not use generic suffixes like -rerun, -rerun2, -rerun3a, -retry, or -fix2; these break the convention and make it impossible to find the artifacts for a given report
- Do merge multiple intermediate folders from successive reruns into the same test-report-YYYYMMDD-NN-artifacts/ folder rather than creating -rerunN variants; the artifacts from rerun 1, rerun 2, and rerun 3 all support the same report
- Do not commit anything under ._test_output/ (it is gitignored); but do ensure the folder name on disk matches the report ID so a reader can find the artifacts
- When the second exec reuses the first exec's folder (because the build was not re-cleaned), record this explicitly in the second report's evidence column with a note like "shared with first exec"
- Don't reference old -rerun folder names in test-report evidence columns; update them when the convention is applied


## Improvement: avoid nested PowerShell backtick continuations in shell_command

Condition:
- Running a PowerShell script through `functions.shell_command` with an inner `powershell -Command "& script ."` invocation that passes many parameters, especially array parameters such as `-RowsToRun @('stress row',.)`

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
- A stress or longrun wrapper row emits `row_gate . exitCode=0`, but the row server stopped during the request phase or before final scrape, and required files such as `metrics-after.txt`, `evidence-summary.md`, or `cap-exit.json` are missing

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


## Improvement: Validation position matters for bounded-error exits

Condition:

- A test plan row expects a bounded-error exit from a startup validation block, but the block may run after model load, warmup, or another precondition step

Action:

- Verify empirically that the validation block runs before the failing precondition. If the process exits with a crash or non-bounded status before the validation message, classify the row as a startup-path failure even if the validation source exists. Check sibling invalid configurations for a shared earlier root cause.
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
- Do use the `-f` format operator or `${name}` braces instead of `"$name:."`. PowerShell parses `$name:` as a scoped variable prefix and can fail before evidence or link analysis runs.


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


## Improvement: Hybrid crash classification needs exact server log end-state

Condition:

- A hybrid cache leg ends with a transport error, unreachable server, or silent server termination

Action:

- Do inspect the end of server stderr, last cache-state line, request id, and warning/error family counts before assigning a product verdict. Distinguish warning-cascade fixes from new crash signatures. Use deterministic request ids, error-count hashes, and cache-state-at-death as reproducibility evidence.


## Improvement: verify hybrid fix against multiple legs, not just the failing one

Condition:
- Developer patch targets a hybrid-cache warning cascade (e.g. demote_paylo / mark_payload demotion failed) on a row that previously aborted mid-leg

Action:

- Do verify the fix on the previously-failing leg AND the parallel leg that uses the same hybrid flags. If the cascade count drops to zero on both legs but the parallel leg still fails for a different reason (e.g. separate crash), record the fix as partial-PASS and open a new bug handoff for the remaining failure. Do not close the stage when the original failing row is still FAIL even if the warning cascade itself is gone.


## Improvement: distinguish last-OK from first-error when a server crash is silent

Condition:

- Stage rerun shows a hybrid leg server died mid-leg with no FATAL/OOM/SEGV/exception in server.err.log, and the prior run also died silently with a different first-failure request_id

Action:

- Do report BOTH `last_ok_request_id` and `first_error_request_id` in the durable report's bug section, not just the first error. A matching `last_ok_request_id` across runs (e.g. `stress row-new-5` recurring in both -05 and -06 despite different first-failure points) is a stronger reproducibility signal than the first-error index, because the deterministic workload sends the same request sequence each leg and identical last-OK confirms the crash window is bounded. Cite cache state at death and the last log-line timestamp to bound the crash window. Pair the FAIL with a NEW bug handoff ID, not the prior ID, because the crash root cause is distinct from any warning cascade the prior fix targeted.


## Improvement: redirect runner output via *> instead of Tee-Object for long-running scripts

Condition:
- QA session launches a long-running runner script (10+ min per leg, 4+ legs) via & path\to\script.ps1 . 2>&1 | Tee-Object -FilePath  and the live log file stays empty until the entire pipeline completes

Action:
- Do use file redirect *>  2>&1 (or >  2>&1) instead of Tee-Object -FilePath when the runner runs as a background async terminal. Tee-Object buffers output in the pipeline and only writes to the file when the upstream completes, so live-tail polling sees 0 bytes for the entire run. The redirect form flushes incrementally through PowerShell's file handle, making the live log readable from the first command output. Keep Tee-Object for short interactive runs where you also want the output in the terminal; switch to *> for long-running captures where live evidence matters more than synchronous stdout.


## Improvement: Crash-dump expectations require crash-dump flag wiring

Condition:

- A test plan or rerun expects crash dumps or SEH evidence from a server process

Action:

- Do inspect runner argument construction before classifying missing dumps. If the runner did not pass the crash-dump flag to the server, report a runner gap rather than a product no-dump regression. Add or request explicit crash-dump-dir wiring before relying on dump presence as evidence.


## Improvement: normalize CRLF to LF on every new QA markdown file

Condition:
- QA session uses create_file to write a new markdown report under ._design_docs/. on Windows

Action:
- Do not trust git diff --check exit code on the freshly-written file. Windows create_file writes CRLF (CR + LF) by default, which git diff --check flags as trailing whitespace on every line (CR before LF). Rewrite the file with ReadAllText + Replace('
','
') + WriteAllText immediately after creation. Verify CR byte count is 0 via [System.IO.File]::ReadAllBytes and re-run git diff --check --no-index /dev/null D:\source\llama.cpp-jet\.agents\skills\self-improvement\assets\qa.md to confirm zero warnings. Do not rely on Get-Content for this verification because PowerShell normalizes line endings on read and hides CR.


## Improvement: Mid-leg crash fixes need baseline signature comparison

Condition:

- A rerun after a fix still crashes during a long leg, but the fix targeted a specific prior crash

Action:

- Do compare the new crash signature, request id window, error-count hash, and cache-state-at-death against pre-fix evidence before calling the fix ineffective. Same signature means likely unresolved prior bug; different signature means a new failure path. Record the distinction in the report.


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
- QA author drafts or updates a test plan, review, or re-review that cites a specific line range (e.g. design part file L64-72 for output equivalence) and uses the cited content as evidence for a row contract

Action:
- Do not trust the line range without byte-level verification. Read the cited file at the cited line range and confirm the actual content matches the cited claim. Common drift: off-by-7 to off-by-15 lines because the cited range was eyeballed against a previous session's read, against a stale copy, or before a later correction note shifted the file. Cross-check with `Get-Content path | Select-Object -Skip (start-1) -First (end-start+1)` or equivalent after the last doc edit. If the cited content does not match, edit the row to cite the correct line range before handoff. Do not block the review on a citation drift when the substance is correct and the cited range is in the same neighborhood (within ~10 lines); record the drift as an INFO finding and update the citation. Do block when the cited content is in a different section entirely.


## Improvement: test-plan review verdict when underlying BLOCKING was fixed between authoring and review

Condition:
- A QA test-plan review session is run in a NEW fresh session (B) on a test plan authored in a prior session (A). The test plan's "Findings from prior review" section still documents a BLOCKING finding (e.g. the finding driver contract defect) that was authored against pre-fix state. An intervening implementation-fix gate between session A and session B has resolved the BLOCKING and its review document verifies the resolution (e.g. part file impl-fix review PASS with byte-level verification of the driver Main dispatcher).

Action:
- Do not REWORK the test plan solely on the BLOCKING documentation in the "Findings from prior review" section. Read the implementation-fix review document and byte-level verify the driver or code in question in the current session. If the resolution is real, verdict PASS with a NON-BLOCKING finding that flags the historical documentation (e.g. F-RP-NN: "Findings from prior review" section describes pre-fix state; the finding BLOCKING resolved per <fix-review-doc> PASS <date>; substance rows + PASS criteria remain executable post-fix). The test plan rows + PASS criteria are the binding contract, not the findings section. The findings section is context. Record any line-citation drifts in the findings section (e.g. cited impl log L244 vs actual content at L237) as NON-BLOCKING or INFO findings per the existing `verify cited line range matches the actual content before quoting`rule. Don't make the test-plan review session redo the work of the implementation-fix session; just verify the fix is real and continue.


## Improvement: PowerShell here-string backtick is the escape character, not literal

Condition:
- A QA session needs to append markdown content to a file (memory entry, test report, plan)
  using PowerShell here-string @"."@ and the content contains literal backticks for inline
  code spans (for example the phrase verify cited inside backticks).

Action:
- Do not put literal backticks inside @"."@. PowerShell treats the backtick as the escape
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


## Improvement: Cross-check driver literal flags against server registry

Condition:

- A QA driver builds server arguments from literal `--flag` strings and launch fails before behavior evidence is produced

Action:

- Do compare every literal flag with the server argument registry and any mode-coupled validation before classifying the row. Treat invalid-argument startup failures as driver or harness defects when the flag is unregistered or invalid for the selected mode. Do not proceed to product verdicts until the launch contract is valid.


## Improvement: verify driver dot-sources cover transitive wrapper dependencies

Condition:
- QA reviews an implementation fix or plan that updates a driver script (e.g., `compare-legacy-vs-hybrid.ps1`) which dots a fixed set of lib helpers, and one of those helpers is itself a wrapper that calls functions defined in another lib helper the driver never dots (transitive dependency). The wrapper's header documents its required dot-source order, but the driver ignores it. The defect is latent until QA actually exercises the wrapper's call path: when a prior BLOCKING failure short-circuits before the wrapper is invoked, the dot-source gap stays hidden.

Action:
- Do enumerate the full set of lib helpers the driver dots, then for each direct helper, recursively resolve every function the helper calls (via `Select-String -Pattern '^[a-zA-Z]+\s+function\b'` or `grep -E '^\s*[a-zA-Z-]+\s*\(\s*\{?\s*\$'`) and verify the called function is defined in either (a) a lib helper the driver dots, (b) a lib helper the calling helper dots, or (c) a PowerShell built-in. When the wrapper header documents a required dot-source order (e.g., `. .\lib\agentic-prompt-generator.ps1` first), confirm the driver honours that order. Cross-check by extracting the wrapper's actual `New-ComparisonWorkload` body and verifying each called function name resolves to a definition in the union of dot-sourced libs. Treat any unresolved transitive call as a BLOCKING driver-contract gap and classify affected rows as `BLOCKED-driver-dot-source`, not `BLOCKED-prior-failure`, so the next session surfaces it instead of inheriting it.


## Improvement: Re-execute every distinct call path after driver fix

Condition:

- A fix changes a shared driver or wrapper default, but another call site can override the same value or bypass the fixed path

Action:

- Re-execute every distinct call path the defect could affect, not only the most prominent one. Capture both the working path and any still-unwired path, classify partial fixes explicitly, and hand off the remaining call site without re-opening already-fixed scope.
## Improvement: Compare wrapper prompt size with server per-slot context before execution

Condition:

- A wrapper or driver emits prompts with target token sizes that may exceed the server per-slot context after model and parallelism limits are applied

Action:

- Before running the matrix, read the effective context cap from model metadata or startup logs, compute per-slot context from driver settings, and compare it with wrapper target sizes. If targets cannot fit, classify affected rows as context mismatch and recommend a runner/design adjustment instead of treating startup request rejection as a product-cache failure.
## Improvement: Byte-audit hashtable path values across Start-Process

Condition:

- A PowerShell runner uses `Start-Process -ArgumentList` and consumes hashtable-returned paths from helper functions

Action:

- Do inspect raw bytes of the emitted path and the failing argument, not just displayed text. If leading whitespace appears only in redirected child-process execution, classify it as invocation-context-dependent path corruption and verify any fix through the same `Start-Process` path.


## Improvement: distinguish Manager claim of fabrication from invocation-context-dependent bug

Condition:
- Manager or user reports a prior-session-claimed bug as "fabricated" with citation of a standalone pwsh -NoProfile -Command test that produced clean hashtable property access, but the durable report cited byte-level evidence (e.g., 3 spaces between "at" and "D:" in a Write-Output line)

Action:
- Do not treat the Manager "fabricated" claim as ground truth without verification. The Driver or helper may have an invocation-context-dependent bug that does NOT reproduce in pwsh -Command but DOES reproduce when the same script is invoked via Start-Process pwsh -File <script.ps1> -ArgumentList @(.). Read the actual main.log/main.err.log on disk with `[System.IO.File]::ReadAllBytes` and dump the relevant bytes; do not trust Get-Content (which strips CR characters). If the byte evidence on disk shows the alleged artefact (e.g., 0x20 0x20 0x20 between two characters), the bug is real but invocation-context-dependent; report it as RE-OPENED with byte-level evidence rather than dropping it. Run the canonical driver at least once in the new session to confirm reproducibility under the same invocation context. Cite both the Manager's verification (clean return under pwsh -Command) and the canonical-driver log bytes (real artefact under Start-Process invocation context) so the next Developer handoff can isolate the root cause rather than treating the finding as already-resolved.


## Improvement: end-to-end gitignore scope for in-tree build artifacts

Condition:
- Setting up a session root under `._test_output/`, capturing setup-env.json, or running tests that read in-tree build files (e.g., `build-cuda/CMakeCache.txt`)

Action:
- Do not try to read gitignored paths via `git show HEAD:<path>`. The path is gitignored because the build artifact belongs to the working tree, not git history. Read it directly with `Select-String -Path 'D:\source\llama.cpp-jet\build-cuda\CMakeCache.txt'` or `Get-Content` instead. Capture the resulting values (CMAKE_CXX_FLAGS_RELEASE, GGML_CUDA:BOOL, CMAKE_BUILD_TYPE) in setup-env.json under explicit fields with the actual file path in the field name or value. If you previously captured the field as 'NOT_FOUND' (because git show returned null), regenerate setup-env.json with corrected fields before citing it in the durable report.


## Improvement: Pre-create cold path before launching hybrid server

Condition:

- QA execution runs a canonical driver that passes a cold-store path to the server, but the path does not yet exist and the server requires an existing root

Action:

- Create the cold path as setup before invoking the canonical driver, and document that setup in the environment evidence. Also record a Developer handoff if the driver itself should create the directory in future runs.
## Improvement: Verify dot-prefixed durable paths before running scripts

Condition:

- A brief specifies a durable-doc or test-script path whose dotted prefix may differ from the actual on-disk directory

Action:

- Verify the path with `Test-Path` and directory listing before running or citing it. Prefer the canonical dotted durable-doc path when both dotted and non-dotted directories exist, and mirror artifacts only when the brief requires a compatibility citation path.
## Improvement: Driver-stopped classifications need byte-level evidence

Condition:

- A QA report must classify rows after the canonical driver exits fatally before completing all phases

Action:

- Do verify every cited file with `Test-Path`, read exit-code and stderr artifacts directly, and record absent per-leg artifacts explicitly. Do not fabricate or infer row evidence from prior sessions. Use byte-level checks for paths or logs when the failure may involve hidden whitespace or encoding artifacts.


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
- A Developer fix is documented as DONE in an implementation log part file (e.g. part file stress row-IMPL-FIX-07), the diff is on disk per git diff HEAD, and the dry-run preflight passes, but the actual driver run still reproduces the same bug with byte-identical output (e.g. 3 leading whitespace bytes 0x20 0x20 0x20 between concatenated string parts)

Action:
- Do not trust a Developer fix just because (a) the diff is on disk, (b) the dry-run preflight returns PASS, and (c) the implementation log marks it DONE. The fix may be insufficient if it changes the code shape without addressing the actual root cause (e.g. adding [string] cast does not strip whitespace from a hashtable property value).
- Do run the actual driver end-to-end after every Developer fix, not just the dry-run gate. Capture stdout and inspect the first emitted line as raw bytes ([System.IO.File]::ReadAllBytes + hex dump) to confirm the bug is gone, not just moved.
- When the fix is insufficient, classify it as PARTIAL-fix-ineffective in the QA report and explicitly enumerate what was verified working (e.g. Edit 1 of 2) vs what did not resolve the bug (e.g. Edit 2 of 2). This lets the next Developer iterate on a known-scope sub-bug rather than restart the investigation.
- Do cite the byte-identical reproduction (same hex bytes at same offset) to prove the bug is the same one across sessions, not a new variant. The driver line number where the fatal exit happens is a strong corroborator.


## Improvement: avoid self-matching process cleanup during budget stops

Condition:
- QA must stop a long-running driver or server after a wall-clock budget, and cleanup uses `Get-CimInstance Win32_Process` or command-line substring filters that include the run id, script name, or command text

Action:
- Do first stop the concrete server process by name or known PID, then enumerate candidate driver processes with full command lines and exclude the current PowerShell process id and any wrapper whose command line contains the cleanup query itself. Kill only the exact driver PID whose command line starts with `pwsh -NoProfile -File <driver.ps1>` and contains the target run id. Re-query after cleanup with an exact driver-script predicate, and treat self-matching query wrappers as noise rather than failed cleanup.


## Improvement: verify hybrid cache_hits_total against actual duplicate message distribution before reporting FAIL

Condition:
- QA classifies the Hybrid reuse row of a full-comparison run as FAIL because `llamacpp:cache_hits_total{mode="hybrid"}` stayed at 0 across all completed hybrid legs, but the workload generator marked N requests as `cache_class=exact` without verifying how many actual duplicate message hashes exist and how spaced the duplicates are

Action:
- Do compute the unique-message-hash distribution among the cache_class=exact requests before classifying Hybrid reuse as FAIL. For each `cache_class=exact` request, hash the messages payload with SHA-256 and group by hash. If the unique-hash count equals the request count, the workload has no actual duplicates and 0 hits is expected regardless of cache health. If the unique-hash count is smaller, examine spacing: a hot cache of N entries can retain at most N anchor messages; if the duplicate spacing exceeds N requests, the second occurrence will miss.
- Do record the hot cache budget (`--cache-ram`) and observed per-entry size from the metrics-after `cache_bytes` and `cache_entries` to compute the actual hot cache capacity. Compare capacity to the workload duplicate spacing.
- Do also inspect the metrics-before of the warm cycle hybrid legs. If `cache_entries=0` at start, the cold-store is not auto-loaded into the hot cache at server start; this is a separate product observation, not a the stage driver-extraction regression.
- When 0 hits is observed but the workload is too sparse for the hot cache to retain duplicates, record the verdict as FAIL with a `workload-design` finding so the Developer can reclassify. Do not silently accept the runner classification without computing the unique-hash distribution and capacity-vs-spacing comparison.

## Improvement: compare concurrent expected-hit misses against a sequential same-server baseline

Condition:
- QA classifies live concurrent replay where the expected-hit analyzer predicts hot exact-hit rows and the concurrent run returns zero cached tokens for some of those rows

Action:
- Do compare the concurrent run to a sequential run from the same server process, same transcript, same expected-hit table shape, and same cache budget before choosing the blocker class. If sequential proves every predicted hot exact hit and concurrent misses only a subset while HTTP, namespace count, and logs stay clean, classify as a concurrent cache reuse or runner ordering failure, not transcript incompleteness, budget under-sizing, or startup failure. Record the exact missed request ids and the matching `cache_hits_total` delta so Developer can reproduce the gap.

## Improvement: compare artifact-root prose against executable commands

Condition:
- Reviewing a QA test plan that defines a fresh per-session output root and also includes command checklists or runner examples

Action:
- Do compare every prose artifact-root requirement with every `-OutputDir`, `-OutDir`, durable report path, and row-specific path in the command examples. Treat dotted-prefix differences such as `._test_output` versus `_test_output` as blocking when the plan could split one session's evidence across two roots. When correcting the plan, choose the root that matches the active row family and existing runner convention, then update prose, commands, evidence bullets, path checks, and handoff/index text to use the same spelling before execution.

## Improvement: keep PowerShell validation one-liners simple

Condition:
- Running QA hygiene or link-check validation as inline PowerShell against docs

Action:
- Do use explicit loops, temporary variables, and the `-f` format operator for path/line output. Assign `foreach` output to a variable before piping to `Format-Table`, `Where-Object`, or `Measure-Object`; don't place a pipeline immediately after a closing script block when the parser can treat it as an empty pipe element. Don't embed statement-form `if` inside arithmetic expressions, and don't interpolate variables immediately followed by `:` in double-quoted strings; these patterns can turn validation into parser noise and force a rerun before evidence is usable.

## Improvement: classify required coverage target compile failures as failures

Condition:
- QA execution must run a required coverage row, coverage tooling is present, but a focused test target needed by the coverage command fails to compile before the coverage wrapper starts

Action:
- Do classify the coverage row as `FAIL` with the exact compile error and target name. Do not report it as a missing-tool or Manager-approved coverage blocker when OpenCppCoverage or the configured coverage tool exists and the blocker is source or test target compilation. Continue other executable rows, but keep the session verdict failed until Developer fixes the target or Manager changes the required coverage contract.

## Improvement: reconcile split setup logs with later run roots

Condition:
- When QA execution evidence uses one run id for setup/preflight logs and a later run id for the final model-backed run after a harness/report-emission retry

Action:
- Do verify the setup logs predate the final run, the binaries are fresh before traffic starts, and the final run used the same build tree and HEAD. Cite setup logs and final run artifacts separately. Do not reject the final run solely because controller or ctest logs have the earlier retry suffix, but record the suffix split and any transient setup rerun in the report.

## Improvement: prefer direct server introspection over weakening prompt-token evidence

Condition:
- A test-plan correction finds that live script evidence proves only `prompt_tokens > cached_tokens` while the design or plan requires exact full rendered request token length

Action:
- Do search the server's public diagnostic/helper endpoints and existing harnesses for a direct proof path before narrowing the plan. For chat prompts, check whether `/apply-template` can render the request and `/tokenize` can count the rendered prompt with matching tokenization flags. If such endpoints exist, make the script assert `usage.prompt_tokens == rendered_request_tokens` and still assert cache-specific fields such as `timings.cache_n == usage.prompt_tokens_details.cached_tokens`; only narrow plan wording when no direct proof path exists.

## Improvement: isolate prefix proof from reasoning-template history rewrites

Condition:
- A live chat prefix-restore QA workload must prove rendered-token prefix compatibility, but the selected model's chat template rewrites, strips, or reclassifies assistant history through reasoning/thinking tags so replaying the API response cannot render as a strict token prefix

Action:
- Do first inspect `/apply-template` outputs and token arrays for turn1, assistant replay, and turn2 to find the exact mismatch. If the mismatch is template history rewriting rather than cache behavior, use a run-local stable chat template for the live row and save that template as an artifact. Keep the same model, prove prefix compatibility with `/apply-template` plus `/tokenize`, and then classify cache fields, hit delta, and prefix metrics from that corrected workload. Do not classify a product bug until the strict prefix proof passes.
