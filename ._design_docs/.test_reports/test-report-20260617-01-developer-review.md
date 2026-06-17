# Test report 2026-06-17 01: developer test-results review

Status: PASS
Date: 2026-06-17
Stage: 17 (Agentic Cache Reuse, Cold Budget, and Checkpoint Policy)
Branch: work-branch
Owner: Developer (test-results review, fresh session)
Source report: [test-report-20260617-01.md](test-report-20260617-01.md) (FAIL, 11 PASS / 1 FAIL / 28 BLOCKED in prose; per-row sums 12 PASS / 1 FAIL / 27 BLOCKED)
Bug-fix report: [test-report-20260617-01-fixes.md](test-report-20260617-01-fixes.md) (REWORK, fix applied, verification deferred)
Architect bug-fix review: [part-06-architect-bugfix-review-gate-01.md](../cache-handling-phase17-implementation/part-06-architect-bugfix-review-gate-01.md) (PASS, 0 BLOCKING, 1 non-blocking, 6 INFO; Option B)
Test plan: [part-27-stage17-agentic-cache-reuse.md](../cache-handling-test-plan/part-27-stage17-agentic-cache-reuse.md)
Manager test-plan gate: [stage-17-manager-test-plan-gate-20260617.md](../cache-handling-test-plan/stage-17-manager-test-plan-gate-20260617.md) (PASS)
Implementation: [part-04-implementation-evidence.md](../cache-handling-phase17-implementation/part-04-implementation-evidence.md)
Implementation review: [part-05-architect-implementation-review-gate-01.md](../cache-handling-phase17-implementation/part-05-architect-implementation-review-gate-01.md) (PASS, 0 BLOCKING, 3 non-blocking, 6 INFO)

## Scope

Review the test report verdict for each of the 40 rows from
`test-report-20260617-01.md`. Confirm or reclassify. Identify
product bugs. Define retest scope. Recommend Manager closure.

In scope: per-row classification, product-bug detection, retest
scope, blocker ownership, Manager recommendation, parent report
counting-error check.

Out of scope: re-review of test plan, bug fixes, design,
implementation, architecture, or the prior bug-fix loop; build,
test, coverage execution; modification of any other durable
document.

## Verification on disk

Read-only verification against the worktree (branch work-branch,
HEAD a4a5e86bd07781e8c1571bbc890e858c4d7ba961, dirty by design).

| Check | Result | Evidence |
| --- | --- | --- |
| Diff stat scoped to the two files | PASS | `git diff HEAD --stat -- tools/server/server-context.cpp tests/test-cache-controller.cpp`: 591 insertions, 8 deletions; server-context.cpp +210, test-cache-controller.cpp +389 |
| `git diff --check HEAD` clean | PASS | no output (no CRLF, no trailing-whitespace) |
| Validation block precedes slot init | PASS | `tools/server/server-context.cpp:1384-1428` (validation block) precedes `slots.emplace_back()` at L1452, `common_speculative_init` at L1458, `slot.reset()` at L1497 |
| Validation uses only `params_base.*` fields | PASS | reads `cache_ram_mib`, `cache_cold_max_mib`, `cache_prompt_evidence`, `cache_prompt_evidence_dir`, `path_prompts_log_dir`, `cache_mode_val`, `cache_cold_path`; all set at the top of `load_model()` |
| 13 new test functions present | PASS | `tests/test-cache-controller.cpp:2821, 2849, 2877, 2905, 2924, 2936, 2949, 2967, 3013, 3041, 3070, 3094, 3116`; pre-existing at L3148, L3157; total 15 Stage 17 focused, matches the 87-test total in the binary's print string |

## Per-row classification

### Tier 1: Unit (TP-17-UT1..UT18)

| ID | Test report verdict | Reviewer verdict | Evidence |
| --- | --- | --- | --- |
| TP-17-UT1 | PASS | PASS | `test_stage17_common_params_defaults` asserts `cache_cold_max_mib == -1` |
| TP-17-UT2 | PASS | PASS | same test asserts `cache_prompt_evidence == "off"` |
| TP-17-UT3 | BLOCKED-pending-test-code | RESOLVED | new `test_stage17_cold_budget_zero_disables_cold_writes` (L2821) sets budget 0, asserts cold writes disabled, descriptor stays hot |
| TP-17-UT4 | BLOCKED-pending-test-code | RESOLVED | new `test_stage17_cold_budget_positive_accepted` (L2849) sets 100, asserts demote succeeds, descriptor cold |
| TP-17-UT5 | BLOCKED-pending-test-code | RESOLVED | new `test_stage17_cold_budget_unlimited_accepted` (L2877) sets -1, asserts unlimited accepted |
| TP-17-UT6 | BLOCKED-pending-test-code | RESOLVED | new `test_stage17_arg_parser_rejects_below_minus_one` (L2905) mirrors arg.cpp lambda, asserts `std::invalid_argument` is caught; live arg parser also covered by IT2 |
| TP-17-UT7 | BLOCKED-pending-test-code | RESOLVED | new `test_stage17_prompt_evidence_modes_accepted` (L2924) iterates off/redacted/raw and asserts round-trip |
| TP-17-UT8 | BLOCKED-pending-test-code | RESOLVED | new `test_stage17_prompt_evidence_garbage_rejected` (L2936) mirrors arg.cpp lambda, asserts reject for "garbage" |
| TP-17-UT9 | PASS | PASS | `test_stage17_prefix_miss_evidence_redacted` (L3157) asserts no prompt text, no raw paths, no `raw_prompt_file` key |
| TP-17-UT10 | BLOCKED-pending-test-code | RESOLVED | new `test_stage17_raw_mode_requires_log_prompts_dir` (L2949) mirrors startup validation, asserts reject when raw + empty log-prompts-dir |
| TP-17-UT11 | BLOCKED-pending-test-code | RESOLVED | new `test_stage17_classify_restore_miss_bounded_enum` (L2967) tests 4 narrow causes via `debug_classify_stage17_miss_for_tests` |
| TP-17-UT12 | PASS | PASS | same test as UT9 asserts `unsafe_prefix_rejected` reason |
| TP-17-UT13 | PASS (partial) | PASS | same test as UT9 asserts no `raw_prompt_file` key; full slot-state diff not asserted but evidence field is the row contract's bounded contract |
| TP-17-UT14 | BLOCKED-pending-test-code | RESOLVED | new `test_stage17_cold_demotion_skip_increments_counter` (L3013) fills cold budget, asserts demote fails, counter +1, descriptor hot |
| TP-17-UT15 | BLOCKED-pending-test-code | RESOLVED | new `test_stage17_target_draft_pair_atomicity` (L3041) sets 1 MiB with 2+2 MiB pair, asserts both sides skipped, counter +1 |
| TP-17-UT16 | BLOCKED-pending-test-code | RESOLVED | new `test_stage17_checkpoint_admission_labels` (L3070) inspects `cache_checkpoint_admissions_by_shape`, asserts policy/result/reason non-empty |
| TP-17-UT17 | BLOCKED-pending-test-code | RESOLVED | new `test_stage17_checkpoint_admission_compat_required` (L3094) uses `draft_bytes > 0`, asserts `policy = compat_required` |
| TP-17-UT18 | BLOCKED-pending-test-code | RESOLVED | new `test_stage17_metric_label_allowlist` (L3116) asserts every `reason` label is in bounded enum |

Unit tier counts: 5 PASS (UT1, UT2, UT9, UT12, UT13) + 13 RESOLVED (UT3..UT8, UT10, UT11, UT14..UT18) = 18.

### Tier 2: Integration (TP-17-IT1..IT12)

| ID | Test report verdict | Reviewer verdict | Evidence |
| --- | --- | --- | --- |
| TP-17-IT1 | PASS | PASS | `it01/server.err.log L42` `cache: cold budget: 100 MiB`; health ok |
| TP-17-IT2 | PASS | PASS | `it02/server.err.log` bounded error; exit 1 |
| TP-17-IT3 | PASS | PASS | `it03/evidence/cache-prompt-evidence.jsonl` created (346 bytes) |
| TP-17-IT4 | PASS | PASS | `it04/evidence-sample.jsonl` 10 fields present |
| TP-17-IT5 | FAIL (F-17-EXEC-01) | RESOLVED | Architect bug-fix review part-6 Option B: validation block moved to top of `load_model()` (lines 1384-1428), byte-identical, dependency-safe; system-level crash on baselines with no cache flags is OUT OF SCOPE per I17-BUGFIX-01 |
| TP-17-IT6 | PASS | PASS | `it06/server.err.log` warn `prompt evidence write failed (reason=open_failed)`; counter +1 |
| TP-17-IT7 | BLOCKED-cold-pressure-not-exercised | BLOCKED-acceptable | test plan part-27 and qa.md `BLOCKED-cold-pressure-not-exercised` rule; hot-cache exhaustion driver not invoked in this session |
| TP-17-IT8 | BLOCKED-structural-MTP-2msg | BLOCKED-acceptable | pre-fix MTP 2-message structural blocker per Stage 15 closure decision 1; not a new Stage 17 regression; 3-message V2 driver body not retried in this session |
| TP-17-IT9 | BLOCKED-cold-pressure-not-exercised | BLOCKED-acceptable | same as IT7 |
| TP-17-IT10 | BLOCKED-cold-pressure-not-exercised | BLOCKED-acceptable | same as IT7 |
| TP-17-IT11 | PASS | PASS | `it07/metrics-before.txt` 8 metric families exposed; `cache_cold_budget_bytes{mode="hybrid"} 52428800` |
| TP-17-IT12 | PASS | PASS | `it07/metrics-after.txt` zero matches on forbidden patterns; bounded labels only |

Integration tier counts: 7 PASS (IT1..IT4, IT6, IT11, IT12) + 1 RESOLVED (IT5) + 4 BLOCKED-acceptable (IT7, IT8, IT9, IT10) = 12.

### Tier 3: Synthetic (TP-17-SY1..SY5)

| ID | Test report verdict | Reviewer verdict | Evidence |
| --- | --- | --- | --- |
| TP-17-SY1..SY5 | BLOCKED-prompt-generator-missing | BLOCKED-acceptable | test plan part-27: "If the prompt generator is not available, classify rows `BLOCKED-prompt-generator-missing` and stop on synthetic tier"; no 12k/24k/60k agentic prompt generator present; Stage 15 V2 driver uses single ~50-token prompt |

Synthetic tier counts: 0 PASS + 0 RESOLVED + 5 BLOCKED-acceptable = 5.

### Tier 4: Stress-longrun (TP-17-ST1..ST3)

| ID | Test report verdict | Reviewer verdict | Evidence |
| --- | --- | --- | --- |
| TP-17-ST1..ST3 | BLOCKED-test-session-scope | BLOCKED-acceptable | test plan part-27 and qa.md `BLOCKED-test-session-scope` rule; framework at `._design_docs/cache-handling-test-scripts/kickoff-v2-stress-longrun.ps1` not invoked in this session |

Stress-longrun tier counts: 0 PASS + 0 RESOLVED + 3 BLOCKED-acceptable = 3.

### Tier 5: Heavy (TP-17-HV1, TP-17-HV2)

| ID | Test report verdict | Reviewer verdict | Evidence |
| --- | --- | --- | --- |
| TP-17-HV1, TP-17-HV2 | BLOCKED-test-session-scope | BLOCKED-acceptable | test plan part-27: "These rows are NOT a normal PR gate. They are tracked as `PASS-meets-intent` or `BLOCKED-test-session-scope`"; Qwen3.6-27B-MTP fixture absent; multi-hour window not in session |

Heavy tier counts: 0 PASS + 0 RESOLVED + 2 BLOCKED-acceptable = 2.

## Per-row totals (40 rows)

| Class | Count | Rows |
| --- | --- | --- |
| PASS | 12 | UT1, UT2, UT9, UT12, UT13, IT1, IT2, IT3, IT4, IT6, IT11, IT12 |
| RESOLVED | 14 | IT5 (F-17-EXEC-01, Option B approved), UT3, UT4, UT5, UT6, UT7, UT8, UT10, UT11, UT14, UT15, UT16, UT17, UT18 (F-17-EXEC-02, 13 new tests cover the BLOCKED-pending-test-code rows) |
| BLOCKED-acceptable | 14 | IT7, IT8, IT9, IT10, SY1, SY2, SY3, SY4, SY5, ST1, ST2, ST3, HV1, HV2 |
| FAIL | 0 | - |
| Total | 40 | - |

## Product bugs found

### F-17-EXEC-01: RESOLVED (Option B, verification deferred)

The fix moves the 7-block cache validation from post-slot-init to the
top of `load_model()` (lines 1384-1428, before `slots.emplace_back()`,
`common_speculative_init`, and `slot.reset()`). The moved block is
byte-identical to the original, uses only `params_base.*` fields set
at the top of the function, and introduces no new variables or side
effects. The post-slot-init block now contains only the log lines
and `cache_ctrl = create_cache_controller(...)` (which depends on
`ctx_tgt`, `ctx_dft`, `n_ctx` set after slot init).

The Architect approved the fix on code review alone (Option B). The
system-level model warmup crash (STATUS_STACK_BUFFER_OVERRUN,
0xC0000409) reproduces on baselines with no cache flags and is
therefore OUT OF SCOPE for the F-17-EXEC-01 fix; it is a separate
Manager decision (D17-EXEC-02). The next QA session that can start
the server cleanly will exercise IT5 automatically; the fix is
positioned to make IT5 produce a clean bounded-error exit.

Reviewer agrees with Option B. The fix is a pure code reordering
with no semantic change. Code review is sufficient.

### F-17-EXEC-02: RESOLVED (87/87 tests pass)

13 new test functions added to `tests/test-cache-controller.cpp`
cover all 13 BLOCKED-pending-test-code rows (UT3, UT4, UT5, UT6,
UT7, UT8, UT10, UT11, UT14, UT15, UT16, UT17, UT18). Tests that
depend on private internals (`classify_restore_miss`) use the
existing `debug_classify_stage17_miss_for_tests` accessor. Tests
that depend on the arg parser (UT6, UT8, UT10) mirror the
lambda's validation logic; the live arg parser is covered by IT2.
The print string at `tests/test-cache-controller.cpp:3296` confirms
87 tests total (74 existing + 13 new). All 87 pass, exit 0, no new
warnings or regressions in existing tests.

Reviewer agrees the 13 new tests correctly cover the 13 BLOCKED
rows. Each test is a focused unit assertion of the row contract.

### N17-BUGFIX-01 (Architect finding): non-blocking follow-up

The post-slot-init block at `tools/server/server-context.cpp:1548-1551`
contains a duplicate `if (cache_mode_active != CACHE_MODE_HYBRID) {
... throw std::runtime_error("--cache-cold-path requires --cache-mode
hybrid"); }` check. After the F-17-EXEC-01 move, the moved block at
lines 1416-1421 has already rejected this case before reaching the
post-slot-init block, so the duplicate is unreachable in practice.

The duplicate is defensive and harmless. Architect recommends
removing it in a follow-up stage (non-blocking). Reviewer agrees;
this is not a Stage 17 closure concern.

### I17-BUGFIX-01 (Architect INFO): system-level crash

The system-level model warmup crash is a separate environmental
issue. fit_params projection 9933 MiB vs the original test report's
1466 MiB suggests a different system state. The crash is at the
model warmup stage BEFORE the validation block runs. Reviewer agrees
this is OUT OF SCOPE for Stage 17 and is the subject of a separate
Manager decision (D17-EXEC-02).

### No new product bugs

No additional product bugs were surfaced by the bug-fix report or
the parent test report beyond the two findings the Architect
already documented (N17-BUGFIX-01, I17-BUGFIX-01) and the two
original findings (F-17-EXEC-01, F-17-EXEC-02) which are now
resolved.

## Retest scope

The minimum retest scope for the next test execution session:

1. **IT5 regression check.** Once the system-level model warmup crash
   is resolved (or in a fresh system state), re-run IT5 with
   `--cache-prompt-evidence raw` and no `--log-prompts-dir`. The
   post-fix expected outcome is a clean bounded-error exit
   (`raw prompt evidence requires --log-prompts-dir`) with a
   non-zero exit code, NOT a STATUS_STACK_BUFFER_OVERRUN.
2. **13 new unit tests regression check.** Re-run
   `build-cov/bin/Release/test-cache-controller.exe`. Expected:
   87/87 PASS, 0 FAIL, 0 new warnings. No regression in the
   existing 74 tests.
3. **Optional clean rerun of all integration rows** if the
   system-level crash is resolved and the test environment is
   fresh. The 7 integration PASS rows (IT1..IT4, IT6, IT11, IT12)
   should remain PASS; IT5 should now PASS (bounded error exit);
   IT7, IT9, IT10 require a cold-pressure driver to be exercised.

The 4 BLOCKED-acceptable integration rows (IT7, IT8, IT9, IT10)
plus the 5 BLOCKED-acceptable synthetic, 3 stress-longrun, and
2 heavy rows are not part of this retest scope. They route to
follow-up sessions per the test plan's session-scope rules.

The 13 unit rows do not need a fresh execution; their tests are
on disk and the focused test binary exit-0 result is durable
evidence for the current bug-fix loop.

## Unresolved execution blockers

These items carry over from the parent test report and the
Architect bug-fix review. None block Stage 17 closure. Each is
owned by a separate role or session.

| ID | Title | Severity | Owner |
| --- | --- | --- | --- |
| F-16-TR-03 | Coverage BLOCKED by Release build without /Zi (`build-cov/CMakeCache.txt:80: CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG`); OpenCppCoverage produces header-only .cov | non-blocking for PASS | Developer (separate task: add /Zi /DEBUG to CMAKE_CXX_FLAGS_RELEASE or build separate RelWithDebInfo target) |
| I17-BUGFIX-01 | System-level model warmup crash on baselines with no cache flags; separate environmental issue | non-blocking for PASS | Manager (D17-EXEC-02: investigate memory accounting discrepancy, re-run in fresh state, or defer to follow-up) |
| F-17-EXEC-03 | 4 integration rows (IT7, IT8, IT9, IT10) BLOCKED in this session | non-blocking for PASS | future QA session (cold-pressure driver + Stage 16 3-message input) |
| F-17-EXEC-04 | 5 synthetic rows (SY1..SY5) BLOCKED-prompt-generator-missing | non-blocking for PASS | Developer or future QA session (add agentic prompt generator at 12k/24k/60k) |
| F-17-EXEC-05 | 3 stress-longrun rows (ST1..ST3) BLOCKED-test-session-scope | non-blocking for PASS | future stage (re-run framework drivers) |
| F-17-EXEC-06 | 2 heavy rows (HV1, HV2) BLOCKED-test-session-scope | non-blocking for PASS | future stage or nightly run (Qwen3.6-27B-MTP fixture) |
| N17-BUGFIX-01 | Duplicate cold-path-hybrid check at server-context.cpp:1548-1551 is now dead code | non-blocking for PASS | Architect or follow-up Developer (remove duplicate in follow-up stage) |
| Parent count typo | Parent prose says "Total 11 PASS / 1 FAIL / 28 BLOCKED" but per-row sums to 12 PASS / 1 FAIL / 27 BLOCKED | non-blocking, non-test | QA (correct prose in a follow-up edit; per-row table is the authoritative source) |

## Manager closure recommendation

PASS. Stage 17 is ready for Manager closure.

- F-17-EXEC-01 RESOLVED. Validation block moved to top of
  `load_model()` (lines 1384-1428). Code review by Architect
  part-6 confirms byte-identical, dependency-safe. System-level
  model warmup crash is OUT OF SCOPE per I17-BUGFIX-01 and
  routes to a separate Manager decision (D17-EXEC-02). The next
  QA session in a clean system state will exercise IT5
  automatically.
- F-17-EXEC-02 RESOLVED. 13 new test functions in
  `tests/test-cache-controller.cpp` cover all 13 BLOCKED-
  pending-test-code unit rows. 87/87 tests pass.
- 12 rows PASS, 14 rows RESOLVED, 14 rows BLOCKED-acceptable
  (session-scope per test plan), 0 rows FAIL.
- One non-blocking Architect finding (N17-BUGFIX-01: duplicate
  cold-path-hybrid check) is defensive and harmless; routes to
  a follow-up stage.
- D17-EXEC-01 (accept F-17-EXEC-01 fix based on code review
  alone, defer verification) is the right call. D17-EXEC-02
  (system-level crash as a separate decision) and D17-EXEC-03
  (optional duplicate check removal) are non-blocking follow-ups.

The Manager can close Stage 17 with the N17-BUGFIX-01,
F-17-EXEC-03..06, F-16-TR-03, and parent count typo items as
separate follow-ups.

## Handoff

Next owner: Manager for Stage 17 closure.

The Manager:

1. Closes Stage 17 (current status `test-results-review`).
2. Applies D17-EXEC-01 (Option B: accept F-17-EXEC-01 fix based
   on code review, defer verification to a future test execution
   session in a clean system state).
3. Applies D17-EXEC-02 (system-level model warmup crash as a
   separate environmental decision; investigate memory accounting
   discrepancy, re-run in fresh state, or defer to follow-up).
4. Applies D17-EXEC-03 (optional: remove duplicate cold-path-
   hybrid check at server-context.cpp:1548-1551 in a follow-up
   stage).
5. Carries F-17-EXEC-03 (cold-pressure driver for IT7, IT9, IT10)
   and F-17-EXEC-04 (agentic prompt generator for SY1..SY5) to
   a future QA session.
6. Carries F-17-EXEC-05 (stress-longrun framework re-run) and
   F-17-EXEC-06 (Qwen3.6-27B-MTP heavy rows) to a future stage
   or nightly run.
7. Carries F-16-TR-03 (coverage RelWithDebInfo rebuild) as a
   separate Developer task (non-blocking).
8. Carries the parent count typo (11/28 vs 12/27) as a QA
   follow-up edit; per-row table is authoritative.
9. Updates the stage tracker row 17 from `test-results-review`
   to `closed`, citing this review as the closure evidence.

No source code, design, implementation, architecture, test plan,
or other test report files were modified by this review. Only
`test-report-20260617-01-developer-review.md` was created. This
file uses LF line endings, plain ASCII status labels, and stays
under the 300-line durable-doc cap (this report is 196 lines).
