# Stage 9 implementation plan - Part 1

Source: [../cache-handling-phase9-implementation.md](../cache-handling-phase9-implementation.md)

## Status

Planning date: 2026-06-01
Plan state: drafted for Architect review and Manager implementation-plan gate.
Implementation state: closed.

## Accepted design baseline

Implement Stage 9 against the accepted design in
[cache-handling-phase9-design.md](../cache-handling-phase9-design.md), Parts
01 through 05, plus the Manager design gate in
[part-06-manager-design-gate.md](../cache-handling-phase9-design/part-06-manager-design-gate.md).

Binding decisions:

- Checkpoint payloads are descriptor-owned branch-node payloads.
- `plain_transformer` prefers the deepest valid exact blob.
- `checkpoint_dependent` traverses checkpoint nodes first.
- `target_plus_draft` is an overlay on either profile, not a separate profile.
- The workload profile is part of the namespace.
- Prepared-prompt boundaries guide checkpoint placement when available.
- Target/draft restore applies atomically. Partial restore is a defect.
- Checkpoint payloads share hot, cold, eviction, promotion, and cleanup rules
  with exact blobs.
- Legacy cache behavior must not change when hybrid mode is disabled.

## Existing code anchors

Primary implementation files:

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

Existing types to extend:

- `payload_kind`, already has `exact_blob` and `checkpoint`.
- `payload_descriptor`, currently stores kind, pair state, version, sizes,
  checksums, store reference, residency, and owner.
- `branch_node`, already has `exact_blob_payload_id` and
  `checkpoint_payload_id`.
- `prepared_prompt_metadata` and `prompt_boundary`, used for boundary spans.
- `hybrid_cache_entry`, which still carries exact payload identity and prompt
  checkpoints.
- `cache_compatibility_key` and `namespace_key`, which already include
  `workload_profile`.

Runtime detection sources for 9-01:

- Target context: `llama_get_model(ctx_tgt)`.
- Draft context presence: `ctx_dft != nullptr`.
- Public model helpers: `llama_model_n_swa(model)`,
  `llama_model_is_recurrent(model)`, and `llama_model_is_hybrid(model)`.
- Context params: `llama_context_params::swa_full` and
  `llama_context_params::ctx_type`.
- Draft and MTP identity from `common_params::speculative`, existing
  `draft_context_mode`, and the Stage 5 namespace fields.
- Internal helper source, if server code needs richer per-layer checks:
  `llama_hparams::is_swa_any()`, `llama_hparams::is_recurrent(il)`,
  `llama_hparams::has_kv(il)`, and `LLAMA_CONTEXT_TYPE_MTP`.

If a helper is not exported from `include/llama.h`, add a small server-side
classification helper close to `hybrid_cache_controller`, or add a reviewed
public helper only if no internal route can see the needed fact.

## Advisory resolutions

### 9-01 profile detection

Add an internal `cache_workload_profile` enum with values
`plain_transformer`, `checkpoint_dependent`, and `unsupported`. Keep
`target_plus_draft` as a pair overlay derived from draft context shape.

Detection order:

1. Require initialized `ctx_tgt` and target model. If missing, return
   `unsupported`.
2. If SWA is present through `llama_model_n_swa(model) > 0`, context SWA mode,
   or internal `is_swa_any()`, choose `checkpoint_dependent`.
3. If recurrent or hybrid state is present through
   `llama_model_is_recurrent(model)` or `llama_model_is_hybrid(model)`,
   choose `checkpoint_dependent`.
4. If rollback or RS limits are represented by existing server/runtime params,
   wire those params into the same helper. If no concrete param exists, record
   `unsupported` instead of guessing.
5. Otherwise choose `plain_transformer`.
6. Derive pair overlay from `ctx_dft != nullptr` plus the Stage 5 speculative
   mode identity: no draft, separate draft, target MTP, or separate-model MTP.

Negative tests:

- Null target context or target model returns `unsupported` and falls back.
- Contradictory draft shape, such as `ctx_dft != nullptr` without a usable
  speculative mode key, rejects reuse.
- Unknown context type or future speculative mode rejects reuse.
- Missing checkpoint metadata for an otherwise checkpoint-dependent runtime
  recomputes instead of matching exact-only branches as canonical continuity.

### 9-02 admission transaction

Checkpoint admission must use this boundary:

1. Pre-attach validation: hybrid enabled, namespace resolved, profile resolved,
   target node found, boundary metadata validated or degraded fallback recorded,
   pair state resolved, serialized bytes available, descriptor fields built,
   checksum and size computed, and hot-store capacity checked.
2. Hot-store write: insert target and optional draft bytes under a new
   payload ID, but keep the descriptor unreachable from the graph.
3. Descriptor insert: add the descriptor to `payload_descriptors` with
   residency `hot` and kind `checkpoint`.
4. Graph attach: set `branch_node::checkpoint_payload_id` only after the
   descriptor and hot bytes are both present and validated.
5. Entry sync and indexes: update entry payload accounting, usage, LRU, prefix
   indexes, and metrics after graph attach succeeds.

Rollback order:

1. If validation fails before hot-store write, mutate nothing.
2. If hot-store write succeeds but descriptor insert fails, erase hot bytes.
3. If descriptor insert succeeds but graph attach fails, erase the descriptor,
   then erase hot bytes.
4. If graph attach succeeds but entry sync or metadata-budget admission fails,
   detach the graph field, erase the descriptor, erase hot bytes, restore old
   usage and index keys, and emit an admission failure.
5. If replacing an older checkpoint, keep the old descriptor attached until the
   new descriptor is fully attached. Detach the old descriptor only after the
   new descriptor is visible, then schedule old payload cleanup through the
   normal ownership-checked path.

Cleanup order:

1. Detach graph reference.
2. Remove descriptor from `payload_descriptors`.
3. Remove hot bytes or schedule cold deletion only after ownership checks.
4. Update metrics and diagnostics.

### 9-03 checkpoint evidence

Part 2 defines the evidence route. Implementation must first look for a local
checkpoint-dependent fixture, preferably an SWA, recurrent, hybrid, or
Qwen3.5-style target/MTP model already used by the server tests. If none is
available, the implementation and QA handoff must use focused controller tests
plus one public task-flow test that proves boundary metadata reaches the cache
controller.

## Ordered implementation steps

1. Add workload-profile types, string conversion, namespace serialization, and
   profile stats fields.
2. Implement profile detection and pair-overlay detection in the hybrid
   controller.
3. Extend descriptor and branch-node sync paths so exact and checkpoint
   payload IDs can coexist.
4. Add checkpoint admission using the transaction boundary above.
5. Extend restore planning with exact-first and checkpoint-first strategies.
6. Wire metadata-only checkpoint re-materialization through the Stage 8 plan.
7. Extend cold demotion, promotion, eviction, and cleanup for checkpoint
   descriptors.
8. Keep target/draft pair validation atomic for checkpoint restore and
   admission.
9. Add metrics and diagnostics without prompt text, file paths, or serialized
   state in labels.
10. Add focused unit tests and public task-flow tests.
11. Update test plan, implementation log, and evidence sections before opening
    implementation review.

## Documentation plan

During implementation, add dated evidence parts under this directory. Each
completed step must record changed files, behavior, tests run, and failures or
skips. Update `document-index.md` when new durable parts are added.
