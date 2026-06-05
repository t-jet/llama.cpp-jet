# Phase 4 implementation plan: LRU eviction policy with protected roots

Source: [../cache-handling-phase4-implementation.md](../cache-handling-phase4-implementation.md)

## Status

Planning date: May 27, 2026  
Implementation state: code complete, awaiting implementation review  
Approved design baseline: [Phase 4 design](../cache-handling-phase4-design.md), especially [Part 7: Independent design review](../cache-handling-phase4-design/part-07-independent-design-review.md)

Phase 4 is cleared for implementation. The design review passed with no blocking findings. The accepted baseline is byte-accounted LRU eviction in hybrid mode, protected roots as higher-retention entries rather than pins, `--cache-ram` as the hot payload budget, and an internal policy boundary with LRU as the only implemented policy.

Do not add `--cache-eviction-policy` in this phase unless the architecture document changes first.

## Design baseline

Implement Stage 4 against these decisions:

- `--cache-ram` is the hot full-state payload RAM budget.
- `--cache-ram -1` means unlimited payload budget. The policy records usage but does not evict for byte pressure.
- `--cache-ram 0` continues to disable prompt cache allocation.
- Resident payload bytes are `target_state_bytes + draft_state_bytes`.
- Metadata, tokens, indexes, namespace strings, and checkpoints are outside the Phase 4 hot payload budget.
- A target-plus-draft entry is one eviction unit. The policy must not evict only target or only draft state.
- LRU recency must be deterministic in tests. Prefer a monotonic `uint64_t use_sequence` over `system_clock`.
- Successful save, equivalent-entry refresh, and successful restore refresh recency.
- Failed restore does not refresh recency.
- Protected roots are evicted after unprotected entries, but they still count against the budget.
- Protected entries may be evicted or rejected when keeping them would leave resident payload bytes over budget.
- The policy boundary must stay small enough to support later SLRU or 2Q without moving restore logic into the policy.

## Current code baseline

The relevant Phase 3 code is concentrated in:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tools/server/server-cache-controller.h`
- `tools/server/server-cache-controller.cpp`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`
- `tools/server/CMakeLists.txt`
- `tests/CMakeLists.txt`

Current Phase 3 scaffolding already has useful pieces:

- `hybrid_cache_entry::protected_root`
- `hybrid_cache_entry::mark_used()`
- `hybrid_cache_controller::lru_index`
- `hybrid_cache_controller::evict_lru()`
- `hybrid_cache_controller::update()`
- `n_evictions` stats and `llamacpp_cache_evictions_total`
- metadata-derived protected-root assignment in `save_slot()`

Those pieces are not Stage 4 completion by themselves. The current LRU index is controller-owned, clock-based, and tied to broad `entry.size()` accounting. `entry.size()` includes tokens, namespace strings, and checkpoint bytes, while Stage 4 eviction must use resident serialized target plus draft bytes. The current protected behavior skips protected entries first and then evicts protected entries as a fallback, but it does not expose protected byte totals, protected decision counters, protected admission rejection counts, or the required warning/debug diagnostics. The current restore paths refresh recency before state restore finishes, while Phase 4 requires recency refresh only after successful restore.

## Ordered implementation steps

### Step 4.1: Add policy-facing data and deterministic recency

Add entry fields or helpers for:

- `resident_payload_bytes`
- `use_sequence`
- stable insertion or entry id tie-breaker
- target-present and draft-present checks

Replace clock-based LRU ordering in the hybrid path with deterministic sequence ordering. Keep `use_count` only if existing stats or tests still need it.

Update debug helpers so tests can create entries with payload sizes, protection state, and known recency order without a live model context.

### Step 4.2: Introduce the internal policy boundary

Add a `server_cache_policy_lru` component, likely as:

- `tools/server/server-cache-policy-lru.h`
- `tools/server/server-cache-policy-lru.cpp`

Keep the policy input free of restore or serialization details. It should receive candidates with entry handle or id, namespace id, resident payload bytes, token count, use sequence, protection state, and target/draft presence. It should return an eviction plan with reasons such as `over_budget`, `admission_retry`, and `protected_budget_pressure`.

The controller remains responsible for deleting entries from the list, LRU indexes, prefix indexes, and stats.

### Step 4.3: Enforce byte-accounted admission and eviction

Change `save_slot()` to compute serialized target and draft byte sizes before admission. Reject a new entry when its resident payload bytes exceed the configured budget, unless the budget is unlimited.

After inserting or refreshing an entry, ask the policy for evictions until resident payload bytes fit or no legal candidates remain.

Keep exact-blob invariants:

- no target payload means no admission
- target and draft are stored and evicted together
- a draft-required restore must not use an entry without draft bytes

### Step 4.4: Correct recency refresh on restore

Move recency refresh in `try_restore_from_cache()` and `load_slot()` until after target and draft restore have both succeeded. Failed target or draft restore increments restore failure stats but does not update `use_sequence`.

Keep eviction-induced misses on the normal fallback path.

### Step 4.5: Add protected-root accounting and diagnostics

Track:

- protected resident payload bytes
- unprotected resident payload bytes
- protected entry count
- protected root decisions
- protected root evictions
- protected root admission rejections

Emit the required diagnostics:

- save rejected because payload bytes exceed the hot budget
- LRU eviction selected an unprotected entry
- protected root skipped while unprotected entries satisfy pressure
- protected-root budget pressure detected
- protected root evicted because protected bytes exceeded the budget
- eviction could not satisfy budget because no legal candidates remain

Include namespace id, token count, resident payload bytes, budget bytes, protected state, and use sequence when those fields are available.

Use warning logs for protected eviction or admission rejection. Use debug logs when protected entries are only skipped.

### Step 4.6: Extend stats and Prometheus export

Add JSON stats fields:

- `resident_payload_bytes`
- `hot_payload_budget_bytes`
- `n_payload_evictions`
- `n_protected_root_decisions`
- `n_protected_root_evictions`
- `n_protected_root_admission_rejections`
- `protected_payload_bytes`
- `unprotected_payload_bytes`
- `n_protected_entries`

Keep existing fields such as `size_bytes`, `n_evictions`, hits, misses, and restore failures for compatibility.

Add Prometheus counters:

- `llamacpp_cache_payload_evictions_total`
- `llamacpp_cache_protected_root_decisions_total`

Do not add a custom label framework for Phase 4. Use the existing cache metric export shape.

### Step 4.7: Add focused unit and integration tests

Extend `tests/test-cache-controller.cpp` for isolated controller and policy behavior:

- oldest unprotected entry evicts first
- restore refreshes recency only after success
- failed restore leaves recency unchanged
- equivalent-entry refresh updates recency without duplicating the entry
- tie-breaking is stable
- resident payload bytes drive eviction, not token or metadata size
- oversize admission is rejected
- unlimited budget records usage and does not evict
- protected entries survive while unprotected entries can satisfy the budget
- protected entries are evicted when protected bytes exceed the budget
- stats counters and protected byte totals are correct

Extend `tools/server/tests/unit/test_cache_modes.py` or add a focused server test for Prometheus output if the existing Python harness covers metrics without a live model.

### Step 4.8: Build, test, and document evidence

Expected verification commands:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
cmake --build build --config Release --target llama-server -j 4
pytest tools/server/tests/unit/test_cache_modes.py
```

If the local build directory or Python harness differs, record the exact commands used and the reason for any substitution.

After each implementation step, update this implementation log with changed files, behavior changes, and real evidence.

## Affected code files

Expected code edits:

- `tools/server/server-cache-hybrid.h`: entry fields, stats fields, debug helpers, policy ownership
- `tools/server/server-cache-hybrid.cpp`: resident-byte accounting, update flow, index maintenance, stats helpers
- `tools/server/server-context.cpp`: save/restore admission, recency refresh timing, Prometheus export
- `tools/server/server-cache-controller.h`: only if the policy boundary needs a common stats or budget accessor
- `tools/server/server-cache-controller.cpp`: only if construction wiring changes
- `tools/server/CMakeLists.txt`: add new policy source files
- `tests/test-cache-controller.cpp`: policy/controller tests
- `tests/CMakeLists.txt`: only if new test targets are added
- `tools/server/tests/unit/test_cache_modes.py`: metrics-shape coverage

Expected new files:

- `tools/server/server-cache-policy-lru.h`
- `tools/server/server-cache-policy-lru.cpp`

Docs to update during implementation:

- `._design_docs/cache-handling-phase4-implementation.md`
- `._design_docs/cache-handling-phase4-implementation/part-01-implementation-plan.md`
- additional `part-XX-*.md` files if implementation evidence grows past the document size limit
- `._design_docs/document-index.md` if new durable documents are added

## Tests, docs, and evidence plan

Unit tests must exercise the policy without a live model context. Controller tests should prove that eviction plans remove entries from all indexes and leave stats consistent.

Integration tests should cover the server-visible surfaces:

- JSON stats fields
- Prometheus metric names
- no behavior change for legacy cache mode
- hybrid restore still works after eviction-induced misses

Coverage target: at least 80 percent line coverage for new or materially changed hybrid cache policy code. If coverage tooling is unavailable in this environment, record the commands that would produce it and the concrete test coverage that was run.

The implementation log must record:

- changed files for each completed step
- tests run and exact pass/fail results
- build command output summary
- any design deviation, with the design part that must be updated before sign-off

## Risks and blockers

- Current code uses wall-clock time for LRU. Tests that depend on access order may remain flaky unless recency moves to a sequence.
- Current `size()` and `calculate_total_size()` include non-payload bytes. Leaving eviction on those helpers would violate the Phase 4 budget contract.
- Current restore paths update recency before restore completion. That can make a corrupt or incomplete entry harder to evict.
- Pre-admission eviction in `save_slot()` may evict useful entries before serialization succeeds. The implementation should avoid destructive pressure handling until the new entry is valid enough to admit.
- `--cache-ram -1` is currently converted to a zero byte limit in the hybrid constructor. Phase 4 needs to preserve the difference between unlimited budget and cache disabled.
- Existing tests use token-limit eviction paths. Stage 4 still needs byte-budget tests because `--cache-ram` is the acceptance path.
- Prometheus export is centralized in `server-context.cpp`; adding counters must preserve existing metric names and mode labels.
- Protected roots come from trusted metadata today. Do not add request-controlled pinning or broad marker parsing in this phase.

## Phase 3 scaffolding versus Stage 4 behavior

Phase 3 added enough LRU-like behavior to prove non-destructive exact blob reuse, but Stage 4 changes the acceptance target.

Phase 3 behavior:

- LRU is embedded in `hybrid_cache_controller`.
- Recency uses `std::chrono::system_clock`.
- Eviction pressure uses broad entry size and token count.
- Protected roots are skipped before fallback eviction.
- Metrics expose broad cache evictions only.
- Restore paths refresh usage before full restore success.

Stage 4 behavior to add:

- LRU policy exists behind an internal policy boundary.
- Recency is deterministic and testable.
- Eviction pressure uses resident serialized target plus draft payload bytes.
- Admission rejects a new over-budget payload before insertion.
- Protected roots are a weighted class, not pins, and their byte pressure is observable.
- Protected over-budget decisions log explicit diagnostics.
- JSON stats and Prometheus expose payload evictions and protected-root decisions.
- Failed restore attempts do not refresh recency.

## Handoff state

Implementation is code complete for Step 4.1 through Step 4.8. See [Part 4: Implementation evidence](part-04-implementation-evidence.md) for changed files, behavior changes, build and test evidence, and remaining risks. The next activity is implementation review.
