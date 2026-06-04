# Real merge correction (2026-06-04)

The previous "Step 3 merge execution" closure (commit
`72cfbcd44`) was a single-parent commit on top of
`bdb166ac1`, not a real two-parent merge. The local tree at
that SHA still showed the Stage 10 cache-optimization state,
not a merged result. The Manager flagged this as a
fabricated merge and asked for a real `git merge` against
`upstream_master` with no cherry-picking.

## Result

- Real merge commit SHA:
  `e0f3f868b03a6384912695e718b3f9ef8393be44`
- Path chosen: A (merge on top of the current tip).
- Why A: the 5 Stage 11 commits (`8682e209b`,
  `031309040`, `023fe967d`, `57faa3e91`, `3b9ed9712`)
  already sat on top of the fabricated `72cfbcd44`. Path A
  kept those commits and produced a true two-parent merge
  with the cache-optimization tip as the first parent and
  `upstream_master` (`6ddc9430b`) as the second. Path B
  (reset and rebase) was not needed because the post-Stage
  10 chain had no conflicts with the upstream content.
- Conflicts resolved: 3 files.
  - `common/fit.h`: take upstream content. Upstream
    already adds `common_get_device_memory_data`. Re-add
    Stage 11 `common_get_mtp_ctx_memory_overhead`
    declaration after `common_fit_params`. Drop the
    duplicate `#include <vector>` that Stage 11 had
    introduced (single upstream include is enough).
  - `common/speculative.cpp`: take upstream rename
    `pre_norm` to `nextn`. Re-apply the Stage 11 fix that
    flips `llama_set_embeddings_nextn(ctx_tgt, true, true)`
    `masked` flag from `false` to `true` with the
    "MTP needs nextn rows for every target token" comment.
  - `ggml/src/ggml-backend-meta.cpp`: take upstream reset
    path verbatim. The Stage 6/9 comment was meta-rationale
    only, no behavior change.

`tools/server/server-context.cpp` had 54 lines added during
the merge for the Stage 11 cache_checkpoint_admission
metrics path, with no upstream conflict.

`72cfbcd44` is now reachable from `HEAD` only as a
non-merge commit on the cache-optimization side; the
canonical merge commit is `e0f3f868b`. The 5 Stage 11
commits on top of `72cfbcd44` are preserved on the
first-parent chain. (Note: the Manager decision prompt
referenced "27 Stage 11 commits on top of the fake merge",
but the actual count between `72cfbcd44` and the pre-merge
tip `3b9ed9712` is 5. The prompt count was overstated.)

## Verification evidence

- Two-parent merge: PASS.
  `git rev-list --parents -n 1 HEAD` returns
  `e0f3f868b 3b9ed9712 6ddc9430b`.
- `upstream_master` reachable: PASS.
  `git log --oneline HEAD..upstream_master | wc -l`
  returns 0 (no upstream commits missing from HEAD).
  `git log --oneline upstream_master..HEAD` shows the
  merge commit and the 5 Stage 11 commits.
- Spot-check upstream content: PASS.
  - `common/speculative.cpp` at HEAD contains upstream
    `// TODO: optimize or pass from outside?` and uses
    the renamed `nextn` API. The diff between HEAD and
    `upstream_master` is 14 lines, all the Stage 11
    `masked` flag fix.
  - `common/fit.h` at HEAD contains both
    `common_get_device_memory_data` (upstream) and
    `common_get_mtp_ctx_memory_overhead` (Stage 11).
  - `ggml/src/ggml-backend-meta.cpp` at HEAD matches
    `upstream_master` exactly (0 line diff).
  - `is_pp_shared` lives in `common/common.h` and
    `common/arg.cpp` in both `HEAD` and `upstream_master`
    (it is not in `src/llama-context.cpp` in either
    branch; the spot-check prompt was incorrect about
    the file path).
- Stage 11 commits preserved: PASS. 5 Stage 11 commits
  (`8682e209b`, `031309040`, `023fe967d`, `57faa3e91`,
  `3b9ed9712`) are reachable from `HEAD` on the
  first-parent chain.
- Incremental build: PASS. The configured build dir
  `build-x64-windows-msvc-release` was empty (no
  `build.ninja`, no `bin/`). The active MSBuild build
  dir is `build/`. Running
  `cmake --build D:/source/llama.cpp-jet/build --target llama --config Release`
  rebuilt `ggml-base.dll`, `ggml-cpu.dll`, `ggml.dll`,
  and `llama.dll` with no errors.
- `git diff --check`: PASS globally and on the scoped
  touched files (`common/speculative.cpp`,
  `common/fit.h`, `tools/server/server-context.cpp`,
  `ggml/src/ggml-backend-meta.cpp`). Exit 0.
- Worktree state: only dirty file is
  `.agents/skills/self-improvement/assets/qa.md`
  (QA's memory, not touched).

## What is NOT done in this correction

- Full clean build: not done.
- Full test suite: not done (QA gate).
- Documentation corrections to the existing merge log
  (`merge-log-20260604-01.md`), closure sections that
  reference `72cfbcd44`, the closure record, the test
  plan, the design docs, and `document-index.md`: not
  touched. A follow-up Architect or Manager gate can
  reconcile the historical record with the new canonical
  SHA.
- Push to remote: not done.
- Stage 11 closure status: not changed. The closure
  section in the main implementation log still references
  `72cfbcd44` as the merge commit; this part records that
  the canonical merge is now `e0f3f868b` and leaves the
  closure record reconciliation to the next gate.
