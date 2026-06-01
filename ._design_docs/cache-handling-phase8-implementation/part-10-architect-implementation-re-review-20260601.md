# Stage 8 architect implementation re-review - 2026-06-01

Source: [../cache-handling-phase8-implementation.md](../cache-handling-phase8-implementation.md)

## Scope

This re-review checked the Developer corrections in
[Part 9](part-09-implementation-review-corrections-20260601.md) against the
three blocking findings from
[Part 8](part-08-architect-implementation-review-20260601.md). The review
covered the production restore path, Stage 8 Prometheus metric shape,
branch-metadata admission rejection, focused regression tests, document size
rules, and index state.

Primary files reviewed:

- `tools/server/server-context.cpp`
- `tools/server/server-cache-hybrid.*`
- `tests/test-step13-stage8.cpp`
- `tools/server/tests/unit/test_cache_modes.py`
- Stage 8 design Parts 3 through 5
- Stage 8 implementation Parts 8 and 9

## Verdict

PASS.

The Developer corrections close S8-IMPL-01, S8-IMPL-02, and S8-IMPL-03. I did
not find new architecture blockers in the re-review scope.

## Findings

### S8-IMPL-01: production restore re-materialization

Status: CLOSED.

`try_restore_from_cache()` now calls
`select_restore_source_for_metadata_only()` after branch lookup selects the
candidate and before slot snapshots, context clearing, payload validation, or
slot state mutation. The helper calls
`branch_forest_index::plan_rematerialization()` for selected metadata-only
nodes, rejects validation mismatch with miss counters and mismatch counters,
and falls back without modifying the selected node or slot.

When the plan has a usable payload-bearing source ancestor, the restore path
switches to that source entry and restores from that payload. This satisfies
the Stage 8 contract for replay from the nearest valid source while preserving
fallback safety. The later save path remains responsible for attaching the new
payload to the selected metadata-only node after replay succeeds.

Focused evidence exists in `tests/test-step13-stage8.cpp` for restore-source
selection, successful re-materialization, failed re-materialization preserving
metadata-only state, and mismatch handling.

### S8-IMPL-02: Prometheus Stage 8 metric shape

Status: CLOSED.

The `/metrics` exporter in `tools/server/server-context.cpp` now emits the
Stage 8 metric names from the approved design:

- `cache_metadata_only_retentions_total`
- `cache_node_rematerializations_total`
- `cache_node_rematerialization_bytes_total`
- `cache_validation_mismatches_total`
- `cache_mismatch_parent_selections_total`
- `cache_equivalent_branch_deduplications_total`
- `cache_branch_pruning_total`
- `cache_branch_pruned_metadata_bytes_total`
- `cache_cold_cleanup_total`
- `cache_branch_metadata_admission_rejections_total`

The metric lines include the design labels for namespace, reason, result,
method, source, and action as applicable. The server's existing `mode` label is
also present and does not conflict with the Stage 8 label contract.

`tools/server/tests/unit/test_cache_modes.py` now asserts the Stage 8 names and
label combinations through the public metrics surface.

### S8-IMPL-03: branch-metadata admission rejection

Status: CLOSED.

`admit_entry_with_payload()` now enforces the branch-metadata budget after node
creation and before publishing the entry to the LRU and prefix indexes. If
metadata pruning cannot bring usage under the soft limit, the code removes the
new payload, removes the new branch node, erases the entry, increments
`cache_branch_metadata_admission_rejections_total`, records over-limit pressure,
and returns admission failure.

Focused regression tests cover protected-root-only pressure and active-ref-only
pressure. Both cases reject the new admission and preserve the pre-existing
entry.

## Non-blocking observations

- The added restore-source test verifies the production selection helper used
  by `try_restore_from_cache()` without constructing a full `server_slot` in
  the focused binary. This is acceptable for the Stage 8 gate because the
  production restore path now calls the same helper before state mutation.
- Metadata-only restore from a cold source ancestor still falls back until the
  source is promotable through the existing payload flow. I did not treat that
  as a Stage 8 blocker because the reviewed requirement is restore from a valid
  payload-bearing source and safe fallback on unavailable sources.
- Document sizes remain under the 300-line split limit.

## Commands run

```powershell
cmake --build build --config Release --target test-step13-stage8 -j 4
ctest --test-dir build -C Release -R test-step13-stage8 --output-on-failure
cmake --build build --config Release --target test-cache-controller -j 4
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
$env:LLAMA_SERVER_BIN_PATH='D:\source\llama.cpp-jet\build\bin\Release\llama-server.exe'
$env:LLAMA_SERVER_TEST_SKIP_MODEL_PRELOAD='1'
pytest tools/server/tests/unit/test_cache_modes.py
git diff --check
```

Results:

- `test-step13-stage8` built and passed.
- `test-cache-controller` built and passed.
- `test_cache_modes.py` passed with `3 passed, 1 xfailed`.
- `git diff --check` passed.

The Python run also printed pre-existing Requests and pytest-asyncio warnings;
they did not fail the test.

## Gate state

Stage 8 implementation re-review is PASS. The implementation can move to the
next Manager gate for QA/test execution handoff.
