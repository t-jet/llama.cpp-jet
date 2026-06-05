# Phase 4 implementation: evidence

Source: [../cache-handling-phase4-implementation.md](../cache-handling-phase4-implementation.md)

## Status

Implementation date: May 27, 2026  
Implementation state: Stage 4 closed

This part records the code work for Step 4.1 through Step 4.8 of the approved plan. It does not add `--cache-eviction-policy`; LRU remains the only internal policy.

Review fixes from [Part 6](part-06-review-fixes.md) are now applied. Equivalent-entry refresh uses the same post-refresh budget enforcement path as insertion, and protected-root eviction now increments both the protected decision counter and the protected eviction counter.

## Changed files

Code:

- `tools/server/server-cache-policy-lru.h`
- `tools/server/server-cache-policy-lru.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tools/server/CMakeLists.txt`

Tests:

- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

Docs:

- `._design_docs/cache-handling-phase4-implementation.md`
- `._design_docs/cache-handling-phase4-implementation/part-04-implementation-evidence.md`
- `._design_docs/cache-handling-phase4-implementation/part-06-review-fixes.md`
- `._design_docs/document-index.md`

Pre-existing dirty or untracked docs were present before implementation started: `._design_docs/document-index.md`, the Phase 4 design docs, the Phase 4 implementation docs, and self-improvement memory files for architect, developer, and manager.

## Behavior changes

Step 4.1 added deterministic recency and resident payload accounting:

- `hybrid_cache_entry` now has stable entry id, insertion sequence, and monotonic use sequence fields.
- Clock-based LRU ordering was removed from the hybrid path.
- `resident_payload_bytes()` is target state bytes plus draft state bytes. Tokens, namespace strings, metadata, and checkpoints still count in `size_bytes`, but no longer drive the Stage 4 hot payload budget.

Step 4.2 added the internal policy boundary:

- `server_cache_policy_lru` receives controller-owned candidates and returns an eviction plan.
- The policy does not serialize, restore, own indexes, or inspect HTTP/request metadata.
- The controller still removes entries from storage, prefix index, LRU index, and stats.

Step 4.3 added byte-accounted admission and eviction:

- `--cache-ram -1` now stays distinguishable from a zero byte limit in hybrid mode.
- A new save is rejected if its serialized target plus draft payload exceeds the hot payload budget.
- After insertion, the controller asks the policy for evictions until resident payload bytes fit.
- Target and draft blobs remain one eviction unit.

Step 4.4 moved restore recency updates:

- `try_restore_from_cache()` and `load_slot()` update recency only after target and draft restore succeed.
- Failed restore paths still increment restore failure stats and do not refresh `use_sequence`.

Step 4.5 added protected-root accounting and diagnostics:

- Stats now track protected payload bytes, unprotected payload bytes, protected entry count, protected-root decisions, protected-root evictions, and protected-root admission rejections.
- Unprotected LRU eviction, protected-root skip, protected budget pressure, protected eviction, oversize save rejection, and unsatisfied budget paths log explicit diagnostics.

Step 4.6 added stats and Prometheus export:

- JSON stats expose `resident_payload_bytes`, `hot_payload_budget_bytes`, `n_payload_evictions`, `n_protected_root_decisions`, `n_protected_root_evictions`, `n_protected_root_admission_rejections`, `protected_payload_bytes`, `unprotected_payload_bytes`, and `n_protected_entries`.
- Prometheus export now includes `llamacpp_cache_payload_evictions_total` and `llamacpp_cache_protected_root_decisions_total`.

Step 4.7 added focused tests:

- Isolated policy tests cover deterministic unprotected eviction, protected-root skip behavior, protected fallback eviction, and unlimited budget behavior.
- Controller tests cover deterministic sequence tracking, resident payload byte eviction, protected-root priority, protected fallback eviction, unlimited budget behavior, stats fields, and token-limit compatibility.
- Python server metrics tests check the new Prometheus metric names for cache metrics.

Review-fix tests added:

- Equivalent-entry refresh budget enforcement: starts from a resident set that becomes over budget after a budget change, refreshes an existing entry, and verifies resident payload bytes fit before the helper returns.
- Multiple protected evictions: forces two protected evictions in one enforcement pass and verifies `n_protected_root_evictions` is 2 while `n_protected_root_decisions` includes the protected eviction decisions.

Focused Stage 4 coverage added after the test-results review:

- H33 failed restore recency: `test_hybrid_failed_restore_does_not_refresh_recency()` uses a controller fault-injection helper to force a restore failure after lookup, verifies `n_restore_failures == 1`, then applies byte pressure and proves the failed candidate is evicted first.
- H37 protected admission rejection: `test_hybrid_protected_admission_rejection_stats()` uses a stats-capable controller admission helper with trusted protected metadata and an oversized payload. It verifies no entry is admitted, resident/protected bytes stay at zero, and `n_protected_root_decisions` plus `n_protected_root_admission_rejections` increment.

## Evidence

Commands run from `d:\source\llama.cpp-jet`:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
```

Outcome: passed. CMake regenerated the build files, then built `test-cache-controller.exe`.

```powershell
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Outcome: passed. `1/1` selected test passed in `0.02 sec` (`0.04 sec` total real time) after adding isolated policy coverage.

```powershell
cmake --build build --config Release --target llama-server -j 4
```

Outcome: passed. Built `build\bin\Release\llama-server.exe`.

```powershell
pytest tools/server/tests/unit/test_cache_modes.py
```

Outcome: blocked by the test harness before test execution. The module preload fixture tried to start `../../../build/bin/Release/llama-server.exe` and Windows reported `FileNotFoundError`.

```powershell
$env:LLAMA_SERVER_BIN_PATH='D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe'
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
pytest tools/server/tests/unit/test_cache_modes.py
```

Outcome: passed with existing expected xfail. Result: `2 passed, 1 xfailed in 3.51s` after adding isolated policy coverage.

Review-fix retest from `d:\source\llama.cpp-jet`:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
```

Outcome: passed. Built `build\bin\Release\test-cache-controller.exe`.

```powershell
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Outcome: passed. `1/1` selected test passed in `0.03 sec`.

```powershell
cmake --build build --config Release --target llama-server -j 4
```

Outcome: passed. Built `build\bin\Release\llama-server.exe`.

```powershell
$env:LLAMA_SERVER_BIN_PATH='D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe'
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
pytest tools/server/tests/unit/test_cache_modes.py
```

Outcome: passed with existing expected xfail. Result: `2 passed, 1 xfailed in 4.17s`. Pytest also emitted existing dependency and asyncio fixture-scope warnings.

Focused H33/H37 coverage retest from `d:\source\llama.cpp-jet`:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
```

Outcome: passed. Built `build\bin\Release\test-cache-controller.exe`. The first attempt failed because pre-existing H31/H32 controller tests passed non-copyable `server_tokens` by value; those calls now use `clone()`.

```powershell
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Outcome: passed. `1/1` selected test passed in `0.02 sec`.

```powershell
build\bin\Release\test-cache-controller.exe
```

Outcome: passed. Direct output reported all 40 controller tests passed, including `H31 LRU entry-state ordering`, `H32 successful-restore recency`, `hybrid failed restore does not refresh recency`, and `hybrid protected admission rejection stats`.

```powershell
cmake --build build --config Release --target llama-server -j 4
```

Outcome: passed. Built `build\bin\Release\llama-server.exe`.

## Remaining risks

- No coverage report was generated in this environment, so the 80 percent target is supported by focused tests rather than measured line coverage.
- The Python metrics suite still has an existing xfailed hybrid repeated-restore test. This implementation did not change that known test status.
- Log diagnostics were verified by code path review and passing tests that exercise the decision paths. There is no log-capture assertion in the current focused test harness.

## Handoff

State: Stage 4 implementation evidence accepted for closure.

Final QA reconciliation `test-report-20260527-08.md` accepted H30-H37. The final developer test-results review in [Part 8](part-08-test-results-review.md) accepts H38-H39 from the earlier manual metrics and legacy compatibility evidence in `test-report-20260527-01.md`. No product bug or execution blocker remains from the Stage 4 evidence set.

Closure decision: see [Part 9: Stage closure decision](part-09-stage-closure-decision.md).
