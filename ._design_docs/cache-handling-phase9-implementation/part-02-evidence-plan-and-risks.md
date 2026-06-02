# Stage 9 implementation plan - Part 2: evidence plan and risks

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)

## Status

Planning date: 2026-06-01
Plan state: drafted.

## Focused test plan

Add or extend focused tests in the existing cache test style:

- `tests/test-cache-controller.cpp` for profile detection, namespace matching,
  descriptor validation, admission rollback, exact-first ranking, and
  checkpoint-first ranking.
- `tests/test-step12-branch-graph.cpp` for branch node payload identity and
  checkpoint metadata traversal.
- `tests/test-step13-stage8.cpp` or a new Stage 9 focused test for
  metadata-only checkpoint re-materialization and mismatch handling.
- `tests/test-step6-demotion-protocol.cpp`,
  `tests/test-step7-promotion-protocol.cpp`, and
  `tests/test-step11-test-hooks-fault-injection.cpp` for checkpoint cold
  demotion, promotion, and target/draft failure paths.
- `tests/test-step10-metrics.cpp` for Prometheus and JSON metric shape.
- `tests/test-step8-integration-wiring.cpp` or a new Stage 9 integration test
  for public task-flow boundary metadata reaching the cache controller.

Required focused cases:

- `plain_transformer` chooses exact blob over checkpoint when both are valid.
- `checkpoint_dependent` chooses the deepest valid checkpoint.
- Exact blob can act as accelerator or root for a checkpoint-dependent path.
- Checkpoint namespace mismatch is rejected without hit counter refresh.
- Unknown runtime profile falls back and emits unsupported-profile diagnostics.
- Missing or degraded prepared-prompt metadata falls back to token or position
  placement and records the degraded reason.
- Boundary checksum mismatch rejects the checkpoint.
- Checkpoint admission rollback leaves no graph descriptor reference when hot
  bytes, descriptor insert, graph attach, or entry sync fails.
- Replacement keeps the old checkpoint visible until the new one is committed.
- Target/draft checkpoint mismatch rejects restore before live mutation.
- Checkpoint cold promotion validates version, checksum, pair state, target
  bytes, and draft bytes before live mutation.
- Metrics use enum labels only.

## Integration and model-backed evidence

Implementation must first check whether the local test environment has a
checkpoint-dependent model fixture:

- SWA model: any local Gemma, Llama 4, Exaone, OLMo, Phi, or similar fixture
  whose runtime reports SWA.
- Recurrent or hybrid model: any local Mamba, RWKV, Jamba, Granite hybrid,
  Qwen3Next, Qwen3.5, or similar fixture whose runtime reports recurrent or
  hybrid state.
- Draft or MTP fixture: the local Qwen3 target/draft pair used by Stage 8, if
  it can exercise checkpoint save and restore.

If a suitable fixture exists, run at least one model-backed public HTTP or
equivalent task-flow row that proves checkpoint-first restore for a
checkpoint-dependent profile.

If no suitable fixture exists, record the absence in the implementation log and
use substitute evidence:

- focused controller test proving checkpoint-first ranking and restore plan
  selection for a synthetic checkpoint-dependent profile
- focused controller test proving profile detection fallback for unknown mode
- task-flow test proving prepared boundary metadata reaches checkpoint
  admission logic
- cold-store round trip for a checkpoint descriptor through the production
  store and I/O worker

The substitute path is acceptable only for planning and local QA when the model
fixture is unavailable. It must be explicit in the QA handoff.

## Build and test evidence

Expected developer evidence after implementation:

- `cmake --build build --config Release --target test-cache-controller`
- `cmake --build build --config Release --target test-step12-branch-graph`
- Stage 9 focused test target, if a new target is added.
- `ctest --test-dir build -C Release -R "test-cache-controller|test-step12-branch-graph|stage9" --output-on-failure`
- Focused server Python or HTTP tests for boundary propagation and model-backed
  checkpoint-first restore when a fixture exists.
- `git diff --check` over changed code, tests, and Stage 9 docs.

Do not claim model-backed checkpoint coverage unless the command output proves
it used a checkpoint-dependent fixture.

## Metrics and diagnostics evidence

Verify these metrics:

- `cache_checkpoint_restores_total{profile,payload_residency,pair_state,result}`
- `cache_checkpoint_hits_total{profile,payload_residency,pair_state}`
- checkpoint paths reflected in promotion, demotion, eviction, restore failure,
  fallback, validation mismatch, and re-materialization counters

Verify diagnostics for:

- profile selected
- unsupported profile or unknown runtime shape
- checkpoint admission accepted or rejected
- degraded or invalid boundary metadata
- checkpoint candidate rejected by namespace, pair state, version, checksum, or
  boundary validation
- fallback reason after restore failure

Labels and diagnostic fields must not include prompt text, marker strings, file
paths, serialized bytes, or raw boundary metadata values.

## Risks and handling

| Risk | Handling |
| --- | --- |
| Profile detection misses a constrained runtime. | Default unknown shapes to unsupported fallback unless checkpoint metadata is fully usable. Add negative tests. |
| Checkpoint admission exposes an unrestorable descriptor. | Use the transaction and rollback order in Part 1. Add failure injection tests for each boundary. |
| Exact-blob performance regresses for plain transformers. | Keep exact-first ranking and add exact-versus-checkpoint tests for `plain_transformer`. |
| Target/draft checkpoint restore partially applies. | Promote and validate both sides before live mutation. Reuse Stage 5 transaction tests and add checkpoint variants. |
| Boundary metadata is too weak for `/completion`. | Emit degraded diagnostics and use token or position fallback. Do not rescan raw prompt text to infer trusted boundaries. |
| No model-backed checkpoint-dependent fixture exists locally. | Record the fixture gap and use the focused substitute evidence path above. |

## Handoff state

Implementation planning is ready for independent review. No production code or
test code has been changed in this planning pass.
