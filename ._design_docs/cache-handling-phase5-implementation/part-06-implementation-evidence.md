# Phase 5 implementation: implementation evidence

Source: [../cache-handling-phase5-implementation.md](../cache-handling-phase5-implementation.md)

## Scope

Implementation date: May 27, 2026

This part records the Stage 5 code work after the manager implementation-plan gate in [Part 5](part-05-manager-implementation-plan-gate.md).

## Starting state

The worktree already had uncommitted documentation and memory changes before this implementation pass. The Phase 5 design and implementation documents were untracked at task start. This part records only the Stage 5 implementation evidence added during this pass.

## Step evidence

### Step 5.1 and 5.2: descriptor, hot-store, and validation seams

Status: complete.

Planned files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

Planned behavior:

- Move exact blob payload bytes out of `hybrid_cache_entry`.
- Add descriptor and hot payload records with deterministic IDs.
- Validate descriptor version, kind, pair state, sizes, checksums, store refs, owner entry, and residency before admission and restore.
- Keep LRU policy byte-oriented and driven by descriptor byte fields.

Changed files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`

Implementation notes:

- Added `payload_descriptor`, `hot_payload_record`, `payload_store_ref`, and Stage 5 enum values for kind, pair state, and residency.
- Replaced direct exact blob ownership in `hybrid_cache_entry` with `payload_id` plus descriptor-derived cached fields used by the existing LRU candidate path.
- Added a local FNV-1a checksum helper for serialized byte buffers.
- Added descriptor admission and restore validation helpers with reason strings and Stage 5 stats counters.

### Step 5.3 through 5.6: production migration, restore transaction seam, and metrics

Status: complete.

Changed files:

- `tools/server/server-context.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

Implementation notes:

- `save_slot` now serializes target and draft bytes into temporary vectors, creates and validates a descriptor, then admits the entry and hot payload record together.
- Equivalent-entry refresh still preserves the existing Stage 4 behavior: it refreshes recency and protection without replacing the payload.
- `load_slot` and `try_restore_from_cache` validate descriptors and resolve hot payload records before live state restore.
- Restore failure paths capture the live slot prompt state and any available serialized target/draft state before applying payload bytes. Target and draft apply failures restore that snapshot and fall back without hit accounting or recency refresh.
- Added Prometheus metrics for descriptor validation failures, pairing violations, fallback restores, hot descriptors, and evicted descriptors.

Review-fix update:

- [Part 8](part-08-review-fix-evidence.md) fixes the empty pre-restore rollback limitation found in implementation review. Production rollback now restores serialized pre-images when available and clears a target or draft sequence when that side had no serialized pre-restore bytes. The clear path is checked before payload bytes are applied.

### Step 5.7 and 5.8: focused tests and server regression shape

Status: complete.

Changed files:

- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

Implementation notes:

- Added focused controller coverage for target-only and target-plus-draft descriptors, pair mismatch, checksum failure, evicted descriptor rejection, paired byte accounting, and restore transaction failure counters.
- Extended metrics-shape regression checks so legacy and hybrid metrics expose the new Stage 5 counters and gauges.

### Step 5.9: build and test evidence

Status: complete.

Commands run:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
cmake --build build --config Release --target llama-server -j 4
$env:LLAMA_SERVER_BIN_PATH=(Resolve-Path build/bin/Release/llama-server.exe); $env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'; pytest tools/server/tests/unit/test_cache_modes.py
cmake --build build --config Release --target test-cache-controller -j 4; if ($LASTEXITCODE -eq 0) { ctest --test-dir build -C Release -R test-cache-controller --output-on-failure }
cmake --build build --config Release --target llama-server -j 4
```

Observed results:

- `test-cache-controller` build: passed.
- `ctest -R test-cache-controller`: passed, 1/1 test, latest run 0.04 seconds.
- `llama-server` build: passed.
- `pytest tools/server/tests/unit/test_cache_modes.py`: 2 passed, 1 xfailed. The xfail is the existing hybrid repeated-restore exposure limitation in the test file, not a new Stage 5 failure.

Coverage evidence:

- No C++ line coverage command was available in this configured build. The coverage gap is recorded as a limitation.
- Focused C++ tests cover descriptor creation, pair mismatch, checksum failure, evicted descriptor rejection, descriptor byte accounting, and restore transaction failure counters.
- Python metrics-shape coverage confirms the new Stage 5 Prometheus metrics are exported for the cache metrics endpoint.

## Final implementation status

Status: ready for implementation review.

Changed files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`
- `._design_docs/cache-handling-phase5-implementation.md`
- `._design_docs/cache-handling-phase5-implementation/part-06-implementation-evidence.md`

Document index:

- No `document-index.md` update was made in this implementation pass. The new part is linked from the Phase 5 implementation entry, and the index already points readers to that entry rather than listing individual part files.

Remaining risk:

- No full model-backed target-plus-draft live-slot probe was added during the Part 8 fix pass because this workspace does not provide a small fixture for that path. The focused failure-injection regression covers the empty-preimage rollback branch, and `llama-server` build evidence covers the production code path.

### Step 5.10: draft context compatibility key correction

Status: complete.

Changed files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tests/test-cache-controller.cpp`

Implementation notes:

- Added explicit draft context mode identity to the hybrid compatibility key.
- The key now distinguishes no draft context, normal separate draft model, target-derived `draft-mtp`, and separate-model `draft-mtp`.
- Separate draft model identity now includes the configured draft model source as well as runtime model dimensions when a real draft context is available.
- Added focused controller regression coverage for H57/N25/N26 namespace isolation without loading GGUF files.
- H57 maps to pairwise namespace differences across all four runtime modes. N25 maps to normal separate draft versus both MTP modes. N26 maps to both MTP modes versus normal separate draft.

Evidence:

- `cmake --build build --config Release --target test-cache-controller -j 4`: passed.
- `ctest --test-dir build -C Release -R test-cache-controller --output-on-failure`: passed, 1/1 test, latest run 0.04 seconds.
