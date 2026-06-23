# Stage 23 implementation: full S/L matrix execution plan

Status: Manager closure PASS
Date: 2026-06-23
Stage: 23 (Full S/L Matrix Execution)
Owner: QA
Source design: [cache-handling-phase23-design.md](cache-handling-phase23-design.md)
Scope: execution planning, reviewed harness correction, and S03 product-fix review history. Architect did not edit product code.
Current gate: Stage 23 closed PASS
## Purpose
Stage 23 runs the deferred S/L matrix from Stage 20: stress rows S01..S08 and longrun rows L01..L03. This is the run plan and wrapper readiness checklist, not the full matrix evidence report.
## Correction record
QA review gate 01 returned REWORK. [Part 2](cache-handling-phase23-implementation/part-02-execution-plan-rework-corrections.md) records Stage 17 flags, the Qwen3.5 MTP model path, `._test_output` row roots, and batch/row side-log gates.
QA re-review gate 01 found one remaining blocker. [Part 4](cache-handling-phase23-implementation/part-04-longrun-before-metrics-correction.md) records the L01..L03 before-metrics correction. QA re-review gate 02 passed in [part 5](cache-handling-phase23-implementation/part-05-execution-plan-re-review-gate-02.md). Manager CUDA gate D23-CUDA-01/02 is recorded in [part 7](cache-handling-phase23-implementation/part-07-manager-cuda-gate.md).
Manager test-execution gate D23-EXEC-01/02 stopped the matrix at S03. The S03
product fix handoff is recorded in [part 9](cache-handling-phase23-implementation/part-09-s03-product-fix-handoff.md).
Architect S03 fix review gate 01 returned REWORK in [part 10](cache-handling-phase23-implementation/part-10-architect-s03-fix-review-gate-01.md).
Part 11 records correction evidence; Architect re-review PASS is in [part 12](cache-handling-phase23-implementation/part-12-architect-s03-fix-re-review-gate-02.md).
Manager accepted the S03 fix gate in [part 13](cache-handling-phase23-implementation/part-13-manager-s03-fix-gate.md).
Focused S03 rerun failed before health; Manager stop gate is in [part 14](cache-handling-phase23-implementation/part-14-manager-s03-rerun-gate-01.md).
The S03 startup-crash fix is recorded in [part 15](cache-handling-phase23-implementation/part-15-s03-startup-crash-fix.md).
Architect review of the startup-crash fix passed in [part 16](cache-handling-phase23-implementation/part-16-architect-s03-startup-crash-fix-review.md).
The focused CUDA S03 rerun failed with a product crash in [stage23-s03-rerun-20260621-09.md](.test_reports/stage23-s03-rerun-20260621-09.md).
Developer review confirms product bug F-23-S03-RERUN09-01 in [stage23-s03-rerun-20260621-09-developer-review.md](.test_reports/stage23-s03-rerun-20260621-09-developer-review.md).
The Developer fix for F-23-S03-RERUN09-01 is recorded in [stage23-s03-rerun-20260621-09-fixes.md](.test_reports/stage23-s03-rerun-20260621-09-fixes.md).
Architect bugfix review PASS is recorded in [stage23-s03-rerun-20260621-09-bugfix-review.md](.test_reports/stage23-s03-rerun-20260621-09-bugfix-review.md). The focused CUDA S03 rerun passed in [stage23-s03-rerun-20260621-10.md](.test_reports/stage23-s03-rerun-20260621-10.md): clean build, CUDA active, wrapper dry-run PASS, live S03 wrapper exit 0, row gate OK, 5056 requests, after metrics present, redacted prompt evidence present, and cold bytes under the 512 MiB budget.
Manager decision D23-RESUME-01 (2026-06-21): resume Stage 23 test execution at the remaining rows S04..S08 and L01..L03. S01/S02 from the valid CUDA report and focused S03 report 10 remain accepted evidence. QA must use a fresh durable report and fresh output root for the remaining rows, keep S04..S08 before L01..L03, preserve clean-build and CUDA gates, and stop on the first product crash, runner-contract failure, prompt leak, or setup blocker that invalidates row evidence.
S04 sub-session [stage23-remaining-s04-20260621-01.md](.test_reports/stage23-remaining-s04-20260621-01.md) PASS: clean build, CUDA active, wrapper dry-run PASS, live S04 wrapper exit 0, row gate OK, 6272 requests, after metrics present, redacted prompt evidence present, raw prompt-key scan clean, and cold bytes under the 512 MiB budget. S05..S08 and L01..L03 remain not run in this sub-session.
S05 sub-session [stage23-remaining-s05-20260621-01.md](.test_reports/stage23-remaining-s05-20260621-01.md) BLOCKED-runner-contract: clean build, CUDA active, wrapper dry-run PASS, live S05 evidence preserved, but the S05 row script ran three 30 minute profiles under a Stage 23 30 minute row cap. The wrapper parent timed out and no `row_gate` or `batch_end` was written. This is a setup/runner block, not a product bug. Manager owns the S05 disposition before any S06 sub-session opens.
Developer S05 runner-contract fix [stage23-remaining-s05-20260621-01-fixes.md](.test_reports/stage23-remaining-s05-20260621-01-fixes.md) changes the S05 script to treat `DurationMin` as the whole row cap and split it across the three mixed workload profiles. Wrapper dry-run/live side logs now print the S05 profile allocation before rerun. No product code, public metrics, public flags, tests, or fixtures changed. Architect bugfix review PASS is recorded in [stage23-remaining-s05-20260621-01-bugfix-review.md](.test_reports/stage23-remaining-s05-20260621-01-bugfix-review.md). Focused S05 rerun [stage23-remaining-s05-20260621-02.md](.test_reports/stage23-remaining-s05-20260621-02.md) PASS: clean build, CUDA active, dry-run and live profile allocation 600/600/600 seconds, wrapper exit 0, `row_gate` and `batch_end` present, 1599 requests across three profiles, redacted prompt evidence present and raw-key scan clean, no HTTP 500/error/corrupt lines, and cold bytes under the 512 MiB budget.
S06 sub-session [stage23-remaining-s06-20260621-01.md](.test_reports/stage23-remaining-s06-20260621-01.md) BLOCKED-runner-contract: clean build, CUDA active, wrapper dry-run PASS, live S06 wrapper exit 0, `row_gate` and `batch_end` present, 1596 requests, redacted prompt evidence present and raw-key scan clean, no HTTP 500/error/corrupt/write-failure lines, and cold bytes under the 512 MiB budget. The run did not exercise cold queue pressure because the Stage 23 wrapper appended `--cache-ram 512` after S06's local `--cache-ram 16`; server logs show the effective limit was 512.000 MiB, with 0 demotions, 0 skipped demotions, 0 cold evictions, and 0 cold files. Current gate: Manager owns S06 disposition before any S07 sub-session opens. S07..S08 and L01..L03 remain not run.
Developer S06 runner-contract fix [stage23-remaining-s06-20260621-01-fixes.md](.test_reports/stage23-remaining-s06-20260621-01-fixes.md) changes the wrapper contract for S06 only: the encoded Stage 17 flags no longer append wrapper `--cache-ram 512`, the child receives explicit `-HotBudgetMiB 16`, and dry-run/live side logs print `effective_cache_ram_mib=16`. Required Stage 23 flags still pass through S06: CUDA, fit off, cold max 512, cold path, redacted prompt evidence, evidence directory, model, and run root. Other rows still receive wrapper `--cache-ram 512`. Architect bugfix review PASS is recorded in [stage23-remaining-s06-20260621-01-bugfix-review.md](.test_reports/stage23-remaining-s06-20260621-01-bugfix-review.md). No product code, public metrics, public flags, tests, fixtures, commits, or pushes changed. Current gate: Manager accepts the review before QA runs focused S06 with a fresh suffix; S07..S08 and L01..L03 remain not run.
Focused S06 rerun [stage23-remaining-s06-20260621-02.md](.test_reports/stage23-remaining-s06-20260621-02.md) BLOCKED-runner-contract: clean build, CUDA active, dry-run PASS, live wrapper exit 0, `row_gate` and `batch_end` present, 1593 requests, redacted prompt evidence present and raw prompt scan clean, no HTTP 500/error/corrupt/write-failure lines, cold bytes under the 512 MiB budget, and the effective hot limit fixed at 16 MiB. The row still did not exercise cold queue pressure: after metrics show 0 demotions, 0 skipped demotions, 0 cold evictions, and 0 cold files. This is a setup/runner evidence gap, not a product failure.
Developer S06 pressure-workload fix [stage23-remaining-s06-20260621-02-fixes.md](.test_reports/stage23-remaining-s06-20260621-02-fixes.md) keeps S06 at 16 MiB hot budget and required Stage 23 flags, but uses the existing Qwen3-0.6B pressure fixture for S06 only because the Qwen3.5 MTP payload is about 50 MiB and cannot be admitted under 16 MiB. Architect review PASS is recorded in [stage23-remaining-s06-20260621-02-bugfix-review.md](.test_reports/stage23-remaining-s06-20260621-02-bugfix-review.md). Focused S06 rerun [stage23-remaining-s06-20260622-01.md](.test_reports/stage23-remaining-s06-20260622-01.md) PASS: clean build, CUDA active, dry-run and live S06 pressure-workload side logs present, live pressure model `Qwen3-0.6B-Q8_0.gguf`, primary Qwen3.5 model recorded in notes, effective hot limit 16 MiB, cold budget 512 MiB, wrapper exit 0, `row_gate` and `batch_end` present, 1605 requests, 1604 demotions, 1467 cold evictions, 0 write errors, redacted prompt evidence clean, and cold bytes under budget.
Focused S07 run [stage23-remaining-s07-20260622-01.md](.test_reports/stage23-remaining-s07-20260622-01.md) BLOCKED-runner-contract: clean build, CUDA active, `test-cache-controller`, `test-step12-branch-graph`, and `tools/server/tests/unit/test_cache_modes.py` passed; dry-run and live S07 wrapper exit were 0; `row_gate` and `batch_end` were present; 4077 requests completed; metrics-before/after and redacted prompt evidence were present; redacted and error scans were clean; cold bytes stayed under the 512 MiB budget. The live S07 row did not exercise protected-root pressure because the Stage 23 wrapper appended `--cache-ram 512` after S07's local `--cache-ram 8`; server logs show the effective hot limit was 512 MiB, with 0 protected-root decisions, 0 protected-root demotions, 0 hot evictions, and 0 demotions. This is a setup/runner evidence gap, not a product failure. Current gate: Manager owns S07 disposition before any S08 sub-session opens; S08 and L01..L03 remain not run.
Developer S07 runner-contract fix [stage23-remaining-s07-20260622-01-fixes.md](.test_reports/stage23-remaining-s07-20260622-01-fixes.md) changes the wrapper contract for S07 only: the encoded Stage 17 flags no longer append wrapper `--cache-ram 512`, the child receives explicit `-HotBudgetMiB 8`, and dry-run/live side logs print `effective_cache_ram_mib=8`. Architect review PASS is recorded in [stage23-remaining-s07-20260622-01-bugfix-review.md](.test_reports/stage23-remaining-s07-20260622-01-bugfix-review.md). Focused S07 rerun [stage23-remaining-s07-20260622-03.md](.test_reports/stage23-remaining-s07-20260622-03.md) remains BLOCKED-runner-contract: the 8 MiB flag contract worked, but Qwen3.5 payloads are about 50 MiB and every save was rejected before pressure could run. Developer S07 pressure-workload fix [stage23-remaining-s07-20260622-03-fixes.md](.test_reports/stage23-remaining-s07-20260622-03-fixes.md) makes S07 use the Qwen3-0.6B pressure fixture when available, records the primary Qwen3.5 model in notes, and uses unique non-protected pressure prompts under the same 8 MiB budget. Architect review PASS is recorded in [stage23-remaining-s07-20260622-03-bugfix-review.md](.test_reports/stage23-remaining-s07-20260622-03-bugfix-review.md): QA may accept focused S07 from live payload pressure plus focused trusted protected-root controller evidence; live public degraded protected-root counters are not required. Focused S07 rerun [stage23-remaining-s07-20260622-04.md](.test_reports/stage23-remaining-s07-20260622-04.md) PASS: clean build, CUDA active, `test-cache-controller`, `test-step12-branch-graph`, and `tools/server/tests/unit/test_cache_modes.py` passed; trusted protected-root controller lines covered `hybrid payload budget eviction`, `hybrid multiple protected evictions count decisions`, and `hybrid protected admission rejection stats`; dry-run and live S07 pressure-workload side logs were present; live pressure model `Qwen3-0.6B-Q8_0.gguf`, primary Qwen3.5 model recorded in notes, effective hot limit 8 MiB, cold budget 512 MiB, wrapper exit 0, `row_gate` and `batch_end` present, 4521 requests, 1487 admitted entries, 4479 demotions, 22 payload evictions, 1685 cold evictions, 0 oversize rejects, redacted prompt evidence clean, and cold bytes under budget. Public protected-root counters remained 0 and were accepted only with focused trusted protected-root evidence. S08 and L01..L03 remain not run.
Focused S08 run [stage23-remaining-s08-20260622-01.md](.test_reports/stage23-remaining-s08-20260622-01.md) PASS: clean build, CUDA active, bounded `test-cache-controller` rerun PASS, `test-step11-test-hooks-fault-injection` PASS with 17/17 focused fault cases, dry-run S08 only with required Stage 23 flags, live S08 row gate and batch end present, focused precondition `Stub: False` with fault exit 0, 1592 requests over 30 minutes, redacted prompt evidence clean, no HTTP 500/crash/exception/corrupt/write-failure/error patterns, and cold bytes 0 under the 512 MiB budget. Stress rows S01..S08 are now PASS. L01..L03 remain not run.
Focused L01 run [stage23-remaining-l01-20260622-01.md](.test_reports/stage23-remaining-l01-20260622-01.md) PASS: clean build, CUDA active, dry-run L01 only with required Stage 23 flags, wrapper OS exit 0, `row_gate` and `batch_end` present, metrics before/after present, 120 requests over the two hour V2 cap, all 120 liveness samples true, after-warmup working set delta 0.005%, after-warmup handle delta 0.000%, redacted prompt evidence clean, no HTTP 500/crash/exception/corrupt/write-failure/error/host allocation patterns, and cold bytes 0 under the 512 MiB budget. L02 and L03 remain not run.
Focused L02 run [stage23-remaining-l02-20260622-01.md](.test_reports/stage23-remaining-l02-20260622-01.md) BLOCKED-runner-contract: clean build, CUDA active, dry-run L02 only with required Stage 23 flags, wrapper OS exit 0, `row_gate` and `batch_end` present, metrics before/after present, 60 requests over the 30 minute cap, all 60 liveness samples true, redacted prompt evidence clean, no HTTP 500/crash/exception/corrupt/write-failure/error/host allocation product patterns, and cold bytes 0 under the 512 MiB budget. The row did not produce the required legacy comparison evidence: the child script ran one hybrid leg only, did not start a legacy control leg, did not write a paired baseline or comparison artifact, and left `evidence-summary.md` at `PENDING`. This is a runner contract block, not a product failure. L03 remains not run.
Developer L02 runner-contract fix [stage23-remaining-l02-20260622-01-fixes.md](.test_reports/stage23-remaining-l02-20260622-01-fixes.md) changes the L02 child runner to split the 30 minute row cap into a bounded `legacy-control` leg and a bounded `hybrid-stage23` leg, write per-leg mode and flag evidence, write `l02-comparison.json`, and end root `evidence-summary.md` with non-PENDING status when both legs make requests. The Stage 20 wrapper now prints the L02 comparison plan in dry-run/live side logs and requires `l02-comparison.json` plus `evidence-summary.md` in the L02 row gate. A 60 second child smoke passed with paired artifacts. Architect bugfix review PASS is recorded in [stage23-remaining-l02-20260622-01-bugfix-review.md](.test_reports/stage23-remaining-l02-20260622-01-bugfix-review.md). Focused L02 rerun [stage23-remaining-l02-20260622-02.md](.test_reports/stage23-remaining-l02-20260622-02.md) PASS: clean build, CUDA active, dry-run and live comparison plan present, wrapper OS exit 0, `row_gate` and `batch_end` present, 900 second legacy-control leg plus 900 second hybrid-stage23 leg, 30 requests per leg, `l02-comparison.json` status PASS, root `evidence-summary.md` Result PASS, hybrid redacted prompt evidence clean, no product error patterns, and cold bytes under the 512 MiB budget. Focused L03 run [stage23-remaining-l03-20260622-01.md](.test_reports/stage23-remaining-l03-20260622-01.md) BLOCKED-runner-contract: clean build, CUDA active, dry-run L03 only with required Stage 23 flags, live wrapper OS exit 0, `row_gate` and `batch_end` present, 120 requests over two hours, all 120 liveness samples true, metrics before/after present, redacted prompt evidence clean, no product error patterns, and cold bytes 0 under the 512 MiB budget. The row did not prove the required mixed workload longrun: the child script reports `Variant: legacy-2h`, sends one repeated legacy-control probe, produces only `profile=checkpoint_dependent` and `lookup_outcome=exact_entry_absent`, and leaves `evidence-summary.md` at `PENDING`. This is a runner contract block, not a product failure.
Developer L03 runner-contract fix [stage23-remaining-l03-20260622-01-fixes.md](.test_reports/stage23-remaining-l03-20260622-01-fixes.md) changes the L03 child runner to run a Stage 23 hybrid mixed workload instead of the legacy-control loop. The two hour cap is split across exact/cache_prompt, checkpoint-dependent, near/non-exact, and new/uncached prompt classes; `l03-mixed-workload.json` records profile counts, metrics deltas, prompt-evidence outcomes, checksum/lookup-path spread, mode flags, and status; root `evidence-summary.md` no longer remains `PENDING` when all classes make requests. The wrapper now prints the L03 mixed-workload plan in dry-run/live side logs and requires `l03-mixed-workload.json` plus `evidence-summary.md` for L03 only. Parse checks, wrapper dry-run, child dry-run, and a 60 second child smoke passed. Architect bugfix review PASS is recorded in [stage23-remaining-l03-20260622-01-bugfix-review.md](.test_reports/stage23-remaining-l03-20260622-01-bugfix-review.md). Focused L03 rerun [stage23-remaining-l03-20260622-02.md](.test_reports/stage23-remaining-l03-20260622-02.md) PASS: clean build, CUDA active, dry-run and live mixed-workload plan present, wrapper OS exit 0, `row_gate` and `batch_end` present, 120 requests across all four harness classes, 50 token-span checksums, 50 lookup paths, root summary PASS, redacted evidence clean, no product error patterns, and cold bytes under the 512 MiB budget. Developer final test-results review [stage23-final-test-results-review-20260623-01.md](.test_reports/stage23-final-test-results-review-20260623-01.md) PASS: S01..S08 and L01..L03 have accepted PASS evidence; no product failures, runner blocks, or evidence gaps remain. Manager closure [stage23-manager-closure-20260623-01.md](.test_reports/stage23-manager-closure-20260623-01.md) PASS.

## Manager gate
QA execution must not start until Manager accepts this execution plan.

Manager review checklist:

- D23-DESIGN-01 remains accepted.
- D23-DESIGN-02 is satisfied by this plan before any multi-hour execution.
- D23-DESIGN-03 is honored: deterministic S/L prompts are the default.
- Product code, public surfaces, public metric names, and tests remain
  unchanged before execution. Harness changes are limited to the correction
  record above.
- Wrapper dry-run, prerequisites, clean build, batching, evidence layout, row
  verdicts, resume rules, retry rules, and stop conditions are acceptable.

## Inputs

Read before execution: Stage 23 design and review, Stage 20 implementation,
Stage 17 test plan part 27, `kickoff-stage20-stress-longrun.ps1`, and the file
lists under `cache-handling-test-scripts/stress/` and `longrun/`.

## Rows and order

Run order is fixed unless Manager changes it in writing:

| Batch | Rows | Cap | Notes |
| --- | --- | ---: | --- |
| 1 | S01 | 30m | stress start |
| 2 | S02 | 30m | concurrent multi-slot row |
| 3 | S03 | 30m | branch forest |
| 4 | S04 | 30m | prompt storms |
| 5 | S05 | 30m | mixed workload |
| 6 | S06 | 30m | cold queue pressure |
| 7 | S07 | 30m | protected root |
| 8 | S08 | 30m | integrity failure |
| 9 | L01 | 2h | hybrid stability |
| 10 | L02 | 30m | legacy comparison |
| 11 | L03 | 2h | mixed workload longrun |

Use `-BatchSize 1` for Stage 23 unless Manager approves a later parallel run.
The row scripts own their server cleanup, so serial execution gives cleaner row
evidence. Stress rows use the Stage 15 1000 hits+misses threshold. Longrun rows
use stated row intent when total hits+misses stays below 1000.

## Evidence paths

Use a single run id for the whole session:

```powershell
$RunId = "stage23-sl-matrix-YYYYMMDD-NN"
```

Durable report: `._design_docs/.test_reports/stage23-sl-matrix-YYYYMMDD-NN.md`

Non-durable output: `._test_output/stage23-sl-matrix-YYYYMMDD-NN/preflight/`
and `._test_output/stage23-sl-matrix-YYYYMMDD-NN/<ROW>-Jnew/`.

Pass `-RunRoot "$Out"` to the wrapper. Do not let row artifacts land under
`._design_docs/.test_reports/`; that directory is for the durable Markdown
report only.

Per row, capture `launch.log`, `launch.err`, `server.out.log`,
`server.err.log`, metrics before/after, redacted JSONL tail, cold bytes
before/after, row summary JSON, and `cap-exit.json` when the row exits by cap.

## Preflight commands

Run these only after Manager accepts this plan.

Create preflight folders:

```powershell
$RunId = "stage23-sl-matrix-YYYYMMDD-NN"
$Root = "D:\source\llama.cpp-jet"
$Out = Join-Path $Root "._test_output\$RunId"
$Preflight = Join-Path $Out "preflight"
New-Item -ItemType Directory -Force -Path $Preflight | Out-Null
```

Verify branch and dirty state:

```powershell
git branch --show-current | Tee-Object -FilePath "$Preflight\01-branch.txt"
git status --short | Tee-Object -FilePath "$Preflight\02-git-status.txt"
```

Verify scripts and fixture:

```powershell
Get-ChildItem ._design_docs\cache-handling-test-scripts\stress\*.ps1 | Select-Object Name,Length,LastWriteTime | Tee-Object -FilePath "$Preflight\03-stress-scripts.txt"
Get-ChildItem ._design_docs\cache-handling-test-scripts\longrun\*.ps1 | Select-Object Name,Length,LastWriteTime | Tee-Object -FilePath "$Preflight\04-longrun-scripts.txt"
Get-ChildItem ._test_models\Qwen3.5-4B-MTP-GGUF | Select-Object Name,Length,LastWriteTime | Tee-Object -FilePath "$Preflight\05-fixture.txt"
```

Verify ports 8800..8821:

```powershell
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -ge 8800 -and $_.LocalPort -le 8821 } | Select-Object LocalAddress,LocalPort,OwningProcess | Tee-Object -FilePath "$Preflight\06-port-listeners.txt"
```

If any listener exists, stop and recheck only if it belongs to a stale local
test process. Otherwise ask Manager for a replacement range.

Verify disk and cold path:

```powershell
$Cold = "D:\tmp\cache-cold-stage23"
New-Item -ItemType Directory -Force -Path $Cold | Out-Null
Get-PSDrive D | Select-Object Name,Free,Used | Tee-Object -FilePath "$Preflight\07-disk.txt"
Get-ChildItem -LiteralPath $Cold -Force | Tee-Object -FilePath "$Preflight\08-cold-path-before.txt"
```

Required free space: at least 30 GiB on the output volume and at least 10 GiB
on the cold-path volume before each batch. Cold path must be empty before a row
unless the row is resuming a preserved attempt.

## Clean build commands

Stale builds are not valid evidence. Run a clean build before matrix execution:

```powershell
cmake --build build-cov --config Release --target clean *> "$Preflight\09-clean.log"
cmake --build build-cov --config Release --target test-cache-controller -j 4 *> "$Preflight\10-build-test-cache-controller.log"
cmake --build build-cov --config Release --target llama-server -j 4 *> "$Preflight\11-build-llama-server.log"
.\build-cov\bin\Release\test-cache-controller.exe *> "$Preflight\12-test-cache-controller.log"
Get-Item build-cov\bin\Release\llama-server.exe,build-cov\bin\Release\llama-server-impl.dll,build-cov\bin\Release\test-cache-controller.exe | Select-Object FullName,Length,LastWriteTime | Tee-Object -FilePath "$Preflight\13-binary-freshness.txt"
```

Build acceptance: all commands exit 0, `llama-server.exe` and
`llama-server-impl.dll` mtimes are recorded, and the implementation DLL mtime
counts as freshness evidence on Windows launcher builds.

## Wrapper readiness check

Run dry-run before any live row:

```powershell
powershell -NoProfile -Command "& ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 `
  -RowsToRun @('S01','S02','S03','S04','S05','S06','S07','S08','L01','L02','L03') `
  -RunRoot '$Out' `
  -ModelPath 'D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf' `
  -CacheColdPath "D:\tmp\cache-cold-stage23" `
  -CachePromptEvidenceDir "D:\source\llama.cpp-jet\._test_output\$RunId\prompt-evidence" `
  -CacheColdMaxMib 512 `
  -CacheRamMib 512 `
  -CachePromptEvidence redacted `
  -JinjaVariant new `
  -BasePort 8800 `
  -BatchSize 1 `
  -DryRun" *> "$Preflight\14-wrapper-dry-run.log"
```

Dry-run acceptance: exit code 0, all 11 rows listed, every row includes
`--cache-mode hybrid`, `--cache-cold-max-mib 512`,
`--cache-prompt-evidence redacted`, `--cache-prompt-evidence-dir`,
`--n-gpu-layers all`, and `--fit off`; port allocation stays in 8800..8821.
The side log must show the Qwen3.5 model path and row output under
`._test_output`.

## Batch and row gates

The corrected wrapper writes these side-log records:

- `batch_gate`: selected ports, listeners on those ports, free bytes on the
  output drive, cold-path item count, and run-root writability.
- `launched`: row id, port, PID, script, cap, and live Stage 17 flag string.
- `row_gate`: child exit code, recursive evidence file count, required evidence
  file presence, and row output directory.

Before the durable report accepts a row, copy these side-log lines into the row
table or cite the side-log path and line numbers. Treat missing `row_gate` or a
non-zero child exit as `BLOCKED-runner-contract` unless the row evidence proves
a product failure.

## Live execution commands

Run stress first:

```powershell
powershell -NoProfile -Command "& ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 `
  -RowsToRun @('S01','S02','S03','S04','S05','S06','S07','S08') `
  -RunRoot '$Out' `
  -ModelPath 'D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf' `
  -CacheColdPath "D:\tmp\cache-cold-stage23" `
  -CachePromptEvidenceDir "D:\source\llama.cpp-jet\._test_output\$RunId\prompt-evidence" `
  -CacheColdMaxMib 512 `
  -CacheRamMib 512 `
  -CachePromptEvidence redacted `
  -JinjaVariant new `
  -BasePort 8800 `
  -BatchSize 1"
```

Run longrun after stress verdicts are recorded:

```powershell
powershell -NoProfile -Command "& ._design_docs\cache-handling-test-scripts\kickoff-stage20-stress-longrun.ps1 `
  -RowsToRun @('L01','L02','L03') `
  -RunRoot '$Out' `
  -ModelPath 'D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf' `
  -CacheColdPath "D:\tmp\cache-cold-stage23" `
  -CachePromptEvidenceDir "D:\source\llama.cpp-jet\._test_output\$RunId\prompt-evidence" `
  -CacheColdMaxMib 512 `
  -CacheRamMib 512 `
  -CachePromptEvidence redacted `
  -JinjaVariant new `
  -BasePort 8808 `
  -BatchSize 1"
```

If Manager wants single-row retry, use the same command shape with
`-RowsToRun @('<ROW>')` and a new row attempt suffix in the report.

## Row verdicts

PASS requires complete row evidence, no crash, no corrupt restore, bounded
diagnostics, redacted prompt evidence without raw prompt text, cold budget at or
below limit when bounded, and the row behavior from the Stage 23 design table.

FAIL applies to product symptoms: crash after request phase begins, corrupt or
unsafe prefix restore, repeated HTTP 500 after setup is valid, raw prompt leak
in redacted mode, cold write failure without bounded handling, or exact-repeat
regression with matching identity evidence.

BLOCKED applies to setup or session evidence gaps: missing fixture, stale
binary, port collision after one setup retry, disk shortage, cap exit before
required evidence, unavailable metric with no substitute, runner contract
failure, or missing row evidence.

Stress row below 1000 hits+misses is `BLOCKED-stress-low-throughput` unless
Manager approved a different row threshold before the run.

## Resume and retry rules

- Do not rerun a row with complete evidence unless Manager requests a focused
  harness confirmation.
- If interrupted before server startup or before first request, retry once with
  a clean cold path and a new row attempt suffix.
- If a row reaches cap with complete cap-exit evidence, classify it and do not
  extend the cap in the same attempt.
- If setup fails because of port collision, stale process, missing fixture, or
  missing evidence directory, fix setup and rerun once.
- If the same product symptom appears twice, stop the matrix and open the
  bug-fix loop.
- Preserve all failed-attempt evidence. Do not overwrite row directories.

## Stop conditions

Stop the session and write the durable report if clean build or wrapper dry-run
fails, the fixture is absent, disk headroom is too low, two rows in a batch
share the same product symptom, any redacted row leaks prompt text, cleanup
fails, or Manager asks for pause or plan change.

## Report format

The durable report must include preflight exit codes, clean build and binary freshness,
wrapper dry-run result and side-log path, row tables, any FAIL bug list, BLOCKED
rationale, and final Stage 23 verdict or bug-handoff state.
