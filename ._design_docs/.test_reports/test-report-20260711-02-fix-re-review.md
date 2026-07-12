# Stage 38 fix re-review: checkpoint-span prefix validator

Date: 2026-07-12
Owner: Architect
Scope: fresh independent re-review of the Developer fix in
`test-report-20260711-02-fixes.md` against the binding Stage 38 design and
the failing report -02 product bug.
Verdict: PASS

## Inputs reviewed

- `AGENTS.md`
- `.agents/skills/architect/SKILL.md`
- `.agents/skills/self-improvement/SKILL.md` + `assets/architect.md`
- `.agents/skills/humanizer/SKILL.md`
- `.agents/skills/caveman/SKILL.md`
- `._design_docs/cache-handling-phase38-design.md`
- `._design_docs/cache-handling-phase38-design/part-01-prefix-checkpoint-partial-restore.md`
- `._design_docs/cache-handling-phase38-implementation/part-06-implementation-re-review-20260711.md`
- `._design_docs/.test_reports/test-report-20260711-02.md`
- `._design_docs/.test_reports/test-report-20260711-02-developer-review.md`
- `._design_docs/.test_reports/test-report-20260711-02-fixes.md`
- Live diff: `git diff -w -- tools/server/ tests/`
- Live code: `tools/server/server-cache-hybrid.cpp`, `tools/server/server-cache-hybrid.h`,
  `tests/test-cache-controller.cpp`, and the untracked script
  `._design_docs/cache-handling-test-scripts/stage38-prefix-restore-and-cold-budget.ps1`

No code, tests, scripts, the fixes file, the phase design, or
`document-index.md` were edited. No tests were executed.

## Root cause confirmation

Report -02 showed turn 1 rendered tokens are a strict prefix of turn 2, yet
the live server rejected the checkpoint-dependent candidate as
`unsafe_prefix_rejected` with `cached_tokens=0`. The pre-fix `tx_restore`
replaced every partial-length match with a hard-coded
`cache_restore_miss_reason::unsafe_prefix_rejected` and never reached a
validator, so even a checkpoint-safe candidate was rejected before apply.

The fix replaces that hard-coded rejection with a real call to
`validate_strict_prefix_candidate`, and the validator now keys the accepted
prefix length off `restored_token_count_for_payload(entry, selected_payload_kind)`
rather than the entry's full prompt length. For a checkpoint payload
`restored_token_count_for_payload` returns `descriptor.token_span_end`, i.e.
the checkpoint span, not the full entry length. In the live run the saved
entry carried 35 prompt tokens and a checkpoint descriptor for 11 tokens; the
validator now checks the 11-token span, not the 35-token boundary.

A second gap is closed in the same validator: checkpoint descriptors can
back checkpoint-safe spans that are not `MESSAGE_END` boundaries. The
validator's checkpoint branch accepts a descriptor span/checksum match
without requiring `MESSAGE_END`, while the exact-blob branch keeps the
stricter `MESSAGE_END` boundary check.

## Review checklist

| # | Item | Verdict | Evidence |
| --- | --- | --- | --- |
| 1 | Fix root-cause correctness | PASS | `tx_restore` at `tools/server/server-cache-hybrid.cpp:5427-5438` now computes `selected_payload_kind` via `select_restore_payload_kind(*it_best, profile)` and calls `validate_strict_prefix_candidate` instead of hard-coded reject. `validate_strict_prefix_candidate` at `:2102` sets `prefix_tokens = restored_token_count_for_payload(entry, selected_payload_kind)`. `restored_token_count_for_payload` at `:1914-1934` returns `descriptor.token_span_end` for checkpoint payloads. This admits the 11-token checkpoint span that report -02 wrongly rejected. Unchecked arbitrary LCP matches still fail the descriptor span/checksum gate below, so unsafe matches are not admitted. |
| 2 | Strict-prefix invariant preserved | PASS | Validator at `:2112-2117` requires `common_prefix_tokens >= prefix_tokens` (`entry.tokens.get_common_prefix(task.tokens)`), else `checksum_mismatch`. Positive: `test_stage38_checkpoint_prefix_uses_checkpoint_span` (`tests/test-cache-controller.cpp:3623-3664`) admits a 3-token checkpoint span inside a 5-token entry against a 7-token request. Negative: entry_ids/request_ids share only the checkpoint span; any divergence at positions 0-2 trips `get_common_prefix` or the descriptor checksum gate. |
| 3 | Binding constraints held | PASS | See constraints-held table below. |
| 4 | Regression test adequacy | PASS | `test_stage38_checkpoint_prefix_uses_checkpoint_span` uses a longer entry (5 tokens) with a shorter checkpoint descriptor (3 tokens) and a non-`MESSAGE_END` (`SYSTEM_END`) checkpoint-safe boundary. Under the old full-entry rule `restored_token_count_for_payload` returned 5, `prefix_tokens > entry.n_tokens()` is false but `common_prefix_tokens(5) < 5` is false and the `MESSAGE_END` boundary check then failed, so the old path rejected. The new span rule returns 3 and the descriptor gate accepts. The test fails under old, passes under new, and guards the span rule. |
| 5 | No new correctness gap from non-MESSAGE_END checkpoint boundary | PASS | `attach_checkpoint_payload` at `tools/server/server-cache-hybrid.cpp:3918-3956` RECOMPUTES `descriptor.boundary_checksum = cache_token_span_checksum(entry.tokens, span_start, span_end)` from cached entry bytes, never from request-supplied boundary metadata. The validator recomputes `prefix_checksum` from `entry.tokens` and `request_prefix_checksum` from `task.tokens` and requires `descriptor.boundary_checksum == prefix_checksum == request_prefix_checksum`. A non-prefix request cannot satisfy the request-side recompute. Descriptor existence and `token_span_start==0 && token_span_end==prefix_tokens && boundary_checksum!=0` are all checked. Exact-blob branch keeps `MESSAGE_END`. |
| 6 | Live evidence credibility | PASS | Fix report table records `cached_tokens=11`, `timings.cache_n=11`, `prompt_tokens=63`, hybrid hit delta `1`, `cache_prefix_candidates_total{...,result="accepted",reason="accepted_strict_prefix"} 1`, `cache_checkpoint_restores_total{...,result="success"} 1`, `cache_checkpoint_hits_total{...} 1`, and gauge `2147483648`. Server log shows `try_restore - successfully restored 11 tokens` and `restore-apply slot=3 restored_tokens=11`. These values are internally consistent (restored 11 of 63, public total unchanged) and reflect real reuse, not cosmetic output. |
| 7 | Durable-doc requirement | PASS (no copy needed) | part-01 already permits "a checkpoint descriptor whose boundary checksum validates against the requested prefix" and lists "checkpoint-safe boundary selected by the checkpoint policy" as an approved boundary. The checkpoint-span rule is a refinement of that existing design clause, not a new behavior. part-06 implementation re-review already records the validator call site, pair-state threading, and the checkpoint-or-recompute gate. No behavior change stranded only in the `-fixes.md`. |

## Constraints-held table

| Binding constraint | Status | Evidence |
| --- | --- | --- |
| `/completion` prefix restore out of scope, must recompute | HELD | Validator at `tools/server/server-cache-hybrid.cpp:2105-2107` returns `unsafe_prefix_rejected` when `task.prompt_metadata.diagnostic_source != "openai-chat"`. `/completion` does not set `openai-chat`. `test_stage38_completion_strict_prefix_recomputes` still covers this. |
| Public prompt-token totals stay full request length | HELD | No production schema field reporting `n_prompt_tokens` was changed. `usage.prompt_tokens==63` in the live row while `cached_tokens==11`, confirming public total stays full length and only cache-specific fields report the restored span. |
| Only cache-specific fields report restored prefix length | HELD | Restored prefix flows through `slot.n_prompt_tokens_cache`, `timings.cache_n`, and `usage.prompt_tokens_details.cached_tokens`. No new public field added. |
| Checkpoint-dependent, SWA, recurrent, RS-limited, target-plus-draft, and MTP restore checkpoint-safe only | HELD | Validator gate at `:2150-2155` returns `unsafe_prefix_rejected` for `checkpoint_dependent` profiles or `target_and_draft` pair state when `selected_payload_kind != checkpoint`. Exact-blob prefixes for these runtimes still recompute. |
| Correctness over hit rate | HELD | Every validator failure path returns a bounded miss reason and reaches the normal recompute path via `tx_restore` (`n_misses++; record_restore_miss(...); return response`). No silent accept on validation gap. |

## Findings

None blocking.

Non-blocking: the `debug_validate_strict_prefix_for_tests` hook can exercise
the checkpoint-span gate without a live draft context, which is the same
test-only hook pattern already accepted in part-06 for F38-IMPL-01. It reuses
`find_equivalent_entry`/`find_best_match` and calls the production validator,
so it is not a parallel reimplementation.

## Fix root-cause verdict

Correct. Span-validation admits safe candidates because the accepted prefix
length now follows the selected payload's checkpoint span
(`descriptor.token_span_end`) instead of the full entry length. The live
35-token entry with an 11-token checkpoint descriptor is now evaluated at the
11-token span. It blocks unsafe candidates because the descriptor gate
requires `token_span_start==0`, `token_span_end==prefix_tokens`, a nonzero
`boundary_checksum`, three-way checksum equivalence across descriptor, cached
entry span, and request span, and the `common_prefix_tokens >= prefix_tokens`
token-equality check. Arbitrary LCP matches that are not backed by a real
checkpoint descriptor fail one of these gates and recompute.

## Regression-test verdict

Adequate. `test_stage38_checkpoint_prefix_uses_checkpoint_span` covers the
root cause (longer entry, shorter checkpoint span, non-`MESSAGE_END`
checkpoint-safe boundary) and fails under the old full-entry/MESSAGE_END-only
validator. Negative coverage is provided by the existing
`test_stage38_completion_strict_prefix_recomputes`,
`test_stage38_prefix_boundary_checksum_rejects`,
`test_stage38_pair_state_mismatch_rejects_prefix`,
`test_stage38_target_draft_prefix_requires_checkpoint_safe`, and
`test_stage38_generated_output_never_replayed` rows.

## Durable-doc requirement

No copy needed. The phase38 design part-01 already permits checkpoint-descriptor
prefix restore, and part-06 records the validator mechanism, call site, and
constraint-held table. The fix is a correct refinement of those clauses, not a
new behavior that would strand durable changes only in the fixes report.

## Verdict

PASS. Fix root cause is correct, strict-prefix invariant preserved, all five
binding constraints held, regression test adequate, live evidence credible,
no new correctness gap.

Next owner: Manager (gate decision).
