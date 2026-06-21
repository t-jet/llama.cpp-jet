# Stage 21 F-21-RERUN-01 code-fix implementation evidence

Status: PASS
Date: 2026-06-18
Stage: 21 (Heavy Tier Mixed Workload Verification)
Author: Developer (code-fix implementation)
Source: [test-report-stage21-payload-unavailable-fixes.md](test-report-stage21-payload-unavailable-fixes.md) (fix plan PASS); [part-09-architect-fix-plan-review-gate-01.md](../cache-handling-phase21-implementation/part-09-architect-fix-plan-review-gate-01.md) (Architect fix-plan review PASS); [stage21-heavy-20260618-01-rerun.md](stage21-heavy-20260618-01-rerun.md) (QA rerun FAIL, F-21-RERUN-01/02); [cache-handling-phase21-design.md](../cache-handling-phase21-design.md); [cache-handling-phase21-implementation.md](../cache-handling-phase21-implementation.md)
Scope: Apply F-21-RERUN-01 2-line production fix, add 3 unit tests, build, run tests, fix CRLF in Architect review file, format checks, write evidence. NO heavy execution, NO commits, NO pushes.

## Summary

F-21-RERUN-01 code fix applied and verified. Two production changes in `tools/server/server-cache-hybrid.cpp`: (1) modified `refresh_entry_payload_accounting` (line 1573) to include demoting payloads in budget calculation, (2) removed premature zeroing of `resident_payload_bytes` in `mark_payload_kind_evicted` (line 3128). Three unit tests added to `tests/test-cache-controller.cpp`: TP-21-UT4 (demoting payload counted in budget), TP-21-UT5 (descriptor resident_bytes preserved during demotion), TP-21-UT6 (entry eviction during demotion does not crash). Both binaries built (test-cache-controller.exe, llama-server.exe). All 97 unit tests passed (94 prior + 3 new). CRLF stripped from Architect review file. Format checks pass (no CR, no BOM, no trailing whitespace, git diff --check exit 0). Ready for Architect bug-fix review.

## Code change 1: `refresh_entry_payload_accounting` (line 1573)

File: `tools/server/server-cache-hybrid.cpp`
Line range: 1573-1578 (modified), context 1563-1585
Function: `refresh_entry_payload_accounting`

Change: Modified residency check to include demoting payloads in budget calculation.

Before:

```cpp
        if (descriptor.residency != payload_residency_state::hot ||
            descriptor.resident_payload_bytes == 0 ||
            hot_payloads.find(descriptor.store_ref.id) == hot_payloads.end()) {
            continue;
        }
```

After:

```cpp
        if ((descriptor.residency != payload_residency_state::hot &&
             descriptor.residency != payload_residency_state::demoting) ||
            descriptor.resident_payload_bytes == 0 ||
            hot_payloads.find(descriptor.store_ref.id) == hot_payloads.end()) {
            continue;
        }
```

Rationale: Demoting payloads still occupy hot memory (the `hot_payloads` map contains them) until `handle_demotion_completion` erases them at line 656. The budget check must count all payloads in hot memory, not just those in `hot` residency state. This prevents false "under budget" reports that trigger evictions while in-flight demotions are holding hot memory.

## Code change 2: `mark_payload_kind_evicted` (line 3128)

File: `tools/server/server-cache-hybrid.cpp`
Line range: 3126-3130 (modified), context 3112-3140
Function: `mark_payload_kind_evicted`

Change: Removed premature zeroing of `descriptor.resident_payload_bytes` after demotion is queued.

Before:

```cpp
            if (demote_payload(payload_id)) {
                descriptor_it->second.resident_payload_bytes = 0;
                refresh_entry_payload_accounting(entry);
                return true;
            }
```

After:

```cpp
            if (demote_payload(payload_id)) {
                refresh_entry_payload_accounting(entry);
                return true;
            }
```

Rationale: After `demote_payload` queues the write (setting `residency = demoting` at line 429), hot memory is NOT released. The descriptor should retain its original `resident_payload_bytes` value until demotion completes and hot memory is released (at `handle_demotion_completion` line 656). The premature zeroing caused `refresh_entry_payload_accounting` to see a descriptor in `demoting` state with 0 resident bytes, which was then skipped by the check at line 1573, causing `entry.resident_payload_bytes_cached` to drop to 0 and the budget check to undercount.

## Unit test additions

File: `tests/test-cache-controller.cpp`
Line range: 3106-3191 (added), context 3104-3195
Functions: `test_stage21_demoting_payload_counted_in_budget`, `test_stage21_descriptor_resident_bytes_preserved_during_demotion`, `test_stage21_entry_eviction_during_demotion_does_not_crash`

### TP-21-UT4: `test_stage21_demoting_payload_counted_in_budget`

Purpose: Verify demoting payloads are counted in resident budget calculation.

Scenario:
1. Create controller with hot payload budget = 1000 bytes.
2. Admit checkpoint payload = 600 bytes.
3. Configure cold store and start IO worker.
4. Read `resident_payload_bytes` from stats (should be >= 600).
5. Trigger demotion.
6. Read `resident_payload_bytes` from stats again (should still be >= 600).

Assertion: `resident_demoting >= 600` (demoting payload is counted in budget).

### TP-21-UT5: `test_stage21_descriptor_resident_bytes_preserved_during_demotion`

Purpose: Verify descriptor's `resident_payload_bytes` is NOT zeroed during demotion.

Scenario:
1. Create controller with token limit = 2, payload budget = 1000 bytes.
2. Admit checkpoint payload = 800 bytes.
3. Configure cold store and start IO worker.
4. Read `resident_payload_bytes` from stats (should be >= 800).
5. Trigger demotion.
6. Verify residency state is `demoting`.
7. Read `resident_payload_bytes` from stats again (should still be >= 800).

Assertion: `resident_demoting >= 800` (descriptor's resident bytes preserved during demotion).

### TP-21-UT6: `test_stage21_entry_eviction_during_demotion_does_not_crash`

Purpose: Verify entry eviction during demotion does not crash or assert.

Scenario:
1. Create controller with token limit = 100, payload budget = 800 bytes.
2. Admit 2 checkpoints (300 bytes each, total 600 bytes, 80% of budget).
3. Configure cold store and start IO worker.
4. Trigger demotion of first checkpoint.
5. Admit 3rd checkpoint (300 bytes, forces eviction).

Assertion: No crash, no assertion failure (eviction path handles in-flight demotion safely).

All 3 tests registered in `main()` at lines 3543-3545, after existing Stage 21 tests.

## Test count update

File: `tests/test-cache-controller.cpp`
Line: 3549 (modified)

Before: `Total: 94 tests (... + 3 Stage 21 bugfix 2026-06-18)`

After: `Total: 97 tests (... + 6 Stage 21 bugfix 2026-06-18)`

Updated count from 94 to 97 (added 3 new Stage 21 tests).

## Build evidence

### test-cache-controller.exe

Command:

```powershell
cmake --build 'd:\source\llama.cpp-jet\build-cov' --config Release --target test-cache-controller -j 4
```

Exit code: 0

Binary metadata:

```
FullName      : D:\source\llama.cpp-jet\build-cov\bin\Release\test-cache-controller.exe
Length        : 2818048
LastWriteTime : 2026-06-18 17:49:47
```

### llama-server.exe

Command:

```powershell
cmake --build 'd:\source\llama.cpp-jet\build-cov' --config Release --target llama-server -j 4
```

Exit code: 0

Binary metadata:

```
FullName      : D:\source\llama.cpp-jet\build-cov\bin\Release\llama-server.exe
Length        : 13312
LastWriteTime : 2026-06-18 17:48:49
```

## Test execution evidence

Command:

```powershell
cd 'd:\source\llama.cpp-jet'
.\build-cov\bin\Release\test-cache-controller.exe 2>&1 | Tee-Object 'd:\source\llama.cpp-jet\._test_output\stage21-rerun01-unittests.log'
```

Exit code: 0

Test summary:

```
All tests passed successfully!
Total: 97 tests (31 original + 5 Part 14 comprehensive + 4 Stage 4 focused + 4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused + 7 Stage 9 focused + 9 Stage 10 bugfix loop + 3 Stage 10 2026-06-04 T114 + 15 Stage 17 focused + 2 Stage 18 bugfix 2026-06-18 + 6 Stage 21 bugfix 2026-06-18)
```

Stage 21 test results:

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

All 97 tests passed. No regressions in 94 prior tests. All 6 Stage 21 tests (3 prior + 3 new) visible and PASSED.

## CRLF fix evidence

File: `._design_docs/cache-handling-phase21-implementation/part-09-architect-fix-plan-review-gate-01.md`

Command:

```powershell
$path = 'd:\source\llama.cpp-jet\._design_docs\cache-handling-phase21-implementation\part-09-architect-fix-plan-review-gate-01.md'
$content = Get-Content -Path $path -Raw
$content = $content -replace "`r`n", "`n"
[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
$bytes = [System.IO.File]::ReadAllBytes($path)
$hasCR = ($bytes | Where-Object { $_ -eq 0x0D }).Count -gt 0
$hasBOM = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
Write-Host "CR=$hasCR BOM=$hasBOM"
```

Result:

```
CR=False BOM=False
```

CRLF stripped successfully. File is now LF-only UTF-8 without BOM.

## Format check evidence

Command:

```powershell
git -C 'd:\source\llama.cpp-jet' diff --check HEAD -- tools/server/server-cache-hybrid.cpp tests/test-cache-controller.cpp
```

Exit code: 0 (no format issues)

Per-file byte-level checks:

```
server-cache-hybrid.cpp : CR=False BOM=False
test-cache-controller.cpp : CR=False BOM=False
part-09-architect-fix-plan-review-gate-01.md : CR=False BOM=False
```

All 3 files are LF-only UTF-8 without BOM. No trailing whitespace. No format violations.

## Scope guard

Files modified:

```
d:\source\llama.cpp-jet\tools\server\server-cache-hybrid.cpp
d:\source\llama.cpp-jet\tests\test-cache-controller.cpp
d:\source\llama.cpp-jet\._design_docs\cache-handling-phase21-implementation\part-09-architect-fix-plan-review-gate-01.md
```

Files created:

```
d:\source\llama.cpp-jet\._design_docs\.test_reports\test-report-20260618-01-rerun-fixes.md
```

No other production files modified. No other test files modified. No heavy execution. No llama-server chat completion runs. No HV-expanded. No commits. No pushes.

## Handoff

Next owner: Architect
Next task: Bug-fix review (code change itself, not the plan)
Next input: This fix evidence file + modified production code + modified test code

The fix is ready for Architect code-change review. Production code changes are minimal (2 lines), test coverage is complete (3 new unit tests), and format compliance is verified.
