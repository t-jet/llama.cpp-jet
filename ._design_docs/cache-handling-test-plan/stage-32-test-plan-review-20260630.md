# Stage 32 test-plan review 2026-06-30

VERDICT: PASS

## Scope

Review subject:

- `._design_docs/cache-handling-test-plan.md`
- `._design_docs/cache-handling-test-plan/part-36-stage32-live-comparison-rerun.md`

Inputs checked:

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase32-design.md`
- `._design_docs/cache-handling-phase32-implementation.md`
- `._design_docs/cache-handling-phase32-implementation/part-02-plan-corrections-20260630.md`
- `._design_docs/cache-handling-phase32-implementation/part-03-implementation-plan-re-review-20260630.md`

No comparison was run. This is a test-plan review only.

## Findings

No blocking findings.

No non-blocking findings.

## Checklist

Scope is current. Part 36 matches the Stage 32 design and corrected
implementation plan: rerun the Stage 29/30 legacy-vs-hybrid comparison after
Stage 31, require live reuse and metric-shape evidence, keep debug-only and
known warning cleanup out of scope, and forbid product-code edits until failed
live evidence and a Manager correction loop.

Wording is generic enough for execution. The plan uses concrete example paths
for the current 2026-06-30 run, but it also requires the next chronological
suffix when the execution date or setup state changes. It does not present any
planned command output as evidence, and it says the full comparison must not
run during the planning gate.

Clean build and stale-binary rules are complete. The plan requires a clean
Release CUDA configure and build of `llama-server` and
`test-cache-controller`, focused controller evidence, CUDA proof, binary path,
size, UTC timestamp, git state, and the corrected Part 02 stale-binary proof.
The stale-binary decision compares `llama-server.exe` with the newest Stage 31
production source and `test-cache-controller.exe` with
`tests/test-cache-controller.cpp`, then blocks on any stale result.

Execution commands are reproducible. Dry-run and live commands specify the
driver, model, run root, report path, cold path, binary, port, budgets,
context, parallelism, seed, request count, cycles, and equivalence prompt
count. The dry-run gate checks fixture, binary, port, paths, unique cold path,
and no server startup. The full run repeats the same command without
`-DryRun` and preserves partial artifacts if the 150 to 180 minute budget ends.

Evidence format is sufficient. Required rows cover correctness, reuse,
namespace bounds, bounded labels, HELP/TYPE shape, hot RAM, cold store,
performance, errors, cleanup, and hygiene. Part 36 points to the Part 02
evidence-only extractor for derived JSON and keeps traffic/product behavior
unchanged.

Output conventions are clear. Durable Markdown goes under
`._design_docs/.test_reports/`; non-durable logs and derived JSON go under
`_test_output/stage32-cache-modes-20260630-01/`; the hybrid cold path is
outside the repo. The plan keeps public/durable evidence free of prompts, raw
namespace IDs, paths, and payload bytes.

Classification rules are executable. PASS, PARTIAL, FAIL, and BLOCKED are
defined with enough detail to classify fresh execution without new decisions.
The rules cover zero reuse, high namespace cardinality, unbounded labels,
duplicate HELP/TYPE blocks, cold-store failures, throughput regression,
missing fixtures, stale binaries, setup failure, missing artifacts, and unsafe
cleanup.

The parent test plan is already 300 lines, so this review intentionally does
not add a parent review-report link. `document-index.md` is the durable index
entry for this review.

## Gate

Stage 32 test plan is ready for Manager test-plan gate and then QA execution.
QA can execute from Part 36 plus the corrected implementation plan without
inventing missing stale-binary, evidence extraction, output path, or
classification decisions.
