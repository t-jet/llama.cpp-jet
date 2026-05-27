# Cache handling test plan

Status: Active  
Last updated: 2026-05-27  
Scope: server integration tests for implemented cache behavior  
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

This plan covers server integration tests for the cache behavior implemented now. Unit and focused C++ tests are tracked by the normal project test suite and are not acceptance gates in this document.

## Finding current implementation status

Use [document-index.md](./document-index.md) first. For Stage 4, read:

- [cache-handling-phase4-design.md](./cache-handling-phase4-design.md)
- [cache-handling-phase4-implementation.md](./cache-handling-phase4-implementation.md)
- [cache-handling-phase4-implementation/part-06-review-fixes.md](./cache-handling-phase4-implementation/part-06-review-fixes.md)
- [cache-handling-phase4-implementation/part-07-implementation-re-review.md](./cache-handling-phase4-implementation/part-07-implementation-re-review.md)

## Test coverage summary

The integration plan covers:

- Stage 1 mode selection, legacy compatibility, and public HTTP surface checks.
- Stage 2 boundary metadata and protected-root propagation.
- Stage 3 non-destructive exact blob cache behavior, restore metrics, namespace isolation, and draft-model pairing.
- Stage 4 resident payload byte budget enforcement, deterministic LRU behavior, restore recency semantics, protected-root eviction priority and fallback, protected admission rejection, and Stage 4 metrics.
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

Do not treat cold storage, metadata-only branch nodes, shared branch graphs, checkpoint-first traversal, native Jinja boundary capture, public JSON cache stats, cache policy selection flags, or separate hot/metadata/cold budget flags as current acceptance criteria.

## Contents

This document is split into smaller part files. Read the parts in order when you need the full plan.

- [Part 1: implemented scope and exclusions](./cache-handling-test-plan/part-01-implemented-scope-and-exclusions.md)
- [Part 2: current integration coverage](./cache-handling-test-plan/part-02-current-automated-coverage.md)
- [Part 3: integration test matrix](./cache-handling-test-plan/part-03-integration-test-matrix.md)
- [Part 4: edge and negative scenarios](./cache-handling-test-plan/part-04-edge-and-negative-scenarios.md)
- [Part 5: runner and evidence format](./cache-handling-test-plan/part-05-runner-and-evidence-format.md)
- [Part 6: stress tests and acceptance criteria](./cache-handling-test-plan/part-06-stress-tests-and-acceptance.md)
- [Part 7: test report quality and templates](./cache-handling-test-plan/part-07-test-report-quality-and-templates.md)

## Review reports

- [Stage 4 test-plan review: 2026-05-27](./cache-handling-test-plan/stage-4-test-plan-review-20260527.md)

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
