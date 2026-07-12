VERDICT: REWORK

# Stage 38 design review: prefix partial restore and cold-budget gauge

Date: 2026-07-11
Reviewer: Architect
Scope: independent design review only

## Inputs reviewed

- `AGENTS.md`
- `.agents/skills/architect/SKILL.md`
- `.agents/skills/humanizer/SKILL.md`
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-stage-tracker.md`
- `._design_docs/.manager-inputs/manager-input-20260711-stage38-prefix-checkpoint-partial-restore.md`
- `._design_docs/cache-handling-phase38-design.md`
- `._design_docs/cache-handling-phase38-design/part-01-prefix-checkpoint-partial-restore.md`
- `._design_docs/cache-handling-phase38-design/part-02-cold-budget-gauge-fix.md`
- `._design_docs/cache-handling-phase38-design/part-03-observability-and-tests.md`
- `._design_docs/cache-handling-architecture.md`
- `._design_docs/cache-handling-architecture/part-02-restore-and-residency-flow.md`
- `._design_docs/cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md`
- `._design_docs/cache-handling-architecture/part-06-stage-5-draft-context-modes-and-pairing.md`
- `._design_docs/cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md`
- `._design_docs/cache-handling-requirements.md`
- `._design_docs/cache-handling-requirements/part-01-status.md`
- `._design_docs/cache-handling-requirements/part-02-fully-slot-independent-shared-reuse.md`
- Stage 17 design entry and parts 1-4
- Stage 36 design entry and Manager closure part 7
- Focused source anchors in `tools/server/server-cache-hybrid.cpp`,
  `tools/server/server-context.cpp`, and `tools/server/server-slot.h`

## Scope decision

Stage 38 correctly includes both user-directed items:

- safe strict-prefix/checkpoint partial restore for same-prefix plus new-user-turn
  agentic workloads;
- D36-FU-01 cold-budget gauge correction for the 2048 MiB negative value.

The review cannot pass yet because two design decisions are still unclear in
the candidate docs.

## Blocking findings

### F38-DESIGN-01: `/completion` fallback policy is still open

Part 1 allows token-position prefix restore for `/completion` fallback metadata
only if design review accepts it as deterministic. Part 3 repeats the question
as open. That leaves Developer with a policy choice after design review.

Stage 38 scope is centered on `/v1/chat/completions` and the shared controller
paths used by it. Requirements R32-R33 allow token fallback when metadata is
degraded, but R34-R36d and R90-R92 require fail-safe behavior. The design must
make the decision now: either exclude `/completion` prefix restore from Stage 38
and classify it as unsafe, or include it with exact validation rules and tests.

Required correction: update parts 1 and 3 to close the `/completion` fallback
decision. If included, add acceptance coverage for deterministic token-position
restore. If excluded, say it always falls back in Stage 38.

### F38-DESIGN-02: public prompt-token accounting can be read as suffix-only

Part 3 says prompt input token count represents only suffix tokens still
processed by the normal prompt path where response schemas expose that split.
That wording is unsafe for OpenAI-compatible reporting. Public prompt token
counts must continue to describe the full request prompt. Only cache-specific
fields should report the restored prefix length:

- `slot.n_prompt_tokens_cache`
- `timings.cache_n`
- `usage.prompt_tokens_details.cached_tokens`

The suffix length is an internal prefill-work count, not a replacement for
public `prompt_tokens` or task prompt length. A suffix-only public prompt count
would break Stage 32 and Stage 36 comparison evidence and confuse operators.

Required correction: state that public total prompt-token fields remain the full
request prompt length. Stage 38 may add internal evidence for suffix tokens
processed, but it must not change public usage totals.

## Non-blocking observations

- Namespace, pair-state, descriptor integrity, token checksum, semantic
  boundary, and checkpoint-safe constraints match Stage 17 and the architecture
  baseline.
- Suffix processing forbids generated-output replay and keeps final-state save
  on the normal `tx_save` path.
- Hot/cold residency and protected-branch behavior are covered. Cold promotion
  remains inline before live apply, matching the Stage 25 transaction model.
- The cold-budget gauge design covers the likely signed 32-bit narrowing path,
  preserves `-1`, keeps `0`, and requires `1`, `2047`, `2048`, `4096`, `0`, and
  `-1` evidence.
- Prefix metrics use bounded labels. The design correctly treats accepted
  partial restores as hits only after apply succeeds.

## Documentation hygiene

Existing Stage 38 files reviewed are below the 300-line cap:

- entry: 91 lines
- part 1: 119 lines
- part 2: 89 lines
- part 3: 97 lines

This review part is under the cap and uses ASCII-only prose.

## Handoff

Handoff state: re-review required.

Next owner: Architect or design author for Stage 38 design correction.

Developer implementation planning remains blocked until the two blocking
findings are corrected and a fresh design review records PASS.
