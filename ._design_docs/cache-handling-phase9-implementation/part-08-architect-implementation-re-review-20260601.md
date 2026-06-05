# Stage 9 Architect implementation re-review - 2026-06-01

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
Reviewer: Architect (independent)
Gate: Implementation re-review after Part 7 corrections
Verdict: REWORK

## Scope and gate status

This re-review checks the Part 7 correction evidence against the approved
Stage 9 design, the approved implementation plan, and the corrected code.

Gate status: REWORK. The original blocking findings are mostly closed, but a
new cold-checkpoint restore blocker prevents QA planning.

## Sources reviewed

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase9-design.md`
- `._design_docs/cache-handling-phase9-design/part-01-scope-and-workload-profiles.md`
- `._design_docs/cache-handling-phase9-design/part-02-checkpoint-payload-lifecycle-and-interfaces.md`
- `._design_docs/cache-handling-phase9-design/part-03-restore-strategy-and-prepared-prompt-boundaries.md`
- `._design_docs/cache-handling-phase9-design/part-04-pairing-cold-store-metrics-and-diagnostics.md`
- `._design_docs/cache-handling-phase9-design/part-05-testability-traceability-exclusions-and-risks.md`
- `._design_docs/cache-handling-phase9-implementation.md`
- `._design_docs/cache-handling-phase9-implementation/part-01-implementation-plan.md`
- `._design_docs/cache-handling-phase9-implementation/part-02-evidence-plan-and-risks.md`
- `._design_docs/cache-handling-phase9-implementation/part-06-architect-implementation-review-20260601.md`
- `._design_docs/cache-handling-phase9-implementation/part-07-implementation-review-corrections-20260601.md`

## Code and tests reviewed

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-graph.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`

## Prior finding disposition

| ID | Disposition | Notes |
| --- | --- | --- |
| S9-IMPL-01 | Fixed | Checkpoint descriptors now carry token span, position span, boundary kind, boundary ID, boundary checksum, native-boundary flag, and boundary-required state. Production save updates entry metadata before checkpoint admission and restore validation rechecks checkpoint metadata against entry metadata. |
| S9-IMPL-02 | Fixed for the reported exact-only case | `select_restore_candidate()` rejects checkpoint-dependent candidates without a hot checkpoint, and `load_slot()` / `try_restore_from_cache()` reject checkpoint-dependent restores when checkpoint metadata is not valid. See new S9-IMPL-06 for the cold-checkpoint regression introduced by the hot-only test. |
| S9-IMPL-03 | Fixed for hot-budget accounting | The budget path now evicts or demotes both exact and checkpoint descriptors for the selected branch entry, and the added focused test proves checkpoint bytes do not remain hot after budget eviction. Per-payload eviction precision remains limited but is not the blocker in this pass. |
| S9-IMPL-04 | Fixed | Checkpoint hit and restore metric rows are now recorded by profile, payload residency, pair state, and restore result, and Prometheus export emits those label values instead of constant `all` buckets. |
| S9-IMPL-05 | Partially improved | Added focused tests cover boundary metadata, checksum rejection, missing-boundary fallback, exact-only checkpoint-dependent rejection, checkpoint cold demotion, checkpoint budget eviction, and hit metric shape. They still do not cover model-backed HTTP behavior, production task-flow boundary propagation, or cold checkpoint restore selection. |

## Blocking findings

### S9-IMPL-06: cold checkpoint payloads cannot be selected for checkpoint-dependent restore

Severity: BLOCKING

Approved design requirement:

- Part 3 requires checkpoint-dependent restore to prefer the deepest valid
  checkpoint candidate and, if the selected checkpoint payload is cold, request
  paired promotion before live mutation.
- Part 4 requires checkpoint payloads to use the same cold promotion and
  demotion machinery as exact payloads.
- Part 5 requires checkpoint cold promotion and demotion coverage.

Code evidence:

- `tools/server/server-cache-hybrid.cpp:1039` through `:1052`
  implements `entry_has_payload_kind_for_restore()` as hot-only by requiring
  residency `hot` and a hot payload record.
- `tools/server/server-cache-hybrid.cpp:1071` through `:1088`
  implements `checkpoint_path_valid_for_restore()` with that same hot-only
  predicate, so cold checkpoint descriptors are rejected as "missing
  checkpoint-bearing path".
- `tools/server/server-cache-hybrid.cpp:1099` through `:1117`
  makes `select_restore_candidate()` skip checkpoint-dependent candidates unless
  `entry_has_payload_kind_for_restore(..., checkpoint)` is true.
- `tools/server/server-context.cpp:5767` through `:5779` and `:5998` through
  `:6009` contain cold-promotion branches for selected payloads, but a cold
  checkpoint-dependent candidate cannot reach those branches because selection
  and checkpoint-path validation already require hot residency.
- `tests/test-cache-controller.cpp:1796` through `:1815` proves a checkpoint can
  be demoted to cold, but it does not attempt a checkpoint-dependent restore
  from that cold descriptor or assert that promotion is requested.

Impact:

Stage 9 can demote checkpoint descriptors, but checkpoint-dependent restore
treats those demoted checkpoints as unavailable instead of promoting them.
That breaks the checkpoint cold-store contract and makes the documented
cold-restore behavior unreachable for checkpoint-dependent workloads.

Required correction:

Separate "checkpoint path exists and metadata is valid" from "payload is hot and
ready to apply." Candidate selection and checkpoint-path validation must accept
valid cold checkpoint descriptors, then the restore path must request promotion
before live mutation. Add a focused test that demotes a checkpoint, runs
checkpoint-dependent restore selection or load planning, and proves promotion or
the documented async miss is recorded.

## New advisory findings

### S9-IMPL-07: restore metric evidence covers shape storage but not restore export behavior

Severity: ADVISORY

The corrected metric code records checkpoint restore rows with the required
dimensions, but the added focused metric test only checks
`cache_checkpoint_hits_by_shape`. Before QA closure, add evidence that
`cache_checkpoint_restores_by_shape` and the Prometheus restore metric include
real `profile`, `payload_residency`, `pair_state`, and `result` values and do
not expose namespace, prompt, path, or payload material.

## Verification run

- `cmake --build build --config Release --target test-cache-controller`: PASS
- `.\build\bin\Release\test-cache-controller.exe`: PASS, 59 tests

The passing focused target does not cover S9-IMPL-06.

## Required corrections

- Fix S9-IMPL-06 before QA planning.
- Add cold-checkpoint restore or restore-planning coverage that proves cold
  checkpoint promotion is reachable.
- Extend metric evidence for checkpoint restore rows and Prometheus export.
- Keep Part 7's model-backed HTTP limitation visible in the next evidence pass
  unless a suitable checkpoint-dependent fixture is run.

## Next action

Next owner: Developer.

Handoff state: REWORK. Developer should correct the cold checkpoint restore
path and add focused evidence, then request Architect implementation
re-review. QA should not start Stage 9 planning from this implementation
snapshot.
