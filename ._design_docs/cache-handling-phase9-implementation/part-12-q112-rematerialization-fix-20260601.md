# Stage 9 Q112 re-materialization fix - 2026-06-01

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
QA report: [../.test_reports/test-report-20260601-05.md](../.test_reports/test-report-20260601-05.md)
Test-results review: [part-11-test-results-review-20260601.md](part-11-test-results-review-20260601.md)
Owner: Developer
Status: fix implemented; ready for Architect bug-fix review

## Scope

This fix addresses Q112 from QA report 20260601-05. Q112 failed because
`test-step13-stage8.exe` aborted in
`test_hybrid_rematerialization_commits_target_draft_together` with descriptor
validation reporting `missing target payload`.

Q103 and Q102 public checkpoint probe limitations were not changed in this
fix pass.

## Root cause

Stage 9 made payload handling kind-aware for exact and checkpoint descriptors.
After metadata-only eviction, the entry's exact payload ID was cleared, but the
old evicted exact descriptor could remain in `payload_descriptors` for the same
entry. Re-materialization then attached a new target/draft exact descriptor, so
descriptor accounting saw both the stale evicted target/draft descriptor and
the new valid target/draft descriptor.

## Fix

Before re-materializing an exact payload, `materialize_entry_payload()` now
removes stale evicted exact descriptors owned by the entry. It leaves checkpoint
descriptors and non-evicted exact descriptors untouched.

This keeps the re-materialized exact target/draft payload, descriptor owner,
hot payload record, branch node exact payload ID, pair state, and resident byte
accounting aligned.

## Changed files

- `tools/server/server-cache-hybrid.cpp`
- `._design_docs/cache-handling-phase9-implementation.md`
- `._design_docs/cache-handling-phase9-implementation/part-12-q112-rematerialization-fix-20260601.md`
- `._design_docs/.test_reports/test-report-20260601-05-fixes.md`
- `._design_docs/document-index.md`

## Evidence run

- `cmake --build build --config Release --target test-step13-stage8`: PASS
- `build\bin\Release\test-step13-stage8.exe`: PASS
- `cmake --build build --config Release --target test-cache-controller`: PASS
- `build\bin\Release\test-cache-controller.exe`: PASS, 59 tests
- `cmake --build build --config Release --target test-step10-metrics test-step12-branch-graph`: PASS
- `ctest --test-dir build -C Release -R "test-cache-controller|test-step10-metrics|test-step12-branch-graph|test-step13-stage8" --output-on-failure`: PASS, 4/4 tests
- `build\bin\Release\test-step10-metrics.exe`: PASS
- `git diff --check -- tools/server/server-cache-hybrid.cpp ._design_docs/cache-handling-phase9-implementation.md ._design_docs/document-index.md`: PASS

The first parallel build attempt for `test-step13-stage8` collided with a
simultaneous `test-cache-controller` build on the same object file and failed
with a Windows permission error. The target passed when rerun serially.

## Retest handoff

Next owner: Architect for bug-fix review.

After review, QA should rerun the Stage 9 focused regression set and rerun Q103
and Q102 with a public probe that proves checkpoint admission before checking
checkpoint restore or public metric evidence.
