# Developer improvement memory

## Improvement: Read-only developer review forbids re-running tests or binaries

Condition:
- User request explicitly says "Do NOT run tests" or "Do NOT run the model" for Developer test-results review

Action:
- Rely on QA agent's cited test log files (e.g. `test-cache-controller-fix-l-20260606-01.log`) for PASS/FAIL evidence and cited build log files for build exit codes. Don't invoke `test-cache-controller.exe`, `llama-server.exe`, or any focused test binary to "independently verify" the run; running binary is prohibited side-effect and log file is source of truth. If log file shows expected PASS/FAIL lines, that IS independent verification. Don't add "I re-ran the binary for sanity" step that violates explicit prohibition.

## Improvement: Markdown table cells cannot contain pipe characters

Condition:
- Writing markdown review file with `| Table cell |` row where cell content contains literal `|` (e.g. PowerShell pipeline `git diff ... | Select-String ...`, regex alternation `a|b|c`, shell pipe, or backtick-wrapped command containing pipe)

Action:
- Reword cell to avoid literal `|` inside table cell. Rewrite shell command as phrase like "followed by regex scan for `a`, `b`, and `c`" or move command to fenced code block below table. Don't escape with `\|`; some markdown renderers still treat escaped pipe as column separator. Verify cell renders with expected column count by running markdown linter (e.g. `markdownlint-cli2` rules MD056, MD060) before declaring file clean.

## Improvement: CRLF artifact on git diff --check is reportable but non-actionable

Condition:
- Running `git diff --check -- <untracked-file>` after `git add -N` and file is CRLF (Windows worktree default) with `cr=lf` byte counts, and byte-level `[regex]::Matches($content, '[ \t]+(?=\r?$)')` scan returns 0 matches, and file's tracked siblings are also CRLF

Action:
- Report exit code verbatim (e.g. "git diff --check scoped-rc=2") AND pair with byte-level scan result AND note that rc is CRLF artifact (literal `\r` before `\n` triggers default trailing-space rule on every CRLF line). Don't convert file to LF in same gate to silence check; "Preserve local line endings" rule applies and user did not ask for line-ending cleanup. Byte-level scan and sibling CRLF match are proof of cleanliness, not git diff --check exit code.

## Improvement: Dirty worktree handoff

Condition:
- Changing code or durable planning documents in worktree that already has uncommitted changes

Action:
- Capture pre-existing dirty state before edits. When relevant files already have large unrelated diffs, identify current task's changed paths and behavior with focused searches or line anchors, and distinguish those changes from existing user or prior-agent work in handoff.

## Improvement: Verify untracked documentation edits

Condition:
- Editing documentation file that is untracked in git, or parent documentation directory is untracked

Action:
- Verify changed lines, status text, line counts, and trailing-whitespace state directly with file reads or searches. Run scoped whitespace check for tracked touched paths when available, then report path as changed. Use `Select-String -Pattern '[ \t]+(?=\r?$)'` for trailing whitespace on untracked files, and `[regex]::Matches($content, '[^\x00-\x7F]')` for non-ASCII scans. `git diff --check` is misleading for untracked files: after `git add -N` it runs, but on CRLF worktree content the diff is "empty index" -> "CRLF worktree" and literal `\r` before `\n` triggers default `trailing-space` rule on every CRLF line, so non-zero exit code can be CRLF artifact rather than real defect. Always pair scoped `git diff --check -- <path>` exit code with `Select-String -Pattern '[ \t]+(?=\r?$)'` byte-level scan, and report both together. If byte-level scan returns 0 and file's siblings are CRLF, do NOT convert file to LF in same gate; "Preserve local line endings" rule applies and user did not ask for line-ending cleanup. Don't rely on plain `git diff`; it does not show untracked file content.

## Improvement: Windows server pytest path

Condition:
- Running `tools/server/tests` pytest modules on Windows from repo root and harness tries to launch relative `../../../build/bin/.../llama-server.exe`

Action:
- Rerun focused tests with `LLAMA_SERVER_BIN_PATH` set to absolute built server executable. Use `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` when module preload fixture is unrelated to behavior under test.

## Improvement: Mandatory startup memory order

Condition:
- Task instructions require reading self-improvement memory before any other task action

Action:
- Make first assistant action tool read of self-improvement skill and agent memory before any acknowledgement, commentary update, skill-use announcement, plan, AGENTS.md discussion, analysis, or non-memory tool use. Don't send even brief "I'll load memory first" note until read is complete, including when user pasted repo instructions or note only says memory will be loaded.

## Improvement: Test-results review gate classification

Condition:
- Reviewing QA execution reports for staged gate with FAIL, SKIP, BLOCKED, or misleading runner output

Action:
- Classify each non-pass item as product bug, QA harness gap, environment/configuration limitation, design/test-plan mismatch, or acceptable deferred coverage. For model-backed rows, verify raw artifacts show the required preconditions before calling it product bug: server command, readiness or endpoint status, response shape, metrics when required, and focused log/diagnostic scans. If a leakage scan is clean only because the required diagnostic line is absent, classify the missing diagnostic separately from leakage. Update stage implementation status or review artifact with exact next gate action.

## Improvement: Cross-reference same-day QA follow-up sessions

Condition:
- Writing Developer test-results review on QA execution report and follow-up QA automation/fix session is already in same workspace on same day

Action:
- Scan test_reports directory for next-suffix same-day report before delivering verdict. Reference follow-up session in per-row review where its reusable scripts already address FAIL/BLOCKED rows, so Manager gate decision sees both original blocker and in-flight fix. Don't duplicate follow-up's work. Don't escalate original report's blockers as Developer fix sessions when follow-up QA session already owns harness or script gap.

## Improvement: Replace stale test-report references

Condition:
- Updating existing test-results review for newer or corrected QA report

Action:
- Replace stale report IDs, row statuses, blocker counts, and owner assignments throughout durable review and parent implementation status before handoff.

## Improvement: Extract GGUF templates directly

Condition:
- Adding or refreshing `._test_models/*/chat_template.jinja` fixtures from GGUF model

Action:
- Extract `tokenizer.chat_template` from GGUF metadata first. Validate paired `chat_template_new.jinja` by rendering both files and confirming marked render strips back to original output. Don't copy baseline template from nearby model and assume it matches.

## Improvement: Windows server repro ports

Condition:
- Reproducing llama-server startup behavior on Windows with manually chosen ports

Action:
- Check `netsh interface ipv4 show excludedportrange protocol=tcp` or use known unreserved port range before treating bind failures as product behavior.

## Improvement: --metrics flag required for cache_checkpoint_* verification probes

Condition:
- Probing llama-server public /metrics for cache_checkpoint_* (or any cache controller) rows on stage-10 closure contract, and prior probe scripts or test plan steps omit --metrics from server start command

Action:
- Include --metrics in Start-Process ArgumentList before launching server; /metrics endpoint returns 501 not_supported_error without it, and empty or 0-row body looks like product bug rather than missing flag. Verify flag is present by checking for 501 error in first probe run and re-launching with --metrics added before escalating to focused-substitute evidence.

## Improvement: Hybrid restore timing triage

Condition:
- Hybrid cache metrics report hit, checkpoint admission succeeds, or public completion timing still reports `cache_n=0`

Action:
- Trace full handoff from checkpoint export flags and descriptor span metadata through controller restore, slot launch, and prompt processing. Check request `cache_prompt`, explicit `id_slot` routing, restored token count, and checkpoint/SWA replay guards before treating mismatch as response serialization or test-shaping only.

## Improvement: Split near-limit planning docs early

Condition:
- Creating durable implementation or planning documentation likely to approach 300-line document limit

Action:
- Split entry into short TOC/status file and part files before drafting full content. Don't leave over-limit draft in worktree while reviewing. After any trim or consolidation, run `Measure-Object -Line` immediately to confirm line count actually dropped; paragraph consolidation can grow line count rather than reduce it.

## Improvement: Cache metric defaults across modes

Condition:
- Adding cache metrics sourced from hybrid-only stats but emitted through shared server `/metrics` path

Action:
- Verify metric shape for both hybrid and legacy cache modes. Use safe default values for stats fields legacy controllers do not report.

## Improvement: Preserve local line endings in patch edits

Condition:
- Creating or editing any file on Windows (tracked or untracked) with `create_file`, `replace_string_in_file`, or `multi_replace_string_in_file`, and HEAD or sibling tracked files use LF line endings

Action:
- Inspect resulting byte-level line endings and run scoped `git diff --check` immediately after edit, before declaring worktree clean. `create_file` and `replace_string_in_file` on Windows save as CRLF even when HEAD is LF. `[System.IO.File]::WriteAllText` with `UTF8` adds UTF-8 BOM by default; use `New-Object System.Text.UTF8Encoding($false)`, strip BOM with `if ($content[0] -eq [char]0xFEFF) { $content = $content.Substring(1) }`, convert CRLF to LF with `-replace "\`r\`n", "\`n"` and strip trailing whitespace with `-replace '[ \t]+(?=\r?$)', ''` on every line, so worktree matches HEAD's blob format AND git diff --check exits 0. Trailing-whitespace strip is required because `create_file` and CRLF-to-LF pass can leave tab or space on otherwise-blank diff-context lines, and `git diff --check` reports those even on untracked file once `git add -N` registered. For untracked files, run `git add -N` first so `git diff --check` sees it; use scoped `git diff --check` with file path argument to avoid unrelated global whitespace failures in dirty worktree. Verify with `git diff -w --stat` showing only intended insertions.

## Improvement: Update indexes before mutable keys

Condition:
- Changing cache entries indexed by mutable fields such as use sequence, insertion sequence, namespace, token prefix, or payload residency

Action:
- Capture old index key and remove or update existing index entry before mutating field. Don't add refreshed entry without first proving old index entry was removed.

## Improvement: Strip trailing whitespace when copying terminal output into markdown code blocks

Condition:
- Pasting long block of terminal or build-log output (cmake configure / cmake build / ctest / make / MSBuild) into markdown code fence in implementation log, design doc, or test report, and doc will later be checked with `git diff --check` or per-line trailing-whitespace scan

Action:
- Strip trailing whitespace per line on captured block before pasting (per-line PowerShell `'-replace [ \t]+(?=\r?$), '''` is canonical fix). CMake, MSBuild, and ctest frequently emit trailing-space lines. Always pair paste with per-line `Select-String -Pattern '[ \t]+(?=\r?$)'` scan over final file and fix any matches; don't rely on visual review of code block. Verify with `git diff -w --stat` that only intended insertions remain.

## Improvement: Avoid parallel MSBuild targets sharing objects

Condition:
- Building multiple CMake/MSBuild targets on Windows that share generated projects or object files, especially `server-context.cpp`

Action:
- Build targets sequentially or use one combined build command. Don't launch parallel tool calls for separate MSBuild targets that can race on `ZERO_CHECK`, `server-context.obj`, or shared object outputs; failure can appear as compiler errors mixed with `Permission denied` on generated object files.

## Improvement: OpenCppCoverage binary: export path resolves relative to --working_dir

Condition:
- Running `run_coverage.ps1` and Phase 1 reports `no .cov file produced (exit 0)` for all focused tests even though test binaries exited 0 and `OpenCppCoverage.exe` ran

Action:
- Search for .cov files under `<BuildDir>/bin/<Config>/<OutDir>/cov-binary/` (--working_dir plus relative path) before declaring run failed. OpenCppCoverage's `--export_type binary:<path>` resolves path relative to `--working_dir` even when `<path>` starts with Windows drive letter, and script's `if (Test-Path $covFile)` check looks at expected absolute path. If .cov files are at relative path, copy to expected absolute path and re-run script. Don't assume script's `no .cov file produced` warning means OpenCppCoverage failed; it means check path is wrong, not that instrumentation failed.

## Improvement: Full rebuild needs reconfigure after CMakeFiles wipe

Condition:
- Wiping `build-cov/` build outputs (bin, tools, tests, CMakeFiles) and running `cmake --build build-cov --config Release` expecting full rebuild

Action:
- Run `cmake -S . -B build-cov` first to regenerate per-subproject vcxproj files before invoking `cmake --build`; without reconfigure, post-wipe build only emits one or two link lines and exits quickly because subproject vcxproj files are gone. Verify reconfigure by counting `.vcxproj` files in `build-cov/` (expect ~140+ for full llama.cpp build with tests) before declaring rebuild complete. Don't delete `CMakeFiles/` without plan to reconfigure; MSBuild's `ALL_BUILD.vcxproj` references subproject vcxproj files that only exist after next `cmake` run.

## Improvement: Scope whitespace checks in dirty worktrees

Condition:
- `git diff --check` fails in dirty worktree because unrelated pre-existing files have whitespace errors

Action:
- Rerun `git diff --check -- <touched paths>` for current task files and report both scoped result and unrelated global failure. Don't fix unrelated whitespace unless user asked for cleanup.

## Improvement: Check staged touched content against HEAD

Condition:
- Touched files already have staged or added changes before the current task, and the task requires `git diff --check` evidence

Action:
- Run both scoped `git diff --check -- <touched paths>` for unstaged changes and `git diff --check HEAD -- <touched paths>` for the full staged-plus-unstaged content. Don't treat the first clean check as sufficient when `git status --short` shows `A`, `M` in the index column, or other staged state for touched paths.

## Improvement: File must end with exactly one LF, not zero and not two

Condition:
- Writing or rewriting a markdown or text file on Windows with PowerShell where the user requires LF or sibling tracked files end with a single hex-0A

Action:
- End the file with exactly one trailing hex-0A. Don't append a backtick-n to a join without checking the join's tail first; doubling up yields hex-0A hex-0A and `git diff --check` reports "new blank line at EOF" with exit 2. Don't strip the trailing newline just because the source content didn't visibly show one; tracked git blobs in this repo end with a single LF. Verify with `ReadAllBytes` last byte showing hex-0A and not hex-0A hex-0A before running `git diff --check`.

## Improvement: Preserve blob line structure on Windows

Condition:
- Restoring or comparing tracked file from Git blob on Windows to repair local edit or line-ending mistake

Action:
- Don't pipe `git show HEAD:path` through `Set-Content`; PowerShell can collapse or rewrite line structure. Use binary-safe restore path or direct Git/cmd redirect, then verify line counts and diff scope before continuing.


## Improvement: Live-path dry-run echo should match the planned port

Condition:
- PowerShell driver script has DryRun block that prints plan and exits 0, AND live-path code computes per-iteration port via $portUse =  +  (or similar offset), AND DryRun block hardcoded the base port in the echo string

Action:
- Compute the same per-iteration value in the DryRun block before the echo so the printed plan matches the live run. Don't ship a dry-run echo that says port  when the live run would actually bind $Port + . Smoke-test by running pwsh -NoProfile -File <script>.ps1 -DryRun 2>&1 | Select-Object -First 5 and confirming the printed port matches the live-path arithmetic. Apply to any driver that loops over $SlotCounts, $ProfileList, or similar per-iteration offset.

## Improvement: Subdir creation must live after the DryRun early-exit

Condition:
- PowerShell driver script has DryRun early-exit via if () { ...; exit 0 } AND the script creates a per-variant or per-profile subdir with New-Item -ItemType Directory BEFORE the DryRun check

Action:
- Move the subdir creation to the live path, after the DryRun block. DryRun must leave the filesystem unchanged except for the operator-visible print output. Verify with Test-Path <subdir> after pwsh -NoProfile -File <script>.ps1 -DryRun and confirm the path is absent. If a dry-run echo prints the planned subdir path, that's the right way to communicate the path; the dir itself should not exist until the live run.

## Improvement: Single source of truth for runtime arguments in profile-driven drivers

Condition:
- PowerShell driver script declares per-profile $args array that hardcodes a runtime value (e.g. --model, $ModelPath), AND the live path appends the actual per-profile value via $startArgs =  + @('--model',._design_docs/.test_reports/test-report-20260607-06-fixes.md.model)

Action:
- Remove the runtime value from the per-profile $args array. Live path is the single source of truth. Per-profile $args should contain only structural flags (cache mode, parallel, cache-ram, draft model when it differs from primary). Adding the value twice means the per-profile value overrides the live value, but the per-profile value is usually wrong (hardcoded default instead of profile-specific path). Smoke-test by parsing the file and grep'ing the per-profile $args for runtime values to confirm none remain.

## Improvement: Sub-hour wall-clock needs its own int parameter

Condition:
- PowerShell driver script has -DurationHours (int) parameter and the planned run is multi-hour; user later asks for a 5 min or 10 min sanity run

Action:
- Add -DurationMin (int, default 0) parameter. When $DurationMin -gt 0 use $DurationMin * 60; otherwise fall back to $DurationHours * 3600. Update the dry-run echo to print the active unit. Don't rely on -DurationHours 0 plus a magic minute parameter; the precedence rule (DurationMin > 0 first) is the simple way to disambiguate.
## Improvement: Keep planning-only tasks evidence-scoped

Condition:
- User explicitly asks for implementation planning or docs only and says not to implement code

Action:
- Verify planning deliverables with document checks such as line counts, ASCII/plain-text scans, trailing-whitespace scans, and focused diffs. Don't run build, test, benchmark, coverage, security, or QA execution as evidence unless user opens that activity.

## Improvement: Keep document index state aligned

Condition:
- Changing durable planning document's gate state, review state, or handoff state in documentation set linked from `._design_docs/document-index.md`

Action:
- Check matching document-index entry and update stale status or handoff wording in same session. Don't leave index pointing to already-corrected blocker or outdated next owner.

## Improvement: Convert plan docs fully when implementation lands

Condition:
- Updating implementation-planning documents after code work completes

Action:
- Search touched stage docs for stale phrases such as "plan only", "does not authorize implementation", "Next", "implementation open", and "evidence expected later"; replace them with current implementation-review handoff, real evidence, or explicit not-run scope before final handoff.

## Improvement: Record implementation-plan REWORK corrections in gate docs

Condition:
- Reworking implementation planning docs after an independent plan review returns REWORK with named blockers

Action:
- Update both the parent implementation log and the affected part files with the review verdict, the corrected blocker list, the next re-review gate, and any document-index status wording that changed. Don't only patch the technical plan content while leaving the gate or handoff text saying first review is still next.

## Improvement: Export-ModuleMember errors when dot-sourcing helper scripts

Condition:
- Authoring PowerShell helper script (`lib/*.ps1`) intended to be dot-sourced by other scripts (`. $path` or `& $path` style), and the helper ends with `Export-ModuleMember -Function Name` for "documentation" purposes

Action:
- Don't add `Export-ModuleMember` to a script meant to be dot-sourced. When dot-sourced, PowerShell emits non-terminating error `Export-ModuleMember: ... can only be called from inside a module` on every invocation, and the dot-sourcing script aborts at `if ($ErrorActionPreference -eq 'Stop')` even though the export line is at the end. Remove the line; dot-sourcing exposes all functions in the caller's scope automatically. Verify by running `pwsh -File <entry-script> -DryRun` and confirming no Export-ModuleMember lines appear in the captured stderr/stdout.

## Improvement: Pipeline-then-+ in PowerShell is positional arg to Where-Object

Condition:
- Writing PowerShell that combines a pipeline result with array concatenation on the same assignment, e.g. `$result = $arr | Where-Object { ... } + @('a','b')` or `$flags = $flags + @('x') | Where-Object { ... }`

Action:
- Split into separate statements when the right-hand side mixes pipeline with `+`. PowerShell parser binds the `+` as a positional argument to the pipeline's last cmdlet (typically `Where-Object`), producing `A positional parameter cannot be found that accepts argument '+'.` even when the result type makes the `+` unambiguous. Use `$filtered = $arr | Where-Object { ... }; $result = $filtered + @('a','b')` or `($arr | Where-Object { ... }) + @('a','b')` with explicit grouping. The parser-tokenize test passes in both shapes; only the runtime parameter binder catches this, so always include a `pwsh -File <script> -DryRun` round in syntax verification log.

## Improvement: pwsh -Command backslash-dollar escaping

Condition:
- Running one-liner PowerShell command from PowerShell or pwsh terminal via `pwsh -NoProfile -Command "..."` and command contains `\$var` or `\$null` PowerShell escape sequences

Action:
- Write command to temporary `.ps1` file and invoke with `pwsh -NoProfile -File <path>.ps1`. Don't use `pwsh -NoProfile -Command` with `\$` escapes; outer shell strips backslash and PowerShell sees bare `$var` or `$null` reference that fails to parse, producing `ParserError: Unexpected token '\'` message. Applies to syntax checks, tokenize calls, and any one-liner needing PowerShell variable scoping.

## Improvement: Verify upstream tracking branch against actual upstream

Condition:
- Pre-merge analysis or any merge step assumes local tracking branch is current, especially when Manager plan-change decision overrides design's "single primary `upstream` remote with `master` ref" assumption to use local `upstream_master` branch instead

Action:
- Compare local tracking branch tip to actual upstream default branch tip via `GET https://api.github.com/repos/<owner>/<repo>/compare/<local-tip>...master` call or `commits?per_page=1` endpoint. Record SHA and date of both tips, ahead/behind count, and subject and date of each side. Surface any non-zero gap as new Manager decision in pre-merge report's "Manager decisions requested" section and as numbered risk. Don't open pre-merge triage on range that quietly misses upstream commits; merge log will then have known gap that Architect review cannot recover from.

## Improvement: Plain ASCII scan on humanizer-cleaned report tables

Condition:
- Writing long triage tables in pre-merge report or review report and humanizer pass leaves prose clean but table cells still contain em dashes (U+2014) or other typographic punctuation

Action:
- Run `[regex]::Matches($content, '[^\x00-\x7F]')` scan on file before handoff and replace em dashes with ` - ` (space-hyphen-space) or commas inside table cells. Em dashes are not flagged by `git diff --check` on untracked files, so scan is only defense. Scan also catches smart quotes, non-breaking spaces, and BOM bytes humanizer would otherwise miss.

## Improvement: T114a .h inline coverage lift is not reachable on MSVC

Condition:
- T114a product-only coverage fix targets .h inline method bodies in `tools/server/server-cache-legacy.h`, `tools/server/server-cache-controller.h`, or `tools/server/server-cache-hybrid.h` and build uses MSVC with /Ob1 (OnlyExplicitInline, RelWithDebInfo default) or /Ob2 inlining

Action:
- Don't rely on direct calls, member function pointers, volatile member function pointers, or file-scope #pragma optimize("", off) to credit .h source line. Verified 2026-06-05: adding `__declspec(noinline)` BEFORE return type on inline body accessors of `hybrid_cache_entry` (`size`, `n_tokens`, `resident_payload_bytes`, `has_target_payload`, `has_draft_payload`, `mark_used`) lifted T114a from 0.6974 (2077/2978) to 0.7035 (2090/2971) and `hybrid.h` per-file from 0.5929 (83/140) to 0.7273 (96/132). Body attribution moves from test .cpp call site to .h source line as expected under MSVC /Ob1. Don't split function into forward declaration plus separate _impl() body; MSVC rejects trailing `__declspec(noinline)` after cv-qualifier with C2143; correct placement is before return type. Don't attempt to lift denominator-inflating lines that are pure declarations, structural `};` braces, or un-called function bodies (`policy-lru::plan_evictions`); they need test plan denominator change or new test cases, not noinline annotation.

## Improvement: Verify prompt facts against repo state before acting

Condition:
- Manager or user prompt includes specific quantitative or locational facts about repo (commit counts, file paths, expected content, named build directories) tied to binding decision and prompt treats as given

Action:
- Verify each cited fact with direct git or file command (`git log --oneline <range>`, `git grep`, `git rev-list --parents`, `git diff <ref1> <ref2> -- <path>`, `Test-Path <build-dir>/build.ninja`) before acting on it. Don't propagate prompt's numbers, paths, or expected content into implementation log, evidence section, or merge commit message if they disagree with actual state. Record both prompt's claim and actual value in implementation entry so next reviewer can see discrepancy. If build directory named in prompt is empty (no `build.ninja`, no `bin/`, no `.vcxproj`), look for actual populated build directory and use that, noting substitution in verification evidence.

## Improvement: Verify struct field existence before fix re-apply

Condition:
- Manager/user prompt asks to re-apply fix from prior commit (e.g. `git show <sha>:<path>`) and prompt says to apply small N-change scope to function body, but fix's body references struct fields that may have been renamed, removed, or restructured in current source tree

Action:
- Run `git grep` for each struct field fix body uses (including those accessed via `obj->field`) against CURRENT source tree before applying any change. If field is absent in current struct, do NOT fabricate translation or rename. Do NOT run build expecting success. Record missing field(s) in implementation log and submit blocked/divergence report with specific struct-shape difference (e.g. "fix-mtp uses `buf_configs` paired `ctx`+`buf`; current uses rotating `stc_static` + `stc_compute[2]` containers with separate `bufs` vector"). Surface three options: (1) authorise structural refactor to add missing fields, (2) authorise translated fix using current field names, (3) defer re-apply. Don't treat "follow the fix-mtp naming" instruction as covering missing fields; that instruction anticipates field-name drift, not field absence. Don't run `cmake --build` against changes referencing absent struct members; first compile error provides no useful evidence beyond "the field is missing".

## Improvement: Real-merge build halt may mask other latent duplicates

Condition:
- Fixing real `git merge` build halt caused by redefinition error (C2086, C2264, etc.) in file that both merge parents modified, and Manager binding decision authorized only one specific duplicate removal

Action:
- Run full incremental compile to same target after first duplicate removal, even if manager's binding decision specified only first error; prior build halt at error N may have masked errors N+1, N+2 that fix exposes. If build then halts on second pre-existing duplicate, STOP per binding "build fails for any other reason" rule, document second duplicate with `git blame` evidence, and escalate new Manager decision rather than expanding authorized scope unilaterally. Don't claim first fix is "PASS" in implementation log until incremental compile to binding target succeeds. Don't commit single-fix tree that does not compile; next developer would inherit non-compiling state.

## Improvement: Scope-check regex duplicate candidates before fixing

Condition:
- Regex scan of merged worktree file returns N candidate duplicate declarations (function or static names appearing twice) in file that both merge parents modified

Action:
- Manually verify lexical scope of each candidate pair before applying any fix: class methods, class forwarders (`Foo::method` outside class), and same-name overloads are not true duplicates. Only `static` definitions or free functions in same scope with byte-identical bodies are true duplicates. Don't apply fix based on regex count alone; typical scan of 6800-line server file returns 7-8 candidates, of which 1-2 are real duplicates. Use 5-line-before-and-after context check to confirm scope. Use `git blame` on each copy to confirm two copies came from different parents of merge.

## Improvement: Keep optional runtime failures separate from compile-blocker fixes

Condition:
- Fixing a QA-reported compile blocker and an optional post-build binary run exposes a different runtime assertion or behavior failure outside the reported blocker

Action:
- Do document the runtime failure with exact file, line, command, and exit code, then stop unless the user authorized broader runtime triage. Don't keep exploratory implementation changes that are not needed for the compile fix; revert them before handoff so the final diff stays scoped to the reported blocker.

## Improvement: Runtime blocker authorization can expose cascades

Condition:
- User explicitly opens a correction session for a runtime assertion found after a compile-blocker fix and asks to rerun the focused binary

Action:
- Continue through later assertions from the same focused binary until it passes or a new blocker needs escalation. Classify each later assertion as stale test setup, test-helper drift, or product behavior before editing; keep the fix report updated with the broader root-cause chain and final pass evidence.

## Improvement: Read-only blocker triage should separate fixture, driver, route, and prompt-shape causes

Condition:
- User asks for root cause of a benchmark blocker and names several possible causes, while also saying not to edit files

Action:
- Prove or rule out each named cause with direct evidence from report files, captured driver/server flags, prompt body, fixture/template contents, and the exact production validation branch. Don't stop at the report's verdict text; trace the failure string to code and compare the runtime prompt shape to the metadata contract before classifying as test-framework, fixture, driver, or product bug.

## Improvement: PowerShell rg file lists need explicit expansion

Condition:
- Running `rg` on Windows PowerShell against generated or untracked documentation paths with wildcard arguments such as `dir/*.md`

Action:
- Build an explicit `$paths` array from `Get-ChildItem` and pass that array to `rg`. Don't rely on mixed literal paths plus wildcard strings inside one command; `rg` can receive the wildcard literally and fail with `The filename, directory name, or volume label syntax is incorrect`.

## Improvement: PowerShell foreach output must be collected before formatting

Condition:
- Running a PowerShell one-liner that emits objects from `foreach (...) { ... }` and then pipes directly to `Format-Table`, `Select-Object`, or another command, including quick verification scans after implementation work

Action:
- Collect objects into an array inside the loop, then pipe the array after the loop. For compact scans, start with `$rows=@(); foreach (...) { $rows += [pscustomobject]@{...} }; $rows | Format-Table`. Don't write `foreach (...) { ... } | Format-Table`; PowerShell reports `An empty pipe element is not allowed`, wasting a verification turn.

## Improvement: Use word-boundary scans for forbidden review terms

Condition:
- Verifying a documentation artifact for forbidden terms such as PR, commit, or source patch, and normal technical words may contain those letters as substrings

Action:
- Use word-boundary or phrase-specific regex patterns, such as `\bPR\b`, `\bcommit\b`, and `source patch`, instead of broad substring scans. Don't treat matches inside words like product, prompt, prerequisite, or projector as verification findings.



## Improvement: Multi-config generator junction preserves original .pdb path

Condition:
- CMake multi-config generator (Visual Studio) reconfigure changes CMAKE_BUILD_TYPE or default config in a build directory that already has outputs from a different config, and the new config has no real directory yet

Action:
- Verify whether `build-cov/bin/<NewConfig>` is a real directory or a Windows reparse point (junction) to `build-cov/bin/<OldConfig>` before declaring reconfigure successful. Use `fsutil reparsepoint query <path>`. If junction, the linker's .pdb embeds the resolved path (OldConfig), not the requested NewConfig, and OpenCppCoverage / similar PDB readers will skip the module because the script's --modules pattern (NewConfig) does not match the .pdb's embedded path (OldConfig). Verified 2026-06-07: removing the junction with `cmd /c rmdir` and creating a real directory, then re-linking the test binaries (full link, not incremental, since the previous .exe was at the junction target), produces a 12674-byte .cov with the Release pattern vs 37 bytes (header only) with the junction. Don't try to copy the binaries from OldConfig to NewConfig; the .pdb's embedded module path is from the link invocation, not the file location. When the user reconfigure command uses a different config than the original, ask before doing destructive junction removal; junction removal + re-link is in-scope for "fix coverage config" but destructive of the original output layout.
