# Phase 4 implementation plan: independent review

Source: [../cache-handling-phase4-implementation.md](../cache-handling-phase4-implementation.md)

## Review scope

Review date: May 27, 2026

Reviewed documents:

- [Phase 4 implementation entry](../cache-handling-phase4-implementation.md)
- [Part 1: Implementation plan](part-01-implementation-plan.md)
- [Phase 4 design entry](../cache-handling-phase4-design.md)
- [Phase 4 design parts 1-7](../cache-handling-phase4-design/part-07-independent-design-review.md)
- [Stage 4 architecture source](../cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md)
- [Requirements](../cache-handling-requirements.md)
- Relevant code in `tools/server/server-cache-hybrid.h`, `tools/server/server-cache-hybrid.cpp`, `tools/server/server-context.cpp`, `tools/server/server-cache-controller.h`, `tools/server/server-cache-controller.cpp`, `tests/test-cache-controller.cpp`, and `tools/server/tests/unit/test_cache_modes.py`

This was an implementation-plan review. No code was changed.

## Verdict

REWORK.

The plan is mostly feasible and tracks the approved design well. It correctly calls out the existing Phase 3 scaffolding, the need for deterministic recency, resident target-plus-draft byte accounting, protected-root pressure handling, successful-restore-only recency refresh, JSON stats, Prometheus counters, and focused tests.

One required design diagnostic is missing from the implementation steps. The plan must carry it before code work starts, because otherwise an implementation can pass the plan while failing Part 4 of the approved design.

## Finding 1: ordinary unprotected LRU eviction diagnostic is missing

Severity: Required correction

The approved design requires a log event when LRU eviction selects an unprotected entry. Part 4 lists this as a required diagnostic event: "LRU eviction selected an unprotected entry."

The implementation plan lists diagnostics for oversize save rejection, protected-root skips, protected-root budget pressure, protected eviction, admission rejection, and unsatisfied budget. It does not require the ordinary unprotected eviction diagnostic.

Code inspection shows this path already exists in a rough form in `hybrid_cache_controller::evict_lru()`, where unprotected entries are selected before protected fallback. Stage 4 will move or wrap this decision through `server_cache_policy_lru`, so the plan must explicitly preserve the diagnostic at the policy/controller boundary. Without that requirement, the developer could add the new policy and metrics but lose the operator-visible reason for the most common eviction path.

Required correction:

- Update Part 1 Step 4.5 to include the required diagnostic: LRU eviction selected an unprotected entry.
- The diagnostic should include the useful context named in the design when available: namespace id, token count, resident payload bytes, hot payload budget, protected state, and use sequence.
- Add or update a focused test or log-capture check if the project has a practical log assertion path. If log capture is not practical, the implementation notes must record how this diagnostic was verified.

Acceptance check:

- A review of the corrected plan can trace every required Part 4 log event to an implementation step or evidence item.

## Feasibility checks

The rest of the plan is feasible against the current code baseline.

- `hybrid_cache_entry` currently uses `last_used_time` and `mark_used()` with `std::chrono::system_clock`; the plan's deterministic `use_sequence` replacement is necessary.
- `entry.size()` and `calculate_total_size()` include tokens, checkpoint bytes, and namespace strings; the plan correctly requires separate resident payload accounting for `data.main` plus `data.drft`.
- `save_slot()` currently evicts before serialization when broad size pressure predicts an over-budget insert; the plan correctly requires admission based on serialized payload bytes and avoids destructive pressure handling until the incoming entry is valid enough to admit.
- `try_restore_from_cache()` and `load_slot()` currently refresh LRU state before target and draft restore complete; the plan correctly moves refresh after successful restore.
- Protected roots currently skip unprotected entries first and then fall back to protected eviction, but there are no protected byte totals, decision counters, admission rejection counters, or protected-pressure diagnostics; the plan correctly adds those.
- Prometheus export is centralized in `server-context.cpp`; the plan correctly adds the Stage 4 counters through existing cache stats rather than adding a new label framework.
- Existing controller tests already cover token-limit eviction and protected fallback. They are not enough for Stage 4, and the plan correctly adds byte-budget, deterministic recency, protected-pressure, and stats coverage.

## Required corrections

Documentation:

- Correct `part-01-implementation-plan.md` before implementation starts, or add a follow-up review part that records the correction.
- Keep the implementation entry status as rework until the missing diagnostic is included.

Code:

- No code correction is requested by this review. Code work should wait for the plan correction.

## Handoff

State: re-review required.

Next owner: developer or architect to correct the implementation plan, then architect for a short re-review. Implementation should not start from the current plan because it omits a required Stage 4 diagnostic.
