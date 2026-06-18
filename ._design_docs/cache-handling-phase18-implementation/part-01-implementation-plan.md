# Stage 18 implementation plan

Status: authored; pending Architect implementation-plan review
Date: 2026-06-18
Author: Developer (implementation plan, fresh session)
Scope: Stage 18 implementation plan only. Not implementation, not design re-review, not test plan authoring.
Source decisions: D17-EXEC-03, D17-CLOSURE-02 / F-16-TR-03

## Approved baseline

Implementation must follow the approved Stage 18 design:

- [Stage 18 design entry](cache-handling-phase18-design.md)
- [Part 1: Item 1 design - remove duplicate cold-path-hybrid check](cache-handling-phase18-design/part-01-item1-duplicate-cold-path-hybrid-check.md)
- [Part 2: Item 2 design - add /Zi /DEBUG:FULL to CMAKE_CXX_FLAGS_RELEASE](cache-handling-phase18-design/part-02-item2-cxx-flags-release-debug-info.md)
- [Part 3: Test plan rows, traceability, risks, and handoff](cache-handling-phase18-design/part-03-test-plan-traceability-risks-handoff.md)
- [Part 4: Design review gate 01 (Architect PASS, 0 BLOCKING, 3 non-blocking, 1 INFO)](cache-handling-phase18-design/part-04-design-review-gate-01.md)

Manager decisions binding (Stage 17 closure, 2026-06-17):

- D17-EXEC-03: remove the duplicate cold-path-hybrid check at
  `tools/server/server-context.cpp` lines 1554-1557 in the post-slot-init
  block (artifact of F-17-EXEC-01 validation block move).
- D17-CLOSURE-02 / F-16-TR-03: add `/Zi /DEBUG:FULL` to
  `CMAKE_CXX_FLAGS_RELEASE` for the `build-cov` build configuration so
  OpenCppCoverage produces line-count coverage data instead of
  header-only `.cov` files.

Architecture and requirement inputs remain binding:
[cache-handling-architecture.md](cache-handling-architecture.md),
[cache-handling-requirements.md](cache-handling-requirements.md), and
[cache-handling-test-plan.md](cache-handling-test-plan.md).

## Design-review findings to address in plan

The Stage 18 design review (part 4) returned PASS with 0 BLOCKING, 3
non-blocking, 1 INFO findings. This plan addresses each finding during
implementation:

| Finding | Severity | Plan resolution |
| --- | --- | --- |
| F-18-DR-01 | NON-BLOCKING | After Item 1 deletion, the corner case `--cache-cold-path set, --cache-cold-max-mib 0, --cache-mode legacy` would silently proceed. Implementation Step 1.6 records the post-implementation behavior in the evidence section. Step 1.7 (TP-18-IT1 evidence) verifies the server exit code and error message. If the corner case is intentionally suppressed (cold writes disabled makes the cold-path config dead anyway), the evidence documents the behavior; if not, the evidence flags it for follow-up. Either outcome is acceptable; the finding is closed by recording what actually happens. |
| F-18-DR-02 | NON-BLOCKING | This plan uses 89/89 throughout. The actual test count was verified: `(Get-Content tests/test-cache-controller.cpp \| Select-String -Pattern '^void test_').Count` = 89 (74 pre-Stage 17 + 15 `test_stage17_*` functions). The design's "87 tests pass (74 + 13)" wording is corrected to "89 tests pass (74 + 15)" in this plan. TP-18-FT1 and TP-18-FT6 expected outcomes use 89/89. |
| F-18-DR-03 | NON-BLOCKING | This plan uses "same SRV_ERR message and same throw string" rather than "byte-identical". The moved block at lines 1417-1420 has additional conditions (`cache_cold_max_mib != 0` and `!cache_cold_path.empty()`) that the duplicate at 1554-1557 does not have; only the SRV_ERR message text and throw string are byte-identical, not the surrounding if-condition. |
| F-18-DR-04 | INFO | `-DCMAKE_BUILD_TYPE=Release` is a no-op for the Visual Studio 18 2026 generator (multi-config ignores CMAKE_BUILD_TYPE). The cmake invocation in Step 2.2 still includes it for documentation completeness (matches the design's recorded command), and the implementation evidence notes the no-op explicitly. No code change. |

## Code surfaces

Files affected by this stage:

- `tools/server/server-context.cpp`: Item 1 deletion (lines 1554-1557)
  and comment update (line 1552).
- `build-cov/CMakeCache.txt`: Item 2 flag update (line 80 CXX, line 98
  C). Line 83 `CMAKE_CXX_FLAGS_RELWITHDEBINFO` is NOT modified.
- `tests/test-cache-controller.cpp`: no code change. Test count
  verification only (89/89 baseline).
- `build-cov/bin/Release/test-cache-controller.exe`: rebuilt with new
  flags (Item 2 Step 2.5).
- `build-cov/bin/Release/llama-server.exe`: rebuilt with new flags
  (Item 2 Step 2.6).

Out of scope (per design Non-goals):

- Any other build directory (`build`, `build-cuda`, etc.).
- `CMakePresets.json` or root `CMakeLists.txt`.
- The F-17-EXEC-01 moved validation block (lines 1384-1428) stays
  untouched. The F-17-EXEC-02 unit test additions stay untouched.

## Item 1: Remove duplicate cold-path-hybrid check

The post-slot-init block at lines 1553-1566 contains a duplicate of the
cold-path-hybrid validation that the F-17-EXEC-01 move already enforces
at lines 1417-1420 (same SRV_ERR message and same throw string, but
the moved block has additional `cache_cold_max_mib != 0` and
`!cache_cold_path.empty()` conditions that the duplicate does not have).
The duplicate is unreachable in the common case but still catches one
edge case (see F-18-DR-01).

### Item 1 steps

1. Read `tools/server/server-context.cpp` lines 1545-1575 to confirm
   the current state: comment at 1552, outer guard at 1553, inner
   if-block at 1554-1557 (SRV_ERR 1555, throw 1556, closing brace 1557),
   cold-budget log lines at 1558-1565, closing brace of outer guard at
   1566.
2. Read `tools/server/server-context.cpp` lines 1410-1430 to confirm
   the moved block's structure: three validation checks ending with
   the cache-cold-path vs cache-mode check at lines 1417-1420
   (same SRV_ERR message and same throw string as the duplicate).
3. Apply the deletion of lines 1554-1557 only. Do not touch the outer
   guard at line 1553, the cold-budget log lines at 1558-1565, or the
   moved block at lines 1410-1430.
4. Apply the comment update at line 1552. Remove the
   `// Phase 6: Validate cold path configuration` comment (the
   surrounding code is self-explanatory after the deletion; the design
   recommends removal over rewriting).
5. Verify no other references to the deleted throw message or the
   removed comment via
   `Select-String -Path tools/server/server-context.cpp -Pattern 'cache-cold-path requires --cache-mode hybrid'`.
   Expect exactly 1 match at lines 1419-1420.
6. Build `test-cache-controller.exe` via
   `cmake --build build-cov --config Release --target test-cache-controller -j 4`.
   Expect exit 0.
7. Build `llama-server.exe` via
   `cmake --build build-cov --config Release --target llama-server -j 4`.
   Expect exit 0.
8. Run `build-cov/bin/Release/test-cache-controller.exe` directly. Expect
   89/89 PASS (74 pre-Stage 17 + 15 Stage 17 `test_stage17_*` functions).
9. Capture the focused diff via
   `git diff HEAD -- tools/server/server-context.cpp`. Expect 4 lines
   removed (1554-1557) plus the comment removed at 1552 (5 lines total).

### Post-implementation evidence (F-18-DR-01 resolution)

Step 8 evidence is the primary input. If `test-cache-controller.exe`
passes 89/89, the common case is unaffected. The corner case
`--cache-cold-path X --cache-cold-max-mib 0 --cache-mode legacy` is
addressed by TP-18-IT1 in the test plan; the implementation evidence
records the actual server exit code and error message for that
configuration. If the server starts without erroring (the post-deletion
behavior predicted by the F-18-DR-01 analysis), the evidence documents
this as "cold writes disabled makes the cold-path config dead; silent
proceed is acceptable per the design's recommendation that deletion is
still reasonable for the common case." If the server still errors
(some path was missed), STOP and escalate to Manager.

## Item 2: Add /Zi /DEBUG:FULL to CMAKE_CXX_FLAGS_RELEASE

`build-cov/CMakeCache.txt` line 80 currently shows
`CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` (verified 2026-06-18).
Without `/Zi` (program database) and `/DEBUG:FULL` (full debug info),
OpenCppCoverage produces header-only `.cov` files with no line counts,
which blocks the closure contracts T114, T114a, and T115 inherited from
Stage 10. Adding these flags lets the coverage tool emit line-count
data while keeping `/O2 /Ob2` (full optimization, no `/Ob1` regression).

### Item 2 steps

1. Read `build-cov/CMakeCache.txt` lines 78-100 to confirm the current
   flag values: line 80 `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG`,
   line 83 `CMAKE_CXX_FLAGS_RELWITHDEBINFO:STRING=/O2 /Ob1 /DNDEBUG`
   (unchanged), line 98 `CMAKE_C_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG`.
2. Capture the original build-cov cmake configure flags (the set of
   `-D` flags originally used). The Stage 17 implementation evidence
   may have these; if not, run
   `cmake -B build-cov -LA` and record the cache values before
   reconfigure.
3. Run cmake reconfigure:

   ```powershell
   cmake -B build-cov -DCMAKE_BUILD_TYPE=Release `
         -DCMAKE_CXX_FLAGS_RELEASE="/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL" `
         -DCMAKE_C_FLAGS_RELEASE="/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL" `
         <original flags minus any duplicate of CMAKE_BUILD_TYPE>
   ```

   Note per F-18-DR-04: `-DCMAKE_BUILD_TYPE=Release` is a no-op for the
   Visual Studio 18 2026 generator (multi-config). It is included for
   documentation parity with the design's recorded command. The flags
   that take effect are the CMAKE_CXX_FLAGS_RELEASE and
   CMAKE_C_FLAGS_RELEASE values.
4. Verify `build-cov/CMakeCache.txt` line 80 now contains
   `/O2 /Ob2 /DNDEBUG /Zi /DEBUG:FULL` and line 98 contains the same
   for C flags. Line 83 (CMAKE_CXX_FLAGS_RELWITHDEBINFO) is unchanged
   (we are not modifying RelWithDebInfo).
5. Run a clean rebuild of `test-cache-controller.exe`:
   `cmake --build build-cov --config Release --target test-cache-controller -j 4`.
   Expect exit 0. The build takes longer than a normal Release build
   because every C++ TU is recompiled with `/Zi`. Plan for 5-10 minutes.
6. Run a clean rebuild of `llama-server.exe`:
   `cmake --build build-cov --config Release --target llama-server -j 4`.
   Expect exit 0.
7. Run `build-cov/bin/Release/test-cache-controller.exe` directly.
   Expect 89/89 PASS (74 + 15). The flags do not change runtime
   behavior; only PDB size grows.
8. Quick OpenCppCoverage smoke test: run OpenCppCoverage against
   `test-cache-controller.exe` with `--export_type binary:<path>` and
   confirm the `.cov` file is larger than the header-only baseline
   (>100 KB per binary) and contains line-count data. If OpenCppCoverage
   is not available, defer to TP-18-IT4 in the test plan.
9. Record the full cmake reconfigure command and the resulting flag
   values in the implementation evidence so the change is reproducible
   from a fresh build-cov.

### Build freshness

The full build-cov rebuild is required because every C++ translation
unit needs to be recompiled with `/Zi`. An incremental rebuild alone
(after just editing CMakeCache.txt) would not produce the new PDB;
the build system relies on the compile flags to know which translation
units are stale. Per developer self-improvement memory, a CMakeFiles
wipe must be followed by `cmake -S . -B build-cov` to regenerate
subproject vcxproj files before `cmake --build`. The Step 3 reconfigure
serves that role.

## Test plan reference

This implementation plan does not author the test plan; the Stage 18
design part 3 proposes 13 rows (7 focused + 6 integration) for the
test plan author to pick up in a follow-up. The implementation
evidence will reference these row IDs:

| ID | Type | Item | Description | Expected |
| --- | --- | --- | --- | --- |
| TP-18-FT1 | focused | 1 | Build + run test-cache-controller after Item 1 deletion | 89/89 PASS |
| TP-18-FT2 | focused | 1 | `git diff --check` on server-context.cpp | Clean |
| TP-18-FT3 | focused | 1 | Select-String count of duplicate validation string | 1 match |
| TP-18-FT4 | focused | 2 | Select-String CMAKE_CXX_FLAGS_RELEASE in CMakeCache.txt | Contains /Zi, /DEBUG:FULL |
| TP-18-FT5 | focused | 2 | Select-String CMAKE_C_FLAGS_RELEASE in CMakeCache.txt | Contains /Zi, /DEBUG:FULL |
| TP-18-FT6 | focused | 2 | Rebuild + run test-cache-controller with new flags | 89/89 PASS |
| TP-18-FT7 | focused | 2 | Rebuild + /health on llama-server with new flags | Server starts, /health 200 |
| TP-18-IT1 | integration | 1 | llama-server with cold-path + legacy mode | Clean bounded-error exit, no STATUS_STACK_BUFFER_OVERRUN |
| TP-18-IT2 | integration | 1 | llama-server with cold-path + hybrid mode | Server starts normally |
| TP-18-IT3 | integration | 1 | Re-run Stage 17 IT5 row | Clean bounded-error exit |
| TP-18-IT4 | integration | 2 | Re-run OpenCppCoverage against test-cache-controller | .cov file > 100 KB, line-count data |
| TP-18-IT5 | integration | 2 | End-to-end coverage script | .cov files have line data |
| TP-18-IT6 | integration | 2 | Chat completion with MTP fixture on new flags | Server starts, completion succeeds |

## Evidence plan

Implementation evidence will record:

- Pre-state evidence (read-only): `git log --oneline -3 -- tools/server/server-context.cpp build-cov/CMakeCache.txt`
  (already captured 2026-06-18: HEAD is 23a1d4593 on work-branch).
- Pre-state evidence (read-only): `git diff HEAD -- tools/server/server-context.cpp`
  (currently empty; no pre-existing edits on this path).
- Item 1 evidence: diff scope (5 lines removed: 1552 comment + 1554-1557
  inner if-block), Select-String count after deletion (1 match at
  1419-1420), test-cache-controller 89/89, llama-server build success,
  TP-18-IT1 corner-case behavior documented.
- Item 2 evidence: cmake reconfigure command (with full flag set),
  CMakeCache.txt line 80/98 updated, CMakeCache.txt line 83 unchanged,
  test-cache-controller 89/89, llama-server build success, /health
  200, OpenCppCoverage smoke test result.
- Combined evidence: `git diff --stat HEAD` showing files changed
  (server-context.cpp only; build-cov is gitignored), focused test
  pass count (89/89), integration smoke test (default flags, /health,
  clean exit).

## Known risks

| # | Risk | Impact | Mitigation |
| --- | --- | --- | --- |
| 1 | F-18-DR-01 corner case (cold-path set, cold-max-mib 0, mode legacy) silently proceeds after Item 1 deletion | Low; cold writes disabled makes the config dead anyway | Step 1.6 records actual behavior in evidence; TP-18-IT1 verifies |
| 2 | Reconfiguring build-cov loses other cached variables | Low; only affects cmake invocation order | Step 2.2 captures original flags; Step 2.3 reapplies them with the new flag added |
| 3 | `/Zi` PDB size grows large (hundreds of MB for full llama-server) | Low; coverage builds already produce large PDBs | No CI artifact budget verified for this project. If budget is exceeded, follow-up de-flag is straightforward (one cmake reconfigure) |
| 4 | Coverage script paths assume `build-cov/bin/Release/`; new flags do not change paths | None | Paths unchanged. Evidence records the unchanged path |
| 5 | CMakeFiles wipe + reconfigure required for clean rebuild (per self-improvement memory) | Low; the Step 2.3 reconfigure covers it | Step 2.3 includes the reconfigure; no separate wipe planned |
| 6 | build-cov is gitignored; the cmake invocation is the durable record, not the file diff | Documentation only | Step 2.9 records the full reconfigure command in evidence |
| 7 | Item 1 and Item 2 are independent but sequenced in the plan; if Item 1 breaks a build, Item 2 cannot proceed | Low; Item 1 is a 4-line deletion with no API surface change | Item 1 Steps 1.6-1.8 confirm build success before Item 2 starts |

## Handoff

Next owner: **Architect for implementation-plan review in a fresh
session.**

If Architect implementation-plan review PASS, the plan advances to
Manager for the implementation-plan gate. After Manager implementation
gate PASS, the plan advances to implementation in this or a follow-up
Developer session.

Out of scope for this planning session (and to be done by other agents
in their own sessions):

- The Stage 17 implementation log, tracker, document-index, and any
  other durable doc are NOT modified by this plan. They will be
  updated by the Developer implementation session after this plan is
  approved, or by the Manager closure session after implementation.
- The 13-row test plan is a proposal in the design part 3; the
  test-plan author picks it up in a follow-up.
- No code, builds, tests, or commits are authorized at this planning
  gate. The plan is evidence by line counts, file paths, and command
  references; the implementation session will run the actual commands
  and capture real evidence.
