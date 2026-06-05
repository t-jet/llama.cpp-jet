# Cache handling test plan - Part 10: Stage 8 metadata-only re-materialization

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Stage 8 scope

Stage 8 keeps branch metadata after payload bytes are evicted. The controller can validate a selected metadata-only path, restore from the nearest valid payload-bearing ancestor, and attach a new payload only after validation and save succeed. Mismatches are cache misses. Equivalent same-namespace branches are reused, and branch metadata admission can reject a new node when safe pruning cannot satisfy the soft metadata budget.

Design documents:

- [Stage 8 design](../cache-handling-phase8-design.md)
- [Part 1: overview and objectives](../cache-handling-phase8-design/part-01-overview-and-objectives.md)
- [Part 2: interfaces and lifecycle rules](../cache-handling-phase8-design/part-02-interfaces-and-lifecycle-rules.md)
- [Part 3: re-materialization and mismatch handling](../cache-handling-phase8-design/part-03-rematerialization-and-mismatch-handling.md)
- [Part 4: deduplication, pruning, and cleanup](../cache-handling-phase8-design/part-04-deduplication-pruning-and-cleanup.md)
- [Part 5: observability and testability](../cache-handling-phase8-design/part-05-observability-testability-and-review-readiness.md)

Implementation documents:

- [Stage 8 implementation](../cache-handling-phase8-implementation.md)
- [Part 9: implementation-review corrections](../cache-handling-phase8-implementation/part-09-implementation-review-corrections-20260601.md)
- [Part 10: Architect implementation re-review](../cache-handling-phase8-implementation/part-10-architect-implementation-re-review-20260601.md)

## Out of scope for Stage 8 acceptance

Do not require these future-stage behaviors:

- checkpoint-first restore or checkpoint-specific branch ranking
- public metadata-budget CLI flags
- public `/cache/stats` success
- public request fields for branch metadata control
- separate public hot, metadata, and cold budget flags
- cross-restart branch graph restore guarantees
- tolerant namespace matching

## Evidence sources

Use the narrowest evidence source that can create the required precondition.

| Source | Covers | Limits |
| --- | --- | --- |
| `test-step13-stage8` | metadata-only transitions, re-materialization plans, mismatch handling, equivalent deduplication, cold cleanup ownership, admission rejection, and focused controller stats | Does not prove model-backed public HTTP restore by itself |
| `test-cache-controller` | Stage 4-7 regression, descriptor ownership, slot refs, and focused cache-controller behavior | Use exact test names or source locations for each mapped row |
| `tools/server/tests/unit/test_cache_modes.py` | public metric shape, missing `/cache/stats`, and model-backed smoke when a server binary is configured | Metric-shape rows are not proof of internal transition semantics |
| PowerShell integration runner | clean report creation, server startup, public HTTP requests, logs, and metrics snapshots | The runner has no dedicated Stage 8 matrix yet |
| Stats-capable or fault-injection harness | internal branch identity, forced payload eviction, descriptor corruption, and branch metadata pressure | Mark rows `BLOCKED` if the harness is required but unavailable |

## Positive coverage

| ID | Scenario | Expected result |
| --- | --- | --- |
| S80 | Metadata-only retention after payload eviction | Payload eviction clears owned payload descriptors and resident bytes, marks the node metadata-only, and preserves node ID, namespace, parent, children, token spans, checksum spans, protection, usage, and metadata accounting. |
| S81 | Active slot refs block payload eviction | A referenced node cannot become metadata-only through payload eviction. After the ref is released, eviction can retain the node as metadata-only. |
| S82 | Protected-root metadata survives payload eviction | A protected root can lose payload bytes under budget pressure, but protected graph metadata remains and is not pruned by ordinary pressure. |
| S83 | Metadata-only topology preserves descendants | A metadata-only parent remains discoverable through parent, child, descendant, and path-to-root traversal when retained descendants depend on it. |
| S84 | Safe leaf pruning | An unreferenced metadata-only leaf that is not protected and has no retained descendants can be pruned, with metadata bytes removed from accounting. |
| S85 | Re-materialization full match | A selected metadata-only node validates the requested path, chooses the nearest payload-bearing source ancestor or root source, restores from that source, and attaches the new payload only after save succeeds. |
| S86 | Re-materialization save failure | If materialization save fails, the node remains metadata-only, no payload descriptor is attached, and the request falls back without partial slot or graph mutation. |
| S87 | Target/draft re-materialization is atomic | A target/draft node re-materializes both sides as one descriptor. A partial target-only materialization is not accepted for a draft runtime. |
| S88 | Restore source selection | Production restore-source selection uses the same metadata-only planning helper covered by focused tests and switches restore to the nearest payload-bearing ancestor before live slot mutation. |
| S89 | Equivalent payload-bearing branch reuse | Admission of an equivalent same-namespace branch reuses the canonical payload-bearing node and does not create a duplicate branch or share one descriptor across owners. |
| S90 | Equivalent metadata-only branch reuse | Admission of an equivalent metadata-only branch reuses the canonical node and re-materializes it when needed. |
| S91 | Cold cleanup ownership | Cold cleanup deletes cold bytes only when the pruned or evicted node exclusively owns the descriptor and no retained branch or descendant still references it. |

## Negative and blocked-precondition coverage

| ID | Scenario | Expected result |
| --- | --- | --- |
| S92 | Token or checksum validation mismatch | Re-materialization is rejected, mismatch counters increment, the mismatched metadata-only node remains unchanged, and the request falls back as a miss. |
| S93 | Mismatch parent selection | The new divergence branch is created or found under the deepest validated ancestor, with deterministic tie-breaking independent of insertion order or unordered-map iteration. |
| S94 | Missing payload-bearing ancestor | If no valid payload-bearing source exists and root replay cannot be planned, the controller falls back without changing the selected node or slot state. |
| S95 | Cross-namespace equivalent rejection | Equivalent lookup and deduplication never merge nodes across namespaces, even when token spans and checksums match. |
| S96 | Branch metadata admission rejection under protected pressure | When only protected or topology-required metadata remains and safe pruning cannot satisfy the soft metadata budget, admission rejects the new node, removes the tentative payload and branch, and increments admission rejection metrics. |
| S97 | Branch metadata admission rejection under active refs | When active slot refs prevent safe pruning, admission rejects the new node and preserves the referenced existing entry. |
| S98 | Branch pruning blocked by retained descendants | Pruning an internal metadata-only node with retained descendants is rejected unless an approved reparenting operation preserves path semantics. Stage 8 can use the conservative reject path. |
| S99 | Cold cleanup blocked by shared ownership | If ownership checks find another retained node, descendant, or pair side that depends on the cold descriptor, cleanup leaves the file in place and branch pruning fails when deletion is required for consistency. |

## Metrics and labels

When `/metrics` is enabled, capture these Stage 8 metrics and required labels:

```text
cache_metadata_only_retentions_total{namespace=...,reason=...}
cache_node_rematerializations_total{namespace=...,result=...}
cache_node_rematerialization_bytes_total{namespace=...}
cache_validation_mismatches_total{namespace=...,method=...}
cache_mismatch_parent_selections_total{namespace=...,source=...}
cache_equivalent_branch_deduplications_total{namespace=...,action=...}
cache_branch_pruning_total{namespace=...,result=...,reason=...}
cache_branch_pruned_metadata_bytes_total{namespace=...}
cache_cold_cleanup_total{namespace=...,result=...}
cache_branch_metadata_admission_rejections_total{namespace=...,reason=...}
```

The existing `mode` label may also appear. It does not replace the Stage 8 labels.

## Stage 4-7 regression

| ID | Scenario | Expected result |
| --- | --- | --- |
| R20 | Stage 4 regression after Stage 8 | H30-H39 behavior remains valid: payload byte budgets, LRU recency, protected-root priority, failed-restore recency, equivalent refresh, and Stage 4 metrics are not weakened by metadata-only retention. |
| R21 | Stage 5 regression after Stage 8 | H40-H58 behavior remains valid: descriptor ownership, pair-state validation, transactional restore, draft runtime namespace isolation, and Stage 5 metrics still hold. |
| R22 | Stage 6 regression after Stage 8 | C60-C65, H60-H74, N30-N35, M10-M17, and F01-F10 remain valid when metadata-only branches and cold payload storage are both in use. |
| R23 | Stage 7 regression after Stage 8 | G70-G89 remain valid: branch lifecycle, namespace validation, slot refs, checksum lookup, metadata accounting, global hot LRU, and Stage 7 metrics still work. |

## Clean build and execution rules

Stage 8 execution starts from a clean build. At minimum, build these targets:

```powershell
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target llama-server test-cache-controller test-step12-branch-graph test-step13-stage8 -j 4

$Binary = Get-Item build\bin\Release\llama-server.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    throw "llama-server.exe is stale. Run the clean build again."
}
```

Run focused Stage 8 checks with:

```powershell
ctest --test-dir build -C Release -R "test-step13-stage8|test-cache-controller" --output-on-failure
$env:LLAMA_SERVER_BIN_PATH=(Resolve-Path build\bin\Release\llama-server.exe).Path
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
pytest tools/server/tests/unit/test_cache_modes.py
```

`LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` is a Windows test workaround for Python metric-shape and server-mode tests. It is acceptable only for rows that assert startup, public surface, and Prometheus metric labels. Do not use it as evidence for model-backed save, restore, hit, miss, eviction, or re-materialization behavior.

## Evidence checklist

Every Stage 8 report should state:

- clean build commands, targets, binary timestamp, and dirty worktree state
- evidence source for each row: public HTTP, focused Stage 8 test, focused controller test, Python metric-shape test, or another harness
- exact focused test target names and source files for internal preconditions
- command line, model path, cache flags, cold path, and draft flags for model-backed rows
- before and after metrics snapshots for retention, re-materialization, mismatch, deduplication, pruning, cold cleanup, and admission rejection rows
- token sequences, namespace IDs, candidate ordering, and mismatch-parent choice for deterministic selection rows
- descriptor ownership and cold file references for cleanup rows
- final `PASS`, `FAIL`, `SKIP`, and `BLOCKED` counts

Do not report run-specific results in this plan. Store execution evidence in a fresh `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` file.
