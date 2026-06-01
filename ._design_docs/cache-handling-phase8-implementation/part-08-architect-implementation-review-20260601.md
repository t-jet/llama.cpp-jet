# Stage 8 architect implementation review - 2026-06-01

Source: [../cache-handling-phase8-implementation.md](../cache-handling-phase8-implementation.md)

## Scope

This review checked the current worktree against the approved Stage 8 design
and implementation plan. The evidence included:

- `tools/server/server-cache-graph.*`
- `tools/server/server-cache-hybrid.*`
- `tools/server/server-cache-store-cold.*`
- `tools/server/server-context.cpp`
- `tests/CMakeLists.txt`
- `tests/test-step13-stage8.cpp`
- Stage 8 implementation evidence Parts 6 and 7

Review focus matched the active gate: metadata-only retention, pruning,
re-materialization validation, mismatch handling, equivalent-branch
deduplication, cold cleanup ownership, budget enforcement, slot references,
and metrics.

## Verdict

REWORK.

The focused Stage 8 test target builds and passes, but the implementation does
not yet satisfy the approved production and observability contracts.

## Findings

### S8-IMPL-01: Production restore does not invoke metadata-only re-materialization

Severity: BLOCKING

Approved requirement:

- Stage 8 design Part 3, "Re-materialization trigger": the controller starts
  re-materialization when branch lookup selects a metadata-only node as the
  restore or branching point and no better payload-bearing equivalent is
  available in the same namespace.
- Stage 8 implementation plan Step 8.5 requires controller integration when
  branch lookup selects a metadata-only node. Step 8.6 requires successful
  re-materialization and atomic save.

Code evidence:

- `tools/server/server-context.cpp:5546` through `tools/server/server-context.cpp:5644`
  selects a restore candidate, handles cold/demoting/promoting payload states,
  and then calls `validate_payload_for_restore()`. If the selected entry is
  metadata-only with an evicted descriptor, this path returns false instead of
  planning and committing re-materialization.
- `tools/server/server-context.cpp:5503` through `tools/server/server-context.cpp:5516`
  can materialize an equivalent metadata-only entry during `save_slot()`, but
  that does not cover the approved restore trigger.
- `tools/server/server-cache-hybrid.cpp:1097` and related tests exercise
  `debug_rematerialize_first_entry_for_tests()`, not the production restore
  path.

Impact:

After payload eviction, a retained metadata-only branch is visible to lookup,
but a production restore cannot re-materialize it. The behavior falls back
before the Stage 8 validation and mismatch contract runs.

Required correction:

Route the production restore path through the Stage 8 plan when lookup selects
a metadata-only node with no usable hot or promotable cold payload. Validate
the request tokens, handle mismatch as a branch divergence, commit payload
materialization only after save succeeds, and leave slot state unchanged on
fallback. Add a focused production-path test, not only a debug-helper test.

### S8-IMPL-02: Stage 8 metrics are not exported through Prometheus with required labels

Severity: BLOCKING

Approved requirement:

- Stage 8 design Part 5 says Stage 8 uses the existing Prometheus endpoint
  when metrics are enabled, and lists labels for the new counters.
- Implementation plan Step 8.11 requires the Stage 8 lifecycle decisions to be
  exposed through stats, metrics, logs, and diagnostics without removing
  earlier metric names.

Code evidence:

- `tools/server/server-cache-hybrid.cpp:627` through `tools/server/server-cache-hybrid.cpp:637`
  adds unlabeled JSON stats counters.
- `tools/server/server-context.cpp:4482` through `tools/server/server-context.cpp:4551`
  exports Stage 7 and cold-layer metrics, but none of the Stage 8 metrics from
  the approved design, such as `cache_node_rematerializations_total`,
  `cache_validation_mismatches_total`, or `cache_cold_cleanup_total`.
- `tests/test-step13-stage8.cpp:490`, `tests/test-step13-stage8.cpp:507`,
  `tests/test-step13-stage8.cpp:556`, and `tests/test-step13-stage8.cpp:585`
  assert JSON stats only. They do not check Prometheus metric names or labels.

Impact:

The implementation evidence proves internal counters exist, but the public
observability surface required by the design is absent. Operators and QA cannot
observe Stage 8 lifecycle outcomes through the approved metrics endpoint.

Required correction:

Export the Stage 8 counters in the Prometheus handler with the required
namespace, result, reason, action, source, or method labels. Add a metric-shape
test that proves the endpoint exposes the approved names and labels.

### S8-IMPL-03: Branch-metadata admission rejection is not enforced

Severity: BLOCKING

Approved requirement:

- Stage 8 design Part 2 budget model requires admission rejection or
  over-budget diagnostics after demotion, payload eviction, cold cleanup, and
  metadata pruning cannot satisfy pressure.
- Stage 8 design Part 4 requires metadata pressure handling to refuse new
  metadata admission when no safe prune candidate remains.
- Implementation plan Step 8.9 requires admission rejection as the last resort.

Code evidence:

- `tools/server/server-cache-hybrid.cpp:432` through `tools/server/server-cache-hybrid.cpp:441`
  prunes metadata and comments that admission rejection is handled later.
- `tools/server/server-cache-hybrid.cpp:1681` through
  `tools/server/server-cache-hybrid.cpp:1693` records over-limit pressure but
  does not reject an admission.
- `tools/server/server-context.cpp:5519` through `tools/server/server-context.cpp:5535`
  admits a new branch after descriptor validation without checking whether the
  branch-metadata budget remains over limit.
- `n_cache_branch_metadata_admission_rejections` is exported in JSON stats but
  is never incremented in the implementation.
- `tests/test-step13-stage8.cpp` has pruning tests, but no admission rejection
  test for the "no safe candidate remains" case.

Impact:

Stage 8 still behaves as diagnostic-only for branch metadata admission when
safe pruning cannot satisfy the budget. This violates the design change from
accounting to enforcement.

Required correction:

Check the branch metadata budget after the pressure pipeline and before new
node admission commits. If no safe pruning candidate can bring usage under the
limit, reject the admission, increment
`cache_branch_metadata_admission_rejections_total`, and emit the approved
diagnostic. Add focused tests for protected-root-only and active-ref-only
over-budget cases.

## Non-blocking observations

- `git diff --check` passed during this review.
- `test-step13-stage8` and `test-cache-controller` both built and passed in
  Release configuration.
- Document sizes remain under the 300-line split limit after this review part.
- Cold cleanup uses forest-owned referenced IDs before deleting unreferenced
  cold descriptors, but the implementation still needs the admission and
  metrics fixes above before this gate can pass.

## Commands run

```powershell
cmake --build build --config Release --target test-step13-stage8 -j 4
ctest --test-dir build -C Release -R test-step13-stage8 --output-on-failure
cmake --build build --config Release --target test-cache-controller -j 4
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
git diff --check
```

Results: all commands passed.

## Gate state

Stage 8 implementation review is REWORK. Do not advance to QA until the three
blocking findings above are corrected and re-reviewed.
