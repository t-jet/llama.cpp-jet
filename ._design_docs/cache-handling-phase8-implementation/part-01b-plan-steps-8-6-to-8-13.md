# Stage 8 implementation plan - Part 1B

Source: [part-01-implementation-plan.md](part-01-implementation-plan.md)

## Step 8.6: successful re-materialization and atomic save

Goal: after validation succeeds, save a new payload for the selected node,
then flip the node out of metadata-only state only after the save succeeds.
Target and draft materialization must commit atomically.

Tests:

- Successful materialization creates a payload descriptor and updates usage.
- Save failure leaves the node metadata-only.
- Target/draft payloads commit together.

## Step 8.7: validation mismatch handling and new branch creation

Goal: on mismatch, reject materialization for the mismatched node, select the
deepest validated parent, and attach a new payload only to the new branch.

Tests:

- Mismatch creates a new branch under the deepest validated ancestor.
- The mismatched metadata-only node remains unchanged.
- No-segment-validates uses the namespace root as parent.

## Step 8.8: equivalent-branch deduplication admission

Goal: before creating a node, search for an equivalent branch. Reuse a
payload-bearing equivalent, re-materialize a metadata-only equivalent, or
canonicalize duplicates. Lookup and admission must be atomic.

Tests:

- Equivalent payload-bearing node is reused.
- Equivalent metadata-only node is re-materialized.
- Concurrent admission does not create duplicate nodes.

## Step 8.9: branch-metadata budget enforcement

Goal: enforce the branch metadata budget after the pressure pipeline runs:
demotion, payload eviction, cold cleanup, metadata pruning, then admission
rejection or over-budget diagnostics.

Tests:

- Safe metadata-only leaves are pruned.
- Protected roots and active refs are excluded.
- Admission rejection is the last resort when pruning cannot satisfy budget.

## Step 8.10: cold cleanup ownership safety

Goal: prove descriptor ownership before deleting cold payload bytes. The
forest identifies which descriptors are still referenced; the cold store only
receives IDs to delete.

Tests:

- Unreferenced cold payloads are deleted.
- Retained descendants block deletion.
- Target/draft pairs are cleaned together.
- Partial delete failure keeps descriptors for retry.

## Step 8.11: metrics and diagnostics

Goal: expose Stage 8 lifecycle decisions through stats, metrics, logs, and
diagnostics without removing earlier metric names.

Required metric names:

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

## Step 8.12: build wiring and standalone test target

Goal: compile Stage 8 changes and add `test-step13-stage8`.

Required commands:

```powershell
cmake --build build --config Release --target test-step13-stage8 -j 4
ctest --test-dir build -C Release -R test-step13-stage8 --output-on-failure
```

## Step 8.13: regression, evidence, and handoff docs

Goal: update durable implementation evidence and record exact build and test
results, gaps, and next gate state.
