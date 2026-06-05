# Cache handling test plan - Part 9: Stage 7 branch graph foundation

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Stage 7 scope

Stage 7 replaces the flat hybrid entry list with a shared branch forest. The implemented scope covers `branch_node`, `branch_forest_index`, strict namespace compatibility, slot references, branch-metadata RAM accounting, checksum-assisted lookup, and global hot-payload LRU selection across namespaces. Stage 6 cold storage remains in scope as a regression surface.

Design documents:

- [Stage 7 design](../cache-handling-phase7-design.md)
- [Part 4: test specifications](../cache-handling-phase7-design/part-04-test-specifications.md)
- [Part 5: metrics and observability](../cache-handling-phase7-design/part-05-metrics-and-observability.md)
- [Part 6: acceptance criteria](../cache-handling-phase7-design/part-06-acceptance-criteria.md)

Implementation documents:

- [Stage 7 implementation](../cache-handling-phase7-implementation.md)
- [Part 5: implementation evidence](../cache-handling-phase7-implementation/part-05-implementation-evidence.md)
- [Part 7: review corrections](../cache-handling-phase7-implementation/part-07-review-corrections.md)
- [Part 9: metrics correction](../cache-handling-phase7-implementation/part-09-metrics-correction.md)
- [Part 10: implementation re-review](../cache-handling-phase7-implementation/part-10-implementation-re-review.md)

## Out of scope for Stage 7 acceptance

This list applies only when executing the Stage 7 row set below. Stage 8 acceptance now lives in [Part 10](part-10-stage8-metadata-only-rematerialization.md).

Do not require these future-stage behaviors:

- metadata-only branch nodes
- equivalent-branch deduplication
- checkpoint-first restore
- branch pruning as a production lifecycle
- public metadata-budget CLI flags
- re-materialization from an ancestor payload
- tolerant namespace matching
- public `/cache/stats` success; it remains absent from the public HTTP surface unless a later stage changes it

## Evidence sources

Use all evidence sources that match the row under test. Do not mark a row `PASS` from a source that cannot create the required precondition.

| Source | Covers | Limits |
| --- | --- | --- |
| `test-step12-branch-graph` | branch node defaults, namespace key hashing, lifecycle, traversal, token and checksum lookup, slot ref counting, eviction candidate ordering, concurrent ref acquire/release | Does not start `llama-server` and does not prove model-backed restore |
| `test-cache-controller` | controller stats, metadata soft-limit diagnostics, slot refs blocking production eviction, global eviction across namespaces, checksum lookup candidate selection | Uses focused controller fixtures, not public HTTP |
| `tools/server/tests/unit/test_cache_modes.py` | public metric shape for legacy and hybrid modes, missing `/cache/stats`, simple model-backed hybrid restore path | Does not cover every Stage 7 branch policy precondition |
| PowerShell integration runner | clean report creation, server startup, public HTTP requests, metrics snapshots, logs | Has no dedicated Stage 7 row matrix yet |
| Stats-capable or fault-injection harness | internal entry identity, protected-root preconditions, corrupted or mismatched state | Mark rows `BLOCKED` if this harness is unavailable |

## Positive coverage

| ID | Scenario | Expected result |
| --- | --- | --- |
| G70 | Branch node creation and metadata accounting | New nodes have stable IDs, namespace IDs, payload references, token/checksum spans, protected-root state, and nonzero metadata RAM estimates. |
| G71 | Forest lifecycle and traversal | Root, child, and descendant relationships can be queried. Parent removal fails while children remain. Protected roots are not removed by ordinary test teardown. |
| G72 | Token-span lookup | Prefix lookup returns only same-namespace candidates whose token spans satisfy the requested minimum match length. |
| G73 | Length-qualified checksum lookup | Checksum lookup returns candidates only when checksum and match-token length both match. Wrong length or namespace returns no candidate. |
| G74 | Multi-slot references | Two slots can reference the same node. Releasing one slot does not remove the node or make the other slot unable to restore. |
| G75 | Slot refs block payload eviction | Payload candidates with active refs are excluded from hot-payload eviction or demotion selection. |
| G76 | Namespace isolation | Same namespace restores may hit. Cross-namespace restore attempts miss and increment namespace validation failure evidence. |
| G77 | Multi-namespace coexistence | Nodes from multiple namespaces remain visible in controller stats. Namespace node, root, and metadata counts are independent. |
| G78 | Global hot-payload LRU | Under hot budget pressure, payload eviction candidates are ordered globally across namespaces by unprotected-before-protected policy and LRU sequence, not per namespace. |
| G79 | Metadata soft-limit diagnostics | Setting the internal metadata soft max below current usage reports over-limit metrics and diagnostics without pruning or reparenting branch nodes. |
| G80 | Checksum-assisted restore candidate | A longer request can select a cached prefix candidate through checksum lookup when token lookup alone is insufficient. |
| G81 | Stage 1-6 regression | Existing save/load, descriptor ownership, draft pairing, cold demotion/promotion, and public HTTP surface behavior remain valid after forest-backed integration. |

## Negative and blocked-precondition coverage

| ID | Scenario | Expected result |
| --- | --- | --- |
| G82 | Cross-namespace restore attempt | Restore is rejected as a miss before payload application. No hit, usage refresh, or slot mutation is counted for the unsafe candidate. |
| G83 | Remove node with active slot refs | Removal fails and the node remains queryable. |
| G84 | Remove retained parent | Removal fails while descendants remain linked to the parent. |
| G85 | Metadata pressure | Over-limit metadata soft-limit checks do not remove nodes, drop refs, or change topology. |
| G86 | Protected-root pressure | Unprotected payloads are selected before protected-root payloads. If protected payloads alone exceed budget, protected payload demotion or eviction is allowed with diagnostics, but graph metadata remains. |
| G87 | Active ref under budget pressure | A referenced node is skipped as an eviction candidate. If all candidates are referenced, the row needs focused stats or fault-injection evidence and may be `BLOCKED` for public HTTP. |
| G88 | Metrics label shape | Stage 7 Prometheus metrics include accepted labels for namespace, method, traversal operation, action, residency, decision, and validation result. |
| G89 | Cold store regression | With `--cache-cold-path` configured, demotion and promotion update branch node residency mirrors and keep Stage 6 metrics valid. Use focused evidence if public HTTP cannot observe residency. |

## Observability

When `/metrics` is enabled, capture these Stage 7 names where relevant:

```text
cache_branch_nodes_created_total
cache_branch_lookups_total{namespace=...,method="token_span"}
cache_branch_lookups_total{namespace=...,method="checksum_span"}
cache_branch_lookup_hits_total
cache_branch_traversals_total{operation="path_to_root"}
cache_branch_traversals_total{operation="descendants"}
cache_branch_traversals_total{operation="children"}
cache_namespace_count
cache_namespace_nodes{namespace=...}
cache_namespace_roots{namespace=...}
cache_namespace_metadata_bytes{namespace=...}
cache_budget_branch_metadata_bytes
cache_budget_branch_metadata_soft_max_bytes
cache_budget_branch_metadata_ratio
cache_budget_branch_metadata_over_limit
cache_eviction_payloads_total{action=...}
cache_eviction_payload_bytes_total{action=...}
cache_eviction_payload_blocked_refs_total
cache_protected_root_payload_decisions_total{decision=...}
cache_protected_root_payload_bytes{residency=...}
cache_slot_ref_acquires_total
cache_slot_ref_releases_total
cache_slot_ref_concurrent_peak
cache_forest_lock_acquires_total
cache_forest_lock_retries_total
cache_namespace_validations_total{result=...}
cache_namespace_validation_failures_total
```

For focused controller evidence, capture the corresponding JSON stats fields: `branch_forest`, `branch_metadata_bytes`, `branch_metadata_soft_max_bytes`, `branch_metadata_over_limit`, `n_branch_nodes_created`, `n_branch_token_lookups`, `n_branch_checksum_lookups`, `n_branch_lookup_hits`, `n_slot_ref_acquires`, `n_slot_ref_releases`, and namespace validation counters.

## Clean build rules

Stage 7 execution still starts from a clean build. At minimum, build these targets for a Stage 7 session:

```powershell
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target llama-server test-cache-controller test-step12-branch-graph -j 4

$Binary = Get-Item build\bin\Release\llama-server.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    throw "llama-server.exe is stale. Run the clean build again."
}
```

Run focused Stage 7 checks with:

```powershell
ctest --test-dir build -C Release -R "test-step12-branch-graph|test-cache-controller" --output-on-failure
$env:LLAMA_SERVER_BIN_PATH=(Resolve-Path build\bin\Release\llama-server.exe).Path
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
pytest tools/server/tests/unit/test_cache_modes.py
```

If a session also executes model-backed public HTTP rows, keep the runner report fresh and per session as described in Part 5 and Part 7.

## Evidence checklist

Every Stage 7 report should state:

- clean build commands, targets, and binary timestamp
- exact commit or dirty worktree state
- evidence source for each row: public HTTP, focused graph test, focused controller test, Python metrics shape test, or other harness
- command line, model path, and relevant cache flags for model-backed rows
- before and after metrics snapshots for save, lookup, hit, miss, eviction, demotion, promotion, and validation rows
- focused test target names and source files for internal preconditions
- namespace IDs or fixture names used to prove same-namespace and cross-namespace behavior
- slot-ref setup and release sequence for multi-slot rows
- metadata soft-limit value and observed metadata bytes for over-limit rows
- payload budget, measured payload size, and eviction candidate order for LRU rows
- final `PASS`, `FAIL`, `SKIP`, and `BLOCKED` counts

## Reusable execution checklist

1. Read the current Stage 7 implementation log and re-review verdict before running.
2. Confirm test-plan review and manager approval opened QA execution.
3. Create a fresh report under `._design_docs/.test_reports/`.
4. Record the dirty worktree state without reverting user-owned changes.
5. Clean build `llama-server`, `test-cache-controller`, and `test-step12-branch-graph`.
6. Run focused graph and controller checks for G70-G80 internals.
7. Run Python metric-shape checks for G88 and public surface regression.
8. Run model-backed public HTTP rows for save/load, namespace isolation, metrics changes, and Stage 1-6 regression as the session scope requires.
9. Mark rows that need missing stats, draft, or fault-injection support as `BLOCKED` with the missing precondition and handoff owner.
10. Preserve logs, metrics, commands, and focused test output in the report.
