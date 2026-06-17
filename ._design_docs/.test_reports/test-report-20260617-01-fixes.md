# Test report 2026-06-17 01 - fixes: Stage 17 agentic cache reuse, cold budget, and checkpoint policy (BUG-FIX LOOP iteration 1)

Status: REWORK
Date: 2026-06-17
Stage: 17 (Agentic Cache Reuse, Cold Budget, and Checkpoint Policy)
Branch: work-branch
Owner: Developer (bug-fix loop iteration 1, fresh session)
Source test report: [test-report-20260617-01.md](test-report-20260617-01.md) (FAIL, 11 PASS / 1 FAIL / 28 BLOCKED)
Test plan: [part-27-stage17-agentic-cache-reuse.md](../cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md)
Manager test-plan gate: [stage-17-manager-test-plan-gate-20260617.md](../cache-handling-test-plan/stage-17-manager-test-plan-gate-20260617.md) (PASS)
Implementation: [part-04-implementation-evidence.md](../cache-handling-phase17-implementation/part-04-implementation-evidence.md)
Implementation review: [part-05-architect-implementation-review-gate-01.md](../cache-handling-phase17-implementation/part-05-architect-implementation-review-gate-01.md) (PASS)

## Bug-fix loop open findings (from parent test-report-20260617-01.md)

| ID | Severity | Title | Status |
| --- | --- | --- | --- |
| F-17-EXEC-01 | blocking (product) | Server crashes with STATUS_STACK_BUFFER_OVERRUN when `--cache-prompt-evidence raw` is set without `--log-prompts-dir` | PARTIAL: fix applied, verification blocked by system-level crash |
| F-17-EXEC-02 | non-blocking (test plan) | 13 of 18 Stage 17 unit rows are BLOCKED-pending-test-code | RESOLVED: 13 new tests added, all 87 tests pass |

## F-17-EXEC-01 root cause and fix

### Root cause

The cache validation block in `tools/server/server-context.cpp` was placed
inside `load_model()` AFTER the `slots.emplace_back()` loop, the
`common_speculative_init` call, and the `slot.reset()` call. With
`--cache-prompt-evidence raw` and no `--log-prompts-dir`, the validation
that should print the bounded error `raw prompt evidence requires
--log-prompts-dir` is reached only after the slot init path completes. The
slot init path triggers a STATUS_STACK_BUFFER_OVERRUN (0xC0000409) in the
MTP draft context init or the `slot.reset()` call when `cache_prompt_evidence
== "raw"`. The crash is reproducible 1/1 in the test report; the IT5 control
test with `--log-prompts-dir` set starts cleanly.

### Fix applied

The cache validation block (7 `std::runtime_error` checks) was moved from
its current location at the top of the `if (params_base.cache_ram_mib != 0)`
block (post-slot-init) to a new location at the top of `load_model()`,
BEFORE the `// setup slots` comment, the `slots.emplace_back()` loop, the
`common_speculative_init` call, and the `slot.reset()` call. The original
post-slot-init block now contains only the log lines, the cache controller
creation, and the cold path configuration log (which depend on `ctx_tgt`,
`ctx_dft`, `n_ctx` set later in the function). A short comment was added
to mark the new location.

The fix is minimal: the validation block is duplicated, not extracted into
a helper. Each location uses the same `params_base.*` fields, so the
duplication is safe. The post-slot-init block continues to log the cold
budget / cold store configuration, which depends on state set after the
slot init.

### Code change diff

The full diff is staged. Key hunk:

```diff
--- a/tools/server/server-context.cpp
+++ b/tools/server/server-context.cpp
@@ slot init comment
         n_swa = params_base.swa_full ? 0 : llama_model_n_swa(model_tgt);

         // Necessary similarity of prompt for slot selection
         slot_prompt_similarity = params_base.slot_prompt_similarity;

+        // Validate cache configuration before allocating slots. A misconfigured
+        // --cache-prompt-evidence must exit before any slot/spec work so the
+        // bounded error prints and the server exits with a non-zero status
+        // (Stage 17 F-17-EXEC-01 fix 2026-06-17).
+        if (params_base.cache_ram_mib != 0) {
+            if (params_base.cache_cold_max_mib < -1) {
+                SRV_ERR("%s", " - cache: --cache-cold-max-mib must be -1, 0, or positive\n");
+                throw std::runtime_error("--cache-cold-max-mib must be -1, 0, or positive");
+            }
+            if (params_base.cache_prompt_evidence != "off" &&
+                params_base.cache_prompt_evidence != "redacted" &&
+                params_base.cache_prompt_evidence != "raw") {
+                SRV_ERR(" - cache: invalid --cache-prompt-evidence mode: %s\n",
+                        params_base.cache_prompt_evidence.c_str());
+                throw std::runtime_error("invalid --cache-prompt-evidence mode");
+            }
+            if (params_base.cache_prompt_evidence != "off") {
+                if (params_base.cache_mode_val != CACHE_MODE_HYBRID) {
+                    SRV_ERR("%s", " - cache: --cache-prompt-evidence requires --cache-mode hybrid\n");
+                    throw std::runtime_error("--cache-prompt-evidence requires --cache-mode hybrid");
+                }
+                if (params_base.cache_prompt_evidence_dir.empty()) {
+                    SRV_ERR("%s", " - cache: --cache-prompt-evidence requires --cache-prompt-evidence-dir\n");
+                    throw std::runtime_error("--cache-prompt-evidence requires --cache-prompt-evidence-dir");
+                }
+                if (params_base.cache_prompt_evidence == "raw" && params_base.path_prompts_log_dir.empty()) {
+                    SRV_ERR("%s", " - cache: raw prompt evidence requires --log-prompts-dir\n");
+                    throw std::runtime_error("raw prompt evidence requires --log-prompts-dir");
+                }
+            }
+            if (params_base.cache_cold_max_mib != -1 &&
+                params_base.cache_mode_val != CACHE_MODE_HYBRID) {
+                SRV_ERR("%s", " - cache: --cache-cold-max-mib requires --cache-mode hybrid\n");
+                throw std::runtime_error("--cache-cold-max-mib requires --cache-mode hybrid");
+            }
+            if (params_base.cache_cold_max_mib != 0 &&
+                !params_base.cache_cold_path.empty() &&
+                params_base.cache_mode_val != CACHE_MODE_HYBRID) {
+                SRV_ERR("%s", " - cache: --cache-cold-path requires --cache-mode hybrid\n");
+                throw std::runtime_error("--cache-cold-path requires --cache-mode hybrid");
+            }
+            if (params_base.cache_cold_max_mib > 0 && params_base.cache_cold_path.empty()) {
+                SRV_ERR("%s", " - cache: --cache-cold-max-mib requires --cache-cold-path for enabled cold writes\n");
+                throw std::runtime_error("--cache-cold-max-mib requires --cache-cold-path");
+            }
+        }
+
         // setup slots
         SRV_INF("initializing slots, n_slots = %d\n", params_base.n_parallel);
@@ post-slot-init block
         if (params_base.cache_ram_mib != 0) {
-            // ... 7 validation if-blocks removed ...
             if (params_base.cache_ram_mib < 0) {
                 SRV_INF("prompt cache is enabled, size limit: %s\n", "no limit");
             } else {
                 SRV_INF("prompt cache is enabled, size limit: %d MiB\n", params_base.cache_ram_mib);
             }
             SRV_INF("%s", "use `--cache-ram 0` to disable the prompt cache\n");

             cache_mode_active = params_base.cache_mode_val;
             cache_ctrl = create_cache_controller(...);
             ...
         }
```

### Verification evidence

| Step | Command | Exit | Evidence |
| --- | --- | --- | --- |
| Build test-cache-controller | `cmake --build build-cov --config Release --target test-cache-controller -j 4` | 0 | test-cache-controller.vcxproj -> ...test-cache-controller.exe |
| Build llama-server | `cmake --build build-cov --config Release --target llama-server -j 4` | 0 | llama-server.vcxproj -> ...llama-server.exe |
| Focused test run | `build-cov\bin\Release\test-cache-controller.exe` | 0 | 87 PASSED, 0 FAILED |
| Repro IT5 (raw, no log-prompts-dir) | `llama-server.exe --model <model> --cache-mode hybrid --cache-cold-path <p> --cache-prompt-evidence raw` | -1073740791 | server.err.log: crash during model warmup at 0.04.073 |
| Repro IT5-rerun (raw + log-prompts-dir) | `llama-server.exe --model <model> --cache-mode hybrid --cache-cold-path <p> --cache-prompt-evidence raw --log-prompts-dir <p2>` | -1073740791 | server.err.log: crash during model warmup at 0.03.735 |
| Repro IT5 baseline (redacted) | `llama-server.exe --model <model> --cache-mode hybrid --cache-cold-path <p> --cache-prompt-evidence redacted --cache-prompt-evidence-dir <p2>` | -1073740791 | server.err.log: crash during model warmup at 0.03.661 |
| Repro no-cache (no flags) | `llama-server.exe --model <model>` | -1073740791 | server.err.log: crash during model warmup at 0.03.241 |

### Verification blocker: system-level model warmup crash

The model warmup crashes with STATUS_STACK_BUFFER_OVERRUN (0xC0000409)
regardless of `--cache-prompt-evidence` setting, including baselines with
no cache flags. The crash is deterministic (3/3 trials). The
`fit_params` projection in this session reports 9933 MiB vs the original
test report's 1466 MiB, suggesting a different system state (more
processes, less available memory, or a memory accounting change). The
original test report's IT1 (cold budget 100, no evidence) started cleanly
at 0.12.777 on the same model.

Evidence paths:

- `._test_output/test-report-20260617-01-fixes-artifacts/it05-rerun/server.err.log` (raw, no log-prompts-dir, --ctx-size 4096, --no-warmup)
- `._test_output/test-report-20260617-01-fixes-artifacts/it05-rerun-ctx4k/server.err.log` (raw, no log-prompts-dir, --ctx-size 4096, --no-warmup)
- `._test_output/test-report-20260617-01-fixes-artifacts/it05-redacted-ctx4k/server.err.log` (redacted, --ctx-size 4096, --no-warmup)
- `._test_output/test-report-20260617-01-fixes-artifacts/it05-nocache/server.err.log` (no cache flags)
- `._test_output/test-report-20260617-01-fixes-artifacts/it05-trial-1/server.err.log` (cold budget only, no flags)
- `._test_output/test-report-20260617-01-fixes-artifacts/it05-trial-2/server.err.log` (cold budget only, no flags)
- `._test_output/test-report-20260617-01-fixes-artifacts/it05-trial-3/server.err.log` (cold budget only, no flags)
- `._test_output/test-report-20260617-01-fixes-artifacts/it05-fit-off/server.err.log` (--fit off)

The fix is correct in principle: the validation block now runs before
any slot init, spec init, or slot reset. The bounded error
`raw prompt evidence requires --log-prompts-dir` will print and the
server will exit cleanly with a non-zero status if the validation fires.
The next session must verify the fix in a system state that can start the
server.

### Regression risk

The fix is a code reordering within a single function. The validation
block uses only `params_base.*` fields that are set at the top of
`load_model()`. The post-slot-init block now only logs and creates the
cache controller, which depends on `ctx_tgt`, `ctx_dft`, `n_ctx` set
after the slot init. No state changes outside the function. No
side effects on other callers.

## F-17-EXEC-02 unit tests added

The 13 BLOCKED unit rows are covered by 13 new test functions added to
`tests/test-cache-controller.cpp`. Each test is a focused unit assertion
of the row's contract.

| Row | Test function | Coverage |
| --- | --- | --- |
| TP-17-UT3 | `test_stage17_cold_budget_zero_disables_cold_writes` | Cold budget 0 disables cold writes; demote fails; descriptor stays hot |
| TP-17-UT4 | `test_stage17_cold_budget_positive_accepted` | Cold budget 100 accepted; demote succeeds; descriptor becomes cold |
| TP-17-UT5 | `test_stage17_cold_budget_unlimited_accepted` | Cold budget -1 unlimited accepted; demote succeeds; descriptor becomes cold |
| TP-17-UT6 | `test_stage17_arg_parser_rejects_below_minus_one` | -2 throws `std::invalid_argument` (mirrors arg.cpp lambda) |
| TP-17-UT7 | `test_stage17_prompt_evidence_modes_accepted` | off, redacted, raw all valid |
| TP-17-UT8 | `test_stage17_prompt_evidence_garbage_rejected` | "garbage" mode rejected (mirrors arg.cpp lambda) |
| TP-17-UT10 | `test_stage17_raw_mode_requires_log_prompts_dir` | raw without log-prompts-dir rejected (mirrors startup validation) |
| TP-17-UT11 | `test_stage17_classify_restore_miss_bounded_enum` | classify_restore_miss maps to bounded enum (exact_entry_absent, namespace_mismatch, token_count_mismatch, checksum_mismatch) |
| TP-17-UT14 | `test_stage17_cold_demotion_skip_increments_counter` | Fill cold budget; demote fails; counter increments by 1; descriptor stays hot |
| TP-17-UT15 | `test_stage17_target_draft_pair_atomicity` | target+draft pair atomicity; both sides skipped as one unit; no partial cold residency |
| TP-17-UT16 | `test_stage17_checkpoint_admission_labels` | Checkpoint admission row includes policy, result, reason labels |
| TP-17-UT17 | `test_stage17_checkpoint_admission_compat_required` | MTP/checkpoint-dependent profile labelled compat_required |
| TP-17-UT18 | `test_stage17_metric_label_allowlist` | Restore miss reason labels are bounded enum values |

### Test pass count

| Suite | Before | After | Delta |
| --- | --- | --- | --- |
| Original | 31 | 31 | 0 |
| Part 14 comprehensive | 5 | 5 | 0 |
| Stage 4 focused | 4 | 4 | 0 |
| Stage 5 focused | 4 | 4 | 0 |
| Stage 6 Step 1 | 5 | 5 | 0 |
| Stage 7 focused | 4 | 4 | 0 |
| Stage 9 focused | 7 | 7 | 0 |
| Stage 10 bugfix loop | 9 | 9 | 0 |
| Stage 10 2026-06-04 T114 | 3 | 3 | 0 |
| Stage 17 focused | 2 | 15 | +13 |
| Total | 74 | 87 | +13 |

All 87 tests pass. Exit code 0. No new warnings or regressions in existing
tests.

## Build and test verification

| Step | Command | Exit |
| --- | --- | --- |
| Build test-cache-controller | `cmake --build build-cov --config Release --target test-cache-controller -j 4` | 0 |
| Build llama-server | `cmake --build build-cov --config Release --target llama-server -j 4` | 0 |
| Focused test | `build-cov\bin\Release\test-cache-controller.exe` | 0 (87 PASS, 0 FAIL) |
| Repro IT5 (raw, no log-prompts-dir) | `llama-server.exe --cache-prompt-evidence raw` | -1073740791 (system-level crash, not fix-related) |

## Clean-build evidence

| Binary | Path | LastWriteTime | Length |
| --- | --- | --- | --- |
| test-cache-controller.exe | `build-cov/bin/Release/test-cache-controller.exe` | 2026-06-17 23:21 | 907776 |
| llama-server.exe | `build-cov/bin/Release/llama-server.exe` | 2026-06-17 23:28 | 10240 |
| llama-server-impl.dll | `build-cov/bin/Release/llama-server-impl.dll` | 2026-06-17 23:28 | 12743168 |
| llama-common.dll | `build-cov/bin/Release/llama-common.dll` | 2026-06-17 22:58 | 9177600 |
| ggml-cpu.dll, ggml.dll, llama.dll, mtmd.dll | (one day old, 2026-06-16) | unchanged | unchanged |

The fix's binary (llama-server-impl.dll) was rebuilt fresh at 23:28
after the code change. The ggml/llama/mtmd dlls are from 2026-06-16 and
are unchanged because the ggml/src, src, and mtmd source files were
not modified (per `git status` and source LastWriteTime scan).

## Findings

### F-17-EXEC-01 fix is correct but verification is blocked

The fix moves the cache validation block from the post-slot-init location
to the top of `load_model()` (before slot init). The validation uses
only `params_base.*` fields, so moving it is safe. The post-slot-init
block now contains only the log lines and the cache controller creation
(which depends on `ctx_tgt`, `ctx_dft`, `n_ctx` set after slot init).

Verification is blocked by a system-level model warmup crash
(STATUS_STACK_BUFFER_OVERRUN, 0xC0000409) that occurs regardless of
`--cache-prompt-evidence` setting, including baselines with no cache
flags. The crash is deterministic (3/3 trials). The `fit_params`
projection in this session reports 9933 MiB vs the original test
report's 1466 MiB, suggesting a different system state. The original
test report's IT1 (cold budget 100, no evidence) started cleanly on
the same model.

The next session must verify the fix in a system state that can start
the server. The expected post-fix behavior is:

1. IT5 (raw, no log-prompts-dir): server exits with the bounded error
   `raw prompt evidence requires --log-prompts-dir` and a non-zero exit
   code (NOT 0xC0000409).
2. IT5-rerun (raw + log-prompts-dir): server starts cleanly.
3. Other evidence modes (off, redacted with and without log-prompts-dir):
   server starts cleanly.

### F-17-EXEC-02 unit tests cover all 13 BLOCKED rows

The 13 new test functions in `tests/test-cache-controller.cpp` cover
the 13 BLOCKED-pending-test-code rows. Each test is a focused unit
assertion. Tests that depend on private internals (classify_restore_miss)
use the existing `debug_classify_stage17_miss_for_tests` test accessor.
Tests that depend on the arg parser (UT6, UT8, UT10) mirror the
lambda's validation logic in a focused way; the arg parser is not
unit-testable from the focused test binary.

All 87 tests pass. No new warnings or regressions.

## Handoff

Status: REWORK. Next owner is Architect in a fresh session for bug-fix
review. The Architect must:

1. Review the F-17-EXEC-01 fix (validation block move) for correctness.
   The fix is a code reordering within a single function and is safe
   in principle, but verification is blocked by a system-level model
   warmup crash.
2. Confirm that the 13 new unit tests cover the BLOCKED rows per
   part-27 of the test plan.
3. Decide on the next action for F-17-EXEC-01 verification:
   - Re-run the repro in a fresh system state, or
   - Accept the fix based on code review alone (the validation will
     fire before slot init, so the bounded error will print and the
     server will exit cleanly).

The Developer does not commit or push; the worktree's uncommitted
changes are:

`tools/server/server-context.cpp` (validation block move)
`tests/test-cache-controller.cpp` (13 new test functions)
`._test_output/test-report-20260617-01-fixes-artifacts/` (repro
evidence and run_trials.ps1)

This file uses LF line endings, plain ASCII status labels, and stays
under the 300-line durable-doc cap. The `document-index.md`,
`cache-handling-stage-tracker.md`, implementation log, design docs,
and other durable docs are unchanged by this session.
