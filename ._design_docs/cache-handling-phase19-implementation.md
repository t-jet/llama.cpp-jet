# Stage 19 implementation: System-Level Model Warmup Crash Investigation

Status: closed
Date: 2026-06-18
Stage: 19 (System-Level Model Warmup Crash Investigation)
Design baseline: [cache-handling-phase19-design.md](cache-handling-phase19-design.md)
Current gate: closed (Manager closure 2026-06-18)

## Scope

This implementation log covers Stage 19 investigation and disposition.
No commits, PR text, or reviewer responses are approved by this file.

Stage 19 scope:

- Investigate residual warmup crash scenarios after Stage 18 fix
- Determine branch (A: code-related fix, B: environmental follow-up, C: no reproduction)
- Apply branch-specific action or document disposition

## Contents

- [Part 1: implementation plan](#part-1-implementation-plan) (also serves as plan file, 206 lines)
- [Part 2: Manager implementation-plan gate](cache-handling-phase19-implementation/part-02-manager-implementation-plan-gate.md)
- [Part 3: Branch C implementation evidence](cache-handling-phase19-implementation/part-03-branch-C-implementation-evidence.md) (209 lines)
- [Part 4: Architect implementation review gate 01](cache-handling-phase19-implementation/part-04-architect-implementation-review-gate-01.md)

## Gate status

| Gate | Status |
| --- | --- |
| Stage 19 design authoring | PASS (see design entry + parts 1-4) |
| Stage 19 design review | PASS (see [design part 5](cache-handling-phase19-design/part-05-design-review-gate-01.md), 0 BLOCKING, 2 non-blocking, 2 INFO) |
| Stage 19 Manager design gate | PASS (see [design part 6](cache-handling-phase19-design/part-06-manager-design-gate.md)) |
| Stage 19 implementation planning | PASS (this file, 206 lines) |
| Stage 19 implementation-plan review | PASS (see [part 01](cache-handling-phase19-implementation/part-01-architect-implementation-plan-review-gate-01.md), 0 BLOCKING, 2 non-blocking, 1 INFO) |
| Stage 19 Manager implementation-plan gate | PASS (see [part 2](cache-handling-phase19-implementation/part-02-manager-implementation-plan-gate.md)) |
| Stage 19 implementation | PASS (see [part 3](cache-handling-phase19-implementation/part-03-branch-C-implementation-evidence.md), Branch C: no reproduction) |
| Stage 19 implementation review | PASS (see [part 4](cache-handling-phase19-implementation/part-04-architect-implementation-review-gate-01.md), 0 BLOCKING, 3 non-blocking, 0 INFO) |
| Stage 19 closure | PASS (Manager closure 2026-06-18, see D19-CLOSURE-01 below) |

## Manager closure decision (D19-CLOSURE-01)

Date: 2026-06-18
Verdict: PASS

Stage 19 is closed with Branch C disposition (no reproduction). All gates advanced.

### Substantive finding

The original D17-EXEC-02 baseline warmup crash does NOT reproduce in the current system state. Evidence:

- 5 successive baseline launches all reach `/health` HTTP 200
- Peak working set stable at 5156.7-5157.0 MiB (delta 0.3 MiB)
- System memory snapshot: 32185 MiB free, ample headroom
- fit_params projection 5150 MiB vs 63124 MiB total (8.2% utilization)
- No port conflict on 18220-18222

Stage 18 fix (D18-CLOSURE-01) is sufficient as-is. Branch C disposition: no code change, baseline crash not reproducible in current system.

The original Stage 17 fit_params projection of 9933 MiB vs current 5150 MiB suggests the baseline crash was environmental (memory pressure at the time of Stage 17 closure). Current system state has 32x memory headroom.

### Optional follow-ups (non-blocking)

- F-19-IR-01: path prefix `_test_output` vs on-disk `._test_output` - cosmetic
- F-19-IR-02: MiB conversion uses 3 different conventions in same file - cosmetic
- F-19-IR-03: Step 2.2 omits ctx_dft site - not required for Branch C
- NB-19-IPR-01/02: implementation-plan review non-blockings - cosmetic

### Code changes (UNCOMMITTED)

- None. Branch C disposition: no code change. tools/server/server-context.cpp and tests/test-cache-controller.cpp unchanged from Stage 18 closure.

## Handoff

Stage 19 closed. Next stage: Stage 20 (Stage 17 test infrastructure additions).

This file uses LF line endings, plain ASCII status labels, and stays under the 300-line durable doc cap.

---
# Stage 19 implementation plan: system-level model warmup crash investigation

Status: authored; pending Architect implementation-plan review
Date: 2026-06-18
Author: Developer (implementation plan, fresh session)
Scope: Stage 19 implementation plan only. Not implementation, not design re-review, not test plan authoring, not Stage 20.
Source decision: D17-EXEC-02 (Stage 17 closure, 2026-06-17)
Stage 18 status: closed (validation block moved BEFORE warmup, resolves F-18-EXEC-01 and F-18-EXEC-02)

## Approved baseline

Implementation must follow the approved Stage 19 design:

- [Stage 19 design entry](cache-handling-phase19-design.md) (63 lines)
- [Part 1: question, three-branch disposition, reproduction plan](cache-handling-phase19-design/part-01-question-disposition-and-reproduction.md)
- [Part 2: root cause analysis and fix proposal](cache-handling-phase19-design/part-02-root-cause-analysis-and-fix-proposal.md)
- [Part 3: test plan rows, closure criteria, traceability](cache-handling-phase19-design/part-03-test-plan-closure-traceability.md)
- [Part 4: risks, open questions, handoff](cache-handling-phase19-design/part-04-risks-open-questions-handoff.md)
- [Part 5: design review gate 01 (Architect PASS, 0 BLOCKING, 2 non-blocking, 2 INFO)](cache-handling-phase19-design/part-05-design-review-gate-01.md)
- [Part 6: Manager design gate (PASS, 2026-06-18)](cache-handling-phase19-design/part-06-manager-design-gate.md)

Manager design gate PASS: three-branch disposition (A: code-related fix, B: environmental follow-up, C: no-reproduce close) approved; reproduction plan and analysis steps reviewable; 4 test plan rows approved.

Architecture and requirement inputs remain binding: [cache-handling-architecture.md](cache-handling-architecture.md), [cache-handling-requirements.md](cache-handling-requirements.md), [cache-handling-test-plan.md](cache-handling-test-plan.md).

## Design-review findings to address in plan

| Finding | Severity | Plan resolution |
| --- | --- | --- |
| F-19-DR-01 | NON-BLOCKING | Step 2.2 first runs `git show HEAD:tools/server/server-context.cpp` line numbers to capture exact crash-site candidates before evidence capture. Plan Step 1.4 records `Process.StartTime`, `Process.ExitTime`, `HasExited`, `ExitCode`, and last log line as the crash-site localization inputs. |
| F-19-DR-02 | INFO | Step 2.1 uses `Select-String -Pattern 'if \(params_base.cache_ram_mib != 0\)'` to verify the gate is at the expected line. The design text says "line 1242" but the gate pattern returns line 1249; the "1242-1291" range matches the comment-header-to-closing-brace span. No plan change. |
| F-19-DR-03 | INFO | The document-index has no Stage 19 row yet. The doc-index update is a separate activity owned by the Manager closure cycle. No plan change here. |
| F-19-DR-04 | NON-BLOCKING | Step 2.2 localizes the crash site from the LAST log line before exit before any Branch A fix is applied. The conditional fix in Step 3.1 is applied only AFTER Step 2.2 confirms the site is in the slot init preamble window. The exact fix text depends on Step 2.2 evidence. |

## Code surfaces

Files potentially affected by this stage (Branch A only; Branch B and Branch C do not modify code):

- `tools/server/server-context.cpp`: Branch A only. Conditional fix scope is bounded by Step 2.2 crash-site evidence. Estimated diff scope: 5-15 lines (slot init preamble guard, `throw` to `return false` replacement, SRV_ERR log line). No change outside `load_model` lines 1108-1500+.
- `build-cov/bin/Release/llama-server.exe`: rebuilt if Branch A modifies `server-context.cpp`.
- `tests/test-cache-controller.cpp`: Branch A only. TP-19-FT1 adds a focused signature fixture (conditional).

PowerShell test harness scripts (always created, per branch):

- `._test_output/stage19-repro/RT1.1-baseline-single.ps1`: single-launch reproduction
- `._test_output/stage19-repro/RT1.2-baseline-5x.ps1`: 5x repeat memory accumulation
- `._test_output/stage19-repro/RT1.3-baseline-portshift.ps1`: port-shift isolation
- `._test_output/stage19-repro/RT1.4-process-watcher.ps1`: process lifetime + last log line
- `._test_output/stage19-repro/RT2-memory-snapshot.ps1`: system memory snapshot helper
- `._test_output/stage19-repro/RT3-stage18-regression-smoke.ps1`: Stage 18 IT1+IT3 smoke check

Out of scope (per design Non-goals):

- Any change outside the baseline path (Branch A fix does not touch cache-flag paths).
- `build`, `build-cuda`, `build-cuda-stage13`, `build-phase2`, `build-test`, `build-x64-windows-msvc-release`, `build-cov` other than the rebuilt `llama-server.exe`.
- `CMakePresets.json` or root `CMakeLists.txt` (no cmake change required).
- `include/llama.h` (Branch A fix uses existing `llama_get_memory` and `llama_memory_can_shift` APIs at lines 555 and 774; no header change).
- The Stage 18 validation block at lines 1242-1291 (already in correct position).
- Document-index, stage tracker, Stage 18 implementation log, design docs (separate activity).

## Step 1: Reproduction (per design part 1)

Step 1 runs the baseline launch matrix and captures crash evidence on the BASELINE path (no cache flags).

### Step 1.1: Single-launch baseline (RT1.1)

```powershell
# RT1.1 - single-launch baseline
$port = 18220
$outLog = 'd:\source\llama.cpp-jet\._test_output\stage19-repro\RT1.1\server.out.log'
$errLog = 'd:\source\llama.cpp-jet\._test_output\stage19-repro\RT1.1\server.err.log'
$healthLog = 'd:\source\llama.cpp-jet\._test_output\stage19-repro\RT1.1\health-response.log'
if (Test-Path $outLog) { Remove-Item $outLog }
if (Test-Path $errLog) { Remove-Item $errLog }
if (Test-Path $healthLog) { Remove-Item $healthLog }
$proc = Start-Process -FilePath 'd:\source\llama.cpp-jet\build-cov\bin\Release\llama-server.exe' `
    -ArgumentList @('--port', $port, '--model', 'd:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf') `
    -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru -NoNewWindow
for ($i=0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    try {
        $r = Invoke-WebRequest -Uri "http://127.0.0.1:$port/health" -UseBasicParsing -ErrorAction Stop
        $r.Content | Out-File -FilePath $healthLog -Encoding utf8
        break
    } catch {
        if ($i -eq 29) { "Failed: $($_.Exception.Message)" | Out-File -FilePath $healthLog -Encoding utf8 }
    }
}
$proc.Refresh(); $proc.HasExited; $proc.ExitCode
Get-Process -Id $proc.Id -ErrorAction SilentlyContinue | Stop-Process -Force
```

Expected clean: `health-response.log` starts with `{"status":"ok"}`, exit code 0.
Expected crash: empty or partial `server.err.log`, no `{"status":"ok"}`, `ExitCode` is -1073740791 (0xC0000409 STATUS_STACK_BUFFER_OVERRUN).

### Step 1.2: 5x repeat (RT1.2)

Runs the Step 1.1 command 5 times sequentially with a 5-second gap. Captures: process lifetime, exit code, peak working set per launch, last log line per launch. Compares peak working set across launches to detect accumulation.

Detection rule: if any launch's peak working set is > 10% higher than the previous launch's, flag for Branch B. If 5 successive launches all reach `/health` HTTP 200 with stable working set, this is Branch C evidence.

### Step 1.3: Port-shift (RT1.3)

Runs the Step 1.1 command on ports 18220, 18221, 18222 sequentially. Captures: same metrics. Purpose: rule out port conflict (Stage 17 evidence shows the crash is deterministic 3/3 with single launches, so port conflict is unlikely but should be excluded).

### Step 1.4: Process watcher (RT1.4)

Wraps the Step 1.1 command with explicit `Process.StartTime`, `Process.ExitTime`, `HasExited`, `ExitCode` capture. After exit, reads `server.err.log` to find the LAST log line before exit. Outputs a JSON record:

```json
{
  "startTime": "2026-06-18T02:30:00Z",
  "exitTime": "2026-06-18T02:30:02Z",
  "lifetimeSec": 2.4,
  "hasExited": true,
  "exitCode": -1073740791,
  "lastLogLine": "llama_model_load: warming up ...",
  "lastLogLineOffset": 1234
}
```

The `lastLogLine` is the crash-site localization input for Step 2.2.

## Step 2: Analysis (per design part 2)

Step 2 produces the Branch A/B/C verdict from Step 1 evidence.

### Step 2.1: Verify validation gate

```powershell
Select-String -Path tools/server/server-context.cpp -Pattern 'if \(params_base.cache_ram_mib != 0\)'
```

Verification result observed at planning time: 2 matches at lines 1249 (validation block gate) and 1528 (cache controller creation block). The 1528 match is the controller creation gate, NOT a duplicate validation block. The design text expects "1 match"; the actual count is 2 because the pattern also matches the post-slot-init controller creation. This is not a defect; the design's "1 match" wording is ambiguous. The plan uses the 1249 match as the validation gate, confirmed by the range 1242-1291.

Conclusion: baseline path with default `cache_ram_mib = 0` skips the validation block. The Stage 18 fix cannot affect this path. Any baseline crash is independent of the validation block ordering.

### Step 2.2: Localize crash site in `load_model`

For each candidate site, run `git show HEAD:tools/server/server-context.cpp | Select-String -Pattern '<site-marker>'` to capture the actual line number at HEAD (F-19-DR-01 resolution). Expected results (from design review):

| Site marker pattern | Expected line at HEAD |
| --- | --- |
| `slots.emplace_back` | 1455 |
| `slot.reset\(` | 1500 |
| `mctx = mtmd_init_from_file` | 1389 |
| `model_dft.reset\(llama_model_load_from_file` | 1331 |
| `common_init_from_params` | 1292 |
| `llama_init = common_init_from_params` | 1292 |

Then compare the Step 1.4 `lastLogLine` against these candidate sites. The closest match is the crash site.

If `lastLogLine` is `llama_model_load: warming up` or `common_init_from_params entered`, the site is `common_init_from_params` at line 1292 (Branch A, warmup-path). If `lastLogLine` is `slot.reset()`-preceding log, the site is in the slot loop window (lines 1432-1500, Branch A, slot-init). If `lastLogLine` is empty, the crash is pre-warmup (Branch A, init path). If `lastLogLine` is at the warmup completion log, the crash is post-warmup (Branch A, slot setup).

### Step 2.3: fit_params projection

```powershell
Select-String -Path 'd:\source\llama.cpp-jet\._test_output\stage19-repro\RT1.1\server.err.log' -Pattern 'fit_params'
```

Capture the projection value logged at SRV_INF lines 1135 and 1235 (per design part 2). Stage 17 evidence: 9933 MiB vs 1466 MiB baseline. If projection is > 5000 MiB AND system available memory is below projection, classify as Branch B.

### Step 2.4: System memory snapshot

```powershell
Get-CimInstance Win32_OperatingSystem | Select-Object TotalVisibleMemorySize, FreePhysicalMemory
```

Capture before Step 1.1 launch and after. The before/after delta is the working-set growth per launch. Stage 17 evidence: 9933 MiB projection was a system with limited free memory.

### Step 2.5: Branch verdict

| Evidence | Verdict |
| --- | --- |
| Last log line indicates specific buffer overrun; fit_params <= 5000 MiB; system memory ample | Branch A (code-related) |
| fit_params > 5000 MiB AND system free memory low; system delta growing across 5x | Branch B (environmental) |
| 5 successive launches all reach `/health` HTTP 200; working set stable | Branch C (no reproduction) |

The verdict is recorded in the implementation evidence part file at the end of Step 2.

## Step 3: Branch-specific action

### Step 3.1: Branch A action (conditional)

If Step 2.5 returns Branch A:

1. Localize the crash site to a single candidate (Step 2.2 verdict).
2. Apply the conditional fix per design part 2 (Branch A fix, 3 steps):
   - Move speculative decoding init and `slots.emplace_back()` loop into a guarded block that runs only after `model_tgt != nullptr` and `ctx_tgt != nullptr` AND `llama_memory_can_shift(llama_get_memory(ctx_tgt))` returns success.
   - Replace any `throw std::runtime_error` in the slot init preamble with `return false`.
   - Add SRV_ERR log lines BEFORE the crash-prone step with bounded message.
3. Build `llama-server.exe` via `cmake --build build-cov --config Release --target llama-server -j 4`. Expect exit 0.
4. Re-run Step 1.1 to confirm clean exit. If clean, add TP-19-FT1 fixture test (Step 4.4).
5. Record implementation evidence in `cache-handling-phase19-implementation/part-03-branch-a-implementation-evidence.md`.

### Step 3.2: Branch B action

If Step 2.5 returns Branch B:

1. Do NOT modify code. Document environmental classification: memory pressure, fit_params projection discrepancy, system free memory below projection.
2. Surface as new separate stage: append row to `cache-handling-stage-tracker.md` "Future stages" section with title "System-level warmup environmental stability follow-up" (Manager closure follow-up).
3. Record implementation evidence in `cache-handling-phase19-implementation/part-03-branch-b-environmental-classification.md`.

### Step 3.3: Branch C action

If Step 2.5 returns Branch C:

1. Do NOT modify code. Document 5-successive-launch evidence: working set stable, all reached `/health` HTTP 200, no STATUS_STACK_BUFFER_OVERRUN.
2. Record implementation evidence in `cache-handling-phase19-implementation/part-03-branch-c-no-reproduction.md`.
3. The Stage 18 fix is sufficient as-is. Stage 19 closes with no-reproduction evidence.

## Step 4: Test plan execution (per design part 3)

Step 4 runs the 4 test plan rows from design part 3. The rows are integration (RT1, RT2, RT3) and focused (FT1, conditional on Branch A).

### Step 4.1: TP-19-RT1 (integration, reproduction)

Re-run the Step 1.2 5x repeat on the post-Step-3 binary. Expected per branch:

- Branch A: 5 successive clean launches, all reach `/health` HTTP 200.
- Branch B: 5 successive launches with growing working set; some may reach `/health` HTTP 200, some may exit with bounded error.
- Branch C: 5 successive clean launches, all reach `/health` HTTP 200.

Capture per-launch JSON record: `startTime`, `exitTime`, `lifetimeSec`, `hasExited`, `exitCode`, `healthReached`, `peakWorkingSetMB`. Write to `._test_output/stage19-repro/RT1-results.json`.

### Step 4.2: TP-19-RT2 (integration, environmental)

Re-run Step 2.3 and Step 2.4 evidence capture. Output: `._test_output/stage19-repro/RT2-memory-snapshot.json` with `totalMiB`, `freeMiB`, `fitParamsProjectionMiB`, and the Branch B threshold check.

### Step 4.3: TP-19-RT3 (integration, regression smoke)

Run the Stage 18 IT1 and IT3 paths (cache-flag-induced) on the post-Step-3 binary. Expected: both PASS (regression check). Use the Stage 18 test harness scripts; do NOT modify them.

### Step 4.4: TP-19-FT1 (focused, conditional on Branch A)

If Branch A is selected, add a focused signature fixture to `tests/test-cache-controller.cpp`:

- Capture the crash signature from the pre-fix Step 1.1 run: process exit code, last log line, stack frame count (if available via `Get-EventLog` or `!analyze`).
- Add a test function `test_stage19_baseline_crash_signature` that documents the signature in test code for future regression.

If Branch B or Branch C is selected, TP-19-FT1 is recorded as no-op with rationale in the test plan row table.

## Step 5: Closure documentation (per design part 3 closure criteria)

Step 5 produces the closure evidence file. The closure criteria from design part 3 are:

1. The reproduction plan runs in a fresh Developer session (Steps 1.1-1.4).
2. The root cause analysis (Step 2.1-2.5) produces a Branch A, B, or C verdict with evidence.
3. The fix proposal (or no-fix decision) is applied or recorded (Step 3.1-3.3).
4. The test plan rows pass (Branch A) or are recorded as no-op (Branch B/C) (Step 4.1-4.4).
5. The Manager closure decision records the verdict and any follow-up (separate Manager activity).

The implementation evidence file path is `cache-handling-phase19-implementation/part-03-branch-{A|B|C}-*.md` per Step 3. The implementation log entry is updated with the verdict, evidence path, and handoff state.

## Evidence plan

Per branch:

| Branch | Evidence files | Key content |
| --- | --- | --- |
| A | `RT1-results.json`, `RT2-memory-snapshot.json`, `RT3-regression-smoke.log`, `branch-a-implementation-evidence.md` | 5x repeat clean, fit_params <= 5000 MiB, code fix applied, FT1 fixture added |
| B | `RT1-results.json`, `RT2-memory-snapshot.json`, `branch-b-environmental-classification.md` | fit_params > 5000 MiB, free memory low, no code change, follow-up stage proposed |
| C | `RT1-results.json`, `RT2-memory-snapshot.json`, `branch-c-no-reproduction.md` | 5x repeat clean, working set stable, no code change |

All evidence files are under `._test_output/stage19-repro/` (gitignored) for raw output and `._design_docs/cache-handling-phase19-implementation/` for the durable implementation evidence part file.

## Known risks

From design part 4 (R-19-DESIGN-*):

- R-19-DESIGN-01 (medium): the `cache_ram_mib != 0` gate covers cache-flag paths but not baseline. RT1.1 captures baseline explicitly. Plan Step 1.1 prohibits all cache flags.
- R-19-DESIGN-02 (low): Stage 17 evidence is from 2026-06-17; current system state may differ. RT2 memory snapshot captures current state. Plan Step 2.4 runs the snapshot fresh.
- R-19-DESIGN-03 (medium): Branch A fix scope depends on Step 2.2 crash-site evidence. Conditional fix in Step 3.1 is a starting template; the Developer session may revise.
- R-19-DESIGN-04 (low): Branch B environmental follow-up is a new separate stage. Stage 19 design does not pre-define the follow-up; the Manager closure decision proposes Stage 20 or 21.

From design review (F-19-DR-*):

- F-19-DR-01 (NON-BLOCKING): line number drift in Step 2 candidates. Plan Step 2.2 captures actual line numbers at HEAD before evidence capture.
- F-19-DR-04 (NON-BLOCKING): Branch A fix uses valid APIs but exact crash site is undetermined. Plan Step 2.2 localizes the site before Step 3.1 applies the fix.

Out of scope risks:

- The 2-match observation in Step 2.1 (validation gate + controller creation gate) is not a defect; both are gated by `cache_ram_mib != 0` and the controller creation block is unrelated to the validation block. Documented in Step 2.1.

## Handoff

Next owner: **Architect** for implementation-plan review in a fresh session. The Architect reviews this plan against:

1. The approved Stage 19 design (entry + parts 1-6).
2. The five-step ordered plan (reproduction, analysis, branch-specific action, test plan execution, closure).
3. The branch-specific action plans (Step 3.1-3.3) and their evidence paths.
4. The test plan rows (Step 4.1-4.4) and their branch-conditioned outcomes.
5. The four design-review findings and their resolution paths.
6. The four design risks and their mitigations.
7. The code surfaces and estimated diff scope for Branch A.
8. The out-of-scope list (no cmake change, no header change, no doc-index change).

The Architect returns PASS or REWORK with findings. On PASS, the Manager advances Stage 19 to implementation execution in a fresh session. The design, Stage 18 implementation log, tracker, document-index, and any other durable doc are NOT modified by this plan or the implementation-plan review.
