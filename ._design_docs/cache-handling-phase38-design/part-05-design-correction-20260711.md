# Stage 38 design correction: review blockers

Source: [../cache-handling-phase38-design.md](../cache-handling-phase38-design.md)
Review source: [part 04](part-04-design-review-20260711.md)

Date: 2026-07-11
Owner: Architect

## Scope

This correction only closes the two blocking findings from the independent
Stage 38 design review. It does not change production code, tests, scripts, or
the cold-budget gauge design.

## F38-DESIGN-01 resolution

Stage 38 excludes `/completion` prefix restore.

The supported Stage 38 restore path remains `/v1/chat/completions` and the
shared cache-controller paths used by it. If a `/completion` request produces a
strict-prefix token-position candidate, the implementation must reject prefix
restore for that candidate and recompute the prompt. It should record a bounded
unsafe or fallback reason, but it must not attempt partial slot apply.

This keeps fallback metadata on the fail-safe side of R34-R36d and R90-R92. A
future stage can add `/completion` support only with a route-specific boundary
contract, validation rules, and tests.

Required doc changes made:

- Part 1 now states that `/completion` token-position candidates are unsafe in
  Stage 38.
- Part 3 now closes the open question and adds TP-38-PR-10 for recompute
  behavior.
- The entry document lists `/completion` prefix restore as out of scope.

## F38-DESIGN-02 resolution

Public prompt-token totals stay unchanged.

After an accepted partial restore, only cache-specific fields report the
restored prefix length:

- `slot.n_prompt_tokens_cache`
- `timings.cache_n`
- `usage.prompt_tokens_details.cached_tokens`

OpenAI-compatible total prompt-token fields, including `usage.prompt_tokens`,
must still report the full request prompt length. The suffix token count is
internal work evidence only. Tests may use it to prove that recompute work was
reduced, but it is not a replacement for public prompt totals.

Required doc changes made:

- Part 3 now separates cache-specific restored-prefix fields from public total
  prompt-token fields.
- Part 3 now states that suffix length may be diagnostic evidence only.

## Handoff

Handoff state: ready for independent design re-review.

Developer implementation planning remains blocked until the re-review records
PASS and Manager approves the design gate.
