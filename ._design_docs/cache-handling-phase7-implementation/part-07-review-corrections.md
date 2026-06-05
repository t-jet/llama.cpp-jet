# Stage 7 review corrections - Part 7

Source: [../cache-handling-phase7-implementation.md](../cache-handling-phase7-implementation.md)  
Correction date: May 31, 2026  
Trigger: [Part 6 implementation review](part-06-implementation-review.md), verdict REWORK

## Scope

This correction pass fixes the five blocking implementation review findings from Part 6. QA is not
open yet. The next gate is implementation re-review.

## Code corrections

R1 slot references:

- Added a slot-held branch node id to production `server_slot` state.
- `save_slot()`, `try_restore_from_cache()`, and `load_slot()` now acquire a branch ref after the
  branch node is selected and before the slot is assigned to that node.
- `prompt_clear()` releases the prior branch ref through the cache controller callback.
- Replacing a slot's node releases the previous node ref.
- Forest active refs now block production payload eviction candidates.

R2 forest-backed eviction:

- `build_policy_candidates()` now starts from `branch_forest_index::payload_eviction_candidates()`.
- The adapter resolves forest node ids back to entries for the existing Stage 4 policy planner.
- Protected-root ordering remains unprotected payloads first, then protected-root payloads under
  protected-budget pressure.
- Added controller coverage for global eviction across namespaces.

R3 checksum lookup:

- Restore candidate selection now merges token-span candidates with length-qualified checksum
  candidates when boundary metadata supplies a prefix checksum.
- Namespace validation still runs before payload resolution and before live slot mutation.
- Added controller coverage where checksum lookup finds a cached prefix candidate for a longer
  request.

R4 metrics:

- Prometheus export now includes the accepted Stage 7 metric names from design Part 05.
- Python metrics-shape tests now check namespace, metadata ratio, payload eviction, protected-root
  payload, slot-ref, forest-lock, and namespace-validation metric names.
- Existing Stage 4, Stage 5, and Stage 6 metric names remain in the shape test.

R5 documentation size:

- Split oversized design Part 07 into a short index plus Part 07A and Part 07B detail files.
- Updated the Stage 7 design TOC with the new Part 07A/07B links.
- Rechecked all Stage 7 design and implementation markdown files for the 300-line rule.

## Files changed

Code and tests:

- `tools/server/server-cache-controller.h`
- `tools/server/server-cache-legacy.h`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

Docs:

- `._design_docs/cache-handling-phase7-design.md`
- `._design_docs/cache-handling-phase7-design/part-07-independent-design-review.md`
- `._design_docs/cache-handling-phase7-design/part-07a-independent-design-review-blocking.md`
- `._design_docs/cache-handling-phase7-design/part-07b-independent-design-review-nonblocking.md`
- `._design_docs/cache-handling-phase7-implementation.md`
- `._design_docs/cache-handling-phase7-implementation/part-07-review-corrections.md`
- `._design_docs/document-index.md`

## Evidence

Focused controller build:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
```

Result: PASS. Built `build\bin\Release\test-cache-controller.exe`.

Focused controller tests:

```powershell
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Result: PASS. CTest ran 1 test and it passed in 0.08 seconds.

Server build:

```powershell
cmake --build build --config Release --target llama-server -j 4
```

Result: PASS. Built `build\bin\Release\llama-server.exe`.

Metrics shape:

```powershell
$env:LLAMA_SERVER_BIN_PATH=(Resolve-Path build\bin\Release\llama-server.exe).Path; $env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'; pytest tools/server/tests/unit/test_cache_modes.py
```

Result: PASS. Pytest reported 3 passed and 1 xfailed. The xfail is the existing explicit `id_slot`
restore-path limitation.

Branch graph:

```powershell
cmake --build build --config Release --target test-step12-branch-graph -j 4
ctest --test-dir build -C Release -R test-step12-branch-graph --output-on-failure
```

Result: PASS. CTest ran 1 test and it passed in 0.02 seconds.

Stage 6 cold-path regressions:

```powershell
cmake --build build --config Release --target test-step6-demotion-protocol test-step7-promotion-protocol test-step10-metrics -j 4
ctest --test-dir build -C Release -R "test-step6-demotion-protocol|test-step7-promotion-protocol|test-step10-metrics" --output-on-failure
```

Result: PASS. CTest ran 3 tests and all passed in 7.07 seconds.

Document line-count check:

```powershell
Get-ChildItem ._design_docs/cache-handling-phase7-design -Filter *.md | ForEach-Object { '{0} {1}' -f (Get-Content $_.FullName).Count, $_.Name }; Get-ChildItem ._design_docs/cache-handling-phase7-implementation -Filter *.md | ForEach-Object { '{0} {1}' -f (Get-Content $_.FullName).Count, $_.Name }
```

Result: PASS. Every Stage 7 design and implementation markdown file is under 300 lines. The largest
files are design Part 02 at 276 lines and implementation Part 01 at 266 lines.

## Limits

- No coverage report was generated in this environment.
- TSAN was not run. The active Windows/MSVC build tree is not configured with a ThreadSanitizer
  target.

## Handoff

Correction status: complete.

Recommended next gate: implementation re-review against Part 6 findings R1 through R5.
