# Developer improvement memory

## Improvement: Dot-prefixed design-docs paths and dot-dir PowerShell probes

Condition:

- When a brief or task refers to paths under `._design_docs` (dot-prefixed) but the shell command uses the spellings `_design_docs`, `.\_design_docs`, or strips the leading dot, OR when a recursive `Get-ChildItem` on `.\_design_docs` returns empty silently (no error) on a path that should exist

Action:

- Do use the exact dot-prefixed path (for example `.\._design_docs\...`, with the leading dot on the directory) in PowerShell `Get-Content`, `Get-ChildItem`, and `Select-String -Path`. Plain `.\_design_docs` returns empty results without an error because the directory is `._design_docs`. Treat a no-hit recursive search on a path you expect to exist as a dot-prefix typo before treating the file as missing; confirm with `Get-ChildItem -Force` because dot-prefixed entries may not appear in the default listing. The same applies to other repo dot-prefixed dirs like `._test_models`, `._design_docs`, `._test_output`.

## Improvement: create_file writes CRLF on Windows; durable docs need explicit LF pass

Condition:

- When using the `create_file` tool to create a durable markdown file on Windows where the project convention is LF-only

Action:

- Do follow create_file with an explicit LF conversion pass: read the file with `[System.IO.File]::ReadAllText`, replace `\`r\`n` with `\`n`, then write back with the UTF8-no-BOM overload of `[System.IO.File]::WriteAllText` so no BOM is added and CRLF is gone. Verify with a byte-level CR=0, LF=line count, and BOM first-3-bytes check, because the durable-doc convention for this repo is LF-only no-BOM and create_file alone leaves CRLF on Windows. Do not rely on `git diff --check` alone for untracked new files; pair it with the byte-level check before declaring the file ready.

## Improvement: Concurrent cache reuse differential is product bug, not Stage 33 pattern

Condition:

- A Developer test-results review sees a sequential-vs-concurrent differential on hybrid cache restore: same server, same process, same transcript and same `expected-hits.jsonl`; sequential hits all predicted hot rows, concurrent hits a strict subset; `server.err.log` shows 0 crash, 0 request-error, 0 exception, 0 corruption, 0 ASSERT, 0 error; namespace count stays bounded; hot budget is large enough to hold the full candidate set with headroom; hit and miss rows are interleaved through the workload, not clustered or long-spaced.

Action:

- Do classify as product bug in the concurrent cache reuse path (e.g. `tx_restore` / `try_restore_from_cache` mutex boundary, branch forest index concurrent access, payload descriptor race, pair-state evaluation under concurrent restore). Do not apply the Stage 33 long-spaced-duplicate EXPECTED-BEHAVIOR pattern: that pattern required hot budget too small to retain entries across the duplicate interval; if the hot budget has headroom and the same candidates hit in sequential, the differential is concurrency, not capacity. Do classify any `restore-apply=0` server.log signal as a separate TP-34-OB-03 logging gap (part-37 requires restore-apply to appear whenever `expected_result=hit` resolves), not bundled with the cache reuse FAIL. Do not propose code changes in the review session; hand off to a fresh Developer session for diagnosis and fix.

## Improvement: PowerShell hashtable path values need explicit normalization after redirected Start-Process

Condition:

- A PowerShell driver gets path strings from a hashtable returned by a helper, then passes those paths through a redirected `Start-Process pwsh` execution path

Action:

- Do assign each path to an explicit local `[string]` variable before downstream use. If redirected execution still shows leading whitespace, trim and byte-check the emitted path before passing it to `Get-Content`, child processes, or report output. Do not trust a standalone parent-process probe when the failing path crosses a redirected child process boundary.


## Improvement: Brief line numbers can drift after prior edits

Condition:

- A handoff or brief cites line numbers from a file that may have changed since the brief was written

Action:

- Do re-read the live file with line numbers and locate the target by surrounding text before editing. Treat the brief line number as a hint, not an anchor. Proceed only when the live text matches the intended change.


## Improvement: Release C++ tests must not rely on assert side effects

Condition:

- Writing or modifying C++ tests that run in Release or any build where `NDEBUG` may be defined

Action:

- Do not use `assert(.)` for setup, side effects, or required failure checks. Replace required checks with explicit `if (!cond) { fprintf(stderr, .); std::abort(); }`. Verify the negative path actually fails by temporarily reverting the fix or using a focused failing input. Check compile flags when the file tries to `#undef NDEBUG`.


## Improvement: Baseline crashes must be separated from current fix evidence

Condition:

- A required test pack crashes while verifying a narrow fix, and the crash may predate the current changes

Action:

- Do verify whether the crash reproduces without the current change before blaming the fix. Use a clean rebuild and a baseline run when feasible. If the baseline is already broken, report current-fix evidence separately and hand off the pre-existing crash as its own defect. Do not claim full pack PASS when the baseline cannot reproduce the expected count.


## Improvement: Durable report totals must match per-row sums

Condition:

- When writing or reviewing a durable report that has both an aggregate summary
  line/table and per-row verdict, decision, or triage tables

Action:

- Sum the per-row values yourself across all row tables and compare them to the
  aggregate summary before handoff. If they disagree, treat the row table as
  authoritative, correct the aggregate summary, and rerun the count check before
  declaring the document ready. In review-only contexts where you cannot edit,
  cite the computed total and file the mismatch as a report correction unless
  the active gate says otherwise.


## Improvement: Dirty worktree handoff

Condition:

- When changing code or durable planning documents in a worktree that already has uncommitted changes, especially tracked index/log files that already contain prior stage rows or untracked stage documents

Action:

- Do capture the pre-existing dirty state before edits; when the relevant files already have large unrelated diffs, identify the current task's changed paths and behavior with focused searches or line anchors, and distinguish those changes from existing user or prior-agent work in the handoff. If `git diff` on `document-index.md` or an implementation log includes pre-existing stage entries, state which exact row or paragraph this session added instead of implying ownership of the whole diff.


## Improvement: Verify untracked documentation edits

Condition:

- When editing or creating a documentation file that is untracked in git, or when the parent documentation directory is untracked

Action:

- Do verify the changed lines, status text, line counts, trailing-whitespace state, AND line endings directly with file reads or searches; run a scoped whitespace check for tracked touched paths when available, then report the path as changed. If the hygiene note itself is edited after measurement, rerun the line-count and whitespace checks and record the final values, not the earlier draft values.
- Do include `git status --short` in the handoff evidence for untracked documentation, because `git diff --name-only` and `git diff --check` omit untracked files unless intent-to-add is used. Treat status output as the authoritative changed-path source for new docs when staging is not authorized.
- Use `Select-String -Pattern '[ \t]+$'` for trailing whitespace on untracked files, `[regex]::Matches($content, '[^\x00-\x7F]')` for non-ASCII scans, and a byte-level CR/CRLF count (PowerShell walk over `[byte[]]` content) for line-ending checks, because `git diff --check` only reports tracked files. When the user explicitly requires `git diff --check` on a new untracked file, run `git add -N <path>` first so the diff check includes the file without staging its content, then clear the intent-to-add with `git reset -q -- <path>` before final status if the task did not authorize staging. Don't rely on plain `git diff`, because it does not show untracked file content.
- Use `(Get-Content -LiteralPath $path).Count` for the logical line count and compare it to the LF byte count on LF-only markdown. If a combined PowerShell byte/line probe prints an impossible value such as `lines=0` with nonzero LF bytes, rerun the line count directly before reporting evidence.
-.


## Improvement: Markdown lint catches what byte-level checks miss

Condition:

- When creating durable planning markdown files via `create_file` on Windows (or any path that produces a new untracked markdown file)

Action:

- Do run BOTH byte-level verification (CR=0, LF matches line count, no BOM, no non-ASCII, no trailing whitespace) AND a markdown lint pass (or a manual check for list style consistency and trailing newline) before declaring the file ready; byte-level checks catch line-ending and BOM issues but not markdown semantics like MD004 (unordered list marker style `+` vs `-`), MD047 (single trailing newline at end of file), or MD009 (trailing spaces inside lines). Fix the markdown issues with single-line edits BEFORE the LF conversion pass so the LF pass preserves the fixes and the file ends with exactly one trailing newline. Don't rely on byte-level verification alone; pair it with a markdown lint pass for durable-doc files.


## Improvement: Windows server pytest path

Condition:

- When running `tools/server/tests` pytest modules on Windows from the repository root and the harness tries to launch a relative `../../../build/bin/./llama-server.exe`

Action:

- Do rerun focused tests with `LLAMA_SERVER_BIN_PATH` set to the absolute built server executable; use `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` when the module preload fixture is unrelated to the behavior under test.


## Improvement: std::thread+detach inside llama_server() before model load races with CUDA init

Condition:

- When adding a std::thread that is detached inside `llama_server()` in `tools/server/server.cpp` (or any function that runs before `llama_backend_init()` or `llama_numa_init(params.numa)`), and the thread body performs Windows API calls (CreateFileA, GetProcessWorkingSetSizeEx, GetLocalTime, etc.)

Action:

- Do NOT spawn the thread inside `llama_server()` even when moved after `common_params_parse()`; the race with subsequent CUDA init produces a NULL pointer write in KERNELBASE+0xF9A40 (STATUS_ACCESS_VIOLATION, param[0]=1, param[1]=0) caught by the existing SEH filter. The crash is identical regardless of where in the function the thread is spawned (before or after common_params_parse). Disabling the thread entirely (`server_diag::start_snapshot_thread(crash_dump_dir);` commented out) made all 4 legs run normally. The terminate handler install (`std::set_terminate`) is safe; only the detached thread body is unsafe. Use a different mechanism for sampling (e.g., write snapshots from the main thread on each request, or use pthreads without detach, or sample from inside the request loop). Don't trust std::thread+detach as a fire-and-forget mechanism inside `llama_server()` initialization.


## Improvement: Mandatory startup memory order

Condition:

- When task instructions require reading self-improvement memory before any other task action

Action:

- Do make the first assistant action a tool read of the self-improvement skill and agent memory before any acknowledgement, commentary update, skill-use announcement, plan, AGENTS.md discussion, analysis, or non-memory tool use; don't send even a brief "I'll load memory first" note until that read is complete, including when the user pasted repo instructions or the note only says memory will be loaded.


## Improvement: Cherry-pick list must distinguish code-introducing merges from worktree-artifact commits

Condition:

- When a "merge cycle" cherry-pick plan lists the cycle's first commit as a merge commit that should bring the upstream code, but the diff between the named commit and its single parent is all worktree artifacts (build logs, test reports, coverage HTML) with no production code changes

Action:

- Do inspect `git show <commit> --stat` and `git diff-tree --no-commit-id --name-only -r <parent> <commit>` before assuming the named commit will bring the upstream code. If the named commit is purely artifacts, fall back to the user's stated fallback: do `git merge <upstream-ref> --no-ff -X ours` (or the user's documented strategy) on the integration branch first, then cherry-pick the artifact commit on top so its files are added but no code is duplicated. The plan's fallback (`git merge origin/upstream_master --no-ff -X ours`) brought the code with no conflicts because the -X ours strategy preferred caveman's content for boundary-level conflicts; the 1264 artifact files were then added cleanly by the cherry-pick. Don't try to "force" the cherry-pick to bring code; check the diff structure first.


## Improvement: Cross-merge can split declarations from definitions

Condition:

- When a cross-merge integration builds with unresolved symbols for functions that are declared in headers and referenced by call sites

Action:

- Check the merge parents or source branches for the missing function body before writing a stub. If one lineage contains the full definition, copy it verbatim into the merged file at the correct scope and rebuild. Do not invent a minimal implementation for a merge artifact unless the original definition is genuinely absent.


## Improvement: Cross-merge function signature mismatches

Condition:

- When a cross-merge integration produces compile errors C2065 (undeclared identifier) inside a function body for a parameter that exists in the upstream signature but not the local lineage's signature, even though the body was applied from upstream

Action:

- Do check whether the function signature comes from the local lineage (kept by `-X ours`) while the body was applied from upstream. The signature kept the 3-arg form, but the body references a 4th parameter (e.g., `is_placeholder`). Add the missing parameter to the local signature and update call sites to pass the new value. Don't try to make the body not reference the new parameter; the body is correct, the signature is the local artifact.


## Improvement: Cross-merge rejects caveman's degraded() fallback

Condition:

- When a cross-merge integration's tests fail with an assertion that the helper returned true when the test expected false, and the production code path includes a `degraded() || !boundaries_native` fallback that the upstream branch doesn't have

Action:

- Do remove the fallback from the merged code to match upstream's strict check. The fallback was added by the local lineage to support a specific case (probably non-native or degraded metadata) but it makes the strict boundary check not strict. Removing the fallback from both `validate_checkpoint_descriptor_metadata` and `attach_checkpoint_payload` made the test pass. Don't try to make the test match the fallback; the test is the cycle's expected behavior and the fallback is the local artifact.


## Improvement: Test-results review gate classification and PASS closure proof

Condition:

- When reviewing QA execution reports for a staged gate, including FAIL, SKIP,
  BLOCKED, misleading runner output, or a PASS report used for closure after a
  fix loop

Action:

- Do classify each non-pass item as product bug, QA harness gap,
  environment/configuration limitation, design/test-plan mismatch, or acceptable
  deferred coverage; for PASS closure reviews, verify freshness against the
  last fix/review gate, required PASS/FAIL/BLOCKED counts, cited artifact
  existence, and raw artifact values for each binding metric before saying no
  product bug or execution blocker remains. For model-backed rows, verify that
  the run created the required precondition metrics or logs before calling it a
  product bug, and update the stage implementation status with the exact next
  gate action.


## Improvement: Cross-reference same-day QA follow-up sessions

Condition:

- When writing a Developer test-results review on a QA execution report and a follow-up QA automation/fix session is already in the same workspace on the same day

Action:

- Do scan the test_reports directory for the next-suffix same-day report before delivering the verdict, and reference the follow-up session in the per-row review where its reusable scripts already address the FAIL/BLOCKED rows, so the Manager gate decision sees both the original blocker and the in-flight fix; don't duplicate the follow-up's work, and don't escalate the original report's blockers as Developer fix sessions when the follow-up QA session already owns the harness or script gap.


## Improvement: Replace stale test-report references

Condition:

- When updating an existing test-results review for a newer or corrected QA report

Action:

- Do replace stale report IDs, row statuses, blocker counts, and owner assignments throughout the durable review and parent implementation status before handoff.


## Improvement: Extract GGUF templates directly

Condition:

- When adding or refreshing `._test_models/*/chat_template.jinja` fixtures from a GGUF model

Action:

- Do extract `tokenizer.chat_template` from the GGUF metadata first and validate the paired `chat_template_new.jinja` by rendering both files and confirming the marked render strips back to the original output; don't copy the baseline template from a nearby model and assume it matches.


## Improvement: Windows server repro ports

Condition:

- When reproducing llama-server startup behavior on Windows with manually chosen ports

Action:

- Do check `netsh interface ipv4 show excludedportrange protocol=tcp` or use a known unreserved port range before treating bind failures as product behavior.


## Improvement: --metrics flag required for cache_checkpoint_* verification probes

Condition:

- When probing llama-server public /metrics for cache_checkpoint_* (or any cache controller) rows on the stage-10 closure contract, and the prior probe scripts or test plan steps omit --metrics from the server start command

Action:

- Do include --metrics in the Start-Process ArgumentList before launching the server; the /metrics endpoint returns 501 not_supported_error without it, and an empty or 0-row body looks like a product bug rather than a missing flag. Verify the flag is present by checking for the 501 error in the first probe run and re-launching with --metrics added before escalating to focused-substitute evidence.


## Improvement: Hybrid restore timing triage

Condition:

- When hybrid cache metrics report a hit, checkpoint admission succeeds, or public completion timing still reports `cache_n=0`

Action:

- Do trace the full handoff from checkpoint export flags and descriptor span metadata through candidate selection, controller restore, slot launch, and prompt processing; check request `cache_prompt`, explicit `id_slot` routing, restored token count, and checkpoint/SWA replay guards before treating the mismatch as response serialization or test-shaping only. If an exact match reports `payload_unavailable`, inspect both early residency gates in the restore path and later descriptor validation, because a transient state may be rejected twice even while valid hot bytes remain. If a rerun changes from `payload_unavailable` to `exact_entry_absent`, inspect lookup predicates such as `entry_has_payload_kind_for_restore`, restore-candidate rank/filter logic, selected-payload fallback rules, and descriptor lifetime cleanup such as `remove_payload`; a validation fix is incomplete if candidate selection still hides the descriptor, a stricter precheck blocks the later fallback path, or queued completion can arrive after descriptor erase. If a later rerun keeps the same row, same miss reason, and same hit pattern after a focused fix, and metrics show the fixed fallback path was not exercised, classify the prior root cause as incomplete rather than a distinct new root cause unless new evidence proves divergence., require_hot=true)` also rejected demoting; allowing demoting only when the hot payload record still exists made focused tests pass without forcing an async design.


## Improvement: Split near-limit planning docs early

Condition:

- When creating durable implementation or planning documentation that is likely to approach the 300-line document limit

Action:

- Do split the entry into a short TOC/status file and part files before drafting the full content; don't leave an over-limit draft in the worktree while reviewing. When appending evidence to an unsplit near-cap file, aim for at least a 5-10 line buffer below the cap instead of landing exactly on 300, because later wording fixes can push it over. After any trim or consolidation, run `Measure-Object -Line` immediately to confirm the line count actually dropped, because paragraph consolidation can grow line count rather than reduce it.
- When reporting final line counts for the 300-line cap, use `(Get-Content -LiteralPath $path).Count` or a byte-level LF count so blank lines are included; `Measure-Object -Line` can undercount blank lines and produce a misleading lower number.


## Improvement: Cache metric defaults across modes

Condition:

- When adding cache metrics that are sourced from hybrid-only stats but emitted through the shared server `/metrics` path

Action:

- Do verify the metric shape for both hybrid and legacy cache modes, and use safe default values for stats fields that legacy controllers do not report.


## Improvement: Preserve local line endings in patch edits

Condition:

- When applying manual patches to files that may use CRLF or mixed line endings, or when the tracked file is LF in HEAD but the edit tool saves the worktree as CRLF on Windows

Action:

- Do inspect the resulting diff, `git diff --stat`, and byte-level CR/LF counts before and after any newline cleanup. If a formatter or shell rewrite changes unrelated lines only because of newline normalization or adds a BOM, restore your own changes for that file and reapply the patch narrowly before handoff. Do not normalize a whole source file to LF or CRLF just to appease `git diff --check` unless that matches the file's intended repository style; compare the scoped diff size after cleanup and stop if the stat balloons. On Windows, use `New-Object System.Text.UTF8Encoding($false)` or `[System.Text.UTF8Encoding]::new($false)` for writes, strip any BOM, and verify with `git diff --check` plus a diff/stat that shows only the intended content changes.


## Improvement: CRLF script diffs need byte-level whitespace verification

Condition:

- When a touched PowerShell or script file intentionally remains CRLF in the worktree and scoped `git diff --check` reports trailing whitespace only on added lines that end with CRLF

Action:

- Do verify the diff stat shows only intended content insertions, run `Select-String -Pattern '[ \t]+$'` for real trailing spaces or tabs, and record byte-level CR/LF counts proving the file stayed consistently CRLF. Don't normalize the whole script to LF just to satisfy `git diff --check` when that would create line-ending churn against the local file style.


## Improvement: Update indexes before mutable keys

Condition:

- When changing cache entries that are indexed by mutable fields such as use sequence, insertion sequence, namespace, token prefix, or payload residency

Action:

- Do capture the old index key and remove or update the existing index entry before mutating the field; don't add the refreshed entry without first proving the old index entry was removed.


## Improvement: Avoid parallel MSBuild targets sharing objects

Condition:

- When building multiple CMake/MSBuild targets on Windows that share generated projects or object files, especially `server-context.cpp`

Action:

- Do build those targets sequentially or use one combined build command; don't launch parallel tool calls for separate MSBuild targets that can race on `ZERO_CHECK`, `server-context.obj`, or shared object outputs, because the failure can appear as compiler errors mixed with `Permission denied` on generated object files.


## Improvement: OpenCppCoverage binary: export path resolves relative to --working_dir

Condition:

- When running `run_coverage.ps1` and Phase 1 reports `no .cov file produced (exit 0)` for all focused tests even though the test binaries exited 0 and `OpenCppCoverage.exe` ran

Action:

- Do search for the .cov files under `<BuildDir>/bin/<Config>/<OutDir>/cov-binary/` (i.e., the `--working_dir` plus the relative path) before declaring the run failed; OpenCppCoverage's `--export_type binary:<path>` resolves the path relative to `--working_dir` even when `<path>` starts with a Windows drive letter, and the script's `if (Test-Path $covFile)` check looks at the expected absolute path. If the .cov files are at the relative path, copy them to the expected absolute path and re-run the script; Phase 1's `if (Test-Path $covFile)` will find the copied files, add them to `$covFiles`, and Phase 3 will merge them. Don't assume the script's `no .cov file produced` warning means OpenCppCoverage failed; it means the check path is wrong, not that the instrumentation failed.


## Improvement: Full rebuild needs reconfigure after CMakeFiles wipe

Condition:

- When wiping `build-cov/` build outputs (bin, tools, tests, CMakeFiles) and running `cmake --build build-cov --config Release` expecting a full rebuild

Action:

- Do run `cmake -S . -B build-cov` first to regenerate the per-subproject vcxproj files before invoking `cmake --build`; without the reconfigure, the post-wipe build only emits one or two link lines and exits quickly because the subproject vcxproj files are gone. Verify the reconfigure by counting `.vcxproj` files in `build-cov/` (expect ~140+ for a full llama.cpp build with tests) before declaring the rebuild complete. Don't delete `CMakeFiles/` without a plan to reconfigure, because MSBuild's `ALL_BUILD.vcxproj` references subproject vcxproj files that only exist after the next `cmake` run.


## Improvement: Scope whitespace checks in dirty worktrees

Condition:

- When `git diff --check` fails in a dirty worktree because unrelated pre-existing files have whitespace errors

Action:

- Do rerun `git diff --check -- <touched paths>` for the current task files and report both the scoped result and the unrelated global failure; don't fix unrelated whitespace unless the user asked for cleanup.


## Improvement: Preserve blob line structure on Windows

Condition:

- When restoring or comparing a tracked file from a Git blob on Windows to repair a local edit or line-ending mistake

Action:

- Don't pipe `git show HEAD:path` through `Set-Content`, because PowerShell can collapse or rewrite line structure; use a binary-safe restore path or a direct Git/cmd redirect, then verify line counts and diff scope before continuing.


## Improvement: Keep planning-only tasks evidence-scoped

Condition:

- When the user explicitly asks for implementation planning or docs only and says not to implement code

Action:

- Do verify the planning deliverables with document checks such as line counts, ASCII/plain-text scans, trailing-whitespace scans, and focused diffs; don't run build, test, benchmark, coverage, security, or QA execution as evidence unless the user opens that activity.


## Improvement: Keep document index state aligned

Condition:

- When changing a durable planning document's gate state, review state, or handoff state in a documentation set that is linked from `._design_docs/document-index.md`

Action:

- Do check the matching document-index entry and update stale status or handoff wording in the same session; don't leave the index pointing to an already-corrected blocker or outdated next owner.


## Improvement: pwsh -Command backslash-dollar escaping

Condition:

- When running a one-liner PowerShell command from a PowerShell or pwsh terminal via `pwsh -NoProfile -Command "."` and the command contains `\$var` or `\$null` PowerShell escape sequences

Action:

- Do write the command to a temporary `.ps1` file and invoke it with `pwsh -NoProfile -File <path>.ps1`; don't use `pwsh -NoProfile -Command` with `\$` escapes because the outer shell strips the backslash and PowerShell sees a bare `$var` or `$null` reference that fails to parse, producing a `ParserError: Unexpected token '\'` message. This applies to syntax checks, tokenize calls, and any one-liner that needs PowerShell variable scoping.


## Improvement: Verify upstream tracking branch against actual upstream

Condition:

- When the pre-merge analysis or any merge step assumes a local tracking branch is current, especially when a Manager plan-change decision overrides the design's "single primary `upstream` remote with `master` ref" assumption to use a local `upstream_master` branch instead

Action:

- Do compare the local tracking branch tip to the actual upstream default branch tip via a `GET https://api.github.com/repos/<owner>/<repo>/compare/<local-tip>.master` call or the `commits?per_page=1` endpoint, record the SHA and date of both tips, the ahead/behind count, and the subject and date of each side; surface any non-zero gap as a new Manager decision in the pre-merge report's "Manager decisions requested" section (the design's decision id may not cover it) and as a numbered risk; don't open the pre-merge triage on a range that quietly misses upstream commits, because the merge log will then have a known gap that the Architect review cannot recover from.


## Improvement: Plan must document resolution path for non-blocking review findings

Condition:

- When a design or plan-review document records a non-blocking finding that should be resolved during implementation or QA execution

Action:

- Record the resolution path explicitly in the implementation plan. Name the canonical source QA should consult, the table or row where QA records the result, and the condition that closes the finding. Do not just link to the finding and assume later reviewers can infer the closure path.


## Improvement: Plain ASCII scan on humanizer-cleaned report tables

Condition:

- When writing long triage tables in a pre-merge report or a review report and the humanizer pass leaves the prose clean but the table cells still contain em dashes (U+<year>) or other typographic punctuation

Action:

- Do run a `[regex]::Matches($content, '[^\x00-\x7F]')` scan on the file before handoff and replace em dashes with ` - ` (space-hyphen-space) or commas inside the table cells; em dashes are not flagged by `git diff --check` on untracked files, so the scan is the only defense; the scan also catches smart quotes, non-breaking spaces, and BOM bytes that the humanizer would otherwise miss.


## Improvement: MSVC inline header coverage may be unreachable

Condition:

- A coverage task tries to raise product coverage by exercising inline method bodies in headers under MSVC

Action:

- Do check optimization and inlining flags before designing the coverage lift. If MSVC inlines or elides the header body, add coverage through a non-inline call path or classify the gap as tool/build-limited. Do not promise a header-line coverage lift without confirming the generated code can be attributed to that header line.


## Improvement: Verify prompt facts against repo state before acting

Condition:

- When a Manager or user prompt includes specific quantitative or locational facts about a repo that are tied to a binding decision

Action:

- Verify each cited fact with a direct git or file command before acting. Do not propagate prompt numbers, paths, or expected content into logs or merge notes if they disagree with repo state. For dotted durable-doc directories, list sibling files before creating new paths so a missing leading dot does not create orphan documents.

## Improvement: Build halt can mask later compile or runtime defects

Condition:

- When fixing a real `git merge` build halt caused by a redefinition error (C2086, C2264, etc.) in a file that both merge parents modified, and the Manager binding decision authorized only one specific duplicate removal

Action:

- Run the full incremental compile to the same target after the first authorized fix. The first build halt can hide later compile errors, and a clean build can still expose runtime failures in tests that exercise the merged path. If the next failure is outside the binding, document the evidence and escalate a new Manager decision instead of expanding scope unilaterally.


## Improvement: Hybrid-only sustained-load stalls are product evidence by default

Condition:
- When a hybrid-cache sustained-load test stalls or fails under hot-budget pressure while the comparable native/default leg completes under the same host limits

Action:
- Treat the differential result as product evidence for the hybrid controller path, not as host-capacity evidence by default. Check that both legs used comparable limits, that the runner preserved artifacts, and that the failing warnings point to hybrid demote/evict behavior before asking QA to rerun.


## Improvement: AST parser for PowerShell function surface when dot-source auto-runs body

Condition:

- When a verification step needs to confirm a PowerShell script exposes specific functions, and the script ends with a top-level invocation (e.g., a trailing `Main` line) that would auto-run on dot-source

Action:

- Do use `[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)` followed by `$ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) | ForEach-Object Name` for static function extraction. Don't try to dot-source and strip the trailing invocation (the strip pattern is fragile across line-ending variations and regex mode gotchas); the AST parser is read-only, fast, and exact. '.\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1'; Get-Command -CommandType Function | Select-Object Name }"` failed because the driver ends with `Main` and dot-source auto-runs `Main`, which crashed with `BLOCKED-preflight: {binary_exists:false, .}` and exited 1 before the function enumeration could run. The AST approach confirmed all 4 required functions (`Invoke-Phase1OutputEquivalence`, `Invoke-CycleLeg`, `Invoke-Phase05WorkloadBuild`, `Write-Stage29Report`) are present in 14 total exposed functions, with exit code 0. Don't trust a dot-source smoke test when the target script has trailing top-level statements.


## Improvement: Driver flags need parser and mode-validation checks

Condition:

- When a Driver / test-runner script constructs a server ArgumentList that contains CLI flags which the server validates against runtime state (e.g., cache mode, parallelism, model capability), and the prior review/fix sessions only verified the flag name against `common/arg.cpp` registration without checking the validation blocks in `tools/server/server-context.cpp` (or the equivalent server entry point)

Action:

- Trace each driver `--` literal through both parser registration and any mode-coupled validation blocks in the server entry path. A flag can be registered but still invalid for a specific cache mode or runtime state, so gate driver arguments on the same conditions the server enforces.


## Improvement: QA report Errors list may include errors not addressed by the Cause or Proposed fix sections

Condition:

- When a QA test report's "Errors" list contains N error entries (e.g., C2679 at line X, C2440 at line Y) but the "Cause" section and "Proposed fix" section only address one of them, and the unaddressed errors are the same defect (same struct field, same upstream commit, same root cause) as the addressed one

Action:

- Do treat the unaddressed error as the SAME defect at a different location, not as a separate unrelated error. Apply the same fix pattern to each instance of the defect (e.g., one-line addition per brace-init aggregate that is missing the upstream-introduced field). Document each fix in the Developer fixes file as "Fix N (line M, function F, struct S): ." with the same root cause citation. Note explicitly in the QA fixes file that the QA's proposed scope was incomplete and which additional fixes were applied. The user's "do not attempt unrelated fixes" constraint means fixing the SAME defect at a different location is allowed because the work is not unrelated; it completes the QA's proposed fix. }` initializer (which was the local-parent code, not the upstream-added one) was the correct minimal change. The `git blame` evidence showed the 1649 initializer predated the merge (<date>, Xuan-Son Nguyen) and the upstream commit that added `allow_video` was 8f83d6c27 (<date>).


## Improvement: Do not embed self-changing commit SHA in amended content

Condition:

- When a docs commit includes a content file (e.g., test report, design doc) that references the commit's own SHA, and you amend the commit to add more content

Action:

- Do not pin the docs commit's own SHA inside content that may be amended. An amend changes the SHA, which would require another content edit and another amend. Reference the commit by stable attributes such as subject, parent, sequence position, or simply "the docs commit".


## Improvement: Scope-check regex duplicate candidates before fixing

Condition:

- When a regex scan of a merged worktree file returns N candidate duplicate declarations (function or static names appearing twice) in a file that both merge parents modified

Action:

- Do manually verify the lexical scope of each candidate pair before applying any fix: class methods, class forwarders (`Foo::method` outside the class), and same-name overloads are not true duplicates. Only `static` definitions or free functions in the same scope with byte-identical bodies are true duplicates. Don't apply a fix based on the regex count alone; a typical scan of a 6800-line server file returns 7-8 candidates, of which 1-2 are real duplicates. Use a 5-line-before-and-after context check to confirm scope, and use `git blame` on each copy to confirm the two copies came from different parents of the merge.


## Improvement: Build output piped to Select-Object buffers all output

Condition:
- Running cmake --build <build-dir> --config Release 2>&1 | Select-Object -Last N or similar build command in PowerShell where the build output is piped to Select-Object (or Select-String or Where-Object) that buffers the entire output before emitting the filtered result

Action:
- Do use Tee-Object -Variable <name> to capture the full output to a PowerShell variable while also passing it through, or redirect to a log file with *> <log-path> and Get-Content it after the build completes; don't pipe cmake/msbuild output to Select-Object -Last N; the pipe buffers all output and the terminal shows nothing until the build completes, which makes it impossible to monitor build progress or detect early errors. If you only need the tail, write to a log file and read the last N lines with Get-Content -Tail N. ## Improvement: Verify QA runtime-behavior claims against model log before designing the fix

Condition:
- When a QA test report or fixes file makes a claim about runtime behavior (e.g., "MTP creates internal checkpoints at every `min spacing = 256` step boundary", "checkpoint positions follow rule X", "first checkpoint is at position Y") and the recommended fix scope is designed around that claim

Action:
- Do grep the model log (e.g., `Select-String -Path ._analysis\model_log.txt -Pattern "created context checkpoint"`) and tabulate the actual `n_tokens` values before designing the fix; the model log is the source of truth for runtime behavior, not the config values (e.g., `min spacing = 256`).` which follow a non-linear pattern determined by the speculative-decoding internal state. The right fix was to use the chat path's per-message loop `token_end` values as a proxy (for the failing test case 61-token prompt, the first MTP checkpoint at `n_tokens=11` aligns with end of user message), not to pre-compute `min spacing` multiples. Don't design the fix around the QA's claim without verifying; the per-message boundary emission inside the existing loop covered the test case without needing to pre-compute MTP positions.


## Improvement: Working-branch docs need git checkout to master before merge

Condition:
- When user instructions say 'switch to local default branch (master)' and 'run the merge on master' but the Step 1 work (pre-merge report, implementation log updates) is committed on a working branch (e.g., cache-optimization-caveman), not on master

Action:
- Do use git checkout <working-branch> -- <file-path> after switching to master to bring the working-branch files onto master before the merge. The git checkout stages the file, so it will be part of the merge commit or a follow-up commit. Don't assume the user knows the working branch is ahead of master; verify with git log --oneline master..<working-branch> before switching. If the merge needs the pre-merge report to be updated post-merge, the report must be on master before the merge so the update can be committed on master.


## Improvement: Test-helper API changes need runtime verification

Condition:

- When fixing a test by changing a debug/test-only helper call shape, overload, namespace, or metadata argument, and the helper has side effects on shared state that later assertions read

Action:

- Do not stop at a successful build. Run the test binary directly, capture stdout and stderr, and verify later assertions plus warning logs. If an overload change alters admission, namespace, payload, or metadata behavior, treat it as a runtime test defect until the assertion path passes.


## Improvement: Test assertion line numbers need source verification

Condition:

- When a test report or fixes file claims a specific test function crashed at a specific line number, and the Developer needs to fix the test

Action:

- Read the test file at the cited revision and match the assertion text to the test function before trusting the report attribution. If the line number or function name drifted, document the corrected source location and scope the fix to the actual failing assertion.

## Improvement: Check build artifact timestamps against source timestamps before running tests

Condition:

- When a cmake --build completes with exit 0 but the test results don't match the expected behavior of the current source code

Action:

- Do check the binary timestamp against the source file timestamps before running tests; if the binary timestamp is BEFORE the source file timestamp, the binary is stale and the test results are from the old code. Rebuild explicitly and verify the binary timestamp is AFTER the source timestamp before drawing conclusions from test failures. The fix was to rebuild explicitly and verify the new binary timestamp.


## Improvement: Iterative test fix exposes more latent defects

Condition:

- When a test fix moves the test binary crash point past the
  current failing test, and the new crash point is in a
  different test function with a different root cause

Action:

- Do apply the same pattern iteratively to each newly
  exposed test, distinguishing "same defect pattern" (apply
  the same fix) from "new substantive issue" (report to
  Manager). For the namespace mismatch pattern: use the
  2-arg debug_find_match_tokens_for_tests(tokens,
  namespace_id) form for entries with literal namespaces,
  and the 2-arg metadata form for entries with metadata. For
  the entry_count contract: use n_evictions /
  n_payload_evictions instead of debug_entry_count_for_tests
  after eviction. For the 1-arg form empty-tokens issue: add
  a guard in the 1-arg debug helper to return -1 for empty
  tokens. For the workload profile check: report as
  substantive issue (production code rejects unsupported
  profile, test uses nullptr ctx_tgt). Do NOT try to fix all
  remaining test defects in one shot; each fix may expose
  more. The iteration took 5 build +
  test cycles to reach the substantive issue.


## Improvement: Plan author must not author a sibling agent's review slot

Condition:

- When a user brief for a planning deliverable (entry doc + part files) explicitly says a specific part (e.g. `part file`) is authored by a different fresh agent session (Architect, Manager, or QA) and the planning agent must not author it

Action:

- Do record the sibling slot in the entry doc's `## Contents` section with explicit "not authored by this session" wording (e.g. "part file: . - created by a fresh Architect session after the plan is otherwise complete. Not authored by this Developer session.") so a reader sees the slot exists, knows what goes there, and is not surprised that the part file is absent. Do not create an empty placeholder file; the absence of the part file is the signal that the sibling session owns it. ## Improvement: PowerShell path-separator normalization vs git ls-files

Condition:

- When a PowerShell script needs to decide between git mv and Move-Item for items in a directory by checking if any tracked file from git ls-files <dir>/ lives inside that item, and the script builds the comparison prefix from a Windows-side path (e.g., Get-ChildItem . | % FullName then Replace('D:\\source\\llama.cpp-jet\\', '')), which yields backslash-separated relative paths

Action:

- Do normalize the tracked-path keys to backslashes (e.g., ( -replace '/', '\\')) OR build the comparison prefix with forward slashes (e.g., ( -replace '\\', '/') + '/') before the StartsWith check; don't compare Windows-side backslash paths to git ls-files forward-slash paths directly. The bug defaults every item to the non-git mv branch and silently loses git rename history on bulk moves. The cleanup commit 4f434897e therefore shows 1270 files as 1269 deletes + 1 .gitignore modification with no rename detection. The end state matched the user's accepted "show as deleted" plan, but the same bug in a code-introducing move would lose real history. When this is detected post-hoc, the cheapest recovery is git add -A + commit (current files in dest are gone from index, old files are gone from disk) plus an explicit note in the commit message.


## Improvement: Handoff H2 collision in multi-gate stage implementation logs

Condition:

- When appending a new gate-evidence section to the stage implementation log that already contains a `## Handoff` H2 heading (typical for the post-plan handoff section written by the planning author) and the new section is also required to be `## Handoff` (typical for a post-readiness, post-execution, or post-closure handoff section)

Action:

- Do rename the existing `## Handoff` to a more specific variant (e.g. `## Handoff to execution` for the post-plan handoff) so the new `## Handoff` H2 is unique; MD024 disallows duplicate H2 headings and the existing markdownlint configuration will flag the duplicate. Don't try to disable MD024 for the file; the rename is a one-line, non-substantive change that preserves the existing content. The rename is also a useful reader cue: the original Handoff section talks about post-plan handoff, and the new Handoff section talks about post-readiness handoff, so the more specific name reflects the actual content.


## Improvement: MD024 collision in multi-item implementation plans (H3 "### Steps" duplication)

Condition:

- When authoring an implementation plan that covers multiple distinct design items (e.g., Item 1, Item 2) in the same file and each item's "ordered implementation steps" section uses the same generic H3 heading (e.g., `### Steps` for both)

Action:

- Do rename each item's H3 to be context-specific (e.g., `### Item 1 steps`, `### Item 2 steps`) so the H3 heading is unique; MD024 disallows duplicate headings at any level and the existing markdownlint configuration will flag the duplicate. Don't try to disable MD024 for the file; the rename is a one-line, non-substantive change that preserves the content. The rename is also a useful reader cue: the renamed H3 immediately identifies which item's steps are below it, and the body text still starts at the same line. The same principle applies to any H2/H3/H4 generic heading (`### Steps`, `### Handoff`, `### Risks`, `### Evidence`) repeated across multi-item or multi-section plans.


## Improvement: Spec examples must be checked against runtime data

Condition:

- When a bug-fix spec gives example data structures (boundary spans, token counts, field values) for the runtime code path that the fix targets, and the spec's smoke test plan asks you to issue requests that should produce that data structure

Action:

- Capture the actual runtime structure before relying on spec examples. Add temporary debug logging if needed, rebuild, run the smoke, and compare real spans, counts, and field values to the example. If they differ, either extend the fix to the real structure or escalate that the smoke target does not match the implementation path.


## Improvement: QA runtime hypotheses need source-data verification

Condition:
- When a test report's analysis hypothesises a specific token-position alignment (e.g., "the user message ends at token 11") that the fix is designed to cover, but the actual fixture's token distribution doesn't match the hypothesis

Action:
- Do verify the hypothesis against the actual rendered prompt and chat-template tokeniser output before trusting the analysis; tabulate the per-message token positions from the chat path's per-message loop output (or the test report's evidence) and check that the hypothesised position matches. If the hypothesis is wrong, the fix is designed for the wrong case and may not work." prompt. The system prompt-span boundary has token_end ~12, the user prompt-span has token_end ~62, neither equals 11. The MTP checkpoint at
_tokens=11 is determined by the model's internal state, not by message boundaries. Don't trust the test report's positional hypothesis without verifying the actual token distribution.


## Improvement: Refactor cleanup must remove all references to old variables

Condition:

- When a Developer refactor replaces a control-flow flag (e.g. bool flag = false; if (cond) { . flag = true; } else { . }) with a new structure (e.g. T* best = nullptr; if (best) { . } else { . }) and removes the original flag declaration

Action:

- Search the changed block for leftover assignments or reads of the old variable before claiming the refactor is applied. Use a literal search for the old name and confirm every remaining match is intentional. A stale assignment can leave the tree uncompilable even when the new control flow looks correct.


## Improvement: Close test file handles before Windows cleanup

Condition:

- When a Windows-focused test reads a temporary file and then removes the containing temp directory in the same test

Action:

- Do close the input/output stream before calling `std::filesystem::remove_all`, or use a nested scope so the stream is destroyed first; call the `remove_all(path, std::error_code&)` overload for best-effort cleanup. Windows can keep the file locked while the stream is open, causing `remove_all` to throw after all assertions pass.


## Improvement: Baseline warmup crashes block product-bug verification

Condition:

- When a Developer bug-fix session applies a targeted startup change, builds the binary fresh, and then cannot verify because the server crashes during model warmup on both the fixed path and a baseline invocation

Action:

- Treat the baseline crash as a verification blocker, not a regression in the targeted fix. Run a minimal baseline first; if it crashes the same way, document repeated trials, exit codes, resource state, and crash-site logs. Also verify the new binary contains the intended code path before routing verification to a fresh session.


## Improvement: Visual Studio generator needs separate Release linker debug flags

Condition:
- When adding Release debug information flags for the Visual Studio generator with the goal of producing PDBs for coverage or crash analysis

Action:
- Set the Release linker flag variables separately from the compile flags. Visual Studio generator projects keep compile and link settings in different sections, and passing linker-only flags through `CMAKE_CXX_FLAGS_RELEASE` can be misinterpreted as a preprocessor define.


## Improvement: Startup validation should use the caller's error channel

Condition:
- When a startup validation or init path uses an exception to signal an invalid configuration, and the call chain to the throw site has no catch block

Action:
- Do not rely on exceptions for bounded startup exits unless the entire call chain catches them. If the enclosing init function already returns `bool` or another status channel and the caller already handles failure, use that channel. Verify both the message and the process exit code before declaring the fix complete.


## Improvement: Startup-crash closure needs repeated clean-launch evidence

Condition:

- A fix claims to close an intermittent startup crash or launch-time failure

Action:

- Do require multiple consecutive clean launches with the target flags before treating the crash as closed. Record exact command, exit code, stderr tail, and any crash-dump state. One clean launch is smoke evidence, not closure evidence.


## Improvement: PowerShell tail filters can hide long-running output

Condition:
- When running a build or long-running PowerShell command and piping output to `Select-Object -Last N` or `Select-Object -First N` to filter the tail/head for display

Action:
- Use `Tee-Object -Variable <name>` to capture full output while still displaying it, or write to a log file and read the tail with `Get-Content -Tail N`. Do not pipe directly to `Select-Object -Last N` for live feedback, because it can buffer output until the command completes.


## Improvement: Prototype runners need explicit contract gap review

Condition:
- When an accepted design says an existing runner or script is a prototype, may be used only as input, or was not approved as final evidence

Action:
- Read the prototype before writing the implementation plan and add a dedicated plan section listing concrete gaps against the accepted evidence contract. Cover output naming, redaction boundaries, request/response artifacts, summary schema, metric capture, baseline paths, verdict calculation, and a dry-run validation step.


## Improvement: Dry-run summaries should use explicit sentinel values

Condition:
- When a runner dry-run writes the same summary or comparison schema that live execution will later fill with runtime-only metrics

Action:
- Do write explicit dry-run sentinel values such as `DRYRUN` plus `inconclusive` classification for runtime-only fields; don't leave those fields as null, because reviewers need to distinguish intentionally unexecuted evidence from missing runner output.


## Improvement: Runner PASS verdicts need explicit evidence gates

Condition:
- When fixing or writing a runner verdict path that can return PASS from aggregate counters, partial evidence, or default-empty reason arrays

Action:
- Do encode each required PASS predicate as an explicit gate before the PASS branch, with separate `FAIL-*`, `BLOCKED-metric-unavailable`, and `BLOCKED-runner-contract` reason arrays. After patching, read the changed function or diff before validation to catch stale variables and old reason handling that parser checks may not flag.


## Improvement: PowerShell foreach output before piping

Condition:
- When writing a PowerShell one-liner that emits objects from a `foreach` block, script block, or inline loop and then pipes the produced objects to formatting or filtering

Action:
- Do assign the loop or script-block output to a variable first, then pipe the variable. This avoids parser errors from placing `|` immediately after a closing brace in dense one-liners used for hygiene checks. Apply this even to quick hygiene commands; repeated parser failures waste review time.


## Improvement: Cold-path startup crashes need setup split

Condition:
- When a Windows llama-server startup crash happens with `--cache-cold-path` and the process exits before `/health`, especially with `0xc0000409` or no fatal tail after model load

Action:
- Do run two minimized CUDA launches before deeper cache triage: one with the same cold path missing, and one after explicitly creating the cold path and evidence directory. Classify missing-directory failures as a harness setup bug plus any unbounded product error handling; don't continue root-cause work as CUDA, model, or cache-pressure failure until the existing-directory launch is tested.


## Improvement: Write exact build evidence after commands finish

Condition:
- When updating a durable fix report with exact build evidence such as binary mtimes, test counts, or command exits

Action:
- Do run the build/test commands first, collect filesystem mtimes and exit codes, then write the evidence section. Don't write placeholder mtimes or counts before the command finishes, because a later correction pass can leave stale evidence in an otherwise valid report.


## Improvement: Manager gate outranks runner PASS-candidate in test-results reviews

Condition:
- When reviewing a QA rerun where the runner summary reports `PASS-candidate`, `OK`, or another aggregate non-fail label, but a Manager gate or accepted stage contract lists stricter acceptance checks for the same rows

Action:
- Do classify the row against the Manager gate first and treat the runner label as evidence only. If the runner accepted a partial hit count or partial evidence, state that split explicitly in the developer review, assign product or harness ownership from the stricter gate, and do not let the aggregate runner label downgrade a gate FAIL to PASS or BLOCKED.


## Improvement: Focused test counts must match binary output

Condition:
- When adding, removing, replacing, or de-duplicating focused test functions or registrations

Action:
- Do update the registered test calls, any hard-coded binary summary count, and any durable report test-count wording in the same edit; run the binary and verify the printed total plus the new/removed PASS lines before documenting evidence. If removing a placeholder wrapper, remove it from the focused count instead of keeping a no-op and state which direct PASS lines satisfy the inherited invariant. ## Improvement: Manager-only exceptions stay blockers without recorded decisions

Condition:
- When a QA report failure could fit a named exception path, but the design or Manager gate says the exception is valid only after an explicit Manager decision

Action:
- Do classify the current gate result as FAIL/product bug or blocked handoff until the Manager decision exists in a durable doc. Cite the exact design or Manager acceptance line that requires the exception, and do not recommend accepting the run as an exception candidate based only on plausible timing or bounded diagnostics.


## Improvement: Serial MSBuild for shared CMake targets

Condition:
- When building multiple CMake/MSBuild targets that share generated objects, project dependencies, or output files in the same build tree

Action:
- Do run those builds serially, or build the broader target after the narrower target completes. Don't launch shared-target MSBuild invocations in parallel tool calls, because they can collide on the same `.obj`, `.lib`, `.exp`, or generated output and create a false permission-denied build failure.


## Improvement: Async completion tests must drain queued work

Condition:
- When testing an asynchronous demotion or promotion completion path and manually invoking a private completion handler or synthetic completion result

Action:
- Do either avoid enqueueing the worker item, or process/drain the real queued worker item before the test ends. Prefer a real worker-backed completion when the test is meant to prove queued ownership or lifetime behavior. Don't manually complete a synthetic result after enqueueing the same operation and leave the queued work item behind, because a later worker start/stop or destructor path can emit unrelated stale-completion diagnostics and make the regression evidence noisy.


## Improvement: Wrapper dry-run must expose nested row-cap allocation

Condition:
- When a parent runner passes one row cap to a child script that internally subdivides the row into profiles, phases, or sub-runs

Action:
- Do make both the child dry-run output and the parent wrapper side log show the total row cap and each internal allocation before any live run. Don't rely on parent flag validation alone, because it can pass while the child multiplies the cap internally and violates the stage runner contract.


## Improvement: Windows access violations need symbolized offset triage

Condition:
- When a Windows model-backed server row loses `llama-server.exe` with no fatal tail in `server.err.log`, and Windows Application Error reports `0xc0000005` with a fault offset in `llama-server-impl.dll`

Action:
- Do read `Get-WinEvent` Application records and map `image base + fault offset` with local `llvm-symbolizer.exe --obj=build-cov\bin\Release\llama-server-impl.dll <address>` before stopping at the last cache warning. If a focused fix removes the visible pressure symptom but the same AV offset remains, treat the first fix as incomplete and continue root-cause analysis from the symbolized frame; don't classify the remaining crash as a separate environment issue without symbol evidence.


## Improvement: Carry forward explicit next-review scope from Manager gates

Condition:
- When a Manager gate assigns the current review a normal classification task and also requires the next Architect, QA, or Manager review to include a special scope item such as a fix-history fragility review

Action:
- Do record that special scope in both the root-cause direction and handoff sections, name the Manager decision ID, and make it part of the retest or review authorization path. Don't leave it only in the inputs-reviewed or gate-basis section, because the next owner may otherwise miss the extra review obligation while following the product-bug handoff.


## Improvement: Owned-scope restore fixes can use precondition hooks

Condition:
- When a product bug is in a restore or request path but the direct function body is outside the owned write scope

Action:
- Do inspect the direct function to find owned helpers called before the failing branch, then patch the narrow owned helper if it can satisfy the same contract without public-surface changes. Document the indirect fix point and add a focused regression that proves the helper changes the end-to-end state the direct function consumes. Don't edit out-of-scope files just because the failing log line is printed there.


## Improvement: Non-gating metric anomalies need explicit follow-up classification

Condition:
- When a QA report passes the active gate but includes a non-gating metric anomaly with an impossible or invalid value

Action:
- Do classify the anomaly explicitly as a gate blocker, separate follow-up, or non-issue. If Manager marked it non-gating but the value is still invalid product telemetry, keep the gate verdict tied to the accepted criteria and record a separate follow-up with focused metric-accounting retest scope.


## Improvement: Pass server-flag arrays to child PowerShell rows with encoded args

Condition:
- When a PowerShell wrapper must pass a dynamic list of server flags through `Start-Process` into child `.ps1` row scripts, especially flags beginning with `--` or arrays supplied through `powershell -File`

Action:
- Do encode the server-flag array as JSON and Base64, pass it as one scalar parameter, decode it inside the child script, and validate both wrapper dry-run and child dry-run. Don't pass raw `string[]` values or documented `@('stress row','stress row')` syntax through an outer `powershell -File` command and assume the child receives the same array, because the command boundary can flatten row arrays or reinterpret `--flag` tokens as script parameters.


## Improvement: Check doc cap immediately after pointer edits

Condition:
- When adding a short gate pointer, status line, or cross-reference to an existing durable design or implementation document near the 300-line cap

Action:
- Do check the physical line count immediately after the edit and bring the file back under 300 lines by tight reflow or required splitting before other hygiene checks. On Windows, verify the count with byte-level LF counting or explicit line enumeration, not only `Get-Content | Measure-Object -Line`, because text-pipeline counts can underreport a near-limit untracked Markdown file. Don't assume a small pointer edit is exempt from the document size rule; parent stage logs can already be close enough that one or two lines violate the cap.


## Improvement: Row-specific server flags need final-value assertions

Condition:
- When a child runner intentionally sets a row-specific server flag and the parent wrapper also passes the same flag through encoded, appended, or shared server args

Action:
- Do remove or reorder the parent duplicate for that row, pass the child override explicitly when possible, and add dry-run side-log assertions for both the row-specific final value and a neighboring row that still uses the parent default. Do not rely on "flag present" checks when duplicate CLI flags use last-value-wins behavior.


## Improvement: Decode encoded PowerShell flag arrays into explicit lists

Condition:
- When a child PowerShell runner decodes a Base64/JSON server-flag array and then filters or indexes the decoded values

Action:
- Do decode into an explicit `System.Collections.Generic.List[string]`, iterate that list, and write a per-leg `server-flags.txt` proof before launch. Don't assume a helper returning `[string[]]` stays array-shaped across script boundaries, because a collapsed scalar string can make `$flags[$i]` index characters and pass a lone `-` or unfiltered duplicate flags to `llama-server`.


## Improvement: Pressure workloads need admit-size proof

Condition:
- When fixing a cache pressure runner where the goal is demotion, cold eviction, queue pressure, or skip evidence under a small byte budget

Action:
- Do first prove a single payload can be admitted under that budget by checking live save size or a short smoke. If the minimum payload is larger than the budget, changing prompt count or identity cannot create demotion pressure; adjust the fixture or workload shape so payloads fit, then run a short smoke long enough to cross the next pressure boundary before documenting the fix.


## Improvement: Protected-root rows need protected-counter proof

Condition:
- When fixing a protected-root pressure runner with public HTTP prompts or chat messages

Action:
- Do distinguish generic payload pressure from trusted protected-root pressure. Verify `llamacpp_cache_protected_root_decisions_total`, `cache_protected_root_payload_decisions_total`, protected payload bytes, or protected demotion counters separately from payload eviction/demotion counters. If public requests only produce degraded metadata and protected counters stay zero, document that as a residual review decision instead of claiming full protected-root proof from payload pressure alone.


## Improvement: Mixed workload artifacts need path diversity

Condition:
- When a mixed workload runner uses a model fixture whose public prompt-evidence profile can collapse to one model-level profile

Action:
- Do record harness prompt-class counts and prompt-evidence path diversity, such as token-span checksums or outcome/checksum pairs, in the row artifact. Don't rely only on public `profile` labels to prove workload mix.


## Improvement: Root-level test scripts need depth-specific source root

Condition:
- When adding a PowerShell runner directly under
  `._design_docs/cache-handling-test-scripts/` and reusing patterns from
  scripts in `stress/`, `bench/`, or `longrun/`

Action:
- Do derive the repository root from the new script's actual directory depth and
  prove `RunRoot`, `ReportPath`, `ModelPath`, and binary paths in dry-run output
  before live smoke. Don't copy a subdirectory script's `..\..\..` source-root
  calculation into a root-level script; root-level scripts need `..\..`.


## Improvement: Keep validation artifacts inside allowed scope

Condition:
- When a task gives an allowed-file list but validation commands can create
  durable reports, logs, or other tracked artifacts outside that list

Action:
- Do route validation outputs to ignored scratch paths when the runner contract
  permits it, or remove only self-created out-of-scope artifacts before handoff.
  Preserve enough evidence in allowed implementation notes and ignored run
  output. Don't leave generated reports outside the allowed paths merely because
  the validation command produced them.

## Improvement: Git diff checks do not cover untracked tooling

Condition:
- When validating newly added or still-untracked scripts, tests, or tooling files
  and the handoff asks for `git diff --check`

Action:
- Do run the requested `git diff --check -- <paths>` and also run a direct
  trailing-whitespace scan on the same paths. Report when the paths are
  untracked, because `git diff --check` can exit 0 with no output while checking
  no file content.


## Improvement: Preserve correction-smoke failures

Condition:
- When a runner-contract correction smoke or focused verification run produces a
  new valid FAIL/BLOCKED row while proving the corrected harness behavior

Action:
- Do preserve the new row verdict in the durable evidence and explain whether it
  is product behavior, runner behavior, or acceptance-blocking scope. Don't tune
  smoke parameters or rewrite the report to force a PASS when the failure is the
  corrected classifier doing its job.


## Improvement: Encode explicit GPU requirements in runner contracts

Condition:
- When the stage requires Nvidia CUDA/GPU execution and the runner or test plan
  owns server launch commands

Action:
- Do encode the required GPU launch flags in the runner, expose them in dry-run
  output, require `GGML_CUDA:BOOL=ON` configure proof, and require startup-log
  CUDA/NVIDIA runtime proof before row classification. Don't rely on plan prose
  or prior-stage convention to make a CPU run invalid after the fact.


## Improvement: Keep baseline diagnostics out of hybrid safety verdicts

Condition:
- When a comparison runner evaluates a hybrid-only safety policy alongside a
  native/default baseline that can emit superficially similar counters

Action:
- Do scope the failure predicate to the variant that owns the policy, and keep
  baseline counters as diagnostic fields. Don't fail a hybrid safety row from
  native/default cache counters unless the design explicitly says the baseline
  participates in that safety contract.


## Improvement: Verify runner JSON dry-runs under Windows PowerShell

Condition:
- When a PowerShell runner dry-run writes machine-readable JSON artifacts that
  QA may execute through `powershell.exe -File` or a child `Start-Process`
  wrapper

Action:
- Do verify the dry-run under Windows PowerShell 5 as a child process, not only
  under `pwsh` or the current shell. If `ConvertTo-Json` stalls, serialize a
  bounded plain object graph first and print only a short status line after the
  JSON file is written. Also test comma-delimited scalar row arguments at the
  script boundary, because `string[]` parameters can arrive flattened.


## Improvement: Avoid PowerShell automatic match variable names

Condition:
- When a PowerShell helper uses `-match` inside a loop and also stores state in a
  collection or scalar named `$matches`, `$Matches`, or another case variant

Action:
- Do rename the local state before patching and add a direct helper check that
  exercises at least one matching line. PowerShell variable names are
  case-insensitive, and `-match` repopulates the automatic `$Matches` hashtable,
  so a local `$matches` collection can be replaced mid-loop and fail later method
  calls such as `.Add(.)`.


## Improvement: Line-ending mismatch inflates git diff stat

Condition:

- When `git ls-files --eol` reports an index/worktree line-ending mismatch and `git diff --shortstat` shows large churn for a small content change

Action:

- Report whitespace-insensitive content stats with `git diff -w --shortstat` alongside the raw stat, and document the line-ending mismatch so reviewers see the true content delta. Do not normalize a whole file just to clean the stat unless the task explicitly calls for it.


## Improvement: Extract full types before moving function bodies across TUs

Condition:

- When a binding requires moving a function body into another translation unit and the body takes or touches a type whose full definition lives only in the source translation unit

Action:

- First check that the destination translation unit has access to every full type used by the moved body, not just forward declarations. If a type or enum is defined inline in the source translation unit, extract it to a header before moving the function. Remove any test stubs that were only compensating for the missing real header.

## Improvement: PowerShell `Set-Content -NoNewline` collapses line arrays

Condition:

- When manipulating multi-line text files on Windows by reading with `Get-Content` and writing back with `Set-Content -NoNewline`

Action:

- Do not use `Set-Content -NoNewline` to write a multi-line array back to a file. It strips separators between items and can collapse the file into one logical line. Join with explicit line endings or use an API that writes each line with the intended newline, then verify line count and CR/LF bytes.

## Improvement: Silent-crash classification needs error-count hash comparison

Condition:

- A new integration run reports a silent crash and prior evidence may already contain the same crash signature

Action:

- Do compare `summary.json.error_counts` keys byte-for-byte with prior crash signatures before classifying the failure. Same hash means likely prior-decision carry-over; different or absent hash means a new defect path. Do not rely on request index alone, because crash timing can move under cache pressure.


## Improvement: Cold-store accounting tests must drive completion path

Condition:

- Adding focused tests for cold-store accounting or per-id byte tracking

Action:

- Do drive the completion handler or equivalent production accounting path directly, not only setup helpers. Assert both aggregate counters and per-id maps after demotion, eviction, cleanup, and error paths. Do not count setup-only tests as proof that completion accounting is correct.


## Improvement: MSVC /GF string pool splits long literals with length prefixes

Condition:

- When a Windows MSVC Release binary uses `/GF` (string pooling, the default), and a byte-level scan for a contiguous ASCII literal (e.g. `--crash-dump-dir`) returns 0 occurrences

Action:

- Do not conclude the literal is absent; MSVC /GF stores pooled strings with a 4-byte length prefix between them, so a single logical string like `--crash-dump-dir` may be physically stored as `--crash-` + 4-byte length + `dump-dir` + 4-byte length. Verify by searching for shorter substrings (`--crash`, `dump-dir`) and confirming the gap is exactly 4 bytes; if so, the full literal IS compiled in. Pair the byte search with `dumpbin /dependents` and a substring search before declaring the flag plumbing is missing in the binary. Don't restart a heavy MSBuild cycle on the strength of a single negative byte scan; verify the literal is actually absent via partial substring search first.


## Improvement: Keep argv splice storage alive through parser use

Condition:

- When source code splices custom CLI flags out of `argv` by building replacement argument storage inside a shorter-lived scope, then passes the derived `argv` pointer to a parser after that scope exits

Action:

- Flag this as a use-after-free bug. Keep the filtered argument storage in the same scope as every parser use, or store strings and pointer arrays together with matching lifetime. If a startup path crashes while walking arguments, inspect argv storage lifetime before blaming the runner.

## Improvement: Candidate fixes need both focused and runtime verification

Condition:

- A fix candidate is paired with a new regression test and is meant to close a runtime failure

Action:

- Do verify the candidate at two layers: the focused regression test and the runtime or integration path that originally failed. If the new regression fails on the fixed binary, or the runtime failure still reproduces with the same signature, classify the candidate as incomplete. Do not assume the test is wrong without an independent runtime check.


## Improvement: Use side-channel MSVC ASan builds without durable CMake edits

Condition:

- A Windows investigation needs ASan instrumentation for a focused binary but the stage scope does not allow durable CMake changes

Action:

- Do create a separate build directory with ASan compile flags and matching CUDA host-compiler flags when CUDA is enabled. Verify the binary depends on the ASan runtime before trusting the run. Do not edit project CMake files for a one-off diagnostic build unless the task explicitly asks for durable build-system changes.


## Improvement: MSVC ASan runtime path must include compiler bin directory

Condition:

- When invoking an MSVC ASan-instrumented binary from a shell that may not have the compiler runtime directory on `PATH`

Action:

- Prefix `PATH` with the matching MSVC bin directory before running the binary. Do not copy ASan DLLs next to the executable as a workaround; that hides the dependency. Verify ASan is active with a deliberate signal or expected ASan output on the targeted test binary.
## Improvement: std::abort status is not ASan evidence

Condition:

- A Windows test exits with `STATUS_STACK_BUFFER_OVERRUN` or another fast-fail-looking status while ASan is enabled or expected

Action:

- Do distinguish test-authored `std::abort()` from sanitizer findings. Treat ASan evidence as the explicit `AddressSanitizer: .` report in stderr, not the Windows process status alone. If stderr contains only the test failure message followed by abort, classify it as a test assertion failure, not heap corruption.


## Improvement: Markdown lint MD049 expects asterisk emphasis even for code identifiers

Condition:

- When writing durable planning markdown tables that contain code identifiers like `enqueue_demotion`, `cache_state_mutex_`, `hybrid_cache_controller`, `io_worker.debug_*_for_tests`, or `execute_inline` and the table cell uses them inline (not wrapped in backticks)

Action:

- Do wrap underscore-delimited code identifiers in backticks before placing them in markdown table cells, or escape the underscores with backslash (`enqueue\_demotion`). Do not assume backtick-wrapping alone is enough; the markdownlint MD049 rule reports underscore-emphasis violations even when the identifier is inside a code span, because the linter parses the cell content separately. Fix was to escape the underscores (`debug\_set\_queue\_capacity\_for\_tests`) which the linter then accepts. Don't paste raw C++ identifier names into markdown table cells; either wrap them in code spans with no underscore conflict or escape the underscores.


## Improvement: PowerShell WriteAllLines on Windows inserts CRLF

Condition:

- When creating or modifying a markdown file on Windows via PowerShell line-writing APIs and the durable-doc convention requires LF-only line endings

Action:

- Do not rely on `WriteAllLines` to produce LF-only output on Windows. Use `WriteAllText` after normalizing the content string to LF, and verify with a byte-level CR count immediately after programmatic writes.

## Improvement: MSVC warning level can hide deprecation markers

Condition:

- A change adds deprecation attributes or expects C4996 warnings from MSVC builds

Action:

- Do inspect the captured compiler command line for warning level and external warning flags before using absence of warnings as evidence. If the configured level suppresses the warning, verify marker placement in source and build success instead. Recommend a warning-level follow-up only when surfaced warnings are required by the task.


## Improvement: Use [Environment]::Exit(N) for script exit codes when invoked via & in -Command

Condition:

- When running a PowerShell script via `pwsh -NoProfile -Command "& '.\path\to\script.ps1' -Arg"` from a parent shell, and the script uses `exit N` inside a try/catch or function scope to set a non-zero exit code

Action:

- Do use `[Environment]::Exit(N)` instead of `exit N` to ensure the exit code propagates back to the parent shell. The plain `exit` statement inside an `&` invocation may exit the script but the exit code can be lost or default to 1, regardless of the value passed. After replacing all four `exit N` calls with `[Environment]::Exit(N)`, the parent shell's `$LASTEXITCODE` correctly showed 0 for the success branch and 4 for the BLOCKED-server-not-running classification branch. Don't rely on `exit N` inside script functions or try/catch blocks; the parent shell may not see the value. Use `[Environment]::Exit(N)` for explicit, predictable exit code propagation.


## Improvement: 300-line cap + lint-forced blank lines around headings forces part-file split, not just trim

Condition:

- When appending a new subsection (with header + paragraph + links) to a durable doc that is already at the 300-line cap, and the markdown lint rule MD022 requires blank lines around every heading so a single subsection takes 5-7 lines (header + blank above + paragraph + blank + next header + .)

Action:

- Do split into a new part file from the start instead of trying to trim the new content; trim attempts hit MD031/MD022/MD047 conflicts that force re-adding the blank lines the trim removed. Move the new section into part-NN-<slug>.md and replace the in-doc content with a 2-3 line pointer that links to the new part file. A 5-line stress row-IMPL-FIX-02 pointer section pushed it to 305; a 7-line subsection pushed it to 307; trimming blank-line-around-headings to get under 300 triggered MD022 errors that re-forced the blank lines. Splitting into part-file.md and replacing the entry-doc section with a 2-line pointer brought the entry doc back to 297 lines and the new part file to 33 lines, both well under cap. Don't try to inline the section into an at-cap entry doc; the markdown lint's blank-line requirements and the 300-line cap are in tension. Move the content out and link it from the entry doc.


## Improvement: Driver review must cross-check literal flags against server validation

Condition:

- Reviewing a driver or runner that builds child process arguments from literal `--flag` strings

Action:

- Do grep every literal flag, confirm registration in the server argument parser, and trace mode- or context-coupled validation blocks for each mode the driver runs. Syntax, parameter names, and dry-run output are not enough if the server rejects the flag combination at startup.


## Improvement: Byte-verify new markdown immediately after creation on Windows

Condition:

- When creating a new markdown file on Windows for durable planning docs or reports

Action:

- Run the byte-level CR/LF check immediately after creation, before additional edits. Verify CR=0, no BOM, final byte LF, no trailing whitespace, and expected ASCII/non-ASCII policy. If the file has CRLF, normalize it before continuing so later edits do not hide the source of the line-ending change.

## Improvement: Brief line numbers for fix targets can drift; disambiguate by surrounding code context

Condition:
- When a Manager/QA brief specifies line numbers for a one-line fix that targets one of multiple call sites with the same parameter pattern in the same file (e.g., brief says "L292 already has `-MaxIterations 200`; fix L294 which has `-MaxIterations 50`")

Action:
- Do verify BOTH line locations on disk with a byte-level read BEFORE applying the fix; brief line numbers can drift by +/- N lines (this case: brief L292/L294, disk L147/L149, off by 145). Use surrounding code context (variable names like `$OutputEquivalencePrompts` vs `$RequestCount`, function arguments, comments) to make the `replace_string_in_file` match unique, not the brief's line number. Verify the change preserves LF count (a parameter value change should not add or remove lines) and that the AST parse is clean. Don't trust brief line numbers alone; verify with disk read and use unique surrounding context.


## Improvement: Metric HELP/TYPE fixes must include secondary row writers

Condition:

- When fixing Prometheus HELP/TYPE duplication in a route or endpoint that has local metric emitters plus older helper functions that append rows to the same output stream

Action:

- Search the whole writer scope for helper calls that emit rows after local header-once logic is added. Route helper rows through the same one-header-per-name registry or replace helper calls with direct header-once emission for the required families.
## Improvement: Implementation part filenames can drift from prompts

Condition:

- When a user asks to read numbered implementation parts by approximate title or stale filename, and the first direct read fails for those paths

Action:

- Read the implementation entry document part links and list the part directory before treating missing filenames as blockers. Use the live linked filenames as authoritative when the part number and scope match.
## Improvement: Verify live driver response schema before assigning cache behavior bugs

Condition:
- When a live comparison driver reports zero cache reuse or zero token reuse, but server metrics or focused probes suggest hits occurred, and the endpoint is not the same endpoint used by older scripts

Action:
- Do inspect the exact response schema for that endpoint before changing product restore code; for `/v1/chat/completions`, read cached prompt tokens from `usage.prompt_tokens_details.cached_tokens` and use `timings.cache_n` only as fallback. Don't classify zero driver `cache_n` as product save/restore failure until the driver is reading the endpoint's current cache-token field.


## Improvement: Close every independent evidence channel before re-review

Condition:
- When a failed report has separate evidence channels for the same behavior, such as request-row cache reuse and Prometheus hit-delta counters, and a fix explains only one channel

Action:
- Do run or preserve a focused live probe that closes each independent channel before marking the fix ready for review. For the stage-style cache reuse, collect both parsed request rows with non-zero `cache_n` and a positive `llamacpp:cache_hits_total{mode="hybrid"}` delta from the same duplicate-request run.

## Improvement: Separate gate-blocking bugs from non-gated metric observations

Condition:
- When reviewing QA test results and the report includes a real-looking product metric anomaly that is outside the accepted test-plan PASS rows, while all binding setup, correctness, hit, performance, error, cleanup, and hygiene rows pass

Action:
- Do classify the anomaly as a non-blocking product observability bug candidate, state that no stage-blocking product bug remains, and avoid requesting retest for the current gate unless the accepted test plan explicitly makes that metric value a pass/fail row. Hand Manager a separate follow-up decision instead of blocking closure.

## Improvement: Coverage target drift can be wider than first compile error

Condition:
- When a coverage build fails because one focused test target calls a removed API, and the coverage script builds or runs a list of sibling focused targets from the same old stage

Action:
- Do scan every target in the coverage list for the removed API family before declaring the first target fixed. If several sibling targets still depend on retired behavior, either update all still-valid tests to the current API or remove obsolete behavior-only targets from the coverage mapping, then build the corrected target set. Do not stop after the first target compiles if the coverage package still names other stale targets.

## Improvement: Coverage floor rework needs early lift math

Condition:
- When asked to raise a focused coverage row to fixed percentage floors after a measurable coverage report already names current product-only and combined rates

Action:
- Do calculate the exact additional covered product lines needed before editing tests, then choose test work that can plausibly cover that many product lines. If the gap is hundreds of product lines and current null-context tests only cover helpers, identify the likely live-context or fixture-bound paths before spending time on marginal target additions. After each coverage run, compare the gained product lines to the remaining floor gap and stop with a clear blocker if the chosen test-only path cannot close it.


## Improvement: Cache A/B zero-hit results need retention math before product-bug classification

Condition:

- When a cache comparison driver reports zero cache hits or zero reused tokens in one mode, but prior focused probes prove metric extraction works

Action:

- Compute whether the workload can retain an entry long enough for a duplicate request before classifying the result as product failure. Estimate hot-cache entry capacity, admission rate, predicted retention time, and measured duplicate interval. If duplicates arrive after predicted eviction, classify as workload or budget mismatch rather than a cache restore regression.

## Improvement: Live prefix-restore failures need rendered-token prefix proof

Condition:

- When reviewing a live chat prefix-restore QA failure where `cached_tokens` and hit metrics are zero, but the request pair includes generated or synthetic assistant turns

Action:

- Do inspect raw requests plus rendered template/tokenization artifacts before assigning a product restore bug. Require machine evidence that the first rendered prompt tokens are a strict prefix of the second request tokens, or that the selected checkpoint-safe prefix tokens match. If the driver inserts synthetic assistant text or omits the actual prior assistant output so strict-prefix proof is absent, classify the first action as QA workload/script correction with focused retest; escalate to product only after a corrected strict-prefix workload still fails.

## Improvement: Incomplete build trees need explicit fallback evidence

Condition:

- When a requested or preferred CMake build directory exists but build invocation fails because generator files such as `build.ninja`, `.sln`, or project files are missing

Action:

- Do inspect the build directory before retrying. If another generated build tree already exists and matches the requested evidence scope closely enough, use that tree for focused compile/test evidence and record the failed preferred build command as a blocker. Do not claim the preferred build passed, and do not spend time reconfiguring it unless the task specifically requires that exact preset.

## Improvement: Review-blocked concurrency tests must hit production branches

Condition:

- When fixing an implementation review finding that says a concurrency or race test used a synthetic sleep, helper commit, or helper-owned critical section instead of the production branch under review

Action:

- Do add the narrowest test-only hook at the live production branch boundary and assert a branch-specific signal from that path. Drive the public transaction method in the test, prove the competing operation runs while the hook is paused, and assert the production second-pass or post-relock counter when the review finding names that branch. Do not count helper-shaped setup code as evidence for production transaction coverage.

## Improvement: Callback composition findings need public-path evidence

Condition:

- When an implementation review finding says a callback registration overwrites an existing lifecycle handler, but live lower-level registration code may already compose callbacks

Action:

- Do inspect both the public setter and the lower-level callback storage before patching. Make the production path explicit at the owner boundary, then add a focused hook that drives the public setter and the actual lifecycle callback, asserting both local lifecycle state and external notification order. Do not rely on a helper-only callback composition test when the finding names a public setter.

## Improvement: Verify refreshed remote-tracking refs before and during merge evidence

Condition:

- When a task states that a remote-tracking source ref has already been
  refreshed, or when a merge/rework implementation gate starts after a cleanup
  commit and depends on a previously approved upstream source tip, or when a
  no-commit merge remains open long enough for the source ref or actual
  upstream tip to change during evidence gathering

Action:

- Do run the required `git status --short`, `rev-parse`, `log -1`,
  `merge-base`, `rev-list --count`, `remote -v`, and `ls-remote` checks before
  merge commands or durable evidence edits, and repeat the SHA checks before
  claiming implementation-gate closure. Compare live ref SHA, approved source
  SHA, range count, merge base, actual upstream remote tip, and `MERGE_HEAD`
  as separate gates. If the named ref still points at the old SHA, moves
  backward after the merge opens, the approved object exists only as a
  loose/local object, or actual upstream has advanced beyond the local object
  store, stop before merge and record a source-ref blocker unless Manager has
  already approved a pinned known-gap path. If drift is discovered after a
  no-commit merge is already open, do only bounded documentation and hygiene
  needed to preserve the partial state, then stop for Manager direction; don't
  run more code/test evidence or close the gate on the stale merge, even when
  `MERGE_HEAD` still names the approved source tip. If Manager authorizes
  abort-and-redo, verify untracked paths first, run only `git merge --abort`
  (not `reset`), confirm `MERGE_HEAD` is gone, refresh the selected source ref
  to actual upstream, then redo the pre-merge analysis against the latest
  source tip. Don't treat a clean worktree or prior cleanup commit as
  authorization to merge or finish a stale or mismatched source ref.

## Improvement: Quote git revision ranges in PowerShell variables

Condition:

- When building a git revision range from PowerShell variables, such as
  `$old..$new`, for `git rev-list`, `git log`, or `git diff`

Action:

- Do quote or concatenate the full revision range string before passing it to
  git, for example `"$old..$new"`. Unquoted `$old..$new` can be parsed by
  PowerShell as a range expression or otherwise passed incorrectly, producing
  misleading counts. Verify suspicious counts with the quoted form before
  recording them in durable docs.

## Improvement: Escape markdown-link brackets in PowerShell row matching

Condition:

- When replacing a markdown table row in PowerShell by matching a literal link
  prefix such as `| [cache-handling-phase35-implementation.md]`

Action:

- Do use an escaped regex match like `-match '^\| \[cache-handling-phase35-implementation\.md\]'` or exact string comparison after extracting the cell. Do not use `-like '| [cache-handling-phase35-implementation.md]*'`, because PowerShell treats `[...]` as a wildcard character set and can match the first ordinary table row, corrupting the wrong line.

## Improvement: Parenthesize PowerShell range expressions for Select-Object

Condition:

- When using `Select-Object -Index` with a numeric range in PowerShell, such as
  reading a file slice around lines 70 through 130

Action:

- Do pass the range as an expression with parentheses, for example
  `Select-Object -Index (70..130)`. Do not pass `-Index 70..130`, because
  PowerShell treats it as a string and fails before producing the file slice.

## Improvement: Clean Windows build workers after non-timeout failures

Condition:

- When a Windows `cmake --build` or MSBuild invocation exits non-zero before
  the outer timeout, especially before a fallback build in the same build tree

Action:

- Do run the same leftover-process check used for timeout cleanup for `cmake`,
  `MSBuild`, `cl`, `link`, `ninja`, and `devenv`, then stop any remaining build
  workers before the fallback or handoff. Do not limit cleanup verification to
  timeout paths; MSBuild can remain alive after ordinary link failures such as
  `LNK1136` and contaminate the next focused build attempt.

## Improvement: Resolve report artifact path drift against accepted plan

Condition:

- When a task gives a raw artifact path, but the accepted test plan and QA
  report use a different durable/non-durable artifact root spelling

Action:

- Do treat the accepted plan and QA report as authoritative after the first
  direct path read fails. Check both dot-prefixed and non-dot project-root
  variants before declaring the artifact missing, and record the path actually
  read in the review evidence.

## Improvement: Verify working-tree code against review verdict before assuming rework

Condition:

- When a REWORK or BLOCKING review verdict cites code behavior with line anchors
  from a prior session, and the same uncommitted diff may already contain a fix
  applied after the review snapshot

Action:

- Do read the live working-tree code at the cited anchors (treating the review's
  line numbers as hints) before assuming the production fix is missing. Inspect
  the uncommitted diff with `git diff -w` to separate real semantic changes from
  CRLF/whitespace noise, and confirm whether the fix the review requires is
  already present. When it is present, focus the session on what the review calls
  open (missing tests, evidence, doc updates) rather than re-applying code. Do
  record in the evidence which parts were already in the tree and which the
  session added, so the re-review can trace every claimed correction to a
  concrete change.

## Improvement: Do not parallel-build overlapping MSBuild targets

Condition:

- When verifying Windows CMake/MSBuild targets that share source objects or
  project dependencies, such as `test-cache-controller` and `llama-server`
  both compiling `server-cache-hybrid.cpp`

Action:

- Do run overlapping build targets serially, or in one `cmake --build`
  invocation when that target combination is supported. Don't launch parallel
  `cmake --build` processes for targets that can compile the same object file;
  MSBuild can fail with `Cannot open compiler generated file ... .obj:
  Permission denied` even when the code is correct. If it happens, check for
  leftover build workers, rerun the failed target serially, and record the first
  failure as build-process contention, not product evidence.
