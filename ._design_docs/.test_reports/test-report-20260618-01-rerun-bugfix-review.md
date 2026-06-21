# Stage 21 F-21-RERUN-01 bug-fix review

VERDICT: REWORK

Status: REWORK
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification)
Author: Architect (bug-fix review)
Source: [test-report-20260618-01-rerun-fixes.md](test-report-20260618-01-rerun-fixes.md) (Developer fix evidence); [test-report-stage21-payload-unavailable-fixes.md](test-report-stage21-payload-unavailable-fixes.md) (fix plan PASS); [part-09-architect-fix-plan-review-gate-01.md](../cache-handling-phase21-implementation/part-09-architect-fix-plan-review-gate-01.md) (Architect fix-plan review PASS); [cache-handling-phase21-design.md](../cache-handling-phase21-design.md) (design)
Scope: Review F-21-RERUN-01 code change in `tools/server/server-cache-hybrid.cpp` and 3 new unit tests in `tests/test-cache-controller.cpp`. No production code edits, no test code edits, no commits, no pushes.

## Summary

REWORK. Code changes are functionally correct and all 97 unit tests pass (94 prior + 3 new). However, the fix evidence file `test-report-20260618-01-rerun-fixes.md` contains CRLF line endings, violating the Stage 15+ durable documentation format governance. This is a BLOCKING finding per the Stage 15 closure contracts that require LF-only UTF-8 for all durable docs, test reports, and review artifacts. The Developer must convert the fix evidence file to LF-only and confirm the conversion via byte-level check before the bug-fix can be accepted. All other checklist items PASS (code correctness, test coverage, scope, format of production/test files, compile-clean build, no regressions).

Code change verification: Change 1 (refresh_entry_payload_accounting line 1573-1574) correctly includes demoting residency state in budget calculation. Change 2 (mark_payload_kind_evicted) is functionally correct via early return at line 3129 that guards the zeroing line at line 3136. The Developer's claim of "removed" is imprecise — the line was removed from inside the if-block and the early return prevents reaching it when demotion succeeds. This is the correct fix pattern.

## Findings table

| ID | Severity | Description | Evidence citation |
| --- | --- | --- | --- |
| F-21-FR-01 | BLOCKING | Fix evidence file contains CRLF line endings | Byte-level check: `test-report-20260618-01-rerun-fixes.md` CR=True (0x0D present). Stage 15+ governance requires LF-only UTF-8 for all durable docs, test reports, and review artifacts. The Developer claimed CRLF fix for Architect review file in fix evidence section "CRLF fix evidence" but did NOT apply it to their own fix evidence file. |

## Verification checklist

| # | Item | Verdict | Evidence |
| ---: | --- | --- | --- |
| 1 | Code change 1 (refresh_entry_payload_accounting): residency check includes demoting | PASS | Verified via `read_file` lines 1563-1585. Actual code at lines 1573-1574: `if ((descriptor.residency != payload_residency_state::hot && descriptor.residency != payload_residency_state::demoting) \|\| ...)`. The check now includes `demoting` state, so demoting payloads are counted in budget calculation. Matches proposed fix in fix plan part 1. |
| 2 | Code change 2 (mark_payload_kind_evicted): zeroing prevented when demote succeeds | PASS | Verified via `read_file` lines 3112-3140. The line `descriptor_it->second.resident_payload_bytes = 0;` still exists at line 3136, but it is GUARDED by an early return at line 3129. Actual code at lines 3126-3129: `if (demote_payload(payload_id)) { refresh_entry_payload_accounting(entry); return true; }`. When demotion succeeds, the function returns at line 3129 and never reaches line 3136. This is functionally correct. The Developer's claim of "removed" is imprecise but the fix is correct. |
| 3 | 3 new unit tests added and pass: TP-21-UT4, UT5, UT6 | PASS | Verified via `read_file` lines 3104-3195 in `tests/test-cache-controller.cpp`. Three tests added: `test_stage21_demoting_payload_counted_in_budget` (line 3105), `test_stage21_descriptor_resident_bytes_preserved_during_demotion` (line 3137), `test_stage21_entry_eviction_during_demotion_does_not_crash` (line 3169). All 3 registered in main() at lines 3528-3530 (verified via `grep_search`). Independent test run confirms all 3 PASSED (grep output lines 246, 248, 250). |
| 4 | 97 total tests pass (94 prior + 3 new): no regressions | PASS | Independent test run output: "All tests passed successfully!" (line 254). "Total: 97 tests (...)" (line 255). Exit code: 0. All 94 prior tests still pass. |
| 5 | Stage 21 tests (TP-21-UT1..UT6) all PASS | PASS | Independent test run output shows all 6 Stage 21 tests: "Stage 21 exact repeat restore with prompt-only save... PASSED" (line 240-241); "Stage 21 exact repeat prefix boundary... PASSED" (line 242-243); "Stage 21 near prefix still rejected... PASSED" (line 244-245); "Stage 21 demoting payload counted in budget... PASSED" (line 246-247); "Stage 21 descriptor resident_bytes preserved during demotion... PASSED" (line 248-249); "Stage 21 entry eviction during demotion does not crash... PASSED" (line 250-251). All 6 visible and PASSED. |
| 6 | Format clean for production code and test code: LF-only, no BOM, no trailing whitespace | PASS | Byte-level check: `server-cache-hybrid.cpp` CR=False, BOM=False, NonAscii=False. `test-cache-controller.cpp` CR=False, BOM=False, NonAscii=False. `git diff --check HEAD -- tools/server/server-cache-hybrid.cpp tests/test-cache-controller.cpp` exit code: 0 (no trailing whitespace). |
| 7 | Format clean for fix evidence file (BLOCKING per Stage 15+ governance) | FAIL | Byte-level check: `test-report-20260618-01-rerun-fixes.md` CR=True (0x0D present). The file has CRLF line endings. Stage 15+ governance requires LF-only UTF-8 for all durable docs, test reports, and review artifacts. This is BLOCKING per the Stage 15 closure contracts. See F-21-FR-01. |
| 8 | Scope contained: only 2 files modified (and fix evidence file) | PASS | `git diff --stat HEAD -- tools/server/server-cache-hybrid.cpp tests/test-cache-controller.cpp` output: "tests/test-cache-controller.cpp \| 441 ++++... tools/server/server-cache-hybrid.cpp \| 4 +-... 2 files changed, 316 insertions(+), 129 deletions(-)". Only 2 production/test files modified. Fix evidence file is new (created). No runner edits, no other production code touched. |
| 9 | Compile-clean build: exit 0 for test-cache-controller | PASS | Fix evidence cites build exit code: 0 for both `test-cache-controller.exe` (2818048 bytes, 2026-06-18 17:49:47) and `llama-server.exe` (13312 bytes, 2026-06-18 17:48:49). Independent test run exit code: 0. |
| 10 | Public metrics not changed: no public metric names, CLI flags, or endpoint behavior changed | PASS | `git diff --stat` shows only internal function changes in `server-cache-hybrid.cpp` (4 lines +/-). No public metric names added or changed. No CLI flag changes. No endpoint behavior changes. Fix is internal budget calculation only. |
| 11 | Stage 5/6/8/9/10/17 invariants preserved: prior tests still pass | PASS | All 94 prior tests pass. No regressions. Budget enforcement invariants (Stage 5/6/8/9/10/17) preserved. Test run shows all original tests, Part 14, Stage 4-10, Stage 17, Stage 18 tests PASSED. |

## Code change verification

### Change 1: `refresh_entry_payload_accounting` (line 1573-1574)

**File**: `tools/server/server-cache-hybrid.cpp`
**Function**: `refresh_entry_payload_accounting`
**Line range**: 1563-1585 (function body), 1573-1574 (modified check)

**Before** (per fix plan):

```cpp
        if (descriptor.residency != payload_residency_state::hot ||
            descriptor.resident_payload_bytes == 0 ||
            hot_payloads.find(descriptor.store_ref.id) == hot_payloads.end()) {
            continue;
        }
```

**After** (actual code read, lines 1573-1576):

```cpp
        if ((descriptor.residency != payload_residency_state::hot &&
             descriptor.residency != payload_residency_state::demoting) ||
            descriptor.resident_payload_bytes == 0 ||
            hot_payloads.find(descriptor.store_ref.id) == hot_payloads.end()) {
            continue;
        }
```

**Verdict**: PASS. The check now includes `demoting` state via `(descriptor.residency != hot && descriptor.residency != demoting)`, which is equivalent to `(residency == hot || residency == demoting)`. Demoting payloads are now counted in the resident budget calculation. This matches the proposed fix in the fix plan.

### Change 2: `mark_payload_kind_evicted` (line 3128-3129)

**File**: `tools/server/server-cache-hybrid.cpp`
**Function**: `mark_payload_kind_evicted`
**Line range**: 3112-3140 (function body), 3126-3129 (modified if-block)

**Developer's claim**: "Removed `descriptor_it->second.resident_payload_bytes = 0;` at line 3128."

**Actual finding**: The line `descriptor_it->second.resident_payload_bytes = 0;` still exists at line 3136 in the fall-through eviction path. However, it is GUARDED by an early return at line 3129 when demotion succeeds.

**Actual code** (lines 3126-3136):

```cpp
            if (demote_payload(payload_id)) {
                refresh_entry_payload_accounting(entry);
                return true;  // <-- early return at line 3129
            }
            SRV_WRN(" - hybrid cache: demotion failed for payload_id %" PRIu64 ", falling back to immediate eviction\n",
                    payload_id);
        }

        record_payload_eviction(descriptor_it->second, "success", "hot_budget");
        descriptor_it->second.residency = payload_residency_state::evicted;
        descriptor_it->second.resident_payload_bytes = 0;  // <-- line 3136, still present
```

**Control flow analysis**:

- When `demote_payload(payload_id)` returns true (demotion queued), the function executes line 3128 (`refresh_entry_payload_accounting(entry)`) and then returns at line 3129.
- The zeroing line at 3136 is NOT reached when demotion succeeds.
- When demotion fails (cold store not configured or demotion queue full), the function falls through to the immediate eviction path (lines 3133-3136), where zeroing the resident bytes is correct.

**Verdict**: PASS. The fix is functionally correct. The Developer's description is imprecise (claimed "removed" but the line exists at 3136), but the actual implementation correctly guards the zeroing line via early return. When demotion succeeds, the descriptor retains its original `resident_payload_bytes` value until `handle_demotion_completion` releases hot memory (line 656). This preserves Stage 17 / Stage 5 design intent: demoting payloads occupy hot memory until the write completes.

## Test verification

### TP-21-UT4: `test_stage21_demoting_payload_counted_in_budget`

**Location**: `tests/test-cache-controller.cpp` lines 3105-3132
**Purpose**: Verify demoting payloads are counted in resident budget calculation.

**Scenario**:
1. Create controller with hot payload budget = 1000 bytes.
2. Admit checkpoint payload = 600 bytes.
3. Configure cold store and start IO worker.
4. Read `resident_payload_bytes` from stats (should be >= 600).
5. Trigger demotion via `debug_demote_first_checkpoint_for_tests()`.
6. Verify residency state is `demoting`.
7. Read `resident_payload_bytes` from stats again (should still be >= 600).

**Assertion**: `resident_demoting >= 600` (demoting payload is counted in budget).

**Independent test run result**: "Stage 21 demoting payload counted in budget... PASSED" (line 246-247 in test output).

**Verdict**: PASS. Test verifies fix 1 (demoting payloads included in budget calculation). Test uses real cache API, not mocked. Test is idempotent (creates unique temp directory). Test is independent (no dependency on other tests).

### TP-21-UT5: `test_stage21_descriptor_resident_bytes_preserved_during_demotion`

**Location**: `tests/test-cache-controller.cpp` lines 3137-3167
**Purpose**: Verify descriptor's `resident_payload_bytes` is NOT zeroed during demotion.

**Scenario**:
1. Create controller with token limit = 2, payload budget = 1000 bytes.
2. Admit checkpoint payload = 800 bytes.
3. Configure cold store and start IO worker.
4. Read `resident_payload_bytes` from stats (should be >= 800).
5. Trigger demotion via `debug_demote_first_checkpoint_for_tests()`.
6. Verify residency state is `demoting`.
7. Read `resident_payload_bytes` from stats again (should still be >= 800).

**Assertion**: `resident_demoting >= 800` (descriptor's resident bytes preserved during demotion).

**Independent test run result**: "Stage 21 descriptor resident_bytes preserved during demotion... PASSED" (line 248-249 in test output).

**Verdict**: PASS. Test verifies fix 2 (descriptor's resident_payload_bytes not zeroed prematurely). Test uses real cache API. Test is idempotent. Test is independent.

### TP-21-UT6: `test_stage21_entry_eviction_during_demotion_does_not_crash`

**Location**: `tests/test-cache-controller.cpp` lines 3169-3191
**Purpose**: Verify entry eviction during demotion does not crash or assert (F-21-RERUN-02 "descriptor not found" safe path).

**Scenario**:
1. Create controller with token limit = 100, payload budget = 800 bytes.
2. Admit 2 checkpoints (300 bytes each, total 600 bytes, 75% of budget).
3. Configure cold store and start IO worker.
4. Trigger demotion of first checkpoint via `debug_demote_first_checkpoint_for_tests()`.
5. Admit 3rd checkpoint (300 bytes, forces eviction to stay within 800 bytes budget).

**Assertion**: No crash, no assertion failure (eviction path handles in-flight demotion safely).

**Independent test run result**: "Stage 21 entry eviction during demotion does not crash... PASSED" (line 250-251 in test output).

**Verdict**: PASS. Test verifies the "descriptor not found" path (F-21-RERUN-02) is safe. Test exercises the real eviction code path during demotion. Test does not crash. Test is idempotent. Test is independent.

## Format check: literal byte counts

### Production code

**File**: `tools/server/server-cache-hybrid.cpp`

Byte-level check (PowerShell):

```powershell
$bytes = [System.IO.File]::ReadAllBytes('d:\source\llama.cpp-jet\tools\server\server-cache-hybrid.cpp')
$hasCR = ($bytes | Where-Object { $_ -eq 0x0D }).Count -gt 0
$hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$nonAscii = ($bytes | Where-Object { $_ -gt 0x7F }).Count -gt 0
```

Result: `CR=False BOM=False NonAscii=False`

Verdict: PASS (LF-only UTF-8 without BOM).

### Test code

**File**: `tests/test-cache-controller.cpp`

Byte-level check (PowerShell):

```powershell
$bytes = [System.IO.File]::ReadAllBytes('d:\source\llama.cpp-jet\tests\test-cache-controller.cpp')
$hasCR = ($bytes | Where-Object { $_ -eq 0x0D }).Count -gt 0
$hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$nonAscii = ($bytes | Where-Object { $_ -gt 0x7F }).Count -gt 0
```

Result: `CR=False BOM=False NonAscii=False`

Verdict: PASS (LF-only UTF-8 without BOM).

### Fix evidence file (BLOCKING)

**File**: `._design_docs/.test_reports/test-report-20260618-01-rerun-fixes.md`

Byte-level check (PowerShell):

```powershell
$bytes = [System.IO.File]::ReadAllBytes('d:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260618-01-rerun-fixes.md')
$hasCR = ($bytes | Where-Object { $_ -eq 0x0D }).Count -gt 0
$hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
$nonAscii = ($bytes | Where-Object { $_ -gt 0x7F }).Count -gt 0
```

Result: `CR=True BOM=False NonAscii=False`

Verdict: FAIL (CRLF line endings present). This is BLOCKING per Stage 15+ governance.

## Scope verification: literal git diff --stat

Command:

```powershell
git -C 'd:\source\llama.cpp-jet' diff --stat HEAD -- tools/server/server-cache-hybrid.cpp tests/test-cache-controller.cpp
```

Output:

```
 tests/test-cache-controller.cpp      | 441 +++++++++++++++++++++++++----------
 tools/server/server-cache-hybrid.cpp |   4 +-
 2 files changed, 316 insertions(+), 129 deletions(-)
```

Verdict: PASS. Only 2 files modified. Scope is minimal and contained.

Command:

```powershell
git -C 'd:\source\llama.cpp-jet' diff --check HEAD -- tools/server/server-cache-hybrid.cpp tests/test-cache-controller.cpp
```

Exit code: 0

Verdict: PASS. No trailing whitespace or other format issues.

## Independent test run: exit code, total tests, passed, failed, Stage 21 PASS lines (literal)

Command:

```powershell
cd 'd:\source\llama.cpp-jet'
.\build-cov\bin\Release\test-cache-controller.exe 2>&1 | Tee-Object 'd:\source\llama.cpp-jet\._test_output\stage21-rerun01-fix-review-unittests.log'
```

Exit code: 0

Total tests: 97

Passed: 97

Failed: 0

Stage 21 test lines (literal from `stage21-rerun01-fix-review-unittests.log`):

```
test-cache-controller: Stage 21 exact repeat restore with prompt-only save...
  PASSED
test-cache-controller: Stage 21 exact repeat prefix boundary...
  PASSED
test-cache-controller: Stage 21 near prefix still rejected...
  PASSED
test-cache-controller: Stage 21 demoting payload counted in budget...
  PASSED
test-cache-controller: Stage 21 descriptor resident_bytes preserved during demotion...
  PASSED
test-cache-controller: Stage 21 entry eviction during demotion does not crash...
  PASSED
```

Summary line:

```
Total: 97 tests (31 original + 5 Part 14 comprehensive + 4 Stage 4 focused + 4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused + 7 Stage 9 focused + 9 Stage 10 bugfix loop + 3 Stage 10 2026-06-04 T114 + 15 Stage 17 focused + 2 Stage 18 bugfix 2026-06-18 + 6 Stage 21 bugfix 2026-06-18)
```

Verdict: PASS. All 97 tests pass. All 6 Stage 21 tests (TP-21-UT1..UT6) visible and PASSED.

## Required corrections

### F-21-FR-01: Fix evidence file CRLF line endings (BLOCKING)

**File**: `._design_docs/.test_reports/test-report-20260618-01-rerun-fixes.md`

**Issue**: The file contains CRLF line endings (CR=True). Stage 15+ governance requires LF-only UTF-8 for all durable docs, test reports, and review artifacts.

**Required correction**:

Convert the file to LF-only UTF-8 without BOM via PowerShell:

```powershell
$path = 'd:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260618-01-rerun-fixes.md'
$content = [System.IO.File]::ReadAllText($path)
$content = $content -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
```

Verify the conversion via byte-level check:

```powershell
$bytes = [System.IO.File]::ReadAllBytes($path)
$hasCR = ($bytes | Where-Object { $_ -eq 0x0D }).Count -gt 0
$hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
Write-Host "CR=$hasCR BOM=$hasBOM"
```

Expected result: `CR=False BOM=False`

**Acceptance check**: Architect must verify the corrected file has CR=False before accepting the fix.

## Files created or modified

**Created**:
- `._design_docs/.test_reports/test-report-20260618-01-rerun-fixes.md` (fix evidence, CRLF present, requires correction)
- `._design_docs/.test_reports/test-report-20260618-01-rerun-bugfix-review.md` (this review file)
- `._test_output/stage21-rerun01-fix-review-unittests.log` (test run output)

**Modified**:
- `tools/server/server-cache-hybrid.cpp` (2 changes: line 1573-1574 residency check, line 3128-3129 early return)
- `tests/test-cache-controller.cpp` (3 new tests: TP-21-UT4, UT5, UT6; test count updated to 97)

**NOT modified** (confirmed):
- No runner scripts modified
- No design docs modified
- No implementation log modified
- No document-index modified
- No commits
- No pushes

## Handoff

**Next owner**: Developer (to correct F-21-FR-01)

**Next task**: Convert `test-report-20260618-01-rerun-fixes.md` to LF-only UTF-8 and verify via byte-level check. After correction, Architect will re-review and issue PASS verdict if CR=False.

**Handoff state**: REWORK (1 BLOCKING finding: F-21-FR-01)

## Confirmation

- No commits
- No pushes
- No production code edits (read-only review)
- No test code edits (read-only review)
- No runner edits
- No scope expansion (only reviewed the 2 files modified by Developer and wrote review file)
