# Phase 5 implementation plan: payload-metadata separation and target/draft pairing

Source: [../cache-handling-phase5-implementation.md](../cache-handling-phase5-implementation.md)

## Status

Planning date: May 27, 2026  
Implementation state: not started  
Plan state: ready for independent implementation-plan review  
Approved design baseline: [Phase 5 design](../cache-handling-phase5-design.md), especially [Part 3](../cache-handling-phase5-design/part-03-save-restore-eviction-and-pairing-behavior.md), [Part 4](../cache-handling-phase5-design/part-04-validation-diagnostics-and-observability.md), [Part 5](../cache-handling-phase5-design/part-05-testability-and-requirement-traceability.md), and [Part 9](../cache-handling-phase5-design/part-09-independent-design-re-review.md)

Stage 5 is cleared for implementation planning by the manager design gate in [Phase 5 design Part 10](../cache-handling-phase5-design/part-10-manager-design-gate.md). This plan must not be treated as code evidence.

## Design baseline

Implement Stage 5 against these accepted decisions:

- `PayloadDescriptor` is the first-class metadata record for exact blob payloads.
- Serialized target and draft bytes move out of `hybrid_cache_entry::data` into a hot payload store owned by the hybrid controller.
- Each descriptor has exactly one owner cache entry.
- Stage 5 admits only hot exact blob payloads. `checkpoint` and `cold` remain reserved values.
- Runtime shape decides legal pair state: no draft context requires `target_only`; a draft context requires `target_and_draft`.
- Save, restore, eviction, validation, and future offload references must treat target and draft as one pair.
- Descriptor validation covers version, kind, pair state, sizes, checksums, store reference, residency, and owner entry.
- Target-plus-draft restore is transactional. It must use scratch staging or a pre-restore live-slot snapshot before live mutation.
- Restore recency, usage, and exact-hit metrics update only after the full transaction commits.
- Stage 4 LRU policy behavior, protected-root priority, `--cache-ram` semantics, and legacy mode behavior stay unchanged.
- No cold files, async I/O, branch graph nodes, checkpoint admission, public cache stats endpoint, or new CLI flags are part of this stage.

## Current code baseline

Relevant current files:

- `tools/server/server-cache-hybrid.h`: `hybrid_cache_entry` owns `server_prompt_data data`; stats, indexes, test helpers, and controller fields live here.
- `tools/server/server-cache-hybrid.cpp`: controller helpers, admission test hooks, LRU candidate construction, byte accounting, eviction execution, and namespace helpers live here.
- `tools/server/server-context.cpp`: production hybrid `save_slot`, `try_restore_from_cache`, and `load_slot` are implemented here with direct `data.main` and `data.drft` access.
- `tools/server/server-cache-policy-lru.h` and `.cpp`: Stage 4 policy receives resident payload bytes and target/draft presence only.
- `tests/test-cache-controller.cpp`: focused controller tests and policy tests run without a live model context.
- `tools/server/tests/unit/test_cache_modes.py`: server cache mode and metrics-shape tests.
- `tools/server/CMakeLists.txt` and `tests/CMakeLists.txt`: build wiring for new sources or test targets.

The current code already has deterministic `entry_id`, `use_sequence`, Stage 4 resident byte accounting, protected-root stats, and failed-restore no-refresh coverage. It does not have descriptor objects, a hot payload store, checksum validation, pair-state validation as a separate seam, or transactional rollback for draft failure after target apply success.

## Data structures and interfaces

Add small internal types before changing production flow:

- `payload_kind`: `exact_blob` now; reserve `checkpoint`.
- `payload_pair_state`: `target_only` and `target_and_draft`.
- `payload_residency_state`: `hot` and `evicted`; reserve `cold` but reject it in Stage 5 validation.
- `payload_store_ref`: an opaque hot-store handle, not a raw vector pointer exposed to policy.
- `payload_descriptor`: fields from the design, including ID, kind, pair state, version, sizes, checksums, store reference, residency, owner entry, creation sequence, and validation sequence.
- `hot_payload_record`: owns serialized target bytes and optional draft bytes.
- `payload_descriptor_registry` or controller-owned equivalent: creates descriptors, validates descriptors, resolves store refs, marks evicted descriptors, and removes descriptors with their owner entry.
- `payload_pairing_validator`: checks descriptor pair state against runtime target/draft shape and payload presence.
- `restore_transaction` or restore applier seam: stages or snapshots target and draft state, commits only after all required sides apply, and rolls back to the pre-restore slot state on failure.

Keep the LRU policy interface byte-oriented. It may receive descriptor-derived resident byte fields and target/draft presence flags, but it must not validate descriptors or read payload bytes.

## Ordered implementation steps

### Step 5.1: Introduce descriptor and hot-store types

Add internal descriptor, enum, store reference, and hot payload record types. Put them near the hybrid controller or in new `server-cache-payload.*` files if the source stays clearer that way.

Add deterministic ID and validation sequence generation for tests. Add a byte-range checksum helper with fixed test vectors. Prefer an existing project helper if one fits serialized byte buffers; if no suitable helper exists, keep the new helper local to Stage 5 payload validation and document the algorithm in the implementation evidence.

### Step 5.2: Build descriptor validation and pairing seams

Add admission and restore validators that can run without a live model context. Cover version, kind, residency, owner entry, store ref, sizes, checksums, pair state, runtime draft presence, missing target, missing draft, and unexpected draft bytes.

Validation must return reasoned failures so diagnostics, metrics, and tests can distinguish descriptor validation failures from ordinary lookup misses.

### Step 5.3: Migrate exact blob entries to descriptor-owned payloads

Replace direct ownership of `server_prompt_data data` in `hybrid_cache_entry` with descriptor identity or a descriptor handle. During save, serialize target and draft bytes into temporary payload records first, build and validate a descriptor, then admit the entry and store record together.

Required migration behavior:

- A failed new save leaves existing cache state unchanged.
- A failed equivalent-entry refresh leaves the previous valid descriptor and payload intact.
- Entry deletion removes the descriptor and payload record exactly once.
- Resident bytes come from descriptor fields, not from `data.main.size() + data.drft.size()`.
- Test helpers create descriptors through the same validation path unless a test explicitly injects malformed descriptors.

### Step 5.4: Preserve Stage 4 eviction through descriptor accounting

Change policy candidates to read resident bytes, target presence, and draft presence from descriptors. Eviction must remove target and draft bytes together and then either remove the descriptor with the entry or mark it `evicted` if retained for diagnostics.

Keep these Stage 4 behaviors unchanged:

- `--cache-ram -1` means unlimited.
- `--cache-ram 0` disables prompt cache allocation through the existing startup path.
- Protected roots have higher retention priority but still count against the budget.
- Equivalent-entry refresh enforces the payload budget.
- Protected-root decision and payload eviction metrics continue to fire.

### Step 5.5: Add transactional restore

Refactor `try_restore_from_cache` and `load_slot` to validate the descriptor and resolve hot payload bytes before touching live target or draft state.

Preferred implementation: stage target and draft restore outside the live slot, then commit both sides together. If the llama state API does not allow scratch staging, take a pre-restore snapshot of the live slot state before applying either side.

Required failure behavior:

- Validation failure leaves the live slot untouched and falls back.
- Target apply failure restores the pre-restore state and falls back.
- Draft apply failure after target apply success restores the exact pre-restore state and falls back.
- Commit failure restores the exact pre-restore state and falls back.
- Rollback failure is a restore failure diagnostic and must not be counted as a hit.
- No failure path refreshes recency, updates usage, or increments exact-hit metrics.

Do not use reset-to-empty as the generic rollback unless the captured pre-restore state was empty.

### Step 5.6: Add diagnostics, stats, and Prometheus metrics

Extend hybrid stats with descriptor and pairing fields without removing Stage 4 fields:

- descriptor validation failures
- pairing violations
- restore failures by descriptor, pairing, target apply, draft apply, commit, and rollback reason where practical
- fallback restores
- hot descriptor count
- evicted descriptor count if retained
- target-only descriptor count
- target-plus-draft descriptor count

Add Prometheus output in the existing cache metrics path for the required Stage 5 counters. Keep labels or structured counters small and compatible with the current export style.

Diagnostics must include entry ID, payload ID, kind, pair state, runtime draft presence, version, residency, byte sizes, failure reason, transaction phase, and fallback reason. Do not log serialized payload bytes, request text, or sensitive checksums.

### Step 5.7: Add focused unit and regression tests

Extend `tests/test-cache-controller.cpp` or add a focused test target if the file becomes too broad. Required coverage includes:

- descriptor creation for target-only and target-plus-draft exact blobs
- unsupported version, size mismatch, checksum mismatch, missing target, missing draft, unexpected draft, evicted residency, stale store ref, and owner mismatch rejection
- runtime pair mismatch rejection in both directions
- save failure and equivalent refresh failure leave old entries intact
- resident byte accounting uses descriptor fields
- eviction removes paired bytes together and never leaves one side hot
- evicted descriptors cannot restore
- successful restore refreshes recency only after transaction commit
- failed validation leaves live target and draft state untouched
- target apply failure rolls back and reports fallback
- draft apply failure after target success rolls back and reports fallback
- commit failure rolls back and reports fallback
- failure paths do not increment exact-hit metrics or usage
- descriptor and pairing diagnostics or metrics increment on the right failures

Keep existing Stage 1 through Stage 4 tests passing.

### Step 5.8: Add server-level regression and failure-injection coverage

Extend Python or C++ integration tests only where unit tests cannot prove the visible behavior. Cover:

- legacy mode unchanged
- hybrid exact blob save/restore still works after descriptor separation
- Stage 4 LRU and protected-root behavior still use the same resident-byte budget
- metrics include Stage 5 counters without removing Stage 4 metrics
- fallback runs when descriptor validation rejects a selected candidate
- target-plus-draft failure injection proves there is no half-restored public slot state

Use explicit test hooks for malformed descriptors and restore applier failures. Do not require model-backed corruption tests when a deterministic focused seam proves the same branch.

### Step 5.9: Build, test, and document evidence

Expected verification commands:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
cmake --build build --config Release --target llama-server -j 4
pytest tools/server/tests/unit/test_cache_modes.py
```

If the environment supports clean-build QA evidence for this stage, use the clean build procedure from [cache-handling-test-plan.md](../cache-handling-test-plan.md) before final sign-off.

Coverage target: at least 80 percent line coverage for new or materially changed Stage 5 hybrid cache code. If coverage tooling is unavailable, record the attempted command, why it could not run, and the concrete unit and regression coverage that did run.

After each implementation step, update this implementation log with changed files, behavior changes, exact build and test results, coverage evidence or limitations, and unresolved risks.

## Documentation updates during implementation

Update these durable documents as code lands:

- [cache-handling-phase5-implementation.md](../cache-handling-phase5-implementation.md): current status and part links.
- This part or later implementation evidence parts: completed steps, changed files, test evidence, and deviations.
- [cache-handling-test-plan.md](../cache-handling-test-plan.md): Stage 5 implemented scope, exclusions, and evidence rules.
- Test-plan part files if Stage 5 adds reusable failure-injection or metrics checks.
- [document-index.md](../document-index.md): new implementation parts or test-plan documents.

Do not update Phase 5 design documents for implementation details unless implementation exposes a design gap. A design gap blocks the step until the design is corrected and reviewed.

## Risks and blockers

- The live llama state API may not provide true scratch staging. If so, implementation must prove snapshot rollback restores the exact pre-restore slot state.
- Current `try_restore_from_cache` and `load_slot` have duplicate direct restore logic. Refactoring them carelessly can create divergent transaction behavior.
- Existing debug helpers create byte vectors directly. They must move to descriptor-aware helpers without hiding malformed-descriptor test cases.
- Checksum overhead may be visible on hot restores. Correctness comes first, but implementation evidence should record basic timing or justify deferring benchmarks.
- Retaining evicted descriptors for diagnostics can look like Stage 8 metadata-only nodes. Keep retention short-lived and non-restorable, or remove descriptors with entries.
- New metrics must not double count existing Stage 4 restore failure and payload eviction counters.
- Draft-model integration coverage has been thin in earlier stages. Stage 5 cannot sign off without target-plus-draft failure-injection coverage.

## Review readiness

This implementation plan is ready for independent review when the reviewer can confirm:

- The plan starts from the current exact blob implementation and explains how to migrate `hybrid_cache_entry::data`.
- Descriptor, hot-store, pairing validator, and restore-transaction responsibilities are separate.
- The target-plus-draft transactional restore contract from the corrected design is implemented as a required step, not left to interpretation.
- Ordered steps preserve Stage 4 LRU, protected-root, budget, metrics, and legacy behavior.
- Validation, diagnostics, stats, Prometheus metrics, unit tests, regression tests, and failure-injection tests are explicit.
- Evidence and coverage expectations are concrete.
- No code change is included in this planning task.
