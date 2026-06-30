# Manager inputs: Stage 32 fix Stage 31 findings and rerun comparison

MANAGER INPUTS - NOT AN APPROVED DESIGN

Date: 2026-06-29
Stage: 32
Branch: work-branch
Current gate: Design
Current owner: Architect
Most recent completed gate: Stage 31 Manager closure PASS

## User directive

Verbatim user request:

```text
ok. open the next stage which will fix al things found on the stage 31 and run comparison tests again to verify cache performance.
```

Manager interpretation:

- Open Stage 32 as a follow-up to Stage 31.
- Fix any remaining Stage 31 follow-up items that still need product or test
  work.
- Rerun model-backed comparison traffic on the current fixed tree.
- Verify cache performance after the Stage 31 namespace and metric fixes.

## Starting evidence

Stage 31 closed PASS, but left live comparison confirmation as advisory:

- `cache-handling-phase31-implementation/part-06-manager-closure-20260629.md`
- `.test_reports/test-report-20260629-13-stage31-01.md`
- `.test_reports/test-report-20260629-13-stage31-01-developer-review.md`

Stage 31 product result:

- Namespace hashing now uses stable runtime compatibility plus
  `metadata.compatibility_key`.
- Prompt-local metadata remains validation and diagnostics data.
- Prometheus cache metrics aggregate bounded labels and emit one HELP/TYPE
  block per metric name.

Stage 31 remaining advisory items:

- Rerun the Stage 30 model-backed comparison on the current tree.
- Confirm non-zero hybrid reuse on exact-repeat or near-prefix rows.
- Confirm bounded namespace cardinality in live `/metrics`.
- Confirm single HELP/TYPE blocks in live `/metrics`.
- Re-check cache performance after the namespace fix.

Other observed items to classify in Stage 32 design:

- Debug build without `--config Release` hit a known debug-only const-mutex
  compile issue at `server-cache-hybrid.cpp:4601`.
- Release build emitted pre-existing `%zu` warnings in later
  `tests/test-cache-controller.cpp` code outside Stage 31 changes.

## Manager scope request

Architect should write the Stage 32 design from scratch. The design should
decide which Stage 31 observations are in scope for fixes before comparison
rerun, and which are explicit non-goals.

Expected design coverage:

- Fix scope for remaining Stage 31 findings or observations.
- Comparison rerun plan based on the Stage 29/30 cache-modes driver.
- Required evidence for non-zero hybrid cache reuse.
- Required evidence for bounded namespace count and bounded Prometheus labels.
- Performance acceptance criteria for cache comparison.
- Wall-clock budget based on Stage 30 timing: cold-start model legs took about
  27.6 min legacy and 31.3 min hybrid on 2026-06-29.
- Clean build and stale-binary rules.
- Failure handling if live comparison still reports zero hits or high namespace
  cardinality.

## Source documents

- `._design_docs/cache-handling-phase31-design.md`
- `._design_docs/cache-handling-phase31-implementation.md`
- `._design_docs/cache-handling-phase31-implementation/part-03-probe-evidence-20260629.md`
- `._design_docs/cache-handling-phase31-implementation/part-04-implementation-evidence-20260629.md`
- `._design_docs/cache-handling-phase31-implementation/part-06-manager-closure-20260629.md`
- `._design_docs/.test_reports/test-report-20260629-12-stage30-01.md`
- `._design_docs/.test_reports/test-report-20260629-13-stage31-01.md`
- `._design_docs/.test_reports/test-report-20260629-13-stage31-01-developer-review.md`
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`
- `._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`

## Stage intake decision

Stage 32 intake PASS.

Next owner: Architect.

Next gate: Design. Create `._design_docs/cache-handling-phase32-design.md` and
update `._design_docs/document-index.md`.
