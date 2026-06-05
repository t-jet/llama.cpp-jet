# Software Architecture: Alternate Hybrid Cache Mode for llama-server - Part 6: Stage 5 draft context modes and pairing

Source: [../cache-handling-architecture.md](../cache-handling-architecture.md)

## Scope

This part defines how Stage 5 descriptor pairing interacts with speculative decoding runtimes. It does not change legacy prompt-cache behavior. It applies only when the hybrid cache controller saves, restores, validates, accounts, or evicts descriptor-owned exact blob payloads.

The researched code paths are:

- `common/arg.cpp`: `--model-draft` is an alias of `--spec-draft-model`; `--spec-type draft-mtp` may also discover an MTP sidecar for HF models.
- `tools/server/server-context.cpp`: the server creates `ctx_dft` from a separate draft model when one is configured, or creates an MTP context from the target model when `draft-mtp` is configured without a separate draft model.
- `common/speculative.cpp`: `draft-simple` needs an explicit draft model path; a draft model path without an explicit draft type enables `draft-simple`; `draft-mtp` uses `ctx_dft` when present.
- `tools/server/server-cache-hybrid.*`: Stage 5 save and restore currently decide descriptor pair state from runtime draft-context presence.

## Mode classification

Stage 5 must treat these runtime modes as distinct for compatibility:

| Runtime mode | Current runtime shape | Stage 5 descriptor pair state |
| --- | --- | --- |
| No draft context | `ctx_dft == nullptr` after speculative initialization | `target_only` |
| Separate draft model | `--model-draft` or `--spec-draft-model` loads a separate model context | `target_and_draft` |
| MTP draft context from target | `--spec-type draft-mtp` without a separate draft model creates an MTP context against the target model | `target_and_draft` |
| MTP draft context from separate model | `--spec-type draft-mtp` with `--model-draft` loads the draft model with `LLAMA_CONTEXT_TYPE_MTP` | `target_and_draft` |

The descriptor pair state is intentionally binary. It answers only whether the serialized cache object has a draft side. It must not be stretched to encode which speculative algorithm produced that draft context.

Compatibility must carry the richer mode identity. A `target_and_draft` descriptor saved from a normal separate draft model is not compatible with an MTP context only because both have draft bytes. The namespace or compatibility key must distinguish at least:

- no draft context
- separate draft model context
- MTP context on the target model
- MTP context on a separate draft model
- draft model identity when a separate model is used
- target model identity when MTP uses the target model
- context type or equivalent runtime discriminator for MTP versus non-MTP draft contexts

If the active implementation only keys on `ctx_dft` presence and model dimensions, that is not enough for the combined draft-model/MTP case. The required correction is compatibility-key expansion, not a change to descriptor pair-state semantics.

## Save and restore rules

For no draft context:

- Save serializes only target state.
- Admission requires `target_only`.
- Restore accepts only `target_only`.
- A `target_and_draft` descriptor is a pairing violation and must fall back without hit accounting or recency refresh.

For a separate draft model via `--model-draft` or `--spec-draft-model`:

- Save serializes target and draft state as one descriptor-owned payload.
- Admission requires `target_and_draft`.
- Restore validates the same draft-model compatibility namespace before live mutation.
- Restore applies target and draft state transactionally. Failure on either side is a whole-restore failure.
- Eviction and byte accounting use `target_state_bytes + draft_state_bytes`.

For `--spec-type draft-mtp` without a separate draft model:

- The runtime still has a draft context, so Stage 5 uses `target_and_draft`.
- The compatibility mode must record that the draft side is an MTP context derived from the target model.
- Restore must not reuse a target-only entry, a normal separate-draft entry, or an MTP entry from a different target/runtime shape.

For `--spec-type draft-mtp` with `--model-draft`:

- The runtime has a separate draft model loaded as an MTP context.
- Stage 5 uses `target_and_draft`.
- Compatibility must include both the separate draft model identity and the MTP context discriminator.
- QA should treat this as separate from normal `--model-draft` coverage.

## Combined and unsupported combinations

The cache controller must not make speculative-decoding policy decisions. It should observe the initialized runtime shape and enforce descriptor compatibility for that shape.

`--model-draft` without an explicit draft spec type is an existing speculative behavior: the server enables draft-model speculation. Hybrid cache must preserve that behavior and save `target_and_draft` entries when `ctx_dft` remains active.

`--spec-type draft-mtp` without `--model-draft` is a valid MTP draft-context mode when context creation succeeds. Hybrid cache must preserve it and save `target_and_draft` entries.

`--spec-type draft-mtp` with `--model-draft` is allowed by the current startup path. Hybrid cache must not reject it solely because both options are present. It must isolate it from normal separate-draft and target-derived MTP namespaces.

If multiple speculative implementations are enabled in one run, the cache contract is still based on the single initialized draft context used by the slot. Draftless n-gram speculators do not add a draft payload. If a draft context exists for any model-backed speculative implementation, Stage 5 requires `target_and_draft`; if no draft context exists, it requires `target_only`.

## Template and model-suite note

Jinja or chat-template changes are orthogonal to this Stage 5 pairing decision. Template identity remains part of the cache namespace through the existing prompt-preparation compatibility rules. Draft-pair tests may use `/completion` prompts or an existing Qwen chat template without adding cache-specific template markers.

The local `._test_models/Qwen3-8B-GGUF` and `._test_models/Qwen3-0.6B-GGUF` directories currently provide GGUF files only. They are suitable candidates for the residual public `--model-draft` coverage after QA wires the target path to Qwen3-8B and the draft path to Qwen3-0.6B. If chat-boundary tests are added later, use the established fork-only template-marker contract from the architecture docs and keep byte-for-byte unmarked rendering checks.

## QA handoff

QA should split Stage 5 draft coverage by mode:

- target-only hybrid restore, with no draft context
- normal separate draft model restore, using Qwen3-8B target plus Qwen3-0.6B draft when local resources allow it
- MTP restore without a separate draft model, using an MTP-capable model fixture
- MTP restore with a separate draft model, only if the model pair is known to support that runtime
- negative compatibility checks that prevent reuse between all of the above modes

Public HTTP evidence is enough for successful model-backed save and restore. Pair mismatch, corrupted descriptor, failed target apply, failed draft apply, rollback failure, and unsupported clear preflight still require focused controller or fault-injection evidence.
