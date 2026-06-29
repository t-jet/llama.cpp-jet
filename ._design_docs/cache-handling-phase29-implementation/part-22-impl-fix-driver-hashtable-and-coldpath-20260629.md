# Stage 29 implementation fix: driver hashtable round-trip + cold-path pre-create

Status: S29-IMPL-FIX-07 DONE
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison)
Owner: Developer (fix session)
Source handoff: [part-21](./part-21-qa-reexec-handoff-20260629-09.md) (QA -09 re-execution handoff)
Branch: work-branch
Driver path: `D:\source\llama.cpp-jet\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1`

## Summary

Two edits to the main driver. Both targeted BLOCKING findings from the
QA -09 handoff: F-29-EXEC-17 (hashtable-scope whitespace on `$wl.workload`)
and F-29-EXEC-19 (cold path not pre-created). After the edits, the driver
parses cleanly, passes `-DryRun` with preflight PASS, and is ready for the
Manager implementation-fix gate review (iteration 4) and a fresh QA
re-execution.

## Root cause (from QA -09 part-21)

F-29-EXEC-17: `main.stdout.log` line 1 reads `Workload built at   D:\...`
with 3 spaces (0x20 0x20 0x20) between "at" and the path. The Manager's
standalone probe showed `$wl.workload` returns a clean string, so the
whitespace is not inherent to hashtable property access. It surfaces under
the driver execution context only. Driver dies at `Get-Content -LiteralPath $WorkloadPath`
with `Cannot find drive. A drive with the name '  D' does not exist.`

F-29-EXEC-19: hybrid cold store rejected `--cache-cold-path` with
`cold store: configure failed: root path does not exist`. The driver
never created the parent directory; llama-server's cold-store code
requires the path to exist before it can be opened.

## Edits

### Edit 1: Start-Stage29Server pre-create cold path

Location: `compare-legacy-vs-hybrid.ps1` L89-L91 (after S29-IMPL-FIX-06 the function starts at L87).

```powershell
function Start-Stage29Server {
    param([string]$Mode, [int]$Port)
+    if ($Mode -eq 'hybrid' -and $CacheColdPath -and -not (Test-Path $CacheColdPath)) {
+        New-Item -ItemType Directory -Force -Path $CacheColdPath | Out-Null
+    }
    $args = @('-m', (Resolve-Stage29Path $ModelPath), '--cache-mode', $Mode, '--port', $Port, '-c', $ContextSize, '--parallel', $Parallel, '--cache-ram', $HotBudgetMiB, '--metrics', '--seed', $Seed)
```

The guard only fires when `$Mode -eq 'hybrid'`, when `$CacheColdPath` is
non-empty, and when the path does not already exist. Legacy mode and
pre-populated paths bypass the `New-Item` call.

### Edit 2: Main dispatcher explicit string variables

Location: `compare-legacy-vs-hybrid.ps1` L230-L246.

```powershell
    if ($preflight.status -ne 'PASS') { Write-Error ("BLOCKED-preflight: " + ($preflight | ConvertTo-Json -Compress)); exit 2 }
    $wl = Invoke-Phase05WorkloadBuild
-    Write-Output ("Workload built at " + $wl.workload)
+    $wlPath = [string]$wl.workload
+    $eqPath = [string]$wl.equivalence
+    Write-Output ("Workload built at " + $wlPath)
    try {
        $eq = Invoke-Phase1OutputEquivalence
    ...
-    Invoke-CycleLeg -Cycle 1 -Mode 'legacy' -WorkloadPath $wl.workload -Phase 'cold-start'
-    Invoke-CycleLeg -Cycle 1 -Mode 'hybrid' -WorkloadPath $wl.workload -Phase 'cold-start'
+    Invoke-CycleLeg -Cycle 1 -Mode 'legacy' -WorkloadPath $wlPath -Phase 'cold-start'
+    Invoke-CycleLeg -Cycle 1 -Mode 'hybrid' -WorkloadPath $wlPath -Phase 'cold-start'
    for ($c = 1; $c -le $Cycles; $c++) {
-        Invoke-CycleLeg -Cycle $c -Mode 'legacy' -WorkloadPath $wl.workload -Phase 'warm'
-        Invoke-CycleLeg -Cycle $c -Mode 'hybrid' -WorkloadPath $wl.workload -Phase 'warm'
+        Invoke-CycleLeg -Cycle $c -Mode 'legacy' -WorkloadPath $wlPath -Phase 'warm'
+        Invoke-CycleLeg -Cycle $c -Mode 'hybrid' -WorkloadPath $wlPath -Phase 'warm'
    }
```

The `[string]` cast normalizes the type. The explicit `$wlPath` local
variable is what gets passed to every `Invoke-CycleLeg -WorkloadPath`,
so the hashtable-scope whitespace cannot reach any downstream path.

## Verification

Driver byte-level audit:

- Line count: 252 (was 247; +5 net from 2 edits; under 300-line cap).
- LF=252, CR=0, BOM=NO, last byte 0x0A.
- Trailing whitespace scan: NONE.
- Non-ASCII scan: NONE.

Grep checks:

- `$wl.workload`: 1 hit at L230 (`$wlPath = [string]$wl.workload`). No `Invoke-CycleLeg` call uses `$wl.workload`; all 4 cycle-leg calls now use `$wlPath`.
- `New-Item.*CacheColdPath`: 1 hit at L90 inside `Start-Stage29Server`.
- `$wlPath`: 7 hits. 1 inside `Invoke-Phase05WorkloadBuild` (L149, local var for the workload JSONL path), 1 conversion at Main L230, 1 `Write-Output` at L232, 4 `Invoke-CycleLeg -WorkloadPath` arguments (L242, L243, L245, L246).

Hygiene:

- `git diff --check -- compare-legacy-vs-hybrid.ps1`: exit 0.
- `git diff --stat`: 1 file changed, 12 insertions(+), 7 deletions(-) (includes the 2 pre-existing S29-IMPL-FIX-06 line modifications on `New-ComparisonWorkload`).
- PowerShell parser: `PARSE_OK` (no syntax errors).

`-DryRun` self-test:

- Command: `pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -DryRun -LlamaServerPath D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe -ModelPath D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf -RunRoot D:\source\llama.cpp-jet\_test_output\stage29-cache-modes-20260629-07-dryrun`
- Exit code: 0.
- Output: `DryRun preflight: {"ps_version_ok":true,"binary_exists":true,"fixture_exists":true,"port_free":true,"cuda_proof":"PASS","git_head":"dbf593978b66a0d46a030f80c6e87345e08b3a04","git_dirty":18,"status":"PASS"}`
- Status PASS, cuda_proof PASS. `git_dirty` is informational only.

## What is NOT changed

- Production code (no edits under `tools/server/`, `common/`, `ggml/`, `gguf-py/`).
- Test code (`tests/`).
- Runner scripts.
- Test plan.
- Design files.
- The wrapper script `lib/compare-legacy-vs-hybrid-workload.ps1` (200 lines, design-correct).
- The 4 lib helpers (`Read-Stage29MetricSnapshot.ps1`, `Write-Stage29EvidenceRow.ps1`, `Test-Stage29OutputEquivalence.ps1`, `Wait-Stage29VramBaseline.ps1`).
- S29-IMPL-FIX-01..06 changes are preserved (the S29-IMPL-FIX-06 inline `-MaxIterations 200 -SizeClass '2k'` flags on the `New-ComparisonWorkload` calls remain visible in the git diff and are not touched by this session).

## Carry-forward items (non-blocking)

- F-29-EXEC-13: Release build lacks `/Zi`; OpenCppCoverage unusable. Affects TP-29-CV-01 only.
- F-29-EXEC-14: huggingface-hub==1.16.1 does not satisfy transformers constraint. Affects TP-29-RG-01 pytest sub-check only.

## Handoff

Next owner: Manager (implementation-fix gate review, iteration 4). After gate PASS, QA re-execution per test plan part-33 (cold-start cycle 1 through warm cycle 3 with the canonical driver). After re-run PASS: Developer test-results review. After Developer review: Manager closure per D-CLOSURE-29-NN.
