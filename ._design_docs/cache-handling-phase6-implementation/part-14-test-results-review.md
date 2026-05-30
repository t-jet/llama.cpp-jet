# Phase 6 test-results review

Reviewer: Developer agent
Date: May 31, 2026
Scope: Stage 6 cold payload storage and asynchronous I/O — final QA test results classification and gate assessment

## Verdict: PASS

All 10 Stage 6 focused C++ test steps pass in Release configuration. No product bugs remain. Two test-infrastructure bugs were found and fixed. Two SKIP results are expected and documented.

## Source documents

| Document | Role |
| --- | --- |
| `test-report-20260530-01.md` | Initial QA run (PARTIAL — step3-4 crash) |
| `test-report-20260530-02.md` | Rerun after TEST_ASSERT fix (PARTIAL — step8 race) |
| `test-report-20260530-03.md` | Final rerun after all fixes (PASS) |
| `test-report-20260530-01-fixes.md` | Bug-fix report covering both fixes |
| `part-13-implementation-review.md` | Architect implementation review (PASS) |

## Finding classification

### Finding 1: Release-mode assertion no-op (test-step3-4 crash)

| Field | Value |
| --- | --- |
| Finding ID | F1 |
| Classification | **Test bug** |
| Root cause | `#undef NDEBUG` placed after `#include <cassert>` in all 10 test files, making `assert()` a no-op in Release builds. When assertions are disabled, invalid state propagates unchecked, causing undefined behavior (stack buffer overrun) in test 3.6. |
| Affected tests | test-step3-4-cold-store-write-read (crash), all other test files (latent — assertions were coincidentally true) |
| Product behavior impact | **None.** The bug is in the test harness, not in production code. Production code does not use `assert()` for runtime checks. |
| Fix | Replaced all `assert()` calls with `TEST_ASSERT()` macro (calls `exit(1)` on failure, works in both Debug and Release). Applied to all 10 test files, 407 total replacements. |
| Fix scope | Test-only. No production code changed. |
| Status | **Fixed.** Confirmed in report 02 and report 03. |
| Affects Stage 6 behavior? | No. |

### Finding 2: Race condition in test_cold_store_wired_to_io_worker (test-step8)

| Field | Value |
| --- | --- |
| Finding ID | F2 |
| Classification | **Test bug** |
| Root cause | `test_cold_store_wired_to_io_worker` called `process_completions()` immediately after `demote_payload()` without waiting for the I/O worker thread to complete the async write. The assertion on `n_demotion_successes == 1` failed because the completion had not yet been posted. |
| Affected tests | test-step8-integration-wiring, test 10 |
| Product behavior impact | **None.** The product code works correctly. The test was missing a synchronization delay that other async tests already include. |
| Fix | Added `std::this_thread::sleep_for(std::chrono::milliseconds(200))` between `demote_payload()` and `process_completions()`, consistent with the pattern in test-step5, test-step6, and test-step7. Also added missing `#include <chrono>`. |
| Fix scope | Test-only. No production code changed. |
| Status | **Fixed.** Confirmed in report 03. |
| Affects Stage 6 behavior? | No. |

### Finding 3: SKIP results for Windows non-writable directory tests

| Field | Value |
| --- | --- |
| Finding ID | F3 |
| Classification | **Expected environment limitation** |
| Details | test-step2-cold-store test (non-writable directory) and test-step9-startup-validation test (non-writable directory) are skipped on Windows because Windows does not support POSIX-style `chmod` to make a directory non-writable. |
| Product behavior impact | **None.** The skipped tests validate error handling for non-writable directories, which is a POSIX-specific concern. |
| Status | **Expected.** Documented in test-plan review and all three test reports. |
| Affects Stage 6 behavior? | No. |

## Finding summary

| ID | Type | Product bug? | Fixed? | Affects Stage 6 behavior? |
| --- | --- | --- | --- | --- |
| F1 | Test bug | No | Yes | No |
| F2 | Test bug | No | Yes | No |
| F3 | Environment limitation | No | N/A (expected) | No |

**No product bugs were found.** Both failures were test-infrastructure issues that masked or exposed incorrect test behavior, not defects in the Stage 6 production code.

## Test result confirmation

### Report 03 final results

| Test | Result | Tests passed | SKIP |
| --- | --- | --- | --- |
| test-step1-state-machine | PASS | 8/8 | — |
| test-step2-cold-store | PASS | 15/15 | 1 (Windows non-writable dir) |
| test-step3-4-cold-store-write-read | PASS | 27/27 | — |
| test-step5-io-worker | PASS | 20/20 | — |
| test-step6-demotion-protocol | PASS | 16/16 | — |
| test-step7-promotion-protocol | PASS | 16/16 | — |
| test-step8-integration-wiring | PASS | 14/14 | — |
| test-step9-startup-validation | PASS | 12/12 | 1 (Windows non-writable dir) |
| test-step10-metrics | PASS | 8/8 | — |
| test-step11-test-hooks-fault-injection | PASS | 17/17 | — |

- **Total test steps: 10**
- **PASS: 10**
- **FAIL: 0**
- **SKIP: 2** (both expected, Windows-specific non-writable directory checks)

### Progression across reports

| Test | Report 01 | Report 02 | Report 03 |
| --- | --- | --- | --- |
| step1 | PASS (8/8) | PASS (8/8) | PASS (8/8) |
| step2 | PASS (14/15, 1 SKIP) | PASS (15/15, 1 SKIP) | PASS (15/15, 1 SKIP) |
| step3-4 | **FAIL** (Release crash) | PASS (27/27) | PASS (27/27) |
| step5 | PASS (20/20) | PASS (20/20) | PASS (20/20) |
| step6 | PASS (16/16) | PASS (16/16) | PASS (16/16) |
| step7 | PASS (16/16) | PASS (16/16) | PASS (16/16) |
| step8 | PASS (11/11)* | **FAIL** (10/11, race) | PASS (14/14) |
| step9 | PASS (10/11, 1 SKIP) | PASS (11/11, 1 SKIP) | PASS (12/12, 1 SKIP) |
| step10 | PASS (8/8) | PASS (8/8) | PASS (8/8) |
| step11 | PASS (16/16) | PASS (16/16) | PASS (17/17) |

\* Report 01 step8 result was a false PASS — `assert()` was a no-op in Release mode, so the race condition was never checked.

## Bug-fix confirmation

### Fix 1: TEST_ASSERT macro (test-only)

- **Scope:** All 10 test files. 407 `assert()` calls replaced with `TEST_ASSERT()`.
- **Production code changed:** No.
- **Behavior change:** Assertions now correctly terminate the test process on failure in both Debug and Release configurations. Previously, assertions were silently disabled in Release builds.
- **Stage 6 behavior impact:** None. The `TEST_ASSERT()` macro is only defined and used in test files. Production code paths are unaffected.

### Fix 2: sleep_for race condition (test-only)

- **Scope:** `tests/test-step8-integration-wiring.cpp`, one test function.
- **Production code changed:** No.
- **Behavior change:** Added a 200ms sleep between `demote_payload()` and `process_completions()` to allow the I/O worker thread to complete the async write before checking results. This matches the pattern used in all other async tests.
- **Stage 6 behavior impact:** None. The sleep is only in the test harness. The product code's async behavior is correct — the test was not waiting for the async operation to complete.

## Non-blocking findings from implementation review

The architect's implementation review (part-13) identified four non-blocking findings. None of these are product bugs, and none affect the test-results gate:

| NB | Description | Impact on tests |
| --- | --- | --- |
| NB-1 | Single-field `promotion_enqueue_time` may be overwritten by concurrent promotions | No test impact. Current tests use sequential promotions. |
| NB-2 | `n_cold_payload_bytes` underflow guard silently skips subtraction | No test impact. Metric tests verify correct values. |
| NB-3 | `cold_store_header` byte-offset discrepancy with design | No test impact. Implementation is self-consistent. |
| NB-4 | Redundant residency check in `demote_payload` | No test impact. Produces a more specific diagnostic message. |

## Pre-existing issues

The test reports note one pre-existing issue outside Stage 6 scope:

- **test-cache-controller test 17** (`test_hybrid_rejects_partial_blob_match`): This assertion failure existed before Stage 6 changes and is unrelated to the cold layer. It is not a Stage 6 finding and does not affect this gate.

## Stage closure assessment

| Criterion | Status |
| --- | --- |
| All 10 test steps pass in Release configuration | ✅ Confirmed in report 03 |
| No product bugs remain | ✅ Both findings were test bugs |
| All test bugs are fixed | ✅ Both fixes applied and verified |
| SKIP results are expected and documented | ✅ 2 Windows-specific skips, documented |
| Bug fixes are test-only, no production code changes | ✅ Confirmed |
| Implementation review passed (part-13) | ✅ PASS verdict, 4 non-blocking findings |
| No blocking findings from any source | ✅ |

**The Stage 6 implementation is ready for stage closure.** All acceptance criteria are met: 10/10 test steps pass, zero product bugs, zero unfixed findings, and the implementation review verdict is PASS.
