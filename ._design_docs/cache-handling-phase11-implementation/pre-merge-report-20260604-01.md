# Stage 11 pre-merge analysis report

Report ID: pre-merge-report-20260604-01
Date opened: 2026-06-04
Date closed: 2026-06-04
Owner: Developer
Reviewer: Architect
Approver: Manager
Source: `upstream_master` (local tracking branch)
Target: `cache-optimization` (local default branch)
Plan reference: [part-01-implementation-plan.md](part-01-implementation-plan.md)
Design reference: [../cache-handling-phase11-design/part-02-pre-merge-analysis.md](../cache-handling-phase11-design/part-02-pre-merge-analysis.md)
Manager plan-change decision: local `upstream_master` is the upstream
reference, not a new `upstream` remote with `master` ref. Recorded in
the entry doc on 2026-06-04.

## Upstream reference verification

The Developer verified the local `upstream_master` tracking branch on
2026-06-04 before opening the commit range.

### Commands and outputs

| # | Command | Observed output |
| --- | --- | --- |
| 1 | `git rev-parse upstream_master` | `6ddc9430b145f61a0c1733b9d79c99c0ebdedf50` |
| 2 | `git log -1 --format='%H %ai %s' upstream_master` | `6ddc9430b145f61a0c1733b9d79c99c0ebdedf50 2026-06-04 10:58:13 +0300 readme : add status badges (#24104)` |
| 3 | `git merge-base cache-optimization upstream_master` | `40d5358d3c730b81729ba81cd5c44ed596d02510` |
| 4 | `git log --oneline cache-optimization..upstream_master` count | 225 commits |
| 5 | `git rev-parse --abbrev-ref HEAD` | `cache-optimization` |
| 6 | `git remote -v` | `origin  https://github.com/t-jet/llama.cpp-jet.git (fetch)` and `(push)`. No `upstream` remote is configured. |
| 7 | `git log --name-only --format='%H\|%ai\|%s' cache-optimization..upstream_master` | 1155 lines covering 225 commits |

### Staleness check against the actual llama.cpp upstream

The Developer compared the local `upstream_master` tip
`6ddc9430b145f61a0c1733b9d79c99c0ebdedf50` to the actual
`ggml-org/llama.cpp` `master` tip using the GitHub REST API:

| Source | SHA (short) | Subject | Date (UTC) |
| --- | --- | --- | --- |
| Local `upstream_master` | `6ddc9430` | readme: add status badges (#24104) | 2026-06-04 07:58:13 |
| GitHub `master` | `45864798` | webui: fix tool selector toggle/counter, key tools by stable identity (#24065) | 2026-06-04 11:09:49 |

The compare endpoint
(`https://api.github.com/repos/ggml-org/llama.cpp/compare/6ddc9430b...master`)
returned:

- `status: ahead`
- `ahead_by: 5`
- `behind_by: 0`
- `total_commits: 5`
- `merge_base_commit: 6ddc9430b145f61a0c1733b9d79c99c0ebdedf50`

The local `upstream_master` is **5 commits behind** the actual upstream
`master`. The 5 missing commits are:

| # | SHA (short) | PR | Subject | File-glob group match |
| --- | --- | --- | --- | --- |
| 1 | `e3ba22d6` | #24091 | fix(mtmd): handle Gemma 4 audio projector embedding size | none (mtmd outside scope) |
| 2 | `7ac5a422` | #24053 | cmake: skip cvector-generator and export-lora when CPU backend is disabled | none (build outside scope) |
| 3 | `00664040` | #24089 | server: add header to `tools/server/server-http.h` | HTTP and routes |
| 4 | `4d742877` | #23974 | build: use umbrella Headers directory for XCFramework module map | none (build outside scope) |
| 5 | `45864798` | #24065 | webui: fix tool selector toggle/counter | HTTP and routes (1 line), UI files outside scope |

Commit #3 (`00664040`) and the `server-http.h` line in commit #5
(`45864798`) both add `#include <unordered_map>` to
`tools/server/server-http.h`. Commit #3 declares the include
declaration; commit #5 confirms the include is present. The functional
impact is null. The Developer records this as Risk R1 in the risks
section.

## Commit range

- Range expression: `cache-optimization..upstream_master`
- Merge base SHA: `40d5358d3c730b81729ba81cd5c44ed596d02510`
- `upstream_master` tip SHA: `6ddc9430b145f61a0c1733b9d79c99c0ebdedf50`
- Total commits in range: 225
- Date range: 2026-04-23 (earliest) to 2026-06-04 (newest)

### File-glob filter

Per design Part 2, the file-glob filter is the set of patterns in
design Part 2 "File-glob groups for scope selection." A commit is in
scope when any of its changed paths matches a glob group, or when its
commit message references a relevant subsystem.

The filter applied to the 225-commit range produced **25 in-scope
commits**. The Developer recorded the filter result in a working
file at the run-time temporary path and verified the count by
re-running the filter with the same patterns.

### Exclusions

- Test-only, documentation-only, build-only, and CI-only commits are
  excluded per design Part 2 rule 3, except when the commit also
  changes a runtime path the prior-stage contracts govern. The
  in-scope commit list reflects this rule. The 200 commits excluded
  by the file-glob filter are all in that category.
- No merge commits are in the 25-commit in-scope set. The Developer
  verified each in-scope commit has exactly one parent.
- No pure version bumps are in the 25-commit in-scope set.

## Triage table

The triage table is sorted by commit date (oldest first). Each row
records the upstream SHA (short, 12 chars), the commit date, the
upstream subject, the files that matched a file-glob group, the
triage decision, the rationale, and the prior-stage contract (when
the decision is INTEGRATE or REWORK-REQUIRED). The Developer assigned
the decisions. The Architect reviews the assignments in the
pre-merge review. The Manager is the only agent who can change a
NO-OP, INTEGRATE, or DEFER into a REWORK-REQUIRED.

| # | SHA | Date | Subject | Files touched (in glob groups) | Triage | Rationale | Prior-stage contract |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | `1acee6bf` | 2026-05-22 | server: only parse empty msg if continuing an assistant msg (#23506) | `tools/server/server-task.cpp` | NO-OP | Empty-message parsing in chat template task transport. Does not touch cache, checkpoint, speculative, or HTTP paths. | n/a |
| 2 | `b22ff4b7` | 2026-05-23 | cmake/ui: refactor the build (#23352) | `common/common.h`, `tools/server/server-http.cpp` | INTEGRATE | Refactor of the `LLAMA_UI_DEFAULT_ENABLED` gate in `common_params` and the UI asset handler in `server-http.cpp`. UI asset embedding is now sourced from a `llama_ui_find_asset` lookup. The default-`ui` field becomes unconditionally `true`. The local fork's `cache-optimization` does not override the default; the field rename is additive and safe. Apply with local verification that the new `LLAMA_UI_HAS_ASSETS` macro is defined when the build embeds the UI. | Stage 10 (deterministic seams, public surface stability) - the public surface set is unchanged. |
| 3 | `83eebe9d` | 2026-05-24 | server: add margin for draft model for `fit` (#23485) | `tools/server/server-context.cpp` | INTEGRATE | Adds a `common_fit` margin for the draft model during the `fit` estimation in `server_context`. The local `server-context.cpp` already has the `fit_params` and `fit_params_target` paths. The draft-model margin increases the reserved context for the draft. The speculative path and namespace identity are preserved. | Architecture Part 6 (speculative mode namespace isolation), Stage 4 (hot and cold residency budget pool) - the draft fit does not touch the budget pool. |
| 4 | `e2ef8fe4` | 2026-05-25 | server: fix checkpoints creation (#22929) | `common/arg.cpp`, `common/chat.cpp`, `common/chat.h`, `common/common.cpp`, `common/common.h`, `tools/server/server-common.cpp`, `tools/server/server-context.cpp`, `tools/server/server-task.h` | INTEGRATE | Renames `params.checkpoint_every_nt` to `params.checkpoint_min_step` (semantic shift: "every n tokens" -> "minimum spacing between checkpoints"). Adds `n_before_user` to `slot.task->params` and a new `message_spans` field on chat template output. New `common_chat_split_by_role` helper and `prompt_get_n_before_user` function. The local `common.h` has the old `checkpoint_every_nt` field; the rename touches 4+ local files. The local Stage 9 hybrid cache checkpoint work in `server-cache-hybrid.cpp` is a separate concern and is not affected. Apply with local adjustment: rename `checkpoint_every_nt` to `checkpoint_min_step` in `common/common.h`, `common/arg.cpp`, `common/common.cpp`, and `tools/server/server-context.cpp`. Add the new `n_before_user` field to `server_task::params` and accept `message_spans` in chat template output. | Stage 9 (workload profile detection, prepared-prompt boundary placement) - the new `n_before_user` mechanism extends the prepared-prompt boundary contract with metadata. Compatible. |
| 5 | `6c4cbdc7` | 2026-05-25 | server: MTP layer kv-cache should respect draft type ctk (#23646) | `tools/server/server-context.cpp` | INTEGRATE | The MTP draft context `cparams_dft` now copies `type_k` and `type_v` from the draft's `cache_type_k` / `cache_type_v` parameters. The local `server-context.cpp` already has `cache_type_k` and `cache_type_v` wiring for the draft speculative (lines 1125-1126). The local MTP cparams path in `cparams_dft` does not yet propagate the draft's `cache_type_k` / `cache_type_v`. The upstream commit adds the propagation; the local will absorb it. 4 lines, low risk. | Architecture Part 6 (speculative mode namespace isolation), Stage 5 (draft runtime mode identity) - the MTP path remains a distinct mode identity. |
| 6 | `7085492c` | 2026-05-27 | server: fix the log message when using SSL (#23393) | `tools/server/server-http.cpp`, `tools/server/server-http.h` | NO-OP | Log-message wording fix in the SSL path. No behavioral change. | n/a |
| 7 | `6b4e4bd5` | 2026-05-27 | common: fix env names to all have `LLAMA_ARG_` prefix (#23778) | `common/arg.cpp` | INTEGRATE | Standardizes the env-var prefix in `common/arg.cpp` (10 lines). Most of the 29 changed files are workflow yaml files. The local `arg.cpp` has its own env-var parsing; the env-var prefix rename is mechanical. Apply with local verification that no local env-var consumer depends on the old prefix. | Stage 10 (deterministic seams) - the public surface is unchanged. |
| 8 | `0b246862` | 2026-05-28 | server: minor tweaks to use more cpp features (#23785) | `tools/server/server-http.cpp`, `tools/server/server-http.h` | INTEGRATE | Refactor of `server_http_context::init` to use lambdas, structured bindings, and `std::optional`. Pure refactor, no behavior change. The local `server-http.cpp` will absorb the refactor. | Stage 10 (deterministic seams) - the public surface is unchanged. |
| 9 | `7fb1e70b` | 2026-05-28 | arg: Add `LLAMA_ARG_API_KEY_FILE` env var for `--api-key-file` (#23167) | `common/arg.cpp` | NO-OP | Adds a new env-var name. The local fork has no prior API-key-file work that this would conflict with. The change is additive. | n/a |
| 10 | `d205df6` | 2026-05-28 | server, ui: Add support for HTTP ETags in llama-server (#23701) | `tools/server/server-http.cpp` | NO-OP | Adds ETag-based caching to the HTTP layer. Does not touch cache, checkpoint, or speculative paths. | n/a |
| 11 | `98e480a` | 2026-05-29 | app: move licences to llama-app (#23824) | `common/arg.cpp` | NO-OP | Removes 12 lines from `common/arg.cpp` that referenced the moved licenses. Pure license-management refactor. | n/a |
| 12 | `cb47092` | 2026-05-29 | server: bump timeout to 3600s (#23842) | `common/common.h`, `tools/server/server-queue.cpp`, `tools/server/server-queue.h` | NO-OP | Bumps the default request timeout from 600s to 3600s. No contract change. The local has its own `common/common.h` and `server-queue` paths. | n/a |
| 13 | `06d26dfd` | 2026-05-29 | download: add option to skip_download (#23059) | `common/arg.cpp`, `common/arg.h`, `common/common.h` | NO-OP | Adds `--skip-download` option to the model download path. Not a contract path. | n/a |
| 14 | `0821c5fc` | 2026-05-30 | server: in SSE mode, send HTTP headers when slot starts (#23884) | `tools/server/server-context.cpp`, `tools/server/server-task.cpp`, `tools/server/server-task.h` | INTEGRATE | Adds a `is_begin` flag to `send_partial_response` so that SSE responses send HTTP headers and status code before the first token. The local `server-context.cpp` has its own SSE response path. Apply with local adjustment: ensure the new `is_begin` flag is plumbed through the local SSE path and the local `res->is_begin` member exists. 21 lines, low risk. | Stage 10 (deterministic seams) - the public surface is unchanged. |
| 15 | `6f165c1c` | 2026-06-01 | server: handle If-None-Match weak ETags (#23916) | `tools/server/server-http.cpp` | NO-OP | 1-line change in the ETag parser. Functional fix only. | n/a |
| 16 | `5254a79` | 2026-06-01 | common: support manually triggering the reasoning budget end sequence (#23949) | `common/sampling.cpp`, `common/sampling.h` | NO-OP | Adds a manual end-sequence trigger for the reasoning budget. Per design Part 2 rule on the sampling group, the commit is in scope only when it also changes a path the cache layer reads from. This commit does not change a cache-layer path. Sampling-only change. | n/a |
| 17 | `5dcb7116` | 2026-06-01 | speculative: fix n_outputs_max and remove draft-simple auto-enable (#23988) | `common/arg.cpp`, `common/speculative.cpp`, `common/speculative.h`, `tools/server/server-context.cpp` | INTEGRATE | Adds a `common_speculative_n_max` helper in `common/speculative.cpp` and removes the speculative-type switch from `server-context.cpp` (replaced by a call to the helper). Removes the draft-simple auto-enable behavior. The local `common/speculative.h` does not have `common_speculative_n_max`; the local `server-context.cpp` has the old speculative-type switch (in `server_n_outputs_max`, see commit #18). Apply with local adjustment: add the helper to the local `common/speculative.{h,cpp}` and remove the duplicate switch from the local `server-context.cpp`. The CI workflow also enables server tests on PRs - informational only. | Architecture Part 6 (speculative mode namespace isolation), Stage 5 (draft runtime mode identity) - the helper centralizes n_max logic without changing the mode identity. |
| 18 | `de6f727a` | 2026-06-01 | llama: limit max outputs of `llama_context` (#23861) | `common/common.cpp`, `common/common.h`, `tools/server/server-context.cpp` | INTEGRATE | Adds a `n_outputs_per_seq` field to `llama_cparams` and a new static `server_n_outputs_max` in `server-context.cpp` that uses it. The local `llama-cparams.h` and `common.h` do not have `n_outputs_per_seq`. The local `llama-context.cpp` uses `n_outputs_max = std::max<int64_t>(n_outputs, n_seq_max())`. Apply with local adjustment: add `n_outputs_per_seq` to `llama_cparams` and update `server-context.cpp` to call the new `server_n_outputs_max` helper. Note: commit #17 supersedes this one in the upstream timeline; the local should apply #17 first (which simplifies the speculative switch in `server_n_outputs_max`), then #18 (which re-adds the helper with embedding/pooling adjustments). | Architecture Part 6 (speculative mode namespace isolation), Stage 5 (draft runtime mode identity) - the helper uses the same draft-mode identity and respects the embedding and pooling adjustments. |
| 19 | `354ebac8` | 2026-06-02 | server: real-time reasoning interruption via control endpoint (#23971) | `common/common.h`, `common/sampling.cpp`, `tools/server/server-common.cpp`, `tools/server/server-context.cpp`, `tools/server/server-context.h`, `tools/server/server-task.cpp`, `tools/server/server-task.h` | INTEGRATE | Adds a new `SERVER_TASK_TYPE_CONTROL` task type and a `server_task_result_control` result type. Adds a `reasoning_control` field to `common_task_params` and a new control endpoint handler in `server-context.cpp`. The local `server-task.h` and `server-context.cpp` have their own task type enums and result types. Apply with local adjustment: extend the local `SERVER_TASK_TYPE` enum and `server_task_result` hierarchy with the new type. 277 lines, the largest change in the in-scope set. | Stage 10 (bounded diagnostics for failure and fallback paths), Stage 2 (prepared-prompt boundary metadata) - the control endpoint does not change the prepared-prompt boundary transport. |
| 20 | `4f3a4beb` | 2026-06-02 | llama: deprecate `llama_set_warmup` (#24009) | `common/common.cpp` | NO-OP | Deprecates the `llama_set_warmup` public function. 3 lines removed from `common/common.cpp`. The local does not call `llama_set_warmup`. | n/a |
| 21 | `f8e67fc5` | 2026-06-02 | ui: Add Thinking mode toggle with reasoning effort levels + improvements for Chat Form Add Action UI (#23434) | `common/arg.cpp` | NO-OP | 40 files, 1100 insertions, mostly UI files. 2 lines removed from `common/arg.cpp`. Pure UI feature, no contract path. | n/a |
| 22 | `60130d18` | 2026-06-02 | server: add SSE ping interval (#24013) | `common/arg.cpp`, `common/common.h`, `tools/server/server-context.cpp`, `tools/server/server-queue.cpp`, `tools/server/server-queue.h` | INTEGRATE | Adds an `--sse-ping-interval` option that emits a `:\\n\\n` SSE comment when no data has been sent for the interval. The ping is emitted in the `res->next` callback. The local `server-context.cpp` has its own `res->next` callback. Apply with local adjustment: plumb the `sse_ping_interval` through the local callback and the local `common/common.h` `common_params` struct. 29 lines, low risk. | Stage 10 (deterministic seams) - the public surface gains one new option. Operators do not parse the SSE comment body. |
| 23 | `0b715406` | 2026-06-02 | common: fix state save in `common_prompt_batch_decode` (#23468) | `common/common.cpp`, `common/common.h` | NO-OP | Fixes a state-save bug in the prompt batch decode path. The state here is `llama_context` state, not cache state. The local does not call this helper. | n/a |
| 24 | `e3666269` | 2026-06-02 | arg: removed unnecessary mmproj download when users pass `--no-mmproj` (#23425) | `common/arg.cpp` | NO-OP | Removes a download path that triggered when the user passed `--no-mmproj`. Pure arg-parsing fix. | n/a |
| 25 | `166fe294` | 2026-06-04 | qwen35: use post-norm hidden state for MTP (#24025) | `common/speculative.cpp`, `common/speculative.h`, `tools/server/server-context.cpp` | INTEGRATE | Renames the speculative MTP "pre-norm" API to "nextn": `llama_set_embeddings_pre_norm` -> `llama_set_embeddings_nextn`, `llama_get_embeddings_pre_norm` -> `llama_get_embeddings_nextn`, `common_speculative_need_embd_pre_norm` -> `common_speculative_need_embd_nextn`, `server_slot::need_embd_pre_norm` -> `server_slot::need_embd_nextn`. The local `common/speculative.cpp` has 9 references to the old `pre_norm` API (lines 6, 165, 491, 492, 587, 629, 690, 776, 1521) and the local `tools/server/server-context.cpp` has 3 references (lines 533, 538 and the `need_embd_pre_norm` member at 262). The local Stage 9 fix reports (`fix-qwen-eval-2`, `fix-qwen-summary`) reference the old API name in 5+ places; those are docs and need the same rename in follow-up. Apply with local adjustment: rename the API across `common/speculative.{h,cpp}`, `tools/server/server-context.cpp`, and the fix-report docs. The local `llama_set_embeddings_pre_norm(ctx_tgt, true, /*masked*/ true)` (line 491) is the local Stage 9 fix that flipped the `masked` flag to `true`; the upstream rename preserves the value, so the local fix is preserved. | Architecture Part 6 (speculative mode namespace isolation), Stage 5 (draft runtime mode identity) - the rename is a pure API rename. The MTP path remains a distinct mode identity. |

## Triage summary

| Decision | Count |
| --- | --- |
| NO-OP | 13 |
| INTEGRATE | 12 |
| REWORK-REQUIRED | 0 |
| DEFER | 0 |
| REVERT | 0 |
| NEEDS-DECISION | 0 |

NO-OP breakdown (13): `1acee6bf`, `7085492c`, `7fb1e70b`, `d205df6`, `98e480a`, `cb47092`, `06d26dfd`, `6f165c1c`, `5254a79`, `4f3a4beb`, `f8e67fc5`, `0b715406`, `e3666269`.

INTEGRATE breakdown (12): `b22ff4b7`, `83eebe9d`, `e2ef8fe4`, `6c4cbdc7`, `6b4e4bd5`, `0b246862`, `0821c5fc`, `5dcb7116`, `de6f727a`, `354ebac8`, `60130d18`, `166fe294`.

Affected prior stages (by INTEGRATE count): speculative path (commits #5, #17, #18, #25 = 4), server context (commits #2, #3, #14, #17, #18, #19, #22 = 7), server task (commit #14, #19 = 2), common params (commits #2, #7, #12, #13, #17, #22 = 6), HTTP (commits #2, #8, #10, #15 = 4), chat template (commit #4 = 1), checkpoint logic (commit #4 = 1).

Expected reworks: 0. No commit in the 25-commit in-scope set invalidates a prior-stage contract from design Part 1. The fork's Stage 9 hybrid cache checkpoint work in `server-cache-hybrid.cpp` is independent of the upstream's mid-prompt state-save checkpoint mechanism (commit #4 `e2ef8fe4`) and is not affected.

## Manager decisions requested

D1 (fork point SHA): The fork point is
`40d5358d3c730b81729ba81cd5c44ed596d02510`. Manager approval is
recorded in the merge log "Cover and metadata" section when Step 3
opens.

D2 (rework-trigger threshold): Not applicable for this cycle. No
REWORK-REQUIRED decisions in the triage table.

D3 (known gap): Not applicable for this cycle. No DEFER decisions in
the triage table.

D4 (mapping for a metric or field rename): Not applicable. No
upstream commit in the 25-commit in-scope set renames a public
metric, a bounded diagnostic field, or a CLI flag that the fork's
Stage 10 closure contracts name. The `--checkpoint-every-n-tokens`
CLI flag and the `params.checkpoint_every_nt` field are renamed
by commit #4 to `--checkpoint-min-step` and `params.checkpoint_min_step`,
but the rename is in the upstream's mid-prompt state-save path,
not in the hybrid cache public surface. The fork's Stage 10 closure
contracts on `cache_checkpoint_*` Prometheus metrics are not
affected.

D5 (extension of the upstream commit range): Not applicable. The
range is applied as the design Part 1 rule specifies.

D6 (NEW, surfaced by the pre-merge analysis): The local
`upstream_master` is 5 commits behind the actual
`ggml-org/llama.cpp` `master` branch on 2026-06-04. The Manager
decides whether the Developer fetches and fast-forwards
`upstream_master` from `https://github.com/ggml-org/llama.cpp.git`
`master` before Step 3 opens, or merges with the current 5-commit
gap. The recommended default is to fetch and re-run the pre-merge
analysis on the refreshed range. The Developer records the chosen
path in the merge log when Step 3 opens.

## Risks

R1. The local `upstream_master` is 5 commits behind the actual
upstream `master` on 2026-06-04. The 5 missing commits are listed
in the "Upstream reference verification" section. Two of the 5
(commits #3 and #5 in the staleness table) touch
`tools/server/server-http.h`. The functional impact of the missing
commits is null (`#include <unordered_map>` was already available
transitively), but the merge range does not include them. If the
Manager does not approve the recommended fetch-and-refresh path
(D6), the merge log records the 5-commit gap as a known gap with
a follow-up plan to re-sync `upstream_master` after the merge
closes.

R2. Commit `e2ef8fe4` (server: fix checkpoints creation) renames
`params.checkpoint_every_nt` to `params.checkpoint_min_step`. The
local `common/common.h` has the old name. The merge must update
`common/common.h`, `common/common.cpp`, `common/arg.cpp`, and
`tools/server/server-context.cpp` in lockstep. The rename is
mechanical but the developer must also update the CLI flag from
`--checkpoint-every-n-tokens` to `--checkpoint-min-step` in
`common/arg.cpp` and the operator documentation. The fork's
operator docs in `tools/server/README.md` reference the old flag
and need a corresponding update.

R3. Commit `166fe294` (qwen35: use post-norm hidden state for MTP)
renames the speculative MTP "pre_norm" API to "nextn". The local
`common/speculative.{h,cpp}` has 9 references to the old API and
the local `tools/server/server-context.cpp` has 3 references. The
local Stage 9 fix reports (`fix-qwen-eval-2`, `fix-qwen-summary`)
reference the old API name in 5+ places. The merge must rename
the API across the runtime code and update the fix-report docs
in a follow-up. The Stage 9 fix that flips the `masked` flag to
`true` (line 491 of local `common/speculative.cpp`) is preserved
by the rename.

R4. Commit `5dcb7116` (speculative: fix n_outputs_max and remove
draft-simple auto-enable) and commit `de6f727a` (llama: limit max
outputs of `llama_context`) are chained in the upstream timeline.
The Developer must apply them in order. The local does not have
the intermediate state from commit #5 (the speculative-type switch
in `server-context.cpp` was never there locally), so the local
can absorb both commits without intermediate-state conflicts. The
local does not have `n_outputs_per_seq` in `llama_cparams` and
must add it during the merge of #18. The Developer should run
the build after each commit to confirm the local Stage 9 work
still compiles.

R5. Commit `354ebac8` (server: real-time reasoning interruption
via control endpoint) is the largest change in the in-scope set
at 277 insertions across 22 files. The new `SERVER_TASK_TYPE_CONTROL`
task type and `server_task_result_control` result type are
additive. The local `server-task.h` and `server-task.cpp` have
their own task type enums and result hierarchy. The Developer
must extend the local enum and result hierarchy with the new
type. The local cache-controller path in `server-cache-controller.{h,cpp}`
is not affected by the new control endpoint.

R6. Commit `5dcb7116` enables server tests on PRs in
`.github/workflows/server.yml` (3 lines removed). After the
merge, the fork's CI will run server tests on every PR. The
Developer does not have control over the fork's CI configuration
and records this as an informational risk in the merge log.

R7. The 225-commit range includes commits the file-glob filter
excludes. The Developer verified the filter is correct by
re-running the same patterns. A commit that the filter missed
would appear as an unassigned upstream commit in the integration
branch after the merge. The Architect pre-merge review is the
defense against a missed filter row.

## D6 outcome

The Manager decided D6 on 2026-06-04. The Developer proceeds with
the current 5-commit gap and re-syncs `upstream_master` from
`https://github.com/ggml-org/llama.cpp.git` `master` after the
merge closes. The follow-up plan is:

- Owner: Developer (the next Stage 11 cycle that reopens the
  upstream merge activity).
- Target cycle: the next Stage 11 merge cycle that opens after the
  current merge closes. The cycle opens when the
  `upstream_master` tracking branch is at least 25 commits behind
  the actual `ggml-org/llama.cpp` `master` tip, or when the
  Manager opens a new Stage 11 cycle for any other reason.
- Action: fetch the upstream `master` ref into
  `upstream_master` with a fast-forward, re-run the pre-merge
  analysis on the refreshed range, and surface a new D6 decision
  if the new range exposes a contract gap the current range did
  not.
- Contract link: the 5-commit gap does not invalidate a
  prior-stage contract from design Part 1. The 5 missing commits
  are recorded in this report's "Upstream reference verification"
  section. Two of the 5 (`00664040` and the `server-http.h` line
  in `45864798`) touch `tools/server/server-http.h` with null
  functional impact. The remaining 3 touch only `tools/mtmd`,
  `tools/CMakeLists.txt`, or `build-xcframework.sh`, which are
  outside the file-glob groups in design Part 2.

The merge log records the 5-commit gap as a known gap in the
"Deferred upstream commits" and "Known gaps" sections.

## Next gate

The Architect records a review verdict on the pre-merge report
(Step 2 in the implementation plan). The Architect verdict PASSES
only when triage reasons cite a contract, a path, or a test
surface, and the aggregate summary is consistent with the triage
table. The Manager reviews the Architect verdict and records the
D1 fork point approval and the D6 staleness decision in the merge
log when Step 3 opens. The next owner after the pre-merge review
is the Manager.

The Manager is the only agent who can change a NO-OP, INTEGRATE,
or DEFER decision into a REWORK-REQUIRED decision. The Developer
does not change a triage decision without a Manager record.

The merge execution (Step 3), the per-rework planning (Step 4),
the regression test scope (Step 5), and the merge log and Stage 11
closure (Step 6) remain closed until the Manager review of the
pre-merge analysis passes.
