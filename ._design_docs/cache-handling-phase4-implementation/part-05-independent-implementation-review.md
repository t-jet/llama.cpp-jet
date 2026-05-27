# Phase 4 implementation: independent review

Source: [../cache-handling-phase4-implementation.md](../cache-handling-phase4-implementation.md)

## Review scope

Review date: May 27, 2026

Reviewed documents:

- [Phase 4 implementation entry](../cache-handling-phase4-implementation.md)
- [Part 1: Implementation plan](part-01-implementation-plan.md)
- [Part 2: Independent implementation-plan review](part-02-independent-implementation-plan-review.md)
- [Part 3: Implementation-plan re-review](part-03-implementation-plan-re-review.md)
- [Part 4: Implementation evidence](part-04-implementation-evidence.md)
- [Phase 4 design entry](../cache-handling-phase4-design.md)
- [Phase 4 design parts 1-7](../cache-handling-phase4-design/part-07-independent-design-review.md)
- [Stage 4 architecture source](../cache-handling-architecture/part-05-stage-4-lru-eviction-policy-with-protected-roots.md)
- [Requirements](../cache-handling-requirements.md)
- [AGENTS.md](../../AGENTS.md)

Reviewed code and tests:

- `tools/server/server-cache-policy-lru.h`
- `tools/server/server-cache-policy-lru.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tools/server/CMakeLists.txt`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

This was an implementation review. No code fixes were made.

## Verdict

REWORK.

The implementation covers most of the approved Stage 4 behavior. It adds a dedicated LRU policy component, deterministic use sequences, resident target-plus-draft payload accounting, protected-root pressure handling, new stats fields, Prometheus counters, and focused tests. The focused build and test commands passed.

Two implementation gaps block sign-off. One save refresh path can skip immediate budget enforcement, and the protected-root decision counter does not count protected eviction decisions at the granularity required by the approved test plan.

## Findings

### Finding 1: equivalent-entry refresh skips immediate byte-budget enforcement

Severity: Required correction

The approved design says the controller must add or refresh an entry, then ask the policy for evictions until resident bytes fit or no legal plan remains. Part 2 describes this in the save flow, and Part 1 lists equivalent-entry refresh as a recency-refresh event.

`hybrid_cache_controller::save_slot()` returns immediately after finding an existing exact entry:

- `tools/server/server-context.cpp:5291` finds the existing entry.
- `tools/server/server-context.cpp:5295` updates protection.
- `tools/server/server-context.cpp:5296` refreshes recency.
- `tools/server/server-context.cpp:5300` returns without calling `evict_until_within_budget()`.

That leaves a refresh save outside the Stage 4 admission and eviction flow. If the cache is already over budget because of a configuration change, accounting correction, earlier admission bug, or a protected-root pressure scenario that still needs cleanup, this path can refresh recency and leave resident payload bytes over the configured hot budget until some later maintenance call happens. It also weakens the protected-root pressure behavior because a protected refresh can broaden retention priority without immediately forcing the policy to account for the current protected and unprotected byte totals.

Required correction:

- After an equivalent-entry refresh, run the same payload-budget enforcement used after insertion.
- Keep recency refresh only for the successful refresh path.
- Add or update a focused controller test that starts from an over-budget state, refreshes an existing entry, and verifies resident payload bytes fit the configured budget before `save_slot()` returns or before the equivalent test helper returns.

Acceptance check:

- Save insertion and save refresh both trace to the same Stage 4 byte-budget policy enforcement point.

### Finding 2: protected-root decision metrics undercount protected evictions

Severity: Required correction

The approved Phase 4 test plan requires the protected-root decision counter to increment for skip, pressure, evict, and reject paths. Part 4 defines `cache_protected_root_decisions_total`, and Part 5 lists the required metric cases.

The current implementation increments `n_protected_root_decisions` for protected skip and protected pressure in `evict_until_within_budget()`:

- `tools/server/server-cache-hybrid.cpp:287` to `tools/server/server-cache-hybrid.cpp:295`

Protected eviction itself increments only `n_protected_root_evictions`:

- `tools/server/server-cache-hybrid.cpp:249` to `tools/server/server-cache-hybrid.cpp:253`

This means one policy plan that evicts two protected entries records one protected decision and two protected evictions. The JSON field and Prometheus counter can therefore under-report the number of protected eviction decisions, even though each protected eviction is a policy decision that considered protected-root state. The existing tests only assert `n_protected_root_decisions >= 1`, so they do not catch the mismatch.

Required correction:

- Increment `n_protected_root_decisions` for each protected eviction, or document and implement a different exact counter contract that still satisfies the approved skip, pressure, evict, and reject metric cases.
- Add a focused test with multiple protected evictions and assert the decision counter covers the evict path, not only the pressure path.
- Keep `n_protected_root_evictions` as the specific protected eviction count.

Acceptance check:

- JSON stats and `llamacpp_cache_protected_root_decisions_total` count protected eviction decisions consistently with the approved Phase 4 test plan.

## Review decisions

Passed checks:

- Resident payload accounting uses `data.main.size() + data.drft.size()` and keeps broad `size_bytes` separate.
- Target and draft payloads remain one eviction unit.
- Recency is deterministic through monotonic use sequences, with stable insertion and entry-id tie-breakers in policy ordering.
- Restore recency updates happen after target and draft restore success in both restore paths reviewed.
- Protected roots are ordered after unprotected entries and can still be evicted under budget pressure.
- `--cache-eviction-policy` was not added.
- Legacy cache mode construction and stats remain compatible with the existing controller interface.
- The new policy files are wired into `tools/server/CMakeLists.txt`.

Non-blocking notes:

- The controller still keeps an `lru_index` and LRU-named helpers. The active eviction decision has moved into `server_cache_policy_lru`, so this is not a sign-off blocker for Stage 4, but future policy work should remove or rename controller-owned LRU scaffolding if another policy needs different ordering state.
- Log diagnostics were reviewed by code path. The current focused tests do not capture logs, matching the limitation recorded in Part 4.

## Commands run

Commands run from `d:\source\llama.cpp-jet`:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
```

Outcome: passed. Built `build\bin\Release\test-cache-controller.exe`.

```powershell
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Outcome: passed. `1/1` selected test passed.

```powershell
$env:LLAMA_SERVER_BIN_PATH='D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe'
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
pytest tools/server/tests/unit/test_cache_modes.py
```

Outcome: passed with the existing expected xfail. Result: `2 passed, 1 xfailed`.

## Changed paths

This review added or updated:

- `._design_docs/cache-handling-phase4-implementation.md`
- `._design_docs/cache-handling-phase4-implementation/part-05-independent-implementation-review.md`

Implementation paths reviewed:

- `tools/server/server-cache-policy-lru.h`
- `tools/server/server-cache-policy-lru.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tools/server/CMakeLists.txt`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

## Required corrections

Code:

- Enforce the byte-budget policy after equivalent-entry refresh in `hybrid_cache_controller::save_slot()`.
- Count protected eviction decisions in `n_protected_root_decisions` or revise the metric contract in durable docs before sign-off.

Tests:

- Add a save-refresh budget enforcement test.
- Add a multiple protected-eviction metric test.

Docs:

- Update Part 4 implementation evidence after fixes with the changed files, commands run, and any metric contract clarification.
- Keep the implementation entry status as rework until this review is closed by re-review.

## Handoff

State: correction loop required.

Next owner: developer for the two required corrections, then architect for implementation re-review. QA should wait for re-review before treating Phase 4 Stage 4 as ready for broader verification.
