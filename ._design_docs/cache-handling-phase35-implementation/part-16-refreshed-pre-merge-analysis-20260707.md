# Stage 35 refreshed pre-merge analysis after abort 2026-07-07

Source: [../cache-handling-phase35-implementation.md](../cache-handling-phase35-implementation.md)

## Status

Verdict: REFRESHED ANALYSIS READY FOR ARCHITECT REVIEW.

Owner: Developer

Date: 2026-07-07

No merge command was run after this refreshed analysis. No conflict resolution,
production code edit, regression run, commit, push, PR, or reviewer response
was performed.

## Metadata

| Field | Value |
| --- | --- |
| Branch | `work-branch` |
| Local tip | `429a4fbce248d6d586669e022f63c1e27cb64f29` |
| Source ref | `origin/upstream_master` |
| Refreshed source tip | `bec4772f6a2527d371557b5d2032641e5ff7619c` |
| Actual upstream `master` | `bec4772f6a2527d371557b5d2032641e5ff7619c` |
| Fork point / merge base | `18ef86ecec723361362a332a79b4d913fd724d40` |
| Range | `HEAD..origin/upstream_master` |
| Prior refreshed analysis tip | `6c487e2f79dea747d70325250121e750ed364b2b` |
| Prior refreshed count | 312 |
| Refreshed count | 317 |
| Date range | 2026-06-11 to 2026-07-07 |
| Filtered count | 94 |
| Working tree | Dirty with Stage 35 docs and Developer memory; no open merge after abort. |

## Source-ref and abort verification

| Check | Command | Output |
| --- | --- | --- |
| Open-merge `HEAD` before abort | `git rev-parse HEAD` | `429a4fbce248d6d586669e022f63c1e27cb64f29` |
| Open-merge `MERGE_HEAD` before abort | `git rev-parse MERGE_HEAD` | `6c487e2f79dea747d70325250121e750ed364b2b` |
| Stale source ref before refresh | `git rev-parse origin/upstream_master` | `47e1de77aa0f06bf73cfd8c5281d95979f89fcbe` |
| Actual upstream before refresh | `git ls-remote https://github.com/ggml-org/llama.cpp.git refs/heads/master` | `bec4772f6a2527d371557b5d2032641e5ff7619c refs/heads/master` |
| Untracked abort-safety check | `git ls-files --others --exclude-standard` | Only `part-14-merge-rework-implementation-blocked-20260707.md` and `part-15-manager-source-ref-and-partial-merge-decision-20260707.md`. |
| Tracked-overlap check | `git ls-files --error-unmatch` on those two paths | Both paths were unknown to Git, so abort would not overwrite tracked files. |
| Abort command | `git merge --abort` | Exit `0`. |
| Merge state after abort | `git rev-parse --verify MERGE_HEAD` | `fatal: Needed a single revision` |
| Fetch command | `git fetch https://github.com/ggml-org/llama.cpp.git master:refs/remotes/origin/upstream_master` | Fast-forwarded `origin/upstream_master` from `47e1de77a` to `bec4772f6`; fetched tags `b9898`, `b9899`, `b9901`, `b9902`. |
| Refreshed source ref | `git rev-parse origin/upstream_master` | `bec4772f6a2527d371557b5d2032641e5ff7619c` |
| Refreshed source detail | `git log -1 --format="%H %ai %s" origin/upstream_master` | `bec4772f6a2527d371557b5d2032641e5ff7619c 2026-07-07 12:05:47 -0700 Add Q2_0 quantization: type definition and CPU backend (#24448)` |
| Actual upstream after fetch | `git ls-remote https://github.com/ggml-org/llama.cpp.git refs/heads/master` | `bec4772f6a2527d371557b5d2032641e5ff7619c refs/heads/master` |
| Remote config | `git remote -v` | `origin https://github.com/t-jet/llama.cpp-jet.git (fetch)`; `origin https://github.com/t-jet/llama.cpp-jet.git (push)` |

Staleness verdict: current. `origin/upstream_master` equals actual upstream
`master` after the direct-ref fetch.

## Verification checks

| Check | Command | Output |
| --- | --- | --- |
| Local tip detail | `git log -1 --format="%H %ai %s" HEAD` | `429a4fbce248d6d586669e022f63c1e27cb64f29 2026-07-07 17:11:01 +0300 docs: refresh Stage 35 premerge gate` |
| Merge base | `git merge-base HEAD origin/upstream_master` | `18ef86ecec723361362a332a79b4d913fd724d40` |
| Refreshed count | `git rev-list --count "HEAD..origin/upstream_master"` | `317` |
| Date first | `git log --reverse --format="%H %ai %s" "HEAD..origin/upstream_master"` first row | `1af154a76f505fdd15777a2486adfa6a75935417 2026-06-11 09:43:04 -0400 vulkan: use medium matmul tile on Asahi Linux (#24306)` |
| Date last | `git log --format="%H %ai %s" "HEAD..origin/upstream_master"` first row | `bec4772f6a2527d371557b5d2032641e5ff7619c 2026-07-07 12:05:47 -0700 Add Q2_0 quantization: type definition and CPU backend (#24448)` |

## Prefix proof

The part 11 refreshed range remains a prefix of the latest range.

| Check | Command | Output |
| --- | --- | --- |
| Prior tip is ancestor | `git merge-base --is-ancestor 6c487e2f79dea747d70325250121e750ed364b2b origin/upstream_master` | exit `0` |
| Prior count | `git rev-list --count "HEAD..6c487e2f79dea747d70325250121e750ed364b2b"` | `312` |
| Refreshed count | `git rev-list --count "HEAD..origin/upstream_master"` | `317` |
| Delta count | `git rev-list --count "6c487e2f79dea747d70325250121e750ed364b2b..origin/upstream_master"` | `5` |

Part 11 rows remain unchanged for the first 312 commits. This report adds only
the five new upstream commits after `6c487e2f79de`.

## Delta filter

| SHA | Subject | Files | Stage 35 result |
| --- | --- | --- | --- |
| `5eca4e3cabad` | `server : add timings and progress to /responses API stream (#25348)` | `tools/server/server-task.cpp`; `tools/server/server-task.h`; `tools/server/tests/unit/test_compat_oai_responses.py` | Included: server route/task streaming and public response telemetry. |
| `f5525f7e7a7e` | `server : fix draft model fit vs load inconsistency (#25056)` | `common/speculative.cpp`; `common/speculative.h`; `tools/server/server-context.cpp` | Included: speculative and MTP draft-context load/fit behavior. |
| `3899b39ce2ac` | `CUDA: Fuse MMVQ post-scale for NVFP4 (#24481)` | CUDA backend and backend-op test files | Excluded: backend kernel optimization, no Stage 35 cache or server contract. |
| `c198af4dc24f` | `spec : fix naming, spacing (#25410)` | `common/speculative.cpp`; `common/speculative.h`; `tools/server/server-context.cpp` | Included: follow-up rename for the speculative init path added by `f5525f7e7a7e`. |
| `bec4772f6a25` | `Add Q2_0 quantization: type definition and CPU backend (#24448)` | quantization, GGML CPU, model loader, and quantize tool files | Excluded: quantization support without draft, MTP, KV, checkpoint, slot-state, route, metric, or cache contract change. |

## New triage rows

| SHA | Subject | Groups | Contracts | Decision | Reason / owner |
| --- | --- | --- | --- | --- | --- |
| `5eca4e3cabad` | `/responses` stream timings and progress | Server context/task, HTTP routes and adapters, tests | Stage 13 route compatibility, Stage 31/32 public telemetry shape | INTEGRATE | Adds public streaming telemetry and a progress state field; integrate with focused scan that cache timing fields and bounded metric labels stay compatible. Developer. |
| `f5525f7e7a7e` | draft model fit vs load consistency | Speculative and MTP, server context and slot lifecycle | Stage 5 target/draft pairing, Stage 9 checkpoint draft state, Stage 34 MTP replay evidence | REWORK-REQUIRED | Moves draft/MTP initialization into common speculative helpers and changes draft context ownership; add to MTP/KV/speculative rework before merge. Architect/Manager. |
| `c198af4dc24f` | speculative init naming cleanup | Speculative and MTP, server context and slot lifecycle | Stage 5 target/draft pairing, Stage 9 checkpoint draft state, Stage 34 MTP replay evidence | REWORK-REQUIRED | Renames the speculative init helper introduced by `f5525f7e7a7e`; route with the same MTP/KV/speculative rework so implementation does not split the helper contract. Architect/Manager. |

No prior row changed decision.

## Aggregate summary

| Decision | Part 11 count | Delta | Refreshed count |
| --- | ---: | ---: | ---: |
| NO-OP | 13 | 0 | 13 |
| INTEGRATE | 68 | +1 | 69 |
| REWORK-REQUIRED | 10 | +2 | 12 |
| DEFER | 0 | 0 | 0 |
| REVERT | 0 | 0 | 0 |

Filtered commits: 94 of 317. Delta excluded commits: 2.

Rework routing:

- MTP/KV/speculative: add `f5525f7e7a7e` and `c198af4dc24f` to the existing
  track with `88a39274ecf8`, `d789527482d9`, `d1b34251bc57`,
  `8c146a836630`, and `024c46ae4e37`.
- Route/session lifecycle: unchanged from parts 11 to 13.
- Checkpoint placement: unchanged from parts 11 to 13.

Expected touched local files from the new filtered rows:

- `common/speculative.cpp`
- `common/speculative.h`
- `tools/server/server-context.cpp`
- `tools/server/server-task.cpp`
- `tools/server/server-task.h`
- `tools/server/tests/unit/test_compat_oai_responses.py`

## Manager decisions requested

- Confirm the refreshed aggregate count: 13 NO-OP, 69 INTEGRATE, 12
  REWORK-REQUIRED, 0 DEFER, 0 REVERT.
- Confirm `f5525f7e7a7e` and `c198af4dc24f` join the existing
  MTP/KV/speculative rework track instead of opening a separate speculative
  init rework.
- Confirm `5eca4e3cabad` stays INTEGRATE with focused route/task telemetry and
  cache timing scans.
- Confirm merge execution remains blocked until this refreshed analysis passes
  Architect review and Manager approval.

## Open questions

- Does moving draft/MTP initialization into `common/speculative.*` require a
  Stage 5 design update for ownership naming, or can the existing
  target/draft-pairing rework absorb it?
- Should `/responses` progress and timing stream fields add a Stage 13 route
  evidence row, or is focused Stage 35 integration evidence enough?

## Handoff

Next owner: Architect.

Next gate: refreshed pre-merge analysis review.

Merge execution, conflict resolution, regression runs, commits, pushes, PRs,
and reviewer responses remain blocked.
