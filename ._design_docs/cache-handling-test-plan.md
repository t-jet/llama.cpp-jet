# Cache handling test plan

Status: Active
Last updated: 2026-06-01
Scope: server integration tests and focused evidence mapping for implemented cache behavior
Target environment: Windows 11, PowerShell, local GGUF model-backed integration tests

## Documentation rules

Use plain ASCII status labels in plans, scripts, and reports: `PASS`, `FAIL`, `SKIP`, and `BLOCKED`.

Every execution session must start from a clean build. Do not use stale or incrementally rebuilt binaries as test evidence.

Required build procedure:

```powershell
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target llama-server -j 4

$Binary = Get-Item build\bin\Release\llama-server.exe
$BuildAge = (Get-Date) - $Binary.LastWriteTime
if ($BuildAge.TotalMinutes -gt 10) {
    throw "llama-server.exe is stale. Run the clean build again."
}
```

## Cache budget test design

Stage 4 eviction tests use `--cache-ram` as an integer MiB budget. The server argument parser does not accept fractional MiB values.

For budget and eviction tests:

1. Measure actual cache entry size for the local model from `/metrics` (`llamacpp_cache_bytes`) and logs.
2. Record the estimated per-entry resident payload size before asserting eviction behavior.
3. Choose an integer `--cache-ram` budget that can admit at least one realistic entry.
4. Drive pressure with enough unique short prompts to exceed that budget.
5. Keep prompts short and deterministic unless a test needs larger payloads.
6. Capture hit, miss, eviction, payload eviction, protected-root decision, entry, byte, and token counters before and after the operation.

Example design:

```powershell
# Measured: one entry is about 330 KiB resident payload.
# Budget: --cache-ram 1 gives about three entries.
# Pressure: create four or more unique entries to force eviction.
```

## Purpose

This plan covers server integration tests for the cache behavior implemented now. When public HTTP cannot create an internal precondition, the plan also maps focused C++ or Python metric-shape evidence that may be used for that row.

## Finding current implementation status

Use [document-index.md](./document-index.md) first. For Stage 4, Stage 5, Stage 6, Stage 7, and Stage 8, read:

- [cache-handling-phase4-design.md](./cache-handling-phase4-design.md)
- [cache-handling-phase4-implementation.md](./cache-handling-phase4-implementation.md)
- [cache-handling-phase4-implementation/part-06-review-fixes.md](./cache-handling-phase4-implementation/part-06-review-fixes.md)
- [cache-handling-phase4-implementation/part-07-implementation-re-review.md](./cache-handling-phase4-implementation/part-07-implementation-re-review.md)
- [cache-handling-phase5-design.md](./cache-handling-phase5-design.md)
- [cache-handling-phase5-implementation.md](./cache-handling-phase5-implementation.md)
- [cache-handling-phase5-implementation/part-06-implementation-evidence.md](./cache-handling-phase5-implementation/part-06-implementation-evidence.md)
- [cache-handling-phase5-implementation/part-08-review-fix-evidence.md](./cache-handling-phase5-implementation/part-08-review-fix-evidence.md)
- [cache-handling-phase5-implementation/part-09-implementation-re-review.md](./cache-handling-phase5-implementation/part-09-implementation-re-review.md)
- [cache-handling-phase6-design.md](./cache-handling-phase6-design.md)
- [cache-handling-phase6-implementation.md](./cache-handling-phase6-implementation.md)
- [cache-handling-phase6-implementation/part-13-implementation-review.md](./cache-handling-phase6-implementation/part-13-implementation-review.md)
- [cache-handling-phase7-design.md](./cache-handling-phase7-design.md)
- [cache-handling-phase7-design/part-04-test-specifications.md](./cache-handling-phase7-design/part-04-test-specifications.md)
- [cache-handling-phase7-design/part-05-metrics-and-observability.md](./cache-handling-phase7-design/part-05-metrics-and-observability.md)
- [cache-handling-phase7-design/part-06-acceptance-criteria.md](./cache-handling-phase7-design/part-06-acceptance-criteria.md)
- [cache-handling-phase7-implementation.md](./cache-handling-phase7-implementation.md)
- [cache-handling-phase7-implementation/part-10-implementation-re-review.md](./cache-handling-phase7-implementation/part-10-implementation-re-review.md)
- [cache-handling-phase8-design.md](./cache-handling-phase8-design.md)
- [cache-handling-phase8-design/part-01-overview-and-objectives.md](./cache-handling-phase8-design/part-01-overview-and-objectives.md)
- [cache-handling-phase8-design/part-02-interfaces-and-lifecycle-rules.md](./cache-handling-phase8-design/part-02-interfaces-and-lifecycle-rules.md)
- [cache-handling-phase8-design/part-03-rematerialization-and-mismatch-handling.md](./cache-handling-phase8-design/part-03-rematerialization-and-mismatch-handling.md)
- [cache-handling-phase8-design/part-04-deduplication-pruning-and-cleanup.md](./cache-handling-phase8-design/part-04-deduplication-pruning-and-cleanup.md)
- [cache-handling-phase8-design/part-05-observability-testability-and-review-readiness.md](./cache-handling-phase8-design/part-05-observability-testability-and-review-readiness.md)
- [cache-handling-phase8-implementation.md](./cache-handling-phase8-implementation.md)
- [cache-handling-phase8-implementation/part-10-architect-implementation-re-review-20260601.md](./cache-handling-phase8-implementation/part-10-architect-implementation-re-review-20260601.md)

## Test coverage summary

The integration plan covers:

- Stage 1 mode selection, legacy compatibility, and public HTTP surface checks.
- Stage 2 boundary metadata and protected-root propagation.
- Stage 3 non-destructive exact blob cache behavior, restore metrics, namespace isolation, and draft-model pairing.
- Stage 4 resident payload byte budget enforcement, deterministic LRU behavior, restore recency semantics, protected-root eviction priority and fallback, protected admission rejection, and Stage 4 metrics.
- Stage 5 payload descriptor separation, hot payload ownership, descriptor validation, target/draft pair validation, draft runtime mode namespace isolation, transactional restore rollback, paired eviction and byte accounting, Stage 5 metrics, legacy compatibility, and Stage 4 regression coverage.
- Stage 6 cold payload storage, asynchronous I/O worker, hot-to-cold demotion, cold-to-hot promotion, startup validation for `--cache-cold-path`, cold store opt-in behavior, target/draft pair demotion and promotion as a unit, fault tolerance for cold file corruption and I/O failures, protected root demotion warning, cold layer metrics, and Stage 4 and Stage 5 regression with cold store configured.
- Stage 7 branch graph foundation, branch node lifecycle, namespace validation, slot references, checksum-assisted lookup, branch metadata RAM accounting and soft-limit diagnostics, global hot-payload LRU selection across namespaces, Stage 7 metrics, and Stage 1-6 regression with the forest-backed controller.
- Stage 8 metadata-only retention, safe re-materialization planning, mismatch-parent handling, equivalent-branch deduplication, branch-metadata admission rejection, cold cleanup ownership, Stage 8 Prometheus metrics labels, and Stage 4-7 regression with metadata-only behavior enabled.
- Edge, negative, concurrency, and stress scenarios that exercise the same server path.

## Current testable scope

Implemented behavior that must be covered:

- `--cache-mode legacy|hybrid`, with legacy as the default.
- Legacy prompt-cache compatibility and unchanged `/health` shape.
- Hybrid exact full-state save and non-destructive restore.
- Successful restore refreshes recency; failed restore does not.
- Equivalent-entry refresh updates recency and enforces the resident payload byte budget.
- `--cache-ram` enforces resident serialized payload bytes (`target_state_bytes + draft_state_bytes`), not incidental metadata.
- Oversized entries are rejected on admission.
- Protected roots have higher retention priority but still count against the budget.
- Unprotected entries evict before protected entries; protected entries evict oldest-first when they are the only way to satisfy budget.
- Metrics expose existing counters plus Stage 4 payload eviction and protected-root decision counters.
- `/cache/stats` is still absent in the public HTTP surface.
- Exact-blob payload bytes are descriptor-owned and stored in the hot payload store instead of directly in cache entries.
- Descriptor validation rejects unsupported version or kind, pair-state/runtime mismatch, checksum mismatch, size mismatch, bad store references, owner mismatch, non-hot residency, missing target bytes, and invalid draft presence.
- Target and draft payloads restore, evict, and account for resident bytes as one pair.
- Draft compatibility separates no draft, normal separate draft model, target-derived `draft-mtp`, and separate-model `draft-mtp` modes. `--model-draft` and `--spec-draft-model` are aliases for the normal separate draft model path unless `--spec-type draft-mtp` selects MTP.
- A failed target or draft restore is transactional: no hit is counted, no usage or recency refresh happens, and the slot returns to its pre-restore state, including the empty-preimage rollback case.
- Unsupported empty-side clear is checked before applying cached target bytes.
- Metrics expose Stage 5 descriptor validation, pairing violation, fallback restore, hot descriptor, and evicted descriptor signals.
- Cold payload storage is opt-in via `--cache-cold-path`. When unconfigured, the server behaves identically to Stage 5.
- Hot payloads are demoted to cold when `--cache-cold-path` is configured and `--cache-ram` budget pressure selects them for eviction.
- Cold payloads are promoted back to hot on cache hit. The current request falls back; subsequent requests benefit from the promotion.
- Startup validation rejects invalid `--cache-cold-path` configurations (empty, non-existent, not a directory, non-writable) and rejects `--cache-cold-path` without hybrid mode.
- Demotion and promotion counters, cold payload bytes, cold payload count, hot payload count, cold restore latency, and eviction exclusion of demoted payloads are observable in `/metrics`.
- Cold file corruption, cold store read failure, and queue-full fallback are testable through fault injection.
- Protected root demotion emits a warning diagnostic.
- Target and draft payloads demote and promote as one unit.
- Stage 4 and Stage 5 behavior is preserved when the cold store is configured.
- Branch graph nodes are created for hybrid saves and remain separate from payload residency.
- Strict namespace validation prevents unsafe cross-model or cross-config restores.
- Token-span and length-qualified checksum lookup select same-namespace branch candidates.
- Slots hold transient refs to branch nodes; active refs block payload eviction or demotion candidates.
- Multiple namespaces share the hot payload budget through one global LRU candidate order.
- Branch metadata RAM is accounted and exposed through metrics and focused stats. The Stage 7 metadata soft max is internal/test-only and diagnostics-only.
- Protected-root graph metadata survives payload eviction and demotion. Protected-root payload bytes still count against the hot budget.
- Stage 7 Prometheus metrics expose branch lookup, namespace, metadata budget, payload eviction, protected-root payload, slot-ref, forest-lock, and namespace-validation signals.
- Payload eviction can retain a branch as metadata-only without pruning topology.
- Re-materialization validates the selected metadata-only path before replay and falls back without slot mutation on mismatch or unavailable source payload.
- Mismatch handling creates or finds a divergent branch under the deepest validated ancestor.
- Equivalent branch admission reuses a same-namespace canonical node instead of adding duplicates.
- Branch-metadata admission rejects a new node when safe pruning cannot satisfy the soft metadata budget.
- Cold cleanup proves descriptor ownership before deleting cold bytes during eviction or pruning.
- Stage 8 Prometheus metrics expose the accepted names and labels for metadata-only retention, re-materialization, mismatch, deduplication, pruning, cold cleanup, and metadata admission rejection.

Do not treat checkpoint-first traversal, native Jinja boundary capture, public JSON cache stats, public metadata-budget flags, cache policy selection flags, separate hot/metadata/cold budget flags, or cross-restart branch graph restore as current acceptance criteria.

## Contents

This document is split into smaller part files. Read the parts in order when you need the full plan.

- [Part 1: implemented scope and exclusions](./cache-handling-test-plan/part-01-implemented-scope-and-exclusions.md)
- [Part 2: current integration coverage](./cache-handling-test-plan/part-02-current-automated-coverage.md)
- [Part 3: integration test matrix](./cache-handling-test-plan/part-03-integration-test-matrix.md)
- [Part 4: edge and negative scenarios](./cache-handling-test-plan/part-04-edge-and-negative-scenarios.md)
- [Part 5: runner and evidence format](./cache-handling-test-plan/part-05-runner-and-evidence-format.md)
- [Part 6: stress tests and acceptance criteria](./cache-handling-test-plan/part-06-stress-tests-and-acceptance.md)
- [Part 7: test report quality and templates](./cache-handling-test-plan/part-07-test-report-quality-and-templates.md)
- [Part 8: Stage 6 cold layer integration](./cache-handling-test-plan/part-08-stage6-cold-layer-integration.md)
- [Part 9: Stage 7 branch graph foundation](./cache-handling-test-plan/part-09-stage7-branch-graph-foundation.md)
- [Part 10: Stage 8 metadata-only re-materialization](./cache-handling-test-plan/part-10-stage8-metadata-only-rematerialization.md)

## Review reports

- [Stage 4 test-plan review: 2026-05-27](./cache-handling-test-plan/stage-4-test-plan-review-20260527.md)
- [Stage 5 test-plan review: 2026-05-28](./cache-handling-test-plan/stage-5-test-plan-review-20260528.md)
- [Stage 6 test-plan review: 2026-05-30](./cache-handling-test-plan/stage-6-test-plan-review-20260530.md)
- [Stage 7 test-plan review: 2026-05-31](./cache-handling-test-plan/stage-7-test-plan-review-20260531.md)
- [Stage 7 manager test-plan gate: 2026-05-31](./cache-handling-test-plan/stage-7-manager-test-plan-gate-20260531.md)
- [Stage 8 test-plan review: 2026-06-01](./cache-handling-test-plan/stage-8-test-plan-review-20260601.md)
- [Stage 8 manager test-plan gate: 2026-06-01](./cache-handling-test-plan/stage-8-manager-test-plan-gate-20260601.md)

## Test scripts

Reusable PowerShell scripts live in [cache-handling-test-scripts/](./cache-handling-test-scripts/).

```powershell
& "._design_docs\cache-handling-test-scripts\execute_tests.ps1"
```

See [cache-handling-test-scripts/README.md](./cache-handling-test-scripts/README.md) for usage, parameters, and maintenance notes.

## Test execution reports

For each execution session, create a new report in [._design_docs/.test_reports/](./.test_reports/) named:

```text
test-report-YYYYMMDD-NN.md
```

Each report must include:

- test run ID matching the filename
- date, tester, and link to this plan
- git commit or dirty working-tree status
- build configuration and binary path
- model path and relevant environment variables
- planned categories and explicit exclusions
- per-test command, request, response, metric, and log evidence
- final `PASS`, `FAIL`, `SKIP`, and `BLOCKED` counts
- reproducible bug reports for failures

Use [Part 7](./cache-handling-test-plan/part-07-test-report-quality-and-templates.md) for the detailed report checklist.
