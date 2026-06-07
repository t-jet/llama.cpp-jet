# Stage 11 follow-up: independent Architect plan review (gate 01)

VERDICT: PASS

## 1. Scope and references

Independent Architect plan review of the Stage 11 follow-up implementation plan `part-20-stage11-mtp-cap-fix-implementation-plan.md`. Source gate: design `part-08-n-outputs-max-cap-followup.md` and design review `part-09-design-review-gate-02.md` (PASS, 0 BLOCKER / 4 NON-BLOCKER / 3 ADVISORY). Architecture invariant: `cache-handling-architecture/part-07-speculative-decode-batch-cap-invariant.md`. Investigation (trusted): `part-19-stage11-mtp-crash-investigation.md`. Source call sites reviewed: `tools/server/server-context.cpp:204, 1109, 1175, 1308, 3714, 3750`; `src/llama-context.cpp:2013, 2152`; `common/common.h` (`n_outputs_max` `int32_t`, `n_batch` `int32_t`, `n_parallel` `int32_t`); `include/llama.h` (`llama_context_params::n_outputs_max` `uint32_t`); `common/speculative.{h,cpp}` (`common_speculative_n_max` returns `int32_t`). Test plan rows H53/H54/H57 inspected in `cache-handling-test-plan/part-03-integration-test-matrix.md`. This review does not edit the plan, the design, the architecture invariant, the design review, the investigation, the implementation log, the test plan, or any test report.

## 2. Findings table

| ID | Severity | Summary | Plan location | Suggested resolution |
| --- | --- | --- | --- | --- |
| F-21-01 | NON-BLOCKER | New `SRV_DBG` line at :3750 uses `%u` format specifier for `params_base.n_outputs_max` which is `int32_t` (common/common.h:6327). Format mismatch is undefined behavior per the C standard. | Step 1 `SRV_DBG` line | Change `%u` to `%d`. |
| F-21-02 | NON-BLOCKER | Step 2 and Step 3 use `std::min<uint64_t>(int32_t, int32_t * (1 + int32_t))` and assign to `int32_t` (Step 2) and `uint32_t` (Step 3) fields. Implicit narrowing conversion will produce a compiler warning under `/W4` or `-Wconversion`. | Step 2 and Step 3 snippets | Use `std::min<uint32_t>` with the same explicit cast style as `server_n_outputs_max` at :204, or wrap the result in `static_cast`. |
| F-21-03 | ADVISORY | Risk table does not include a row for the architecture part 7 per-context vs per-sequence wording drift (F-09-05). The plan acknowledges the follow-up but does not flag it as a tracked risk. | Section 6 "Known risks" | Add a one-line risk row pointing at the Architect follow-up correction pass on `part-07`. |
| F-21-04 | ADVISORY | Evidence plan uses `Select-String` patterns that assume a particular whitespace style around the new initializer-list `std::min({...})`. If the Developer's editor reformats to single-line, the grep pattern in Step 1 may miss the line. | Section 5 "Evidence plan", Step 1 | Add a fallback grep that matches the substring `params_base.n_outputs_max` on the same line as `n_tokens`. |
| F-21-05 | ADVISORY | Code snippets use C-style casts (`(int32_t) params_base.n_outputs_max`) instead of `static_cast<int32_t>`. The plan is in a C++ codebase. | Step 1 snippet | Use `static_cast<int32_t>` for consistency with the surrounding code style. |

## 3. F-09 verification table

| Finding | Addressed | Plan line | Evidence |
| --- | --- | --- | --- |
| F-09-01 | yes | Step 2 and Step 3, both wrap the symmetric formula in `std::min<uint64_t>(params_base.n_batch, ...)` | Clamp present at both :1175 and :1308 call sites in the plan snippets |
| F-09-02 | yes | Section 2 step ordering: "chunked-decode first, then cap-bump" with rationale reworded to "the cap-bump formula is only correct after the chunked loop is bounded" | Step 1 (chunked-decode) precedes Step 2 (draft MTP cap-bump) precedes Step 3 (MTP cparams cap-bump) |
| F-09-03 | yes | Step 1 chunk size uses `params_base.n_outputs_max` (per-context); risk row 2 explicitly states "per F-09-03, the bound is per-context; the per-sequence reading is implicit" | Per-context cap and explicit F-09-03 owner note in Section 6 risk row 2 |
| F-09-04 | yes | Section 4 "Test plan follow-up sub-task (F-09-04)" names Developer as owner, test plan review (Architect) as gate, and Part 11 as the file to open | Plan does not edit the test plan; H53/H54/H57 in `part-03-integration-test-matrix.md` (lines 137, 138, 141) do not reference `cparams_mtp.n_outputs_max == n_parallel` — verification will pass |

## 4. Plan-vs-design conformance check

| Design decision (`part-08`) | Plan conformance |
| --- | --- |
| Target context = chunked-decode on `min(n_batch, cparams.n_outputs_max)` | Step 1 binds per-chunk to `min({n_batch, batch.n_tokens - i, (int32_t) params_base.n_outputs_max})` — matches design |
| Draft MTP context = cap-bump to `n_parallel * (1 + n_max)` with `min(n_batch, ...)` clamp | Step 2 (`params_dft.n_outputs_max`) and Step 3 (`cparams_mtp.n_outputs_max`) both use the symmetric formula with the clamp |
| Non-MTP separate draft path keeps `n_parallel` cap | Step 2 `else` branch keeps `params_dft.n_outputs_max = params_base.n_parallel`; Step 3 is inside the existing `else if (... COMMON_SPECULATIVE_TYPE_DRAFT_MTP ...)` branch, so non-MTP is unaffected |
| `server_n_outputs_max` at :204 is the upstream contract, unchanged | Plan keeps :204 and :1109 unchanged |
| One bounded `SRV_DBG` line at chunked loop, no prompt text, paths, or marker material | Step 1 adds the `SRV_DBG` line; format spec only contains the chunk index, `n_tokens`, and `cparams.n_outputs_max` — bounded |
| `server-cache-hybrid.h` carries no change | Plan explicitly says no change in Section 2 last paragraph |
| T-NOUT-MAX-01, T-NOUT-MAX-02 are proposals, not inlined test plan rows | Section 3 records them as plan-only rows; the test plan follow-up decides adoption |
| H53/H54/H57 must be verified not to pin the old cap | Section 4 sub-task records the verification, owner, and gate |
| Cap-bump memory cost documented, scales with `n_embd` | Risk row 4 includes 49152-byte figure and F-09-07 `n_embd` note |
| Architecture `part-07` wording correction is a follow-up Architect pass (F-09-05), not a plan step | Section 4 explicitly defers the correction |

## 5. Step ordering and code-snippet check

| Step | Ordering | Code-snippet | Notes |
| --- | --- | --- | --- |
| Step 1 (chunked-decode at :3750) | first — correct per F-09-02 | compiles with C++11 initializer-list `std::min`; F-21-01 (`%u` -> `%d`), F-21-05 (C-style cast) are non-blockers | `params_base.n_outputs_max` is in scope inside `update_slots` |
| Step 2 (draft MTP cap-bump at :1175) | second, correct | compiles; F-21-02 narrowing warning on assignment to `int32_t` | `if (spec_mtp) ... else { ... n_parallel; }` correctly splits the existing `if (has_draft / spec_mtp)` branch |
| Step 3 (MTP cparams cap-bump at :1308) | third — correct | compiles; F-21-02 narrowing warning on assignment to `uint32_t` | Inside existing `else if (... COMMON_SPECULATIVE_TYPE_DRAFT_MTP ...)` branch, MTP-only |

Step ordering is correct. All three snippets are compilable against the surrounding code at :1175, :1308, :3750 on HEAD `02db7a768`.

## 6. Manager handoff

Submitting to Manager. Owner: Manager. Next gate: Implementation (Developer) or Developer correction.
