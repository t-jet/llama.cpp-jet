# Stage 9 cold checkpoint restore corrections - 2026-06-01

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
Trigger: [part 8 Architect implementation re-review](part-08-architect-implementation-re-review-20260601.md)
Owner: Developer
Status: corrections implemented; ready for Architect re-review

## Scope

This pass fixes S9-IMPL-06 and adds focused evidence for S9-IMPL-07. No commit
was created.

## Changed files

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tests/test-cache-controller.cpp`
- `._design_docs/cache-handling-phase9-implementation.md`
- `._design_docs/cache-handling-phase9-implementation/part-09-cold-checkpoint-restore-corrections-20260601.md`
- `._design_docs/document-index.md`

## Corrections made

S9-IMPL-06:

- Added `entry_has_payload_descriptor_for_restore()` so restore planning can
  validate descriptor ownership, kind, store reference, target size, and
  non-evicted residency without requiring hot bytes.
- Changed checkpoint-dependent candidate selection and checkpoint path
  validation to accept valid cold, demoting, or promoting checkpoint
  descriptors.
- Kept hot-byte requirements in the restore/apply path. A selected cold
  checkpoint still returns the documented async miss after queuing promotion,
  before any live slot mutation.
- Added a focused test hook that selects a cold checkpoint-dependent candidate
  and requests promotion through the same controller promotion machinery.

S9-IMPL-07:

- Extended focused evidence for `cache_checkpoint_restores_by_shape`.
- The cold-checkpoint test now records a restore row with real enum labels:
  `profile=checkpoint_dependent`, `payload_residency=cold`,
  `pair_state=target_only`, and `result=failure`.
- The test checks that the serialized metric evidence does not contain the test
  namespace or token material.
- The Prometheus exporter already emits checkpoint restore rows from
  `cache_checkpoint_restores_by_shape`; the focused metrics target was rerun to
  keep the export-path evidence current.

## Evidence run

- `cmake --build build --config Release --target test-cache-controller`: PASS
- `.\build\bin\Release\test-cache-controller.exe`: PASS, 59 tests
- `cmake --build build --config Release --target test-step10-metrics`: PASS
- `.\build\bin\Release\test-step10-metrics.exe`: PASS
- `ctest --test-dir build -C Release -R "test-cache-controller|test-step10-metrics" --output-on-failure`: PASS, 2/2 tests
- `git diff --check -- tools/server/server-cache-hybrid.cpp tools/server/server-cache-hybrid.h tests/test-cache-controller.cpp`: PASS

## Failures and skips

- Model-backed checkpoint-dependent HTTP evidence was not run. The local pass
  remains focused controller evidence plus the existing metrics-export target.
- Full `git diff --check` was not used as the decisive check because the
  worktree already has unrelated dirty agent files with known whitespace
  issues. The scoped check above covers the files changed by this correction.

## Remaining limitations

- The focused test proves cold checkpoint selection, async promotion reachability,
  and restore metric row shape. It does not replace a model-backed HTTP run.
- Public Prometheus evidence still depends on the existing `/metrics` exporter
  path consuming the controller row data. A model-backed checkpoint fixture
  should be used before QA closure if one becomes available.

## Handoff

Next owner: Architect for implementation re-review.

Handoff state: Stage 9 corrections are ready for re-review. QA should still wait
for Architect acceptance before planning execution.
