# Stage 28 design part 04: Verification plan

Status: design; Manager gate decision D28-DESIGN-01 2026-06-26
Date: 2026-06-26
Stage: 28 (Technical Debt Removal + Open Bug Fixes)
Owner: Architect (contract); Developer (evidence); QA (regression)

## Scope

Per-fix verification contract plus cross-fix regression. Existing
138-test pack must continue to pass after every fix. The Stage 24
runner must continue to produce a durable report at the configured
path. The Stage 27 fix (`demote_payload` -> `tx_demote_payload` at
line 3396) must continue to verify in the Stage 24 -07 rerun
signature (S03 hybrid 687 reqs vs 258 crash threshold).

---

## Per-fix verification contract

### R28-BUG-01 (TP-26-UT6 test artifact)

| Row | Verification | Pass criterion | Evidence path |
| --- | --- | --- | --- |
| V1.1 | Fix on disk | New abort pattern at lines 3707, 3716-3729, 3736-3751, 3758-3765 | Select-String output |
| V1.2 | Clean build | `cmake --build build-cuda --config Release --target test-cache-controller` exits 0 | `._test_output/build-r28-bug01.log` |
| V1.3 | 138-test pack | `test-cache-controller.exe` exits 0 with "All tests passed successfully!" | `._test_output/test-r28-bug01.log` |
| V1.4 | No regression on prior tests | 110 pre-TP-26-UT6 tests still PASS | `._test_output/test-r28-bug01.log` |
| V1.5 | TP-27-UT-01 still PASS | D-EXEC-24-03 regression test still reproduces and verifies fix | `._test_output/test-r28-bug01.log` |

### R28-BUG-02 (cold-store drift)

| Row | Verification | Pass criterion | Evidence path |
| --- | --- | --- | --- |
| V2.1 | Diagnosis step | One-shot diagnostic log shows orphan-file path = identified candidate | `._test_output/stage24-r28-bug02-diag.log` |
| V2.2 | Fix on disk | Change at the diagnosed line(s) | Select-String output |
| V2.3 | Clean build | `cmake --build build-cuda --config Release --target llama-server --target test-cache-controller` exits 0 | `._test_output/build-r28-bug02.log` |
| V2.4 | TP-28-UT-01 unit test | New test asserts `n_cold_payload_bytes == sum(cold_payload_bytes_by_id_) == filesystem_bytes` after diagnosed path | `._test_output/test-r28-bug02-unit.log` |
| V2.5 | Stage 24 -07 S02 hybrid rerun | Filesystem bytes <= 512 MiB budget (was 5.37 GiB) | `._design_docs/.test_reports/test-report-20260627-01.md` |
| V2.6 | S03 hybrid unchanged | S03 hybrid filesystem < 512 MiB and within per-id map sum | same report |
| V2.7 | D-EXEC-27-08 still verified | S03 hybrid 687+ reqs vs 258 crash threshold | same report |

### R28-BUG-03 (ASan LNK2038)

| Row | Verification | Pass criterion | Evidence path |
| --- | --- | --- | --- |
| V3.1 | CMake change on disk | `target_compile_options(ggml-cuda PRIVATE /fsanitize=address)` in side-channel CMakeLists | Select-String output |
| V3.2 | Clean rebuild | `cmake --build build-cuda-asan --config Release --target llama-server` exits 0 (was 274 LNK2038 errors) | `._test_output/build-r28-bug03-asan.log` |
| V3.3 | Binary functional | `llama-server.exe --version` exits 0 | `._test_output/version-r28-bug03.txt` |
| V3.4 | ASan runtime present | `clang_rt.asan_dynamic-x86_64.dll` exists in build output dir | `Get-ChildItem build-cuda-asan/bin/Release` |
| V3.5 | Future ASan test | TP-26-UT6 can now run with ASan+CUDA | out-of-scope for this stage |

---

## Cross-fix regression contract

After iteration 1 closes, run:

| Check | Command | Pass criterion |
| --- | --- | --- |
| Clean build | `cmake --build build-cuda --config Release --target llama-server --target test-cache-controller` | exit 0 |
| Unit tests | `build-cuda/bin/Release/test-cache-controller.exe` | "All tests passed!"; 138 + new tests |
| Stage 24 -07 rerun | `stage24-chat-s02-s03-comparison.ps1` against `build-cuda/bin/Release/llama-server.exe` | All 4 legs PASS; S03 hybrid >= 258 reqs (D-EXEC-27-08 still verified); S02 hybrid cold budget PASS (was FAIL-cold-budget in -07) |
| Runner exit | same | exit 0; durable report at configured path (was non-zero in -07 with `leak_scan` error) |

After iteration 2 closes, run iteration 1 cross-fix regression again
plus the new tests (TP-28-UT-02, TP-28-UT-03).

---

## Coverage expectations

Stage 28 fixes touch three locations (test file, production file, build
file). The hybrid cache code path is already covered by the 138-test
pack and the Stage 24 runner. No new coverage threshold required.

However, R28-BUG-02 introduces TP-28-UT-01 which adds one new
controller test covering the orphan-file path. R28-TD-03 adds
TP-28-UT-02 covering SEH activation. R28-TD-02 adds TP-28-UT-03
covering demote queue saturation. Total new tests: 3 (TP-28-UT-01..03).

---

## Test plan addendum (proposal for Manager)

Add three rows to the cache-handling-test-plan per row:

- TP-28-UT-01 cold-store per-id map equals filesystem bytes (in
  [cache-handling-test-plan](../cache-handling-test-plan.md) new
  part file `part-31-stage28-cold-store-drift-fix.md`).
- TP-28-UT-02 SEH activation smoke (Windows-only).
- TP-28-UT-03 demote queue saturation (R26-OBS-01).

Test plan authoring is separate durable doc work; deferred to test
plan follow-up per D-EXEC design contract.

---

## Durable report naming

Stage 28 reports follow the existing convention:

- Iteration 1: `.test_reports/test-report-20260627-01.md` (Stage 24
  rerun after R28-BUG-01..03 applied).
- Iteration 2: `.test_reports/test-report-20260627-02.md` (Stage 24
  rerun after R28-TD-01..07 applied).

Each report cites the previous report's verdict table as evidence
continuity.

---

## Existing invariants preserved

All Stage 24-27 invariants are preserved through this verification:

- F-21-EXEC-01 (prompt-only save): unchanged.
- F-21-RERUN-01 (descriptor tracking): unchanged.
- F-22-DR-01 (demotion coordination): unchanged by R28-BUG-02 fix
  (the cold-store accounting fix may adjust decrement timing but not
  the demotion state machine).
- I-25-01..03 (atomicity, isolation, durability): unchanged.
- D-EXEC-26-01 (SEH handler): unchanged.
- D-EXEC-26-02 (argv function-scope vector): unchanged.
- D-EXEC-26-02 cold-store per-id accounting: **strengthened** by
  R28-BUG-02 fix.
- D-EXEC-27-08 (tx_demote_payload at line 3396): unchanged.

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace, and stays under the 300-line durable-doc cap.
