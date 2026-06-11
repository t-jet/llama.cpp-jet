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
