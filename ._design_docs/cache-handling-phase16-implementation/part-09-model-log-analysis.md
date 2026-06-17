# Stage 16 implementation part 9: model log analysis after chat-path prompt-boundary fix

Status: analysis report
Date: 2026-06-17
Stage: 16 follow-up evidence
Source log: `._analysis/model_log.txt`
Build in log: `build 9672 (a4a5e86bd)` with MSVC 19.44.35227.0 for x64
Model in log: `Qwen3.6-27B-MTP-GGUF/Qwen3.6-27B-Q4_K_M.gguf`

## Purpose

This report analyzes the long-running user workload captured after the Stage
16 chat-path prompt-boundary work. It is not a QA rerun and does not change
the Stage 16 closure decision. It records what the production-like session
shows about prompt size, request timing, cache restore behavior, checkpoint
handling, eviction, cold-store behavior, and errors.

## References

| Source | Use |
| --- | --- |
| [Stage 15 design part 9](../cache-handling-phase15-design/part-09-post-closure-chat-path-prompt-boundary.md) | Original post-closure chat-path boundary design and later bug-fix notes |
| [Architecture part 9](../cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md) | Chat-path prompt-span invariant |
| [Stage 16 implementation part 3](part-03-bugfix-mtp-internal-checkpoint.md) | Per-checkpoint prompt-span boundary fix |
| [Stage 16 implementation part 5](part-05-bugfix-iteration-2-mtp-matching.md) | `metadata == "prompt"` matching-loop relaxation |
| [Stage 16 implementation part 8](part-08-architect-bugfix-review-iteration-3.md) | Compile-fix review and QA handoff |
| [test-report-20260616-03.md](../.test_reports/test-report-20260616-03.md) | Controlled Stage 16 PASS evidence |
| [cache-handling-stage-tracker.md](../cache-handling-stage-tracker.md) | Stage 16 closure state |

## Session shape

| Item | Value |
| --- | --- |
| Log size | 51,620,373 bytes |
| Parsed line count | 736,935 lines |
| Timestamp range | 0:00.075 to 645:40.835 |
| Total process lifetime in log | 10h 45m 40.760s |
| Active request window | 1:13.232 to 137:42.145 |
| Idle tail before shutdown | about 8h 28m |
| Requests completed | 19 POST `/v1/chat/completions` |
| HTTP status | 15 x 200, 4 x 500 |
| Log levels | D 703,608; I 9,392; W 41; E 43 |

The first user request starts after model load at 1:13.232. The last request
failure is at 137:42.145. The server remains alive until 645:40.835, then
stops after interrupt.

## Prompt and token statistics

| Metric | Count | Min | p50 | p90 | p99 | Max | Sum |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `prompt_get_n` `n_before_user` | 19 | 11,829 | 23,530 | 61,395 | 61,684 | 61,747 | 549,743 |
| Restore lookup tokens | 19 | 12,055 | 23,545 | 61,562 | 62,993 | 63,307 | 577,293 |
| `task.n_tokens` on started prompts | 15 | 12,055 | 23,459 | 61,462 | 63,063 | 63,307 | 450,704 |
| Slot release tokens | 15 | 12,396 | 23,656 | 61,631 | 63,656 | 63,963 | 456,516 |
| Prompt clear tokens | 15 | 12,396 | 23,656 | 61,631 | 63,656 | 63,963 | 456,516 |

The workload is dominated by large chat prompts. Median lookup size is about
23.5k tokens, with several requests around 61k to 63k tokens. Each successful
request grows the slot past the prompt size by generated tokens before release.

The log has 3,522 prompt timing lines. Prompt processing throughput is stable:
minimum 52.65 tokens/s, p50 61.23 tokens/s, p90 62.98 tokens/s, p99 63.45
tokens/s, maximum 63.50 tokens/s. Late in the run, a 26,956-token prompt was
processing at about 59.36 tokens/s after 454.07 seconds.

## Cache restore behavior

| Metric | Value |
| --- | ---: |
| Non-destructive restore attempts | 19 |
| Exact matches found | 0 |
| `try_restore - no exact match found` | 19 |
| Successful response `cache_n` values | 15 fields, all 0 |
| Positive `cache_n` values | 0 |
| Successful saves | 12 |
| Final recorded cache entries | 12 |
| Final recorded cache tokens | 378,952 |
| Final recorded cache total size | 6,692.734 MiB |
| Cache payload budget | 8,192 MiB |

Every request attempts a non-destructive restore before scheduling. Every
lookup misses the exact cache. The successful responses all report
`cache_n = 0`, so the production-like session did not reuse prior prompts
through the public response timing path.

The important distinction from the pre-fix report is that this log does not
show `checkpoint admission skipped (missing checkpoint boundary metadata)`.
That warning appears 0 times here. The old boundary failure is gone from the
observed log. The remaining problem is different: entries are saved, but later
requests use different namespaces or token spans and miss exact restore.

The first large request used namespace `2977610950730133435`, looked up 61,311
tokens, missed, then saved as entry 1. Later requests also missed and saved new
entries under different namespaces. That points to changing rendered prompt
identity between requests, not a checkpoint-boundary admission warning.

## Metadata shape

Representative `cache metadata:` lines:

| Time | Tokens | Boundaries | Source |
| --- | ---: | ---: | --- |
| 1:13.232 | 61,311 | 462 | `openai-chat`, rendered-text-boundary-inference |
| 20:33.275 | 12,055 | 12 | `openai-chat`, rendered-text-boundary-inference |
| 23:57.302 | 21,776 | 30 | `openai-chat`, rendered-text-boundary-inference |
| 122:25.579 | 26,651 | 20 | `openai-chat`, rendered-text-boundary-inference |
| 130:01.174 | 26,960 | 28 | `openai-chat`, rendered-text-boundary-inference |

Boundary counts scale with the rendered chat content. The very large first
prompt has 462 inferred boundaries. Smaller later prompts have 12 to 30
boundaries. The metadata source remains the chat path and uses rendered-text
boundary inference throughout.

## Checkpoint behavior

| Metric | Value |
| --- | ---: |
| Context checkpoints created | 28 |
| Context checkpoints erased as invalidated | 27 |
| Created checkpoint token min | 11,829 |
| Created checkpoint token p50 | 23,031 |
| Created checkpoint token p90 | 61,501 |
| Created checkpoint token max | 63,155 |
| Created checkpoint size range | 196.059 MiB to 397.530 MiB |

Checkpoint positions include:

```text
11829, 12104, 12310, 12487, 21142, 21319, 21526, 21703,
21939, 22123, 22507, 22835, 22843, 23219, 23253, 23444,
23530, 25770, 26056, 26437, 26751, 60993, 61307, 61395,
61747, 62771, 63155
```

These are not fixed 256-token intervals. They track MTP/internal request
state and prompt growth. Most checkpoints from the previous request are erased
when the next task updates the slot. The log contains no checkpoint-admission
failure text and no missing-boundary warning, so the erasures appear tied to
slot invalidation when the next prompt differs, not to the earlier strict
boundary failure.

## Checkpoint granularity and branch policy

The log suggests that checkpoint granularity is too fine for this workload.
Twenty-eight checkpoints were created across 15 successful requests, but 27
were erased as invalidated. The saved positions often sit close together inside
one rendered prompt, for example 21,142, 21,319, 21,526, 21,703, 21,939,
22,123, 22,507, and 22,835. Each checkpoint is large enough to matter
(196.059 MiB to 397.530 MiB), so dense checkpointing can burn RAM and cold
storage without improving reuse when the next request follows a different
rendered prompt identity.

For agentic chat workflows, a smaller branch policy is probably a better fit.
When the first matching node does not exist for a new agent prompt, the server
usually needs at most two full snapshots for that inference:

1. Save a branch point immediately before the first user message. In common
   agent launches, everything before that point is system instructions, tool
   descriptions, or other reusable agent setup. Another instance of the same
   agent can reuse that prefix and create its own branch from there.
2. Save the final state after inference finishes. If the same agent continues
   the conversation, it will normally continue from the current branch tip.

Intermediate snapshots after earlier system sections but before the branch tip
look less useful. They are neither the stable shared prefix for another agent
instance nor the live continuation point for the same agent. Some prompts can
end with several user messages rather than exactly one user message, so the
boundary rule should be "before the first user message that starts the
conversation-specific branch", not "before the only user message".

This policy still needs a compatibility exception for checkpoint-dependent
models. R84 says checkpoint nodes are canonical branch structure for those
models. The practical target is not "disable checkpoints", but "admit fewer
large snapshots by default and prefer semantic branch points". Dense MTP
internal checkpoints can remain available as a fallback or under a diagnostic
profile, but the default server profile should avoid filling cache storage
with checkpoints that are immediately invalidated.

## Eviction and cold-store behavior

| Metric | Value |
| --- | ---: |
| LRU evictions selected | 19 |
| Evicted token min / p50 / max | 12,396 / 23,656 / 63,963 |
| Evicted payload bytes min / p50 / max | 845,326,380 / 1,323,767,292 / 3,065,221,980 |
| Total evicted payload bytes selected | 30,112,528,012 |
| Cold-store events | 93 |
| Cold files written successfully | 13 |
| Cold write failures | 18 |
| Demotion failures handled | 9 |

Early demotions succeed. Starting at 92:33.486, cold-store writes begin failing
with `cannot write target bytes`, first for payload id 15. Later payload ids
17 through 24 show the same pattern. The controller then logs
`demotion failed ... reverting to hot (failure_reason=1)`.

This matters because the cache has an 8 GiB RAM budget. Once cold demotion
fails, entries that should leave hot storage return to hot. That increases
pressure on host memory during later scheduling and slot updates.

Disk space is a real cache budget, not an operational detail. This run writes
large cold files until writes start failing. A cache implementation that only
budgets hot RAM can still fail under normal use because disk fills first. The
eviction policy should account for cold-layer bytes and should be able to drop
or refuse demotion before the filesystem reports write failure.

The CLI already exposes `--cache-ram N` for hot cache MiB and
`--cache-cold-path PATH` for cold payload storage. It does not expose a cold
disk budget. Add a separate limit, for example `--cache-cold-max-mib N`
(`-1` no limit, `0` disable cold writes), and make LRU eviction consider both
hot bytes and cold bytes. When cold bytes exceed the limit, eviction should
remove unprotected cold payloads or skip demotion with a bounded diagnostic.
That is more predictable than discovering the limit through failed writes.

The cold budget should also leave a safety margin. On Windows, failed writes
can leave staging files or partial payloads if the process exits at the wrong
time. Startup validation and cold cleanup should count cold files on disk and
remove orphaned staging files before admitting more demotions.

## Debug evidence collection

The local argument parser and current upstream server documentation already
have useful prompt-debugging knobs. One detail matters: `--log-prompts-dir`
exists in this local source tree, but the current upstream server README does
not list it. Treat it as fork-local evidence support until it is confirmed
upstream.

| Option | Source | Use for this investigation |
| --- | --- | --- |
| `--log-prompts-dir PATH` | local `common/arg.cpp`, `tools/server/server-context.cpp` | Writes each processed prompt body to a timestamped file before tokenization. This gives evidence for prompt identity drift without scraping long debug logs. |
| `--log-file FNAME`, `-v` / `--verbose` / `--log-verbose`, `-lv` / `--log-verbosity N` | `common/arg.cpp`, upstream server README | Keeps the runtime log and controls detail level. Useful for tying prompt files to cache lookup, admission, demotion, and restore records. |
| `/apply-template` endpoint | upstream server README | Returns the rendered chat prompt without inference. Useful for reproducing prompt rendering differences outside a long run. |
| `--verbose-prompt` | local `common/arg.cpp` | Prints a verbose prompt before generation in supported examples. Less useful for server production runs, but helpful for smaller reproduction cases. |
| `--chat-template`, `--chat-template-file`, `--chat-template-kwargs`, `--jinja`, `--no-jinja` | `common/arg.cpp`, upstream server README | Pins chat rendering. Useful when comparing whether prompt drift comes from template changes, tool formatting, or request content. |
| `--ctx-checkpoints N` and `--checkpoint-min-step N` | `common/arg.cpp`, upstream server README | Bounds checkpoint count and minimum spacing. Useful for testing whether dense checkpointing drives memory or disk pressure. |

For future evidence, `--log-prompts-dir` is the most important existing
option. The log can say "no exact match", but raw prompt snapshots let us diff
the rendered request content, compute prefix equality, and decide whether the
right feature is exact restore, prefix restore, or branch reuse.

Two additions would make this easier without dumping private prompt text into
normal logs:

1. Add a prompt evidence mode that writes per-request metadata next to the raw
   prompt file: preparation id, namespace, prompt token count, first-user
   boundary, boundary count, token-span checksum, and cache lookup result.
2. Add a redacted mode that records hashes and token counts only. That allows
   production evidence collection when raw prompt logging is not acceptable.

## QA reproduction path

The workload can be brought into QA, but it should not be one ordinary fast
test. Use three tiers:

| Tier | Shape | Purpose |
| --- | --- | --- |
| Deterministic synthetic stress | Small fixture, generated 12k / 24k / 60k-token agentic prompts, exact repeats and near-duplicates | Runs often; proves prompt identity, prefix behavior, checkpoint count, eviction, and cold cleanup without a 27B model. |
| Stage 12/15 stress and long-run extension | Existing S01..S08 and L01..L03 framework, with an agentic prompt generator added to prompt storms, large branch forests, mixed profiles, and cold pressure | Fits the current QA process; turns this report into repeatable stress evidence. |
| Heavy manual or nightly reproduction | Qwen3.6-27B-MTP, near-60k prompts, cold path, 8 GiB cache RAM, several-hour run | Reproduces the user workload class; too expensive for normal PR gates. |

The synthetic generator should cover four request classes: exact repeat, same
agent with a new user request, same agent continuing its current branch, and
different agent instance sharing the same system/tools prefix. Each class
should record `cache_n`, restore miss reason, namespace or preparation id,
prompt checksum, first-user boundary, checkpoint create/erase counts, cold
bytes, cold write failures, and HTTP 500 / bad_alloc counts.

After a cold disk budget option exists, add one disk-pressure row with a small
cold limit. The expected result is bounded eviction or skipped demotion with a
bounded diagnostic, not filesystem write failure.

## Errors and warnings

| Category | Count | Notes |
| --- | ---: | --- |
| `n_ctx_seq < n_ctx_train` | 11 | Expected informational warnings during context setup |
| Jinja empty-message exceptions | 21 | Marker-detection probes; recovered by fallback path |
| Erased invalidated context checkpoint | 27 | Runtime checkpoint invalidation as prompts change |
| Cold-store target write failure | 18 error lines | Starts at 92:33.486 |
| Demotion failed, reverting to hot | 9 error lines | Follows cold write failures |
| Host memory allocation failure | 4 request pairs plus response logs | Produces all 4 HTTP 500 responses |
| Task cancellation warnings | 4 | Follow scheduling failures |

The four HTTP 500 responses are all `Host memory allocation failed during task
scheduling: bad allocation`. Each failure pair follows a preceding slot-update
allocation failure in the same request cluster:

| Time | Failed phase | Request result |
| --- | --- | --- |
| 43:59.356 / 44:16.818 | slot update, then task scheduling | 500 at 44:16.819 |
| 122:24.592 / 122:24.597 | slot update, then task scheduling | 500 at 122:24.598 |
| 129:59.715 / 129:59.721 | slot update, then task scheduling | 500 at 129:59.721 |
| 137:42.140 / 137:42.145 | slot update, then task scheduling | 500 at 137:42.145 |

The cold-store write failures start before the later host allocation failures,
but not before the first allocation failure at 43:59. The first allocation
failure happens under heavy cache pressure and large prompt state. Later
failures likely combine the same pressure with failed demotions that keep
payloads hot.

## Findings

| ID | Severity | Finding | Evidence | Action |
| --- | --- | --- | --- | --- |
| LOG-16-01 | INFO | The Stage 16 missing-boundary warning is absent in this workload. | 0 `checkpoint admission skipped`; 0 `missing checkpoint boundary metadata`. | Treat the prior boundary bug as not reproduced in this log. |
| LOG-16-02 | BLOCKING for reuse | No public cache reuse occurred. | 19/19 restore lookups missed; 15/15 successful responses have `cache_n = 0`. | Investigate prompt identity and namespace drift across chat requests. |
| LOG-16-03 | HIGH | Checkpoints are created, then almost all are invalidated by the next task. | 28 created, 27 erased as invalidated. | Compare prompt metadata and rendered prompt checksum between consecutive requests. |
| LOG-16-04 | HIGH | Cold-store writes fail after the cache grows. | 18 cold write-failure error lines; payload ids 15, 17-24 fail. | Check free space, permissions, path `t:\llama-cache`, and partial-file cleanup. |
| LOG-16-05 | HIGH | Host memory allocation failures produce all 500s. | 4 request failures, each with slot-update and scheduling bad_alloc lines. | Reproduce with cold-store health fixed; then size cache RAM and request concurrency. |
| LOG-16-06 | INFO | `n_ctx_seq` and Jinja empty-message errors look non-fatal. | Server continues after both; requests process normally. | Keep as noise unless count changes after code or template changes. |
| LOG-16-07 | HIGH | Cold storage needs an explicit disk budget and LRU integration. | Cold writes fail only after the filesystem refuses target bytes. | Add a CLI cold-byte limit and evict or skip demotion before write failure. |
| LOG-16-08 | MEDIUM | Checkpoint density looks too high for this agentic run. | 28 checkpoints created, 27 erased; many positions are close together. | Test a semantic two-snapshot policy plus checkpoint-dependent fallback. |
| LOG-16-09 | MEDIUM | Existing prompt logging can collect stronger evidence. | `--log-prompts-dir` writes raw prompt files; current log only shows metadata. | Pair raw prompt files with bounded hash/token diagnostics. |

## Architectural interpretation

The controlled Stage 16 QA rerun proved that identical short MTP chat requests
can admit a checkpoint and restore `cache_n = 11` on every repeated request.
This long user workload exercises a different condition: large live prompts
whose rendered chat content and namespace change between requests. The cache
stores entries, but subsequent requests do not match them exactly.

The report therefore does not challenge the Stage 16 closure result. It adds
new evidence for the next investigation: cache effectiveness for real agentic
chat sessions depends on stable prompt identity across turns or on a prefix
restore path that can reuse earlier prompt prefixes when the final user turn
changes.

## Recommended follow-up

1. Add bounded diagnostics for restore miss reason: namespace mismatch, token
   count mismatch, checksum mismatch, or exact-entry absence.
2. For consecutive requests in this log, capture preparation id, namespace,
   token span checksum, prompt token count, and boundary count at save and
   restore lookup.
3. Re-run after confirming `t:\llama-cache` has enough space and write
   permissions, so cold demotion can be separated from prompt identity issues.
4. If exact restore is not expected across agentic multi-turn prompts, define
   the intended prefix-restore behavior and metrics for this workload.
5. Add a cold disk budget CLI option and make eviction account for cold bytes,
   not only hot RAM bytes.
6. Run a checkpoint policy experiment with `--ctx-checkpoints` and
   `--checkpoint-min-step`, comparing the current dense behavior against a
   semantic policy that saves before the first user branch point and at final
   inference state.
7. Capture future repros with `--log-prompts-dir` plus `--log-file`, then add
   a redacted hash/token evidence mode for runs where raw prompt capture is
   not allowed.
8. Add QA rows for the three-tier reproduction path: synthetic stress,
   Stage 12/15 stress-longrun extension, and heavy manual/nightly reproduction.
