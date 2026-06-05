# Stage 7 implementation review - Part 6

Source: [../cache-handling-phase7-implementation.md](../cache-handling-phase7-implementation.md)  
Review date: May 31, 2026  
Reviewer: Architect agent  
Verdict: REWORK

## Scope reviewed

Reviewed the Stage 7 implementation against the accepted design, approved implementation plan, and
prior-stage contracts.

Documents checked:

- [document-index.md](../document-index.md)
- [Stage 7 design entry](../cache-handling-phase7-design.md)
- Stage 7 design Parts 02-06, 10, and 11
- Stage 7 implementation entry and Parts 01-05
- [Stage 4 protected-root budget behavior](../cache-handling-phase4-design/part-03-protected-root-budget-behavior.md)
- [Stage 5 save, restore, eviction, and pairing behavior](../cache-handling-phase5-design/part-03-save-restore-eviction-and-pairing-behavior.md)
- [Stage 5 validation, diagnostics, and observability](../cache-handling-phase5-design/part-04-validation-diagnostics-and-observability.md)
- [Stage 6 promotion, demotion, and persistence behavior](../cache-handling-phase6-design/part-03-promotion-demotion-and-persistence-behavior.md)

Code and tests checked:

- `tools/server/server-cache-graph.h`
- `tools/server/server-cache-graph.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tools/server/CMakeLists.txt`
- `tests/CMakeLists.txt`
- `tests/test-step12-branch-graph.cpp`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

Implementation evidence in Part 5 records passing focused tests, server metrics tests, and cold-path
regressions. TSAN and coverage were not run; those limitations are acceptable only after the
blocking design-conformance issues below are fixed.

## Blocking findings

### R1: Slot references are not integrated into production save/load or eviction

The approved design requires slot save and slot load to acquire a branch-node reference, and slot
release or overwrite to release it. It also requires active refs to block payload eviction candidate
selection. See Stage 7 design Part 03, lines 105-106, and the approved plan Part 01, line 176.

The implementation creates a branch node on save at `tools/server/server-context.cpp:5409`, then
calls `create_branch_node_for_entry()` at `tools/server/server-context.cpp:5411`, but it never calls
`forest.acquire_slot_ref()` for that saved slot. Restore paths update usage after successful restore
at `tools/server/server-context.cpp:5621` and `tools/server/server-context.cpp:5789`, but they also
do not acquire a branch ref for the slot that now uses the node. The only controller-level ref
acquire/release calls are debug hooks at `tools/server/server-cache-hybrid.cpp:716` and
`tools/server/server-cache-hybrid.cpp:723`; the focused controller test exercises those hooks at
`tests/test-cache-controller.cpp:177`, not production slot lifecycle.

Eviction also ignores active branch refs. `evict_until_within_budget()` builds its plan from
`build_policy_candidates()` at `tools/server/server-cache-hybrid.cpp:1188`, and
`build_policy_candidates()` scans `entries` without checking `forest.slot_ref_count()` at
`tools/server/server-cache-hybrid.cpp:1637`. As a result, a node can have an active ref in the forest
and still have its payload selected for demotion or eviction.

Required correction:

- Acquire a branch-node ref on production save and restore after the node is selected.
- Release the previous node ref on slot reset, overwrite, destruction, or replacement.
- Exclude active-ref nodes from production payload eviction or demotion candidates.
- Add a regression test that proves an active production slot ref blocks payload eviction, not only
  `debug_acquire_first_branch_ref_for_tests()`.

### R2: Hot-payload eviction is not driven by the forest-backed candidate API

The accepted design says Stage 7 eviction must use `forest.payload_eviction_candidates()` instead of
scanning a flat list. See Stage 7 design Part 03, line 55, and Part 02, section 2.7.

`branch_forest_index::payload_eviction_candidates()` exists at
`tools/server/server-cache-graph.cpp:371`, and standalone tests cover its ordering in
`tests/test-step12-branch-graph.cpp:144`. Production eviction never calls it. The controller still
uses the old entry-based policy path at `tools/server/server-cache-hybrid.cpp:1188`, backed by the
flat `entries` scan at `tools/server/server-cache-hybrid.cpp:1637`.

This preserves some Stage 4 ordering behavior, but it does not satisfy the Stage 7 contract because
forest-level residency, namespace topology, and active refs are not authoritative for payload
selection.

Required correction:

- Route production hot-payload eviction through forest candidates or prove an equivalent adapter
  that starts from forest candidate IDs and preserves Stage 4 protected-root ordering.
- Keep protected-root payload behavior unchanged: unprotected payloads first, protected roots only
  when needed, with protected-over-budget diagnostics.
- Add an integration test showing global eviction across namespaces through the production path.

### R3: Length-qualified checksum lookup is implemented only as an unused graph API

The accepted design makes checksum lookup part of the Stage 7 lookup contract. See design Part 02,
lines 98 and 147, and the approved plan Part 01, line 30.

`branch_forest_index::find_nodes_by_checksum_span()` is implemented at
`tools/server/server-cache-graph.cpp:220`, and `tests/test-step12-branch-graph.cpp:113` covers the
standalone API. The production lookup paths in `find_best_match()` and `try_restore_from_cache()`
only call `find_nodes_by_token_span()` at `tools/server/server-cache-hybrid.cpp:771` and
`tools/server/server-context.cpp:5436`. They never use boundary checksums from
`prepared_prompt_metadata` to query the forest.

Required correction:

- Integrate length-qualified checksum lookup into the production candidate path where boundary
  metadata supplies checksums.
- Keep namespace validation before payload resolution and before live slot mutation.
- Add controller-level coverage that proves checksum candidates participate in restore selection,
  not only the standalone graph test.

### R4: Stage 7 Prometheus observability is incomplete

Design Part 05 says the listed Stage 7 metrics are exposed through `/metrics`. The implementation
exports only a subset at `tools/server/server-context.cpp:4422`.

Missing required names include:

- `cache_namespace_count`
- `cache_namespace_nodes`
- `cache_namespace_roots`
- `cache_namespace_metadata_bytes`
- `cache_budget_branch_metadata_ratio`
- `cache_eviction_payloads_total`
- `cache_eviction_payload_bytes_total`
- `cache_eviction_payload_blocked_refs_total`
- `cache_protected_root_payload_decisions_total`
- `cache_protected_root_payload_bytes`
- `cache_slot_ref_acquires_total`
- `cache_slot_ref_releases_total`
- `cache_forest_lock_acquires_total`
- `cache_forest_lock_retries_total`
- `cache_namespace_validations_total`

The Python metrics test checks the reduced subset at
`tools/server/tests/unit/test_cache_modes.py:60`, so the evidence does not prove the accepted
observability surface.

Required correction:

- Export the full accepted Stage 7 Prometheus metric set or update the design through a new review
  if any metric is intentionally deferred.
- Add metrics-shape coverage for the full accepted set.
- Keep existing Stage 4, Stage 5, and Stage 6 metric names intact.

### R5: Documentation size rules are not satisfied

The review checklist requires each doc to stay under 300 lines. The current Stage 7 design Part 07
has 412 lines. That predates this review, but the gate cannot pass with the document tree in a known
non-conforming state.

Required correction:

- Split `._design_docs/cache-handling-phase7-design/part-07-independent-design-review.md` into
  smaller part files under the same Stage 7 design tree, or move historical detail into linked
  subparts while keeping navigation clear.
- Recheck all Stage 7 design and implementation markdown files for the 300-line rule.

## Non-blocking observations

- Stage 5 descriptor validation and transactional restore logic are still present. I did not find a
  new Stage 7 regression in the rollback path, but this needs another pass after slot refs are wired
  into restore.
- Stage 6 cold demotion and promotion contracts appear preserved at the descriptor level. The
  missing active-ref eviction filter can still let a payload used by a slot enter demotion, so R1
  must be fixed before the cold-path regression evidence is sufficient.
- Stage 8+ behavior was not introduced: metadata pressure records diagnostics and does not prune,
  reparent, delete, or convert graph nodes.

## Evidence assessment

Part 5 records real commands and passing results for:

- `test-step12-branch-graph`
- `test-cache-controller`
- `llama-server`
- `tools/server/tests/unit/test_cache_modes.py`
- Stage 6 demotion, promotion, and metrics step targets
- scoped `git diff --check`

The evidence is not sufficient for PASS because several tests exercise standalone APIs or debug
hooks while the production controller path does not meet the accepted design.

## Gate decision

Implementation review verdict: REWORK.

Handoff state: CORRECTION LOOP REQUIRED.

The next review should start from this part and verify the concrete corrections above against code,
tests, implementation evidence, and the Stage 7 entry-document status.
