# Test report 20260611-01 fixes: Stage 14 merge semantic conflict in server-context get_meta()

Source: [test-report-20260611-01.md](test-report-20260611-01.md)
Part 01 status: PARTIAL FIX (Developer applied; new build defect discovered)
Part 02 status: TEST FIX APPLIED; build PASS; ctest 67/69 with 1 new
pre-existing runtime defect at line 571; T114/T114a BLOCKED on new defect.
See [test-report-20260611-01-fixes-part02-testfix.md](test-report-20260611-01-fixes-part02-testfix.md).

## Build defect

The build-cov relink (cmake --build build-cov --config Release --target
test-cache-controller test-step10-metrics test-stage10-cold-store-hardening
test-stage10-policy-lru test-step6-demotion-protocol test-step7-promotion-protocol
test-step11-test-hooks-fault-injection test-step12-branch-graph test-step13-stage8
llama-server -j 4) failed with MSVC errors in tools/server/server-context.cpp.

Log: [build-cov-relink-stage14-step5-20260611-01.log](build-cov-relink-stage14-step5-20260611-01.log)

Errors:

- server-context.cpp(1649,13): error C2679 binary '=' no operator found
  which takes a right-hand operand of type 'initializer list'
- server-context.cpp(4160,32): error C2440 function-style-cast cannot
  convert from 'initializer list' to 'server_context_meta'
- Cascade at server-context.cpp(4174,42), (4175,68), (4177,38), (4179,57),
  (4186,64), (4188,54), (4189,58)

## Parent commit analysis

The merge commit 08f3a6155 is a two-parent merge:

- parent 1: 02db7a768 (local master tip pre-merge)
- parent 2: 18ef86ece (upstream master tip, origin/upstream_master)

Git diff parent1..merge for tools/server/server-context.h (one hunk):

```text
@@ -26,6 +26,7 @@ struct server_context_meta {
     bool has_mtmd;
     bool has_inp_image;
     bool has_inp_audio;
+    bool has_inp_video;
     json json_ui_settings;
     json json_webui_settings;
     int slot_n_ctx;
```

This hunk was added by upstream commit 8f83d6c27 ("mtmd : add video input
support (#24269)"), which is one of the 94 commits in the
master..origin/upstream_master range.

Git diff parent1..merge for tools/server/server-context.cpp (one hunk,
51-line addition at the end of the file, unrelated to get_meta()):

```text
@@ -6779,3 +6779,54 @@ size_t legacy_cache_controller::size() const {
 ...
+std::unique_ptr<server_res_generator> server_routes::handle_count_tokens(...)
+{ ... }
```

Git's 3-way merge resolved the conflict by taking upstream's struct change
in the .h file verbatim and keeping the local parent's get_meta() body in
the .cpp file unchanged. Git did not flag this as a conflict because the
additions are in different files (and even within server-context.cpp, the
local parent's get_meta() and the upstream-added handle_count_tokens are
in non-overlapping regions).

The local parent (02db7a768) had not anticipated the new struct field, so
the get_meta() initializer list in the merged tree is missing the
has_inp_video entry. The brace-enclosed initializer list maps
json_ui_settings to has_inp_video (type mismatch: json vs bool), and the
rest of the initializer values cascade to wrong fields, producing the
compiler error cascade.

## Proposed one-line fix

In tools/server/server-context.cpp, function server_context::get_meta(),
insert one initializer between has_inp_audio and json_ui_settings at
approximately line 4167 (the exact line depends on any whitespace edits
between the merge and now).

Before (current post-merge, broken):

```text
        /* has_inp_image          */ impl->chat_params.allow_image,
        /* has_inp_audio          */ impl->chat_params.allow_audio,
        /* json_ui_settings       */ impl->json_ui_settings,
```

After (proposed):

```text
        /* has_inp_image          */ impl->chat_params.allow_image,
        /* has_inp_audio          */ impl->chat_params.allow_audio,
        /* has_inp_video          */ impl->chat_params.allow_video,
        /* json_ui_settings       */ impl->json_ui_settings,
```

The init expression `impl->chat_params.allow_video` matches the pattern
used for has_inp_image and has_inp_audio. Whether
`server_chat_params` has an `allow_video` field needs to be confirmed by
reading common/chat.h around the allow_image and allow_audio members; if
it does not, use the equivalent getter (e.g., `impl->params_base...` or
the matching accessor the upstream commit introduced).

## Scope of fix

- One line in one function in one file.
- The fix is the minimum change to unblock the build. It does not add
  new tests, does not change behavior, and does not touch the durable
  docs, closure record, implementation log, or document-index.md.
- After the fix, the Developer rebuilds build-cov (cmake --build build-cov
  --config Release --target llama-server test-cache-controller ...), then
  hands the tree back to QA for the T114/T114a rerun.

## What QA will do after the fix

1. Verify build-cov relink succeeds with no MSVC errors in
   server-context.cpp.
2. Verify the test binaries in build-cov/bin/Release are dated after the
   fix and link against the post-fix .lib.
3. Re-run the OpenCppCoverage script
   ._design_docs/cache-handling-test-scripts/run_coverage.ps1 with the
   -SkipServerProbe flag (same configuration as the 20260607-02 static
   run, which produced a valid 92.76% combined rate pre-merge).
4. Cite the new coverage-report.md `## Combined result` and
   `## Product-only result` blocks in the next test report.
5. Update test-report-20260611-01.md and this fixes file with the rerun
   outcome and the post-fix numbers.

## Notes for the Developer

- The Step 3 ctest 61/69 (88%) cited in the cycle state was run on the
  build/ tree (BUILD_SHARED_LIBS=ON) using .obj files dated 2026-06-10
  15:17 (pre-merge). The build/ tree was not rebuilt on 2026-06-11
  because the merged sources' LastWriteTime is 2026-06-11 15:34, after
  the Step 3 build pass. After the one-line fix, the Developer should
  also rebuild build/ to confirm the same fix resolves both build
  trees.
- The 94-commit merge range includes other source-level changes that
  could also require follow-up adjustments. The pre-merge report
  [pre-merge-report-20260611-01.md](pre-merge-report-20260611-01.md)
  lists the 16 INTEGRATE and 7 DEFER (in-scope) commits. None of those
  commits is expected to require additional source edits outside of
  what the merge already brought in.
- The 9 focused test binaries in build-cov/bin/Release are statically
  linked. After the one-line fix and a full build-cov rebuild, the
  coverage run will execute the post-fix code paths.

## Fix applied (Developer, 2026-06-11)

QA proposed a one-line fix at server_context::get_meta() line ~4167. After
applying it, the build halted at a second instance of the same defect
(server_chat_params initializer at line 1649 missing `allow_video`),
which the QA "Cause" section did not list separately. After applying the
second one-line fix in the same file (same root cause: upstream commit
8f83d6c27 added both `has_inp_video` and `allow_video`), the build
progressed past server-context.cpp and halted at a NEW defect in
`tests/test-cache-controller.cpp` (see "New defect discovered" below).

### One-line fixes applied to tools/server/server-context.cpp

Fix 1 (line 4170, server_context::get_meta initializer for
server_context_meta): add the upstream-introduced `has_inp_video` field
between `has_inp_audio` and `json_ui_settings`.

Fix 2 (line 1657, server_chat_params initializer in
server_context_impl::init, the brace init for `chat_params = { ... }`):
add the upstream-introduced `allow_video` field between `allow_audio`
and `enable_thinking`. The init expression
`mctx ? mtmd_helper_support_video(mctx) : false` matches the symbol
upstream commit 8f83d6c27 used (mtmd-helper.h:32).

Diff (full, server-context.cpp):

```text
diff --git a/tools/server/server-context.cpp b/tools/server/server-context.cpp
index c96b1cd1a..66ee3845a 100644
--- a/tools/server/server-context.cpp
+++ b/tools/server/server-context.cpp
@@ -1654,6 +1654,7 @@ private:
                 /* tmpls                 */ std::move(chat_templates),
                 /* allow_image           */ mctx ? mtmd_support_vision(mctx) : false,
                 /* allow_audio           */ mctx ? mtmd_support_audio (mctx) : false,
+                /* allow_video           */ mctx ? mtmd_helper_support_video(mctx) : false,
                 /* enable_thinking       */ enable_thinking,
                 /* reasoning_budget      */ params_base.sampling.reasoning_budget_tokens,
                 /* reasoning_budget_msg  */ params_base.sampling.reasoning_budget_message,
@@ -4166,6 +4167,7 @@ server_context_meta server_context::get_meta() const {
         /* has_mtmd               */ impl->mctx != nullptr,
         /* has_inp_image          */ impl->chat_params.allow_image,
         /* has_inp_audio          */ impl->chat_params.allow_audio,
+        /* has_inp_video          */ impl->chat_params.allow_video,
         /* json_ui_settings       */ impl->json_ui_settings,
         /* json_webui_settings    */ impl->json_webui_settings,  // Deprecated
         /* slot_n_ctx             */ impl->get_slot_n_ctx(),
```

The diff is LF-only, ASCII (no new non-ASCII introduced; the pre-existing
em dash at line 595 in HEAD is untouched), and `git diff --check` is
clean. The fix is the minimum change to restore the brace-init
aggregates; behavior is unchanged because the new fields are sourced
from the same `chat_params` the struct already exposes.

### Build results

- build-cov rebuild: HALTED on a NEW defect in
  `tests/test-cache-controller.cpp`, NOT on the QA-reported defect.
  See "New defect discovered" below. server-context.cpp itself compiled
  successfully after both one-liners; the cascade is resolved.
  Build log: [build-cov-rebuild-stage14-fix-20260611-01.log](build-cov-rebuild-stage14-fix-20260611-01.log).
- build/ rebuild: NOT ATTEMPTED. The new test-cache-controller.cpp
  defect is a static-lib link target that affects both build-cov and
  build/, so the build/ rebuild would halt at the same new error. The
  Developer did not run a doomed rebuild. Per the binding rule
  "if the build fails for any other reason, STOP and document", the
  Developer did not proceed.

### ctest results

- ctest build-cov: NOT RUN. The test binaries did not link.
- ctest build/: NOT RUN. The build/ tree was not rebuilt.
- The Step 3 ctest 61/69 (88%) measurement on the stale pre-merge build/
  tree (per the original report "Notes for the Developer") is now
  confirmed stale on a different dimension: even if build/ rebuilds
  cleanly, the test binaries need to be relinked after the server-context.cpp
  fix to pick up the new initializers. The 61/69 number is invalidated
  by the merge and by this fix.

### Fix commit

The fix commit is in a separate commit from this fixes file update.
After both commits land on master:

- Fix commit: 16b416991e674c384dc7dd6e42edf7f39d977b1c
  "Stage 14 Step 3 fix: add has_inp_video and allow_video field
  initializers in server-context.cpp" (one line in server_chat_params
  init at 1657, one line in server_context_meta init at 4170).
- Docs commit: the second commit in the Stage 14 Step 3 fix series
  (parent = 16b416991, subject = "Stage 14 Step 3 fix: QA fixes
  file update + build logs (worktree artifacts)"). The actual SHA
  is not pinned in this file because the file is part of the docs
  commit, so any in-file reference to the docs commit SHA would
  change with each amend. The two build logs
  (build-cov-relink-verify-20260611-01.log and
  build-cov-rebuild-stage14-fix-20260611-01.log) are not committed:
  the repo `.gitignore` matches `*.log` and `/build*`, so the logs are
  worktree-only artifacts by the same convention as the QA's own
  `build-cov-relink-stage14-step5-20260611-01.log`. The logs are
  LF-only and ASCII after the Developer's post-Out-File conversion.

## New defect discovered (Developer, 2026-06-11)

After the QA defect is fixed, the build-cov rebuild halts in
`tests/test-cache-controller.cpp` with three MSVC errors that are NOT
in the QA report's errors list. This is a pre-existing defect in the
local test code (commit 023fe967d1, 2026-06-04, t-jet) that the merge
exposed by changing the underlying classes.

Errors (full list, from
build-cov-rebuild-stage14-fix-20260611-01.log):

- test-cache-controller.cpp(1804,5): error C2668
  `hybrid_cache_controller::debug_admit_checkpoint_for_tests`:
  ambiguous call to overloaded function. Three overloads exist in the
  merged `server-cache-hybrid.h:331-333`:
  - `debug_admit_checkpoint_for_tests(size_t, size_t)` (2 args, 1748)
  - `debug_admit_checkpoint_for_tests(size_t, size_t, bool fail_after_descriptor)` (3 args, bool, 1752)
  - `debug_admit_checkpoint_for_tests(size_t, size_t, int64_t token_span_end)` (3 args, int64_t, 1775)
  The test calls `ctrl.debug_admit_checkpoint_for_tests(64, 0, 2)` with
  literal `2`, which is ambiguous between `bool` (with implicit
  conversion) and `int64_t`. Comment at line 2353 indicates the
  third (int64_t) overload was the intended target
  (`token_span_end = 3` forced the restore token count to a value
  below the full token count).
- test-cache-controller.cpp(1957,9): error C2838 `evicted_residency`:
  illegal qualified name in member declaration. Test uses
  `payload_debug_fault::evicted_residency` (line 1957), but the
  merged `payload_debug_fault` enum in
  `server-cache-hybrid.h:136` does not declare an `evicted_residency`
  member. Existing members (per `git grep payload_debug_fault::` in
  the merged tree): `unsupported_version`, `unsupported_kind`,
  `zero_target_size`, `target_size_mismatch`, `missing_target_bytes`,
  `bad_store_ref`, `missing_hot_record`, `owner_mismatch`,
  `cold_residency`, `unexpected_draft_for_target_only`,
  `missing_draft_for_pair`, `draft_size_mismatch`,
  `draft_checksum_mismatch`, `demoting_residency`,
  `promoting_residency`. No `evicted_residency`.
- test-cache-controller.cpp(2357,5): error C2668 same root cause as
  line 1804 (another ambiguous `debug_admit_checkpoint_for_tests(64, 0, 3)`).
- test-cache-controller.cpp(1957,9): error C2065 `evicted_residency`:
  undeclared identifier (companion diagnostic to C2838).

Parent analysis (updated after verifying the local parent):

- Parent 1 (02db7a768, local) ALREADY had the same enum and overloads
  that the merged tree has today. Verified via
  `git show 02db7a768:tools/server/server-cache-hybrid.h`:
  - `payload_debug_fault` enum at local parent: no `evicted_residency`
    member, same set of values as the merged tree
    (unsupported_version, unsupported_kind, ..., cold_residency, ...,
    demoting_residency, promoting_residency).
  - `debug_admit_checkpoint_for_tests` overloads at local parent:
    three overloads (2-arg, 3-arg bool, 3-arg int64_t), same as
    merged tree.
- Parent 1 ALSO had `tests/test-cache-controller.cpp` with the same
  test calls (line 1957 references `payload_debug_fault::evicted_residency`;
  line 1804, 2357 call `debug_admit_checkpoint_for_tests(64, 0, <literal>)`).
  The test file at the local parent would not compile against the
  local parent's headers either.
- Parent 2 (18ef86ece, upstream) did not have
  `tests/test-cache-controller.cpp` (the diff between the parents
  shows upstream deleted the file; the merge kept the local parent's
  copy). The merge did NOT modify the test file.

Conclusion: the new defect is pre-existing in the local parent and is
NOT a merge regression. The Step 3 ctest 61/69 PASS on the build/ tree
on 2026-06-10 (per the original test report) reflects the build/ tree's
test binaries that pre-dated the Stage 11/12/13 work that introduced
the broken test file, or the build/ tree's configuration that excluded
the test from compilation. The build-cov/bin/Release/test-cache-controller.exe
dated 2026-06-07 may have been built against an earlier header that
did not yet have the third int64_t overload, which is why it linked at
that time.

This is the same class of defect as the QA-reported one (struct field
change with downstream initializer impact) but it pre-dates the merge.
The Developer did NOT attempt a fix because:

1. The user task constraint is "If the build defect is NOT the one
   QA reported, report the actual error and stop. Do not attempt
   unrelated fixes."
2. The Developer memory "Real-merge build halt may mask other
   latent duplicates" says to STOP at the second pre-existing
   duplicate and escalate a new Manager decision rather than expand
   the authorized scope unilaterally.
3. The test-cache-controller.cpp file is owned by Stage 11/13
   developer work (commits 023fe967d1, 0c3c5b240, eadb3fb37,
   31d60a944), not by Step 3 merge work. A fix here may need
   author coordination, not unilateral edits.

The proposed minimum unblock would be:

- At line 1804, cast the literal: `int64_t(2)` (matches the
  token_span_end intent per the line 2353 comment), or rename the
  call to use the explicit 2-arg overload if no third arg was meant.
- At line 1957, replace `payload_debug_fault::evicted_residency`
  with the existing `payload_debug_fault::cold_residency` (the
  test name is `test_stage9_checkpoint_evicted_residency` and the
  intent is "evicted payload fault"; the closest existing enum is
  `cold_residency`).
- At line 2357, cast the literal: `int64_t(3)`.

But these are guesses. The Manager should decide whether the fix
belongs in Step 3 (Stage 14 merge) or in a follow-up Stage 11/13
corrections cycle. The test code may have been authored against a
planned enum that was later renamed, in which case the
`evicted_residency` test was already broken pre-merge and the
build was using a different enum at compile time.

## Handoff

- QA defect (server-context.cpp merge semantic conflict): FIXED.
  Two one-line additions in `tools/server/server-context.cpp` resolve
  the C2679/C2440 cascade and the missing `has_inp_video` /
  `allow_video` initializers. Fix is the minimum change; behavior
  is unchanged; LF-only ASCII; `git diff --check` clean.
- build-cov rebuild: NOT PASS. The build progressed past the
  QA-reported defect and halted at a new defect in
  `tests/test-cache-controller.cpp` (C2668 / C2838 / C2065). The
  test binary link target is broken. The new defect is documented
  above with blame evidence (commit 023fe967d1, 2026-06-04, t-jet,
  vs upstream header changes in commit 8f83d6c27 and neighbors).
- build/ rebuild: NOT ATTEMPTED. The new test-cache-controller.cpp
  defect affects the static lib in both build-cov and build/, so
  build/ would halt at the same error.
- ctest build-cov / ctest build/: NOT RUN. The test binaries did
  not link.
- Next gate: requires a Manager decision on the new
  test-cache-controller.cpp defect. Three options:
  1. Defer to a Stage 11/13 corrections cycle: open a Developer
     task to update the test file (line 1804, 1957, 2357) to match
     the merged header; run QA T114/T114a coverage on the resulting
     tree.
  2. Apply a Step 3 developer-side fix to the test file: cast
     literals to int64_t, replace evicted_residency with the
     closest existing enum value; run QA on the resulting tree.
     This expands the Developer scope beyond the QA-authorized
     one-liners in server-context.cpp and requires Manager
     authorization.
  3. Revert the merge: roll back to 02db7a768; redo the merge
     with conflict resolution that includes the test file. This
     is a Step 3 redo, not a Step 3 fix.
- T114/T114a coverage rerun: BLOCKED until the new defect is
  resolved. The current coverage configuration uses
  `build-cov/bin/Release/test-cache-controller.exe` and friends,
  which do not link.

## Part 02 follow-up (Developer, 2026-06-11)

The Manager's Path A decision (2026-06-11) authorized a minimal test
fix to address the test-cache-controller.cpp compile defects. See
[test-report-20260611-01-fixes-part02-testfix.md](test-report-20260611-01-fixes-part02-testfix.md)
for the full record. Summary:

- Defects 1 and 2 in part 02: FIXED. Test file diff is 13 insertions
  and 3 deletions across three locations (lines 1804, 1953-1965, 2357).
  LF-only ASCII, no BOM, `git diff --check` clean.
- build-cov rebuild: PASS. 106 executables built, no MSVC errors.
- ctest build-cov: 67 of 69 PASS, 2 failures:
  - test-stage10-policy-lru: pre-existing, unchanged.
  - test-cache-controller line 571 (`test_hybrid_rejects_partial_blob_match`):
    NEW pre-existing runtime defect exposed by the merge. The
    admission code path in the merged `server-cache-hybrid.cpp`
    rejects the entry that the test adds; the assertion at line
    571 fails. Not caused by the test fix; the test function
    itself was not modified.
- T114 / T114a: BLOCKED on the new line 571 defect. Coverage run
  was not executed.
- Next gate: Manager decision on the new pre-existing defect at
  test-cache-controller.cpp line 571. See part 02 "Handoff" for
  the three options.
