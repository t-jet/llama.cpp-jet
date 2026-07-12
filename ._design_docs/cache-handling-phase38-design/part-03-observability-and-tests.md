# Stage 38 design: observability and tests

Source: [../cache-handling-phase38-design.md](../cache-handling-phase38-design.md)

## Metrics and logs

Prefix metrics must use bounded labels. Required rows:

| Metric | Type | Labels | Meaning |
| --- | --- | --- | --- |
| `llamacpp:cache_prefix_candidates_total` | counter | `result`, `reason` | Prefix candidates accepted or rejected. |
| `llamacpp:cache_restore_misses_total` | counter | `reason`, `profile`, `pair_state` | Rejected prefix and fallback reasons. |
| `llamacpp:cache_hits_total` | counter | `mode` | Accepted partial restores count as cache hits only after apply succeeds. |
| `llamacpp:cache_checkpoint_hits_total` | counter | existing bounded labels | Accepted checkpoint prefix restores for checkpoint profiles. |
| `llamacpp:cache_cold_budget_bytes` | gauge | `mode` | Configured cold budget bytes, fixed for 64-bit positive values. |

Recommended prefix reasons:

- `accepted_strict_prefix`
- `checksum_mismatch`
- `namespace_mismatch`
- `pair_state_mismatch`
- `semantic_boundary_mismatch`
- `prefix_not_checkpoint_safe`
- `payload_unavailable`
- `generated_output_replay_blocked`

Logs should name the bounded reason, profile, pair state, restored token count,
request token count, and payload residency. Logs must not include prompt text,
raw namespace ids, raw descriptor ids, or filesystem paths beyond existing cold
store startup logging rules.

## Reporting

After accepted partial restore:

- `slot.n_prompt_tokens_cache` equals accepted prefix length.
- `timings.cache_n` equals accepted prefix length.
- Chat `usage.prompt_tokens_details.cached_tokens` equals accepted prefix
  length.
- Public total prompt-token fields, including OpenAI-compatible
  `usage.prompt_tokens`, remain the full request prompt length.
- The suffix token count is internal work evidence only. It may be logged or
  exposed in test diagnostics, but it must not replace public prompt totals.

Rejected candidates report `cached_tokens = 0` unless an exact restore succeeds
through the existing path.

## Regression coverage

Focused tests must cover:

| Row | Scenario | Expected result |
| --- | --- | --- |
| TP-38-PR-01 | Exact repeat | Existing exact restore still wins; no behavior regression. |
| TP-38-PR-02 | Safe strict prefix plus new user turn | Partial restore accepted; suffix processed; cached token count equals prefix length. |
| TP-38-PR-03 | Prefix token checksum mismatch | Candidate rejected; recompute; bounded reason recorded. |
| TP-38-PR-04 | Namespace, template, or tool drift | Candidate rejected before payload apply. |
| TP-38-PR-05 | Pair-state mismatch | Candidate rejected; no target-only or draft-only partial restore. |
| TP-38-PR-06 | Checkpoint-dependent or MTP path | Restore only from checkpoint-safe prefix; arbitrary LCP rejected. |
| TP-38-PR-07 | Cold prefix payload | Cold promotion succeeds before apply, or fallback is safe with payload reason. |
| TP-38-PR-08 | Protected branch under pressure | Protected prefix metadata survives according to policy; budgets still enforced. |
| TP-38-PR-09 | No generated-output replay | Prior assistant output is not emitted unless produced by current generation. |
| TP-38-PR-10 | `/completion` strict-prefix candidate | Prefix restore is not attempted; request recomputes with a bounded unsafe/fallback reason. |
| TP-38-MET-01 | Cold budget 2048 MiB | Gauge reports `2147483648`, never negative. |
| TP-38-MET-02 | Cold budget boundary values | `0`, `1`, `2047`, `2048`, `4096`, and `-1` preserve documented meanings. |

At least one model-backed `/v1/chat/completions` row must prove the public
`cached_tokens` path. Controller tests may prove checksum, pair-state,
checkpoint safety, protected branch behavior, and cold-budget boundary math.

## Traceability

| Requirement or prior stage | Stage 38 coverage |
| --- | --- |
| R6, R12, R84-R86 | Checkpoint-dependent profiles restore only from checkpoint-safe points. |
| R9-R10 | Pair-state validation blocks partial target/draft restore. |
| R27-R33 | Prefix restore depends on prepared semantic boundaries. |
| R34-R36d, R90-R92 | Any unsafe prefix candidate falls back safely. |
| R49-R60, R93 | Cold budget gauge matches configured byte budget. |
| R61-R68 | Accepted and rejected prefix outcomes are observable. |
| R80-R83a | Restored prefix nodes remain shared, non-consumed branch objects. |
| Stage 17 | Implements the deferred safe prefix-restore checks from part 2. |
| Stage 36 D36-FU-01 | Fixes the negative 2048 MiB cold-budget gauge. |

## Closed questions

- `/completion` token-position prefix restore is deferred. Stage 38 must
  recompute `/completion` strict-prefix candidates and record a bounded
  unsafe/fallback reason.
- Should accepted partial prefix restores increment only general hit counters,
  or also a new prefix-hit counter? Current design reuses
  `cache_prefix_candidates_total{result="accepted"}` to avoid a new family.

## Handoff state

Design correction is complete for F38-DESIGN-01 and F38-DESIGN-02. Independent
re-review is required before Manager approves Developer planning.
