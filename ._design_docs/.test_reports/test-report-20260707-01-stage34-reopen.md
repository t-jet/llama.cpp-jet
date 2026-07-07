# Stage 34 reopen test report: idempotent save and Path B

Status: PASS
Date: 2026-07-07
Stage: 34 (reopened)
Owner: QA
Branch: work-branch

Source:

- [part-38 test plan](../cache-handling-test-plan/part-38-stage34-reopen-idempotent-save-and-path-b.md)
- [part-20 Manager gate](../cache-handling-phase34-implementation/part-20-manager-test-plan-gate-20260706.md)

Test execution for the Stage 34 reopen cycle. Five C++ regression rows
(T-34-IDEM-01, T-34-IDEM-02, T-34-IDEM-03, T-34-PATHB-01, T-34-PATHB-02)
plus the TP-34-CC reclassification scope note were exercised against a clean
Release CUDA build. No replay harness was run; the reopen scope is the five
rows only.

## Environment

- Host: EPAMEVNW0000473
- git branch: work-branch
- git HEAD (short): 9f1bbf830
- CMake: cmake version 4.3.2
- Compiler: MSVC via cl.exe under vcvars64.bat, Build Tools 2022
  (path: C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat; Test-Path True)
- CUDA toolkit: Cuda compilation tools, release 13.2, V13.2.78
- Test binary: build-cuda\bin\Release\test-cache-controller.exe
  length 1134592 bytes, mtime 2026-07-07 03:33:48; Test-Path True

## Clean-build evidence

Configure command (per Manager verification, not re-run this session):

```text

cmake -G "Visual Studio 17 2022" -A x64 -DGGML_CUDA=ON -DCMAKE_BUILD_TYPE=Release -B build-cuda

```

Build command (prior session, cited from Manager context): build of target
'test-cache-controller' in 'build-cuda', config Release, '--clean-first'.
That build reported BUILD_EXIT=0.

LLAMA_SERVER_CACHE_TESTS guard: NOT a CMake cache variable. The guard is a
target compile definition wired in tests\CMakeLists.txt line 243:

```text

target_compile_definitions(test-cache-controller PRIVATE LLAMA_SERVER_CACHE_TESTS)

```

CMakeCache.txt contains no LLAMA_SERVER_CACHE_TESTS entry by design; the
guard is applied at the target level, not the cache level. This is the
correct mechanism, so the build-define-missing BLOCKED condition does not
apply. The binary was built with the guard in effect (verified below by the
five LLAMA_SERVER_CACHE_TESTS-gated tests running and passing).

Binary used this session: mtime 2026-07-07 03:33:48, length 1134592. This
binary was produced by the prior clean build and was not rebuilt this
session.

## Per-row verdict

| Row | Test function | Invariant | Expected PASS signal | Observed signal | Verdict | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| T-34-IDEM-01 | test_stage34_idempotent_save_hot_dedupe_use_count | I-34-01 (D34-REOPEN-06, hot-residency dedupe) | one entry, use_count reflects >=2 reuses | "Stage 34 idempotent save hot dedupe use_count" / "PASSED" | PASS | _test_output\stage34-reopen-test-stdout.txt (Test-Path True, 21178 bytes) |
| T-34-IDEM-02 | test_stage34_idempotent_save_skips_slow_read_on_hot_hit | I-34-01 + I-34-02 first-section fast dedupe | second save true, one entry, second-slot slow-read counter 0 | "Stage 34 idempotent save skips slow read on hot hit" / "PASSED" | PASS | _test_output\stage34-reopen-test-stdout.txt (Test-Path True, 21178 bytes) |
| T-34-IDEM-03 | test_stage34_idempotent_save_cold_rematerializes_in_place | I-34-01 widened per Manager required-action 1 | one entry for prompt span/namespace, use_count advances | "Stage 34 idempotent save cold rematerializes in place" / "PASSED" | PASS | _test_output\stage34-reopen-test-stdout.txt (Test-Path True, 21178 bytes) |
| T-34-PATHB-01 | test_stage34_pathb_restore_runs_during_save_read_window | I-34-02 (D34-REOPEN-07, slow read unblocks unrelated tx) | restore completes during paused save's slow-read window | "Stage 34 Path B restore runs during save read window" / "PASSED" | PASS | _test_output\stage34-reopen-test-stdout.txt (Test-Path True, 21178 bytes) |
| T-34-PATHB-02 | test_stage34_pathb_second_pass_dedupe_same_prompt | I-34-02 second-pass dedupe (D34-REOPEN-07) | one entry, second-pass dedupe counter exactly 1, use_count advances | "Stage 34 Path B second-pass dedupe same prompt" / "PASSED" | PASS | _test_output\stage34-reopen-test-stdout.txt (Test-Path True, 21178 bytes) |
| TP-34-CC | (scope note, D34-REOPEN-05) | EXPECTED-BEHAVIOR dispatch-ordering race (Stage 33 precedent) | n/a | Reclassified per part-38; no execution row. Stage 33 closure precedent. | N/A-not-an-execution-row | part-38 scope note; Stage 33 closure report test-report-20260630-03-stage33-01-manager-closure.md |

The binary prints one descriptive label per test (derived from the function
name) followed by a PASSED line. The five labels above were extracted with
Select-String against the captured stdout; each is immediately followed by a
"  PASSED" line at lines 114, 116, 118, 120, 122 of the stdout file.

## Total-tests line

Exit code of test-cache-controller.exe: 0.

Captured final summary verbatim:

```text

All tests passed successfully!
Total: 149 tests (31 original + 5 Part 14 comprehensive + 4 Stage 4
focused + 4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused + 7
Stage 9 focused + 9 Stage 10 bugfix loop + 3 Stage 10 2026-06-04 T114 + 15
Stage 17 focused + 2 Stage 18 bugfix 2026-06-18 + 6 Stage 21 bugfix
2026-06-18 + 9 Stage 23 focused + 15 Stage 22 focused + 2 Stage 24 focused
+ 10 Stage 25 atomic transactional + 5 Stage 26 cold-store accounting + 1
Stage 27 D-EXEC-24-03 heap corruption regression + 3 Stage 28 R28-BUG-02
cold-store drift fix + 1 Stage 28 R28-BUG-01 Step 7 D-EXEC-28-NEWBUG-01
production crash fix + 1 Stage 28 R28-BUG-01 Step 8 D-EXEC-28-NEWBUG-02
production crash fix + 2 Stage 34 replay regressions + 5 Stage 34 reopened
regressions)

```

The "+ 5 Stage 34 reopened regressions" term is the five rows under test.

## ctest -R cache

Command: ctest --test-dir build-cuda -C Release -R cache --output-on-failure

- Exit code: 0
- Selected: 1 (test-cache-controller registers as a single CTest entry)
- Passed: 1
- Failed: 0
- Skipped: 0

CTest aggregates test-cache-controller into one labeled main entry; the 149
individual test counts come from the binary's own stdout above, not from
CTest's internal pass count.

Evidence: _test_output\stage34-reopen-ctest.txt (Test-Path True, 301 bytes).

## Hygiene and output-path checks

- git diff --check exit code: 0
- F34-PATH-01 check, Test-Path ._design_docs/cache-handling-test-scripts/._test_output: False

Non-durable artifacts this session were written to the project-root
_test_output\ tree, per F34-PATH-01 carry-forward.

## Overall verdict

Verdict: PASS. 5 PASS, 0 FAIL, 0 BLOCKED, 0 SKIP, 1 N/A-not-an-execution-row.

All five Stage 34 reopen regression rows pass against a clean, fresh
(2026-07-07 03:33:48) Release CUDA binary built with the
LLAMA_SERVER_CACHE_TESTS target guard. ctest -R cache passes. git diff --check
is clean. F34-PATH-01 holds.

## Next owner and next gate

Next owner: Developer test-results review.
Next gate: test-results review of this report.
