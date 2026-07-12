VERDICT: PASS

# Stage 38 design re-review: corrected prefix restore and gauge fix

Date: 2026-07-11
Reviewer: Architect
Scope: independent design re-review only

## Inputs reviewed

- `AGENTS.md`
- `.agents/skills/architect/SKILL.md`
- `.agents/skills/humanizer/SKILL.md`
- `.agents/skills/caveman/SKILL.md`
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-stage-tracker.md`
- `._design_docs/cache-handling-phase38-design.md`
- `._design_docs/cache-handling-phase38-design/part-01-prefix-checkpoint-partial-restore.md`
- `._design_docs/cache-handling-phase38-design/part-02-cold-budget-gauge-fix.md`
- `._design_docs/cache-handling-phase38-design/part-03-observability-and-tests.md`
- `._design_docs/cache-handling-phase38-design/part-04-design-review-20260711.md`
- `._design_docs/cache-handling-phase38-design/part-05-design-correction-20260711.md`
- `._design_docs/cache-handling-architecture.md`
- `._design_docs/cache-handling-architecture/part-02-restore-and-residency-flow.md`
- `._design_docs/cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md`
- `._design_docs/cache-handling-architecture/part-06-stage-5-draft-context-modes-and-pairing.md`
- `._design_docs/cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md`
- `._design_docs/cache-handling-requirements.md`
- `._design_docs/cache-handling-requirements/part-01-status.md`
- `._design_docs/cache-handling-requirements/part-02-fully-slot-independent-shared-reuse.md`

## Scope and gate status

Stage 38 still covers both approved fixes:

- safe strict-prefix/checkpoint partial restore for the chat-completion hybrid
  cache path;
- D36-FU-01 cold-budget gauge correction for the 2048 MiB negative value.

Design re-review PASS. Developer implementation planning may start after the
Manager design gate passes. This review does not approve code changes, tests,
build execution, commits, or pushes.

## Findings closed

### F38-DESIGN-01 closed

The corrected design excludes `/completion` prefix restore from Stage 38.
Part 1 classifies `/completion` token-position candidates as unsafe and sends
them to recompute even when checksums match. Part 3 adds TP-38-PR-10 and closes
the question with the same policy. The entry document also lists `/completion`
prefix restore as out of scope.

That closes the prior open policy choice. The route stays on the fail-safe side
of R34-R36d and R90-R92 until a later stage defines route-specific boundary
rules and tests.

### F38-DESIGN-02 closed

The corrected design keeps public prompt-token totals at full request length.
Part 3 limits restored-prefix reporting to cache-specific fields:

- `slot.n_prompt_tokens_cache`
- `timings.cache_n`
- `usage.prompt_tokens_details.cached_tokens`

The suffix token count is internal work evidence only. It does not replace
OpenAI-compatible `usage.prompt_tokens` or other public total prompt fields.
This preserves Stage 32 and Stage 36 reporting assumptions.

## Re-review decisions

- Namespace, pair-state, descriptor, checksum, semantic-boundary, and workload
  profile checks remain strict enough for Stage 17 and the architecture
  restore-order contract.
- Checkpoint-dependent, SWA, recurrent, RS-limited, target-plus-draft, and MTP
  profiles remain limited to checkpoint-safe restore points.
- Suffix processing stays prompt prefill work. The design still forbids cached
  generated-output replay.
- Hot/cold residency and protected branch behavior still follow the Stage 25
  transactional model and the protected-root architecture.
- The cold-budget gauge fix still covers 64-bit positive budgets, preserves
  `-1` as unlimited, preserves `0` as cold writes disabled, and requires
  boundary evidence for `1`, `2047`, `2048`, `4096`, `0`, and `-1`.
- Prefix and restore metrics use bounded labels. Accepted partial restores count
  as hits only after live slot apply succeeds.

No new blocking contradiction was found in the corrected design.

## Documentation hygiene

The Stage 38 entry, review parts, document index, and stage tracker remain under
the 300-line cap after this report is linked. The new report is ASCII-only prose.

## Required corrections

None for the design gate.

Developer implementation must still preserve these acceptance checks:

- `/completion` strict-prefix candidates recompute with a bounded unsafe or
  fallback reason.
- Public prompt-token totals remain full request length.
- Cache-specific restored-prefix fields report the restored prefix length.
- The cold-budget gauge emits `2147483648` for `--cache-cold-max-mib 2048`.

## Handoff

Handoff state: ready for Manager design gate.

Next owner: Manager. If Manager approves the design gate, Developer may prepare
the Stage 38 implementation plan from the corrected design and this re-review.
