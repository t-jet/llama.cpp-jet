# Software Architecture: Alternate Hybrid Cache Mode for llama-server - Part 7: Speculative decode-batch cap invariant

Source: [../cache-handling-architecture.md](../cache-handling-architecture.md)

## Scope

This part records a single invariant the speculative decode-batch
builder must respect, and the rule that implements it. The invariant
was missing from the Stage 11 design and surfaced as a server crash on
`cache-optimization-caveman` HEAD `02db7a768`. The investigation is in
[../cache-handling-phase11-implementation/part-19-stage11-mtp-crash-investigation.md](../cache-handling-phase11-implementation/part-19-stage11-mtp-crash-investigation.md).
The Stage 11 follow-up design is in
[../cache-handling-phase11-design/part-08-n-outputs-max-cap-followup.md](../cache-handling-phase11-design/part-08-n-outputs-max-cap-followup.md).

This part is durable. It applies to every stage that touches the
speculative decode-batch builder, not just Stage 11. The Stage 5 draft
context modes (Part 6), the Stage 9 checkpoint integration (test plan
Part 11), and any future rework of the speculative path inherit the
invariant from this part.

## The invariant

The speculative decode-batch builder must keep every `llama_decode`
call's `n_tokens` at or below the per-context `cparams.n_outputs_max`
cap. The cap is set at context init from
`server_n_outputs_max(common_params)` at
`tools/server/server-context.cpp:204` and from
`params_dft.n_outputs_max` / `cparams_mtp.n_outputs_max` for the draft
and MTP draft contexts. The cap is a hard invariant. The
`GGML_ASSERT(n_outputs_max <= cparams.n_outputs_max)` at
`src/llama-context.cpp:2152` enforces it.

The invariant covers the target context and the draft MTP context.
The non-MTP separate draft path is covered indirectly because the
target's `server_n_outputs_max` formula accounts for the non-MTP
speculative `n_max`.

## The rule per context

- **Target context: chunked-decode.** The speculative chunked loop at
  `tools/server/server-context.cpp:3750` must bound the per-chunk
  `n_tokens` on `min(n_batch, cparams.n_outputs_max / n_parallel)`
  or an equivalent per-sequence cap. The cap is per-context, the chunk
  is per-call, and parallel slots share the per-context cap.
- **Draft MTP context: cap-bump.** The draft MTP context's per-call
  `llama_decode` is bounded by `1 + n_max` tokens. Chunking it would
  serialize the draft generation step. The fix is to set
  `cparams_mtp.n_outputs_max = n_parallel * (1 + common_speculative_n_max(&params_base.speculative))`
  at `tools/server/server-context.cpp:1308`, with the matching
  `params_dft.n_outputs_max` at `tools/server/server-context.cpp:1175`
  for the MTP branch only.
- **Non-MTP separate draft model: unchanged.** The non-MTP draft
  context's cap stays at `n_parallel`. The target's cap already
  accounts for the non-MTP speculative `n_max`.

The full justification, the alternatives considered, the affected
call sites, the test plan rows, the risks, the observability rules,
and the out-of-scope items are in
[../cache-handling-phase11-design/part-08-n-outputs-max-cap-followup.md](../cache-handling-phase11-design/part-08-n-outputs-max-cap-followup.md).
This part records the invariant; the Stage 11 follow-up records the
design that implements it.

## Why this is an architecture-level invariant

The cap is a property of the llama context, not of the hybrid cache
controller. The cache controller does not build decode batches; the
speculative `update_slots` path does. The crash site is in
`src/llama-context.cpp:2152`, which is upstream of the hybrid cache
controller entirely.

The hybrid cache controller inherits the invariant by transitivity: a
speculative decode that fails the assertion is a request that never
reaches the cache controller. The fix must live at the layer that
builds the speculative batch, not in the cache layer.

The Stage 5 pair-state rule (Part 6) is the closest analogue. Pair
state is also a property of the speculative runtime that the cache
controller must observe, and the architectural record of pair state
sits in Part 6. The cap invariant sits here in Part 7 for the same
reason.

## How the invariant affects other stages

| Stage | Effect |
| --- | --- |
| Stage 1-3 (hybrid cache controller, non-destructive exact saves/loads, usage tracking) | No direct effect. The cache controller is downstream of the cap check. |
| Stage 4 (byte-accounted LRU with protected roots) | No direct effect. Eviction does not touch the cap. |
| Stage 5 (payload descriptor separation, target/draft pairing) | The cap-bump for the draft MTP context does not change the pair-state rule. The pair-state rule stays binary; the cap is independent. |
| Stage 6 (cold payload storage, async I/O) | No direct effect. Cold I/O does not touch the cap. |
| Stage 7-8 (branch forest, metadata-only nodes, re-materialization) | No direct effect. The branch layer is downstream of the cap. |
| Stage 9 (checkpoint integration, workload profiles) | The cap-bump must not change the checkpoint lifecycle. The four `cache_checkpoint_*` rows remain exposed. |
| Stage 10 (observability, security, hardening) | The new `SRV_DBG` line at the chunked loop is bounded and follows the Stage 10 diagnostic shape. |
| Stage 11 (upstream merge) | The invariant is recorded as a follow-up correction. The Stage 11 merge log records the new part as a follow-up. |

## Handoff

This part is durable. The Stage 11 follow-up design part is the
implementation contract. The Manager accepts the architecture-level
invariant; the Architect reviews the implementation contract; the
Developer implements the contract; QA verifies the test plan rows.
