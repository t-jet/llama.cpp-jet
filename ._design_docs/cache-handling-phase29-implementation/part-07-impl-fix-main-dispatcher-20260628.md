# Stage 29 implementation fix: Main dispatcher + INFO drift corrections

Status: fix complete (Developer fix session, 2026-06-28)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Owner: Developer (fix session in response to QA test-plan BLOCKING finding F-01)
Source finding: [../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md](../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md)
Prior implementation review: [./part-06-impl-review-20260628.md](./part-06-impl-review-20260628.md) (PASS with 0 BLOCKING, 5 INFO; missed F-01 because it inspected helper function presence but not Main dispatcher call graph)
Branch: work-branch

## Background

The QA test-plan authoring session for Stage 29 surfaced a BLOCKING
implementation defect in the driver `Main` dispatcher that the prior
Architect implementation review (part-06) did not catch. The review
verified that `Invoke-CycleLeg`, `Invoke-Phase1OutputEquivalence`,
`Invoke-Phase05WorkloadBuild`, and `Write-Stage29Report` were all
defined as functions in the driver, but did not verify that `Main`
calls them in the full execution path. Without `-DryRun` or
`-OutputEquivalenceOnly`, the full path previously executed only
Phase 0 preflight, Phase 0.5 workload build, and `Write-Stage29Report`;
the latter wrote a per-leg table from an empty `summary.json`.

Every QA test row that depends on Phase 1 / Phase 2 / Phase 3 evidence
(TP-29-CC-01..04, TP-29-PR-01..03, TP-29-AG-01..04) was BLOCKED-driver-contract
at execution until this fix landed.

Three additional INFO drifts (F-02, F-03, F-04) from the same test-plan
review were addressed in this session where straightforward.

## Findings addressed

| ID | Severity | Source | Status |
| --- | --- | --- | --- |
| F-01 | BLOCKING | QA test-plan L189-203 | DONE |
| F-02 | INFO | QA test-plan L205-211 | DONE (impl log + helper docstring aligned to 120s cap per design D29-DESIGN-06) |
| F-03 | INFO | QA test-plan L213-217 (impl review N-03) | SKIPPED (deferred to QA execution gate per impl review N-03; the 5 gating sub-checks cover safety-critical checks and the 2 informational fields record the missing disk/mtime state for QA follow-up) |
| F-04 | INFO | QA test-plan L219-222 (impl review N-02) | DONE (impl log S29-IMPL-02 row updated from "17-param set" to "18-param set" matching actual driver param block) |

## S29-IMPL-FIX-01: Main dispatcher fix (F-01)

### Code change

File: `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`

The `Main` function tail block (lines 222-225 of the prior 228-LF file)
was extended to:

1. Call `Invoke-Phase1OutputEquivalence` after `Invoke-Phase05WorkloadBuild`.
   On exception (server boot fails), classify `BLOCKED-server-not-running`
   and exit 4. On return, classify `BLOCKED-output-equivalence` and exit 5
   if `$eq.Status -ne 'PASS'`. On `PASS`, continue.
2. Call `Invoke-CycleLeg` for the Phase 2 cold-start cycle (cycle=1,
   phase='cold-start', mode='legacy' then mode='hybrid').
3. Loop `Invoke-CycleLeg` for the Phase 3 warm cycles (cycle=1..$Cycles,
   phase='warm', mode='legacy' then mode='hybrid').
4. Call `Write-Stage29Report` to emit the now-populated per-leg table.

`Invoke-CycleLeg` uses script-scope `$BasePort` and `$RunRoot`
(function signature is `param([int]$Cycle, [string]$Mode, [string]$WorkloadPath, [string]$Phase)`).
No `-BasePort` or `-RunRoot` parameters were fabricated.

### Diff shape (concise)

```text
+    try {
+        $eq = Invoke-Phase1OutputEquivalence
+    } catch {
+        $msg = $_.Exception.Message
+        Write-Error ("BLOCKED-server-not-running: " + $msg)
+        exit 4
+    }
+    Write-Output ("OutputEquivalence status=" + $eq.Status + " mismatch=" + $eq.MismatchCount)
+    if ($eq.Status -ne 'PASS') { Write-Error ("BLOCKED-output-equivalence: " + ($eq | ConvertTo-Json -Compress)); exit 5 }
+    Invoke-CycleLeg -Cycle 1 -Mode 'legacy' -WorkloadPath $wl.workload -Phase 'cold-start'
+    Invoke-CycleLeg -Cycle 1 -Mode 'hybrid' -WorkloadPath $wl.workload -Phase 'cold-start'
+    for ($c = 1; $c -le $Cycles; $c++) {
+        Invoke-CycleLeg -Cycle $c -Mode 'legacy' -WorkloadPath $wl.workload -Phase 'warm'
+        Invoke-CycleLeg -Cycle $c -Mode 'hybrid' -WorkloadPath $wl.workload -Phase 'warm'
+    }
```

### Verification

- `[System.Management.Automation.Language.Parser]::ParseFile(...)`: 0 errors.
- Byte-level audit: 243 LF (was 228), CR=0, BOM=False, last byte 0x0A, no
  trailing whitespace, no non-ASCII. File remains well under the 300-LF cap.
- `Main` is now 39 lines (was 25); the file as a whole is 243 LF.

## F-02: cooldown cap drift

### Root cause

Plan entry doc L82 and impl log L249/L282 claim a 180s cap per R29-IMPL-02.
The helper `Wait-Stage29VramBaseline.ps1` default is `MaxWaitSec = 120`
(helper L60), and the docstring at L36 itself says "binding cap of 180s"
contradicting the parameter. The driver `Invoke-CycleLeg` calls the
helper with `-MaxWaitSec 120` (driver L189). Design D29-DESIGN-06 says
"30s sleep + nvidia-smi VRAM back-to-baseline gate, cap at 120s".

### Fix applied

- `Wait-Stage29VramBaseline.ps1` docstring L36-37: removed the 180s
  claim; replaced with a 120s statement that aligns the helper with
  design D29-DESIGN-06 and records the actual call-site MaxWaitSec
  values (60 in Phase 0.5/Phase 1, 120 in Phase 2/Phase 3 cycle legs).
- Impl log S29-IMPL-07 row: replaced "180s cap per R29-IMPL-02" with
  "120s cap per design D29-DESIGN-06".
- Impl log "Plan review N-03 resolution" section: replaced "180s cap"
  with "120s cap" in the cooldown hardener description.

No code behavior change; documentation alignment only.

## F-03: preflight missing 2 of 7 design sub-checks

### Status: SKIPPED

QA test plan F-03 (impl review N-03) records the preflight as missing
"disk check" and "binary mtime > source mtime" sub-checks. Both are
non-blocking: the 5 gating sub-checks cover the safety-critical checks
and `Invoke-Preflight` correctly classifies `BLOCKED-preflight` when
expected.

This fix session defers the two missing sub-checks to the QA execution
gate (per impl review N-03). The impl log S29-IMPL-03 row was updated
to clarify the actual field count (7 fields, 5 gating) for downstream
clarity.

## F-04: driver parameter count drift

### Fix applied to impl log

Impl log S29-IMPL-02 row: replaced "17-param set + `-DryRun` +
`-OutputEquivalenceOnly`" with "18-param set per impl-review N-02:
16 strings/ints + `-DryRun` + `-OutputEquivalenceOnly`".

The driver actually declares 18 typed parameters (driver L18-36). The
17-param count came from the design part-03 L168-185 parameter list,
which included `-ColdStartEnabled` (since dropped because Phase 2
always runs) and did not include `-RequestCount` and
`-OutputEquivalenceOnly` (added by the implementation session for QA
smoke). The wording now matches the actual param block.

## Self-test evidence

Run on 2026-06-28 in fresh Developer session. Commands run from
`d:\source\llama.cpp-jet`:

1. `-DryRun`:

   ```powershell
   pwsh -NoProfile -File ._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1 `
       -LlamaServerPath build-cuda\bin\Release\llama-server.exe `
       -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
       -DryRun
   ```

   Result: exit 0, prints preflight JSON with
   `status: "BLOCKED-preflight"` (cuda_proof=BLOCKED-cuda-configure-missing
   on this host because build-cuda/CMakeCache.txt is not present).

2. `-OutputEquivalenceOnly`:

   ```powershell
   pwsh -NoProfile -File ._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1 `
       -LlamaServerPath build-cuda\bin\Release\llama-server.exe `
       -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
       -OutputEquivalenceOnly
   ```

   Result: exit 4, prints `BLOCKED-server-not-running: equivalence-prompts.jsonl
   missing (Phase 0.5 not run)` (no Phase 0.5 prior execution on this host).

3. Function surface check:

   ```powershell
   pwsh -NoProfile -Command "& { . '.\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1'; Get-Command -CommandType Function | Select-Object -ExpandProperty Name | Sort-Object }"
   ```

   Result: confirms `Invoke-Phase1OutputEquivalence`, `Invoke-CycleLeg`,
   `Invoke-Phase05WorkloadBuild`, `Write-Stage29Report` are all present
   in the function surface (along with the 14 other functions).

## Byte-level audit (post-fix)

| File | LF | CR | BOM | Last byte | non-ASCII | trailing-ws |
| --- | ---: | ---: | --- | --- | ---: | ---: |
| compare-legacy-vs-hybrid.ps1 | 243 | 0 | NO | 0x0A | 0 | 0 |
| Wait-Stage29VramBaseline.ps1 | 90 | 0 | NO | 0x0A | 0 | 0 |
| cache-handling-phase29-implementation.md | 300 | 0 | NO | 0x0A | 0 | 0 |

`git diff --check -- <each file>`: clean.

## Why this fix was missed by the prior review

The Architect implementation review (part-06) verified each step
mapping by pointing to the driver function definition (e.g., "PASS.
Loop accepts Phase parameter, mode, cycle, workload path"). The
review confirmed function presence and parameter shape but did not
trace the call graph from `Main`. A stronger review would have
statically checked that every helper called from `Main` in design
part-03 (Phase 1 equivalence, Phase 2 cold-start, Phase 3 warm loops)
is actually invoked from `Main` in the full execution path.

This is a documented gap in the prior review; future implementation
reviews for staged work should include a `Main`-level call-graph
check against the design's phase sequencing.

## Handoff

Next owner: Manager (implementation-fix gate review). After gate PASS:
QA test-plan part-33 progresses from BLOCKED-driver-contract to
executable. After execution: Developer test-results review. After
Developer review PASS: Manager closure per D-CLOSURE-29-NN.

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace, and stays under the 300-line durable-doc cap.
