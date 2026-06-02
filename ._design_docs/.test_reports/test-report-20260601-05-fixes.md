# Fixes for test report 20260601-05

Source report: [test-report-20260601-05.md](test-report-20260601-05.md)
Stage: 9 checkpoint integration and workload profiles
Date: 2026-06-01
Status: Q112 bug-fix review PASS; QA rerun pending

## Summary

QA report 20260601-05 found one product bug:

- Q112: `test-step13-stage8.exe` failed during target/draft
  re-materialization after metadata-only eviction.

Q100 was blocked by the same abort. Q102 and Q103 were classified later as QA
probe limitations because the public MTP run did not admit a checkpoint before
checking checkpoint restore or hit metrics. Q109 was an expected skip.

## Fix record

The durable implementation evidence is recorded in
[part-12-q112-rematerialization-fix-20260601.md](../cache-handling-phase9-implementation/part-12-q112-rematerialization-fix-20260601.md).

Fix scope:

- Remove stale evicted exact descriptors for an entry before exact-payload
  re-materialization attaches the replacement descriptor.
- Preserve checkpoint descriptors and non-evicted exact descriptors.
- Keep target/draft pair accounting and branch node exact payload identity in
  sync after re-materialization.

## Evidence

- `cmake --build build --config Release --target test-step13-stage8`: PASS
- `build\bin\Release\test-step13-stage8.exe`: PASS
- `build\bin\Release\test-cache-controller.exe`: PASS, 59 tests
- `ctest --test-dir build -C Release -R "test-cache-controller|test-step10-metrics|test-step12-branch-graph|test-step13-stage8" --output-on-failure`: PASS, 4/4 tests
- `build\bin\Release\test-step10-metrics.exe`: PASS

## Review and retest

Architect bug-fix review: PASS in
[part-13-q112-bug-fix-review-20260601.md](../cache-handling-phase9-implementation/part-13-q112-bug-fix-review-20260601.md).

Next owner: QA. QA should produce a fresh rerun report. The rerun should include
Q100/Q112 focused coverage and a corrected Q102/Q103 public probe that first
proves checkpoint admission, or clearly records why that public precondition
remains unavailable.
