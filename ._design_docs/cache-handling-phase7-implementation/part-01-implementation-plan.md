# Stage 7 implementation plan - Part 1

Source: [../cache-handling-phase7-implementation.md](../cache-handling-phase7-implementation.md)

## Status

Planning date: May 31, 2026  
Implementation state: not started  
Plan state: ready for independent implementation-plan review

Code implementation remains closed until this plan passes independent Architect review and manager
approval.

## Accepted design baseline

Implement Stage 7 against the accepted design in
[cache-handling-phase7-design.md](../cache-handling-phase7-design.md), especially Parts 02, 03, 04,
05, and 06. The latest independent design review is
[Part 10](../cache-handling-phase7-design/part-10-independent-design-re-review.md), verdict PASS.
The manager design gate is
[Part 11](../cache-handling-phase7-design/part-11-manager-design-gate.md), verdict PASS, dated May
31, 2026.

Binding decisions from the gate:

- `branch_node` is the first-class cache metadata object. It stores token spans, prefix checksums,
  namespace identity, usage, residency, payload references, protection state, and slot refs.
- `branch_forest_index` is one shared forest across all namespaces, not one index per namespace.
- Namespace compatibility is strict equality before restore.
- Token-span lookup uses stored `token_span`; checksum lookup is length-qualified through
  `prefix_checksums`.
- Branch metadata RAM is accounted and diagnosed with an internal/test-only soft limit. Stage 7
  must not prune, orphan, reparent, delete, or convert graph nodes due to metadata pressure.
- Hot payload RAM remains globally enforced across namespaces.
- Protected roots protect graph metadata and topology. Their payload bytes still count against the
  hot-payload budget and can be demoted or evicted after unprotected candidates are exhausted.
- Branch pruning, metadata-only nodes, equivalent-branch deduplication, and checkpoint-first
  restore stay deferred to later stages.

## Current code baseline

Relevant current files:

- `tools/server/server-cache-hybrid.h`: owns `hybrid_cache_entry`, `payload_descriptor`,
  `hot_payload_record`, cold residency states, LRU indexes, compatibility key helpers, stats, and
  cache test hooks.
- `tools/server/server-cache-hybrid.cpp`: save/load, exact lookup, descriptor validation,
  target/draft restore validation, Stage 4/5/6 budget behavior, cold demotion/promotion, metrics,
  and test helpers live here.
- `tools/server/server-cache-controller.h` and `.cpp`: cache-mode configuration boundary.
- `tools/server/server-cache-store-cold.*` and `server-cache-io-worker.*`: Stage 6 cold layer and
  async worker. Stage 7 must preserve their descriptor and residency contracts.
- `tools/server/server-cache-policy-lru.*`: Stage 4 byte-accounted payload policy. Stage 7 may
  move candidate selection into the forest, but protected-root behavior must remain equivalent.
- `tools/server/server-context.cpp`: production save/restore caller path and prompt reuse behavior.
- `tools/server/CMakeLists.txt` and `tests/CMakeLists.txt`: source and test target wiring.
- `tests/test-cache-controller.cpp`: existing Stage 1-6 focused cache coverage.
- `tests/test-step1-state-machine.cpp` through `tests/test-step11-test-hooks-fault-injection.cpp`:
  Stage 6 step targets.
- `tools/server/tests/unit/test_cache_modes.py`: cache mode, metrics shape, and server-level checks.

## Ordered implementation plan

### Step 7.1: Branch graph header

Goal: add `tools/server/server-cache-graph.h` with `branch_node`, `namespace_key`,
`branch_forest_index` declarations, and `validate_namespace_compatibility()`.

Affected files:

- `tools/server/server-cache-graph.h` (new)

Tests:

- New focused C++ assertions for default fields, metadata byte accounting, namespace hash
  determinism, and compatibility equality.

Dependencies: none.

### Step 7.2: Branch forest implementation

Goal: add `tools/server/server-cache-graph.cpp` with lifecycle, lookup, traversal, namespace,
metadata accounting, slot ref, and payload candidate APIs.

Affected files:

- `tools/server/server-cache-graph.cpp` (new)

Tests:

- Node create/remove, parent-child traversal, token-span lookup, length-qualified checksum lookup,
  namespace listing, slot ref acquire/release, ref-blocked removal, and concurrent mixed operation
  tests.

Dependencies: Step 7.1.

### Step 7.3: Build wiring and standalone test target

Goal: compile the branch graph module before changing production cache flow.

Affected files:

- `tools/server/CMakeLists.txt`
- `tests/CMakeLists.txt`
- `tests/test-step12-branch-graph.cpp` (new)

Tests:

- Build `test-step12-branch-graph`.
- Run `ctest --test-dir build -C Release -R test-step12-branch-graph --output-on-failure`.

Dependencies: Steps 7.1 and 7.2.

### Step 7.4: Hybrid controller forest integration

Goal: replace the flat `std::list<hybrid_cache_entry>` ownership model with
`branch_forest_index` while preserving Stage 5 descriptors and Stage 6 cold residency behavior.

Affected files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp` if production caller state must carry branch node identity

Work items:

- Add a forest member to `hybrid_cache_controller`.
- Migrate save admission to create or refresh branch nodes and attach existing payload descriptor
  references.
- Replace exact lookup with token-span and checksum candidate lookup from the forest.
- Keep descriptor validation, pair-state validation, transaction rollback, and cold promotion
  checks before live slot mutation.
- Keep payload descriptor ownership clear: branch nodes reference payload descriptors; they do not
  own hot bytes directly.

Tests:

- Existing `test-cache-controller` save/load, descriptor validation, rollback, eviction, and cold
  tests still pass.
- New branch-backed save/load tests cover exact hit persistence and no one-shot consumption.

Dependencies: Step 7.3.

### Step 7.5: Namespace validation before restore

Goal: reject cross-namespace restore before resolving or applying payload bytes.

Affected files:

- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h` if stats or test hooks need declarations

Tests:

- Same namespace restore succeeds.
- Different namespace restore returns a miss, does not mutate slot state, and increments namespace
  validation failure diagnostics.
- Draft context modes remain distinguished in namespace computation.

Dependencies: Steps 7.1 and 7.4.

### Step 7.6: Slot reference model

Goal: make slots hold transient references to branch nodes without owning or consuming them.

Affected files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp` if slot lifecycle hooks are needed

Tests:

- Two slots can hold the same node.
- Releasing one slot leaves the node available for the other.
- Active refs block graph removal and payload eviction candidate selection.
- Releasing the final ref makes the payload eligible for normal eviction or demotion.

Dependencies: Steps 7.2 and 7.4.

### Step 7.7: Shared budget and global payload eviction

Goal: add branch metadata accounting and drive hot payload eviction through global forest
candidates across namespaces.

Affected files:

- `tools/server/server-cache-controller.h`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-policy-lru.*` only if the policy interface needs a forest-backed
  candidate shape

Tests:

- Metadata soft-limit diagnostics fire without graph removal or topology changes.
- Global LRU selects payloads across namespaces by `use_sequence`, then `insertion_sequence`.
- Active slot refs block payload selection.
- Stage 4 unlimited, disabled, and protected-root budget behavior remains unchanged.

Dependencies: Steps 7.4 and 7.6.

### Step 7.8: Protected root graph preservation

Goal: preserve protected root metadata and topology while allowing protected-root payload demotion
or eviction under the accepted Stage 4 behavior.

Affected files:

- `tools/server/server-cache-graph.cpp`
- `tools/server/server-cache-hybrid.cpp`

Tests:

- Protected root graph nodes survive payload pressure.
- Unprotected payloads are selected before protected-root payloads.
- Protected-root payloads are demoted or evicted oldest first when protected bytes alone keep the
  hot payload budget over limit.
- Oversized protected-root payload admission is rejected before insertion.

Dependencies: Steps 7.2 and 7.7.

### Step 7.9: Metrics, diagnostics, and `/cache` output

Goal: expose branch graph, namespace, budget, slot ref, eviction, and validation evidence through
the existing stats, Prometheus, log, and diagnostics paths.

Affected files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

Tests:

- Focused stats tests check new counters and gauges.
- Python metrics-shape coverage confirms the new Prometheus metric names without removing Stage
  4/5/6 names.
- `/cache` diagnostics includes branch forest totals, namespace counts, metadata bytes,
  over-limit state, protected roots, and active slot refs.

Dependencies: Steps 7.5 through 7.8.

### Step 7.10: Regression, evidence, and handoff docs

Goal: prove Stage 7 behavior and update durable implementation evidence after code work opens.

Affected files:

- `._design_docs/cache-handling-phase7-implementation.md`
- Later `._design_docs/cache-handling-phase7-implementation/part-XX-*.md` files if this log grows
  past 300 lines
- `._design_docs/cache-handling-test-plan.md` if reusable Stage 7 QA execution rules change
- `._design_docs/document-index.md` if new parts are added

Tests and evidence:

- Build `llama-server` and all affected focused test targets.
- Run `test-step12-branch-graph`, `test-cache-controller`, Stage 6 step tests that cover cold
  demotion/promotion, and server metrics tests.
- Run TSAN or the configured thread-safety sanitizer for branch forest concurrency if available.
  If unavailable, record the attempted command and environment limitation.
- Record changed files, behavior changes, exact commands, results, coverage evidence or coverage
  limitations, and unresolved risks after each implementation step.

Dependencies: all prior steps.
