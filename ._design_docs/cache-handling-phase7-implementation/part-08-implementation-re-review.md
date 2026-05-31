# Stage 7 implementation re-review - Part 8

Source: [../cache-handling-phase7-implementation.md](../cache-handling-phase7-implementation.md)  
Review date: May 31, 2026  
Reviewer: Architect agent  
Verdict: REWORK

## Scope reviewed

Reviewed the corrected Stage 7 implementation after Part 7 against the accepted design, the approved
implementation plan, and the Part 6 blocking findings.

Documents checked:

- [document-index.md](../document-index.md)
- [Stage 7 design entry](../cache-handling-phase7-design.md)
- Stage 7 design Parts 02-07B, 10, and 11
- Stage 7 implementation entry and Parts 01-07
- [Part 6 implementation review](part-06-implementation-review.md)
- [Part 7 review corrections](part-07-review-corrections.md)
- Stage 4 protected-root budget behavior
- Stage 5 save, restore, eviction, and pairing behavior
- Stage 6 promotion, demotion, and persistence behavior

Code and tests checked:

- `tools/server/server-cache-graph.h`
- `tools/server/server-cache-graph.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tools/server/server-cache-controller.h`
- `tools/server/server-cache-legacy.h`
- `tools/server/CMakeLists.txt`
- `tests/CMakeLists.txt`
- `tests/test-step12-branch-graph.cpp`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

This was a code and documentation re-review. I did not rerun the build or test commands recorded in
Part 7.

## Part 6 finding status

| Finding | Status | Re-review note |
| --- | --- | --- |
| R1: production slot refs and active-ref eviction block | RESOLVED | Production slot state now carries `hybrid_cache_branch_node_id`. `save_slot()`, `try_restore_from_cache()`, and `load_slot()` acquire refs after selecting the node. `prompt_clear()` releases the held ref through the controller callback. `build_policy_candidates()` starts from forest candidates and counts active-ref blocks before policy planning. |
| R2: forest-backed hot-payload eviction | RESOLVED | `build_policy_candidates()` now adapts `forest.payload_eviction_candidates(0)` into the Stage 4 LRU policy candidate shape. The forest orders unprotected payloads before protected-root payloads, then by `use_sequence` and `insertion_sequence`. |
| R3: length-qualified checksum lookup in production restore selection | RESOLVED | `find_best_match()` and `try_restore_from_cache()` merge token-span candidates with `find_nodes_by_checksum_span()` candidates when boundary metadata supplies a prefix checksum. Namespace validation happens before payload validation, promotion, or live slot mutation. |
| R4: accepted Stage 7 Prometheus metrics | OPEN | Several Part 6 names are now exported and covered, but the accepted metrics surface is still incomplete. Details below. |
| R5: Stage 7 document size and navigation | RESOLVED | Stage 7 design Part 07 is split into Part 07A and Part 07B. The Stage 7 design and implementation markdown files are all under 300 lines. |

## Blocking finding

### R4: Stage 7 Prometheus metrics still do not match the accepted design

The accepted Stage 7 metrics table says all new metrics are exposed through `/metrics`. It includes
`cache_branch_lookups_total` with `namespace` and `method` labels and
`cache_branch_traversals_total` with an `operation` label.

The corrected export in `tools/server/server-context.cpp` still writes only a mode-level
`cache_branch_lookups_total` counter from `n_branch_token_lookups`. It does not expose checksum
lookups as a separate `method` label, does not include a namespace label, and does not export
`cache_branch_traversals_total` at all. The Python metrics test checks for the unlabelled
`cache_branch_lookups_total` name and does not check traversal metrics or the accepted lookup label
shape.

Required correction:

- Export `cache_branch_traversals_total` or update the accepted Stage 7 design through a reviewed
  design correction if traversal metrics are intentionally deferred.
- Export `cache_branch_lookups_total` with the accepted `namespace` and `method` label surface, or
  record and review a design correction that narrows that contract.
- Extend `tools/server/tests/unit/test_cache_modes.py` to check the accepted Stage 7 metrics shape,
  not only the reduced mode-level names.
- Keep the Stage 4, Stage 5, and Stage 6 metric names that remain present in the current metrics
  test.

## Regression check

Stage 5 descriptor and target/draft pairing behavior appears preserved. The restored paths still run
descriptor validation and pair-state checks before committing usage and slot state, and the rollback
path still avoids reporting a hit on failed target or draft apply.

Stage 6 cold residency behavior appears preserved. Forest nodes mirror descriptor residency, and the
budget path selects payload candidates before calling the existing eviction/demotion flow. I did not
find a correction that splits target and draft bytes or bypasses cold promotion/demotion state
checks.

## Evidence reviewed

Part 7 records passing evidence for:

- `test-cache-controller`
- `llama-server`
- `tools/server/tests/unit/test_cache_modes.py`
- `test-step12-branch-graph`
- Stage 6 demotion, promotion, and metrics regression targets
- Stage 7 document line-count check

Those results are useful but do not close R4 because the current tests assert the reduced metrics
shape rather than the accepted design surface.

## Gate decision

Implementation re-review verdict: REWORK.

Handoff state: CORRECTION LOOP REQUIRED.

The next correction pass should be limited to the Stage 7 observability contract unless the design
is intentionally changed and re-reviewed.
