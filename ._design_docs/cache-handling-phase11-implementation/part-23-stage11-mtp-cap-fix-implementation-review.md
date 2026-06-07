VERDICT: PASS

# Stage 11 follow-up: n_outputs_max cap fix - implementation review

## 1. Scope and references

- Implementation log under review: `part-22-stage11-mtp-cap-fix-implementation.md`.
- Plan: `part-20-stage11-mtp-cap-fix-implementation-plan.md` (PASS, 0 BLOCKER / 3 NON-BLOCKER / 2 ADVISORY).
- Plan review: `part-21-stage11-mtp-cap-fix-plan-review-gate-01.md`.
- Code change: `tools/server/server-context.cpp` (1 file, 18 insertions / 3 deletions).
- Build dir: `build-cuda` (Visual Studio 17 2022, x64, Release, GGML_CUDA=ON, GGML_NATIVE=OFF).
- Head commit: `02db7a768`. Build exit 0.

## 2. Diff-vs-plan conformance

| Step | Plan snippet (location) | Diff hunk | Status | Evidence |
| --- | --- | --- | --- | --- |
| 1 - chunked-decode bound (plan `:3750`) | `std::min({n_batch, batch.n_tokens - i, (int32_t) params_base.n_outputs_max})` plus bounded `SRV_DBG` line (plan L28-L36) | `@@ -3747,5 +3755,9 @@` adds `std::min({...})` initializer-list with identical 3 args; new `SRV_DBG("...chunk=%d n_tokens=%d cap=%d\n", ...)` at +3771 (second hunk `@@ -3759,4 +3771,7 @@`) | Match with F-21-01 correction (`cap=%d`, not `cap=%u`) | Diff hunks 3a and 3b |
| 2 - draft MTP cap-bump (plan `:1175`) | `if (spec_mtp) { params_dft.n_outputs_max = std::min<uint64_t>(params_base.n_batch, params_base.n_parallel * (1 + common_speculative_n_max(&params_base.speculative))); } else { params_dft.n_outputs_max = params_base.n_parallel; }` (plan L42-L49) | `@@ -1173,5 +1173,11 @@` adds two-branch `if (spec_mtp) { ... } else { ... }` with the same formula | Match with F-21-02 correction (`std::min<uint32_t>` + `static_cast<uint32_t>(...)` on both args) | Diff hunk 1 |
| 3 - MTP cparams cap-bump (plan `:1308`) | `cparams_mtp.n_outputs_max = std::min<uint64_t>(params_base.n_batch, params_base.n_parallel * (1 + common_speculative_n_max(&params_base.speculative)));` (plan L57-L59) | `@@ -1306,5 +1312,7 @@` adds the symmetric formula to `cparams_mtp.n_outputs_max` | Match with F-21-02 correction | Diff hunk 2 |

All three steps match the plan with the three F-21 corrections applied exactly as the plan review specified. The `min(n_batch, ...)` clamp is present in both cap-bump formulas. The bounded `SRV_DBG` line sits in the chunked-decode loop above the `llama_decode(ctx_tgt, batch_view)` call. `params_dft.n_outputs_max` and `cparams_mtp.n_outputs_max` are both `uint32_t` (assigned via `common_context_params_to_llama()` which produces `llama_context_params`; field at include/llama.h:342), so `std::min<uint32_t>` matches the LHS type without implicit narrowing.

## 3. F-21 verification

| ID | Addressed | Location | Evidence |
| --- | --- | --- | --- |
| F-21-01 | Yes | `tools/server/server-context.cpp:3771` (new `SRV_DBG` line, 3rd format spec) | `cap=%d` (was `cap=%u` in plan snippet). `params_base.n_outputs_max` is `int32_t` (common/common.h:441); `%d` matches. The redundant `(int32_t)` cast on the arg is harmless. |
| F-21-02 | Yes | `tools/server/server-context.cpp:1175` and `:1308` | Both call sites use `std::min<uint32_t>(static_cast<uint32_t>(params_base.n_batch), static_cast<uint32_t>(params_base.n_parallel * (1 + common_speculative_n_max(&params_base.speculative))))`. Target field is `uint32_t` (llama.h:342); explicit casts suppress `/W4` implicit-narrowing warnings and match the plan review's F-21-02 recommendation. NB: cast style at upstream `server_n_outputs_max` (:204) uses C-style `(uint64_t) params.n_parallel`; the cap-bump uses `static_cast<uint32_t>`. Different style, but F-21-02 explicitly recommended `static_cast`. Non-blocker style note only. |
| F-21-03 | Yes | Plan Section 6 risk row + implementation log Section 3 | Architecture `part-07` per-context vs per-sequence wording drift is recorded as a separate Architect follow-up correction (F-09-05 in the plan), not a code change in this gate. Implementation log Section 3 row F-21-03 documents the disposition. |

## 4. F-09 verification

| ID | Addressed | Evidence |
| --- | --- | --- |
| F-09-01 | Yes | `min(n_batch, ...)` clamp present at both :1175 and :1308. The first argument to `std::min<uint32_t>` is `static_cast<uint32_t>(params_base.n_batch)` in both formulas. |
| F-09-02 | Yes (with note) | Implementation log Section 2 presents Step 1, Step 2, Step 3 in plan order. The actual `git diff` hunk order is by file-line number (:1175, :1308, :3750), which is normal git behavior. F-09-02's logical ordering constraint (chunked-decode bound in place before the cap-bump formulas matter) is satisfied: all three changes land in the same commit and the chunked-decode bound at :3750 is independent of the cap-bump formulas at :1175/:1308. |
| F-09-03 | Yes | Step 1 uses `params_base.n_outputs_max` (per-context cap). The chunked loop at :3750 chunks the whole target batch, not per-sequence, so the per-context cap is the correct bound. The per-sequence share (`cparams.n_outputs_max / n_parallel`) is implicit, consistent with the plan's Section 6 "Starvation for `n_parallel > 1`" risk row. |
| F-09-04 | Yes | Implementation log Section 4 records the plan review's verification of H53/H54/H57 in `cache-handling-test-plan/part-03-integration-test-matrix.md` (lines 137, 138, 141). The plan review (F-09-04) confirmed those rows do not pin `cparams_mtp.n_outputs_max == n_parallel`, so the test plan follow-up is moot. Test plan is not edited in this gate. T-NOUT-MAX-01 and T-NOUT-MAX-02 remain plan-only proposals. |

## 5. Build evidence

- Build command: `cmake --build build-cuda --config Release -j --target llama-server`.
- Exit code: 0.
- `server-context.cpp` recompiled (incremental); `llama-server.exe` relinked.
- Warnings: `LINK : warning LNK4098: defaultlib 'LIBCMT' conflicts with use of other libs; use /NODEFAULTLIB:library` is pre-existing (linker-level libcmt defaultlib conflict, not a code-level warning). Not introduced by this diff. No new warnings from `server-context.cpp` itself.
- `git diff --check -- tools/server/server-context.cpp` exit code: 0.

## 6. Out-of-scope check

- Code change: single file (`tools/server/server-context.cpp`, 18 insertions / 3 deletions). Verified with `git diff --stat` and `git diff` (only this file appears).
- New durable doc: `part-22-stage11-mtp-cap-fix-implementation.md` (staged addition, expected).
- Pre-approved plan: `part-20-stage11-mtp-cap-fix-implementation-plan.md` (staged addition, expected; PASS in plan review).
- `git status --short` also shows pre-existing modifications to `._design_docs/cache-handling-architecture.md`, `._design_docs/cache-handling-phase11-design.md`, `.agents/skills/self-improvement/assets/{architect,developer}.md`, `.codex/agents/manager.toml`, `.github/agents/{architect,manager}.agent.md`, and `AGENTS.md`. These are not touched by this implementation and are out of scope for this review.
- No edits to design (part-08), architecture (part-07), plan body (part-20), plan review (part-21), investigation (part-19), or test plan.
- Implementation log's "Single-file change" claim is accurate for the code diff.

## 7. Manager handoff

Submitting to Manager. Owner: Manager. Next gate: Test planning (QA) or Developer correction.
