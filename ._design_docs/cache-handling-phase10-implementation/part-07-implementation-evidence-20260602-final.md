# Stage 10 implementation evidence - 2026-06-02 final pass

Source: [../cache-handling-phase10-implementation.md](../cache-handling-phase10-implementation.md)

## Status

Implementation state: READY FOR ARCHITECT REVIEW with coverage and benchmark
environment blockers recorded.
QA execution state: not opened.
Commit state: not committed.

## Completed scope

This pass finished the practical Stage 10 implementation items that fit the
current repository state.

- Added bounded Stage 10 metric rows for exact restores, payload transitions,
  payload evictions, protected-root pressure, fallback restores, and structured
  diagnostics.
- Exported those rows through `/metrics` with escaped Prometheus label values.
- Kept existing raw counters for Stage 6 through Stage 9 behavior.
- Added startup validation for impossible hybrid budgets: size limits less than
  `-1` and one-token hybrid budgets now fail before requests are accepted.
- Added focused pressure and abuse coverage for tiny protected-root budgets,
  branch metadata pressure, a larger branch forest, queue pressure, shutdown
  with pending work, and repeated descriptor integrity failures.
- Confirmed no hybrid cache request-marker surface is enabled. Invalid marker
  abuse tests are not applicable in this repo state.

## R61-R68 audit

| Req | Status | Evidence |
| --- | --- | --- |
| R62 exact hits | Filled | `cache_exact_blob_restores_by_shape` and public `cache_exact_blob_restores_total` record result, kind, pair state, residency/profile in direct stats, and bounded reason. |
| R63 checkpoints | Present | Existing checkpoint hit and restore shape rows remain public through `cache_checkpoint_hits_total` and `cache_checkpoint_restores_total`. |
| R64 promotions | Filled | `cache_payload_transitions_by_shape` records promotion queued, success, and failure rows with bounded result and reason. |
| R65 demotions | Filled | The same transition rows cover demotion queued, success, failure, and queue pressure. |
| R66 payload evictions | Filled | `cache_payload_evictions_by_shape` records eviction result and bounded reason. Existing byte counters remain. |
| R66a branch pruning | Present | Existing branch pruning, pruned metadata bytes, and metadata admission rejection metrics remain public. |
| R67 protected roots | Filled | `cache_protected_root_decisions_by_shape` records decision, pressure source, result, and reason. Existing protected-root counters remain. |
| R68 fallback/failure | Filled | `cache_fallback_restores_by_shape` and `cache_structured_diagnostics_by_shape` record bounded strategy, result, event, and reason. |

## Changed files

Code and tests:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tests/test-stage10-cold-store-hardening.cpp`

Documentation:

- `tools/server/hybrid-cache.md`
- `tools/server/tests/README.md`
- `._design_docs/cache-handling-phase10-implementation.md`
- `._design_docs/cache-handling-phase10-implementation/part-07-implementation-evidence-20260602-final.md`
- `._design_docs/document-index.md`

Earlier Part 6 files remain part of the same uncommitted Stage 10 surface.

## R107 minimal-intrusion notes

Touched shared or legacy-adjacent paths:

- `tools/server/server-context.cpp`: required because `/metrics` is the shared
  public exporter. The edits only escape labels and export hybrid stats rows;
  legacy cache policy and request handling are unchanged.
- `tests/CMakeLists.txt`: already touched in Part 6 to register the Stage 10
  focused test target.

No legacy cache controller behavior was changed.

## Evidence

Build:

- `cmake --build build --config Release --target test-stage10-cold-store-hardening`
  - Result: PASS.
- `cmake --build build --config Release --target test-step10-metrics`
  - Result: PASS.
- `cmake --build build --config Release --target llama-server test-step2-cold-store test-step3-4-cold-store-write-read test-cache-controller test-step6-demotion-protocol test-step7-promotion-protocol test-step11-test-hooks-fault-injection test-step12-branch-graph test-step13-stage8`
  - Result: PASS.

Focused tests:

- `ctest --test-dir build -C Release -R "test-(stage10-cold-store-hardening|step10-metrics)" --output-on-failure`
  - First run: FAIL in the queue pressure test because capacity `0` means
    "use default" in the existing worker seam.
  - Corrective action: changed the test to capacity `1` with two queued
    demotions before worker start.
  - Rerun result: PASS, 2/2 tests.
- `ctest --test-dir build -C Release -R "test-(step2-cold-store|step3-4-cold-store-write-read|cache-controller|step6-demotion-protocol|step7-promotion-protocol|step10-metrics|step11-test-hooks-fault-injection|step12-branch-graph|step13-stage8|stage10-cold-store-hardening)" --output-on-failure`
  - Result: PASS, 10/10 tests.

Coverage:

- `clang --version`
  - Result: BLOCKED, `clang` not found on PATH.
- `llvm-profdata --version`
  - Result: BLOCKED, `llvm-profdata` not found on PATH.
- `llvm-cov --version`
  - Result: BLOCKED, `llvm-cov` not found on PATH.
- `gcovr --version`, `lcov --version`, `gcov --version`
  - Result: BLOCKED, fallback coverage tools not found on PATH.

Benchmark:

- `k6 version`
  - Result: BLOCKED, `k6` not found on PATH.
- `python bench.py --help` from `tools/server/bench`
  - Result: BLOCKED, `matplotlib` import failed before argument parsing.

## Security review update

| Category | Status | Notes |
| --- | --- | --- |
| A01 | Mitigated for touched surfaces | Protected-root decisions remain server policy driven. No client cache marker surface is enabled. |
| A03 | Mitigated for touched surfaces | Prometheus labels are escaped and new rows use bounded enum-like fields. |
| A04 | Mitigated for touched surfaces | Impossible startup budgets fail before serving requests. Pressure tests prefer recompute or rejection over unsafe reuse. |
| A05 | Mitigated or blocked by environment | Cold-root hardening remains from Part 6. Coverage and benchmarks are blocked by missing tools, not by product behavior. |
| A08 | Mitigated for touched surfaces | Repeated descriptor and cold-file integrity failures remain stable and fall back. |
| A09 | Mitigated for touched surfaces | Structured diagnostic rows now cover descriptor rejection, fallback, queue pressure, protected-root pressure, promotion, and demotion. |

## Remaining implementation items

Coverage and benchmark evidence remain blocked by local tool availability. They
need a host with LLVM coverage tools or the documented GCOV fallback, plus k6
and Python benchmark dependencies.

No marker validation code was added because no hybrid cache request-marker
surface is enabled.

## Handoff

Implementation is ready for Architect review of the code, tests, docs, and
evidence limits. QA execution remains closed.
