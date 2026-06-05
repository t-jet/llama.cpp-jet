# Build defect: semantic duplicates from the real merge (2026-06-04 / 2026-06-05)

Source: [./part-15-real-merge-correction.md](./part-15-real-merge-correction.md)
Date: 2026-06-04 to 2026-06-05

This part records the two build-defect fix attempts that the
Manager binding decision authorized after the real merge
`e0f3f868b` surfaced semantic duplicates in
`tools/server/server-context.cpp` that git's 3-way merge did
not flag. The final fix commit is `602f3e3f0`.

## Follow-up: near_prompt_end fix attempt and second pre-existing duplicate (2026-06-04)

The Manager binding decision authorized the minimum
duplicate-declaration fix for `near_prompt_end` at
`tools/server/server-context.cpp:3651/3653`. The fix
was applied and is correct in isolation, but the build
progressed past the first error and hit a second
pre-existing semantic duplicate that the prior build
halt was masking. The second duplicate is OUT OF SCOPE
for the binding decision and needs a new Manager
authorization before any commit.

### Fix applied

- File: `tools/server/server-context.cpp`
- Diff: 2 lines removed (1 duplicate declaration, 1
  orphan blank line). No insertions.
- `git diff --check -- tools/server/server-context.cpp`:
  exit 0, clean.
- Worktree line endings: LF only (6796 LF, 0 CR),
  preserved from HEAD blob format. HEAD blob is CRLF
  (6798 LF, 6798 CR); the worktree was LF before the
  edit and stayed LF after.

### Why line 3651 was kept

The two declarations were byte-identical, so removing
either is semantically equivalent. Line 3651 was
chosen because (a) the QA fix report
(`test-report-20260604-05-fixes.md`) recommended it,
and (b) it sits adjacent to the `batch_request_embd`
declaration above, so the natural lexical grouping
stays intact after removal.

### `git blame` evidence for the two declarations

- Line 3651 (kept): `72cfbcd44e` (t-jet, 2026-06-04,
  Stage 11 merge commit). Brought the declaration in
  from the cache-optimization side.
- Line 3653 (removed): `e2ef8fe42c` (jacekpoplawski,
  2026-05-25, "server: fix checkpoints creation"
  PR #22929). The upstream_master-side declaration.

### Build status: BLOCKED on a second pre-existing duplicate

After the `near_prompt_end` fix was applied,
`cmake --build build-cov --config RelWithDebInfo
--target llama-server` compiled further and hit a
`server_n_outputs_max` redefinition:

```text
server-context.cpp(219,17): error C2084: function
  'uint32_t server_n_outputs_max(const common_params &)'
  already has a body [server-context.vcxproj]
      server-context.cpp(204,17):
      see previous definition of 'server_n_outputs_max'

server-context.cpp(1124,37): error C2264:
  'server_n_outputs_max': error in function definition
  or declaration; function not called
```

The two function bodies are byte-identical (PowerShell
string-compare over lines 204-217 vs 219-232 confirmed
`BODIES ARE BYTE-IDENTICAL`).

`git blame` evidence for the two function copies:

- Line 204 (first copy, kept candidate):
  `72cfbcd44e` (t-jet, 2026-06-04, Stage 11 merge
  commit). Brought the function in from the
  cache-optimization side.
- Line 219 (second copy, removal candidate):
  `de6f727aae` (Aman Gupta, 2026-06-01, "llama: limit
  max outputs of `llama_context`" PR #23861).
  Reachable from `upstream_master`.

This is the same root cause as `near_prompt_end`:
`git merge`'s 3-way resolver placed both parents'
copies at adjacent positions because the merge base
did not contain the symbol. The prior build halt on
`near_prompt_end` masked this second error.

The Manager binding decision authorized only the
`near_prompt_end` fix, with the hard constraint
"Minimum diff. 1-3 lines of change." The second
duplicate is 13 lines (the function body) plus a
blank line, so it is out of scope and needs a new
Manager decision.

### Worktree state

The `near_prompt_end` fix is applied to the worktree
but uncommitted. The worktree also carries an
unrelated uncommitted change to
`.agents/skills/self-improvement/assets/qa.md`
(QA's own memory file, not touched in this session).
No commit was made because the build is blocked,
and committing a single-fix tree that does not
compile would leave the next developer without the
correct state.

### Next owner: Manager

The next Manager decision must authorize one of:

1. Remove the second `server_n_outputs_max` copy
   (lines 219-232 plus the blank at 233) using the
   same pattern as the `near_prompt_end` fix. The
   two bodies are byte-identical, so removing
   either is semantically correct. Recommended:
   remove the second copy (Aman Gupta's), keep the
   first (merge commit's), matching the
   cache-optimization chain the Stage 11 work is
   built on.
2. Revert the `near_prompt_end` fix and re-plan the
   merge resolution as a single combined edit that
   removes both duplicates in one pass.
3. Re-run the real merge from scratch with a
   duplicate-finding pass done up front to surface
   all semantic duplicates before resolving
   conflicts.

### What is NOT done in this attempt

- Full clean rebuild: not done.
- Full test suite: not done (QA gate).
- Second duplicate fix: not done. Needs Manager
  authorization.
- Commit of the `near_prompt_end` fix: not done.
  The fix is correct in isolation but the build is
  blocked, so committing would leave a tree that
  does not compile.
- Push to remote: not done.
- Stage 11 closure status: not changed.

## Follow-up: all semantic duplicates from real merge (2026-06-04)

The prior `near_prompt_end` fix attempt was correct in
isolation but the build progressed past the first error
and surfaced a second pre-existing duplicate. The Manager
binding decision authorized fixing both duplicates plus
any further duplicates in the same file or other files
modified by the merge.

### Files both parents modified

`git diff --name-only 3b9ed9712..e0f3f868b` and
`git diff --name-only 6ddc9430b..e0f3f868b` intersect at
two files:

- `common/fit.h` - resolved with conflict at merge time,
  no duplicate bodies in the resolution.
- `tools/server/server-context.cpp` - 9 upstream commits
  plus the Stage 11 cache-optimization commits. Highest
  risk.

### Duplicate scan of server-context.cpp

A regex scan of the worktree file for any name appearing
twice at file scope returned 8 candidates. A manual scope
check ruled out 7 of them:

- `get_response_reader` (lines 4136, 4165): one is a
  method in `server_context_impl`, the other is a class
  forwarder (`server_context::get_response_reader`).
- `init` (lines 938, 1550): one is `void init()` in the
  metrics class, the other is `bool init()` in
  `server_context_impl`. Different classes, different
  signatures.
- `load_model` (lines 1118, 4148): one is a method in
  `server_context_impl`, the other is a class forwarder.
- `load_slot` (lines 6526, 6772): one is
  `hybrid_cache_controller::load_slot`, the other is
  `legacy_cache_controller::load_slot`. Different classes.
- `save_slot` (lines 6058, 6767): one is
  `hybrid_cache_controller::save_slot`, the other is
  `legacy_cache_controller::save_slot`. Different classes.
- `send_error` (lines 2193, 2197, 2201): three overloads
  in the same class, different parameter types.
- `try_send_error` (lines 2218, 2228): two overloads in
  the same class, different parameter types.

Only `server_n_outputs_max` is a true duplicate: two
`static` definitions at file scope with byte-identical
bodies.

### Duplicates fixed in this session

| Name | Lines removed | Lines kept | Kept from | Removed from |
| ------ | -------------- | ------------ | ----------- | -------------- |
| `const bool near_prompt_end` | 3653 + blank 3654 | 3636 | `72cfbcd44e` (merge commit, cache side) | `e2ef8fe42c` (PR #22929, upstream) |
| `static uint32_t server_n_outputs_max(...)` body | 219-232 + blank 218 | 204-217 | `72cfbcd44e` (merge commit, cache side) | `de6f727aae` (PR #23861) + `5dcb711666` (PR #23988) |

Why these lines were kept:

- `near_prompt_end` at line 3636 sits adjacent to the
  `batch_request_embd` assignment above, so the natural
  lexical grouping of the per-slot checkpoint/embedding
  state stays intact.
- `server_n_outputs_max` at line 204 is the first `static`
  definition in this scope and matches the
  cache-optimization chain the Stage 11 work is built on.

### Blame evidence

`server_n_outputs_max`:

- Lines 204-217 (kept): `72cfbcd44e` (t-jet, 2026-06-04,
  Stage 11 merge commit). Brought in from the
  cache-optimization side.
- Line 218 (blank, removed): `72cfbcd44e`.
- Lines 219-232 (removed): `de6f727aae` (Aman Gupta,
  2026-06-01, "llama: limit max outputs of
  llama_context" PR #23861) for all lines except line 227,
  which is `5dcb711666` (Georgi Gerganov, 2026-06-01,
  "speculative: fix n_outputs_max and remove draft-simple
  auto-enable" PR #23988). The two upstream copies drifted
  only in indentation/whitespace around line 227. Both
  upstream copies are byte-identical to the kept
  cache-side copy.

`near_prompt_end`:

- Line 3636 (kept, after the 17-line shift from old line
  3651): `72cfbcd44e` (t-jet, 2026-06-04, Stage 11 merge
  commit). Brought in from the cache-optimization side.
- Line 3637 (blank, kept): `72cfbcd44e`.
- Old line 3653 (removed, shifted to old line 3637 in the
  pre-commit hunk): `e2ef8fe42c` (jacekpoplawski,
  2026-05-25, "server: fix checkpoints creation"
  PR #22929). The upstream-side declaration.

### Build status

- Incremental compile to binding target: PASS.
  `cmake --build D:/source/llama.cpp-jet/build-cov
  --config RelWithDebInfo --target llama-server`
  completed end-to-end with exit 0. The build produced
  `llama-server.exe` at
  `D:/source/llama.cpp-jet/build-cov/bin/RelWithDebInfo/llama-server.exe`
  (37376 bytes, last written 2026-06-05 00:34:41) plus
  `ggml-base.dll`, `ggml-cpu.dll`, `ggml.dll`, `llama.dll`,
  `llama-server-impl.dll`.
- `git diff --check -- tools/server/server-context.cpp`:
  exit 0, clean.
- `git diff --check HEAD~1..HEAD -- tools/server/server-context.cpp`:
  exit 0, clean.
- Worktree line endings: LF only (6781 LF, 0 CR, 0 CRLF).
  The HEAD blob is CRLF; the worktree was LF before the
  edit and stayed LF after.
- Full clean rebuild: not done. QA gate.
- Full test suite: not done. QA gate.

### Fix commit

- SHA: `602f3e3f0415988d5884635eda698f3f57af3afe`
- Subject: `server: remove duplicate definitions from
  real merge of upstream_master`
- Parent: `2aae72085` (Stage 11 merged docs commit on top
  of the real merge `e0f3f868b`). Commit chain between
  the real merge and this fix:
  `e0f3f868b` (merge) -> `2aae72085` (docs) -> `602f3e3f0`
  (this fix). The `2aae72085` commit does not touch
  `server-context.cpp`, so this fix is effectively on
  top of the real merge for the code path.
- Files in the commit: `tools/server/server-context.cpp`
  only. 17 lines removed, 0 inserted. No doc or memory
  file in the commit.

### What is NOT done

- Full clean rebuild: not done.
- Full test suite: not done. QA gate.
- Stage 11 closure status: not changed.
- Push to remote: not done.
- Commit of `part-15`, `developer.md`, `qa.md`, QA report
  files: not done. Architect gate.

### Next owner

QA for full clean rebuild + test re-execution on the
fix commit `602f3e3f0`.
