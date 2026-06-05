# Phase 5 implementation: draft-context compatibility review

Source: [../cache-handling-phase5-implementation.md](../cache-handling-phase5-implementation.md)

## Review scope

Review date: May 28, 2026

This review covers the compatibility-key update for Stage 5 draft-context modes. It checks conformance with [Architecture Part 6](../cache-handling-architecture/part-06-stage-5-draft-context-modes-and-pairing.md), the updated H57/N25/N26 test-plan rows, and the Developer evidence in [Part 6](part-06-implementation-evidence.md#step-510-draft-context-compatibility-key-correction).

Reviewed files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tests/test-cache-controller.cpp`
- `._design_docs/cache-handling-phase5-implementation/part-06-implementation-evidence.md`
- `._design_docs/cache-handling-test-plan/part-03-integration-test-matrix.md`
- `._design_docs/cache-handling-test-plan/part-04-edge-and-negative-scenarios.md`

## Verdict

PASS.

The update matches the Part 6 contract. Pair state remains binary: `ctx_dft == nullptr` maps to target-only behavior, and an active draft context maps to target-plus-draft behavior. The change adds draft runtime identity to the compatibility namespace; it does not change speculative decoding startup, draft context creation, save or restore semantics, legacy cache behavior, HTTP endpoints, or metrics names.

## Decisions

The compatibility key now serializes `draft.mode` before hashing the namespace. The four accepted mode strings are distinct:

- `none`
- `separate-draft-model`
- `mtp-target-model`
- `mtp-separate-model`

That is enough to prevent the Stage 5 collision class from Part 6: normal separate draft model entries no longer share a namespace with target-derived MTP or separate-model MTP entries only because all three have draft bytes.

Draft identity handling is also scoped correctly for this stage. Target-derived MTP uses the configured target model source as draft-side identity. Separate draft modes use `params.speculative.draft.mparams`, so `--model-draft` and `--spec-draft-model` converge on the same key because both flags populate the same field. When a real draft context exists, runtime draft model dimensions are included as extra identity data. That is not broader than the architecture requires, and it avoids relying only on dimensions when a configured draft source is available.

The focused controller test `test_namespace_isolation_draft_context_modes()` maps to H57, N25, and N26 without pretending to be live model evidence. It builds four controlled `common_params` shapes, forces the runtime draft-presence input used by the key builder, checks the expected mode labels, checks non-`none` draft identities for all active draft modes, and asserts pairwise namespace separation. This is realistic for compatibility-key construction because the cache controller observes the initialized runtime shape instead of deciding whether MTP should start.

The implementation evidence does not overclaim. It says the regression covers H57/N25/N26 namespace isolation without loading GGUF files. It does not claim public HTTP restore coverage for H53, H54, or H56.

## Required corrections

None.

## Handoff

State: Stage 5 remains closed for this compatibility-key correction.

Next owner: QA may use the focused H57/N25/N26 evidence for namespace-isolation coverage. Public model-backed MTP save/restore evidence remains fixture-dependent under H53 and H54.
