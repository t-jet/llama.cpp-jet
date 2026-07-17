# Part 39: live pressure seam correction plan

Date: 2026-07-13
Status: INDEPENDENT ARCHITECT RE-REVIEW PASS (DESIGN PART 14)
Authority: design Part 11 and D39-EXEC-01

## Change set

1. In `tools/server/CMakeLists.txt`, add default-OFF
   `LLAMA_STAGE39_LIVE_TEST_SEAM` compilation for server-context and server
   route code. Do not reuse `LLAMA_SERVER_CACHE_TESTS` as the only guard.
2. In `server-cache-hybrid.h/.cpp`, add guarded request, snapshot, validation,
   and one-shot apply types. Hold `cache_state_mutex_`; validate separate exact
   complete hot-candidate and cold-residency eligible-victim sets. Require live
   ownership and unique payload and owner IDs across both sets, unique hot
   ranks, and no omitted or extra eligible victim. Reindex each hot owner once;
   set only rank fields and positive lower budgets; call `tx_update()` once.
   Add no direct outcome mutation.
3. In `server-context.h/.cpp`, add one completion-admission latch shared by task
   dispatch and control. Hold it from idle check through final snapshot or
   failure cleanup. Consume before first mutation. Validation failures remain
   retryable; all later failures remain terminal. Add strict JSON conversion.
4. In `server.cpp`, read the two runtime opt-ins, enforce loopback/single-model/
   hybrid/metrics/positive-budget prerequisites, and conditionally register
   POST `/debug/cache/stage39-live-pressure`. Use constant-time token comparison
   and never log the token.
5. In `._design_docs/cache-handling-test-scripts/stage39-two-layer-pressure.ps1`,
   add `tp39-02`, `tp39-03`, and `tp39-04`
   seam scenarios. Start with measured high budgets, admit model-backed pairs,
   submit one control request, then retain existing metrics, log, response,
   inventory, and reconciliation checks. Write `control-request.json` and
   `control-response.json`; fail on any missing required field or tuple.
6. In `._design_docs/cache-handling-test-scripts/run_coverage.ps1`, replace only
   the Phase 3 dummy tail with absolute no-argument `whoami.exe`; throw
   immediately on nonzero merge exit.

## Tests

- Extend `tests/test-cache-controller.cpp` with
  `test_stage39_live_pressure_control_validation`,
  `test_stage39_live_pressure_tp39_02_multi_victim`,
  `test_stage39_live_pressure_tp39_03_both_filled`, and
  `test_stage39_live_pressure_tp39_04_oversized_both`. Assert duplicate payload,
  owner, and rank rejection within and across arrays; missing and extra hot
  candidates and cold victims; owner mismatch; hot/cold residency mismatch; no
  unlisted eligible cold victim; deterministic tie-break; exact tuple;
  topology; accounting; and one final decision per candidate.
- Add `test_stage39_live_pressure_idle_dispatch_race` and
  `test_stage39_live_pressure_terminal_after_mutation_failure` to that target.
  Pause after idle verification and prove queued completion dispatch stays
  blocked. Inject failures before and after `tx_update()` and prove terminal
  state, pre-pressure restoration, and production recovery ownership.
- Add route tests in `tools/server/tests/unit/test_stage39_live_pressure.py`.
  Prove compile-OFF and runtime-OFF absence, startup guard rejection, token and
  schema rejection, validation retry, idle race, redaction, terminal one-shot,
  and one success. Use the exact OFF/ON commands below.
- Run the PowerShell metric-validation self-test plus parser checks in Windows
  PowerShell 5 and PowerShell 7. Dry-run/static assertions must verify high
  startup budgets precede admission and control follows completed admissions.

## Exact build and route commands

Run from repository root in a clean command environment:

```powershell
cmake -S . -B build-stage39-seam-off -DLLAMA_STAGE39_LIVE_TEST_SEAM=OFF -DLLAMA_BUILD_TESTS=ON
cmake --build build-stage39-seam-off --config Release --target llama-server test-cache-controller
$env:LLAMA_SERVER_BIN_PATH = (Resolve-Path 'build-stage39-seam-off/bin/Release/llama-server.exe').Path
python -m pytest -q tools/server/tests/unit/test_stage39_live_pressure.py -k test_compile_off_route_absent
```

All four commands must exit 0. The named test must receive HTTP 404 and find no
route symbol in the OFF binary. Then run the ON build and route map:

```powershell
cmake -S . -B build-stage39-seam-on -DLLAMA_STAGE39_LIVE_TEST_SEAM=ON -DLLAMA_BUILD_TESTS=ON
cmake --build build-stage39-seam-on --config Release --target llama-server test-cache-controller
$env:LLAMA_SERVER_BIN_PATH = (Resolve-Path 'build-stage39-seam-on/bin/Release/llama-server.exe').Path
python -m pytest -q tools/server/tests/unit/test_stage39_live_pressure.py
```

All four commands must exit 0. Named cases are
`test_runtime_off_route_absent`, `test_startup_guard_rejection`,
`test_token_and_schema_rejection`, `test_validation_retry`,
`test_idle_dispatch_race`, `test_redaction`,
`test_terminal_after_mutation_failure`, and `test_runtime_on_success`.
`test_runtime_on_success` must preserve `control-request.json` and
`control-response.json`; absence and rejection cases must create no control
artifact. Run the Release controller executable separately and require exit 0:

```powershell
& 'build-stage39-seam-on/bin/Release/test-cache-controller.exe'
```

## Executable coverage fail-closed probes

Use this literal disposable fixture at
`._test_output/stage39-coverage-rereview/coverage-probes/OpenCppCoverage-force-merge-fail.cmd`:

```bat
@echo off
setlocal
for %%A in (%*) do if /I "%%~A"=="--input_coverage" exit /b 23
"%STAGE39_REAL_OC%" %*
exit /b %ERRORLEVEL%
```

Set `STAGE39_REAL_OC` to the absolute real OpenCppCoverage executable. The
fixture delegates every capture call and returns 23 only for a merge call.
Create the fixture before these runs and preserve it with all logs.

PowerShell 7 success and forced failure:

```powershell
$root = (Resolve-Path '.').Path
$runner = Join-Path $root '._design_docs/cache-handling-test-scripts/run_coverage.ps1'
$model = Join-Path $root '._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf'
$realOc = 'D:/app/OpenCppCoverage/OpenCppCoverage.exe'
$fixture = Join-Path $root '._test_output/stage39-coverage-rereview/coverage-probes/OpenCppCoverage-force-merge-fail.cmd'
$env:STAGE39_REAL_OC = $realOc
$ok = Join-Path $root '._test_output/stage39-coverage-rereview/success-pwsh7'
$fail = Join-Path $root '._test_output/stage39-coverage-rereview/fail-pwsh7'
if ((Test-Path $ok) -or (Test-Path $fail)) { throw 'pwsh7 output must be fresh' }
& pwsh.exe -NoProfile -File $runner -BuildDir "$root/build-stage39-seam-on" -SourceRoot $root -OutDir $ok -ModelPath $model -OcPath $realOc *> "$ok.log"
if ($LASTEXITCODE -ne 0) { throw "pwsh7 success exit $LASTEXITCODE" }
& pwsh.exe -NoProfile -File $runner -BuildDir "$root/build-stage39-seam-on" -SourceRoot $root -OutDir $fail -ModelPath $model -OcPath $fixture *> "$fail.log"
if ($LASTEXITCODE -ne 1) { throw "pwsh7 forced exit $LASTEXITCODE" }
```

Windows PowerShell 5 success and forced failure:

```powershell
$root = (Resolve-Path '.').Path
$runner = Join-Path $root '._design_docs/cache-handling-test-scripts/run_coverage.ps1'
$model = Join-Path $root '._test_models/Qwen3-0.6B-GGUF/Qwen3-0.6B-Q8_0.gguf'
$realOc = 'D:/app/OpenCppCoverage/OpenCppCoverage.exe'
$fixture = Join-Path $root '._test_output/stage39-coverage-rereview/coverage-probes/OpenCppCoverage-force-merge-fail.cmd'
$env:STAGE39_REAL_OC = $realOc
$ok = Join-Path $root '._test_output/stage39-coverage-rereview/success-powershell5'
$fail = Join-Path $root '._test_output/stage39-coverage-rereview/fail-powershell5'
if ((Test-Path $ok) -or (Test-Path $fail)) { throw 'powershell5 output must be fresh' }
& powershell.exe -NoProfile -File $runner -BuildDir "$root/build-stage39-seam-on" -SourceRoot $root -OutDir $ok -ModelPath $model -OcPath $realOc *> "$ok.log"
if ($LASTEXITCODE -ne 0) { throw "powershell5 success exit $LASTEXITCODE" }
& powershell.exe -NoProfile -File $runner -BuildDir "$root/build-stage39-seam-on" -SourceRoot $root -OutDir $fail -ModelPath $model -OcPath $fixture *> "$fail.log"
if ($LASTEXITCODE -ne 1) { throw "powershell5 forced exit $LASTEXITCODE" }
```

Each success directory must contain `coverage-merged.xml` and
`coverage-report.md`; the report must record at least 80 percent. Each failure
log must contain `OpenCppCoverage merge failed with exit code 23`; its fresh
directory must contain capture `.cov` files but neither `coverage-merged.xml`
nor `coverage-report.md`. Record all four exits and preserve each output tree.

## Required implementation evidence

Record exact files and test names, compile definitions for OFF and ON builds,
route-absence proof, misuse-rejection results, controller/route test output,
PowerShell 5/7 output, coverage merge probes, and a model-backed smoke showing
`tx_save` before control and production decision/log/metric output after it.

Do not claim TP-39-02 through TP-39-04 PASS during implementation. Fresh QA owns
their verdicts. Independent Architect review of code, tests, script, and
evidence is required before QA execution.

## Binding row assertions

| Row | Controller assertion | Live assertion |
| --- | --- | --- |
| TP-39-02 | `test_stage39_live_pressure_tp39_02_multi_victim`: full set, unique owners, equal-rank payload-ID order, two tombstones, commit, accounting, one decision per candidate | `Assert-Tp3902`: ordered victims, incoming ownership, `retained_cold/cold_room_made`, commit, zero topology delta |
| TP-39-03 | `test_stage39_live_pressure_tp39_03_both_filled`: no eligible cold victim, one tombstone, exact `evicted/both_filled`, bounded gauges | `Assert-Tp3903`: measured pair fits lowered hot alone, cold cannot accept, one tuple, zero topology delta |
| TP-39-04 | `test_stage39_live_pressure_tp39_04_oversized_both`: high-budget admission precedes lowering, exact `evicted/oversized_both`, pair atomicity | `Assert-Tp3904`: both measured sizes exceed lowered budgets, one tuple, no partial pair, zero topology delta |
