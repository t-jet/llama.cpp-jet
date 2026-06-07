# Stage 11 follow-up: n_outputs_max cap fix - implementation plan

Read-only implementation plan. No code edits, no commits, no builds, no test runs. Owner: Developer. Source gate: design review `part-09-design-review-gate-02.md` (PASS, 0 BLOCKER / 4 NON-BLOCKER / 3 ADVISORY). Submitting for independent Architect plan review.

## 1. Approved design baseline

- Invariant (architecture): `cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md`. The speculative decode-batch builder must keep every `llama_decode` call's `n_tokens` at or below the per-context `cparams.n_outputs_max` cap, enforced by `GGML_ASSERT(n_outputs_max <= cparams.n_outputs_max)` at `src/llama-context.cpp:2152`.
- Design correction (approved): `cache-handling-phase11-design/part-08-n-outputs-max-cap-followup.md`. Target context = chunked-decode on `min(n_batch, cparams.n_outputs_max)`. Draft MTP context = cap-bump to `n_parallel * (1 + n_max)` (with `min(n_batch, ...)` clamp per F-09-01). Non-MTP separate draft path unchanged.
- Design review (PASS, 0 BLOCKER / 4 NON-BLOCKER / 3 ADVISORY): `cache-handling-phase11-design/part-09-design-review-gate-02.md`.
- Crash trigger (trusted): `cache-handling-phase11-implementation/part-19-stage11-mtp-crash-investigation.md`. `output_reserve(13)` against `cparams.n_outputs_max = 4` in the target context. 13-token batch is residual after MTP verify prefix `1 + n_max = 4` is pre-removed from a 17-token prompt.

## 2. Ordered steps

Order is fixed by F-09-02: chunked-decode first, then cap-bump. The cap-bump formula is only correct after the chunked loop is bounded; otherwise a `n_parallel > 1` MTP draft decode could still exceed the cap.

Step 1 - chunked-decode bound at `tools/server/server-context.cpp:3750`. In the existing chunked-decode loop, change the per-chunk size to include the per-context cap, and add a bounded `SRV_DBG` line above the `llama_decode` call. This is the per-context cap bound required by F-09-03.

````cpp
// file: tools/server/server-context.cpp, inside the chunked-decode loop at :3750
for (int32_t i = 0; i < batch.n_tokens; i = i_next) {
    const int32_t n_tokens = std::min({
        n_batch,
        batch.n_tokens - i,
        (int32_t) params_base.n_outputs_max
    });

    llama_batch batch_view = { /* unchanged */ };

    SRV_DBG("srv  update_slots: speculative chunked decode, chunk=%d n_tokens=%d cap=%u\n",
            i / std::max<int32_t>(1, n_batch), n_tokens, params_base.n_outputs_max);

    const int ret = llama_decode(ctx_tgt, batch_view);
    /* unchanged */
}
````

Step 2 - draft MTP cap-bump at `tools/server/server-context.cpp:1175`. The unconditional assignment becomes a two-branch assignment. The `min(n_batch, ...)` clamp is required by F-09-01. The non-MTP separate draft path keeps the `n_parallel` cap.

````cpp
// file: tools/server/server-context.cpp, replacing the line at :1175
if (spec_mtp) {
    params_dft.n_outputs_max = std::min<uint64_t>(
        params_base.n_batch,
        params_base.n_parallel * (1 + common_speculative_n_max(&params_base.speculative)));
} else {
    params_dft.n_outputs_max = params_base.n_parallel;
}
````

Step 3 - MTP cparams cap-bump at `tools/server/server-context.cpp:1308`. Inside the existing `else if (... COMMON_SPECULATIVE_TYPE_DRAFT_MTP ...)` branch, change the `cparams_mtp.n_outputs_max` assignment to the symmetric formula with the `min(n_batch, ...)` clamp. Same clamp rationale as F-09-01.

````cpp
// file: tools/server/server-context.cpp, replacing the line at :1308
cparams_mtp.n_outputs_max = std::min<uint64_t>(
    params_base.n_batch,
    params_base.n_parallel * (1 + common_speculative_n_max(&params_base.speculative)));
````

`tools/server/server-context.cpp:1109` (`params_base.n_outputs_max = server_n_outputs_max(params_base);`) is unchanged. `tools/server/server-cache-hybrid.h` carries the F-09-06 "(none directly)" note forward: no change expected in that file.

## 3. Tests to add (rows in the plan only; the test plan follow-up decides adoption)

| ID | Scenario | Expected result |
| --- | --- | --- |
| T-NOUT-MAX-01 | Chunked-loop per-chunk n_tokens stays at or below the cap | With a hybrid-mode MTP server (`n_parallel = 1`, `n_max = 3`), the `decoding batch, n_tokens` log line at `server-context.cpp:3714` and the per-chunk `n_tokens` value passed to `llama_decode` at `server-context.cpp:3750` both stay at or below `cparams.n_outputs_max = 4`. The first user prompt from the investigation's repro (`"What is your problem?"`, 17 tokens) decodes without tripping the `output_reserve` assertion. Satisfiable from focused C++ evidence (drives the chunked loop with a batch > cap and asserts the per-chunk size). |
| T-NOUT-MAX-02 | Draft MTP context cap matches the symmetric formula with the `min(n_batch, ...)` clamp | With the same server, `cparams_mtp.n_outputs_max` equals `min(n_batch, n_parallel * (1 + n_max))`. For `n_parallel = 1`, `n_max = 3`, this evaluates to `min(n_batch, 4)`. The draft MTP path's per-call `llama_decode` of `1 + n_max = 4` tokens does not trip the same assertion. Satisfiable from focused C++ evidence (a startup assertion that reads the per-context cap and compares it to the symmetric formula with the clamp). |

## 4. Docs to update

None required. The design (`part-08`), the architecture invariant (`part-07`), the design review (`part-09`), and the investigation (`part-19`) are already in place. The architecture `part-07` wording uses the same ambiguous `min(n_batch, cparams.n_outputs_max / n_parallel)` phrasing as the design and is recorded here as a follow-up Architect correction pass (per F-09-05), not a plan step. The implementation plan does not edit the test plan (F-09-04 sub-task below).

### Test plan follow-up sub-task (F-09-04)

The Architect review (F-09-04) flagged that the design asserts the fix "must satisfy" H53/H54/H57 without verifying that those rows do not pin the old cap value (`cparams_mtp.n_outputs_max == n_parallel`). Test plan follow-up must open test plan Part 11, confirm H53/H54/H57 do not assert `cparams_mtp.n_outputs_max == n_parallel`, and if they do, update the row text. The implementation plan does not edit the test plan; it records the follow-up. Owner: Developer (test plan follow-up). Gate: test plan review (Architect).

## 5. Evidence plan

Per-step grep + a small `SRV_DBG` showing the chunked loop bound. No build, no test run, no coverage, no k6.

| Step | Evidence |
| --- | --- |
| 1 | `Select-String -Path tools/server/server-context.cpp -Pattern 'min\(\{n_batch, batch.n_tokens - i, .*params_base.n_outputs_max\}\)'` and `Select-String -Path tools/server/server-context.cpp -Pattern 'speculative chunked decode, chunk='`. The new `SRV_DBG` line is bounded and free of prompt text, model paths, and marker material. |
| 2 | `Select-String -Path tools/server/server-context.cpp -Pattern 'params_dft.n_outputs_max = std::min<uint64_t>\(params_base.n_batch,'` confirming the spec_mtp branch formula. |
| 3 | `Select-String -Path tools/server/server-context.cpp -Pattern 'cparams_mtp.n_outputs_max = std::min<uint64_t>\(params_base.n_batch,'` confirming the MTP cparams formula. |
| Cross-check | `Select-String -Path tools/server/server-context.cpp -Pattern 'server_n_outputs_max'` and visual diff of the formula at `:204` against the cap-bump formulas at `:1175` and `:1308` to confirm lockstep. |

## 6. Known risks

- **Upstream drift on the cap-bump formula.** The cap-bump at `:1175` and `:1308` must stay in lockstep with `server_n_outputs_max` at `:204`. If upstream changes the formula, both call sites must update in the same commit. Mitigation: a future Stage N pre-merge analysis re-derives the formula from upstream. Cross-check evidence above catches drift in this plan's gate.
- **Starvation for `n_parallel > 1`.** The chunked-decode bound at `:3750` is per-context (`min(n_batch, cparams.n_outputs_max)`), so per-sequence share is `cparams.n_outputs_max / n_parallel` and is implicit. The chunked loop chunks the whole batch, not per-sequence, so no sequence is starved within a chunk. Owner note: per F-09-03, the bound is per-context; the per-sequence reading is implicit and must be re-stated in the Architect follow-up correction on `part-07`.
- **Test plan row updates (F-09-04).** H53/H54/H57 may assert the old cap value. Test plan follow-up owns the verification and the row text update. Implementation plan does not pre-empt that work.
- **Memory cost of cap-bump.** Per the design's risk row, the draft MTP output buffer grows by `(n_parallel * (1 + n_max) - n_parallel) * n_embd * sizeof(float)` per draft context. For `n_parallel = 1`, `n_max = 3`, `n_embd = 4096`, that is 49152 bytes per draft context. Scales with model `n_embd` (F-09-07). Acceptable and symmetric with the target.
- **Latency from chunked-decode.** Bounded by `ceil((prompt - 1 - n_max) / cparams.n_outputs_max) - 1` extra `llama_decode` calls per prompt. The new `SRV_DBG` line gives operator triage data.

## 7. Manager handoff

Submitting for independent Architect plan review. Owner: Manager. Next gate: Implementation-plan review (Architect) or Developer correction.
