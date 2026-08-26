# Stage 40 merge/rework implementation plan 2026-08-26

Sources: ../cache-handling-phase40-design.md, ../cache-handling-phase40-implementation.md

## Status

Owner: Developer. Gate: implementation planning only. Source ref: origin/upstream_master (fc35562ba, fresh — D40-PLAN-01 staleness resolved).

D40-PLAN-01: 3-commit gap (fc35562ba CUDA, da9b5d68c CI, dac869b0a conversion) verified NO-OP — no cache contract impact. origin/upstream_master fetched to fc35562ba. No redo needed.

Stage 39 closure contracts carried into this plan:

- Coverage floor: 0.8486 on approved denominator (per TP-39-03)
- VS2022 conformance gap: VS2026 evidence exists but needs VS2022 rerun before merge

This plan covers merge/rework execution after gate approval. No merge, code, test, commit, push, or PR authorized.

## Entry gates before merge execution

- Source ref and staleness: Re-run staleness commands. Manager resolves 3-commit gap. Stop if SHA or count differs from accepted analysis.
- Dirty worktree: git status --short. Stale items per D40-INTAKE-05. Stop if uncommitted non-planning edit remains.
- AGENTS.md: No commit/push/PR without human approval. Stop if any step depends on unapproved action.
- Rework readiness: 11 REWORK rows routed. Manager may downgrade. Stop if any rework unclosed.

## Ordered phases

Phase 1 - Preflight: Staleness, dirty-tree, source comparison after Manager staleness decision. Output: merge log preflight section.

Phase 2 - Track analysis: Complete 3 per-track analyses below. Output: analysis appendix in merge log.

Phase 3 - Merge setup: Real two-parent merge (no fast-forward, 144 INTEGRATE + 11 REWORK rows). Output: merge command, parent SHAs, conflict list.

Phase 4 - Textual conflicts: Hand-resolve; local-first for hybrid/cache, upstream-first for legacy/default. Output: conflict table with policy, adjustment, contract, test.

Phase 5 - Semantic scans: Duplicate scan, rename grep, enum/struct/helper/behavior audits. Output: scan notes.

Phase 6 - Rework closure: Apply adjustments for all 3 tracks. Update durable docs if needed. Output: evidence entries and changed-file list.

Phase 7 - Regression: After all reworks closed and stale/dirty resolved. Output: build/ctest/HTTP/metrics/coverage/checkpoint/replay evidence.

Phase 8 - Handoff: Final merge log, update entry doc. Output: Architect review handoff.

## Track 1: MTP/KV/speculative

Rows: 88a39274ecf8, 8c146a836630, d1b34251bc57, d789527482d9, f5014e1a79d3

Required: inventory runtime shapes, list new compatibility keys, map to binary pair state, trace through Stage 25 transactions, validate token span/checksum/workload profile, classify metric labels.

## Track 2: Route/session lifecycle

Rows: 1a87dcdc452d, fbbf3ad1900ba

Scope also covers I-34-01/I-34-02 preservation:

- I-34-01: equivalent payload-bearing saves idempotent — verify upstream slot-save changes don't break idempotency
- I-34-02: slow tx_save reads outside cache_state_mutex — verify no upstream change re-introduces reads under the lock

Required: inventory route changes, trace request-to-cache planning, verify SSE replay buffer does not conflict with Stage 34 transcript replay, separate upstream SSE transport from Stage 34 synthesis replay, verify I-34-01 save-idempotency, verify I-34-02 lock-boundary.

## Track 3: Checkpoint placement

Rows: 73618f27a801, f5ddcd1696eca5, f20469d91948f, f6dcda390004b

Required: identify upstream checkpoint trigger mechanisms, compare to prompt-span boundaries, prove token-span/checksum validation before descriptor attachment, assess multi-modal caching signature, check for second cold-path checkpoint writer.

## Semantic conflict scans

Run after textual resolution: conflict markers, duplicate definitions, old/new symbol grep, switch audit for new enum values, struct field audit, helper overlap, behavior-change call-site grep, public metric bounded-label scan.

## Durable doc update triggers

- Speculative discriminator/pair changes: Architecture part 6, Stage 5.
- Checkpoint placement changes: Stage 9, architecture part 9.
- Route/schema changes: Stage 13, architecture part 8.
- Namespace/metric changes: Stage 31/32.
- Branch/session/replay: Stage 34.
- Transaction/lock boundaries: Stage 25.
- Retention/cold-store: Stages 38/39.
- New architecture invariant: cache-handling-architecture.md.

## Regression and evidence matrix

- Source freshness: staleness at regression time
- Build: clean build, config, targets, timestamp
- Cache core: ctest -R cache with raw log
- MTP/KV/speculative: pair-state tests, namespace isolation, unit tests
- Routes/session: HTTP probes for all touched families
- Checkpoint placement: unit tests for prompt-span boundaries
- Metrics: bounded labels, unique HELP/TYPE, hybrid counters
- Cold store: root containment, checksum, atomic write proof
- Stage 34 replay: replay/synthetic rows if touched
- Coverage: 0.8486 per TP-39-03; VS2022 gap noted

## Stop conditions

- Pre-merge: stale ref, changed fork point, dirty tree.
- During conflict: protected contract would change without doc update and Manager decision.
- Pre-regression: any rework track open, metrics shape ambiguous, semantic scans incomplete.
- Rollback: reverse merge, explicit reset, or new merge from fork point. No history rewrites.

Next owner: Architect. Next gate: implementation-plan review. Merge execution stays blocked.