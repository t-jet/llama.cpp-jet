# Cache handling test plan

Status: Active  
Last updated: 2026-05-25  
Scope: server integration tests for implemented cache behavior  
Target environment: Windows 11, PowerShell, local GGUF model-backed integration tests

## Documentation rules

**No unicode icons**: Do not use emojis or unicode symbols in test plans, test code, or test output. Use plain text labels like "PASS", "FAIL", "SKIP", "BLOCKED" instead.

**Build freshness**: Always use freshly built binaries from clean builds. Testing against stale or cached binaries can produce false failures.

**Clean build procedure**:

```powershell
# Clean previous build artifacts
Remove-Item -Recurse -Force build -ErrorAction SilentlyContinue

# Configure and build fresh
cmake -B build -S . -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --target llama-server -j 4
```

## Purpose

This plan covers server integration tests for the cache behavior implemented now. Unit and focused C++ tests are tracked separately and are not acceptance gates in this document.

## Finding current implementation status

To understand what cache features are currently implemented, consult the design documents listed in [document-index.md](./document-index.md), especially documents in the "Cache implementation, verification, and tests" section.

## Current testable scope

Based on the implementation reports, the following features are available for testing:

- `--cache-mode legacy|hybrid` and the cache controller factory
- Legacy mode as the default with existing prompt-cache behavior
- Hybrid mode with exact-blob save/load code, non-destructive restore semantics, LRU indexes, token-prefix lookup, namespace filtering, metadata transport, protected-entry flags, target/draft paired restore checks, and restore-failure counters
- `/health` keeps the upstream shape: `{"status":"ok"}`
- `/cache/stats` is not registered (returns HTTP 404)
- Cache counters are exported through `/metrics` when metrics are enabled

This plan does not treat cold storage, metadata-only branch nodes, shared branch graphs, checkpoint-first traversal, a JSON cache stats endpoint, native Jinja boundary capture, cache policy selection, or new budget flags as current acceptance criteria. Those features are not part of the current implemented scope.

**Note**: This test plan will be adjusted and extended as needed when more functionality is implemented.

---

## Table of Contents

This document is split into smaller part files. Read the parts in order when you need the full content.

- [Part 1: implemented scope and exclusions](./cache-handling-test-plan/part-01-implemented-scope-and-exclusions.md)
- [Part 2: current integration coverage](./cache-handling-test-plan/part-02-current-automated-coverage.md)
- [Part 3: integration test matrix](./cache-handling-test-plan/part-03-integration-test-matrix.md)
- [Part 4: edge and negative scenarios](./cache-handling-test-plan/part-04-edge-and-negative-scenarios.md)
- [Part 5: runner and acceptance criteria](./cache-handling-test-plan/part-05-runner-and-acceptance-criteria.md)

## Test Scripts

**Reusable test automation scripts are available in:** [cache-handling-test-scripts/](./cache-handling-test-scripts/)

These PowerShell scripts implement the test matrix defined in this plan and can be run directly to execute all integration tests. The scripts are maintained alongside this test plan and should be updated when new cache functionality is implemented.

**Quick start:**

```powershell
# Run all tests with default configuration
& "._design_docs\cache-handling-test-scripts\execute_tests.ps1"
```

See [cache-handling-test-scripts/README.md](./cache-handling-test-scripts/README.md) for detailed usage instructions, customization options, and maintenance guidelines.
