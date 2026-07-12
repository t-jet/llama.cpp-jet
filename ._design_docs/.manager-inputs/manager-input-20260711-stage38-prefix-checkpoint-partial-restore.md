# Manager input - Stage 38 prefix/checkpoint partial restore

MANAGER INPUTS - NOT AN APPROVED DESIGN

This Manager intake brief opens Stage 38 on 2026-07-11 as pre-design authority
only. It records the user directive and evidence for Architect design handoff.
It does not approve a design, implementation plan, code change, test plan, or
runtime behavior change.

## User directive

The user directed Architect to perform only the durable stage-opening
documentation update for Manager intake, not to design the feature, edit code,
run builds/tests, overwrite dirty work, or revert existing changes.

The requested stage objective is:

> implement prefix/checkpoint partial restore for agentic workloads. Turn safe
> `unsafe_prefix_rejected` strict-prefix cases into real partial-prompt hits for
> `same prefix + new user turn` workloads.

## Stage numbering

Stage 37 is a reserved chat-only candidate for the cold-store budget metric
mismatch unless the user drops or supersedes it. No durable Stage 37 was opened
on disk at intake, so this durable intake uses Stage 38.

## Intake gate state

Stage intake: PASS.

Active gate: Design.

Next owner: Architect.

## Evidence at intake

Live server repeated approximately 27k-token prompts with:

- `n_prompt_tokens_cache=0`
- `llamacpp:cache_hits_total{mode="hybrid"}=0`
- `cache_restore_misses_total{reason="unsafe_prefix_rejected",profile="checkpoint_dependent",pair_state="target_only"}=2`
- `cache_prefix_candidates_total{result="rejected",reason="prefix_restore_deferred"}=2`

This evidence indicates strict-prefix candidates are observed but deferred and
rejected instead of producing safe partial-prompt reuse.

## Required design scope

Architect design must cover:

- Strict-prefix restore plan.
- Namespace, pair-state, and token checksum validation.
- Semantic boundary validation.
- Checkpoint-dependent and sliding-window/SWA profiles must restore only from
  checkpoint-safe points, not arbitrary offsets.
- Suffix processing after restored prefix.
- Correct `n_prompt_tokens_cache` and `cached_tokens` reporting.
- Accepted and rejected prefix metrics and logs.
- Cold/hot residency and protected branch behavior.
- Regressions for exact repeat, safe prefix hit, checksum mismatch,
  namespace/template/tool drift, checkpoint-dependent path, and no
  generated-output replay.

## Source anchors

- `tools/server/server-cache-hybrid.cpp:2002` `find_prefix_candidate()`
- `tools/server/server-cache-hybrid.cpp:5035` `tx_load` non-exact rejection
- `tools/server/server-cache-hybrid.cpp:5312` `tx_restore` exact-length rejection
- Stage 17 design part 02 prefix candidates deferred as
  `unsafe_prefix_rejected`

## Handoff

Next owner: Architect.

Next gate: Stage 38 design.

This file is pre-design authority only. The design must decide the actual
restore algorithm, validation details, metrics contract, and regression scope
before any implementation work starts.
