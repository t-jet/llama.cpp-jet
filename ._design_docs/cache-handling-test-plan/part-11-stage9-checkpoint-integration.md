# Cache handling test plan - Part 11: Stage 9 checkpoint integration

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Stage 9 scope

Stage 9 makes checkpoint payloads descriptor-owned branch-node payloads and adds workload-profile-aware restore planning. `plain_transformer` namespaces prefer exact blobs. `checkpoint_dependent` namespaces use checkpoint-bearing nodes as the canonical restore path. The `target_plus_draft` shape stays a pairing overlay, so checkpoint target and draft payloads must be validated, restored, demoted, promoted, evicted, and accounted as one unit.

Design documents:

- [Stage 9 design](../cache-handling-phase9-design.md)
- [Part 1: workload profiles](../cache-handling-phase9-design/part-01-scope-and-workload-profiles.md)
- [Part 2: checkpoint lifecycle](../cache-handling-phase9-design/part-02-checkpoint-payload-lifecycle-and-interfaces.md)
- [Part 3: restore strategy and boundaries](../cache-handling-phase9-design/part-03-restore-strategy-and-prepared-prompt-boundaries.md)
- [Part 4: pairing, cold store, metrics](../cache-handling-phase9-design/part-04-pairing-cold-store-metrics-and-diagnostics.md)
- [Part 5: testability and risks](../cache-handling-phase9-design/part-05-testability-traceability-exclusions-and-risks.md)

Implementation documents:

- [Stage 9 implementation](../cache-handling-phase9-implementation.md)
- [Part 5: implementation evidence](../cache-handling-phase9-implementation/part-05-implementation-evidence-20260601.md)
- [Part 9: cold checkpoint restore corrections](../cache-handling-phase9-implementation/part-09-cold-checkpoint-restore-corrections-20260601.md)
- [Part 10: Architect implementation re-review](../cache-handling-phase9-implementation/part-10-architect-implementation-re-review-20260601.md)

## Evidence sources

Use the narrowest source that can create the row precondition.

| Source | Covers | Limits |
| --- | --- | --- |
| `test-cache-controller` | workload profile namespace isolation, descriptor admission rollback, boundary metadata validation, exact-first and checkpoint-first ranking, cold checkpoint promotion, checkpoint budget eviction, metric leak checks | Focused controller evidence, not model-backed HTTP |
| `test-step10-metrics` | Prometheus export shape for checkpoint hit and restore rows | Does not prove a live checkpoint-dependent model path |
| `test-step12-branch-graph` and `test-step13-stage8` | branch payload identity, metadata-only behavior, re-materialization, mismatch, cleanup, and Stage 7-8 regression as needed | Map only rows with matching test names or source evidence |
| PowerShell integration runner | clean report creation, server startup, public HTTP requests, logs, and `/metrics` snapshots | No dedicated Stage 9 matrix yet |
| Model-backed checkpoint fixture | public checkpoint-dependent restore, public `/metrics`, and task-flow boundary evidence | Required only when a suitable SWA, recurrent, hybrid, or MTP fixture is available |

## Positive coverage

| ID | Scenario | Expected result |
| --- | --- | --- |
| Q90 | Workload profile detection | Plain transformer, checkpoint-dependent, unsupported, and target/draft overlay cases resolve from initialized runtime facts, not request text or client hints. |
| Q91 | Workload profile namespace isolation | Same token spans do not match across `plain_transformer`, `checkpoint_dependent`, no-draft, separate-draft, target-MTP, or separate-MTP namespaces. Rejected candidates do not count as hits or refresh recency. |
| Q92 | Checkpoint descriptor admission | Admission validates payload kind, pair state, version, size, checksum, owner, store reference, residency, namespace, token span, position range, and boundary metadata before graph attachment. |
| Q93 | Admission rollback and replacement | Hot-store, descriptor insert, graph attach, and entry-sync failures leave no dangling graph reference. Replacement keeps the old checkpoint visible until the new checkpoint is committed. |
| Q94 | Checkpoint-dependent checkpoint-first restore | A checkpoint-dependent profile selects the deepest valid checkpoint candidate and rejects exact-only branches as canonical continuity. |
| Q95 | Checkpoint-dependent exact accelerator | A valid exact blob can be used only as an accelerator or root for the same checkpoint path. It must not replace checkpoint branch continuity. |
| Q96 | Plain-transformer exact-first restore | A plain transformer profile chooses the deepest valid exact blob when both exact and checkpoint payloads exist. Checkpoint use remains opportunistic. |
| Q97 | Cold checkpoint promotion path | A selected cold checkpoint queues paired promotion, records the async miss or failure row, avoids live slot mutation, and can be reused only after promotion succeeds. |
| Q98 | Target/draft checkpoint pair validation | Target/draft checkpoint descriptors validate pair state and speculative mode before promotion or restore. A partial target-only or draft-only restore is rejected. |
| Q99 | Checkpoint hot/cold budget behavior | Checkpoint payloads share the hot budget with exact blobs, demote and promote through the cold store, evict under pressure, and update resident byte accounting. |
| Q100 | Cleanup ownership | Eviction, replacement, pruning, and cold cleanup delete checkpoint bytes only after descriptor ownership proves no retained node or pair side still owns them. |
| Q101 | Public boundary propagation | A public task-flow or equivalent integration row proves prepared boundary metadata reaches checkpoint admission or records a degraded token/position fallback diagnostic. |
| Q102 | Public `/metrics` checkpoint evidence | A live server scrape, when a fixture can exercise it, shows `cache_checkpoint_restores_total` and `cache_checkpoint_hits_total` labels for profile, residency, pair state, and result. |
| Q103 | Model-backed checkpoint-dependent row | With a suitable SWA, recurrent, hybrid, or MTP fixture, public HTTP or equivalent task flow proves checkpoint-dependent checkpoint-first restore. |

## Negative and substitute-evidence coverage

| ID | Scenario | Expected result |
| --- | --- | --- |
| Q104 | Unsupported or unknown profile | Unknown runtime shape falls back safely, emits diagnostics, and does not reuse exact-only candidates as checkpoint-dependent continuity. |
| Q105 | Boundary mismatch | Missing required boundary metadata, token mismatch, checksum mismatch, boundary kind mismatch, media span mismatch, or projector mismatch rejects the checkpoint and follows Stage 8 mismatch handling when applicable. |
| Q106 | Descriptor validation mismatch | Wrong kind, version, checksum, size, owner, store reference, residency, namespace, target bytes, draft bytes, or pair state rejects restore before hit count, recency refresh, or slot mutation. |
| Q107 | Cold promotion failure | Missing cold bytes, corruption, version mismatch, checksum mismatch, timeout, or worker failure falls back without partial target/draft application. |
| Q108 | Metrics leakage | Checkpoint metrics and diagnostics do not contain prompt text, marker labels, raw boundary IDs when unsafe, file paths, namespace test strings, or serialized payload bytes. |
| Q109 | Model-backed fixture unavailable | If no suitable checkpoint-dependent fixture exists, the report must mark Q103 `BLOCKED` or `SKIP` by local fixture policy and cite substitute focused evidence for Q90-Q100 plus Q101 when possible. |

## Stage 4-8 regression after Stage 9

| ID | Scenario | Expected result |
| --- | --- | --- |
| Q110 | Stage 4-5 regression | Byte-budget LRU, protected-root policy, descriptor validation, target/draft pair enforcement, transactional restore, and draft namespace isolation still pass with Stage 9 code present. |
| Q111 | Stage 6 regression | Cold demotion, promotion, async miss, corruption handling, queue fallback, and cold metrics remain valid for exact blobs and now include checkpoint descriptors where planned. |
| Q112 | Stage 7-8 regression | Branch graph lookup, namespace validation, slot refs, metadata-only retention, re-materialization, mismatch handling, equivalent deduplication, pruning, and cleanup behavior remain valid. |

## Metrics and labels

Capture these names from public `/metrics` when the row uses a live server. Focused metrics evidence may use the JSON stats and exporter tests when no model-backed fixture exists.

```text
cache_checkpoint_restores_total{profile=...,payload_residency=...,pair_state=...,result=...}
cache_checkpoint_hits_total{profile=...,payload_residency=...,pair_state=...}
cache_checkpoint_admissions_total
cache_checkpoint_admission_failures_total
cache_payload_promotions_total
cache_payload_demotions_total
cache_payload_evictions_total
cache_restore_failures_total
cache_fallback_restores_total
cache_validation_mismatches_total
cache_node_rematerializations_total
```

Metric labels must be enum-like. Do not accept prompt text, path material, marker strings, or payload contents in metric labels or diagnostic fields.

## Clean build and execution rules

Stage 9 execution starts from a clean build. At minimum, build these targets:

```powershell
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target llama-server test-cache-controller test-step10-metrics test-step12-branch-graph test-step13-stage8 -j 4

$Binary = Get-Item build\bin\Release\llama-server.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    throw "llama-server.exe is stale. Run the clean build again."
}
```

Focused checks for Stage 9 planning and execution:

```powershell
ctest --test-dir build -C Release -R "test-cache-controller|test-step10-metrics|test-step12-branch-graph|test-step13-stage8" --output-on-failure
$env:LLAMA_SERVER_BIN_PATH=(Resolve-Path build\bin\Release\llama-server.exe).Path
pytest tools/server/tests/unit/test_cache_modes.py
```

Use `LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD=1` only for startup, public surface, and metric-shape rows. Do not use it as evidence for model-backed checkpoint save, restore, hit, miss, promotion, demotion, eviction, or boundary propagation.

## Evidence checklist

Every Stage 9 report should state:

- clean build commands, targets, binary timestamp, and dirty worktree state
- evidence source for each row: public HTTP, focused controller test, metrics test, branch graph test, Stage 8 test, model-backed fixture, or substitute evidence
- exact focused test names or source locations for rows that use focused evidence
- model path, runtime profile evidence, draft or MTP flags, cache flags, and cold path for model-backed rows
- before and after metrics snapshots for checkpoint admission, hit, restore, promotion, demotion, eviction, fallback, validation mismatch, and re-materialization rows
- boundary metadata source or degraded fallback reason for boundary rows
- explicit fixture search result for Q103 and the substitute evidence used if no suitable fixture is available
- final `PASS`, `FAIL`, `SKIP`, and `BLOCKED` counts

Store run evidence only in a fresh `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` file. Do not report run-specific results in this plan.
