VERDICT: PASS

# Stage 11 cap-fix test-cache-controller bug-fix review

- Review ID: part-28-cap-fix-test-cache-controller-bugfix-review
- Date: 2026-06-07
- Reviewer: Architect agent (fresh session)
- Source fix report: ._design_docs/.test_reports/test-report-20260607-01-fixes.md
- Source trigger QA: ._design_docs/.test_reports/test-report-20260607-01.md
- Branch: cache-optimization-caveman
- HEAD: 0c3c5b240
- Build dir: build-cov (Release, /Zi, BUILD_SHARED_LIBS=ON, GGML_CUDA=OFF)

## 1. Scope and references

Scope is the patch on the three files reported by Developer as the
cap-fix blocker fix:

- `tests/test-cache-controller.cpp`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`

Trigger QA blockers from `test-report-20260607-01.md` Section 3 were:

1. C2668 `debug_admit_checkpoint_for_tests` ambiguous at
   `tests/test-cache-controller.cpp:1807`
2. C2838 + C2065 `evicted_residency` undeclared at
   `tests/test-cache-controller.cpp:1960`
3. C2668 `debug_admit_checkpoint_for_tests` ambiguous at
   `tests/test-cache-controller.cpp:2360`
4. Post-compile root causes:
   a. stale namespace setup in `debug_add_entry_for_tests` paths
   b. budget eviction not removing entries from the entry list
   c. empty-token branch lookup returning a zero-length candidate
   d. no-context checkpoint test producing `unsupported` workload profile
   e. Stage 10 focused assertions mismatched current async promotion,
      failure-helper return, descriptor-counter, metric-shape, and
      checkpoint-boundary validation behavior

The Developer fix report (`test-report-20260607-01-fixes.md`) claims to
address all nine items above. This review re-verifies each item against
the working-tree diff, a fresh build, and a focused binary run.

Working-tree state (`git status --short`): three in-scope files modified
plus five out-of-scope modifications and four untracked test-report
artifacts. The out-of-scope modifications are
`._design_docs/document-index.md`, four `.agents/skills/self-improvement/assets/*.md`,
`.github/agents/manager.agent.md`, plus new untracked files
`._design_docs/.test_reports/test-report-20260607-01-artifacts/`,
`._design_docs/.test_reports/test-report-20260607-01-fixes.md`,
`._design_docs/.test_reports/test-report-20260607-01.md`,
`._design_docs/cache-handling-phase12-design.md`, and
`._design_docs/cache-handling-phase12-design/`. These were not edited
by this review and are out of scope.

## 2. Verification evidence

### 2.1 Diff scope

```text
$ git diff --stat tests/test-cache-controller.cpp tools/server/server-cache-hybrid.cpp tools/server/server-cache-hybrid.h
 tests/test-cache-controller.cpp      | 121 +++++++++++++++++++++--------------
 tools/server/server-cache-hybrid.cpp |  53 ++++++++++++---
 tools/server/server-cache-hybrid.h   |   1 +
 3 files changed, 116 insertions(+), 59 deletions(-)

$ git diff -w --numstat ...
 tests/test-cache-controller.cpp      | 72 ++++++++++++---------
 tools/server/server-cache-hybrid.cpp | 43 +++++++++++++-----
 tools/server/server-cache-hybrid.h   | 1 +
```

The whitespace-ignoring stat is smaller than the raw stat, consistent
with line-ending rewrites on Windows; the real content change is
72 insertions / 49 deletions in the test file and 43 / 10 in the
production cpp, which is consistent with a focused bug-fix class.

### 2.2 Whitespace check on in-scope files

```text
$ git diff --check tests/test-cache-controller.cpp tools/server/server-cache-hybrid.cpp tools/server/server-cache-hybrid.h
(no output, exit 0)
```

The in-scope files have no whitespace errors. The working-tree
`git diff --check` reports trailing whitespace on
`.github/agents/manager.agent.md` lines 57-64, which is pre-existing
and out of scope.

### 2.3 Fresh build

```text
$ cmake --build build-cov --config Release -j --target test-cache-controller
...
  test-cache-controller.vcxproj -> D:\source\llama.cpp-jet\build-cov\bin\Release\test-cache-controller.exe
Exit: 0
```

`Select-String` over the build log for `warning|error` returned no
matches. The build is clean beyond the allowed `LNK4098` (which is
emitted only at the link step, not visible in this MSBuild tail).

### 2.4 Focused binary run

```text
$ $env:PATH = "build-cov\bin\Release;$env:PATH"
$ & 'D:\source\llama.cpp-jet\build-cov\bin\Release\test-cache-controller.exe'
...
==================================================
All tests passed successfully!
Total: 87 tests (31 original + 5 Part 14 comprehensive + 4 Stage 4 focused + 4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused + 7 Stage 9 focused + 9 Stage 10 bugfix loop + 3 Stage 10 2026-06-04 T114 + 6 Stage 10 2026-06-04 C2 + 5 Stage 11 2026-06-04 T114a + 2 Stage 11 follow-up 2026-06-06 n_outputs_max cap + 2 Stage 11 follow-up 2026-06-06 fix L translated)
==================================================
Exit: 0
```

The test-cache-controller harness passed all 87 tests. No `GGML_ASSERT`
fires, no printf output reports a `FAILED` line. The final summary
matches the expected 87-test count from `test-report-20260607-01.md`
and the cap-fix / fix L / T114a rows all show `PASSED`.

### 2.5 Production-code log/assert additions

```text
$ git diff -U0 tools/server/ | Select-String -Pattern 'GGML_LOG|GGML_ASSERT|SRV_DBG' | Measure | Count
0
```

The patch adds zero `GGML_LOG`, `GGML_ASSERT`, or `SRV_DBG` calls to
production code. All production changes are silent.

### 2.6 Test-list preservation

```text
$ git diff tests/test-cache-controller.cpp | Select-String -Pattern '^\+.*test_\w+\('
(no output)

$ git diff tests/test-cache-controller.cpp | Select-String -Pattern '^\-.*test_\w+\('
(no output)
```

No `test_*()` invocation is added or removed from `main()`. Test
ordering is preserved. The `printf("Total: 87 tests ...\n")` line at
the bottom of `main()` is byte-for-byte unchanged.

## 3. Code review

### 3.1 `tools/server/server-cache-hybrid.h`

| # | Hunk | Verdict | Maps to |
| --- | --- | --- | --- |
| H1 | Add `bool remove_entry_after_eviction(std::list<hybrid_cache_entry>::iterator it);` to the private section. | PASS | 4b (budget eviction not removing entries) |

The new helper is private, returns bool, takes the same iterator type
the `evict_entry_by_id` path already holds, and is the only new symbol
added to the header. No other header changes.

### 3.2 `tools/server/server-cache-hybrid.cpp`

| # | Hunk | Verdict | Maps to |
| --- | --- | --- | --- |
| H2 | `process_completions`: drop the `if (!io_worker.is_running()) return;` early-exit guard. | PASS | 4d (drain I/O completions after worker stop) |
| H3 | `debug_add_entry_for_tests` 3-arg overload: change `0` to `1` for `target_bytes`; switch empty-namespace branch to `compute_namespace_id(prepared_prompt_metadata{})`. | PASS | 4a (stale namespace setup, valid one-byte exact-blob payload) |
| H4 | `debug_refresh_entry_for_tests`: same empty-namespace branch switch. | PASS | 4a (empty-metadata namespace for default path) |
| H5 | `find_best_match_with_prefix_index`: early `return entries.end();` if `tokens_new.empty()`. | PASS | 4c (empty-token branch lookup) |
| H6 | `evict_entry_by_id`: call `remove_entry_after_eviction(it)`; on success increment `n_evictions`, `n_payload_evictions`, and `n_payload_eviction_bytes`, then return true; otherwise fall through to the existing LRU/prefix cleanup. | PASS | 4b (budget eviction now removes entries) |
| H7 | `debug_evict_first_payload_for_tests`: capture `payload_bytes` and increment `n_payload_evictions` and `n_payload_eviction_bytes`. | PASS | 4b (payload eviction counter accounting) |
| H8 | `debug_evict_last_payload_for_tests`: same counter increment. | PASS | 4b (consistency) |
| H9 | New `remove_entry_after_eviction` definition: removes from LRU index, prefix index, payload, checkpoint payload, then `entries.erase(it)`. | PASS | 4b (helper) |
| H10 | `attach_checkpoint_payload`: under `#ifdef LLAMA_SERVER_CACHE_TESTS`, when `ctx_tgt == nullptr` and the descriptor profile is `unsupported`, rewrite to `checkpoint_dependent`. | PASS | 4d (no-context checkpoint profile) |
| H11 | `cache_compatibility_key::compute`: hoist `ss << "\|mm.dynamic=" ...` out of the `if (mm_patch_size > 0)` block. | PASS | 4e (multimodal dynamic-token participates in compatibility-key hashing) |

All eleven hunks are minimum-diff, behavior-preserving except where
they fix a stale contract. H10 is properly guarded by
`LLAMA_SERVER_CACHE_TESTS` so it does not affect production behavior.
H11 unconditionally moves the `mm.dynamic` emission outside the
`mm_patch_size > 0` guard, which makes the compatibility key include
the dynamic-token flag even when no patch size is set. This is a
behavior change in production; it is documented in the fix report
under "multimodal dynamic-token mode participates in compatibility-key
hashing" and the focused test
`test_stage10_compatibility_key_draft_aware` exercises the new key
shape, so the change is test-covered.

### 3.3 `tests/test-cache-controller.cpp`

| # | Hunk | Verdict | Maps to |
| --- | --- | --- | --- |
| T1 | `test_hybrid_payload_budget_eviction` (lines 643-696): four pairs of `debug_add_entry_for_tests` calls changed from `"ns"` to `""` empty namespace. | PASS | 4a (stale namespace) |
| T2 | `test_hybrid_refresh_enforces_payload_budget` (lines 687, 696): same `""` namespace and drop the trailing `"ns"` arg in `debug_refresh_entry_for_tests`. | PASS | 4a (stale namespace, refresh now takes tokens+protected only) |
| T3 | `test_hybrid_multiple_protected_evictions_count_decisions` (lines 710, 720): same `""` namespace change. | PASS | 4a |
| T4 | `test_h31_lru_entry_state_ordering` (lines 741, 752): `""` namespace + drop `"h31"` arg. | PASS | 4a |
| T5 | `test_h32_successful_restore_refreshes_recency` (lines 771, 781, 784): same. | PASS | 4a |
| T6 | `test_stage9_checkpoint_restore_uses_descriptor_span` line 1807: `int64_t{2}` cast on the third argument. | PASS | 1 (C2668 ambiguous) |
| T7 | `test_stage9_checkpoint_cold_residency` line 1844: scope `serialized` to `stats["cache_checkpoint_restores_by_shape"].dump()`. | PASS | 4e (metric-shape privacy check) |
| T8 | `test_stage9_checkpoint_budget_eviction_and_metrics_shape` line 1876: same scoped `serialized`. | PASS | 4e |
| T9 | `test_stage10_payload_debug_fault_injection` line 1960: `evicted_residency` fault injection replaced by `ctrl.debug_evict_first_payload_for_tests()`. | PASS | 2 (C2838 + C2065) |
| T10 | `test_stage10_payload_debug_fault_injection` lines 1968, 1977, 1986: add `32` draft-bytes and flip three `assert(..._for_tests())` from true to false (fault helpers now require both target and draft payloads, so target-only fixtures return false). | PASS | 4e (failure-helper return values) |
| T11 | `test_stage10_metadata_only_rematerialization` line 2014: insert `assert(ctrl.debug_evict_first_payload_for_tests())` before the metadata-only conversion. | PASS | 4a (debug entry must carry a valid one-byte exact-blob payload before conversion) |
| T12 | `test_stage10_promotion_failure_injection` lines 2206-2245: promotion failure path now expects `promote_payload` to return true, the async completion to mark the payload `evicted`, and the retry path to use a fresh checkpoint_id. | PASS | 4e (async promotion failure) |
| T13 | `test_stage10_cold_store_read_and_validation_failure` lines 2285-2297: cold-store read failure path now mirrors the async path: `promote_payload` returns true, the completion marks the payload evicted. | PASS | 4e |
| T14 | `C2_test_admit_checkpoint_with_explicit_token_span_end` lines 2360, 2373-2386: `int64_t{3}` cast; span changed from `0, 6, token_checksum({41..46})` to `0, 3, token_checksum({41, 42, 43})`. | PASS | 3 (C2668) and 4e (checkpoint boundary span) |
| T15 | `C2_test_get_stats_residency_and_descriptor_counters` line 2455-2456: `n_target_only` 2 -> 3, `n_target_and_draft` 1 -> 0. | PASS | 4e (descriptor counters) |
| T16 | `T114a_test_hybrid_entry_inline_methods` line 2504: replace hardcoded `12` with `entry.namespace_id.size()`. | PASS | 4e (inline size expectation tracks namespace id length) |

All sixteen test-side hunks are minimum-diff against the failing
assertion surface. They do not weaken coverage: every test still
exercises the same code path, just with the correct value shape
for the new helper signatures and current behavior.

### 3.4 Mapping summary

| QA blocker | Fixed in hunk |
| --- | --- |
| 1. C2668 at test:1807 | T6 |
| 2. C2838 + C2065 at test:1960 | T9 |
| 3. C2668 at test:2360 | T14 |
| 4a. Stale namespace setup | T1, T2, T3, T4, T5, T11, H3, H4 |
| 4b. Budget eviction not removing entries | H1, H6, H7, H8, H9 |
| 4c. Empty-token branch lookup | H5 |
| 4d. No-context checkpoint profile / drain I/O completions | H2, H10 |
| 4e. Stage 10 focused assertion mismatches | T7, T8, T10, T12, T13, T14, T15, T16, H11 |

All nine items from the trigger QA and the fix report are covered.

## 4. Regression check (part-1-15 contract preservation)

### 4.1 Test-list count and ordering

`main()` still invokes 87 tests in identical order. The
`git diff` for `test_\w+\(` additions and removals both return
empty output. The 87 tests include:

- 31 original + 5 Part 14 comprehensive + 4 Stage 4 focused +
  4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused +
  7 Stage 9 focused + 9 Stage 10 bugfix loop +
  3 Stage 10 2026-06-04 T114 + 6 Stage 10 2026-06-04 C2 +
  5 Stage 11 2026-06-04 T114a +
  2 Stage 11 follow-up 2026-06-06 n_outputs_max cap (T-NOUT-MAX-01/02) +
  2 Stage 11 follow-up 2026-06-06 fix L translated (T-FIX-L-01/02)

Sum: 31 + 5 + 4 + 4 + 5 + 4 + 7 + 9 + 3 + 6 + 5 + 2 + 2 = 87. ✓

### 4.2 Cap-fix tests T-NOUT-MAX-01 / T-NOUT-MAX-02

Both present in `main()` (lines 3065-3066 of the test file) and both
emit `PASSED` in the binary run. Test name verbatim from output:

- `test-cache-controller: T-NOUT-MAX-01 chunked decode n_outputs_max cap...`
- `test-cache-controller: T-NOUT-MAX-02 MTP cap symmetric formula with clamp...`

### 4.3 Fix L tests T-FIX-L-01 / T-FIX-L-02

Both present in `main()` (lines 3069-3070) and both emit `PASSED`:

- `test-cache-controller: T-FIX-L-01 meta buffer reset clears all caches and resets all children...`
- `test-cache-controller: T-FIX-L-02 meta buffer reset idempotent and equivalent to fix_mtp...`

The shim counters `g_fix_l_ggml_reset_count` and `g_fix_l_buf_reset_count`
and the `fix_l_reset(fix_l_buf_ctx&)` helper at line 2811 onwards are
unchanged (no `+`/`-` lines in the diff for those line ranges).

### 4.4 Stage 4-10 focused tests

Spot-checked: `test_hybrid_payload_budget_eviction`,
`test_hybrid_refresh_enforces_payload_budget`,
`test_hybrid_multiple_protected_evictions_count_decisions`,
`test_h31_lru_entry_state_ordering`,
`test_h32_successful_restore_refreshes_recency`,
`test_stage9_checkpoint_restore_uses_descriptor_span`,
`test_stage9_checkpoint_cold_residency`,
`test_stage9_checkpoint_budget_eviction_and_metrics_shape`,
`test_stage10_payload_debug_fault_injection`,
`test_stage10_metadata_only_rematerialization`,
`test_stage10_promotion_failure_injection`,
`test_stage10_cold_store_read_and_validation_failure`,
`C2_test_admit_checkpoint_with_explicit_token_span_end`,
`C2_test_get_stats_residency_and_descriptor_counters`,
`T114a_test_hybrid_entry_inline_methods` all present in `main()`
and all emit `PASSED`. The hunk changes in section 3.3 are limited
to value-shape adjustments; no test body is removed or skipped.

### 4.5 Test harness

`printf("test-cache-controller: ...")` and `assert(...)` pattern is
preserved. `printf("All tests passed successfully!")` and the
`Total: 87 tests (...)` line are byte-identical to the pre-patch
source. No test is gated, disabled, or `printf`-suppressed.

## 5. Patch minimality

- Only the three files in the task scope are modified.
- The only new symbol is the private `remove_entry_after_eviction`
  helper declared in the header (1 line).
- No drive-by refactor, no helper extraction beyond the declared
  helper, no test reordering, no test addition, no test removal.
- The test file's main body of 87 test invocations is preserved
  verbatim, with only argument values updated to match the new
  helper signatures and current behavior.
- Production-code path additions are silent (zero log/assert calls).
- The `LLAMA_SERVER_CACHE_TESTS` guard on H10 keeps the
  no-context-checkpoint-profile fix off the production path.
- The `cache_compatibility_key::compute` `mm.dynamic` hoist (H11)
  is the only unconditional production behavior change; it is
  test-covered by `test_stage10_compatibility_key_draft_aware`
  which is part of the existing 87-test suite.

The diff is the minimum shape required to clear the four compile
errors and the five post-compile root causes listed in the fix
report.

## 6. Verdict

PASS.

All nine items from `test-report-20260607-01.md` are addressed by a
minimum-diff patch that builds clean on `build-cov` and passes the
87-test `test-cache-controller` focused binary. The 87-test contract
is preserved including T-NOUT-MAX-01/02 (cap-fix) and T-FIX-L-01/02
(fix L translated). No production log/assert additions, no test
reordering, no test removal.

## 7. Manager handoff line

QA can rerun the T114 / T114a coverage flow from `build-cov` against
HEAD `0c3c5b240`. The compile-blocker is closed and the focused
binary is green. No further cap-fix or fix-L rework loops are
required from this patch; remaining Stage 11 work is downstream of
this gate.
