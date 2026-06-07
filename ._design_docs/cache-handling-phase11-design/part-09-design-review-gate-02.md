VERDICT: PASS

# Stage 11 follow-up: independent Architect design review (gate 02)

## 1. Scope and references

Independent Architect design review for the Stage 11 follow-up design
correction. Target: `part-08-n-outputs-max-cap-followup.md` (the
`n_outputs_max` cap follow-up). Architecture invariant under review:
`cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md`.
Investigation (trusted): `cache-handling-phase11-implementation/part-19-stage11-mtp-crash-investigation.md`.
Source call sites reviewed: `tools/server/server-context.cpp:204, 1109,
1175, 1308, 3714, 3750`; `src/llama-context.cpp:2013-2152`;
`common/speculative.cpp:491-492, 594-613`. Prior review
(`part-07-design-review-gate-01.md`) is closed and was not touched.
This review does not edit the design under review, the architecture
part, the investigation, the implementation log, the test plan, or any
test report. Scope: rule correctness against source, memory cost
disclosure, parallel-slot starvation, invariant placement, test plan
backwards-compat, and test row handoff.

## 2. Findings table

| ID | Severity | Summary | Location | Suggested resolution |
| --- | --- | --- | --- | --- |
| F-09-01 | NON-BLOCKER | MTP draft cap-bump "symmetric formula" drops the `min(n_batch, ...)` clamp that the target's `server_n_outputs_max` at `server-context.cpp:204` applies. | `part-08`, "The rule" section, draft MTP bullet | Implementation plan should set `cparams_mtp.n_outputs_max = std::min<uint64_t>(params_base.n_batch, params_base.n_parallel * (1 + common_speculative_n_max(&params_base.speculative)))` at `server-context.cpp:1308`, and the same formula at `server-context.cpp:1175` for the `spec_mtp` branch only. The design intent is clear; the symmetric formula needs the clamp. |
| F-09-02 | NON-BLOCKER | Justification "draft MTP context's per-call `llama_decode` is bounded by `1 + n_max`" holds for `n_parallel = 1` only. For `n_parallel > 1`, the MTP draft's per-call decode at `common/speculative.cpp:613` receives the same `batch_view` the chunked loop just decoded on the target, so the bound is the chunk size `min(n_batch, n_parallel * (1 + n_max))`. | `part-08`, "The rule" section, draft MTP bullet; "Pair-state and target/draft interaction" section | Implementation plan must implement the chunked-decode bound first, then the cap-bump. The cap-bump formula `n_parallel * (1 + n_max)` is still correct; the rationale sentence should be reworded to "bounded by the chunked-decode chunk size" rather than `1 + n_max`. |
| F-09-03 | NON-BLOCKER | Chunked-decode rule says `min(n_batch, cparams.n_outputs_max / n_parallel)` or "equivalent per-sequence cap." The cap is per-context (the assertion at `src/llama-context.cpp:2152` checks `n_outputs_max <= cparams.n_outputs_max` where `cparams.n_outputs_max` is the per-context total). The chunked loop at `server-context.cpp:3750` chunks the whole batch, not per-sequence. | `part-08`, "The rule" section, target context bullet; "Risk" table, parallel-slot row | Implementation plan should use `min(n_batch, cparams.n_outputs_max)` as the per-chunk bound, which is the per-context cap. The per-sequence share is `cparams.n_outputs_max / n_parallel` and is implicit in the per-context bound. Architecture part 7 has the same wording and should be re-read in the same review pass. |
| F-09-04 | NON-BLOCKER | Backwards-compat impact on H53, H54, H57 is asserted ("the fix must satisfy") but not verified. The design does not check whether those test plan rows assert the old cap value (`params_base.n_parallel`). | `part-08`, "Testability" section, H53/H54/H57 rows | Test plan follow-up must confirm H53/H54/H57 do not pin the old cap. If any row asserts `cparams_mtp.n_outputs_max == n_parallel`, the row needs an update. The fix itself is backwards-compatible at the code level; the concern is test plan row text. |
| F-09-05 | ADVISORY | Architecture part 7's chunked-decode bullet uses the same ambiguous `min(n_batch, cparams.n_outputs_max / n_parallel)` wording as the design. If the design is corrected, the architecture part should follow. | `cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md`, "The rule per context" section | A single follow-up correction pass should align the architecture part and the design part on the per-context vs per-sequence wording. The invariant itself is correct. |
| F-09-06 | ADVISORY | `server-cache-hybrid.h` is listed in the "Affected surfaces" table with "(none directly)" but is named because "the speculative batch building lives in the hybrid-aware `update_slots` path." This is accurate but worth a one-line note in the implementation plan that no change to `server-cache-hybrid.h` is expected. | `part-08`, "Affected surfaces" table, `server-cache-hybrid.h` row | Implementation plan should carry the "(none directly)" note forward so the Developer does not search for a change site in that file. |
| F-09-07 | ADVISORY | Cap-bump memory cost is stated for `n_parallel = 1, n_max = 3, n_embd = 4096` as 49152 bytes. The formula `(n_parallel * (1 + n_max) - n_parallel) * n_embd * sizeof(float)` is correct but the design does not note that `n_embd` varies by model. | `part-08`, "Risk" table, cap-bump memory row | Add a one-line note: actual cost scales with the model `n_embd`; the 49152 bytes figure is for `n_embd = 4096`. No change needed if the test plan follow-up records the model used for T-NOUT-MAX-02. |

## 3. Traceability check

- **Requirement-to-design:** R34-R36, R36a-R36d, R90-R92, R120-R124
  are traced in the "Requirement traceability" table of
  `part-08-n-outputs-max-cap-followup.md`. The Stage 5 namespace
  isolation and Stage 10 bounded diagnostics references are also
  traced. The traceability is complete and the cited requirements
  align with the cap invariant.
- **Design-to-test-plan:** H53, H54, H57 (test plan Part 11) and
  T112, T121 (test plan Part 12) are listed as existing rows the fix
  must satisfy. T-NOUT-MAX-01 and T-NOUT-MAX-02 are recorded as
  proposals for the test plan follow-up rather than as inlined test
  plan rows. This is the correct handoff per the Architect skill
  (test plan is a separate durable doc, and corrections to it belong
  to the test plan follow-up gate, not to the design correction).
- **Architecture-to-design:** Architecture part 7 records the
  invariant and points to the design part for the implementation
  contract. The design part points back to the architecture part for
  the invariant. The two-way linkage is correct.

## 4. Risk re-assessment

- **Latency from chunked-decode:** bounded by
  `ceil((prompt - 1 - n_max) / cparams.n_outputs_max) - 1` extra
  calls. Acceptable for typical prompt sizes; the new
  `SRV_DBG` log line at `server-context.cpp:3750` gives operator
  triage data.
- **Memory from cap-bump:** 49152 bytes per draft context for
  `n_parallel = 1, n_max = 3, n_embd = 4096`. Scales with
  `n_embd`. Acceptable and symmetric with the target.
- **Parallel-slot starvation:** the per-context cap is shared across
  `n_parallel` sequences. For `n_parallel = 1` the chunked loop
  already handles the case. For `n_parallel > 1`, the per-chunk bound
  `min(n_batch, cparams.n_outputs_max)` keeps every chunk within the
  per-context cap, so no sequence is starved within a chunk. The
  per-sequence share is `cparams.n_outputs_max / n_parallel` and is
  implicit.
- **Upstream drift:** the cap-bump formula mirrors
  `server_n_outputs_max` at `server-context.cpp:204`, so a future
  upstream change to the formula must update both call sites in
  lockstep. The risk row is recorded.
- **H53/H54/H57 backwards-compat:** not verified in the design (see
  F-09-04). Test plan follow-up must confirm.

## 5. Decision and Manager handoff

Submitting to Manager. Owner: Manager. Next gate: Implementation
planning (Developer) or Architect correction.
