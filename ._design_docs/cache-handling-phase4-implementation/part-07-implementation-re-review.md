# Phase 4 implementation: re-review of Part 6 fixes

Source: [../cache-handling-phase4-implementation.md](../cache-handling-phase4-implementation.md)

## Review scope

Review date: May 27, 2026

This re-review covers the two blocking findings from [Part 5](part-05-independent-implementation-review.md) and the fix evidence in [Part 6](part-06-review-fixes.md).

Reviewed code and tests:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

No implementation changes were made during this re-review.

## Verdict

PASS.

The Part 6 fixes close both blocking findings. Equivalent-entry refresh now uses the shared refresh path and runs hot payload budget enforcement before returning. Protected eviction now increments the protected-root decision counter once per protected entry evicted. Focused controller tests cover refresh-triggered budget enforcement and multiple protected evictions.

## Decisions

### Finding 1: equivalent-entry refresh skips immediate byte-budget enforcement

Status: closed.

`hybrid_cache_controller::save_slot()` now sends duplicate saves through `refresh_existing_entry()` at `tools/server/server-context.cpp:5293`. That helper updates protection, refreshes recency, updates the LRU index, and calls `evict_until_within_budget()` at `tools/server/server-cache-hybrid.cpp:331`.

The focused regression `test_hybrid_refresh_enforces_payload_budget()` lowers the budget after two entries are resident, refreshes an existing entry, and verifies that resident payload bytes are back under budget before the helper returns.

### Finding 2: protected-root decision metrics undercount protected evictions

Status: closed.

`evict_entry_by_id()` now increments `n_protected_root_decisions` and `n_protected_root_evictions` for each protected entry evicted at `tools/server/server-cache-hybrid.cpp:262`. The Prometheus exporter reads `n_protected_root_decisions` for `llamacpp_cache_protected_root_decisions_total` at `tools/server/server-context.cpp:4400`, so JSON stats and metrics use the same counter source.

The focused regression `test_hybrid_multiple_protected_evictions_count_decisions()` forces two protected evictions and verifies that protected eviction count is `2` and protected-root decisions include the pressure decision plus the two eviction decisions.

## Test coverage checked

The required focused tests are present and wired into `main()`:

- `tests/test-cache-controller.cpp:566` covers refresh-budget enforcement.
- `tests/test-cache-controller.cpp:589` covers multiple protected evictions and decision metrics.
- `tests/test-cache-controller.cpp:1102` and `tests/test-cache-controller.cpp:1103` call both regressions.

The Python cache-mode test continues to check that the protected-root decisions metric is exported for legacy and hybrid modes.

## Commands run

Commands run from `d:\source\llama.cpp-jet`:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
```

Outcome: passed. Built `build\bin\Release\test-cache-controller.exe`.

```powershell
cmake --build build --config Release --target llama-server -j 4
```

Outcome: passed. Built `build\bin\Release\llama-server.exe`.

```powershell
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Outcome: passed. `1/1` selected test passed.

```powershell
$env:LLAMA_SERVER_BIN_PATH='D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe'
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
pytest tools/server/tests/unit/test_cache_modes.py
```

Outcome: passed with the existing expected xfail. Result: `2 passed, 1 xfailed in 3.51s`. Pytest also emitted existing dependency and asyncio fixture-scope warnings.

## Changed paths

This re-review added or updated:

- `._design_docs/cache-handling-phase4-implementation.md`
- `._design_docs/cache-handling-phase4-implementation/part-07-implementation-re-review.md`
- `._design_docs/document-index.md`

Implementation paths reviewed but not changed by this re-review:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

## Handoff

State: ready for QA.

Phase 4 Stage 4 implementation fixes pass architecture re-review. QA can use Part 6 and this re-review as the focused evidence for the correction loop.
