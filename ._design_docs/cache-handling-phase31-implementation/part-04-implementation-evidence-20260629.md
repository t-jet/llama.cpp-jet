# Stage 31 implementation evidence 2026-06-29

Status: implementation complete; ready for implementation gate review
Owner: Developer

## Production changes

Namespace computation:

- `hybrid_cache_controller::compute_namespace_id(metadata)` now hashes stable
  runtime compatibility plus `metadata.compatibility_key` only.
- Prompt-local validation data is excluded from namespace hashing:
  `preparation_id`, degraded reason, boundary spans, checksums, protected
  flags, and boundary labels.
- Restore validation still runs after namespace lookup through existing token,
  checksum, descriptor, pair-state, payload-kind, and checkpoint checks.

`preparation_id` decision:

- Assignment trace found `rendered-text-boundary-inference` and
  `token-position-fallback` in `server-context.cpp`.
- Both values describe request preparation/fallback paths, not runtime ABI.
- Decision: validation/diagnostic-only; not a namespace input.

Metrics:

- Cache Prometheus writer now emits HELP and TYPE once per metric name.
- `llamacpp:cache_branch_lookups_total` exposes bounded `method` labels only.
- Namespace node/root/metadata gauges expose one bounded `scope="all"` sample
  per metric.
- Raw namespace ids remain available in `get_stats()` JSON under
  `branch_lookup_namespaces` and `branch_forest.namespaces`.

Stage 30 wording:

- `test-report-20260629-12-stage30-01.md` now qualifies the cold-start hit
  interpretation: exact-repeat rows can produce in-cycle hits in one cold
  server process, so 0 hybrid hits required Stage 31 investigation.

## Test changes

Added focused Stage 31 tests in `tests/test-cache-controller.cpp`:

- `test_stage31_namespace_uses_runtime_compatibility_only`
- `test_stage31_namespace_cardinality_bounded_for_prompt_variants`
- `test_stage31_workload_token_fixture`
- `test_stage31_metric_shape_bounded_labels`

Test-only helpers:

- `hybrid_cache_controller::debug_compute_namespace_id_for_tests()`
- `server_cache_stage31_prometheus_rows_for_tests()`

New regression coverage:

- exact repeat namespace parity and lookup;
- near-prefix shared namespace and prefix lookup;
- namespace isolation by stable compatibility key remains;
- prompt-local checksum/span/degraded/preparation changes do not change
  namespace;
- metric HELP/TYPE shape and bounded branch/namespace labels.

Checkpoint-dependent safety is covered by existing Stage 9 and Stage 22
checkpoint tests in the same run. They still pass after namespace broadening,
including checkpoint boundary metadata and checkpoint-dependent exact fallback.

## Build and test evidence

Probe build/run before production fix:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
.\build\bin\Release\test-cache-controller.exe
```

Result:

- PASS, including temporary current-behavior Stage 31 probes.

Final build/run:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
.\build\bin\Release\test-cache-controller.exe
ctest --test-dir build -C Release -R cache -V
```

Result:

- Build PASS.
- Direct `test-cache-controller.exe` PASS.
- `ctest -R cache` PASS: 1/1 tests, `test-cache-controller`.

Observed warnings:

- Release build reports pre-existing `%zu` format warnings in later
  `tests/test-cache-controller.cpp` code outside Stage 31 changes.
- A Debug build attempt without `--config Release` failed in pre-existing
  debug-only `tx_assert_mutex_held()` const mutex code at
  `server-cache-hybrid.cpp:4601`. Release is the evidence path used here.

## Hygiene

Commands:

```powershell
git diff --check -- tools/server/server-cache-hybrid.cpp tools/server/server-cache-hybrid.h tools/server/server-context.cpp tools/server/server-context.h tests/test-cache-controller.cpp ._design_docs/cache-handling-phase31-implementation.md ._design_docs/cache-handling-phase31-implementation/part-03-probe-evidence-20260629.md ._design_docs/cache-handling-phase31-implementation/part-04-implementation-evidence-20260629.md ._design_docs/.test_reports/test-report-20260629-12-stage30-01.md
```

Result:

- PASS.

## Handoff

Stage 31 is ready for implementation gate review. Remaining risk is live server
confirmation under the Stage 30 workload; focused tests prove the root behavior
and protect the production fix.
