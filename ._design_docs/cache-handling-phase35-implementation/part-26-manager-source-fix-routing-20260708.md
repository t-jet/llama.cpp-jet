# Stage 35 Manager source-fix routing 2026-07-08

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Verdict

PASS. Route the open no-commit merge back to Developer for a focused
merge-resolution source-fix session.

## Evidence reviewed

- Part 22 kept the corrected `upstream_master` source ref stable:
  `origin/upstream_master`, remote `refs/heads/upstream_master`, and
  `MERGE_HEAD` all matched `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe`.
- Part 24 found the first focused retry blocked by a corrupt CUDA object
  (`LNK1136` on `ggml-cuda.dir\Release\argsort.obj`).
- Part 25 pruned the stale CUDA object directory. CUDA objects then rebuilt and
  relinked cleanly, closing the Part 24 object-corruption blocker.
- Part 25 then exposed 27 real compile errors in `server-context.cpp` and
  `server-cache-hybrid.cpp`. The first error is a duplicate `server_state`
  definition; the remaining representative errors are field and helper-name
  mismatches introduced by the merge.

## Gate decision

The active gate remains implementation correction. Architect implementation
review is not useful while the source tree cannot build and the error set is
already classified as merge-resolution defects.

Developer is authorized to edit the minimum source needed to resolve the Part 25
compile errors and preserve Stage 35 merge behavior. Expected scope:
`tools/server/server-context.cpp`, `tools/server/server-context.h`,
`tools/server/server-cache-hybrid.cpp`, and directly required nearby server
types or helpers.

Developer must not abort the merge, create a merge commit, push, create a PR, or
reply to reviewers. Existing staged upstream merge changes and Stage 35
documentation must be preserved.

## Required Developer evidence

- Source-ref check still matching `MERGE_HEAD` and `origin/upstream_master`.
- No unresolved conflict paths.
- Summary of each source fix class.
- Clean focused build for `llama-server` and `test-cache-controller`, or a new
  blocker with full compiler evidence.
- Focused test evidence if the build reaches test execution.
- New implementation evidence part and entry-document update.

## Next owner

Developer.

Next gate: implementation correction for the open no-commit merge.
