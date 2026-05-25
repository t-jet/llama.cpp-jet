# Cache handling test plan

Status: Active  
Last updated: 2026-05-25  
Scope: server integration tests for implemented cache behavior  
Target environment: Windows 11, PowerShell, local GGUF model-backed integration tests

## Purpose

This plan covers server integration tests for the cache behavior implemented now. Unit and focused C++ tests are tracked separately and are not acceptance gates in this document.

The implemented scope comes from the Phase 1 and Phase 2 implementation, verification, adjustment, and gap reports listed in `document-index.md`. When those reports conflict, use the later 2026-05-25 status notes, `cache-handling-phase-1-and-2-adjustments.md`, and `cache-handling-phases-1-and-2-implementation-gaps.md` as the current source of truth.

- `--cache-mode legacy|hybrid` and the cache controller factory are present.
- Legacy mode remains the default and keeps the existing prompt-cache behavior.
- Hybrid mode has exact-blob save/load code, non-destructive restore semantics, LRU indexes, token-prefix lookup, namespace filtering, metadata transport, protected-entry flags, target/draft paired restore checks, and restore-failure counters.
- `/health` keeps the upstream shape: `{"status":"ok"}`.
- `/cache/stats` is not registered.
- Cache counters are exported through `/metrics` when metrics are enabled.

This plan does not treat cold storage, metadata-only branch nodes, shared branch graphs, checkpoint-first traversal, a JSON cache stats endpoint, native Jinja boundary capture, cache policy selection, or new budget flags as current acceptance criteria. Those features are not part of the current implemented scope.

---

## Table of Contents

This document is split into smaller part files. Read the parts in order when you need the full content.

- [Part 1: implemented scope and exclusions](./cache-handling-test-plan/part-01-implemented-scope-and-exclusions.md)
- [Part 2: current integration coverage](./cache-handling-test-plan/part-02-current-automated-coverage.md)
- [Part 3: integration test matrix](./cache-handling-test-plan/part-03-integration-test-matrix.md)
- [Part 4: edge and negative scenarios](./cache-handling-test-plan/part-04-edge-and-negative-scenarios.md)
- [Part 5: runner and acceptance criteria](./cache-handling-test-plan/part-05-runner-and-acceptance-criteria.md)
