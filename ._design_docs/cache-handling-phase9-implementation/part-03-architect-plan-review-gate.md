# Stage 9 implementation plan review gate

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)
Date: 2026-06-01
Reviewer: Architect (independent)
Gate: Implementation plan review
Verdict: PASS

## Scope and gate status

This review covers the Stage 9 implementation plan only. It does not approve
code changes, test execution, or implementation evidence.

Implementation remains closed until Manager approves the implementation-plan
gate.

## Documents reviewed

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase9-design.md`
- `._design_docs/cache-handling-phase9-design/part-01-scope-and-workload-profiles.md`
- `._design_docs/cache-handling-phase9-design/part-02-checkpoint-payload-lifecycle-and-interfaces.md`
- `._design_docs/cache-handling-phase9-design/part-03-restore-strategy-and-prepared-prompt-boundaries.md`
- `._design_docs/cache-handling-phase9-design/part-04-pairing-cold-store-metrics-and-diagnostics.md`
- `._design_docs/cache-handling-phase9-design/part-05-testability-traceability-exclusions-and-risks.md`
- `._design_docs/cache-handling-phase9-design/design-review-gate-01.md`
- `._design_docs/cache-handling-phase9-design/part-06-manager-design-gate.md`
- `._design_docs/cache-handling-phase9-implementation.md`
- `._design_docs/cache-handling-phase9-implementation/part-01-implementation-plan.md`
- `._design_docs/cache-handling-phase9-implementation/part-02-evidence-plan-and-risks.md`

## Code anchors checked

The review checked code only to confirm that the implementation plan points at
real files, types, helpers, and test anchors.

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-graph.h`
- `tools/server/server-cache-graph.cpp`
- `tools/server/server-cache-store-cold.h`
- `tools/server/server-cache-store-cold.cpp`
- `tools/server/server-cache-io-worker.h`
- `tools/server/server-cache-io-worker.cpp`
- `tools/server/server-context.cpp`
- `tools/server/server-task.h`
- `include/llama.h`
- `src/llama-hparams.h`
- `tests/test-cache-controller.cpp`
- `tests/test-step12-branch-graph.cpp`
- `tests/test-step13-stage8.cpp`
- `tests/test-step6-demotion-protocol.cpp`
- `tests/test-step7-promotion-protocol.cpp`
- `tests/test-step11-test-hooks-fault-injection.cpp`
- `tests/test-step10-metrics.cpp`
- `tests/test-step8-integration-wiring.cpp`

Confirmed anchors include `payload_kind::checkpoint`, `payload_descriptor`,
`branch_node::exact_blob_payload_id`, `branch_node::checkpoint_payload_id`,
`prepared_prompt_metadata`, `prompt_boundary`, `cache_compatibility_key`,
`namespace_key::workload_profile`, public model helpers for SWA, recurrent, and
hybrid detection, MTP context type, and existing speculative-mode namespace
fields.

## Findings

### Blocking findings

None.

### Advisory findings

No new advisory finding is required for implementation planning.

Carry-forward advisories from the Stage 9 design review are addressed well
enough for Developer execution:

- 9-01: Part 1 names concrete runtime sources for SWA, recurrent, hybrid,
  context-mode, draft, and MTP detection. It also requires negative tests for
  null target context, contradictory draft shape, unknown context type, future
  speculative mode, and missing checkpoint metadata.
- 9-02: Part 1 defines checkpoint admission as pre-attach validation, hot-store
  write, descriptor insert, graph attach, entry/index sync, rollback, and
  cleanup. Replacement keeps the old checkpoint attached until the new one is
  fully visible.
- 9-03: Part 2 requires a fixture search for SWA, recurrent, hybrid, Qwen3.5,
  or target/draft MTP evidence. It also defines the focused substitute path and
  requires the QA handoff to state when no model-backed fixture exists.

## Decisions

- PASS: The accepted design baseline is explicit and binds the plan to Stage 9
  design Parts 01 through 05 plus the Manager design gate.
- PASS: The ordered implementation steps cover profile detection, namespace
  serialization, checkpoint admission, restore ranking, Stage 8
  re-materialization, cold residency, target/draft atomicity, metrics,
  diagnostics, tests, and documentation.
- PASS: The affected code areas are plausible for the planned behavior. No
  plan step depends on an obviously missing file, type, or helper.
- PASS: Tests, metrics, diagnostics, build evidence, model-backed evidence, and
  substitute evidence are explicit.
- PASS: Risks and blockers are visible. The plan defaults unsafe or unknown
  runtime shapes to fallback behavior instead of inventing a public profile
  selector.
- PASS: The plan keeps implementation closed until independent plan review and
  Manager approval both pass.

## Required next action

Manager should review this PASS result and decide the Stage 9
implementation-plan gate.

Next owner: Manager.

Handoff state: ready for Manager implementation-plan gate. Implementation is
still closed.
