# Stage 11 follow-up: speculative decode-batch sizing under the upstream `n_outputs_max` cap

Source: [../cache-handling-phase11-design.md](../cache-handling-phase11-design.md)

## Goal

Stage 11 closed on commit `6e3aa045c` with the upstream `n_outputs_max` cap
in place. A subsequent MTP draft-context crash on
`cache-optimization-caveman` HEAD `02db7a768` exposed a sizing gap the
original Stage 11 design did not cover. The crash site is
`src/llama-context.cpp:2152` (`GGML_ASSERT(n_outputs_max <= cparams.n_outputs_max) failed`),
and the trigger is the speculative `update_slots` path in
`tools/server/server-context.cpp:3714` building a 13-token decode batch
against a target context whose `cparams.n_outputs_max` is 4.

This part records the design correction. It does not reopen the Stage 11
design gate, which closed on the rework evidence in
[cache-handling-phase11-implementation.md](../cache-handling-phase11-implementation.md).
It adds a new part that owns the speculative decode-batch sizing invariant
the Stage 11 design was missing, and links to a new architecture part that
records the invariant at the level where it actually lives.

## Trigger evidence

The evidence is in
[cache-handling-phase11-implementation/part-19-stage11-mtp-crash-investigation.md](../cache-handling-phase11-implementation/part-19-stage11-mtp-crash-investigation.md).
The investigation is closed and trusted.

Summary of the relevant facts from the investigation:

- Crash: `output_reserve(13)` against `cparams.n_outputs_max = 4` in the target context.
- The 13-token batch is the residual after the MTP verify prefix of
  `1 + n_max = 4` is pre-removed from a 17-token prompt.
- Upstream `server_n_outputs_max` at `server-context.cpp:204` returns
  `min(n_batch, n_parallel * (1 + common_speculative_n_max(&params.speculative)))`
  for the target context, which evaluates to `4` for
  `n_parallel = 1`, `n_max = 3`.
- The target context is initialized with that cap at
  `server-context.cpp:1109` (`params_base.n_outputs_max = server_n_outputs_max(params_base)`).
- The 13-token batch comes from the speculative `update_slots` path at
  `server-context.cpp:3714` (`SRV_DBG("decoding batch, n_tokens = %d\n", batch.n_tokens);`).
- The existing chunked-decode loop at `server-context.cpp:3750` chunks
  on `n_batch`, not on `cparams.n_outputs_max`. With `n_batch > 4` the
  first chunk still calls `llama_decode(ctx_tgt, batch_view)` with
  `n_tokens = 13`, which trips the assertion.
- The draft MTP context cap is also too tight:
  `params_dft.n_outputs_max = params_base.n_parallel` at
  `server-context.cpp:1175` and
  `cparams_mtp.n_outputs_max = params_base.n_parallel` at
  `server-context.cpp:1308`. For `n_parallel = 1` the MTP draft cap is
  1, while the MTP draft's per-call `llama_decode` is bounded by
  `1 + n_max = 4` (OQ2 in the investigation).
- The user hypothesis (fix_mtp_server_instability commits were lost in
  the upstream merge) is false. The A-N checklist in the investigation
  confirms the 13 substantive fix_mtp commits are present in current HEAD.

## The invariant

The speculative decode-batch builder must keep every `llama_decode` call's
`n_tokens` at or below the per-context `cparams.n_outputs_max` cap. The
cap is set at context init and does not change at request time. The
invariant applies to both the target context and the draft MTP context,
but the rule is different for each.

The invariant is durable. It belongs in the architecture, not in any
single stage design. The architecture-level part that records the
invariant is
[../cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md](../cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md).
This part is the Stage 11 follow-up that names the call sites and the
test plan rows that close the gap.

## The rule

**Target context: chunked-decode.** The existing chunked-decode loop at
`tools/server/server-context.cpp:3750` already splits the speculative
batch into multiple `llama_decode` calls. The fix is to bound the chunk
size on `min(n_batch, cparams.n_outputs_max)` for the speculative path,
or to use a per-sequence cap that respects `cparams.n_outputs_max /
n_parallel`. Chunking the residual does not break the MTP verify
semantics because the verify positions are pre-removed from the batch
before the chunked loop runs.

**Draft MTP context: cap-bump.** The draft MTP context's per-call
`llama_decode` is bounded by `1 + n_max`. Chunking it would be
performance-destructive (one draft token per call). The right fix is to
raise the cap to match the target's formula. Concretely, replace
`cparams_mtp.n_outputs_max = params_base.n_parallel;` at
`server-context.cpp:1308` (and the matching
`params_dft.n_outputs_max = params_base.n_parallel;` at
`server-context.cpp:1175`) with the symmetric formula
`n_parallel * (1 + common_speculative_n_max(&params_base.speculative))`.

**Non-MTP separate draft model:** the cap-bump rule for the draft MTP
context does not change the non-MTP separate draft path. The non-MTP
draft context is used for `draft-simple` or other draft-model
speculative types, and the draft context's `n_outputs_max` stays at
`n_parallel`. The cap on those speculative types is the target's
`server_n_outputs_max` formula, which already accounts for the
speculative `n_max`.

## Why these rules and not the alternatives

For the target context, the three options were:

- **Chunked-decode (chosen).** Reuses the existing chunking pattern in
  the speculative loop. No new public surface. No memory over-allocation
  for non-MTP prompts. Adds at most `ceil((prompt - 1 - n_max) / cparams.n_outputs_max) - 1`
  extra `llama_decode` calls per prompt.
- **Cap-bump (rejected for the target).** Raising
  `cparams.n_outputs_max` for the target to absorb the full residual
  would either depend on a per-request prompt size (set at context
  init, not request time) or over-allocate the output buffer to
  `n_batch`. The output buffer size is the cost; over-allocation is
  not acceptable on memory-tight hosts.
- **Batch-shrink (rejected for the target).** Building a smaller batch
  in `update_slots` would require either truncating the residual (which
  breaks the verify path) or queuing the truncated tail for a follow-up
  call (which is chunked-decode with extra bookkeeping).

For the draft MTP context, the three options were:

- **Cap-bump (chosen).** Matches the target's formula and respects
  upstream PR #23861's per-context cap semantics. The fix is one line
  per call site.
- **Chunked-decode (rejected for the draft MTP).** Chunking the
  MTP draft's per-call decode into `1 + n_max` separate calls would
  serialize the draft generation step and break the MTP throughput.
- **Batch-shrink (rejected for the draft MTP).** The MTP draft decode
  is already minimal; there is nothing to shrink.

## Affected surfaces

The fix touches five call sites in two files.

| File | Line | What changes |
| --- | --- | --- |
| `tools/server/server-context.cpp` | 1109 | No change. `params_base.n_outputs_max = server_n_outputs_max(params_base)` stays as-is. The cap is the contract. |
| `tools/server/server-context.cpp` | 1175 | Change `params_dft.n_outputs_max = params_base.n_parallel;` to `params_dft.n_outputs_max = params_base.n_parallel * (1 + common_speculative_n_max(&params_base.speculative));` only for the `spec_mtp` branch. The non-MTP draft path keeps `params_base.n_parallel`. |
| `tools/server/server-context.cpp` | 1308 | Change `cparams_mtp.n_outputs_max = params_base.n_parallel;` to `cparams_mtp.n_outputs_max = params_base.n_parallel * (1 + common_speculative_n_max(&params_base.speculative));`. |
| `tools/server/server-context.cpp` | 3750 | Bound the chunk size on `min(n_batch, cparams.n_outputs_max / n_parallel)` or equivalent per-sequence cap. The chunked loop already exists; the bound changes. |
| `tools/server/server-cache-hybrid.h` | (none directly) | The hybrid controller's `n_tokens()` helpers are not the call site. The investigation names this file because the speculative batch building lives in the hybrid-aware `update_slots` path. No code change in `server-cache-hybrid.h` is required for the sizing fix. |

The two server-context call sites that change the draft MTP cap
(1175 and 1308) are guarded by the existing `if (spec_mtp)` and
`else if (... COMMON_SPECULATIVE_TYPE_DRAFT_MTP ...)` branches. The
non-MTP draft path keeps its `n_parallel` cap. The cap-bump only
applies to the MTP draft context.

## Pair-state and target/draft interaction

The Stage 5 pair-state rule (architecture Part 6) keeps the target and
draft contexts paired for save, restore, eviction, and cold-layer
operations. The cap rule is independent of pair state. Each context
gets its own per-context `cparams.n_outputs_max` at init, and each
context's `llama_decode` calls must respect that cap.

The MTP target path uses `llama_set_embeddings_nextn(ctx_tgt, true, true)`
(common/speculative.cpp:491-492), which sets
`cparams.embeddings_nextn = true` and
`cparams.embeddings_nextn_masked = true`. The
`output_reserve(13)` call still passes the assertion at
`src/llama-context.cpp:2152` because `cparams.embeddings_nextn_masked`
gates the `embd_nextn.size` allocation to `n_embd * n_outputs_max`, not
to `n_embd * n_batch`. The cap on `embd_nextn.size` is the same cap
that breaks the `logits.size` and `embd.size` allocations when the
decode batch exceeds `n_outputs_max`.

The cap-bump for the MTP draft context at 1175 and 1308 is symmetric
with the target's formula. The two contexts end up with the same
`n_outputs_max` value when the MTP draft is active, which is what
upstream PR #23861 intends.

## Testability

The fix must satisfy the following test plan rows.

| Row | Source | Why this row |
| --- | --- | --- |
| H53 | Test plan Part 11 (Stage 9 checkpoint integration) | Target-derived MTP save and restore. The H53 row exercises the same MTP target path that the crash hit. |
| H54 | Test plan Part 11 | Separate-model MTP save and restore. The H54 row exercises the MTP draft path whose cap also needs the cap-bump. |
| H57 | Test plan Part 11 | Normal draft versus MTP namespace isolation. The cap change must not break the namespace isolation. |
| T112 | Test plan Part 12 (Stage 10 observability, security, hardening) | Unsupported runtime shape. The cap-bump must not change the unsupported-runtime-shape rejection. |
| T121 | Test plan Part 12 | Stage 9 regression. The four `cache_checkpoint_*` rows must remain exposed. The cap change does not touch metrics. |

The fix also requires a new test plan row, recorded here as a proposal
for the test plan follow-up rather than as a change to the test plan
itself. The Architect reviews the proposal in the test plan review
gate. The proposed row is:

| ID | Scenario | Expected result |
| --- | --- | --- |
| T-NOUT-MAX-01 | Speculative decode batch stays within `cparams.n_outputs_max` | With a hybrid-mode MTP server (`n_parallel = 1`, `n_max = 3`), the `decoding batch, n_tokens` log line at `server-context.cpp:3714` and the per-chunk `n_tokens` value passed to `llama_decode` at `server-context.cpp:3750` both stay at or below `cparams.n_outputs_max = 4`. The first user prompt from the investigation's repro (`"What is your problem?"`, 17 tokens) decodes without tripping the `output_reserve` assertion. |
| T-NOUT-MAX-02 | Draft MTP context cap matches the target formula | With the same server, `cparams_mtp.n_outputs_max` (read from `SRV_INF("%s: n_outputs_max = %u\n", ...)` at `src/llama-context.cpp:233`) equals `n_parallel * (1 + n_max) = 4`. The draft MTP path's per-call `llama_decode` of `1 + n_max = 4` tokens does not trip the same assertion. |

Both proposed rows are focused or model-backed, depending on whether
a suitable MTP fixture is available. T-NOUT-MAX-01 is satisfiable from
focused C++ evidence (a unit test that drives the chunked loop with a
batch > cap and asserts the per-chunk size). T-NOUT-MAX-02 is
satisfiable from focused C++ evidence (a startup assertion that reads
the per-context cap and compares it to the symmetric formula). The
test plan follow-up can downgrade either row to a substitute evidence
form if the local fixture set cannot exercise the MTP path.

## Risk

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Chunked-decode on the target changes the per-prompt `llama_decode` call count. | Latency rises by the extra calls. Latency is bounded by `ceil((prompt - 1 - n_max) / cparams.n_outputs_max) - 1` extra calls per prompt, each at the speculative batch cost. The cost is small for typical prompt sizes. | The focused C++ test for T-NOUT-MAX-01 records the per-chunk size. The benchmark follow-up compares prompt-to-first-token latency before and after the fix. |
| Cap-bump on the draft MTP raises the per-context output buffer size. | Memory cost rises for the MTP draft context. The draft context's output buffer is sized to `cparams.n_outputs_max * n_embd`, so the cost is `(n_parallel * (1 + n_max) - n_parallel) * n_embd * sizeof(float)` per draft context. For `n_parallel = 1`, `n_max = 3`, `n_embd = 4096`, that is 49152 bytes per draft context. | Acceptable. The cost is bounded and symmetric with the target. The fix also reuses the same `server_n_outputs_max` formula for both contexts, so the buffer sizes are aligned. |
| Chunked-decode changes the per-call `n_outputs` for the MTP target. | The `n_outputs_per_seq` and `cparams.n_outputs_max` invariant must be re-verified for every chunked call, not just the first. | The chunked loop computes `n_tokens` per call; the `output_reserve` assertion enforces the cap on every call. The T-NOUT-MAX-01 row exercises the assertion. |
| Cap-bump on the draft MTP at line 1308 is the only fix site; line 1175 is upstream of the `ctx_dft` creation and feeds the `cparams_mtp`. | A fix at 1308 only might leave the 1175 site stale. | The fix at 1175 is a `params_dft` update that feeds `cparams_dft` for the MTP path. The 1175 site is the source; the 1308 site is the MTP-specific copy. Both must change in lockstep, or one becomes dead code. The implementation plan must list both. |
| The chunked-decode bound on `cparams.n_outputs_max` interacts with `n_parallel > 1` and multi-slot batching. | A naive bound on `cparams.n_outputs_max` per chunk could starve parallel slots. | The bound is per-sequence. `cparams.n_outputs_max` is the per-context total, so per-sequence cap is `cparams.n_outputs_max / n_parallel`. The implementation plan must use the per-sequence value, not the per-context value. |
| The fix relies on the draft MTP context's `n_outputs_max` matching the target's formula. If upstream changes the formula in a future PR, the local cap-bump drifts. | The cap-bump becomes out of date with upstream. | The cap-bump is defined as `n_parallel * (1 + common_speculative_n_max(&params_base.speculative))` to match upstream PR #23861's formula. A future Stage N pre-merge analysis re-derives the formula from upstream. |

## Observability

The fix does not need a new public metric. The existing R61-R68 metric
set, the four `cache_checkpoint_*` rows, and the bounded diagnostics
from Stage 10 are not affected.

The fix needs one new server log line at the speculative chunked-decode
site, recording the chunk count and the per-chunk `n_tokens` for
operator triage. The line is a `SRV_DBG` at the chunked loop in
`server-context.cpp:3750`. Format:

```text
srv  update_slots: speculative chunked decode, chunk = N, n_tokens = K, cap = C
```

where `N` is the chunk index, `K` is `n_tokens` for that chunk, and
`C` is `cparams.n_outputs_max`. The line is bounded and free of
prompt text, model paths, and marker material. No new public metric,
no new bounded diagnostic event, no new public CLI flag.

## Out of scope

- A retry or fallback behavior when the chunked-decode path trips the
  `output_reserve` assertion. The assertion is a hard invariant; the
  fix is to keep the call within the cap, not to catch the failure.
- A new public metric for chunked-decode counts. The server log line
  is enough for operator triage.
- A new focused C++ test binary. The T-NOUT-MAX-01 and T-NOUT-MAX-02
  rows reuse the existing `test-cache-controller` and
  `test-stage10-cold-store-hardening` harnesses, or add a small
  function to one of them. The test plan follow-up decides.
- A change to the legacy default path. The cap rule applies only when
  the speculative path is active.
- A change to the non-MTP separate draft path. The non-MTP draft's
  cap stays at `n_parallel` because the target's cap already accounts
  for the non-MTP speculative `n_max`.

## Requirement traceability

| Requirement | Source | How this part keeps it in force |
| --- | --- | --- |
| R34-R36, R36a-R36d (correctness and fallback) | Architecture | The chunked-decode bound keeps every `llama_decode` call within the per-context cap, which is the hard correctness invariant for the speculative path. |
| R90-R92 (correctness invariants) | Architecture | The cap is the invariant. The fix is the implementation contract that respects the invariant. |
| R120-R124 (fallback and failure handling) | Architecture | The fix prevents the cap violation; the fallback path is unchanged. |
| Stage 5 speculative-mode namespace isolation | Architecture Part 6 | The cap-bump does not touch the namespace key. The pair-state rule is independent. |
| Stage 10 bounded diagnostics | Test plan Part 12 | The new `SRV_DBG` line at the chunked loop is bounded and free of prompt text, paths, and marker material. |
| T114 / T114a coverage floors | Test plan Parts 12, 13 | The fix adds at most a few lines of code; coverage impact is within the existing per-file targets. |

## Self-review against the design checklist

| Item | Status | Note |
| --- | --- | --- |
| Scope | Recorded | Speculative decode-batch sizing under the upstream cap. Out-of-scope items are listed. |
| Prerequisites | Recorded | Stage 10 CLOSED. Stage 11 CLOSED. No new prerequisite. |
| Assumptions | Recorded | Upstream PR #23861 cap formula is stable. Local MTP fixture is available or a focused substitute is acceptable. |
| Interfaces | Recorded | The cap-bump changes `params_dft.n_outputs_max` and `cparams_mtp.n_outputs_max`. The chunked-decode bound changes the chunked loop in `server-context.cpp:3750`. No new interface. |
| Constraints | Recorded | The cap is the hard invariant. Pair state and namespace isolation are independent. |
| Observability | Recorded | One new bounded `SRV_DBG` line. No new public metric. |
| Testability | Recorded | T-NOUT-MAX-01 and T-NOUT-MAX-02 proposals. Existing H53, H54, H57, T112, T121 rows. |
| Decision points | Recorded | Chunked-decode for the target. Cap-bump for the draft MTP. Rejection reasons for the alternatives. |
| Requirement traceability | Recorded | R34-R36, R36a-R36d, R90-R92, R120-R124, Stage 5 namespace isolation, Stage 10 bounded diagnostics, T114/T114a. |
| Risks | Recorded | Latency, memory, multi-slot starvation, upstream drift, parallel slot interaction. |
| Out of scope | Recorded | Retry, fallback, new metric, new test binary, legacy default change, non-MTP draft change. |
| Manager handoff line | Recorded | Bottom of the part. |

## Handoff

Submitting for independent Architect design review. Owner: Manager. Next gate: Design review.
