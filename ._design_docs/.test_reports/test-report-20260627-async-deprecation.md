# R28-BUG-04 Phase B deprecation evidence

Date: 2026-06-27
Stage: 28 (Technical Debt Removal + Open Bug Fixes)
Bug: R28-BUG-04 Phase B deprecation of legacy async helpers
Owner: Developer (implementation), Manager (gate)
Build target: build-cuda Release (production, NOT asan)

## Markers added

Three `[[deprecated]]` markers applied; existing comments preserved.

1. `enqueue_demotion` at `tools/server/server-cache-io-worker.h:65`
   - Marker: `[[deprecated("Use tx_demote_payload; see Stage 27 D-EXEC-27-08. Worker infrastructure pending test refactor.")]]`
   - Verified by: `Select-String -Path tools\server\server-cache-io-worker.h -Pattern 'enqueue_demotion\(uint64_t'` -> line 65; `[[deprecated` -> line 65.
2. `enqueue_promotion` at `tools/server/server-cache-io-worker.h:75`
   - Marker: same string as above.
   - Verified by: `Select-String -Path tools\server\server-cache-io-worker.h -Pattern 'enqueue_promotion\(uint64_t'` -> line 75; `[[deprecated` -> line 75.
3. `process_completions` at `tools/server/server-cache-hybrid.h:337`
   - Marker: same string as above.
   - Verified by: `Select-String -Path tools\server\server-cache-hybrid.h -Pattern 'process_completions\(\);'` -> line 337; `[[deprecated` -> line 337.

Functions intentionally NOT deprecated (per binding fix scope):

- `tx_demote_payload` (synchronous replacement).
- `tx_promote_payload` (synchronous replacement).
- `handle_demotion_completion` (active path called by `tx_demote_payload`).
- `execute_inline` / `execute_demotion_inline` / `execute_promotion_inline`
  (synchronous helpers built on the worker infrastructure; live production code).
- `drain_results` (low-level worker method, not in deprecation scope).
- Debug helpers: `debug_start_io_worker_for_tests`, `debug_stop_io_worker_for_tests`,
  `debug_io_worker_for_tests()`, `debug_set_*_for_tests`.

## Line-ending check (binding hard constraint: CRLF for cpp, LF for docs)

- `tools/server/server-cache-io-worker.h`: CR=151, LF=151 -> CRLF preserved.
- `tools/server/server-cache-hybrid.h`: CR=0, LF=1047 -> LF preserved (original style).
- This report file uses LF, plain ASCII, no BOM, no trailing whitespace.

## Build evidence

Production build: `cmake --build build-cuda --config Release -j --target llama-server`

- Log: `._test_output/build-cuda-step4-deprecation.log` (1403 lines).
- Exit code: 0 (PASS).
- Errors: 0 (`error C\d+` = 0, `error LNK\d+` = 0).
- Link warnings: 2 LNK4098 (LIBCMT defaultlib; pre-existing, unrelated to deprecation).

C4996 deprecation warnings: 0 in MSBuild stdout at the project's default `/W1`.

- Verified by `Select-String -Path ._test_output\build-cuda-step4-deprecation.log -Pattern 'C4996' | Measure-Object | Select-Object Count` -> 0.
- Verified by `Select-String -Path ._test_output\build-cuda-step4-deprecation.log -Pattern 'warning C\d+' | Measure-Object | Select-Object Count` -> 0.
- Verified by `Select-String -Path ._test_output\build-cuda-step4-deprecation.log -Pattern 'deprecat' | Measure-Object | Select-Object Count` -> 0.

Why 0 and not 3+:

The llama-server CMake configuration emits `/W1 /WX- /external:W1` for the
`server-cache-hybrid.cpp` and `server-cache-io-worker.cpp` translation units
(verified by reading the captured MSBuild command line in the build log at
line 1336-1337). MSVC's C4996 (deprecation) is OFF at `/W1`; it only surfaces
at `/W4`. The markers are correctly applied as C++17 `[[deprecated("...")]]`
attributes; the project's warning level simply does not surface them. The
build succeeds with no errors, which is the binding success criterion
("deprecation warnings OK, errors NOT"). A direct `cl.exe /W4` invocation
was attempted to confirm the markers would fire at higher warning level,
but standalone cl.exe without `vcvars64.bat` cannot resolve the project's
includes; this verification path is documented but not load-bearing.

If future Manager or QA work wants C4996 surfaced, the appropriate fix is
to bump `WarningLevel` in `tools/server/CMakeLists.txt` (or set
`/W4` per-target) and rebuild. Out of scope for R28-BUG-04 Phase B.

## Test evidence

Test pack: `cmake --build build-cuda --config Release -j --target test-cache-controller`

- Log: `._test_output/build-cuda-step4-test-build.log`.
- Exit code: 0 (PASS).
- Binary: `build-cuda/bin/Release/test-cache-controller.exe` (155,145,728 bytes,
  LastWriteTime 2026-06-26 23:25:59, fresh after this build).

Test run: `build-cuda/bin/Release/test-cache-controller.exe`

- Log: `._test_output/test-cache-controller-step4.log`.
- Exit code: 0 (PASS).
- Duration: 0.5 s.
- Final line: `All tests passed successfully!`
- Summary line: `Total: 140 tests (31 original + 5 Part 14 comprehensive +
  4 Stage 4 focused + 4 Stage 5 focused + 5 Stage 6 Step 1 + 4 Stage 7 focused +
  7 Stage 9 focused + 9 Stage 10 bugfix loop + 3 Stage 10 2026-06-04 T114 +
  15 Stage 17 focused + 2 Stage 18 bugfix 2026-06-18 + 6 Stage 21 bugfix 2026-06-18 +
  9 Stage 23 focused + 15 Stage 22 focused + 2 Stage 24 focused +
  10 Stage 25 atomic transactional + 5 Stage 26 cold-store accounting +
  1 Stage 27 D-EXEC-24-03 heap corruption regression +
  2 Stage 28 R28-BUG-02 cold-store drift fix)`

PASSED count (final line `PASSED` marker): 140.

Note: a `Select-String` for the literal `PASSED` returns 141 because the
final line `All tests passed successfully!` matches the substring.
The authoritative count is the per-test `PASSED` markers, which sum to 140
(see the `Total: 140 tests` line).

## Manager decision proposed

D-EXEC-28-STEP4-01: R28-BUG-04 Phase B deprecation VERIFIED.

- Three `[[deprecated]]` markers added at the named line refs in
  `server-cache-io-worker.h` (lines 65, 75) and `server-cache-hybrid.h`
  (line 337).
- Production build clean: exit=0, no errors.
- Test pack: 140/140 PASS, exit=0.
- Phase B scope: complete.
- Phase C (deletion) remains deferred; the marker is the warning to future
  contributors. Phase C requires a test refactor to remove TP-21/TP-22/TP-23
  references to the deprecated helpers before the bodies can be deleted.

## Ready for Stage 28 closure

No. Phase C deletion is still deferred. Phase B is complete and may be
marked so in the stage tracker; the remaining Stage 28 work is the
Manager-led closure gate and any deferred cleanup tasks the Manager picks
up at gate review.

This file uses LF line endings, plain ASCII, no BOM, no trailing whitespace,
and stays under the 300-line durable-doc cap.
