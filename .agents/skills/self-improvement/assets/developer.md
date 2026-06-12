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

## Improvement: Cherry-pick list must distinguish code-introducing merges from worktree-artifact commits

Condition:

- When a "merge cycle" cherry-pick plan lists the cycle's first commit as a merge commit that should bring the upstream code, but the diff between the named commit and its single parent is all worktree artifacts (build logs, test reports, coverage HTML) with no production code changes

Action:

- Do inspect `git show <commit> --stat` and `git diff-tree --no-commit-id --name-only -r <parent> <commit>` before assuming the named commit will bring the upstream code. If the named commit is purely artifacts, fall back to the user's stated fallback: do `git merge <upstream-ref> --no-ff -X ours` (or the user's documented strategy) on the integration branch first, then cherry-pick the artifact commit on top so its files are added but no code is duplicated. Verified 2026-06-12 (Stage 14 Path B integration): `44502e38d` was titled "merge origin/upstream_master" but its diff vs parent `08f3a6155` was 1264 added files of S12 reports and coverage HTML; the actual upstream code merge was in `08f3a6155` which was unreachable from caveman. The plan's fallback (`git merge origin/upstream_master --no-ff -X ours`) brought the code with no conflicts because the -X ours strategy preferred caveman's content for boundary-level conflicts; the 1264 artifact files were then added cleanly by the cherry-pick. Don't try to "force" the cherry-pick to bring code; check the diff structure first.

## Improvement: Cross-merge integration exposes partial function bodies

Condition:

- When a cross-merge integration (e.g. caveman + upstream + cherry-picks) lands and the build fails with link errors like "unresolved external symbol server_routes::handle_count_tokens" but the function is declared in a header and referenced in another .cpp

Action:

- Do check the cycle's other branches (`git show <main-branch>:<file>`) for the function definition; the function definition was on the other lineage but not in the merge result because the merge resolved differently for the .cpp file vs the .h. Copy the function definition verbatim from the lineage that had it (search via `git grep 'function_signature' <main-branch>`) and add it to the merged file at the right class scope. Verified 2026-06-12 (Stage 14 Path B): `server_routes::handle_count_tokens` was declared in `server-context.h:152` (from upstream merge) and referenced at `server-context.cpp:5515, 5576, 5630` (from upstream merge) but the definition was in master's `server-context.cpp:6785` which was unreachable from caveman. Adding the definition verbatim from master resolved 13 link errors at once. Don't try to inline the function or write a minimal stub; the cycle's body has the full logic for Anthropic/OAI/OAI-Resp dispatch that the call sites assume.

## Improvement: Cross-merge function signature mismatches

Condition:

- When a cross-merge integration produces compile errors C2065 (undeclared identifier) inside a function body for a parameter that exists in the upstream signature but not the local lineage's signature, even though the body was applied from upstream

Action:

- Do check whether the function signature comes from the local lineage (kept by `-X ours`) while the body was applied from upstream. The signature kept the 3-arg form, but the body references a 4th parameter (e.g., `is_placeholder`). Add the missing parameter to the local signature and update call sites to pass the new value. Verified 2026-06-12 (Stage 14 Path B): `process_mtmd_prompt(mtmd_context*, std::string, std::vector<raw_buffer>)` was kept from caveman, but upstream's body referenced `is_placeholder`; adding the `bool is_placeholder` parameter to the local signature and updating the call site resolved C2065/C2672/C2668 errors. Don't try to make the body not reference the new parameter; the body is correct, the signature is the local artifact.

## Improvement: Cross-merge rejects caveman's degraded() fallback

Condition:

- When a cross-merge integration's tests fail with an assertion that the helper returned true when the test expected false, and the production code path includes a `degraded() || !boundaries_native` fallback that the upstream branch doesn't have

Action:

- Do remove the fallback from the merged code to match upstream's strict check. The fallback was added by the local lineage to support a specific case (probably non-native or degraded metadata) but it makes the strict boundary check not strict. Verified 2026-06-12 (Stage 14 Path B): the test `test_stage9_checkpoint_boundary_metadata` expected `debug_admit_checkpoint_for_tests(64, 0, 64, true)` to return false for a bad_span metadata; the merged code returned true because `degraded() || !boundaries_native` was true (the metadata was neither, but the fallback fired anyway) and the descriptor's boundary_checksum was set to the GOOD span_checksum for the descriptor's span, bypassing the boundary mismatch. Removing the fallback from both `validate_checkpoint_descriptor_metadata` and `attach_checkpoint_payload` made the test pass. Don't try to make the test match the fallback; the test is the cycle's expected behavior and the fallback is the local artifact.

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

- Do run the full incremental compile to the same target after the first duplicate removal, even if the manager's binding decision specified only the first error; the prior build halt at error N may have masked errors N+1, N+2 that the fix exposes. If the build then halts on a second pre-existing duplicate, STOP per the binding "build fails for any other reason" rule, document the second duplicate with `git blame` evidence, and escalate a new Manager decision rather than expanding the authorized scope unilaterally. Don't claim the first fix is "PASS" in the implementation log until the incremental compile to the binding target succeeds. Don't commit a single-fix tree that does not compile, because the next developer would inherit a non-compiling state. Also, do not stop at "build PASS" - the next layer of defects is often a RUNTIME defect, not another compile error: an assertion failure (STATUS_STACK_BUFFER_OVERRUN, exit code 0xc0000409 on Windows / SIGABRT on Linux) in a test that compiles cleanly but exercises the merged production code path differently than the pre-merge code path did. Verified 2026-06-11 (Stage 14 Step 3 test fix): after fixing the C2668/C2838/C2065 compile errors in test-cache-controller.cpp, the build PASSED and ctest then crashed at test_hybrid_rejects_partial_blob_match line 571 because the merged admission code path in server-cache-hybrid.cpp rejects the test's debug_add_entry_for_tests call (logs "descriptor validation failed (admission validation failed)"). The test function was not touched by the test fix; the failure is a pre-existing test defect surfaced by the merge. STOP at this layer too, document the runtime defect with the exact assertion message and the admission code path evidence, and escalate a new Manager decision. Don't expand the authorized scope to modify production code or to "fix" the test by changing its semantics; the right call is a separate Manager decision to either update the test, update the production code, or defer to a follow-up cycle.

## Improvement: QA report Errors list may include errors not addressed by the Cause or Proposed fix sections

Condition:

- When a QA test report's "Errors" list contains N error entries (e.g., C2679 at line X, C2440 at line Y) but the "Cause" section and "Proposed fix" section only address one of them, and the unaddressed errors are the same defect (same struct field, same upstream commit, same root cause) as the addressed one

Action:

- Do treat the unaddressed error as the SAME defect at a different location, not as a separate unrelated error. Apply the same fix pattern to each instance of the defect (e.g., one-line addition per brace-init aggregate that is missing the upstream-introduced field). Document each fix in the Developer fixes file as "Fix N (line M, function F, struct S): ..." with the same root cause citation. Note explicitly in the QA fixes file that the QA's proposed scope was incomplete and which additional fixes were applied. The user's "do not attempt unrelated fixes" constraint means fixing the SAME defect at a different location is allowed because the work is not unrelated; it completes the QA's proposed fix. Verified 2026-06-11 (Stage 14 Step 3 fix): QA listed C2679 at 1649 and C2440 at 4160 in the errors list but the Cause and Proposed fix only addressed the 4160 case; applying the same one-line pattern to the 1649 `chat_params = { ... }` initializer (which was the local-parent code, not the upstream-added one) was the correct minimal change. The `git blame` evidence showed the 1649 initializer predated the merge (2026-01-19, Xuan-Son Nguyen) and the upstream commit that added `allow_video` was 8f83d6c27 (2026-06-08).

## Improvement: Recursive SHA in amended commit's content file

Condition:

- When a docs commit includes a content file (e.g., test report, design doc) that references the commit's own SHA, and you amend the commit to add more content

Action:

- Do not pin the docs commit's SHA inside the content file. The amend changes the commit's SHA, which would change the file's content, which would change the commit's SHA again, creating a recursive update that never converges. Reference the docs commit by stable attributes instead: parent SHA, subject line, position in the commit series, or simply "the docs commit" without a SHA. The fix commit's SHA is stable (it doesn't reference itself) and can be pinned in the docs file. Verified 2026-06-11: pinning the docs commit SHA 84408cc68 in the test-report-20260611-01-fixes.md created a recursive update when the SHA was updated to 6607f814a after amend; replacing the SHA with "the second commit in the Stage 14 Step 3 fix series" broke the recursion.

## Improvement: Scope-check regex duplicate candidates before fixing

Condition:

- When a regex scan of a merged worktree file returns N candidate duplicate declarations (function or static names appearing twice) in a file that both merge parents modified

Action:

- Do manually verify the lexical scope of each candidate pair before applying any fix: class methods, class forwarders (`Foo::method` outside the class), and same-name overloads are not true duplicates. Only `static` definitions or free functions in the same scope with byte-identical bodies are true duplicates. Don't apply a fix based on the regex count alone; a typical scan of a 6800-line server file returns 7-8 candidates, of which 1-2 are real duplicates. Use a 5-line-before-and-after context check to confirm scope, and use `git blame` on each copy to confirm the two copies came from different parents of the merge.


## Improvement: Build output piped to Select-Object buffers all output

Condition:
- Running cmake --build <build-dir> --config Release 2>&1 | Select-Object -Last N or similar build command in PowerShell where the build output is piped to Select-Object (or Select-String or Where-Object) that buffers the entire output before emitting the filtered result

Action:
- Do use Tee-Object -Variable <name> to capture the full output to a PowerShell variable while also passing it through, or redirect to a log file with *> <log-path> and Get-Content it after the build completes; don't pipe cmake/msbuild output to Select-Object -Last N; the pipe buffers all output and the terminal shows nothing until the build completes, which makes it impossible to monitor build progress or detect early errors. If you only need the tail, write to a log file and read the last N lines with Get-Content -Tail N. Verified 2026-06-11: a 4-minute cmake --build build-cov --config Release with Select-Object -Last 30 produced no output for the entire duration because the pipe buffered everything.

## Improvement: Working-branch docs need git checkout to master before merge

Condition:
- When user instructions say 'switch to local default branch (master)' and 'run the merge on master' but the Step 1 work (pre-merge report, implementation log updates) is committed on a working branch (e.g., cache-optimization-caveman), not on master

Action:
- Do use git checkout <working-branch> -- <file-path> after switching to master to bring the working-branch files onto master before the merge. The git checkout stages the file, so it will be part of the merge commit or a follow-up commit. Don't assume the user knows the working branch is ahead of master; verify with git log --oneline master..<working-branch> before switching. If the merge needs the pre-merge report to be updated post-merge, the report must be on master before the merge so the update can be committed on master.

## Improvement: Test-helper API changes need runtime verification, not just compile verification

Condition:
- When fixing a test that calls a debug/test-only helper API (e.g., `debug_add_entry_for_tests(tokens, ...)`, `attach_payload(...)`) by changing the call shape (more args, different overload, different namespace), and the helper has side effects on the same shared state that the subsequent assertion (lookup, count, stats) reads

Action:
- Do not trust that the test fix is complete when the build passes; do run the test binary directly and verify the subsequent assertion passes before declaring the fix done. The build only proves the call type-checks and resolves the overload; the runtime behavior of the new call shape (entry admission, namespace computation, payload registration) can still diverge from the original intent. A signature change to a 5-arg form with the same target_bytes and a `""` namespace may pass the build but the entry may be rejected by the strict namespace check in `find_best_match` because the empty namespace falls back to `compute_namespace_id()` (no metadata) while the lookup uses `compute_namespace_id(metadata)`, producing different hash strings. In llama-server-cache-hybrid, the 5-arg form `debug_add_entry_for_tests(tokens, bool, std::string, size_t target_bytes, size_t draft_bytes)` with `""` namespace did not match the lookup namespace; the metadata form `debug_add_entry_for_tests(tokens, const prepared_prompt_metadata &)` did match. Always pipe the test binary output (both stdout and stderr) to separate log files and grep for the assertion message and any "validation failed" / "namespace" warnings before committing the fix. Verified 2026-06-11: a Stage 5 test fix appeared to admit the entry (no "missing target payload" warning) but the lookup still returned -1 because the strict namespace check skipped it; the metadata form was needed.

## Improvement: debug_add_entry_for_tests 2-arg metadata form loses protected_root

Condition:

- When converting a `debug_add_entry_for_tests` call site to the 2-arg metadata form `(tokens, metadata)` to fix a Stage 5 "missing target payload" admission rejection, and the test asserts eviction behavior based on `protected_root` (e.g., test 20 `test_hybrid_protected_eviction_paths`)

Action:

- Do recognize that the 2-arg metadata form does NOT set `entry.protected_root` (always defaults to false), so the metadata form cannot preserve the `protected_root=true/false` distinction that 2-arg with bool form `(tokens, protected_root)` and 5-arg form `(tokens, protected_root, namespace_id, target_bytes, draft_bytes)` provide; the only available fix that preserves `protected_root` is a production code change to add a new debug helper `(tokens, metadata, protected_root)`. Report this as a substantive issue to Manager rather than applying the metadata form and letting the test fail at a different point.


## Improvement: Verify test assertion line numbers against actual test code, not report claims

Condition:

- When a test report or fixes file claims a specific test function crashed at a specific line number, and the Developer needs to fix the test

Action:

- Do verify the line number by reading the test file directly and matching the assertion text to the test function; don't trust the report's attribution without verification. A prior batch fix report may have misattributed the crash to test N when it was actually test N-1 (e.g., "test 20 line 609" was actually "test 19 line 609" because test 19's assertion was at line 609 in the committed code). Use `git show <commit>:tests/test-cache-controller.cpp` to check the line numbers in the committed code, not the working tree.

## Improvement: Check build artifact timestamps against source timestamps before running tests

Condition:

- When a cmake --build completes with exit 0 but the test results don't match the expected behavior of the current source code

Action:

- Do check the binary timestamp against the source file timestamps before running tests; if the binary timestamp is BEFORE the source file timestamp, the binary is stale and the test results are from the old code. Rebuild explicitly and verify the binary timestamp is AFTER the source timestamp before drawing conclusions from test failures. Verified 2026-06-11 (Stage 14 test 20 fix): a cmake --build at 23:42 produced a binary at 23:41:59, but my source changes were at 23:46:25; the test binary I ran was the old one and the test failure was from the old code, not my new code. The fix was to rebuild explicitly and verify the new binary timestamp.


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
  more. Verified 2026-06-11 (Stage 14 test 21 fix):
  fixing test 21 exposed test 22 (entry_count + find_match),
  fixing test 22 exposed test 23 (same), fixing test 23
  exposed test 24 (same with "h31" namespace), fixing test
  24 exposed test 25 (same with "h32" namespace), fixing
  test 25 exposed test 26 (meta namespace + entry_count),
  fixing test 26 exposed test 27 (empty tokens + namespaces
  count), fixing test 27 exposed test_stage9 (workload
  profile substantive issue). The iteration took 5 build +
  test cycles to reach the substantive issue.


## Improvement: Assert-inversion defects masked by NDEBUG

Condition:

- When the test binary crashes at an assertion in a test
  function that was previously passing in a build with
  NDEBUG defined, and the assertion inverts the helper
  function's return value (e.g., asserts true when the
  helper unconditionally returns false to test a failure
  path)

Action:

- Do check the helper's hard-coded failure path (e.g.,
  `const bool draft_apply_failed = true; ... return false;`)
  before assuming the test code is correct. The 20260607
  build had NDEBUG defined, so `assert()` was a no-op and
  the inverted assertions did not fire. When the build
  switched to NDEBUG-less Release, every inverted
  assertion fires in order, each one exposing the next
  latent defect. Verified 2026-06-12 (Stage 14
  comprehensive fix): fixing the line 2097 crash exposed
  the line 2141 crash (debug_first_entry_metadata_only_
  for_tests is a query, not a converter), then the line
  2182 crash (wrong counter), then the line 2359 crash
  (async promote_payload), then the line 2436 crash (same
  async pattern), then the line 2532 crash (production
  keeps entries in list), then the line 2653 crash (wrong
  stat values), then the line 2713 crash (wrong expected
  size). Each defect was pre-existing and masked by
  NDEBUG. Read the entire test file in one pass before
  fixing iteratively; the user directive "Batch-fix all
  found defects, don't defer anything" applies to all
  exposed defects, not just the current crash point.
