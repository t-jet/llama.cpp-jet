# Developer improvement memory

## Improvement: Dirty worktree handoff

Condition:

- When changing code or durable planning documents in a worktree that already has uncommitted changes

Action:

- Do capture the pre-existing dirty state before edits; when the relevant files already have large unrelated diffs, identify the current task's changed paths and behavior with focused searches or line anchors, and distinguish those changes from existing user or prior-agent work in the handoff.

## Improvement: Verify untracked documentation edits

Condition:

- When editing a documentation file that is untracked in git, or when the parent documentation directory is untracked

Action:

- Do verify the changed lines, status text, line counts, and trailing-whitespace state directly with file reads or searches; run a scoped whitespace check for tracked touched paths when available, then report the path as changed. Use `Select-String -Pattern '[ \t]+$'` for trailing whitespace on untracked files, and `[regex]::Matches($content, '[^\x00-\x7F]')` for non-ASCII scans, because `git diff --check` only reports tracked files. Don't rely on plain `git diff`, because it does not show untracked file content.

## Improvement: Windows server pytest path

Condition:

- When running `tools/server/tests` pytest modules on Windows from the repository root and the harness tries to launch a relative `../../../build/bin/.../llama-server.exe`

Action:

- Do rerun focused tests with `LLAMA_SERVER_BIN_PATH` set to the absolute built server executable; use `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` when the module preload fixture is unrelated to the behavior under test.

## Improvement: Mandatory startup memory order

Condition:

- When task instructions require reading self-improvement memory before any other task action

Action:

- Do make the first assistant action a tool read of the self-improvement skill and agent memory before any acknowledgement, commentary update, skill-use announcement, plan, AGENTS.md discussion, analysis, or non-memory tool use; don't send even a brief "I'll load memory first" note until that read is complete, including when the user pasted repo instructions or the note only says memory will be loaded.

## Improvement: Test-results review gate classification

Condition:

- When reviewing QA execution reports for a staged gate with FAIL, SKIP, BLOCKED, or misleading runner output

Action:

- Do classify each non-pass item as product bug, QA harness gap, environment/configuration limitation, design/test-plan mismatch, or acceptable deferred coverage; for model-backed rows, verify that the run created the required precondition metrics or logs before calling it a product bug, and update the stage implementation status with the exact next gate action.

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

- When probing llama-server public /metrics for cache_checkpoint_* (or any cache controller) rows on a stage-10 closure contract, and the prior probe scripts or test plan steps omit --metrics from the server start command

Action:

- Do include --metrics in the Start-Process ArgumentList before launching the server; the /metrics endpoint returns 501 not_supported_error without it, and an empty or 0-row body looks like a product bug rather than a missing flag. Verify the flag is present by checking for the 501 error in the first probe run and re-launching with --metrics added before escalating to focused-substitute evidence.

## Improvement: Hybrid restore timing triage

Condition:

- When hybrid cache metrics report a hit, checkpoint admission succeeds, or public completion timing still reports `cache_n=0`

Action:

- Do trace the full handoff from checkpoint export flags and descriptor span metadata through controller restore, slot launch, and prompt processing; check request `cache_prompt`, explicit `id_slot` routing, restored token count, and checkpoint/SWA replay guards before treating the mismatch as response serialization or test-shaping only.

## Improvement: Split near-limit planning docs early

Condition:

- When creating durable implementation or planning documentation that is likely to approach the 300-line document limit

Action:

- Do split the entry into a short TOC/status file and part files before drafting the full content; don't leave an over-limit draft in the worktree while reviewing. After any trim or consolidation, run `Measure-Object -Line` immediately to confirm the line count actually dropped, because paragraph consolidation can grow line count rather than reduce it.

## Improvement: Cache metric defaults across modes

Condition:

- When adding cache metrics that are sourced from hybrid-only stats but emitted through the shared server `/metrics` path

Action:

- Do verify the metric shape for both hybrid and legacy cache modes, and use safe default values for stats fields that legacy controllers do not report.

## Improvement: Preserve local line endings in patch edits

Condition:

- When applying manual patches to files that may use CRLF or mixed line endings, or when the tracked file is LF in HEAD but the edit tool saves the worktree as CRLF on Windows

Action:

- Do inspect the resulting diff and newline counts for unnecessary line-ending churn; if a formatter or shell rewrite changes unrelated lines only because of newline normalization or adds a BOM, restore your own changes for that file and reapply the patch narrowly before handoff. On Windows, `replace_string_in_file` can save the whole file as CRLF even when HEAD is LF, and `[System.IO.File]::WriteAllText` with `UTF8` adds a UTF-8 BOM by default; use `New-Object System.Text.UTF8Encoding($false)` and strip the BOM with `if ($content[0] -eq [char]0xFEFF) { $content = $content.Substring(1) }` before saving, then convert CRLF to LF with `-replace "\`r\`n", "\`n"` so the worktree matches HEAD's blob format; verify with `git diff --check` and a `git diff -w --stat` showing only the intended insertions.

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

- When running a one-liner PowerShell command from a PowerShell or pwsh terminal via `pwsh -NoProfile -Command "..."` and the command contains `\$var` or `\$null` PowerShell escape sequences

Action:

- Do write the command to a temporary `.ps1` file and invoke it with `pwsh -NoProfile -File <path>.ps1`; don't use `pwsh -NoProfile -Command` with `\$` escapes because the outer shell strips the backslash and PowerShell sees a bare `$var` or `$null` reference that fails to parse, producing a `ParserError: Unexpected token '\'` message. This applies to syntax checks, tokenize calls, and any one-liner that needs PowerShell variable scoping.

## Improvement: Verify upstream tracking branch against actual upstream

Condition:

- When the pre-merge analysis or any merge step assumes a local tracking branch is current, especially when a Manager plan-change decision overrides the design's "single primary `upstream` remote with `master` ref" assumption to use a local `upstream_master` branch instead

Action:

- Do compare the local tracking branch tip to the actual upstream default branch tip via a `GET https://api.github.com/repos/<owner>/<repo>/compare/<local-tip>...master` call or the `commits?per_page=1` endpoint, record the SHA and date of both tips, the ahead/behind count, and the subject and date of each side; surface any non-zero gap as a new Manager decision in the pre-merge report's "Manager decisions requested" section (the design's D1-D5 may not cover it) and as a numbered risk; don't open the pre-merge triage on a range that quietly misses upstream commits, because the merge log will then have a known gap that the Architect review cannot recover from.

## Improvement: Plain ASCII scan on humanizer-cleaned report tables

Condition:

- When writing long triage tables in a pre-merge report or a review report and the humanizer pass leaves the prose clean but the table cells still contain em dashes (U+2014) or other typographic punctuation

Action:

- Do run a `[regex]::Matches($content, '[^\x00-\x7F]')` scan on the file before handoff and replace em dashes with ` - ` (space-hyphen-space) or commas inside the table cells; em dashes are not flagged by `git diff --check` on untracked files, so the scan is the only defense; the scan also catches smart quotes, non-breaking spaces, and BOM bytes that the humanizer would otherwise miss.

## Improvement: T114a .h inline coverage lift is not reachable on MSVC

Condition:

- When a T114a product-only coverage fix targets the .h inline method bodies in 	ools/server/server-cache-legacy.h, 	ools/server/server-cache-controller.h, or 	ools/server/server-cache-hybrid.h and the build uses MSVC with /Ob1 (OnlyExplicitInline, the RelWithDebInfo default) or /Ob2 inlining

Action:

- Do not rely on direct calls, member function pointers, volatile member function pointers, or file-scope #pragma optimize("", off) to credit the .h source line. Verified 2026-06-05: adding `__declspec(noinline)` BEFORE the return type on the inline body accessors of `hybrid_cache_entry` (`size`, `n_tokens`, `resident_payload_bytes`, `has_target_payload`, `has_draft_payload`, `mark_used`) lifted T114a from 0.6974 (2077/2978) to 0.7035 (2090/2971) and `hybrid.h` per-file from 0.5929 (83/140) to 0.7273 (96/132). The body attribution moves from the test .cpp call site to the .h source line as expected under MSVC /Ob1. Don't split the function into a forward declaration plus a separate _impl() body; MSVC rejects the trailing `__declspec(noinline)` after the cv-qualifier with C2143; the correct placement is before the return type. Don't attempt to lift the denominator-inflating lines that are pure declarations, structural `};` braces, or un-called function bodies (`policy-lru::plan_evictions`); they need a test plan denominator change or new test cases, not a noinline annotation.

## Improvement: Verify prompt facts against repo state before acting

Condition:

- When a Manager or user prompt includes specific quantitative or locational facts about a repo (commit counts, file paths, expected content, named build directories) that are tied to a binding decision and that the prompt treats as given

Action:

- Do verify each cited fact with a direct git or file command (`git log --oneline <range>`, `git grep`, `git rev-list --parents`, `git diff <ref1> <ref2> -- <path>`, `Test-Path <build-dir>/build.ninja`) before acting on it; don't propagate the prompt's numbers, paths, or expected content into the implementation log, evidence section, or merge commit message if they disagree with the actual state. Record both the prompt's claim and the actual value in the implementation entry so the next reviewer can see the discrepancy. If the build directory named in the prompt is empty (no `build.ninja`, no `bin/`, no `.vcxproj`), look for the actual populated build directory and use that, noting the substitution in the verification evidence.

## Improvement: Real-merge build halt may mask other latent duplicates

Condition:

- When fixing a real `git merge` build halt caused by a redefinition error (C2086, C2264, etc.) in a file that both merge parents modified, and the Manager binding decision authorized only one specific duplicate removal

Action:

- Do run the full incremental compile to the same target after the first duplicate removal, even if the manager's binding decision specified only the first error; the prior build halt at error N may have masked errors N+1, N+2 that the fix exposes. If the build then halts on a second pre-existing duplicate, STOP per the binding "build fails for any other reason" rule, document the second duplicate with `git blame` evidence, and escalate a new Manager decision rather than expanding the authorized scope unilaterally. Don't claim the first fix is "PASS" in the implementation log until the incremental compile to the binding target succeeds. Don't commit a single-fix tree that does not compile, because the next developer would inherit a non-compiling state.

## Improvement: Scope-check regex duplicate candidates before fixing

Condition:

- When a regex scan of a merged worktree file returns N candidate duplicate declarations (function or static names appearing twice) in a file that both merge parents modified

Action:

- Do manually verify the lexical scope of each candidate pair before applying any fix: class methods, class forwarders (`Foo::method` outside the class), and same-name overloads are not true duplicates. Only `static` definitions or free functions in the same scope with byte-identical bodies are true duplicates. Don't apply a fix based on the regex count alone; a typical scan of a 6800-line server file returns 7-8 candidates, of which 1-2 are real duplicates. Use a 5-line-before-and-after context check to confirm scope, and use `git blame` on each copy to confirm the two copies came from different parents of the merge.
