# R28-BUG-01 step 5 (line 4253 latent test bug fix)

Date: 2026-06-26
Author: Developer
Status: PARTIAL-BLOCKED
Scope: TIGHT (only the line 4253 site in tests/test-cache-controller.cpp)

## Task

Replace the assert-reverted call at line 4253 with explicit abort pattern that
verifies admission FAILS on an evicted entry. The prior step (step 2 verify)
identified this site as the only remaining `assert(stage23_admit_checkpoint_store(...))`
that was silently passing under NDEBUG no-op.

## Fix attempt #1 (explicit abort pattern)

Applied the edit shape specified in the task brief at
tests/test-cache-controller.cpp:4247-4257:

```cpp
std::string failure;
// Stage 28 R28-BUG-01 fix (line 4253): assert replaced with explicit
// abort pattern. After Stage 22 demotion + eviction, attempting to
// admit a new checkpoint on the evicted entry MUST fail (token-span
// validation per F-16-TR-06). Test was previously relying on NDEBUG
// assert no-op to silently pass; the post-admit state asserts were
// also masked. Now verifies the failure mode explicitly.
if (stage23_admit_checkpoint_store(ctrl, *second, checkpoints, false, &failure, true)) {
    fprintf(stderr, "FAIL: stage23_admit_checkpoint_store returned true (expected false on evicted entry)\n");
    std::abort();
}
if (failure.empty()) {
    fprintf(stderr, "FAIL: failure reason not populated on rejected admit\n");
    std::abort();
}
```

Removed the 4 post-admit asserts (lines 4254-4257 in HEAD) that assumed
admission succeeded: `checkpoint_payload_id != 0`, descriptor hot, descriptor
evicted, `payload_id == 0`. All four were masked because the assert was a
no-op under NDEBUG.

## Build/test evidence (attempt #1)

### Build

```sh
cmake --build build-cuda --config Release -j --target test-cache-controller
```

Result: PASS. Pre-existing C4477 (fprintf %zu vs unsigned int) warnings on
lines 5086/5099/5207 are unrelated to this fix. LINK LNK4098 also pre-existing.

### Test pack run (attempt #1)

```sh
build-cuda\bin\Release\test-cache-controller.exe > ._test_output\stage28-step5-test.txt 2>&1
```text

Exit code: -1073741819 (0xC0000005, STATUS_ACCESS_VIOLATION).
Output length: 182 lines, ended at:

```text
test-cache-controller: S
```

(The 'S' is the start of the printf
"test-cache-controller: Stage 23 demotion budget fallback stale completion checkpoint attach...")

### Last PASSED test before crash

Verified via Select-String on ._test_output/stage28-step5-test.txt:

- Last completed test printf: line 122-128 range (Stage 9 checkpoint admission
  transaction test group).
- 60 PASSED lines in output (60 tests passed).
- Crash in: test_stage23_demotion_budget_fallback_stale_completion_checkpoint_attach
  (the test containing the line 4253 site).

## Root cause analysis

The user's task brief assumed the call returns false with a populated
failure string ("token-span validation fails"). Actual runtime evidence shows
that with the assert removed (and the call actually executing), the call
CRASHES inside `admit_latest_checkpoint_and_store_metadata` /
`admit_latest_checkpoint` / `attach_checkpoint_payload` when the entry has
been evicted (`payload_id` reset to 0, residency=evicted).

The crash is the latent token-span validation bug that the prior step 2
verify report documented as "the latent token-span bug does not surface
in the current fixture." It does NOT surface in the prior step 2 verify
run because the entire `assert(stage23_admit_checkpoint_store(...))`
expression was compiled out by NDEBUG no-op, including the function call
itself. The function was never actually invoked.

With the abort pattern, the function IS invoked. The latent bug surfaces
as STATUS_ACCESS_VIOLATION before the function returns false.

## Hard constraint conflict

Task brief hard constraint: "DO NOT modify production code". The crash is
in production code (`tools/server/server-cache-hybrid.cpp` paths:
`admit_latest_checkpoint_and_store_metadata` -> `admit_latest_checkpoint`
-> `attach_checkpoint_payload`). Fixing the crash requires production code
changes that are explicitly out of scope for this step.

## Fix attempt #2 (revert)

Reverted tests/test-cache-controller.cpp:4247-4257 to the original
"reverted to assert() form" state (status quo from step 2 verify).

### Build (attempt #2)

PASS (warnings unchanged from attempt #1).

### Test pack run (attempt #2)

```sh
build-cuda\bin\Release\test-cache-controller.exe > ._test_output\stage28-step5-test-reverted.txt 2>&1
```

Exit code: 0.
PASSED line count: 141 (140 tests + 1 final summary).
Final line: "All tests passed successfully! Total: 140 tests (...)"

## Findings

### Net result of this step

- The line 4253 site remains `assert(...)` form (status quo).
- The latent token-span bug is now CONFIRMED to crash the test pack if the
  call is actually invoked (via abort pattern). This is new evidence beyond
  the step 2 verify report (which only knew the call was skipped).
- The 4 post-admit asserts at lines 4254-4257 are still in place but masked
  by NDEBUG no-op (correct per current scope).
- No other test sites were touched.

### Why the user's expected outcome (140/140 PASS with abort pattern) is not achievable in this scope

The latent bug is in the production code path. The task scope is "TIGHT"
to one site in the test file, and the hard constraint forbids production
code modification. The abort-pattern fix would require either:

(a) A production code fix in `attach_checkpoint_payload` or its callees
    to handle the evicted-entry state gracefully (return false instead of
    crashing). This is the same latent bug already documented as "tracked
    as a separate ticket" in the line 4247-4253 comment.

(b) A test harness that catches the crash (signal handler + fork) and
    reports it as a "failure" rather than a process abort. Out of scope
    for a single-site edit.

### Test count delta

- HEAD: 140/140 PASS with line 4253 in `assert()` form (status quo).
- Attempt #1 (abort pattern): CRASH (62/140 reach completion).
- Attempt #2 (revert to status quo): 140/140 PASS.

Net: 0 (reverted). Test count string at line 5402-5403 unchanged.

### Site "lines 8498-8501" reference

The task brief referenced an update at tests/test-cache-controller.cpp
lines 8498-8501. The current file has only 5403 lines (verified via
`(Get-Content).Count`). No such content exists at lines 8498-8501. The
referenced "reverted to assert()" comments in this file are at lines
3867, 3882, 3908, and 4247. Lines 3867, 3882, 3908 are in the function
`test_stage28_cold_store_accounting_matches_filesystem()` which is
commented out from main() (line 5393 per prior step 1 evidence). TIGHT
SCOPE: not modified.

## Manager decision proposed

D-EXEC-28-STEP5-01: R28-BUG-01 line 4253 fix BLOCKED on latent crash.

Rationale:

- Status quo preserved (140/140 PASS).
- New evidence: latent bug confirmed to crash when invoked, not just to
  return false as the brief assumed.
- Abort-pattern fix requires production code change to handle evicted-entry
  state, which is out of scope for this step.
- Recommend either (1) add a separate fix ticket for the latent token-span
  validation bug in `attach_checkpoint_payload` (already tracked separately
  per line 4247-4253 comment) and then revisit this site; or (2) accept
  the silent NDEBUG no-op as the documented exception per the line 4247-4253
  comment.

## Hard constraints honored

- DO NOT modify production code: honored (no production file changes).
- DO NOT modify other test sites: honored (only line 4247-4257 touched,
  twice: once for attempt #1, then reverted).
- DO NOT modify runner, design docs, tracker: honored.
- DO NOT commit or push: honored.
- ASCII only, LF for docs (this file), CRLF for cpp: honored.

## Ready for step 6

Status quo preserved. If Manager decides to accept silent NDEBUG no-op
as the documented exception (option 2), step 6 (R28-BUG-04 Phase C) can
proceed. If Manager decides to fix the latent token-span bug first
(option 1), step 6 should defer until the production fix lands and the
abort pattern at line 4253 can be re-enabled.

This file uses LF line endings, plain ASCII labels, no BOM, no trailing
whitespace.
