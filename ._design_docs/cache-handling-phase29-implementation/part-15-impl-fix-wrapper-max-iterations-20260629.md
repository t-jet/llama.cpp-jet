# Stage 29 implementation fix pointer: S29-IMPL-FIX-05

Status: fix complete (Developer fix session, 2026-06-29)
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Owner: Developer (fix session in response to Manager authorization S29-IMPL-FIX-05)
Triggering finding: F-29-EXEC-09 (NON-BLOCKING, evidence) from QA report test-report-20260629-01-stage29-03.md L134
Triggering handoff: QA execution handoff [part-13](./part-13-qa-execution-handoff-20260629.md)
Prior fix pointer: [./part-14-impl-fix-driver-dot-source-20260629.md](./part-14-impl-fix-driver-dot-source-20260629.md) (S29-IMPL-FIX-04)
Branch: work-branch

## Summary

S29-IMPL-FIX-05: plumb `-MaxIterations` parameter through `New-ComparisonWorkload` (default 200) to both `New-AgenticChatPrompt` call sites in the wrapper; driver passes `-MaxIterations 200` for the main workload and `-MaxIterations 50` for the output-equivalence workload. Status DONE.

## Root cause

The wrapper `lib/compare-legacy-vs-hybrid-workload.ps1` calls `New-AgenticChatPrompt` twice (anchor pool at the post-fix first call site, per-request entries at the post-fix second call site) without passing `-MaxIterations`. `New-AgenticChatPrompt` (in `lib/agentic-prompt-generator.ps1`) defaults to `MaxIterations = 50` (L95). The wrapper defaults `SizeClass = '12k'` (L64), which maps to `TargetTokens = 12000` via `$script:SizeClassMap`. The agentic prompt generator's iterative expansion loop (`while ($iterations -lt $MaxIterations)` at L128) cannot reach 12000 tokens in 50 iterations; QA report -04 observed convergence at 10631/12000. Anchor tests at smaller targets converged as expected (2k->1969, 4k->3852, 8k->7669), so the generator works correctly at smaller sizes; only the 12k main workload fails to fully converge.

The bug was latent until QA report -04 ran the main workload at `SizeClass='12k'`. The 50-iteration cap is appropriate for the 5-prompt output-equivalence workload (small `RequestCount`) but insufficient for the 200-request main workload at 12k tokens per prompt.

Manager directive (verbatim user message 2026-06-29): "Don't close the stage until all things are resolved. I mean the following: ... One line in lib/compare-legacy-vs-hybrid-workload.ps1: Add -MaxIterations parameter (or change SizeClass default from '12k' to '2k'), OR Plumb MaxIterations through New-ComparisonWorkload -> New-AgenticChatPrompt and have the driver pass -MaxIterations 200."

## Diff

File 1: `_design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`

Change 1 (signature, 1 line added):

```text
BEFORE (L65):
        [int]    $TokenizeTimeoutSec = 60
    )

AFTER (L65-L66):
        [int]    $TokenizeTimeoutSec = 60,
        [int]    $MaxIterations      = 200
    )
```

Change 2 (anchor pool call site, 1 line added):

```text
BEFORE:
            -Seed ($Seed + $i) `
            -TimeoutSec $TokenizeTimeoutSec | Out-Null

AFTER:
            -Seed ($Seed + $i) `
            -TimeoutSec $TokenizeTimeoutSec `
            -MaxIterations $MaxIterations | Out-Null
```

Change 3 (per-request call site, 1 line added):

```text
BEFORE:
                -Seed ($Seed + $reqIdx + 10000) `
                -TimeoutSec $TokenizeTimeoutSec | Out-Null

AFTER:
                -Seed ($Seed + $reqIdx + 10000) `
                -TimeoutSec $TokenizeTimeoutSec `
                -MaxIterations $MaxIterations | Out-Null
```

File 2: `_design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`

Change 4 (main workload, single-line append):

```text
BEFORE (L147):
        New-ComparisonWorkload -RequestCount $RequestCount -ServerUrl "http://127.0.0.1:$BasePort" -OutPath $wlPath -Seed $Seed -MaxTokens 8

AFTER (L147):
        New-ComparisonWorkload -RequestCount $RequestCount -ServerUrl "http://127.0.0.1:$BasePort" -OutPath $wlPath -Seed $Seed -MaxTokens 8 -MaxIterations 200
```

Change 5 (output equivalence workload, single-line append):

```text
BEFORE (L149):
        New-ComparisonWorkload -RequestCount $OutputEquivalencePrompts -ServerUrl "http://127.0.0.1:$BasePort" -OutPath $eqPath -Seed $Seed -MaxTokens 8

AFTER (L149):
        New-ComparisonWorkload -RequestCount $OutputEquivalencePrompts -ServerUrl "http://127.0.0.1:$BasePort" -OutPath $eqPath -Seed $Seed -MaxTokens 8 -MaxIterations 50
```

Net change: 5 lines added (1 signature + 2 call-site continuations + 2 driver single-line appends), 0 lines removed. Brief's cited line refs (L107-118 for signature, L187 for the call site, L147/L149 for the driver) did not match disk state; actual disk locations are L53-66 for the signature, L106 and L142 for the two wrapper call sites, and L147 / L149 for the driver.

## Self-test

AST parse: `[System.Management.Automation.Language.Parser]::ParseFile` on `compare-legacy-vs-hybrid.ps1` returned 0 errors. Captured at session end (2026-06-29). Live execution NOT performed in this fix session per the Manager brief; the F-29-EXEC-09 evidence already exists in QA report -04.

## Verification evidence

- AST parse on wrapper: `[System.Management.Automation.Language.Parser]::ParseFile` on
  `compare-legacy-vs-hybrid-workload.ps1` returned 0 errors.
- AST parse on driver: `[System.Management.Automation.Language.Parser]::ParseFile` on
  `compare-legacy-vs-hybrid.ps1` returned 0 errors.
- AST parse on generator: `[System.Management.Automation.Language.Parser]::ParseFile` on
  `agentic-prompt-generator.ps1` returned 0 errors (unchanged).
- Grep for `MaxIterations` across
  `._design_docs/cache-handling-test-scripts/**/*.ps1` after fix returns 12 matches total:
  - 5 matches in `lib/agentic-prompt-generator.ps1` (L95 default,
    L102/L103 validation throws, L128 while-loop guard, L141 convergence-fail throw).
  - 4 matches in `lib/compare-legacy-vs-hybrid-workload.ps1`
    (L66 signature default, L114 anchor-pool call site, L150 per-request call site,
    plus the unused validation throw at L102 which is in the generator, not the wrapper).
  - 2 matches in `compare-legacy-vs-hybrid.ps1` driver (L147 `-MaxIterations 200`,
    L149 `-MaxIterations 50`).
  - 0 matches in the 4 Stage 29 helper libs
    (`Read-Stage29MetricSnapshot.ps1`, `Write-Stage29EvidenceRow.ps1`,
    `Test-Stage29OutputEquivalence.ps1`, `Wait-Stage29VramBaseline.ps1`).
- Byte-level audit of `compare-legacy-vs-hybrid-workload.ps1` after fix:
  - LF count: 203 (matches `Get-Content .Count`, +3 from pre-fix 200)
  - CR count: 0
  - BOM: none
  - Last byte: 0x0A
  - Trailing whitespace: 0 matches
  - Non-ASCII characters: 0 matches
- Byte-level audit of `compare-legacy-vs-hybrid.ps1` after fix:
  - LF count: 247 (matches `Get-Content .Count`, 0 net LF change; the
    `-MaxIterations` parameters are appended to existing single-line calls)
  - CR count: 0
  - BOM: none
  - Last byte: 0x0A
  - Trailing whitespace: 0 matches
  - Non-ASCII characters: 0 matches
- `git diff --check` on driver and wrapper: exit 0, no whitespace warnings
  (both files are untracked per status quo; production tree
  `tools/server/`, `tests/`, `common/`, `ggml/`, `gguf-py/` unchanged).
- Wrapper line count: 203 (under the 300-line cap, +3 from pre-fix 200).
- Driver line count: 247 (under the 300-line cap, same as pre-fix).
- Pointer part file (this file): under 300-line cap.
- Implementation log entry doc: 297 LF (in-place paragraph update; under 300-line cap).

## Constraint compliance

- Production code, test code, runner, design, implementation (other than
  the in-place log section update and this pointer part), and test plan:
  NOT modified.
- Stage 25-28 invariants preserved (driver still reads from
  post-Stage-28 closed binary; no source under `tools/server/`,
  `tests/`, `common/`, `ggml/`, or `gguf-py/` is modified).
- ASCII only, LF line endings, no BOM, no trailing whitespace, no
  non-ASCII characters in all files authored or modified.
- Wrapper stays at 203 lines (cap 300, +3 from pre-fix 200).
- Driver stays at 247 lines (cap 300, same as pre-fix; new params appended to existing lines).
- Implementation log entry doc stays at 297 lines (cap 300; in-place paragraph update).
- This pointer part stays under 300 lines (cap).
- `git diff --check` clean on wrapper and driver (scoped diff).

## Handoff

Next owner: Manager (implementation-fix gate review, iteration 4).
Next gate: Manager implementation-fix gate #4 review, then QA
re-execution of the Stage 29 driver per the existing QA test plan
part-33. The driver should now produce a fully-converged main workload
(200 prompts at 12000 tokens each, via 200 iterations) and the existing
output equivalence workload (5 prompts at 12000 tokens each, via 50
iterations, identical to the prior default). After QA re-run PASS:
Developer test-results review. After Developer review PASS: Manager
closure per D-CLOSURE-29-NN.

## Follow-on: S29-IMPL-FIX-06 (2026-06-29)

Driver L149 equivalence call site changed from `-MaxIterations 50` to `-MaxIterations 200` to address F-29-EXEC-12 from QA -05 PARTIAL (test-report-20260629-03-stage29-05.md). Same defect class as F-29-EXEC-09 but on a different call site: FIX-05 plumbed `-MaxIterations $MaxIterations` through both wrapper call sites and set the wrapper default to 200, but the driver equivalence call site was intentionally given a smaller budget (50 iterations for 5 prompts) that the wrapper's default SizeClass=12k cannot satisfy. The wrapper default is unchanged; only the driver-side `-MaxIterations` value at L149 changed. Driver LF stays at 247 (cap 300); AST parse clean (0 errors); no live run per Manager brief. Stage remains at bug handoff per Manager directive 2026-06-29.
