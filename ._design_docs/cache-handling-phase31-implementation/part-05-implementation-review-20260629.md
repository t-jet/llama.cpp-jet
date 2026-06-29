# Stage 31 implementation review 2026-06-29

VERDICT: PASS

## Scope

Review subject:

- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-context.cpp`
- `tools/server/server-context.h`
- `tests/test-cache-controller.cpp`
- `._design_docs/cache-handling-phase31-implementation.md`
- `._design_docs/cache-handling-phase31-implementation/part-03-probe-evidence-20260629.md`
- `._design_docs/cache-handling-phase31-implementation/part-04-implementation-evidence-20260629.md`
- `._design_docs/.test_reports/test-report-20260629-12-stage30-01.md`

Baseline checked:

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-architecture.md`
- `._design_docs/cache-handling-architecture/part-02-restore-and-residency-flow.md`
- `._design_docs/cache-handling-architecture/part-09-chat-path-prompt-boundary-invariant.md`
- `._design_docs/cache-handling-requirements.md`
- `._design_docs/cache-handling-requirements/part-01-status.md`
- `._design_docs/cache-handling-requirements/part-02-fully-slot-independent-shared-reuse.md`
- `._design_docs/cache-handling-phase31-design.md`
- `._design_docs/cache-handling-phase31-design/part-01-design-review-20260629.md`
- `._design_docs/cache-handling-phase31-implementation/part-01-implementation-plan.md`
- `._design_docs/cache-handling-phase31-implementation/part-02-implementation-plan-review-20260629.md`

This is an independent Architect implementation review. No production code was
changed in this review session.

## Gate status

PASS. Stage 31 implementation may move to the next Manager gate.

No blocking or non-blocking findings remain open.

## Decisions

### Probe ordering

PASS. Part 03 records P31-01 through P31-05 before the production fix:

- P31-01 proves exact A/A save and lookup parity, while near-prefix A/B misses
  because prompt-local metadata split the namespace.
- P31-02 shows 20 prompt variants produced 20 namespaces before the fix.
- P31-03 records Stage 30 workload source classes and a focused token fixture.
- P31-04 shows save and lookup parity for identical metadata and shows
  `preparation_id`, degraded reason, span, and checksum changes affected the
  old namespace.
- P31-05 records duplicate HELP/TYPE blocks and raw namespace labels in the
  Stage 30 metrics artifact.

The evidence is enough to authorize the approved production fix. It is not a
full live Stage 30 rerun, and Part 04 correctly leaves that as remaining risk.

### Namespace computation

PASS. `compute_namespace_id(metadata)` now hashes the stable runtime
compatibility key plus `metadata.compatibility_key` only
(`tools/server/server-cache-hybrid.cpp:4248`). It excludes `preparation_id`,
degraded reason, prompt boundary spans, checksums, protected flags, and boundary
labels.

Save and restore use the same metadata namespace path:

- save: `tx_save()` computes `namespace_id = compute_namespace_id(metadata)`
  before admission (`tools/server/server-cache-hybrid.cpp:4778`);
- restore: `tx_restore()` and restore classification compute
  `lookup_namespace_id = compute_namespace_id(task.prompt_metadata)`
  (`tools/server/server-cache-hybrid.cpp:4938`,
  `tools/server/server-cache-hybrid.cpp:5186`).

Validation safety is preserved. Branch lookup still filters namespace
compatibility, then candidate selection and restore paths keep the existing
token, checksum, descriptor, pair-state, payload-kind, and checkpoint validation
checks before slot mutation.

One no-argument helper still returns the raw compatibility key string rather
than the hashed metadata namespace. I found no production save/restore path
mixing that helper with the metadata path. Existing non-metadata test helpers
continue to pass in the focused test run.

### Metrics

PASS. The Prometheus writer now gates cache HELP/TYPE output by metric name
through `cache_metric_headers` (`tools/server/server-context.cpp:4448`). Reused
metric names emit multiple samples but one HELP block and one TYPE block.

Public labels are bounded:

- `llamacpp:cache_branch_lookups_total` uses bounded `method` labels and sums
  raw namespace buckets (`tools/server/server-context.cpp:4498`).
- namespace node/root/metadata gauges use `scope="all"` and aggregate all raw
  namespace ids (`tools/server/server-context.cpp:4527`).

Raw namespace diagnostics remain in `get_stats()` JSON under
`branch_lookup_namespaces` and `branch_forest.namespaces`
(`tools/server/server-cache-hybrid.cpp:1218`).

### Tests

PASS. Focused Stage 31 coverage was added in
`tests/test-cache-controller.cpp`:

- exact repeat namespace parity and exact lookup:
  `test_stage31_namespace_uses_runtime_compatibility_only`
  (`tests/test-cache-controller.cpp:1543`);
- near-prefix shared namespace and prefix lookup:
  same test, B over A returns 4 matching tokens;
- namespace cardinality bounded for prompt variants:
  `test_stage31_namespace_cardinality_bounded_for_prompt_variants`
  (`tests/test-cache-controller.cpp:1579`);
- workload token shape fixture:
  `test_stage31_workload_token_fixture`
  (`tests/test-cache-controller.cpp:1602`);
- metric HELP/TYPE and bounded-label shape:
  `test_stage31_metric_shape_bounded_labels`
  (`tests/test-cache-controller.cpp:1616`).

Namespace isolation for stable runtime inputs remains covered by the existing
namespace tests that still run immediately around the new Stage 31 tests:
model path, draft model, draft context mode, template, LoRA, control vectors,
multimodal identity, and KV-unified state.

Checkpoint-dependent safety is covered by existing Stage 9, Stage 17, Stage 22,
Stage 23, and Stage 28 checkpoint tests in the same `test-cache-controller`
binary. That is acceptable because Stage 31 changed namespace selection, not
checkpoint descriptor validation. The gap is only evidence granularity: no new
Stage 31-specific bad-checksum checkpoint test was added.

### Stage 30 wording

PASS. The Stage 30 report now qualifies the cold-start interpretation:
exact-repeat rows can produce in-cycle hits in one cold server process, so zero
hybrid hits required Stage 31 investigation
(`._design_docs/.test_reports/test-report-20260629-12-stage30-01.md:67`).

## Evidence run by reviewer

Commands:

```powershell
cmake --build build --config Release --target test-cache-controller -j 4
.\build\bin\Release\test-cache-controller.exe
ctest --test-dir build -C Release -R cache -V
git diff --check -- tools/server/server-cache-hybrid.cpp tools/server/server-cache-hybrid.h tools/server/server-context.cpp tools/server/server-context.h tests/test-cache-controller.cpp ._design_docs/cache-handling-phase31-implementation.md ._design_docs/cache-handling-phase31-implementation/part-03-probe-evidence-20260629.md ._design_docs/cache-handling-phase31-implementation/part-04-implementation-evidence-20260629.md ._design_docs/.test_reports/test-report-20260629-12-stage30-01.md
```

Results:

- Release build PASS.
- Direct `test-cache-controller.exe` PASS, 142 tests.
- `ctest -R cache` PASS, 1/1 tests.
- Initial implementation-subject `git diff --check` PASS.

## Required corrections

None.

## Advisory gaps

- No full live Stage 30 workload rerun was performed after the fix. Manager or
  QA should decide whether to run it before closing the Stage 30/31 loop.
- The Stage 30 workload probe used source-message grouping plus focused token
  fixtures, not a full live tokenizer replay of all 200 Stage 30 rows.
- Checkpoint-dependent safety relies on existing checkpoint regression tests
  that still pass, not a new Stage 31-specific corrupted-boundary test.

## Handoff

Next owner: Manager.

Next gate: Manager implementation gate. The implementation review is PASS.
Manager can move Stage 31 toward QA or closure planning, with the live Stage 30
rerun decision called out as the main remaining evidence choice.
