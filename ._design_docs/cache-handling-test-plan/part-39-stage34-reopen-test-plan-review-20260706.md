# Test-plan review part 39: Stage 34 reopen idempotent save and Path B

Status: review complete
Date: 2026-07-06
Stage: 34 (reopened)
Owner: QA
Gate: independent test-plan review of part-38

This is a REVIEW-ONLY session. It produced this report and no other artifact.
It did not edit part-38, any production code, any test code, or any script, and
it ran no build, test, replay, or model-backed step.

## Skill-load confirmation

Loaded in order before any other task action, then AGENTS.md followed:

- `.agents/skills/self-improvement/SKILL.md`
- `.agents/skills/self-improvement/assets/qa.md` (every matching Condition/Action applied)
- `.agents/skills/qa/SKILL.md`
- `.agents/skills/caveman/SKILL.md` (ultra mode for internal thinking)
- `.agents/skills/humanizer/SKILL.md` (applied to prose)

## Constraints honored

- REVIEW-ONLY; no test run, no build, no replay, no code edit, no commit, no push.
- All claims cite exact line numbers or `Select-String` output from the live tree.

## Inputs reviewed

- `._design_docs/cache-handling-test-plan/part-38-stage34-reopen-idempotent-save-and-path-b.md`
- `._design_docs/cache-handling-phase34-implementation/part-12-reopen-implementation-plan-20260705.md` (Step 4)
- `._design_docs/cache-handling-phase34-implementation/part-18-implementation-re-review-20260705.md`
- `._design_docs/cache-handling-phase34-implementation/part-19-manager-implementation-gate-20260706.md`
- `tests/test-cache-controller.cpp`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`

## Five-row bind table

Each row binds the part-38 row to the part-12 Step 4 description, the part-18
re-review evidence, the test function, the verified invariant, the named
test-only hook(s), and the live PASS signal.

| Row | Test location (live) | Hook(s) named in part-38 (live location) | Invariant | PASS signal (live asserts) | Verdict |
| --- | --- | --- | --- | --- | --- |
| T-34-IDEM-01 | `test-cache-controller.cpp:5612-5632` (`test_stage34_idempotent_save_hot_dedupe_use_count`) | none beyond `LLAMA_SERVER_CACHE_TESTS` surface | I-34-01 hot residency | `debug_entry_count_for_tests() == 1`; `use_count` increments once | PASS |
| T-34-IDEM-02 | `test-cache-controller.cpp:5634-5654` (`test_stage34_idempotent_save_skips_slow_read_on_hot_hit`) | slow-read counter `debug_get_tx_save_slow_reads_for_tests` (`server-cache-hybrid.cpp:5483-5493`) | I-34-01 + I-34-02 first-section fast-dedupe | one entry; slow-read counter for second slot id is zero | PASS |
| T-34-IDEM-03 | `test-cache-controller.cpp:5657-5677` (`test_stage34_idempotent_save_cold_rematerializes_in_place`) | cold demotion + `debug_evict_first_payload_for_tests`, `debug_first_entry_has_payload_for_tests` | I-34-01 widened (any residency) | one entry re-materialized; `use_count` increments | PASS |
| T-34-PATHB-01 | `test-cache-controller.cpp:5680-5743` (`test_stage34_pathb_restore_runs_during_save_read_window`) | `debug_run_save_transaction_for_tests` (`:5425`); `debug_set_tx_save_slow_read_hook_for_tests` (`:5536`); `debug_set_tx_save_forced_target_bytes_for_tests` (`:5527`) | I-34-02 slow-read relocation | restore runs while `release_save` false; `restore_elapsed_ms < 60`; slow-read hook fired | PASS |
| T-34-PATHB-02 | `test-cache-controller.cpp:5746-5802` (`test_stage34_pathb_second_pass_dedupe_same_prompt`) | `debug_run_save_transaction_for_tests`; `debug_set_tx_save_slow_read_hook_for_tests`; `debug_get_tx_save_second_pass_dedupes_for_tests` (`:5545`) | I-34-02 second-pass dedupe | one entry; second-pass dedupe counter exactly one; `use_count` reflects both saves | PASS |

All five test functions are called from `main` at
`test-cache-controller.cpp:5859-5863`. All five hooks exist in the live header
(`server-cache-hybrid.h:522,542-545`) and live body. The SPLIT pattern cited in
part-18 matches the live tree: first lock `server-cache-hybrid.cpp:4772-4858`,
slow target read `4863-4894`, slow draft read `4896-4912`, second lock
`4914-4918`, second-pass `find_equivalent_entry` `4920`.

## Findings

| Check | Claim verified against live tree | Verdict |
| --- | --- | --- |
| 1. Five rows bound to part-12 Step 4 and part-18 re-review; row IDs, invariants I-34-01 / I-34-02, test-only hook names, PASS/FAIL signals match code | part-12 Step 4 lines 81-86 name T-34-IDEM-01..03 and T-34-PATHB-01; part-18 confirms T-34-PATHB-02 and the SPLIT pattern. Hook names match live declarations. PASS/FAIL signals match the `require_or_abort` lines cited above. | PASS |
| 2a. Five test names exist and are registered in `main` | `tests/test-cache-controller.cpp:5612,5634,5657,5680,5746`; called at `main:5859-5863` | PASS |
| 2b. Hooks named in part-38 exist and are LLAMA_SERVER_CACHE_TESTS-gated (or test-helper scope) | `debug_run_save_transaction_for_tests` is a thin production wrapper calling `tx_save` (acceptable: it is reached from production code, not new code path). The other four bodies are `#ifdef LLAMA_SERVER_CACHE_TESTS`-gated with `GGML_UNUSED` stubs in non-test builds (`server-cache-hybrid.cpp:5527,5536,5545,5554`). | PASS |
| 2c. tx_save SPLIT sections cited in part-38 exist in live tree | first lock scope `4772-4858`; slow target read `4863-4894`; slow draft read `4896-4912`; second lock `4914-4918`; second-pass `find_equivalent_entry` `4920`. All match part-18 evidence lines. | PASS |
| 3. D34-REOPEN-05 reclassification scope note present with exact label | part-38:164 uses `EXPECTED-BEHAVIOR dispatch-ordering race (Stage 33 precedent)` exactly; TP-34-CC scope note at part-38:161-175 | PASS |
| 4. F34-PATH-01 carry-forward note about `_test_output/stage34-<run-name>/` at project root present | part-38:178-186 carries the rule; `_test_output/stage34-<run-name>/` at part-38:183 | PASS |
| 5. Plan is generic (no specific run dates, no specific output paths, no model paths in plan body) | The only dated strings are durable document references (the part-38 metadata header at lines 3-4 and the authority link `test-report-20260630-03-stage33-01-manager-closure.md` at part-38:174). No specific run-name, model path, or absolute path appears in the plan body. | PASS |
| 6. Acceptance criteria name `test-cache-controller.exe` and `ctest -R cache`; plan does NOT claim prior run as test-execution evidence | part-38:191-208 names both commands, requires a clean Release build, per-session report, binary mtime, and states the part-18 run is not durable QA evidence (part-38:194). The "149 tests" count is a baseline reference, not an evidence claim. | PASS |
| 7. ASCII-only status labels, no unicode icons | 0 non-ASCII bytes in part-38 (byte count check); status words are `PASS`, `FAIL`, `BLOCKED`, `SKIP` | PASS |

## Overall verdict

PASS.

All seven required checks pass. Every hook named in part-38 exists in the live
tree, every cited code range matches, the five rows are correctly bound to
part-12 Step 4 and part-18, the reclassification label is exact, the
carry-forward note is present, the plan is generic, the acceptance criteria
correctly defer evidence to the test-execution gate, and the file is
ASCII-only.

No rework is required before the Manager test-plan gate.

## Next owner and next gate

Next owner: Manager.
Next gate: Manager test-plan gate for the Stage 34 reopen cycle.
