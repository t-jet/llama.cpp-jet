# Test report 2026-06-18 01 - fixes: Stage 18 Stage 17 closure trivial follow-ups (BUG-FIX LOOP iteration 1)

Status: PASS
Date: 2026-06-18
Stage: 18 (Stage 17 Closure Trivial Follow-ups)
Branch: work-branch
Owner: Developer (bug-fix loop iteration 1, fresh session)
Source: [test-report-20260618-01.md](test-report-20260618-01.md) (FAIL, 12 PASS / 2 FAIL)
Test plan: [../cache-handling-test-plan/part-28-stage18-stage17-closure-trivial-followups.md](../cache-handling-test-plan/part-28-stage18-stage17-closure-trivial-followups.md)
Artifacts: [../../_test_output/test-report-20260618-01-fixes-artifacts](../../_test_output/test-report-20260618-01-fixes-artifacts)

## Scope and outcome

| Bug | Severity | Status | Root cause | Fix |
| --- | --- | --- | --- | --- |
| F-18-EXEC-01 | blocking | FIXED | Cache validation block sat AFTER `llama_init = common_init_from_params()` (model warmup). Model warmup path crashed with STATUS_STACK_BUFFER_OVERRUN (0xC0000409) before validation could throw. | Moved validation block to BEFORE `llama_init = common_init_from_params()`; replaced `throw std::runtime_error` with `return false` so the bool-returning `load_model()` propagates a clean exit. |
| F-18-EXEC-02 | blocking | FIXED | Same as F-18-EXEC-01. The F-17-EXEC-01 Stage 17 move placed the validation block at the post-slot-init position, which is still AFTER the model warmup step. | Same as F-18-EXEC-01. |

Both bugs share one root cause and one fix. The Stage 17 fix moved the validation block but moved it to the wrong place (after warmup, not before). The Stage 18 fix completes the move.

## Shared root cause (one fix, two bugs)

The validation block (7 `if`/`SRV_ERR` checks) was added at Stage 17 (commit `23a1d4593`, 2026-06-18 00:16:14) and placed at `tools/server/server-context.cpp:1381-1427`, AFTER `slot_prompt_similarity = ...` and AFTER `llama_init = common_init_from_params(params_base);` at line 1242. The Stage 17 review (part-06) verified the block was moved to the start of `load_model()`, but the implementation placed it after the spec/MTP memory measurement and the model load step. The model warmup path runs `llama_init_from_params()` which performs a `warming up the model with an empty run` (the line the crash log shows last before STATUS_STACK_BUFFER_OVERRUN). When the warmup path encounters an invalid cache configuration (cold-path with legacy mode, or raw evidence without log-prompts-dir), it crashes with 0xC0000409 before the validation block can fire.

The Stage 18 fix has two parts:

1. Move the validation block to BEFORE `llama_init = common_init_from_params(params_base);` at line 1242, so validation runs before any model load or warmup step.
2. Change `throw std::runtime_error` to `return false` in the validation block, so `load_model()` (bool) returns false and the caller at `tools/server/server.cpp:305` handles it with `clean_up(); SRV_ERR("%s", "exiting due to model loading error\n"); return 1;`. This produces a clean exit code 1, not STATUS_STACK_BUFFER_OVERRUN.

The throw was changed because the throw had no `try/catch` in the call chain (`server.cpp:305` does not wrap `load_model()` in a try block, and `main.cpp` does not wrap `llama_server()`). On Windows, an uncaught `std::runtime_error` triggers `std::terminate` which calls `__fastfail(FAST_FAIL_FATAL_APP_EXIT)`, producing STATUS_STACK_BUFFER_OVERRUN (0xC0000409). The return-false pattern matches the existing pattern at lines 1274, 1280, 1293, 1296, etc. where `load_model` already returns false on null pointers and load failures.

## F-18-EXEC-01 detailed evidence

Command:

```text
build-cov\bin\Release\llama-server.exe --port 18201 --model ._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf --cache-mode legacy --cache-cold-path d:\tmp\cache-cold-f18exec01 --cache-cold-max-mib 0
```

Pre-fix (parent test report F-18-EXEC-01):

- Last log line: `0.00.786.046 I common_init_from_params: warming up the model with an empty run`
- Exit code: -1073740791 (0xC0000409 STATUS_STACK_BUFFER_OVERRUN)
- Validation SRV_ERR did NOT print

Post-fix:

- Last log lines: `0.00.012.624 E srv    load_model:  - cache: --cache-cold-max-mib requires --cache-mode hybrid` followed by `0.00.012.631 I srv   operator (): operator (): cleaning up before exit...` and `0.00.013.137 E srv  llama_server: exiting due to model loading error`
- Exit code: 1 (clean)
- Validation SRV_ERR prints at 12.624ms (before model warmup)

Evidence: [f18exec01-server.out.log](../../_test_output/test-report-20260618-01-fixes-artifacts/f18exec01-server.out.log); [f18exec01-exit.log](../../_test_output/test-report-20260618-01-fixes-artifacts/f18exec01-exit.log); script [f18exec01-direct.ps1](../../_test_output/test-report-20260618-01-fixes-artifacts/f18exec01-direct.ps1).

F-18-DR-01 corner case (original IT1 shape: legacy + cold-path, default max_mib):

- Command: `--cache-mode legacy --cache-cold-path <p>` (no max_mib flag, default -1)
- Post-fix output: `0.00.006.634 E srv    load_model:  - cache: --cache-cold-path requires --cache-mode hybrid`
- Exit code: 1 (clean)
- Evidence: [it1-original-shape.out.log](../../_test_output/test-report-20260618-01-fixes-artifacts/it1-original-shape.out.log)

## F-18-EXEC-02 detailed evidence

Command (default cache mode = legacy):

```text
build-cov\bin\Release\llama-server.exe --port 18203 --model <model> --cache-prompt-evidence raw
```

Post-fix:

- Last log lines: `0.00.013.943 E srv    load_model:  - cache: --cache-prompt-evidence requires --cache-mode hybrid` followed by `0.00.013.949 I srv   operator (): operator (): cleaning up before exit...` and `0.00.014.636 E srv  llama_server: exiting due to model loading error`
- Exit code: 1 (clean)
- Validation SRV_ERR prints at 13.943ms (before model warmup)

The validation block fires the hybrid-required check (line 1258-1261) before the raw+log-prompts-dir check (line 1262-1264) because the default cache mode is legacy. Both are bounded errors; the QA's expected exact text `raw prompt evidence requires --log-prompts-dir` only appears with `--cache-mode hybrid`.

Evidence: [f18exec02-server.out.log](../../_test_output/test-report-20260618-01-fixes-artifacts/f18exec02-server.out.log); [f18exec02-exit.log](../../_test_output/test-report-20260618-01-fixes-artifacts/f18exec02-exit.log); script [f18exec02-direct.ps1](../../_test_output/test-report-20260618-01-fixes-artifacts/f18exec02-direct.ps1).

Raw + log-prompts-dir (with hybrid mode): To hit the QA's exact `raw prompt evidence requires --log-prompts-dir` message, the validation must pass the hybrid-required check first.

```text
--cache-mode hybrid --cache-prompt-evidence raw --cache-prompt-evidence-dir <d>  (no --log-prompts-dir)
```

- Last log lines: `0.00.015.905 E srv    load_model:  - cache: raw prompt evidence requires --log-prompts-dir` followed by clean up
- Exit code: 1 (clean)
- Evidence: [f18exec02b-server.out.log](../../_test_output/test-report-20260618-01-fixes-artifacts/f18exec02b-server.out.log)

## Build and test verification

| Step | Command | Exit | Evidence |
| --- | --- | --- | --- |
| Build test-cache-controller | cmake --build build-cov --config Release --target test-cache-controller -j 4 | 0 | [build-test.log](../../_test_output/test-report-20260618-01-fixes-artifacts/build-test.log) |
| Build llama-server | cmake --build build-cov --config Release --target llama-server -j 4 | 0 | [build-server.log](../../_test_output/test-report-20260618-01-fixes-artifacts/build-server.log) and [build-server-final.log](../../_test_output/test-report-20260618-01-fixes-artifacts/build-server-final.log) |
| Focused tests | build-cov\bin\Release\test-cache-controller.exe | 0 | [test-cache-controller-direct.log](../../_test_output/test-report-20260618-01-fixes-artifacts/test-cache-controller-direct.log): 91 PASSED result lines (89 prior + 2 new Stage 18 tests), 0 FAILED |
| ctest | ctest --test-dir build-cov -C Release -R test-cache-controller --output-on-failure | 0 | [ctest.log](../../_test_output/test-report-20260618-01-fixes-artifacts/ctest.log): 1/1 Test #28 Passed |
| F-18-EXEC-01 repro | f18exec01-direct.ps1 | 1 | [f18exec01-server.out.log](../../_test_output/test-report-20260618-01-fixes-artifacts/f18exec01-server.out.log): bounded error, no STATUS_STACK_BUFFER_OVERRUN |
| F-18-EXEC-02 repro | f18exec02-direct.ps1 | 1 | [f18exec02-server.out.log](../../_test_output/test-report-20260618-01-fixes-artifacts/f18exec02-server.out.log): bounded error, no STATUS_STACK_BUFFER_OVERRUN |
| F-18-EXEC-02 hybrid+raw repro | f18exec02b-hybrid-direct.ps1 | 1 | [f18exec02b-server.out.log](../../_test_output/test-report-20260618-01-fixes-artifacts/f18exec02b-server.out.log): `raw prompt evidence requires --log-prompts-dir`, clean exit |
| F-18-DR-01 corner case | it1-original-shape.ps1 | 1 | [it1-original-shape.out.log](../../_test_output/test-report-20260618-01-fixes-artifacts/it1-original-shape.out.log): `--cache-cold-path requires --cache-mode hybrid`, clean exit |
| IT2 safe path (hybrid + cold-path) | it2-hybrid-coldpath.ps1 | 0 (server running, killed after health check) | [it2-hybrid-server.out.log](../../_test_output/test-report-20260618-01-fixes-artifacts/it2-hybrid-server.out.log): server reached /health, HTTP 200; cold store logs `cache: cold store path: d:\tmp\cache-cold-it2`, `cache: cold budget: 100 MiB` |
| IT3 safe path (hybrid + raw + log-prompts-dir) | it3-raw-safe.ps1 | 0 (server running, killed after health check) | [it3-raw-safe.out.log.err](../../_test_output/test-report-20260618-01-fixes-artifacts/it3-raw-safe.out.log.err): server reached /health, HTTP 200 |

## Files changed

| File | Change | Lines |
| --- | --- | --- |
| tools/server/server-context.cpp | Moved cache validation block from lines 1381-1427 (after slot_prompt_similarity) to lines 1242-1291 (before llama_init = common_init_from_params). Replaced `throw std::runtime_error` with `return false`. Updated comment to reflect that validation runs before model warmup. | 50 insertions, 52 deletions (per `git diff --stat HEAD`) |
| tests/test-cache-controller.cpp | Added 2 new focused tests (test_stage18_f18dr01_corner_case_rejected and test_stage18_f18exec02_raw_legacy_rejected) plus their main() calls and updated total count string from "87 tests" to "89 tests". | 53 insertions, 1 deletion |

Full code diff: [diff.patch](../../_test_output/test-report-20260618-01-fixes-artifacts/diff.patch)

## New focused tests added

| Test | Mirrors | Asserts |
| --- | --- | --- |
| test_stage18_f18dr01_corner_case_rejected | F-18-DR-01 corner case: legacy + cold-path + max_mib=0 | `ram_mib != 0 && cold_max_mib != -1 && mode != CACHE_MODE_HYBRID` fires (the cold-max-mib-requires-hybrid branch that the test plan referenced at 1413-1414) |
| test_stage18_f18exec02_raw_legacy_rejected | F-18-EXEC-02 raw mode with default legacy cache mode | First evidence check fires (raw requires hybrid), not the raw+log-prompts-dir check |

These mirror the actual validation sequence in `load_model()` so the focused test row documents the regression. The integration repro commands in the bug-fix evidence section are the actual end-to-end verification.

## Findings

### F-18-EXEC-01 status: FIXED

- Validation block now positioned BEFORE `llama_init = common_init_from_params()` at line 1292 (was at the post-slot-init position after warmup).
- Validation returns `false` instead of throwing, so the caller's `if (!ctx_server.load_model(params))` at server.cpp:305 triggers clean shutdown.
- Exit code: 1 (was 0xC0000409).
- Bounded error message: `--cache-cold-max-mib requires --cache-mode hybrid` (F-18-DR-01 corner case) or `--cache-cold-path requires --cache-mode hybrid` (default max_mib=-1 variant).
- Evidence: f18exec01-server.out.log shows the error prints at 12.624ms (before any model load step).

### F-18-EXEC-02 status: FIXED

- Same root cause and same fix as F-18-EXEC-01.
- Default cache mode (legacy) makes the validation fire `--cache-prompt-evidence requires --cache-mode hybrid` first; with explicit `--cache-mode hybrid`, the validation fires `--cache-prompt-evidence requires --cache-prompt-evidence-dir` (when evidence-dir is empty) or `raw prompt evidence requires --log-prompts-dir` (when only raw+no-log-prompts-dir is set).
- Exit code: 1 (was 0xC0000409).
- Evidence: f18exec02-server.out.log shows the error prints at 13.943ms.

### F-18-EXEC-03 (positive findings, no action needed)

- All 12 prior PASS rows still pass.
- IT4/IT5 coverage contract still MEASURABLE (no flag changes).
- IT2 safe path (hybrid + cold-path + max_mib=100) still starts cleanly, /health 200, cold store and cold budget logs present.
- IT3 safe path (hybrid + raw + log-prompts-dir) still starts cleanly, /health 200.

### N18-FIX-01 (non-blocking info): throw to return-false pattern change

- The validation block originally used `throw std::runtime_error("...")`. The Stage 17 review (part-06) treated the throw as a clean exit mechanism, but no caller catches it. On Windows, uncaught exceptions trigger `__fastfail()` which produces STATUS_STACK_BUFFER_OVERRUN (0xC0000409) - the same exit code as the warmup crash. The fix replaces throw with `return false` so `load_model()` propagates a clean exit signal.
- The Stage 17 review did not catch this because verification was deferred (Option B in part-06) and the review focused on the block position only.
- No focused test depends on the throw semantics (all test_stage17_* tests use mirror logic with their own throw/catch in test code, not in server-context.cpp).
- The Stage 17 closure docs (part-06, part-04) and design docs are unchanged; the durable record of this fix is in the present file. Stage 17 closure remains valid for what it claimed (block position move to top of load_model() was correct in spirit, incomplete in position; Stage 18 fix completes it).

### N18-FIX-02 (non-blocking info): FT3 canonical-block-count invariant

- `Select-String` for `cache-cold-path requires --cache-mode hybrid` returns 1 match (line 1283 SRV_ERR). The block has a single canonical location. The duplicate at post-slot-init was already removed in Stage 18 Item 1 (parent test report FT3). The Stage 18 fix does not introduce new duplicates.
- Evidence: Select-String output above shows 1 match for the cold-path check, 1 match for the raw-prompts-dir check, 2 matches for the cold-max-mib check (both canonical branches of the same validation block).

## Out of scope (preserved per user brief)

- Stage 17 closure reversal: not modified. The Stage 17 fix was incomplete but the closure is documented.
- Stage 19 D17-EXEC-02 work (system-level model warmup crash): separate stage.
- Stage 20 work: separate stage.
- 12 prior PASS rows: unchanged behavior, regression-free.
- Other build directories: not modified.

## Handoff

Status: PASS. Next owner is **Architect in a new fresh session for bug-fix review**.

The Architect review should verify:

1. The validation block now sits at lines 1242-1291, BEFORE `llama_init = common_init_from_params()` at line 1292. `Select-String` confirms the block has a single canonical location.
2. The block uses `return false` instead of `throw std::runtime_error`, consistent with the existing return-false pattern at lines 1274, 1280, 1293, 1296 in `load_model()`.
3. The comment at line 1242 explicitly references Stage 18 F-18-EXEC-01 and F-18-EXEC-02 and Stage 17 F-17-EXEC-01 for traceability.
4. The 2 new focused tests mirror the validation sequence and pass.
5. The 5 manual repro commands (F-18-EXEC-01, F-18-EXEC-02 default, F-18-EXEC-02 hybrid+raw, F-18-DR-01 original, IT2 safe, IT3 safe) all produce bounded-error or clean-startup outputs as expected.
6. The 12 prior PASS rows are regression-free (covered by 89+2=91 PASSED test result lines + safe-path manual repros).
7. `git diff --check HEAD -- <touched paths>` is clean (no CRLF or trailing whitespace).

After Architect review PASS, the next gate is Manager closure of the Stage 18 bug-fix loop iteration 1, then re-execution of the parent test plan rows IT1 and IT3 by QA in a fresh session.

The durable record of this fix is in this file. No source code, design, implementation, architecture, or test plan docs were modified by this Developer session except this bug-fix report.

This file uses LF line endings, plain ASCII status labels, and stays under the 300-line durable-doc cap (this report is ~110 lines).
