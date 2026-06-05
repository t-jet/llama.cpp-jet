# Phase 4 Design: LRU Eviction Policy with Protected Roots - Part 1: Overview and scope

Source: [../cache-handling-phase4-design.md](../cache-handling-phase4-design.md)

## Objective

Phase 4 replaces ad hoc eviction behavior in hybrid mode with a dedicated LRU policy that:

- accounts for resident hot payload bytes
- updates recency on save and successful restore
- gives protected roots higher retention priority
- emits diagnostics when protected roots consume or exceed the configured hot-payload budget
- keeps the policy pluggable without exposing a policy-selection CLI before a second policy exists

The policy must preserve correctness. Eviction can reduce reuse, but it must not leave a slot in a half-restored state or split target and draft state for one cache entry.

## Prerequisites

Phase 4 assumes these Phase 3 behaviors are present:

- hybrid cache mode is opt-in and legacy cache behavior is unchanged when hybrid mode is disabled
- exact full-state blob save and non-destructive restore work for target-only and target-plus-draft entries
- each successful restore updates usage metadata
- namespace compatibility prevents cross-model or cross-configuration restores
- cache statistics and Prometheus export can read hybrid cache counters
- protected-root metadata can reach the cache entry from trusted server-side metadata

If any prerequisite is missing, Phase 4 implementation must either block or document a narrower acceptance target before code work starts.

## In scope

Phase 4 covers:

- a `server_cache_policy_lru` component for eviction decisions
- use of `--cache-ram` as the hot payload RAM budget
- resident-byte accounting for serialized target and draft payloads
- deterministic recency ordering through a monotonic use sequence or equivalent testable clock
- protected-root weighting and diagnostics
- counters and JSON stats for payload evictions and protected-root decisions
- policy-facing interfaces that can later support SLRU or 2Q

## Out of scope

Phase 4 does not cover:

- new operator CLI for selecting an eviction policy
- cold storage, demotion, promotion, or async I/O
- payload descriptor formats
- payload eviction that leaves branch metadata behind
- branch pruning or branch-metadata budget enforcement
- checkpoint payload residency
- request-controlled protected markers

Those items belong to later stages unless a prerequisite gap forces a smaller enabling change.

## Assumptions

- `--cache-ram 0` continues to disable prompt cache allocation.
- `--cache-ram -1` means no configured RAM limit for the prompt cache, so the LRU policy can record usage but must not evict for byte pressure.
- A target-plus-draft entry is one eviction unit. The policy never evicts only target or only draft bytes.
- Protected status comes from trusted server policy and prepared metadata already produced by earlier phases. Clients do not get a raw "pin this forever" control in Phase 4.
- The hybrid cache still runs on the server context path, so Phase 4 does not add locking unless implementation evidence shows cache mutation can happen concurrently.

## Non-goals and compatibility

The default cache path must stay structurally intact. Phase 4 should add a policy boundary inside the hybrid controller, not spread policy checks through unrelated scheduling, HTTP, or prompt-preparation code.

Exact restore semantics do not change. A cache miss caused by eviction must behave like any other miss and continue through the safe prompt processing path.

