# Test report 20260611-01 fixes part 02: test-cache-controller.cpp defects

Source: [test-report-20260611-01.md](test-report-20260611-01.md)
Part 01 (server-context.cpp merge semantic conflict, build defect):
[test-report-20260611-01-fixes.md](test-report-20260611-01-fixes.md)
Status: TEST FIX APPLIED; build PASS; ctest 67/69 with 1 new pre-existing
runtime defect at line 571; T114/T114a BLOCKED on new defect

## Scope

Part 02 covers the test-only defect surfaced by the Stage 14 Step 3 merge
build-cov relink. The defects in `tests/test-cache-controller.cpp` are
pre-existing in local parent `02db7a768` (verified via
`git show 02db7a768:tools/server/server-cache-hybrid.h` for the header
state and `git show 02db7a768:tests/test-cache-controller.cpp` for the
test file state at the local parent). The merge exposed them because the
merged code paths exercise the test more.

Manager decision (2026-06-11): Path A authorized the minimal test fix
plus continue the cycle. The fix is in the test file only; production
code is unchanged.

## Defect 1: ambiguous debug_admit_checkpoint_for_tests call

Test file: `tests/test-cache-controller.cpp`.

Errors at compile time:

- line 1804: error C2668 `debug_admit_checkpoint_for_tests` ambiguous
  call to overloaded function. Call was
  `ctrl.debug_admit_checkpoint_for_tests(64, 0, 2)`.
- line 2357: error C2668 same root cause. Call was
  `ctrl.debug_admit_checkpoint_for_tests(64, 0, 3)`.

Three overloads exist in the merged
`tools/server/server-cache-hybrid.h:331-333`:

- `debug_admit_checkpoint_for_tests(size_t, size_t)` (2 args)
- `debug_admit_checkpoint_for_tests(size_t, size_t, bool fail_after_descriptor)` (3 args, bool)
- `debug_admit_checkpoint_for_tests(size_t, size_t, int64_t token_span_end)` (3 args, int64_t)

The literal `2` or `3` is ambiguous between `bool` (with implicit
conversion) and `int64_t`. The comment at line 2353 (preserved)
indicates the third (int64_t) overload was the intended target
(`token_span_end = 3` forces the restore token count to a value below
the full token count). The line 1804 call expects a restore token count
of 2 per the `debug_first_checkpoint_restore_token_count_for_tests() == 2`
assertion on the next line, so it is also the int64_t overload.

### Fix 1 (Defect 1)

Cast the literal to `int64_t` to disambiguate. Diff (full):

```text
@@ tests/test-cache-controller.cpp line 1804 (test_stage9_checkpoint_restore_uses_descriptor_span):
-    assert(ctrl.debug_admit_checkpoint_for_tests(64, 0, 2));
+    // Stage 14 test fix: cast literal to int64_t to disambiguate the
+    // (size_t, size_t, int64_t token_span_end) overload from the
+    // (size_t, size_t, bool fail_after_descriptor) overload.
+    assert(ctrl.debug_admit_checkpoint_for_tests(64, 0, int64_t(2)));

@@ tests/test-cache-controller.cpp line 2357 (C2_test_admit_checkpoint_with_explicit_token_span_end):
-    assert(ctrl.debug_admit_checkpoint_for_tests(64, 0, 3));
+    // Stage 14 test fix: cast literal to int64_t to disambiguate the
+    // (size_t, size_t, int64_t token_span_end) overload from the
+    // (size_t, size_t, bool fail_after_descriptor) overload.
+    assert(ctrl.debug_admit_checkpoint_for_tests(64, 0, int64_t(3)));
```

Behavior is unchanged; the int64_t overload is the one the test was
calling all along (the bool overload would have caused a different
return value, and the assertions on the next lines would have failed at
runtime before the merge).

## Defect 2: removed enum value payload_debug_fault::evicted_residency

Test file: `tests/test-cache-controller.cpp`.

Error at compile time:

- line 1957: error C2838 `evicted_residency` illegal qualified name in
  member declaration. Companion diagnostic: error C2065
  `evicted_residency` undeclared identifier.

The merged `payload_debug_fault` enum in
`tools/server/server-cache-hybrid.h:136-150` does not declare
`evicted_residency`. Existing members:

- `unsupported_version`, `unsupported_kind`, `zero_target_size`,
  `target_size_mismatch`, `missing_target_bytes`, `bad_store_ref`,
  `missing_hot_record`, `owner_mismatch`, `cold_residency`,
  `unexpected_draft_for_target_only`, `missing_draft_for_pair`,
  `draft_size_mismatch`, `draft_checksum_mismatch`,
  `demoting_residency`, `promoting_residency`.

The test at `test_stage10_payload_debug_fault_injection()` had a
`// Evicted residency` block that called
`debug_inject_first_payload_fault_for_tests(payload_debug_fault::evicted_residency)`
and checked `n_evicted_payload_descriptors == 1`. The intended behavior
is no longer represented in the current enum (only `cold_residency` and
the transient `demoting_residency` / `promoting_residency` exist).
This is a pre-existing test defect; the local parent `02db7a768` had
the same enum and the same test code, so the test would not have
compiled against the local parent either. The build/ tree that
recorded the 61/69 (88%) measurement used an older test binary that
pre-dated the third `int64_t` overload and likely the renamed enum
collapse.

### Fix 2 (Defect 2)

Comment out the `// Evicted residency` block with a one-line comment
explaining the disabled state. The constraint allows commenting out a
test case when the enum was removed; the test function itself stays.
Diff (full):

```text
@@ tests/test-cache-controller.cpp line 1953 (test_stage10_payload_debug_fault_injection):
-    // Evicted residency
+    // Evicted residency case removed: payload_debug_fault::evicted_residency
+    // is not in the current enum (server-cache-hybrid.h). Test disabled to
+    // unblock the build; see test-report-20260611-01-fixes.md for context.
+    /*
     {
         hybrid_cache_controller ctrl(params, 2, 1000, nullptr, nullptr);
         ctrl.debug_add_entry_for_tests(create_tokens({1}), false, "fault-evicted", 64, 0);
         assert(ctrl.debug_inject_first_payload_fault_for_tests(payload_debug_fault::evicted_residency));
         json stats = ctrl.get_stats();
         assert(stats["n_evicted_payload_descriptors"] == 1);
     }
+    */
```

The other six cases in the same test function (`Cold residency`,
`Empty draft preimage failure`, `Unsupported empty clear`,
`Rollback failure`, `Transaction with all failure flags`,
`Transaction success path`) are unchanged and still exercise the
merged code paths.

## Build result (post test fix)

Command: `cmake --build build-cov --config Release`. Log:
[build-cov-rebuild-stage14-testfix-20260611-01.log](build-cov-rebuild-stage14-testfix-20260611-01.log).

- Result: PASS. MSBuild exit code 0.
- 106 executables built (all `*.exe` targets in build-cov/bin/Release).
- No MSVC errors. test-cache-controller.cpp compiled successfully.
- Files: `git diff --check` clean on the modified test file.
- Encoding: LF-only (LF=2709, CRLF=0, no BOM, no non-ASCII) verified
  with byte scan.

## ctest result (post test fix, on build-cov)

Command: `ctest --test-dir build-cov -C Release --output-on-failure`.
Log: [ctest-buildcov-stage14-testfix-20260611-01.log](ctest-buildcov-stage14-testfix-20260611-01.log).

- 67 of 69 tests passed.
- 2 tests failed (both `***Exception: Exit code 0xc0000409` /
  `STATUS_STACK_BUFFER_OVERRUN` from a failed `assert()`):
  - 37 - test-cache-controller (NEW failure, see below)
  - 48 - test-stage10-policy-lru (pre-existing, not caused by this fix)
- 0 not-run tests (the prior 7 not-run tests in the original report
  were from a different build configuration; the current ctest run on
  build-cov reports 69 of 69 tests run).

### NEW pre-existing test failure (separate from Defects 1 and 2)

Test 37 test-cache-controller fails at the very first assertion of
`test_hybrid_rejects_partial_blob_match()` at line 571:

```text
Assertion failed: ctrl.debug_find_match_tokens_for_tests(create_tokens({1, 2, 3, 4, 5})) == 4,
file D:\source\llama.cpp-jet\tests\test-cache-controller.cpp, line 571
```

The hybrid cache logs `descriptor validation failed (admission
validation failed)` immediately before the assertion, indicating the
merged admission code path rejects the entry that the test adds with
`debug_add_entry_for_tests(create_tokens({1, 2, 3, 4}))`. The lookup
therefore returns a value other than 4.

This defect is:

- Pre-existing in the local parent test code: the assertion was
  authored against the pre-merge admission behavior. The merged
  admission code path (in `server-cache-hybrid.cpp`) has stricter
  validation that the test was not updated for.
- NOT introduced by the test fix in this commit. The test fix touched
  lines 1804, 1953-1965, and 2357. Line 571 is in a different test
  function (`test_hybrid_rejects_partial_blob_match`) and was not
  modified. The build passes; the test crashes at runtime.
- Exposed by the merge because the merge brought in the upstream
  admission changes alongside the upstream `has_inp_video` struct
  change. The pre-merge `build-cov/bin/Release/test-cache-controller.exe`
  binary (dated 2026-06-07) was built against the pre-merge headers
  and static libs, so it passed at that time. With the merged static
  libs in place, the new admission path runs and the test fails.

Per the developer improvement memory "Real-merge build halt may mask
other latent duplicates", the build halt at the C2668/C2838/C2065
errors in this same file masked this runtime defect. The fix the
Manager authorized in this session (Defects 1 and 2) unblocked the
build; the next layer of merged code is now exercised and surfaces
this assertion failure.

This defect is OUT OF SCOPE for the test fix authorized by the
Manager's Path A decision. A correct fix likely requires either
updating the test to match the new admission validation contract or
adjusting the production code to restore the pre-merge behavior.
Both are separate Manager decisions.

## T114 and T114a coverage

BLOCKED. The coverage run was not executed. The closure contract
target is `build-cov/bin/Release/ctest-runner.exe` which links
`test-cache-controller.exe` and friends. The coverage run would
include the failing test (currently crashes the test binary) and
cannot produce a valid rate.

The prior valid coverage numbers (pre-merge) are:

- 20260605-02: combined 0.8553 (5436/6356), product 0.7035 (2090/2971)
- 20260607-02: combined 0.9276 (6546/7057), server probe skipped

These are pre-merge baselines and are not reclassified by this
session. The cycle is not ready for Step 6 merge log + closure
until the new defect at line 571 is resolved and T114/T114a can be
re-run on the post-fix tree.

## Fix commit

Test fix commit: in the first commit in the Stage 14 test-fix series
(parent = d45ef1e73, subject = "Stage 14 test fix: pre-existing
test-cache-controller.cpp defect exposed by merge (Defects 1, 2)").
The docs commit (the second commit) updates this part 02 file plus
the main fixes file pointer and the test report; the docs commit's
SHA is not pinned in this file because the file is part of the docs
commit, so any in-file reference to the docs commit SHA would change
with each amend.

## Handoff

- Defects 1 and 2 (compile errors in test-cache-controller.cpp):
  FIXED. Test file changes are 13 insertions and 3 deletions across
  three locations (lines 1804, 1953-1965, 2357). LF-only ASCII, no
  BOM, `git diff --check` clean.
- build-cov rebuild: PASS (MSBuild exit code 0, 106 executables
  built, no MSVC errors).
- ctest build-cov: 67 of 69 PASS. Two failures, both
  STATUS_STACK_BUFFER_OVERRUN (assertion failure) with exit code
  0xc0000409:
  - test-stage10-policy-lru: pre-existing, unchanged from the
    pre-fix ctest (no new failure).
  - test-cache-controller line 571: NEW pre-existing defect
    exposed by the merge (admission validation rejects what the
    test adds). Not caused by the test fix.
- T114 / T114a: BLOCKED on the new line 571 defect. Coverage run
  not executed.
- build/ rebuild: NOT ATTEMPTED. The static-lib link target is
  shared between build-cov and build/; the new line 571 defect
  would also surface on build/ because the test binary uses the
  same production code paths.
- Next gate: Manager decision on the new pre-existing defect at
  test-cache-controller.cpp line 571. Options:
  1. Defer to a Stage 11/13 corrections cycle: open a Developer
     task to investigate the admission validation contract change
     and either update the test or adjust the production code;
     then run QA T114/T114a on the resulting tree.
  2. Apply a Step 3 developer-side fix now: investigate the
     admission change in `server-cache-hybrid.cpp`, decide whether
     the test is correct (and the production code regressed) or
     the test is stale (and the production code is correct), and
     apply the appropriate fix. Requires Manager authorization
     beyond the current Path A scope.
  3. Skip the test: replace the assertion with a `printf` skip
     marker. Not recommended; this is a real assertion, not a
     flaky test.
- After the new defect is resolved: cycle ready for Step 6 merge
  log + closure.

## Part 02 follow-up: line 571 defect investigation (2026-06-11)

### Verdict

Verdict: PRE-EXISTING_TEST_BUG

### Evidence

- Test function (line 571):
  `test_hybrid_rejects_partial_blob_match()` at
  `tests/test-cache-controller.cpp:560-575`. The function body is
  byte-for-byte identical between the local parent `02db7a768` and
  `HEAD` (verified via
  `git diff 02db7a768 HEAD -- tests/test-cache-controller.cpp`,
  which returns empty diff for the function body at line 560-575).
- Input shape (debug_add_entry_for_tests call): The test calls
  `ctrl.debug_add_entry_for_tests(create_tokens({1, 2, 3, 4}))`
  (1-argument form) at line 565. This delegates to the 5-argument
  form with defaults `target_bytes=0, draft_bytes=0`
  (`tools/server/server-cache-hybrid.cpp:937-939`). The constructed
  target vector is empty (size 0) and the draft vector is empty
  (size 0).
- Admission code path that rejects:
  `hybrid_cache_controller::validate_descriptor_against_record` at
  `tools/server/server-cache-hybrid.cpp:2609-2682`. The check
  `if (record.target.empty() || descriptor.target_size_bytes == 0)
  { return fail("missing target payload"); }` at line 2638-2640
  rejects the entry. `attach_payload` at
  `tools/server/server-cache-hybrid.cpp:2697-2736` calls
  `validate_descriptor_against_record` and on failure logs
  "descriptor validation failed (admission validation failed)" via
  `record_payload_validation_failure` (line 3053) and returns false.
  `debug_add_entry_for_tests` (line 950) checks the return value
  and returns without adding the entry to the cache.
- Upstream commits that touched the admission path: NONE. The
  merge range `6ddc9430..18ef86ece` did not touch
  `tools/server/server-cache-hybrid.cpp`,
  `tools/server/server-cache-hybrid.h`, or
  `tests/test-cache-controller.cpp` (verified via
  `git log --oneline 6ddc9430..18ef86ece -- <file>` and
  `git diff 6ddc9430 18ef86ece -- <file>`, both returning empty).
- Pre-merge behavior (from 02db7a768): The
  `validate_descriptor_against_record` function at
  `02db7a768:tools/server/server-cache-hybrid.cpp` is byte-for-byte
  identical to the merged function (verified via
  `git diff 02db7a768 HEAD -- tools/server/server-cache-hybrid.cpp`,
  which returns empty for this function). The "missing target
  payload" check was introduced in Stage 5 complete
  (commit `e8297cafe`, 2026-05-28), which predates the local
  parent `02db7a768` (2026-06-05). The test was authored in
  Stage 3 (commit `db93bb030`) against a contract where empty
  target/draft was allowed. Stage 5 added the "missing target
  payload" validation rule without updating the test.
- Merged behavior: IDENTICAL to pre-merge behavior. The code in
  `tools/server/server-cache-hybrid.cpp`,
  `tools/server/server-cache-hybrid.h`, and
  `tests/test-cache-controller.cpp` is byte-for-byte identical
  between `02db7a768` and `HEAD` (with the exception of the test
  fix at lines 1804, 1953-1965, 2361, which do not touch line 565
  or the `test_hybrid_rejects_partial_blob_match` function).

### Affected prior-stage contract

Contract: Stage 5 descriptor validation (the
`validate_descriptor_against_record` function and its
"missing target payload" check).
Owner: Stage 5 complete (commit `e8297cafe`, 2026-05-28).
What changed: Stage 5 introduced the descriptor validation
contract that requires `record.target` to be non-empty and
`descriptor.target_size_bytes > 0` for admission to succeed.
The test `test_hybrid_rejects_partial_blob_match` was authored
in Stage 3 before this contract was established and was not
updated when Stage 5 added the validation rule. The test
violates the Stage 5 contract by using the 1-argument
`debug_add_entry_for_tests` which defaults to
`target_bytes=0`.

### Recommended fix

Minimal test fix (1 line change at line 565). Change the
`debug_add_entry_for_tests` call from the 1-argument form
(defaults to `target_bytes=0, draft_bytes=0`) to the
5-argument form with `target_bytes=64, draft_bytes=0`. This
matches the pattern used by other tests in the same file
(e.g., line 172, 202, 833). The entry will then be admitted
with a valid target payload, and the subsequent
`debug_find_match_tokens_for_tests` assertions will succeed
as originally intended.

Diff (full):

```text
@@ tests/test-cache-controller.cpp line 565 (test_hybrid_rejects_partial_blob_match):
-    ctrl.debug_add_entry_for_tests(create_tokens({1, 2, 3, 4}));
+    // Stage 14 line 571 fix: use 5-arg form with non-zero target_bytes
+    // so the Stage 5 descriptor validation contract (missing target
+    // payload check in validate_descriptor_against_record) admits the
+    // entry. The 1-arg form defaults to target_bytes=0 which the
+    // validation rejects, causing the lookup to return -1 and the
+    // assertion at line 571 to fail.
+    ctrl.debug_add_entry_for_tests(create_tokens({1, 2, 3, 4}), false, "", 64, 0);
```

Note: The 2026-06-07 test log
(`test-cache-controller-static-20260607-01.log`) shows this
test passing, which is inconsistent with the code-level
analysis. The most likely explanation is that the 2026-06-07
test binary was built from a version of the source tree
where the test was passing (e.g., uncommitted changes that
were not preserved, or a cached static lib from an earlier
build with different source). The current code is
byte-for-byte identical to `02db7a768`, and the validation
rule rejects the test's input. The fix above updates the
test to match the Stage 5 contract.

### Files to modify

- tests/test-cache-controller.cpp (test fix, 1 line at 565)

### Next gate

- Developer applies the test fix at line 565 in a fresh
  session: replace the 1-arg `debug_add_entry_for_tests`
  call with the 5-arg form `(create_tokens({1, 2, 3, 4}), false, "", 64, 0)`.
- Developer rebuilds build-cov (cmake --build build-cov --config Release).
- Developer reruns ctest (ctest --test-dir build-cov -C Release --output-on-failure).
- Expected: 68/69 PASS (test-cache-controller passes; test-stage10-policy-lru
  remains pre-existing failure unchanged).
- Developer runs T114/T114a coverage on the post-fix tree.
- If T114/T114a meets the 80% hybrid-path coverage threshold:
  cycle proceeds to Step 6 merge log + closure.
- If T114/T114a does not meet threshold: bug-fix loop per the
  coverage rule.

## Part 02 line 571 fix (2026-06-11)

### Fix Verdict

Verdict: PRE-EXISTING_TEST_BUG (Architect)

### Fix Applied

Commit 998ae00fa (HEAD +1). Diff
(`tests/test-cache-controller.cpp:560-585`):

```text
@@ tests/test-cache-controller.cpp line 565 (test_hybrid_rejects_partial_blob_match):
-    ctrl.debug_add_entry_for_tests(create_tokens({1, 2, 3, 4}));
-
+    // Stage 14 line 571 fix: use metadata form so entry namespace matches lookup.
     prepared_prompt_metadata meta;
-    GGML_UNUSED(meta);
+    ctrl.debug_add_entry_for_tests(create_tokens({1, 2, 3, 4}), meta);
+
```

The Architect's recommended diff used the 5-arg form
`(tokens, false, "", 64, 0)`. Verification showed that
5-arg form with the `""` namespace falls back to
`compute_namespace_id()` (no metadata), which produces a
different namespace string from what
`debug_find_match_tokens_for_tests` computes via
`compute_namespace_id(metadata)`. The strict namespace
compatibility check in `find_best_match` would skip the
entry even when admitted. The metadata form
(`debug_add_entry_for_tests(tokens, meta)`) uses
`compute_namespace_id(metadata)` directly, matching the
lookup namespace, and admits a 1-byte target payload that
passes the Stage 5 "missing target payload" check.

### Build result

Command: `cmake --build build-cov --config Release`. Log:
[build-cov-rebuild-stage14-line571-20260611-03.log](build-cov-rebuild-stage14-line571-20260611-03.log).

- Result: PASS. MSBuild exit code 0.
- 106 executables built (all `*.exe` targets in build-cov/bin/Release).
- No MSVC errors. test-cache-controller.cpp compiled successfully.
- Files: `git diff --check` clean on the modified test file.
- Encoding: LF-only (LF=2711, CRLF=0, no BOM, no non-ASCII)
  verified with byte scan.

### ctest result (post line 571 fix, on build-cov)

Command: `ctest --test-dir build-cov -C Release --output-on-failure`.
Log: [ctest-buildcov-stage14-line571-20260611-03.log](ctest-buildcov-stage14-line571-20260611-03.log).

- 67 of 69 tests passed.
- 2 tests failed (both `***Exception: Exit code 0xc0000409` /
  `STATUS_STACK_BUFFER_OVERRUN` from a failed `assert()`):
  - 37 - test-cache-controller (line 586: `test_hybrid_prefix_index_short_entry`).
    The line 571 fix passes test 17 (line 571 assertion is no
    longer the failure point). The test binary now aborts at
    test 18 because test 18 has the same 1-arg form
    `debug_add_entry_for_tests(create_tokens({7, 8}))` issue
    (1-arg form delegates to 5-arg with target_bytes=0, which
    Stage 5 validation rejects). Other tests with the same
    1-arg form pattern: lines 608, 609, 629, 630, 638, 639, 1085
    in `tests/test-cache-controller.cpp`. These are out of
    scope for the line 571 fix (would require 7+ additional
    call-site changes, exceeding the 5-line change budget
    without Manager decision).
  - 48 - test-stage10-policy-lru (pre-existing, unchanged from
    the pre-fix ctest, no new failure).

The expected 68/69 result documented in this fixes file's
"Next gate" section was based on the assumption that only
line 571 had the 1-arg form defect. The actual scope of
the 1-arg form defect spans 7+ call sites across multiple
test functions; fixing only line 571 moves the test binary
abort point from test 17 to test 18, leaving the ctest
result at 67/69.

### Coverage result

BLOCKED. The coverage run was not executed. The closure
contract target is `build-cov/bin/Release/ctest-runner.exe`
which links `test-cache-controller.exe` and friends. The
coverage run would include the failing test 18 (currently
crashes the test binary) and cannot produce a valid rate.

The 1-arg form defect must be fixed across all affected
test sites (or a single targeted production-side fix must
be applied) before T114/T114a can be re-run.

### Line 571 Handoff

- Line 571 test fix: APPLIED. Commit 998ae00fa. 3 insertions
  and 3 deletions. LF-only ASCII, no BOM, `git diff --check`
  clean. Test 17 now passes.
- build-cov rebuild: PASS (MSBuild exit code 0, 106 executables
  built, no MSVC errors).
- ctest build-cov: 67 of 69 PASS. Two failures, both
  STATUS_STACK_BUFFER_OVERRUN (assertion failure) with exit
  code 0xc0000409:
  - test-cache-controller line 586 (test 18,
    `test_hybrid_prefix_index_short_entry`): same 1-arg form
    defect as line 571, now exposed because the test 17 abort
    point moved. NOT a regression; same root cause.
  - test-stage10-policy-lru: pre-existing, unchanged.
- T114 / T114a: BLOCKED. The line 571 fix is necessary but
  not sufficient; the 1-arg form defect spans 7+ call sites
  in `tests/test-cache-controller.cpp` (lines 593, 608, 609,
  629, 630, 638, 639, 1085) and one of them is exercised by
  the test binary before coverage can complete.
- Next gate: Manager decision on the broader 1-arg form
  defect. Options:
  1. Apply a Step 3 developer-side fix now: switch the 7+
     affected test call sites to either the 5-arg form with
     matching namespace (or use the metadata form), then
     run QA T114/T114a on the resulting tree. Requires
     Manager authorization beyond the line 571 fix scope
     (more than 5 lines of test file changes).
  2. Defer to a Stage 11/13 corrections cycle: open a
     Developer task to fix the 1-arg form pattern in a
     follow-up session.
  3. Adjust the production code to make the 1-arg form
     work as the original Stage 3 contract intended:
     remove the "missing target payload" check for the
     legacy 1-arg form path. This would restore the
     pre-merge-merge behavior but contradicts the Stage 5
     descriptor validation contract.
- After the broader 1-arg form defect is resolved: cycle
  ready for Step 6 merge log + closure.

## Part 02 batch fix (2026-06-11)

### Verdict

PRE-EXISTING_TEST_BUG (Architect). 4 strict 1-arg call sites
fixed with 2-arg metadata form. build PASS. ctest 67/69
(test 20 line 609 crash; pre-existing test-stage10-policy-lru
crash). T114/T114a remain BLOCKED on a broader substantive
issue: test 20's 2-arg with bool form cannot be fixed with
the 2-arg metadata form because the metadata form loses
`protected_root`.

### Call sites fixed

Commit c390a271e. Diff
(`tests/test-cache-controller.cpp:579-633, 1084-1091`):

```text
@@ tests/test-cache-controller.cpp line 582 (test 18: test_hybrid_prefix_index_short_entry):
-    ctrl.debug_add_entry_for_tests(create_tokens({7, 8}));
-
+    // Stage 14 batch test fix: 1-arg form delegates to 5-arg with target_bytes=0,
+    // rejected by Stage 5 admission validation (missing target payload). Use the
+    // 2-arg metadata form so the entry namespace matches the lookup namespace
+    // (compute_namespace_id(metadata)) and the entry is admitted.
     prepared_prompt_metadata meta;
-    GGML_UNUSED(meta);
+    ctrl.debug_add_entry_for_tests(create_tokens({7, 8}), meta);

@@ tests/test-cache-controller.cpp line 597 (test 19: test_hybrid_lru_eviction_by_token_limit):
-    ctrl.debug_add_entry_for_tests(create_tokens({1, 2}));
-    ctrl.debug_add_entry_for_tests(create_tokens({3, 4}));
+    // Stage 14 batch test fix: 1-arg form delegates to 5-arg with target_bytes=0,
+    // rejected by Stage 5 admission validation. Use the 2-arg metadata form so
+    // both entries share the same default-namespace and are admitted.
+    prepared_prompt_metadata meta;
+    ctrl.debug_add_entry_for_tests(create_tokens({1, 2}), meta);
+    ctrl.debug_add_entry_for_tests(create_tokens({3, 4}), meta);

@@ tests/test-cache-controller.cpp line 1074 (test 23: test_hybrid_lookup_edge_paths):
-    ctrl.debug_add_entry_for_tests(create_tokens({4, 5, 6}));
+    // Stage 14 batch test fix: 1-arg form delegates to 5-arg with target_bytes=0,
+    // rejected by Stage 5 admission validation. Use the 2-arg metadata form so
+    // the entry namespace matches the lookup namespace and is admitted.
+    prepared_prompt_metadata meta;
+    ctrl.debug_add_entry_for_tests(create_tokens({4, 5, 6}), meta);
```

Test 20 (line 618, 619, 627, 628) was NOT fixed with the
2-arg metadata form because the metadata form does not set
`entry.protected_root` (always defaults to false), so the
test's `protected_root`-based eviction assertions would
fail at a different point. A comment was added to test 20
documenting the substantive issue. Test 23 line 1071
(3-arg form) was NOT fixed because it is out of scope for
the strict 1-arg batch and the binary never reaches it
(crashes at test 20 first).

### Build result

Command: `cmake --build build-cov --config Release`. Log:
`build-cov-rebuild-stage14-batch-20260611-01.log` (in
test_reports).

- Result: PASS. MSBuild exit code 0.
- 106 executables built (no MSVC errors).
- `git diff --check` clean on the modified test file.
- LF-only ASCII, no BOM, no non-ASCII.

### ctest result

Command: `ctest --test-dir build-cov -C Release
--output-on-failure`. Log:
`ctest-buildcov-stage14-batch-20260611-02.log` (in
test_reports).

- 67 of 69 tests passed.
- 2 tests failed (both STATUS_STACK_BUFFER_OVERRUN):
  - 37 - test-cache-controller line 609 (test 20
    `test_hybrid_protected_eviction_paths`): 2-arg with
    bool form delegates to 5-arg with target_bytes=0,
    rejected by Stage 5 admission validation. The 2-arg
    metadata form cannot fix this test because the
    metadata form does not set `entry.protected_root`,
    so the test's `protected_root`-based eviction
    assertions would fail at a different point. This is
    a SUBSTANTIVE ISSUE requiring Manager decision.
  - 48 - test-stage10-policy-lru: pre-existing, unchanged.

The test binary aborts at test 20 line 609, so tests 21-74
in the binary never run. Test 23 (line 1074 fix) is
expected to pass when test 20 is resolved.

### T114 and T114a result

BLOCKED. Coverage run not executed. The test binary still
crashes at test 20 line 609. The 2-arg with bool form
defect must be resolved (either via a production code
change to add a new debug helper that accepts
`(tokens, metadata, protected_root)`, or via a test
rewrite that does not depend on `protected_root`) before
T114/T114a can be re-run.

### Handoff

- 4 strict 1-arg call sites fixed: lines 582, 597, 598,
  1074. Commit c390a271e. 23 insertions and 6 deletions.
  LF-only ASCII, no BOM, `git diff --check` clean.
- build-cov rebuild: PASS (106 executables, no errors).
- ctest build-cov: 67/69 (test 20 line 609 + pre-existing
  test-stage10-policy-lru).
- T114 / T114a: BLOCKED on test 20 substantive issue
  (2-arg with bool form cannot be fixed with 2-arg
  metadata form because metadata form loses
  `protected_root`).
- Next gate: Manager decision on test 20 substantive
  issue. Options:
  1. Add a new debug helper `(tokens, metadata,
     protected_root)` to `server-cache-hybrid.h` -
     PRODUCTION code change. This is the only way to
     preserve `protected_root` while matching the
     lookup's namespace.
  2. Rewrite test 20 to not depend on `protected_root`
     - significant test rewrite. The test would need to
     test pure LRU eviction without the
     `protected_root` distinction.
  3. Defer to a Stage 11/13 corrections cycle.
- After the test 20 defect is resolved: cycle ready for
  Step 6 merge log + closure.
