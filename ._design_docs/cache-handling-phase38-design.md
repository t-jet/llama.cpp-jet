# Stage 38 design entry: prefix/checkpoint partial restore and cold-budget gauge fix

Status: Manager design gate PASS, implementation planning open
Date: 2026-07-11
Stage: 38
Owner: Architect
Source brief: [.manager-inputs/manager-input-20260711-stage38-prefix-checkpoint-partial-restore.md](.manager-inputs/manager-input-20260711-stage38-prefix-checkpoint-partial-restore.md)

## Goal

Stage 38 has two scoped fixes:

1. Turn safe strict-prefix cache candidates into partial-prompt restores.
2. Fix `cache_cold_budget_bytes{mode="hybrid"}` so a 2048 MiB budget reports
   `2147483648` bytes, not `-2147483648`.

The prefix work is limited to strict-prefix cases where the cache can prove the
restored state exactly matches the requested prompt prefix. The server must then
process only the suffix prompt tokens. It must not replay generated output.

## Contents

- [Part 1: prefix and checkpoint partial restore](cache-handling-phase38-design/part-01-prefix-checkpoint-partial-restore.md)
- [Part 2: cold-budget gauge fix](cache-handling-phase38-design/part-02-cold-budget-gauge-fix.md)
- [Part 3: observability and tests](cache-handling-phase38-design/part-03-observability-and-tests.md)
- [Part 4: design review 2026-07-11](cache-handling-phase38-design/part-04-design-review-20260711.md)
- [Part 5: design correction 2026-07-11](cache-handling-phase38-design/part-05-design-correction-20260711.md)
- [Part 6: design re-review 2026-07-11](cache-handling-phase38-design/part-06-design-re-review-20260711.md)
- [Part 7: Manager design gate 2026-07-11](cache-handling-phase38-design/part-07-manager-design-gate-20260711.md)

## Scope

In scope:

- Hybrid cache mode only.
- `/v1/chat/completions` and shared cache-controller paths used by it.
- Strict-prefix restore for same namespace, same pair state, same rendered
  prefix tokens, and compatible semantic boundaries.
- Checkpoint-dependent, SWA, recurrent, RS-limited, target-plus-draft, and MTP
  profiles only at checkpoint-safe restore points.
- Hot and cold payload residency, including inline cold promotion.
- Correct `n_prompt_tokens_cache`, `timings.cache_n`, and chat
  `usage.prompt_tokens_details.cached_tokens` after partial restore.
- Cold-budget gauge emission and stats plumbing for values above signed
  32-bit range.

Out of scope:

- Legacy cache behavior.
- `/completion` prefix restore. Stage 38 treats `/completion` token-position
  candidates as unsafe and falls back to recompute.
- Generated-output replay or output memoization.
- Arbitrary offset restore.
- Cross-namespace, cross-template, cross-tool, adapter, media, or draft-mode
  reuse.
- New public request fields or cache inspection endpoints.
- Broad metric renames beyond the cold-budget gauge fix.

## Prerequisites

- Stage 35 is closed PASS after upstream merge.
- Stage 36 is closed PASS and supplies D36-FU-01 as the cold-budget gauge
  follow-up source.
- Stage 17 prefix policy remains binding: unsafe prefix candidates fall back
  unless the full validation set is implemented.
- Architecture Part 2 restore order, Part 5 protected roots, Part 6 pair-state
  rules, and Part 9 chat prompt-span boundary invariant remain binding.
- Stage 25 atomic `tx_*` lifecycle remains binding. Restore planning and cold
  promotion happen under the cache mutex; live slot apply happens outside it.

## Assumptions

- Correctness beats hit rate. Any validation gap returns to recompute.
- `cached_tokens` means prompt tokens restored from cache, not generated tokens.
- Prefix restore may update usage and residency for the restored prefix node,
  but suffix processing owns any new branch materialization.
- Unlimited cold budget (`-1`) keeps its existing documented meaning.

## Interfaces

Developer may add or extend internal structs, but the public behavior must look
like this:

- Restore plan carries `restored_token_count` that may be less than prompt size.
- Slot apply sets `slot.n_prompt_tokens_cache` to the restored prefix length.
- The normal prompt loop starts at `restored_token_count` and processes suffix
  tokens normally.
- Metrics expose accepted/rejected prefix outcomes with bounded labels.
- Cold-budget stats carry a 64-bit signed or unsigned value through JSON and
  Prometheus emission without narrowing to `int32_t`.

## Handoff

Next owner: Developer.

Next gate: implementation planning.
