# Stage 14 pre-merge report 01: pre-merge analysis (Step 1)

Source: [../cache-handling-phase14-implementation.md](../cache-handling-phase14-implementation.md)
Procedure: [../upstream-merge-guide.md](../upstream-merge-guide.md) Part 1 sections 1-3
Plan: [../cache-handling-phase14-implementation/part-04-prerequisites.md](../cache-handling-phase14-implementation/part-04-prerequisites.md)

## Status

Status: Step 1 complete; awaiting Step 2 Manager review, 2026-06-11
Step 1 triage verdict: PASS (94 commits triaged; 4 NO-OP, 16 INTEGRATE, 67 DEFER out-of-file-glob, 7 DEFER in-scope deferred, 0 REWORK-REQUIRED; 0 rework candidates; aggregate counts sum to 94)
Cycle: Stage 14 (post-Stage-12/13 upstream integration)
Step: 1 (pre-merge analysis, cycle first artifact)

## Cover and metadata

- Owner: Developer, Architect review pending
- Date: 2026-06-11
- Stage: 14
- Step: 1 (pre-merge analysis)
- Local default branch: `master`
- Current branch: `cache-optimization-caveman`
- Upstream reference: `origin/upstream_master` (Path C, no local
  tracking branch per Manager decision D4 resolved 2026-06-11)
- Upstream ref tip SHA: `18ef86ecec723361362a332a79b4d913fd724d40`
- Upstream ref tip subject and date: "server: skip unused log lines
  on router mode (#24463)" 2026-06-11 11:36:35 +0200
- Actual upstream `master` tip SHA: `18ef86ecec723361362a332a79b4d913fd724d40`
  (matches `origin/upstream_master`; D6 gap = 0)
- Fork point SHA: `6ddc9430b145f61a0c1733b9d79c99c0ebdedf50`
  (D7 recovered via `git merge-base master origin/upstream_master`)
- Commit count in range `master..origin/upstream_master`: 94
  (upstream ahead of local)
- Commit count in range `origin/upstream_master..master`: 36
  (local ahead of upstream)
- Diff shortstat `master..origin/upstream_master`:
  806 files changed, 10492 insertions(+), 96855 deletions(-)

## Baseline links

- Design baseline: [../cache-handling-phase14-design.md](../cache-handling-phase14-design.md)
  (entry; Path C corrected), parts 01 through 07, plus
  part-06a. Manager design gate PASS 2026-06-11.
- Plan baseline: [../cache-handling-phase14-implementation.md](../cache-handling-phase14-implementation.md)
  (entry), parts 01 through 04, plus
  part-05-architect-plan-review-gate-01.md (Architect plan review
  PASS 2026-06-11, 0 BLOCKING, 2 N, 4 INFO).
- Procedure baseline: [../upstream-merge-guide.md](../upstream-merge-guide.md)
  (entry; Path C corrected), parts 01 through 04.
- Architecture baseline: [../cache-handling-architecture.md](../cache-handling-architecture.md)
  (Stage 14 section in Part 5, Stage 14 endpoint test coverage in
  Part 8).
- Requirements baseline: [../cache-handling-requirements.md](../cache-handling-requirements.md)
  (referenced by the Stage 14 design for contract coverage).

## Upstream reference verification

Per plan part-04 "Upstream reference verification" and per the
D1 carry-forward decision, the upstream reference is the remote
tracking ref `origin/upstream_master`. The Developer operates
against `origin/upstream_master` directly. The Developer
verifies the remote ref tip is current against the actual
upstream `master` via `git ls-remote` before the merge opens.
The verification commands and outputs are below.

| # | Command | Output (2026-06-11) | Expected | Result |
| --- | --- | --- | --- | --- |
| 1 | `git rev-parse origin/upstream_master` | `18ef86ecec723361362a332a79b4d913fd724d40` | A 40-char SHA | PASS |
| 2 | `git log -1 --format='%H %ai %s' origin/upstream_master` | `18ef86ecec723361362a332a79b4d913fd724d40 2026-06-11 11:36:35 +0200 server: skip unused log lines on router mode (#24463)` | Subject and date of remote ref tip | PASS |
| 3 | `git remote -v` | `origin  https://github.com/t-jet/llama.cpp-jet.git (fetch) / (push)` | `https://github.com/t-jet/llama.cpp-jet.git` | PASS |
| 4 | `git ls-remote https://github.com/ggml-org/llama.cpp.git master` | `18ef86ecec723361362a332a79b4d913fd724d40        refs/heads/master` | Actual upstream `master` tip SHA | PASS |
| 5 | `git rev-parse --abbrev-ref HEAD` | `cache-optimization-caveman` | Current branch name | PASS (working branch, not the local default branch) |
| 6 | `git symbolic-ref refs/remotes/origin/HEAD` | `refs/remotes/origin/master` | Canonical default branch | PASS (local default branch is `master`) |
| 7 | `git merge-base master origin/upstream_master` | `6ddc9430b145f61a0c1733b9d79c99c0ebdedf50` | A 40-char SHA (fork point) | PASS (D7 recovered) |
| 8 | `git log --oneline master..origin/upstream_master` followed by `wc -l` | `94` | Upstream commit count | PASS (94 commits ahead of local) |
| 9 | `git log --oneline origin/upstream_master..master` followed by `wc -l` | `36` | Local commit count | PASS (36 commits ahead of upstream) |
| 10 | `git log --oneline origin/upstream_master -20` | See "Commit range" section below | Subjects and SHAs for 20 most recent upstream commits | PASS |
| 11 | `git log --oneline master -5` | See "Local default branch tip" section below | Subjects and SHAs for 5 most recent local commits | PASS |
| 12 | `git diff --shortstat master origin/upstream_master` | `806 files changed, 10492 insertions(+), 96855 deletions(-)` | Rough file count delta | PASS (large delta; Step 2 triage reviews per-commit) |

### Network reachability for `git ls-remote`

The Developer successfully reached
`https://github.com/ggml-org/llama.cpp.git` for the `git
ls-remote` query. The actual upstream `master` tip SHA
`18ef86ecec723361362a332a79b4d913fd724d40` is identical to
`origin/upstream_master` tip. D6 gap = 0 commits.

### Local default branch tip

The local default branch is `master` (per `git symbolic-ref
refs/remotes/origin/HEAD`). The 5 most recent local commits
on `master` are:

- `02db7a768 (origin/master, origin/cache-optimization, origin/HEAD, master, cache-optimization) Merge branch 'cache-optimization'`
- `3c5ddd962 Merge branch 'cache-optimization-stage11-merge' into cache-optimization`
- `5fa2320bf (cache-optimization-stage11-merge) update agents memory and add stage 11 test report`
- `a7cb0d0d3 Stage 11: Manager re-closure PASS (2026-06-05)`
- `dc929d629 Stage 11: durable doc sweep for real-merge rework loop (2026-06-05)`

The most recent local commit is a merge of `cache-optimization`
into `master`. The most recent non-merge local commit is
`5fa2320bf` (stage 11 test report and memory update).

### Working tree state at Step 1 open

Per plan part-04 prerequisite "Local default branch checked out
at a clean tree at cycle open", the working tree must be clean
at cycle open. At Step 1 open the working tree was dirty with
uncommitted changes listed in D5. D5 was resolved via the D5
commit `25d6a2a467da8a67953c45787eb89376c3e565cd` (see D5
record below). After the D5 commit `git status --short` is
empty (clean tree). The working tree is now clean.

## D5 record: worktree dirty at cycle open (RESOLVED 2026-06-11)

D5 was open at Step 1 open. The Developer committed the
working tree state with a single D5 commit per the Manager
record in the entry doc Manager decisions log. The D5 commit
bundles:

- Stage 14 design entry plus 8 parts (path
  `._design_docs/cache-handling-phase14-design.md` and
  `._design_docs/cache-handling-phase14-design/part-01...md`
  through `part-07...md` and `part-06a...md`).
- Stage 14 implementation entry plus 5 parts (path
  `._design_docs/cache-handling-phase14-implementation.md` and
  `._design_docs/cache-handling-phase14-implementation/part-01...md`
  through `part-05...md`).
- 3 self-improvement memory updates
  (`.agents/skills/self-improvement/assets/{architect,developer,manager}.md`).
- `document-index.md` Stage 14 row.
- Modifications to `cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md`
  and `upstream-merge-guide.md` plus 3 parts
  (`part-01-procedure.md`, `part-03-coverage-and-evidence.md`,
  `part-04-edge-cases.md`).
- Implementation log entry doc status line update (line 3) from
  `Status: Implementation planning IN PROGRESS` to
  `Status: Implementation-plan gate PASS, 2026-06-11; Step 1
  pre-merge analysis IN PROGRESS`.

D5 commit metadata:

| Field | Value |
| --- | --- |
| Commit SHA | `25d6a2a467da8a67953c45787eb89376c3e565cd` |
| Short SHA | `25d6a2a46` |
| Date (author) | 2026-06-11 14:30:25 +0300 |
| Subject | `Stage 14 design + impl plan: Path C direct-ref upstream integration` |
| Files changed | 24 (15 created, 9 modified) |
| Insertions | 3181 |
| Deletions | 289 |
| Parent | `31d60a94481851035d21542c511baf75d177f0f2` (Stage 13 complete) |
| Branch | `cache-optimization-caveman` |
| Tree state after commit | clean (`git status --short` returns empty) |

The part-05 architecture whitespace noise (CRLF / trailing
whitespace on the design part-05 file) is included in the
D5 commit bundle per the Manager decision; per-line
whitespace scan was deferred to the Step 1 plan
documentary trail. Path C decision date recorded in the
commit body: 2026-06-11.

## D6 record: `origin` remote URL is the local jet fork (RESOLVED 2026-06-11, gap = 0)

D6 was open at Step 1 open. The Developer ran `git ls-remote
https://github.com/ggml-org/llama.cpp.git master` and compared
the result to the `origin/upstream_master` tip.

| Field | Value |
| --- | --- |
| `origin` URL | `https://github.com/t-jet/llama.cpp-jet.git` (the local jet fork) |
| `origin/upstream_master` tip SHA | `18ef86ecec723361362a332a79b4d913fd724d40` |
| `origin/upstream_master` tip subject | `server: skip unused log lines on router mode (#24463)` |
| `origin/upstream_master` tip date | 2026-06-11 11:36:35 +0200 |
| Actual upstream `master` tip SHA (`git ls-remote`) | `18ef86ecec723361362a332a79b4d913fd724d40` |
| D6 gap (commits) | 0 (ref tip matches upstream tip exactly) |
| Network reachability | PASS (HTTPS GET to `github.com/ggml-org/llama.cpp.git` succeeded) |

D6 is RESOLVED with gap = 0 on 2026-06-11. The
`origin/upstream_master` ref was refreshed since the D1
record (last fetched 2026-06-04 per the original D1). The
D1 record's expected SHA
`db94854ff56549f62b84d2f31608259a9e5e0e9f` is a stale
snapshot; the current ref tip is
`18ef86ecec723361362a332a79b4d913fd724d40`. The Developer
surfaces this as informational in the merge log "Known
gaps" section per D1.

## D7 record: fork point SHA is unknown until Step 1 (RESOLVED 2026-06-11)

D7 was open at Step 1 open. The Developer recovered the fork
point via `git merge-base master origin/upstream_master`.

| Field | Value |
| --- | --- |
| Local default branch | `master` |
| Upstream ref | `origin/upstream_master` |
| Fork point SHA | `6ddc9430b145f61a0c1733b9d79c99c0ebdedf50` |
| Method | `git merge-base master origin/upstream_master` |
| Recovery status | PASS (D7 recovered on 2026-06-11) |

D7 is RESOLVED 2026-06-11. The Manager approves the fork
point SHA. A change to the fork point after the pre-merge
analysis closes reopens the pre-merge analysis per design
Part 6.

## Manager decisions requested

D6 and D7 are recorded above and are RESOLVED on 2026-06-11
with the Developer-recorded evidence. The Manager records
the final approval in this report's Manager decisions log
during the Architect pre-merge report review.

| Decision | Recommended default | Developer evidence | Status (2026-06-11) |
| --- | --- | --- | --- |
| D5 (worktree dirty at cycle open) | Commit working tree state with a single D5 commit before opening pre-merge analysis | D5 commit `25d6a2a467da8a67953c45787eb89376c3e565cd`, clean tree after commit | RESOLVED (Developer recorded; Manager to confirm in review) |
| D6 (`origin` URL is local jet fork) | Use `origin/upstream_master` as upstream reference per Path C; record gap in pre-merge report | `git ls-remote` output matches `origin/upstream_master` tip; D6 gap = 0 | RESOLVED with gap = 0 (Developer recorded; Manager to confirm in review) |
| D7 (fork point SHA unknown until Step 1) | Fork point is the merge base of the local default branch and `origin/upstream_master` | `git merge-base` output `6ddc9430b145f61a0c1733b9d79c99c0ebdedf50` | RESOLVED (Developer recorded; Manager to confirm in review) |

### Newly surfaced open decision

D12 (NEW, 2026-06-11): the `origin/upstream_master` ref tip
on 2026-06-11 (`18ef86ecec723361362a332a79b4d913fd724d40`)
does not match the D1 carry-forward's expected SHA
(`db94854ff56549f62b84d2f31608259a9e5e0e9f`, last fetched
2026-06-04). The ref was refreshed between the D1 record
date (2026-06-04) and the Step 1 open (2026-06-11). The
gap to the actual upstream `master` is 0 (D6 resolved),
so the D1 reference SHA is informational only. The
Developer surfaces D12 as an open Manager decision: the
plan part-01 "Commit range rule" and plan part-04
"Verification commands" table cite the D1 SHA as
expected; both docs are kept verbatim per plan part-04
Path C rules. The Manager decides whether to update the
D1 reference SHA in plan part-01 and plan part-04
verification table to the current ref tip
`18ef86ecec723361362a332a79b4d913fd724d40` as a doc
correction, or to leave the D1 SHA as the historical
anchor and add a "refreshed on 2026-06-11" annotation
in plan part-04.

Recommended default: leave the D1 SHA as the historical
anchor and add a "refreshed on 2026-06-11, current tip
18ef86ece" annotation in plan part-04. The Manager records
the chosen path with a one-line rationale.

## Commit range

Per plan part-03 "Pre-merge analysis commit range rule" and
per the cover metadata, the full commit range is 94 commits
(`master..origin/upstream_master`). The 20 most recent
upstream commits (raw output of
`git log --oneline origin/upstream_master -20`) are:

```text
18ef86ece server: skip unused log lines on router mode (#24463)
1bfbdb134 vocab : adopt leading TemplateProcessing special token as BOS (#24428)
68f30663c vocab : refactor normalizer flags into options struct, add strip_accents (#24371)
db94854ff server : skip checkpoints beyond pos_next (#24411)
ac4cddeb0 vendor : update LibreSSL to 4.3.2 (#24397)
e95dae18d Remove padding and multiple D2D copies for MTP (#24086)
d2462f8f7 chat: fix LFM2/LFM2.5 ignoring json_schema (#24377)
fb83cc9a0 CUDA: Fix ssm_scan_f32 data-races (#24360)
039e20a2d ci : bump komac version (#24396)
d2e22ed97 speculative : fix "ngram-map-k4v" name in logging (#24253)
76da2450a webui: implement pinned conversations support (#21387)
d73cd0767 graph: Fix granite speech model inference by applying embedding scale when deepstack is not used (#24357)
e25a32e98 ci : fix windows release (#24369)
483609509 ui: add opt-in run_javascript frontend tool (#24244)
49f354219 mtmd: build_vit batching (#24352)
d6d0ce821 vulkan: reduce iq1 shared memory usage for mul_mm (#24287)
b4e3dc613 vulkan: add `v_dot2_f32_f16` support in matrix-matrix multiplication and Flash Attention (#24123)
ae735b131 ui: Fix excessive style recalculation on hover (#24243)
9682e351b mtmd: refactor video subproc handling (#24316)
1e912561d server: log prompts to directory (#22031)
```

The full commit range (94 entries) is recorded in the
companion artifact
`tmp/upstream-commit-list-20260611-01.txt` at the repo root
and is referenced by the Step 2 triage part file when
opened. The full commit range is one input to the Step 2
triage (the other inputs are the file-glob groups from
design Part 2 and the per-commit filter rules from plan
part-03).

### Range composition (TRIAGE-INFO-ONLY, INFORMATIONAL)

This section is informational and pre-sorts commits by likely triage outcome. The authoritative triage is in the Triage table section. Do not act on the pre-sort without checking the Triage table.

The 20 most recent upstream commits above include a mix of
runtime-path commits and non-runtime-path commits. Step 2
triage will filter per plan part-03 rules. The Developer's
informational pre-step-2 read of the 20-commit set:

- Runtime paths (likely in-scope):
  `db94854ff` server checkpoint guard,
  `e95dae18d` MTP D2D cleanup,
  `d2462f8f7` chat json_schema fix,
  `fb83cc9a0` CUDA ssm_scan race,
  `49f354219` mtmd build_vit batching,
  `d6d0ce821` and `b4e3dc613` vulkan mul_mm work,
  `d73cd0767` granite speech embedding scale,
  `9682e351b` mtmd video subproc refactor,
  `7d2b45b4f` mtp gemma-4 (the actual gemma-4 commit
  appears in the lower part of the range, not in the
  top-20), `6f3a9f3de` server checkpoint restore guard.
- Build / CI / vendor: `ac4cddeb0` LibreSSL bump,
  `039e20a2d` komac bump, `e25a32e98` windows release
  fix, `3ac3c20c9` webgpu clang-format job. Per plan
  part-03 rule 3 these are EXCLUDED unless they touch a
  runtime path any prior-stage contract governs.
- Documentation / webui: `76da2450a` webui pinned
  conversations, `483609509` webui run_javascript tool,
  `ae735b131` webui style recalc, `efbacf8d2` webui
  mobile chat form. Per plan part-03 rule 3 EXCLUDED
  unless they touch a runtime path.
- Server logging: `18ef86ece` server router mode log
  skip, `1e912561d` server log prompts to directory. Per
  plan part-03 rule 1 these are in the natural range;
  rule 3 review needed for whether the bounded
  diagnostic field set or the public metric set is
  affected.

The Step 2 triage part file is the authoritative source
for per-commit NO-OP / INTEGRATE / DEFER / REWORK-REQUIRED
classification. The Step 1 pre-merge report records the
range, the open decisions, and the upstream reference
verification only.

## Triage table (Step 1 complete)

Per plan part-03, the per-commit triage
(NO-OP / INTEGRATE / DEFER / REWORK-REQUIRED) is the Step 1
deliverable. The Developer assigned the triage for all 94
commits in the `master..origin/upstream_master` range using
the file-glob groups from design Part 2. The table below is
the full per-commit triage. Each row names the prior-stage
contract the upstream commit leaves untouched, modifies, or
breaks. The aggregate summary follows the table.
| # | SHA | Subject | Files | File-glob | Triage | Reason | Contract |
|---|---|---|---|---|---|---|---|
| 1 | 18ef86ecec | server: skip unused log lines on router mode (#24463) | tools/server/server.cpp | none | DEFER | out-of-file-glob | n/a |
| 2 | 1bfbdb134e | vocab : adopt leading TemplateProcessing special token as... | gguf-py/gguf/vocab.py | none | DEFER | out-of-file-glob | n/a |
| 3 | 68f30663cf | vocab : refactor normalizer flags into options struct, ad... | gguf-py/gguf/constants.py + 6 other | none | DEFER | out-of-file-glob | n/a |
| 4 | db94854ff5 | server : skip checkpoints beyond pos_next (#24411) | tools/server/server-context.cpp | server_context | INTEGRATE | Checkpoint admission guard in server-context.cpp; prevents checkpoint writes past pos_next; preserves Stage 9 / T121 public checkpoint admission contract | Stage 9 / T121 (Stage 9, Stage 10 impl Part 9) |
| 5 | ac4cddeb0d | vendor : update LibreSSL to 4.3.2 (#24397) | vendor/cpp-httplib/CMakeLists.txt | none | DEFER | out-of-file-glob | n/a |
| 6 | e95dae18d6 | Remove padding and multiple D2D copies for MTP (#24086) | ggml/include/ggml.h + 19 other | ggml_cuda | DEFER | MTP D2D perf optimization touching ggml-cuda and model layer; design Part 2 CUDA group rule "only when commit also changes a path a prior-stage contract governs" not met | Design Part 2 CUDA group rule |
| 7 | d2462f8f7a | chat: fix LFM2/LFM2.5 ignoring json_schema (#24377) | common/chat.cpp | none | DEFER | out-of-file-glob | n/a |
| 8 | fb83cc9a07 | CUDA: Fix ssm_scan_f32 data-races (#24360) | ggml/src/ggml-cuda/ssm-scan.cu | ggml_cuda | DEFER | CUDA ssm_scan data-race fix; design Part 2 CUDA group rule "only when commit also changes a path a prior-stage contract governs" not met | Design Part 2 CUDA group rule |
| 9 | 039e20a2db | ci : bump komac version (#24396) | .github/workflows/winget.yml | none | DEFER | out-of-file-glob | n/a |
| 10 | d2e22ed975 | speculative : fix "ngram-map-k4v" name in logging (#24253) | common/speculative.cpp | speculative | NO-OP | Log token rename in speculative path; behavior preserved; Stage 5 / Stage 13 namespace contracts unaffected | Stage 5 / Stage 13 compatibility namespace key (Stage 5) |
| 11 | 76da2450a4 | webui: implement pinned conversations support (#21387) | tools/ui/src/lib/components/app/navigation/SidebarNavigation/SidebarNavigation.svelte + 4 other | none | DEFER | out-of-file-glob | n/a |
| 12 | d73cd07674 | graph: Fix granite speech model inference by applying emb... | src/llama-graph.cpp, tools/mtmd/tests.sh | mtmd_path | INTEGRATE | Granite speech embedding scale fix in llama-graph.cpp; mtmd tests.sh is test; preserves Stage 13 MTMD placeholder path contract | Stage 13 MTMD placeholder path (Stage 13 impl) |
| 13 | e25a32e98c | ci : fix windows release (#24369) | .github/workflows/release.yml | none | DEFER | out-of-file-glob | n/a |
| 14 | 483609509d | ui: add opt-in run_javascript frontend tool (#24244) | tools/ui/eslint.config.js + 14 other | none | DEFER | out-of-file-glob | n/a |
| 15 | 49f3542190 | mtmd: build_vit batching (#24352) | tools/mtmd/clip.cpp | mtmd_path | INTEGRATE | mtmd build_vit batching perf; preserves Stage 13 MTMD placeholder path contract | Stage 13 MTMD placeholder path (Stage 13 impl) |
| 16 | d6d0ce8215 | vulkan: reduce iq1 shared memory usage for mul_mm (#24287) | ggml/src/ggml-vulkan/ggml-vulkan.cpp, ggml/src/ggml-vulkan/vulkan-shaders/mul_mat_vecq.comp, ggml/src/ggml-vulkan/vulkan-shaders/types.glsl | none | DEFER | out-of-file-glob | n/a |
| 17 | b4e3dc613b | vulkan: add `v_dot2_f32_f16` support in matrix-matrix mul... | ggml/src/ggml-vulkan/ggml-vulkan.cpp + 4 other | none | DEFER | out-of-file-glob | n/a |
| 18 | ae735b1314 | ui: Fix excessive style recalculation on hover (#24243) | tools/ui/src/app.css | none | DEFER | out-of-file-glob | n/a |
| 19 | 9682e351b8 | mtmd: refactor video subproc handling (#24316) | tools/mtmd/mtmd-helper.cpp | mtmd_path | INTEGRATE | mtmd video subproc refactor; preserves Stage 13 MTMD placeholder path contract | Stage 13 MTMD placeholder path (Stage 13 impl) |
| 20 | 1e912561dd | server: log prompts to directory (#22031) | common/arg.cpp, common/common.h, tools/server/server-context.cpp | server_context,common_arg,common_common | INTEGRATE | Server prompts-to-directory logging feature; new log path is separate from bounded cache metadata line; preserves Stage 10 / Stage 13 bounded diagnostics and OWASP mitigations | Stage 10 / Stage 13 bounded diagnostics, OWASP mitigations (Stage 10) |
| 21 | efbacf8d21 | ui: fix mobile chat form overflow and bust stale bundle c... | tools/ui/scripts/vite-plugin-llama-cpp-build.ts, tools/ui/src/routes/+layout.svelte | none | DEFER | out-of-file-glob | n/a |
| 22 | 26021699bc | ggml : add GGML_OP_COL2IM_1D (#24206) | ggml/include/ggml-rpc.h + 8 other | none | DEFER | out-of-file-glob | n/a |
| 23 | 961e9a3e46 | server : do not clear slots without unified KV cache (#24... | common/arg.cpp, tools/server/README.md, tools/server/server-context.cpp | server_context,common_arg | INTEGRATE | Slot clearing guard in server-context.cpp; defensive against clearing when unified KV cache absent; preserves Stage 7 slot references and E13-01..E13-16 endpoint parity | Stage 7 slot references, E13-01..E13-16 (Stage 7, Stage 13) |
| 24 | f0152efe40 | models : fix plamo2 attention_key/value_length regression... | src/models/plamo2.cpp | none | DEFER | out-of-file-glob | n/a |
| 25 | fd3271e0b4 | ggml-cpu : fix rms_norm_back wrong output under in-place ... | ggml/src/ggml-cpu/ops.cpp | none | DEFER | out-of-file-glob | n/a |
| 26 | e3471b3e73 | Remove case for GGML_TYPE_Q4_K in mvvq.cu (#23528) | ggml/src/ggml-cuda/mmvq.cu | ggml_cuda | DEFER | CUDA MMVQ GGML_TYPE_Q4_K removal; design Part 2 CUDA group rule "only when commit also changes a path a prior-stage contract governs" not met | Design Part 2 CUDA group rule |
| 27 | 3ac3c20c96 | ggml-webgpu: Add clang-format job (#24308) | .github/workflows/build-webgpu.yml, ggml/src/ggml-webgpu/ggml-webgpu-shader-lib.hpp, ggml/src/ggml-webgpu/ggml-webgpu.cpp | none | DEFER | out-of-file-glob | n/a |
| 28 | 1e1aca09da | ggml-webgpu: Improve prefill speeds for k-quants + refact... | ggml/src/ggml-webgpu/wgsl-shaders/mul_mat_decls.tmpl | none | DEFER | out-of-file-glob | n/a |
| 29 | 7d2b45b4f7 | mtp: support for gemma-4 E2B and E4B assistants (#24282) | conversion/gemma.py + 5 other | none | DEFER | out-of-file-glob | n/a |
| 30 | 42a0afd594 | server : do not parse when flushing http headers (#24281) | tools/server/server-task.cpp | server_task | INTEGRATE | HTTP header parse guard in server-task.cpp; skips JSON parse while flushing headers; preserves HTTP layer / route contract | HTTP layer (Architecture, Stage 10 metrics) |
| 31 | a66d50588b | graph: guard iswa kq_mask on its own buffer (#24294) | src/llama-graph.cpp | none | DEFER | out-of-file-glob | n/a |
| 32 | 1705d434f6 | [ggml-webgpu] Handle buffer overlap / buffer aliasing for... | ggml/src/ggml-webgpu/ggml-webgpu-shader-lib.hpp, ggml/src/ggml-webgpu/ggml-webgpu.cpp, ggml/src/ggml-webgpu/wgsl-shaders/concat.wgsl | none | DEFER | out-of-file-glob | n/a |
| 33 | 3b3da01dc2 | [ggml-webgpu] Implement 2D workgroups for scale, binary, ... | ggml/src/ggml-webgpu/ggml-webgpu.cpp + 3 other | none | DEFER | out-of-file-glob | n/a |
| 34 | 3ebe862b5d | docker: install ffmpeg in the released image (#24302) | .devops/cpu.Dockerfile + 7 other | none | DEFER | out-of-file-glob | n/a |
| 35 | 8f83d6c271 | mtmd : add video input support (#24269) | common/arg.cpp + 15 other | server_context,server_common,mtmd_path,common_arg,common_common | INTEGRATE | mtmd video input support new feature; preserves Stage 13 MTMD placeholder path contract | Stage 13 MTMD placeholder path (Stage 13 impl) |
| 36 | c2b1518fd4 | sync : ggml | scripts/sync-ggml.last | none | DEFER | out-of-file-glob | n/a |
| 37 | 6a1de6fbf1 | ggml : bump version to 0.14.0 (ggml/1533) | ggml/CMakeLists.txt | none | DEFER | out-of-file-glob | n/a |
| 38 | 715b86a366 | cli: fix spinner not show during prompt processing (#24283) | tools/cli/cli.cpp | none | DEFER | out-of-file-glob | n/a |
| 39 | c74759a244 | vulkan: Use cm2 decode_vector for mul_mat_id B matrix loa... | ggml/src/ggml-vulkan/ggml-vulkan.cpp + 3 other | none | DEFER | out-of-file-glob | n/a |
| 40 | 0f7fada56b | cuda: reset cuda context after reading memory size (#23935) | ggml/src/ggml-cuda/ggml-cuda.cu | ggml_cuda | DEFER | CUDA context reset after memory size read; design Part 2 CUDA group rule "only when commit also changes a path a prior-stage contract governs" not met | Design Part 2 CUDA group rule |
| 41 | 19bba67c1f | HIP: add gfx1152 and gfx1153 to RDNA3.5 (#24129) | ggml/src/ggml-cuda/vendors/hip.h | ggml_cuda | DEFER | HIP RDNA3.5 GPU target add; design Part 2 CUDA group rule "only when commit also changes a path a prior-stage contract governs" not met | Design Part 2 CUDA group rule |
| 42 | daf6bc9f2d | metal : fix im2col 1D case (audio models) (#24220) | ggml/src/ggml-metal/ggml-metal-device.cpp, tests/test-backend-ops.cpp | none | DEFER | out-of-file-glob | n/a |
| 43 | d403f00ec3 | [SYCL] Update compute runtime version to 26.x in docker (... | .devops/intel.Dockerfile | none | DEFER | out-of-file-glob | n/a |
| 44 | 9e3b928fd8 | common : relax sampler name matching (#23744) | common/arg.cpp + 4 other | server_task,common_arg,common_common,common_sampling | INTEGRATE | Sampler name matching relaxation; sampler is downstream of cache layer; cache namespace key (Stage 5) unaffected | Stage 5 compatibility namespace key (Stage 5) |
| 45 | 8a963fc10e | convert : fix conversion for Mistral-Medium-3.5-128B (#24... | conversion/mistral.py, convert_hf_to_gguf.py | none | DEFER | out-of-file-glob | n/a |
| 46 | 379ac6673b | kv-cache : avoid kv cells copies (#24277) | src/llama-kv-cache.cpp, src/llama-kv-cache.h, src/llama-kv-cells.h | none | DEFER | out-of-file-glob | n/a |
| 47 | f0156d1401 | kv-cache: follow the source cache size when sharing cells... | src/llama-kv-cache.cpp | none | DEFER | out-of-file-glob | n/a |
| 48 | 04eb4c446d | llama : add Gemma4 MTP (#23398) | common/speculative.cpp + 30 other | speculative,server_context | DEFER | Gemma4 MTP touches llama-memory-hybrid* (hybrid memory layer); ambiguous: potential Stage 12 H53/H54 MTP rerun and T114/T114a coverage denominator impact; needs Architect review | Stage 12 H53/H54 MTP rerun, T114/T114a coverage floor (Stage 12, test plan Part 12-13) |
| 49 | 8a091c47ab | spec : fix vocab compatibility check (#24256) | common/speculative.cpp | speculative | INTEGRATE | Speculative vocab compatibility fix; speculative namespace key (Stage 5) still includes draft model identity | Stage 5 compatibility namespace key (Stage 5) |
| 50 | 465b1f0e75 | arg: Skip mmproj download when user supplied mmproj (#24239) | common/arg.cpp | common_arg | NO-OP | CLI flag skip when user supplies mmproj; no runtime contract affected | Architecture CLI flag (Stage 1) |
| 51 | f71af352a5 | convert : fix Gemma4 with no audio encoder (#24242) | conversion/gemma.py | none | DEFER | out-of-file-glob | n/a |
| 52 | 3f7c79d7b5 | docker : bump cuda13 to 13.3.0 (#24228) | .github/workflows/docker.yml | none | DEFER | out-of-file-glob | n/a |
| 53 | 98d5e8ba8a | common/chat : fix LFM2/LFM2.5 reasoning round-trip and <t... | common/chat.cpp, models/templates/LFM2.5-8B-A1B.jinja, tests/test-chat.cpp | none | DEFER | out-of-file-glob | n/a |
| 54 | 31e82494c0 | mtmd: support "frame merge" for qwen-vl-based models (#21... | tools/mtmd/clip-graph.h + 9 other | mtmd_path | INTEGRATE | mtmd frame merge support; preserves Stage 13 MTMD placeholder path contract | Stage 13 MTMD placeholder path (Stage 13 impl) |
| 55 | 6b80c74f28 | completion : remove useless statics (#24226) | tools/completion/completion.cpp | none | DEFER | out-of-file-glob | n/a |
| 56 | 588f0dc2ce | completion : fix format specifier in LOG_INF (#24213) | tools/completion/completion.cpp | none | DEFER | out-of-file-glob | n/a |
| 57 | f5c6ae1827 | mtmd, server: add "placeholder bitmap" for counting token... | tools/mtmd/clip-impl.h + 25 other | server_context,server_common,mtmd_path | INTEGRATE | mtmd placeholder bitmap and input_tokens API; additive new API; preserves Stage 13 MTMD placeholder path contract | Stage 13 MTMD placeholder path (Stage 13 impl) |
| 58 | 5a69c97439 | vulkan: check coopmat2 features before reporting support ... | ggml/src/ggml-vulkan/ggml-vulkan.cpp | none | DEFER | out-of-file-glob | n/a |
| 59 | 5343f4502a | model : rename local n_layer_all variable (#24209) | src/llama-model.cpp | none | DEFER | out-of-file-glob | n/a |
| 60 | 603300b008 | context : fix off-by-one comparisons to n_gpu_layers (#24... | src/llama-context.cpp | none | DEFER | out-of-file-glob | n/a |
| 61 | 308f61c31f | opencl: improve get_rows, cpy, concat and q6_k flat gemv ... | ggml/src/ggml-opencl/ggml-opencl.cpp + 4 other | none | DEFER | out-of-file-glob | n/a |
| 62 | da87e9b612 | common/chat : unify and fix LFM2/LFM2.5 tool parser (#24178) | common/chat-peg-parser.cpp + 3 other | none | DEFER | out-of-file-glob | n/a |
| 63 | e82beaa60d | vulkan: add fwht support for Intel with shmem reduction (... | ggml/src/ggml-vulkan/ggml-vulkan.cpp, ggml/src/ggml-vulkan/vulkan-shaders/fwht.comp, ggml/src/ggml-vulkan/vulkan-shaders/vulkan-shaders-gen.cpp | none | DEFER | out-of-file-glob | n/a |
| 64 | c4a278d68e | model: fix build failed (#24193) | src/llama-model.cpp | none | DEFER | out-of-file-glob | n/a |
| 65 | 64086f2b2f | model, mtmd: Granite4 Vision (#23545) | conversion/__init__.py + 23 other | mtmd_path | INTEGRATE | Granite4 Vision new model support; preserves Stage 13 MTMD placeholder path contract | Stage 13 MTMD placeholder path (Stage 13 impl) |
| 66 | 6effcecd0b | TP: round up granularity to 128 (#24180) | src/llama-model.cpp | none | DEFER | out-of-file-glob | n/a |
| 67 | 86591c7536 | cli: fix model params not propagated (#23893) | tools/cli/cli.cpp | none | DEFER | out-of-file-glob | n/a |
| 68 | 96fbe00393 | model : fix llama_model::n_gpu_layers() (#24188) | src/llama-model.cpp | none | DEFER | out-of-file-glob | n/a |
| 69 | 2016bf2b3b | ui: run npm install when package-lock.json is newer than ... | scripts/ui-assets.cmake | none | DEFER | out-of-file-glob | n/a |
| 70 | 9c955c48b0 | Fix link to available UI settings (#24169) | tools/server/README.md | none | DEFER | out-of-file-glob | n/a |
| 71 | cc7bef34e2 | ui: add ignore-scripts=true to npmrc (#24149) | tools/ui/.npmrc | none | DEFER | out-of-file-glob | n/a |
| 72 | ad1b88ca0d | docs: Update quantization readme (#24133) | tools/quantize/README.md | none | DEFER | out-of-file-glob | n/a |
| 73 | 59917d3922 | minor : fix lint issues (#24165) | src/models/exaone-moe.cpp, src/models/glm4-moe.cpp | none | DEFER | out-of-file-glob | n/a |
| 74 | 7acb4e8cd2 | hparams : refactor `hparams.n_layer` (#24060) | .pi/gg/SYSTEM.md + 128 other | none | DEFER | out-of-file-glob | n/a |
| 75 | 3ecfb150a4 | kleidiai : dynamic chunck-based scheduling for hybrid exe... | ggml/src/ggml-cpu/kleidiai/kleidiai.cpp | none | DEFER | out-of-file-glob | n/a |
| 76 | 2154a0fdcf | CUDA: enroll mul_mat_vec_q_moe into pdl (#24087) | ggml/src/ggml-cuda/mmvq.cu | ggml_cuda | DEFER | CUDA mul_mat_vec_q_moe pdl enrollment; design Part 2 CUDA group rule "only when commit also changes a path a prior-stage contract governs" not met | Design Part 2 CUDA group rule |
| 77 | 46fa662b1f | ci : build-msys job slimming [no ci] (#24157) | .github/workflows/build-msys.yml | none | DEFER | out-of-file-glob | n/a |
| 78 | 7fe2ae45ab | sycl : port multi-column MMVQ from CUDA backend (#21845) | ggml/src/ggml-sycl/ggml-sycl.cpp, ggml/src/ggml-sycl/mmvq.cpp | none | DEFER | out-of-file-glob | n/a |
| 79 | 7c158fbb4a | server : disable on-device spec checkpoints (#24108) | examples/speculative-simple/speculative-simple.cpp, tools/server/server-context.cpp | server_context | INTEGRATE | Server disables on-device spec checkpoints; separate path from T121 public cache_checkpoint_* rows; T121 /metrics contract preserved | T121 public /metrics row (Stage 10 impl Part 9) |
| 80 | 260862b8ca | arg: fix double mtp downloads (#24128) | common/arg.cpp | common_arg | NO-OP | CLI dedup of mtp downloads; no runtime contract affected | Architecture CLI flag (Stage 1) |
| 81 | 42b2d60e57 | webui: [a11y] fix keyboard navigation issues in chat inte... | tools/ui/src/lib/components/app/actions/ActionIcon.svelte + 16 other | none | DEFER | out-of-file-glob | n/a |
| 82 | e7bcf1c3a8 | Move duplicated imatrix code into single common imatrix-l... | common/CMakeLists.txt + 4 other | none | DEFER | out-of-file-glob | n/a |
| 83 | 21444c822e | ui: Fixed packages (#24119) | tools/ui/package-lock.json + 3 other | none | DEFER | out-of-file-glob | n/a |
| 84 | 526977068f | ui: added single line reasoning preview (#23601) | tools/ui/src/lib/components/app/chat/ChatMessages/ChatMessageAgenticContent.svelte + 6 other | none | DEFER | out-of-file-glob | n/a |
| 85 | 0dbfa66a1f | return filter to save memory (#24125) | src/llama-model.cpp | none | DEFER | out-of-file-glob | n/a |
| 86 | e8023568d0 | convert: Fix Gemma 4 Unified conversion (#24118) | conversion/gemma.py | none | DEFER | out-of-file-glob | n/a |
| 87 | 4c51309617 | ggml: vectorize ggml_vec_dot_q4_1_q8_1 with WASM SIMD128 ... | ggml/src/ggml-cpu/arch/wasm/quants.c | none | DEFER | out-of-file-glob | n/a |
| 88 | 6f3a9f3dee | server: avoid unnecessary checkpoint restore when new tok... | tools/server/server-context.cpp | server_context | INTEGRATE | Checkpoint restore guard in server-context.cpp; defensive against unnecessary restore when new tokens present; preserves Stage 7 / T121 / E13-01..E13-16 | Stage 7, T121, E13-01..E13-16 (Stage 7, Stage 10, Stage 13) |
| 89 | a121232fdc | agents: refactor, include more guidelines (#24111) | AGENTS.md | none | DEFER | out-of-file-glob | n/a |
| 90 | 4586479852 | webui: fix tool selector toggle/counter, key tools by sta... | tools/ui/src/lib/components/app/chat/ChatForm/ChatFormActions/ChatFormActionAdd/ChatFormActionAddSheet.svelte + 6 other | none | DEFER | out-of-file-glob | n/a |
| 91 | 4d742877b2 | build : use umbrella Headers directory for XCFramework mo... | build-xcframework.sh | none | DEFER | out-of-file-glob | n/a |
| 92 | 0066404085 | server : add header to tools/server/server-http.h (#24089) | tools/server/server-http.h | server_http | NO-OP | Server adds header to existing server-http.h; structural only; no behavior change | HTTP layer (Architecture, Stage 10 metrics) |
| 93 | 7ac5a4225e | cmake: skip cvector-generator and export-lora when CPU ba... | tools/CMakeLists.txt | none | DEFER | out-of-file-glob | n/a |
| 94 | e3ba22d6cc | fix(mtmd): handle Gemma 4 audio projector embedding size ... | tools/mtmd/clip.cpp | mtmd_path | INTEGRATE | mtmd Gemma 4 audio projector embedding size fix; preserves Stage 13 MTMD placeholder path contract | Stage 13 MTMD placeholder path (Stage 13 impl) |

### Aggregate summary

| Triage | Count | Notes |
|---|---|---|
| NO-OP | 4 | Log token rename, CLI dedup, header structural change |
| INTEGRATE | 16 | New mtmd features, checkpoint guards, sampler matching relax, vocab fix |
| DEFER (out-of-file-glob) | 67 | CI / docs / build / tests / webui / model-layer / pure backend (no runtime path a prior-stage contract governs) |
| DEFER (in-scope, deferred) | 7 | Six commits in the `ggml_cuda` glob where the design Part 2 rule "only when commit also changes a path a prior-stage contract governs" is not met, plus one Gemma4 MTP commit (`04eb4c446d`) that touches the hybrid memory layer (`llama-memory-hybrid*`) and needs Architect review of the Stage 12 H53 / H54 MTP rerun and T114 / T114a coverage denominator impact |
| REWORK-REQUIRED | 0 | No commit weakens, renames, or removes a prior-stage contract |
| Total | 94 | Matches the `git log --oneline` range count |

The aggregate counts add up to 94 (4 + 16 + 67 + 7 + 0 = 94).

### Rework candidates

None. No commit in the 94-commit range weakens, renames, or
removes a prior-stage contract. The DEFER (in-scope, deferred)
entries are deferred under the design Part 2 CUDA group rule
or for Architect review at Step 2, not because they break a
contract.

### Step 1 triage verdict

Step 1 verdict: PASS. The per-commit triage is complete and
the counts are verified. The triage is ready for the
Architect pre-merge report review (per upstream-merge-guide
Part 1 section 5) and for the Manager Step 2 review of
REWORK-REQUIRED entries. Per the design Part 2 rule "The
Manager is the only agent who can change a NO-OP, INTEGRATE,
or DEFER decision into a REWORK-REQUIRED decision", the
Manager reviews the seven DEFER (in-scope, deferred) entries
at Step 2 and decides whether any of them is escalated to
REWORK-REQUIRED. The Step 1 report is the handoff from
pre-merge analysis to merge execution; the merge does not
start until the Architect records a review verdict on this
report and the Manager records the Step 2 decisions.

## Open questions

The Developer surfaces the open questions below for the
Architect pre-merge report review. None of these is a
Step 1 blocker.

1. (D12) The D1 reference SHA in plan part-01 and plan
   part-04 verification table is the 2026-06-04 snapshot
   (`db94854ff56549f62b84d2f31608259a9e5e0e9f`). The
   current `origin/upstream_master` tip is
   `18ef86ecec723361362a332a79b4d913fd724d40` (refreshed
   2026-06-11). The Manager decides whether to update
   the D1 reference SHA in plan part-01 / part-04
   verification table or to add a "refreshed on
   2026-06-11" annotation. See "Newly surfaced open
   decision" D12 in "Manager decisions requested"
   section.

2. (Step 1 triage complete) The full commit range is
   94 entries. Step 1 triage reviewed each entry
   against the plan part-03 commit range rule (5-step
   filter) and the design Part 2 file-glob groups. The
   Triage table section records the filtered per-commit
   triage. The full range is 94 entries (4 NO-OP, 16
   INTEGRATE, 67 DEFER out-of-file-glob, 7 DEFER
   in-scope deferred, 0 REWORK-REQUIRED).

3. (T121 / Stage 13) The "Server : skip checkpoints
   beyond pos_next" commit `db94854ff` (#24411) and the
   "server: avoid unnecessary checkpoint restore when
   new tokens are present" commit `6f3a9f3de` (#24110)
   are classified as INTEGRATE in rows 4 and 88 of the
   Triage table. Both are checkpoint admission and
   restore guards in `server-context.cpp` that preserve
   the T121 public checkpoint admission contract and
   the Stage 13 E13-01..E13-16 endpoint parity.

4. (Stage 12 MTP) The "Remove padding and multiple D2D
   copies for MTP" commit `e95dae18d` (#24086) and the
   "mtp: support for gemma-4 E2B and E4B assistants"
   commit `7d2b45b4f` (#24282) are classified as DEFER
   in row 6 (in-scope, deferred; CUDA group rule) and
   DEFER out-of-file-glob in row 29. The Stage 12
   closure's BLOCKED state on the missing MTP-capable
   GGUF fixture carries forward.

5. (E13-01..E13-16) The "server : do not clear slots
   without unified KV cache" commit `961e9a3e4` (#24190)
   and the "server: avoid unnecessary checkpoint restore
   when new tokens are present" commit `6f3a9f3de`
   (#24110) are classified as INTEGRATE in rows 23 and
   88 of the Triage table. Both are defensive slot and
   checkpoint guards in `server-context.cpp` that
   preserve the E13 endpoint parity rows.

6. (Architect review at Step 2) The Gemma4 MTP commit
   `04eb4c446d` (#23398) is classified as DEFER
   in-scope, deferred in row 48 of the Triage table.
   The commit touches the hybrid memory layer
   (`llama-memory-hybrid-iswa.cpp`,
   `llama-memory-hybrid.cpp`, `llama-memory.h`,
   `llama-kv-cache-iswa.cpp`, `llama-kv-cache-dsa.cpp`)
   and the speculative runtime (`common/speculative.cpp`)
   and `server-context.cpp`. The Developer flags it as
   ambiguous for Architect review at Step 2: the commit
   may affect Stage 12 H53 / H54 public MTP rerun
   evidence and the T114 / T114a coverage denominator.
   The Manager reviews this entry at Step 2 and decides
   whether to keep DEFER or escalate to REWORK-REQUIRED.

7. (Manager review at Step 2) The seven DEFER
   (in-scope, deferred) entries (rows 6, 8, 26, 40, 41,
   48, 76 of the Triage table) need Manager review at
   Step 2 per design Part 2 rule "The Manager is the
   only agent who can change a NO-OP, INTEGRATE, or
   DEFER decision into a REWORK-REQUIRED decision". The
   Developer recommends keeping the six CUDA-group DEFERs
   and the one Gemma4 MTP DEFER (item 6 above) at Step
   1, and deferring any rework decision to the Architect
   and Manager review at Step 2.

8. (Documentation) The D5 commit bundle includes the
   design part-05 file with CRLF / trailing whitespace
   noise. The Developer deferred the per-line whitespace
   scan to the Step 1 plan documentary trail; the
   Step 1 plan includes the part-05 file in the bundle
   per the Manager decision. The Architect pre-merge
   report review can flag the part-05 noise as a
   follow-up if it materially affects the build, test,
   or review.

## Handoff

Next owner: Architect for pre-merge report review.

The Architect reviews this pre-merge report and records
verdicts on:

- D5 record (worktree dirty resolution, D5 commit
  `25d6a2a467da8a67953c45787eb89376c3e565cd`).
- D6 record (gap = 0 between `origin/upstream_master` and
  `git ls-remote` upstream `master`).
- D7 record (fork point SHA
  `6ddc9430b145f61a0c1733b9d79c99c0ebdedf50`).
- D12 open Manager decision (D1 reference SHA
  refresh annotation).
- Upstream reference verification table completeness.
- Commit range and Step 1 triage table (94 rows;
  aggregate counts sum to 94; 0 REWORK-REQUIRED).

The Architect pre-merge report review is named
`pre-merge-report-20260611-01-architect-review.md` per
plan part-03 naming convention. The Step 1 triage table
in this report is the handoff to the Architect and
Manager. Per design Part 2 rule, the Manager is the only
agent who can change a NO-OP, INTEGRATE, or DEFER
decision into a REWORK-REQUIRED decision; the Manager
reviews the seven DEFER (in-scope, deferred) entries at
Step 2 and records the final decisions in this report.

Step 1 closes on Architect pre-merge report review PASS.
Step 2 opens after the Architect review PASS and the
Manager records the final D5 / D6 / D7 / D12 / triage
decisions in this report. The merge does not start until
the Architect records a review verdict and the Manager
records the Step 2 decisions.
