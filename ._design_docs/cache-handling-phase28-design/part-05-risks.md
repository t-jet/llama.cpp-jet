# Stage 28 design part 05: Risks and open questions

Status: design; Manager gate decision D28-DESIGN-01 2026-06-26
Date: 2026-06-26
Stage: 28 (Technical Debt Removal + Open Bug Fixes)
Owner: Architect (catalog); Developer (mitigation); Manager (gate)

## Scope

Per-fix risk profile plus coupling risks and what could break. Each
risk gets a severity, likelihood, mitigation, and contingency.

---

## Per-fix risks

### R28-BUG-01: TP-26-UT6 test artifact

| Aspect | Detail |
| --- | --- |
| Severity | MEDIUM (test-only, no production impact) |
| Likelihood | LOW (clear pattern to apply) |
| Mitigation | Replace each `assert()` with explicit abort-on-fail one at a time, run the test pack after each, confirm exit code |
| Contingency | If a replacement breaks a prior test that was relying on the assert, restore that specific assert and add a comment marking it as known-assert |
| Worst case | One or two tests regress; revert and split into per-test commits |

### R28-BUG-02: cold-store metric vs filesystem drift

| Aspect | Detail |
| --- | --- |
| Severity | HIGH (user-facing metric is wrong; cache budget enforcement relies on it) |
| Likelihood | MEDIUM (diagnosis may reveal root cause is more involved than 3 candidates) |
| Mitigation | Mandatory diagnosis step before fix. Add one-shot diagnostic log of every `cold_store.remove()` return and every `cold_store.write()` call. Rerun Stage 24 -07 S02 hybrid. Log reveals orphan-file path. |
| Contingency | If diagnosis finds a path not in the 3 candidates, document the new path in a stage28-design-addendum part and proceed with the new fix shape. Iteration 1 stays open until drift closes. |
| Worst case | Diagnosis shows the per-id map is fundamentally inadequate; the fix becomes a larger refactor (e.g., write a per-file manifest and reconcile on each `n_cold_payload_bytes` read). Iteration 1 stretches to 2-3 implementation passes. |

### R28-BUG-03: ASan LNK2038 mismatch

| Aspect | Detail |
| --- | --- |
| Severity | LOW (build infrastructure only; no runtime impact) |
| Likelihood | LOW (Option A is well-known CMake pattern) |
| Mitigation | Add `target_compile_options(ggml-cuda PRIVATE /fsanitize=address)` and confirm 274 errors disappear |
| Contingency | If Option A fails (e.g., ggml-cuda headers have ASan-incompatible SAL), fall back to Option B (--whole-archive) or Option C (separate asan target) |
| Worst case | Rebuild time increases substantially because ggml-cuda is large; iteration 1 wall-time stretches |

### R28-BUG-04: async worker code retention after Stage 25 retirement

| Aspect | Detail |
| --- | --- |
| Severity | HIGH (2 production paths hang or leak; user-impacting after first cold-payload restore) |
| Likelihood | HIGH for the prod bugs (already observed at code-review time 2026-06-26); MEDIUM for test migration (41+ refs may have non-obvious dependencies) |
| Mitigation Phase A | Replace `load_slot` line 4929 `promote_payload` call with `tx_promote_payload`; replace `stage23_admit_checkpoint_store` line 1875-1899 async + wait loop with `tx_promote_payload` single call |
| Mitigation Phase B | Mark `enqueue_demotion`, `enqueue_promotion`, `start`, `stop`, `process_completions`, `drain_results`, and the 4 `debug_*_io_worker_for_tests` accessors `[[deprecated]]`; migrate 41+ test refs to `execute_inline` / `execute_*_inline` |
| Contingency Phase A | If `tx_promote_payload` returns false on cold-not-configured, the descriptor stays cold and the caller returns false as before; behavior is unchanged for the cold-not-configured case |
| Contingency Phase B | If a test ref depends on `worker_thread_` timing or `debug_completion_delay_ms_`, the migration rewrites that test to drive `execute_inline` directly with a stub cold store |
| Worst case Phase A | `tx_promote_payload` raises a recursive-mutex reentrancy assertion if called from a thread that already holds the cache-state mutex but not via a tx_* entry point; mitigation is to assert `tx_assert_mutex_held()` at the new call sites |
| Worst case Phase B | Compile errors surface a test that genuinely needs the async timing (e.g., a queue-saturation race); that test must be re-architected, possibly deferred to a Stage 29 dedicated worker-revival stage |
| Worst case combined | Some of the 41+ test refs are tests of worker-queue saturation that cannot be re-architected cleanly; defer those specific tests to Stage 29 and proceed with the rest |

---

## Coupling risks

The three HIGH fixes do not couple to each other (per part-02 fix
coupling matrix). Each can be reverted independently.

MEDIUM fixes couple weakly:

- R28-TD-04 and R28-TD-07 both touch the runner; if applied together
  they share one commit but each fix can be reverted independently.
- R28-TD-02 and R28-TD-03 both add new unit tests; they share the
  test pack but each test is independent.
- R28-BUG-04 Phase B (deprecation) and R28-TD-05 (deletion) are
  coupled: Phase B must land first so deletion is safe. They are
  sequenced across iterations 1 and 2.

LOW fixes are out-of-scope so no coupling risk.

---

## Cross-cut risks

### R28-RISK-01: Re-introducing uncommitted code churn

After Stage 27 closure, the work-tree has 5 uncommitted fixes pending
user commit approval (D-EXEC-24-01, D-EXEC-24-02, D-EXEC-26-01,
D-EXEC-26-02, D-EXEC-27-08). Stage 28 will add more uncommitted
changes. If the user commits Stage 24-27 fixes between Stage 28
design and implementation, the Stage 28 implementation must rebase
on the new HEAD. The risk is line-number drift (e.g., the
`tx_demote_payload` fix at line 3396 might shift by a few lines).

- Mitigation: Architect design uses function names, not line numbers,
  for all references. Implementation review verifies exact line
  numbers against the committed HEAD.
- Contingency: If rebasing fails, stage the Stage 28 implementation
  in a side branch and merge after user commits Stage 24-27.

### R28-RISK-02: Test pack size creep

After iteration 1, test count grows from 138 to 139 (TP-28-UT-01).
After iteration 2, test count grows to 141 (TP-28-UT-02, TP-28-UT-03).
The total test runtime in Release grows proportionally. Current
`test-cache-controller.exe` runtime is ~3 seconds in Release; the
new tests add ~1 second each (controlled `std::abort` and filesystem
touch). Total runtime stays under 10 seconds.

- Mitigation: Each new test has explicit time budget in its test body.
- Contingency: If runtime exceeds 30 seconds, defer the slowest test
  to a slow-test partition (existing pattern).

### R28-RISK-03: Cold-store drift fix perturbs S03 hybrid leg

Stage 27 fix relied on `tx_demote_payload` running inline and
releasing hot memory. R28-BUG-02 fix may add accounting path
changes that touch `handle_demotion_completion`. If the accounting
path breaks the synchronous inline contract, S03 hybrid may regress.

- Mitigation: Stage 24 -07 rerun is mandatory after R28-BUG-02 fix.
- Contingency: If S03 hybrid regresses, revert R28-BUG-02 fix and
  investigate.

### R28-RISK-04: ASan LNK2038 fix breaks CUDA build

Option A adds `/fsanitize=address` to `ggml-cuda`. If CUDA kernel
compilation rejects the flag (some CUDA toolchains do not pass ASan
flags to nvcc), the ggml-cuda build fails.

- Mitigation: Stage the CMake change so the flag is added to host
  compilation only, not device compilation. CMake `target_compile_options`
  with `$<COMPILE_LANGUAGE:CXX>` generator expression.
- Contingency: If Option A fails, fall back to Option B (--whole-archive).

### R28-RISK-05: R28-BUG-04 Phase B deprecation breaks 41+ tests in unexpected ways

Phase B adds `[[deprecated]]` markers to the async API and migrates
the 41+ test refs in one commit. Some tests may depend on subtle
worker-thread timing (e.g., `debug_completion_delay_ms_` used to
synchronize a queue-saturation race). Migration rewrites those tests
to drive `execute_inline` directly, but a test that genuinely
exercises the worker thread's race behavior cannot be migrated by
stubbing and must be re-architected or deferred.

- Mitigation: Audit each of the 41+ test refs for timing or
  thread-affinity dependencies before applying the deprecation
  markers. Build incrementally: deprecate one symbol at a time, fix
  the compile errors, run the test pack, repeat.
- Contingency: If a test cannot be migrated without losing coverage,
  move it to a Stage 29 "async worker revival" todo and proceed with
  the deletion for the rest. Document the deferred test in part-01
  as a new R28-TD-NN item.
- Worst case: 5-10 of the 41+ tests need re-architecting; iteration 1
  Phase B stretches to 2 implementation passes.

### R28-RISK-06: R28-BUG-04 Phase A fixes break timing-sensitive restore paths

`load_slot` line 4929 currently calls `promote_payload` and returns
false immediately (fire-and-forget). Some downstream callers may rely
on the cold-payload being promoted by the time the next request
arrives (e.g., a chat session with a checkpoint restore followed by
a load). The Phase A fix makes promotion synchronous via
`tx_promote_payload`, which can block the request thread on cold
read I/O.

- Mitigation: Bound the cold read time via the existing
  `cold_read_timeout_ms` (if present) or add a `std::async` indirection
  in `tx_promote_payload` so the request thread does not block on the
  filesystem. Verify with a Stage 24 -07 rerun that restore latency
  stays within the existing `n_load_slot_*` metrics.
- Contingency: If synchronous promotion increases restore latency
  beyond the existing per-stage budget, fall back to a hybrid:
  `tx_promote_payload` returns the in-flight future and the caller
  polls; this preserves the old async semantics without the broken
  worker thread.
- Worst case: Restore latency for cold-payload targets regresses
  from < 50 ms (current fire-and-forget, descriptor stuck) to > 500 ms
  (synchronous cold read); this is still preferable to the
  descriptor-leak bug but requires the per-stage latency budget to
  be relaxed.

### R28-RISK-07: stage23 wait loop removal changes cold-checkpoint restore semantics

The stage23 wait loop at line 1875-1899 returns false ("checkpoint
promotion incomplete") after 30 s if the worker did not flip the
residency. In practice today this branch never fires because the
worker is never started, so the loop always times out. The fix
replaces this with a synchronous `tx_promote_payload` call, which
either succeeds (descriptor is hot) or fails fast (no wait).

- Mitigation: Verify the test that exercises this path (TP-23
  stage23_admit_checkpoint) PASSes with the new synchronous behavior
  in both build-cuda Release and build-cuda-asan. Document the new
  expected timing in the test plan.
- Contingency: If the synchronous path exposes a regression in the
  stage23 checkpoint admission logic (e.g., a precondition that the
  async wait was masking), file a new R28-BUG-NN and proceed with
  the async path removed.
- Worst case: Stage 23 test suite regresses; revert the change and
  investigate before re-applying.

---

## Open questions for Manager

| ID | Question | Default if no answer |
| --- | --- | --- |
| OQ-28-01 | Should R28-BUG-02 fix be deferred to a separate Stage 29 if the diagnosis step shows the root cause is a fundamental refactor (not a one-line tweak)? | No, fix in Stage 28; iterate if needed |
| OQ-28-02 | Should iteration 2 (MEDIUM) be in scope for Stage 28, or deferred to Stage 29 to keep this stage focused on HIGH? | Yes, in scope; user direction is "remove all technical debt" which includes MEDIUM |
| OQ-28-03 | Should the runner script fixes (R28-TD-04, R28-TD-07) be combined with iteration 1, or stay in iteration 2? | Iteration 2; they don't unblock HIGH fixes |
| OQ-28-04 | Should iteration 3 (LOW cosmetic) be entirely out-of-scope, or should the prose-typo items (R28-TD-08, R28-TD-09, R28-TD-11) be bundled with the doc updates in iteration 2? | Bundle prose typos with iteration 2 doc fixes |
| OQ-28-05 | Should R28-TD-05 (dead `enqueue_demotion`/`enqueue_promotion`) be in-scope given that the methods are dead code on the production path? | Resolved 2026-06-26: promoted to iteration 2 (MEDIUM) conditional on R28-BUG-04 Phase B compile-clean; the user direction to handle async worker code moved it from "deferred to Stage 29" to in-stage cleanup |
| OQ-28-06 | Should R28-BUG-04 Phase A use `tx_promote_payload` (synchronous under the cache-state mutex) or rebuild a minimal async path (e.g., `std::async`) for the 2 production callers? | Default: synchronous via `tx_promote_payload`. Rationale: matches Stage 25 design intent (stateless inline helper), removes the broken worker thread, and the affected paths (load_slot cold payload, stage23 checkpoint restore) are not latency-critical enough to justify re-introducing async I/O. Reopen OQ-28-06 if Stage 24 -07 rerun shows restore latency regression > 2x current. |

---

## What could break

- **Stage 24 -07 rerun signature change**: post-fix, S02 hybrid may
  PASS instead of FAIL-cold-budget. This is desired, but the existing
  test-report-20260626-07-fixes.md notes "S02 hybrid FAIL-cold-budget"
  as the expected baseline. After Stage 28 fix, that note becomes
  stale and the Stage 24 -08 report supersedes it.
- **Stage 27 closure record**: part-10 records "TP-26-UT6 deferred
  per D-EXEC-27-09". Post-fix, TP-26-UT6 PASSes. The Stage 27 closure
  record becomes stale on this point; Stage 28 implementation log
  updates it via a closure-sweep part.
- **Tracker Stage 27 row Notes**: similar staleness; the Stage 28 row
  in the tracker supersedes the Stage 27 follow-up text.

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace, and stays under the 300-line durable-doc cap.
