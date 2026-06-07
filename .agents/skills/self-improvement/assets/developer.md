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
- Classify each non-pass item as product bug, QA harness gap, environment/configuration limitation, design/test-plan mismatch, or acceptable deferred coverage. For model-backed rows, verify run created required precondition metrics or logs before calling it product bug. Update stage implementation status with exact next gate action.

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

## Improvement: Preserve blob line structure on Windows

Condition:
- Restoring or comparing tracked file from Git blob on Windows to repair local edit or line-ending mistake

Action:
- Don't pipe `git show HEAD:path` through `Set-Content`; PowerShell can collapse or rewrite line structure. Use binary-safe restore path or direct Git/cmd redirect, then verify line counts and diff scope before continuing.

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