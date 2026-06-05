# Stage 9 implementation evidence - 2026-06-01

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)

## Status

Implementation pass: first focused code pass.
Gate state: ready for implementation review after owner accepts the model-backed
evidence limitation below.

## Changed files

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`
- `._design_docs/cache-handling-phase9-implementation.md`
- `._design_docs/cache-handling-phase9-implementation/part-05-implementation-evidence-20260601.md`
- `._design_docs/document-index.md`

## Behavior implemented

- Added `cache_workload_profile` with `plain_transformer`,
  `checkpoint_dependent`, and `unsupported`.
- Added workload profile material to the compatibility key. Null or unclassified
  target context resolves to `unsupported`; SWA, recurrent, and hybrid model
  facts resolve to `checkpoint_dependent`; other initialized targets resolve to
  `plain_transformer`.
- Added checkpoint payload IDs to cache entries and branch nodes as descriptor
  references separate from exact blob payload IDs.
- Allowed `payload_descriptor` validation for `payload_kind::checkpoint` with
  the same pair, version, checksum, residency, owner, and hot record checks used
  by exact blobs.
- Added checkpoint admission helpers that write hot bytes and descriptor state
  before graph attachment, keep the old checkpoint visible until replacement
  succeeds, and roll back injected post-descriptor failure without leaving a
  graph reference.
- Extended restore candidate ranking so plain transformer mode prefers exact
  blobs and checkpoint-dependent mode prefers checkpoint payloads when both are
  valid.
- Reused Stage 6 cold demotion and promotion paths for checkpoint descriptors.
- Added JSON stats and Prometheus export counters for checkpoint admissions,
  checkpoint hits, checkpoint restores, checkpoint failures, and workload
  profile classifications.
- Preserved legacy cache behavior. Changes are under the hybrid controller and
  shared metrics export uses default zero values when a legacy controller omits
  Stage 9 fields.

## Focused tests added

`tests/test-cache-controller.cpp` now covers:

- workload profile namespace separation and unsupported-profile fallback
- checkpoint admission rollback after descriptor creation
- exact-first ranking for `plain_transformer`
- checkpoint-first ranking for `checkpoint_dependent`
- checkpoint descriptor demotion through the cold-store path

## Evidence run

- `cmake --build build --config Release --target test-cache-controller`: PASS
- `.\build\bin\Release\test-cache-controller.exe`: PASS, 57 tests
- `cmake --build build --config Release --target test-step12-branch-graph`: PASS
- `ctest --test-dir build -C Release -R "test-cache-controller|test-step12-branch-graph|stage9" --output-on-failure`: PASS, 2/2 tests
- `cmake --build build --config Release --target test-step10-metrics`: PASS
- `.\build\bin\Release\test-step10-metrics.exe`: PASS
- `git diff --check`: PASS

## Model-backed evidence

Local GGUF fixtures exist under `._test_models`, including Qwen3 and Qwen3.5
target/MTP files. This pass did not run a model-backed checkpoint-first HTTP
row. The current evidence uses the approved substitute path: focused controller
ranking, unsupported-profile fallback, branch graph coverage, metrics coverage,
and checkpoint cold-store demotion.

The next QA or developer pass should add a public task-flow row that loads a
checkpoint-dependent fixture and proves checkpoint-first restore end to end.

## Notes

- Boundary propagation is represented by existing prepared metadata tests and
  namespace material. A dedicated public HTTP boundary propagation row remains
  useful for QA.
- No commit was created.
