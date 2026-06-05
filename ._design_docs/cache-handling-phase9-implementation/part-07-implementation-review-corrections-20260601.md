# Stage 9 implementation review corrections - 2026-06-01

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
Trigger: [part 6 Architect implementation review](part-06-architect-implementation-review-20260601.md)
Owner: Developer
Status: corrections implemented; ready for Architect re-review

## Scope

This part records the rework for S9-IMPL-01 through S9-IMPL-04 and the added
coverage for S9-IMPL-05. No commit was created.

## Changed files

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-graph.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`
- `._design_docs/cache-handling-phase9-implementation.md`
- `._design_docs/cache-handling-phase9-implementation/part-07-implementation-review-corrections-20260601.md`
- `._design_docs/document-index.md`

## Corrections made

S9-IMPL-01:

- Checkpoint descriptors now store placement metadata: token span, position
  span, boundary kind, boundary ID, boundary checksum, native-boundary flag,
  and whether a prepared boundary was required.
- Production checkpoint admission passes the entry's prepared prompt metadata
  into checkpoint descriptor admission.
- Admission rejects boundary-bearing checkpoints when the descriptor cannot be
  tied to a prepared boundary span. Missing prepared metadata uses a token-span
  checksum fallback and records fallback-compatible descriptor metadata.
- Restore validation rechecks checkpoint descriptor metadata against the entry
  metadata before accepting the descriptor.

S9-IMPL-02:

- `checkpoint_dependent` restore candidate selection now requires a hot
  checkpoint-bearing path.
- Restore and load paths reject checkpoint-dependent candidates before live
  mutation when checkpoint metadata or payload validation fails.
- Exact blobs remain usable for plain transformer restores. They no longer
  stand in for checkpoint continuity in checkpoint-dependent mode.

S9-IMPL-03:

- Hot budget eviction is payload-kind aware and processes exact and checkpoint
  descriptors on the selected branch node.
- Branch graph eviction candidates now include checkpoint-only nodes.
- Demotion and promotion completion refresh entry accounting for both exact and
  checkpoint descriptors.
- Branch metadata remains after payload eviction so Stage 8 metadata-only
  validation can still run.

S9-IMPL-04:

- Checkpoint hit counters are recorded by `profile`, `payload_residency`, and
  `pair_state`.
- Checkpoint restore counters are recorded by `profile`, `payload_residency`,
  `pair_state`, and `result`.
- Prometheus export now emits the recorded label values instead of constant
  `all` buckets.
- Added metric-shape coverage that checks the shape contains enum labels and
  does not include namespace text or token material.

S9-IMPL-05:

- Added focused controller tests for boundary ID/span/checksum, corrupted
  boundary checksum rejection, missing-boundary fallback, exact-only rejection
  for checkpoint-dependent restore, checkpoint budget eviction, and checkpoint
  metric shape.
- Model-backed checkpoint-dependent HTTP evidence remains unavailable in this
  pass. The substitute evidence is the approved focused controller path plus
  branch graph and metrics target coverage.

## Evidence run

- `cmake --build build --config Release --target test-cache-controller`: PASS
- `.\build\bin\Release\test-cache-controller.exe`: PASS, 59 tests
- `cmake --build build --config Release --target test-step12-branch-graph`: PASS
- `cmake --build build --config Release --target test-step10-metrics`: PASS
- `.\build\bin\Release\test-step10-metrics.exe`: PASS
- `ctest --test-dir build -C Release -R "test-cache-controller|test-step12-branch-graph|stage9" --output-on-failure`: PASS, 2/2 tests
- `git diff --check -- <Stage 9 correction files>`: PASS

## Check failures and skips

- `git diff --check`: FAIL due to pre-existing trailing whitespace in
  `.codex/agents/*.toml` and `.github/agents/*.agent.md`, outside this Stage 9
  correction scope. Those files were already dirty and were not edited here.
- Model-backed checkpoint-dependent HTTP evidence: not run. Local fixture use
  for an end-to-end checkpoint-first HTTP row remains a QA or follow-up
  developer task.

## Remaining limitations

- The focused tests prove controller admission, restore selection, budget
  eviction, and metric shape. They do not replace a model-backed HTTP run.
- Public task-flow boundary propagation is represented by production save
  wiring and focused metadata tests. A model-backed HTTP row should still be
  added before QA closure if a suitable fixture is available.

## Handoff

Next owner: Architect for implementation re-review.

Handoff state: Stage 9 implementation corrections are ready for re-review.
