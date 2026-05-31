# Stage 7 implementation plan - Part 2

Source: [../cache-handling-phase7-implementation.md](../cache-handling-phase7-implementation.md)  
Continuation of [Part 1](part-01-implementation-plan.md).

## Dependency order

Required order:

1. Branch graph types and standalone forest implementation.
2. Build/test wiring for the new module.
3. Hybrid controller migration to forest-backed save/load.
4. Namespace validation and slot refs.
5. Shared budget, global eviction, and protected-root preservation.
6. Metrics, diagnostics, regression, and durable evidence.

Steps 7.5 and 7.6 can proceed after the first hybrid integration compiles. Steps 7.7 through 7.9
depend on the integration points being stable.

## Evidence plan

Each implementation step must update this log, or a part file if the log grows, before the next
step starts. The evidence entry must include:

- changed file paths
- behavior change
- exact build command and result
- exact focused test command and result
- metrics or diagnostics sample when the step changes observability
- coverage result or a clear reason coverage could not be gathered
- any deviation from this plan and how it was resolved

Expected command set after implementation opens:

```powershell
cmake --build build --config Release --target test-step12-branch-graph -j 4
ctest --test-dir build -C Release -R test-step12-branch-graph --output-on-failure
cmake --build build --config Release --target test-cache-controller -j 4
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
cmake --build build --config Release --target llama-server -j 4
pytest tools/server/tests/unit/test_cache_modes.py
```

Add Stage 6 step-target reruns when a change touches cold demotion, promotion, startup wiring, or
metrics.

## Metrics and diagnostics evidence

Implementation evidence must include samples for the new Stage 7 observability surface:

- branch node creation and lookup counters
- namespace count, per-namespace node count, roots, and metadata bytes
- branch metadata bytes, soft max, ratio, and over-limit state
- payload eviction or demotion counters labeled by namespace and action
- protected-root payload decisions and protected-root payload bytes by residency
- slot ref acquire/release counters and peak concurrent refs
- namespace validation pass/fail counters
- `/cache` diagnostics for branch forest totals, namespace breakdown, metadata pressure, protected
  roots, active slot refs, and peak refs

Metric additions must not remove Stage 4, Stage 5, or Stage 6 metric names.

## Risks and blockers

| Risk | Mitigation |
| --- | --- |
| Flat entry removal can break descriptor ownership | Keep payload descriptors controller-owned and make branch nodes hold descriptor IDs only. |
| Forest lookup can refresh or restore an unsafe namespace | Validate namespace before payload resolution and before any live slot mutation. |
| Slot ref leaks can make payloads permanently unevictable | Add acquire/release tests on save, load, reset, overwrite, and slot destruction paths. |
| Metadata pressure could accidentally prune topology | Keep Stage 7 metadata pressure diagnostic-only and test topology before and after checks. |
| Protected roots could become payload pins again | Test graph preservation separately from protected-root payload demotion or eviction. |
| Global eviction may regress Stage 4 LRU semantics | Reuse existing protected-root ordering rules and rerun Stage 4 controller regressions. |
| Concurrency coverage may depend on sanitizer availability | Run TSAN where supported; otherwise record the limitation and keep deterministic mixed-thread tests. |

## Review readiness

This plan is ready for independent review when the reviewer can confirm:

- It references the accepted Stage 7 design baseline, Part 10 PASS review, and Part 11 manager gate.
- It keeps code implementation closed until independent plan review and manager approval.
- It names affected modules, dependencies, tests, metrics, diagnostics, build evidence, and risks.
- It preserves Stage 4 protected-root payload budget behavior, Stage 5 descriptor validation, and
  Stage 6 cold residency contracts.
- It does not introduce Stage 8+ branch pruning, metadata-only nodes, deduplication, or
  checkpoint-first restore.
