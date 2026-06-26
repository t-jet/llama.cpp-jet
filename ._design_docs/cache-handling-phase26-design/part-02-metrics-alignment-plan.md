# Part 2: Metrics alignment plan

Status: design draft
Date: 2026-06-25
Stage: 26 (Metrics Alignment + Stage 24/25 Carry-Over Resolution)
Author: Architect
Scope: rename `llamacpp_X` to `llamacpp:X`, fix duplicate `mode`
label, update fixture scripts.

## Current state (survey)

Prometheus cache metrics are emitted in
`tools/server/server-context.cpp` lines 4344..4687. Two naming styles
are in use:

- `llamacpp_X`: 37 metrics. Example: `llamacpp_cache_entries` at
  line 4399. Per upstream llama.cpp convention (line 4336..4338 for
  the existing token / decode metrics), the canonical prefix uses a
  colon: `llamacpp:X`.
- `cache_X` (no prefix): 30 metrics. Example:
  `cache_branch_nodes_created_total` at line 4411. These are also
  cache-related metrics and need the `llamacpp:` prefix to land in
  the same namespace as upstream llama.cpp.

The Prometheus scraper error
`label name "mode" is not unique: invalid sample` originates from
`cache_prompt_evidence_records_total` at line 4537. The
`write_cache_metric_with_two_labels` helper at lines 4359..4368
already prepends `{mode="..."}` to the label list, but the caller at
line 4537 explicitly passes `"mode"` as the first label name, so the
emitted series carries `{mode="<from_helper>",mode="<from_caller>"}`
which Prometheus rejects.

## Metric inventory (rename map)

All 37 `llamacpp_X` -> `llamacpp:X` renames (lines from
`tools/server/server-context.cpp`):

| Line | Old name | New name |
| ---: | --- | --- |
| 4399 | `llamacpp_cache_entries` | `llamacpp:cache_entries` |
| 4400 | `llamacpp_cache_bytes` | `llamacpp:cache_bytes` |
| 4401 | `llamacpp_cache_tokens` | `llamacpp:cache_tokens` |
| 4402 | `llamacpp_cache_hits_total` | `llamacpp:cache_hits_total` |
| 4403 | `llamacpp_cache_misses_total` | `llamacpp:cache_misses_total` |
| 4404 | `llamacpp_cache_evictions_total` | `llamacpp:cache_evictions_total` |
| 4405 | `llamacpp_cache_payload_evictions_total` | `llamacpp:cache_payload_evictions_total` |
| 4406 | `llamacpp_cache_protected_root_decisions_total` | `llamacpp:cache_protected_root_decisions_total` |
| 4407 | `llamacpp_cache_restore_failures_total` | `llamacpp:cache_restore_failures_total` |
| 4408 | `llamacpp_cache_descriptor_validation_failures_total` | `llamacpp:cache_descriptor_validation_failures_total` |
| 4409 | `llamacpp_cache_pairing_violations_total` | `llamacpp:cache_pairing_violations_total` |
| 4410 | `llamacpp_cache_fallback_restores_total` | `llamacpp:cache_fallback_restores_total` |
| 4479 | `llamacpp_cache_hot_payload_descriptors` | `llamacpp:cache_hot_payload_descriptors` |
| 4480 | `llamacpp_cache_evicted_payload_descriptors` | `llamacpp:cache_evicted_payload_descriptors` |
| 4482 | `llamacpp_cache_payload_demotions_total` | `llamacpp:cache_payload_demotions_total` |
| 4483 | `llamacpp_cache_payload_demotion_failures_total` | `llamacpp:cache_payload_demotion_failures_total` |
| 4484 | `llamacpp_cache_payload_promotions_total` | `llamacpp:cache_payload_promotions_total` |
| 4485 | `llamacpp_cache_payload_promotion_failures_total` | `llamacpp:cache_payload_promotion_failures_total` |
| 4486 | `llamacpp_cache_payload_cold_evictions_total` | `llamacpp:cache_payload_cold_evictions_total` |
| 4487 | `llamacpp_cache_demotion_queue_full_total` | `llamacpp:cache_demotion_queue_full_total` |
| 4488 | `llamacpp_cache_promotion_queue_full_total` | `llamacpp:cache_promotion_queue_full_total` |
| 4489 | `llamacpp_cache_cold_payload_bytes` | `llamacpp:cache_cold_payload_bytes` |
| 4490 | `llamacpp_cache_cold_payload_count` | `llamacpp:cache_cold_payload_count` |
| 4560 | `llamacpp_cache_protected_root_demotions_total` | `llamacpp:cache_protected_root_demotions_total` |
| 4562..4569 | `llamacpp_cache_promotion_latency_bucket_*` (8) | `llamacpp:cache_promotion_latency_bucket_*` |
| 4571..4576 | `llamacpp_cache_promotion_failure_*_total` and `llamacpp_cache_demotion_failure_*_total` (5) | `llamacpp:cache_promotion_failure_*_total` and `llamacpp:cache_demotion_failure_*_total` |

All 30 `cache_X` -> `llamacpp:cache_X` renames (lines 4411..4687;
specific list kept in the implementation plan).

Total: 37 + 30 = 67 metrics renamed to `llamacpp:` prefix.

## Label conflict fix

`cache_prompt_evidence_records_total` at line 4537. The caller passes
`("mode", "off", "result", "none", 0)` as label_a_name / value and
label_b_name / value. The helper already prepends `{mode="<from stats>"}`
which collides with the explicit `"mode"`.

Two options:

1. Drop the redundant `"mode"` argument so the metric has labels
   `{mode, result}` and the existing helper signature handles it. This
   makes the second label value carry the prompt-evidence-specific
   "off" / "redacted" / "ok" value via the "result" label, which loses
   the prompt-evidence-specific mode field.
2. Rename the redundant `"mode"` argument to `"scope"` (or
   `"evidence_mode"`). The emitted series becomes
   `{mode="hybrid",scope="off",result="none"}`. Prometheus is happy
   because `mode` appears once.

Choose option 2 because the JSON stats payload has both a top-level
`mode` field (cache mode) and a per-record `mode` field (prompt-
evidence-specific). The current call passed that per-record field as
a Prometheus label called "mode" which is the source of the
collision. Renaming to `scope` preserves the data and resolves the
collision.

## Backward compatibility

Metrics are a public API consumed by Prometheus scrapers and dashboards.
Recommendation: HARD RENAME with breaking-change note in the
implementation log. Reasons:

- `llamacpp_X` is non-standard for the upstream llama.cpp convention.
  Operators writing scrapers against upstream have to special-case
  the underscore form.
- The 10 references to `llamacpp_cache_.*` regex in
  `execute_tests.ps1` (lines 188, 218, 248, 1186, 1238, 1293, 1357,
  1470, 1529, 1533) and the 10 metric-name references in the
  `MetricNames` array of `stage24-chat-s02-s03-comparison.ps1` (lines
  30..39) are updated in this stage. Adding aliases doubles the
  surface for Prometheus scrapers without a clear benefit.
- The fix is the same code change count (rename), so aliases would
  add lines without removing any.

## Fixture script updates

- `execute_tests.ps1`: 10 metric-name regex updates. Replace
  `llamacpp_cache_.*` with `llamacpp:cache_.*`.
- `stage24-chat-s02-s03-comparison.ps1`: 10 metric-name references in
  the `MetricNames` array (lines 30..39). Replace each `cache_X`
  entry with its `llamacpp:cache_X` form. All 10 entries are covered
  by the 30-group rename map (`cache_X` -> `llamacpp:cache_X`)
  declared in this part. Also add a metrics-format assertion in the
  runner summary that scans for `llamacpp_` (underscore) and fails
  the leg if found.
- Add a label-uniqueness assertion: the runner greps for
  `,mode="..."` appearing twice in any single line; if found, the leg
  fails with `label-conflict`.

## Handoff

Part-02 is reviewable. The metric rename map and the `scope` rename
for `cache_prompt_evidence_records_total` are the binding contracts.
Implementation plan part-06 sequences the renames before any fixture
script change so the binary emits the new names first, then the
fixture scripts can match.
