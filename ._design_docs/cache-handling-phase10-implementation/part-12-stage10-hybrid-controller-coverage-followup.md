# Stage 10 follow-up: C2 - hybrid controller test functions

- Date: 2026-06-04
- Owner: Developer
- Source of action: [test-report-20260603-architect-review.md](../.test_reports/test-report-20260603-architect-review.md) Finding C / Action C2

## Action

Add hybrid-controller test functions for the uncovered blocks in
`server-cache-hybrid.cpp`. The file sat at 63.16% with 680 uncovered
lines after the closure of Stage 10. The Architect's review called for
tests that use the four cited debug helpers
(`debug_add_entry_for_tests`, `debug_set_hot_payload_budget_bytes_for_tests`,
`debug_admit_checkpoint_for_tests`, `debug_acquire_first_branch_ref_for_tests`)
to push the per-file rate toward the 80% target on the next coverage run.

## Files changed

`tests/test-cache-controller.cpp` (test-only change). No product code
under `tools/server/` was modified.

| New test function | Lines | Debug helpers used | Targeted uncovered block |
| --- | --- | --- | --- |
| `C2_test_update_token_limit_eviction_plan` | 2292-2315 | `debug_add_entry_for_tests` | Token-limit eviction plan loop in `update()` (server-cache-hybrid.cpp:715-731), `build_policy_candidates`, `eviction_policy.plan_evictions`, `evict_entry_by_id` (line 1560) |
| `C2_test_set_byte_budget_after_addition_triggers_eviction` | 2317-2340 | `debug_add_entry_for_tests`, `debug_set_hot_payload_budget_bytes_for_tests` | Late byte-budget enforcement path: `evict_until_within_budget` (line 2119) when the budget is set after entries are admitted |
| `C2_test_admit_checkpoint_with_explicit_token_span_end` | 2342-2364 | `debug_add_entry_for_tests`, `debug_admit_checkpoint_for_tests(size_t, size_t, int64_t)` | Third `debug_admit_checkpoint_for_tests` overload (server-cache-hybrid.cpp:1775) plus the `attach_checkpoint_payload` path (line 2804) and the descriptor span-metadata recording branch |
| `C2_test_branch_ref_blocks_byte_budget_eviction` | 2366-2392 | `debug_add_entry_for_tests`, `debug_set_hot_payload_budget_bytes_for_tests`, `debug_acquire_first_branch_ref_for_tests`, `debug_release_first_branch_ref_for_tests` | `n_eviction_payload_blocked_refs` counter and the eviction guard that holds off payload eviction while a branch ref is active (line 1560 branch with `active_slot_refs > 0`) |
| `C2_test_unlimited_byte_budget_bypasses_eviction` | 2394-2414 | `debug_add_entry_for_tests`, `debug_set_hot_payload_budget_bytes_for_tests(size_t, bool)` | `hot_payload_budget_enabled` (server-cache-hybrid.cpp:3114) `unlimited=true` early-return branch and the no-op `evict_until_within_budget` path that follows |
| `C2_test_get_stats_residency_and_descriptor_counters` | 2416-2438 | `debug_add_entry_for_tests`, `debug_admit_checkpoint_for_tests` | `get_stats()` (server-cache-hybrid.cpp:733) residency and descriptor counter branches: `n_hot_payload_descriptors`, `n_exact_blob_payload_descriptors`, `n_checkpoint_payload_descriptors`, `n_target_only_payload_descriptors`, `n_target_and_draft_payload_descriptors`, and the `branch_forest.namespaces` aggregator |

The new tests are registered in `main()` at lines 2530-2535 of the same
file. The summary line at line 2540 was updated from "72 tests" to "78
tests" with a "+ 6 Stage 10 2026-06-04 C2" tail.

## Per-test rationale

### `C2_test_update_token_limit_eviction_plan`

A constructor with `limit_tokens=4` and three two-token entries forces
`update()` to enter the eviction plan loop in `server-cache-hybrid.cpp:715-731`.
That loop calls `build_policy_candidates()`, runs `eviction_policy.plan_evictions()`,
and calls `evict_entry_by_id(plan.evictions.front().entry_id, plan.evictions.front().reason)`.
The test asserts that the post-update token count is within the limit
and that the `n_evictions` counter is at least one. This covers both the
unprotected and protected branches of `evict_entry_by_id` (line 1560) and
the `mark_payload_evicted` (line 2572) demotion-versus-eviction decision.

### `C2_test_set_byte_budget_after_addition_triggers_eviction`

The constructor budget of 100 MiB is set wide on purpose so the two
1 MiB entries are not immediately over budget. The test then calls
`debug_set_hot_payload_budget_bytes_for_tests(512 * 1024)` to lower the
byte limit below the resident payload, then calls `update()`. This
exercises the `evict_until_within_budget` path in
`server-cache-hybrid.cpp:2119`, including the `evict_entry_by_id` call
chain for byte-budget pressure.

### `C2_test_admit_checkpoint_with_explicit_token_span_end`

The third overload `debug_admit_checkpoint_for_tests(size_t, size_t, int64_t)`
at `server-cache-hybrid.cpp:1775` takes an explicit `token_span_end`
argument. The existing tests only exercise the basic and
`fail_after_descriptor` overloads. This new test sets `token_span_end=3`
on a six-token entry, which forces the `attach_checkpoint_payload` path
at line 2804 to record a `token_span_end` value below the full entry
length, exercising a different branch of the descriptor span-metadata
recording code.

### `C2_test_branch_ref_blocks_byte_budget_eviction`

A first entry is admitted, then `debug_acquire_first_branch_ref_for_tests`
is called to hold a branch ref. A second entry is admitted that pushes
the controller over the 150-byte budget. The test asserts that
`n_eviction_payload_blocked_refs` is at least one and that
`branch_forest.active_slot_refs` is one while the ref is held. After
`debug_release_first_branch_ref_for_tests` and a second `update()`, the
test asserts that `n_payload_evictions` is at least one and that
`active_slot_refs` drops back to zero. This covers the eviction-guard
path in `evict_entry_by_id` (line 1560) and the `n_eviction_payload_blocked_refs`
counter increment.

### `C2_test_unlimited_byte_budget_bypasses_eviction`

The two-argument overload `debug_set_hot_payload_budget_bytes_for_tests(0, true)`
is called with `unlimited=true`, putting the controller into the
unlimited-byte-budget mode. Two 900 KiB entries are added (1.8 MiB
total), then `update()` is called. The test asserts that
`debug_entry_count_for_tests()` stays at two, `resident_payload_bytes`
is 1800 KiB, and `n_payload_evictions` is zero. This covers the
`hot_payload_budget_enabled` early-return at `server-cache-hybrid.cpp:3114`
when `limit_size_unlimited` is true, plus the no-op branch of
`evict_until_within_budget` that follows.

### `C2_test_get_stats_residency_and_descriptor_counters`

Two entries are added: one exact-blob only, one exact-blob plus a
checkpoint. The test calls `get_stats()` and asserts the specific
counter values for `n_hot_payload_descriptors`, `n_exact_blob_payload_descriptors`,
`n_checkpoint_payload_descriptors`, `n_target_only_payload_descriptors`,
`n_target_and_draft_payload_descriptors`, `resident_payload_bytes`, and
the per-namespace node count in `branch_forest.namespaces`. This
exercises the per-counter `if` and `else if` branches in
`get_stats()` at `server-cache-hybrid.cpp:733` and the namespace
aggregator.

## Compile evidence

The `test-cache-controller.vcxproj` was built with MSBuild against
the existing `build/` solution. Output snippet:

```text
  test-cache-controller.cpp
  test-cache-controller.vcxproj -> D:\source\llama.cpp-jet\build\bin\Release\test-cache-controller.exe
```

No new warnings or errors were produced. The full build log is at
`._design_docs/.test_reports/test-report-20260603-04-artifacts/c2-build.log`.

The rebuilt test executable was also run to confirm the new tests
pass. The last lines of the run are:

```text
test-cache-controller: C2 update token-limit eviction plan...
  PASSED
test-cache-controller: C2 set byte budget after addition triggers eviction...
  PASSED
test-cache-controller: C2 admit checkpoint with explicit token span end...
  PASSED
test-cache-controller: C2 branch ref blocks byte-budget eviction...
  PASSED
test-cache-controller: C2 unlimited byte budget bypasses eviction...
  PASSED
test-cache-controller: C2 get stats residency and descriptor counters...
  PASSED

==================================================
All tests passed successfully!
Total: 78 tests (31 original + 5 Part 14 comprehensive + 4 Stage 4 focused + 4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused + 7 Stage 9 focused + 9 Stage 10 bugfix loop + 3 Stage 10 2026-06-04 T114 + 6 Stage 10 2026-06-04 C2)
==================================================
```

The full run log is at
`._design_docs/.test_reports/test-report-20260603-04-artifacts/c2-test-run.log`.

## Expected coverage impact

The new tests should cover several distinct regions in
`server-cache-hybrid.cpp` that the prior test surface did not reach:

- The token-limit eviction plan loop at lines 715-731, including the
  `evict_entry_by_id` body at line 1560 (both the protected and
  unprotected branches) and the `mark_payload_evicted` decision at
  line 2572 that decides between demotion and immediate eviction.
- The `evict_until_within_budget` body at line 2119, including the
  late-budget-change scenario where the byte limit is set after
  entries are already admitted.
- The third overload of `debug_admit_checkpoint_for_tests` at
  line 1775, the `attach_checkpoint_payload` body at line 2804, and
  the descriptor span-metadata recording that differs from the basic
  overload's path.
- The `n_eviction_payload_blocked_refs` counter increment in
  `evict_entry_by_id` (line 1560) and the eviction-guard branch that
  checks `active_slot_refs` before evicting a payload.
- The `hot_payload_budget_enabled` (line 3114) early-return when
  `limit_size_unlimited` is true, plus the bypassed body of
  `evict_until_within_budget` that follows.
- The per-counter branches in `get_stats()` (line 733) for hot,
  exact-blob, checkpoint, target-only, and target-and-draft
  descriptors, plus the namespace aggregator.

The next coverage run should move `server-cache-hybrid.cpp` closer
to the 80% per-file target. The exact number depends on the OpenCppCoverage
denominator and the other tests already in the run.

## Coverage measurement is a future QA task

This gate produces test code only. The coverage measurement, the
follow-up coverage-report.md artifact, and any decision on whether the
C2 action has been satisfied are owned by QA in a separate session. The
Developer does not run coverage as part of this gate.
