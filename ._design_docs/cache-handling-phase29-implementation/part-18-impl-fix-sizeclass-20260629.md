# Stage 29 implementation fix pointer: S29-IMPL-FIX-06

Status: fix complete (Developer fix session, 2026-06-29)
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Owner: Developer (fix session in response to Manager authorization S29-IMPL-FIX-06)
Triggering finding: F-29-EXEC-15 NEW BLOCKING from QA -06 (test-report-20260629-04-stage29-06.md)
Triggering handoff: QA re-execution handoff [part-17](./part-17-qa-reexec-handoff-20260629-04.md)
Prior fix pointer: [./part-15-impl-fix-wrapper-max-iterations-20260629.md](./part-15-impl-fix-wrapper-max-iterations-20260629.md) (S29-IMPL-FIX-05)
Branch: work-branch

## Summary

S29-IMPL-FIX-06: 4 edits align the workload SizeClass with the server's per-slot context cap. Wrapper SizeClassMap gains a `'2k'` entry (Target=2000, SizeClass='2k'). Wrapper default `$SizeClass` changes from `'12k'` to `'2k'`. Agentic-prompt-generator `ValidateSet` on `[string] $SizeClass` extends from `'12k','24k','60k'` to `'2k','12k','24k','60k'`. Driver `Invoke-Phase05WorkloadBuild` passes `-SizeClass '2k'` explicitly on both `New-ComparisonWorkload` call sites (workload.jsonl and equivalence-prompts.jsonl). Status DONE.

## Root cause

The driver defaults `-c 4096 -parallel 2`, which gives a per-slot context of `4096 / 2 = 2048` tokens. The wrapper's default `$SizeClass = '12k'` mapped to `Target = 12000` tokens, so the agentic-prompt-generator built prompts at ~11480 tokens (the 95% of the 12k target). The first Phase 1 `/v1/chat/completions` POST exceeded the per-slot context and the server returned `400 Bad Request`. Phase 1 died before any cycle evidence was produced.

The wrapper and the agentic-prompt-generator both had `12k/24k/60k` baked in as the supported SizeClass set, so the smallest workload the wrapper could produce (12k) was already too large for the driver's per-slot context. The 2k entry was missing at both layers.

## Diff

File 1: `._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`

Change 1 (SizeClassMap, 1 line added):

```text
BEFORE (L47-51):
$script:SizeClassMap = @{
    '12k' = @{ Target = 12000; SizeClass = '12k' }
    '24k' = @{ Target = 24000; SizeClass = '24k' }
    '60k' = @{ Target = 60000; SizeClass = '60k' }
}

AFTER (L47-52):
$script:SizeClassMap = @{
    '2k'  = @{ Target = 2000;  SizeClass = '2k'  }
    '12k' = @{ Target = 12000; SizeClass = '12k' }
    '24k' = @{ Target = 24000; SizeClass = '24k' }
    '60k' = @{ Target = 60000; SizeClass = '60k' }
}
```

Change 2 (default $SizeClass, 1 line modified):

```text
BEFORE (L60):
        [string] $SizeClass          = '12k',

AFTER (L60):
        [string] $SizeClass          = '2k',
```

File 2: `._design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1`

Change 3 (ValidateSet, 1 line modified):

```text
BEFORE (L87):
        [ValidateSet('12k','24k','60k')]

AFTER (L87):
        [ValidateSet('2k','12k','24k','60k')]
```

File 3: `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`

Change 4 (Invoke-Phase05WorkloadBuild, both call sites modified, no line count change):

```text
BEFORE (L147):
        New-ComparisonWorkload -RequestCount $RequestCount -ServerUrl "http://127.0.0.1:$BasePort" -OutPath $wlPath -Seed $Seed -MaxTokens 8 -MaxIterations 200

AFTER (L147):
        New-ComparisonWorkload -RequestCount $RequestCount -ServerUrl "http://127.0.0.1:$BasePort" -OutPath $wlPath -Seed $Seed -MaxTokens 8 -MaxIterations 200 -SizeClass '2k'
```

```text
BEFORE (L149):
        New-ComparisonWorkload -RequestCount $OutputEquivalencePrompts -ServerUrl "http://127.0.0.1:$BasePort" -OutPath $eqPath -Seed $Seed -MaxTokens 8 -MaxIterations 200

AFTER (L149):
        New-ComparisonWorkload -RequestCount $OutputEquivalencePrompts -ServerUrl "http://127.0.0.1:$BasePort" -OutPath $eqPath -Seed $Seed -MaxTokens 8 -MaxIterations 200 -SizeClass '2k'
```

Net change: 1 line added (SizeClassMap entry), 4 lines modified (default $SizeClass, ValidateSet, two driver call sites), 0 lines removed.

## Self-test

- AST parse on wrapper: `[System.Management.Automation.Language.Parser]::ParseFile` on
  `compare-legacy-vs-hybrid-workload.ps1` returned 0 errors.
- AST parse on agentic lib: `[System.Management.Automation.Language.Parser]::ParseFile` on
  `agentic-prompt-generator.ps1` returned 0 errors.
- AST parse on driver: `[System.Management.Automation.Language.Parser]::ParseFile` on
  `compare-legacy-vs-hybrid.ps1` returned 0 errors.
- `-DryRun` self-test: invoked with
  `-ModelPath D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`,
  `-LlamaServerPath D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe`,
  `-BasePort 8998`. Output: preflight status PASS, exit code 0. All five gating
  sub-checks true (ps_version_ok, binary_exists, fixture_exists, port_free,
  cuda_proof=PASS). git_head `dbf593978b66a0d46a030f80c6e87345e08b3a04`,
  git_dirty 12 (untracked .ps1 scripts and test reports only).

## Verification evidence

- Grep `SizeClass` across
  `._design_docs/cache-handling-test-scripts/**/*.ps1` after fix returns the
  expected 17 matches:
  - 2 in `lib/agentic-prompt-generator.ps1` (`SizeClass` in the usage example
    comment at L19, plus the parameter and forward references at L88, L156).
  - 12 in `lib/compare-legacy-vs-hybrid-workload.ps1` (L45 comment,
    L47 declaration, L48-L51 SizeClassMap entries, L65 default param,
    L88/L89 unknown-SizeClass guard, L99/L100 sizeClassName unpacking,
    L110 anchor-pool call site, L147 per-request call site).
  - 2 in `compare-legacy-vs-hybrid.ps1` driver (L147 and L149
    `-SizeClass '2k'` append).
  - 0 in the 4 Stage 29 helper libs
    (`Read-Stage29MetricSnapshot.ps1`, `Write-Stage29EvidenceRow.ps1`,
    `Test-Stage29OutputEquivalence.ps1`, `Wait-Stage29VramBaseline.ps1`).
- Byte-level audit of `compare-legacy-vs-hybrid-workload.ps1` after fix:
  - LF count: 204 (matches `Get-Content .Count`, +1 from pre-fix 203)
  - CR count: 0
  - BOM: none
  - Last byte: 0x0A
  - Trailing whitespace: 0 matches
  - Non-ASCII characters: 0 matches
- Byte-level audit of `agentic-prompt-generator.ps1` after fix:
  - LF count: 308 (matches `Get-Content .Count`, 0 net change; the
    ValidateSet is a single-line edit)
  - CR count: 0
  - BOM: none
  - Last byte: 0x0A
  - Trailing whitespace: 0 matches
  - Non-ASCII characters: 0 matches
- Byte-level audit of `compare-legacy-vs-hybrid.ps1` after fix:
  - LF count: 247 (matches `Get-Content .Count`, 0 net change; the
    `-SizeClass '2k'` is appended to existing single-line calls)
  - CR count: 0
  - BOM: none
  - Last byte: 0x0A
  - Trailing whitespace: 0 matches
  - Non-ASCII characters: 0 matches
- `git diff --check` on wrapper, agentic lib, and driver: exit 0,
  no whitespace warnings.
- Implementation log entry doc: 300 LF (at cap, +2 from pre-fix 298; in-place paragraph addition).
- Pointer part file (this file): under 300-line cap.

## Constraint compliance

- Production code, test code, runner, design, implementation (other than
  this pointer part and the in-place log entry update), and test plan:
  NOT modified.
- Stage 25-28 invariants preserved (driver still reads from
  post-Stage-28 closed binary; no source under `tools/server/`,
  `tests/`, `common/`, `ggml/`, or `gguf-py/` is modified).
- ASCII only, LF line endings, no BOM, no trailing whitespace, no
  non-ASCII characters in all files authored or modified.
- Wrapper at 204 lines (cap 300, +1 from pre-fix 203).
- Agentic lib at 308 lines (cap 300, 0 net change; cap was already
  exceeded by a prior session, no further growth).
- Driver at 247 lines (cap 300, 0 net change; -SizeClass appended to existing lines).
- Implementation log entry doc at 300 lines (cap 300, +2 from pre-fix 298).
- This pointer part under 300 lines (cap).
- `git diff --check` clean on wrapper, agentic lib, and driver (scoped diff).

## Handoff

Next owner: Manager (implementation-fix gate review, iteration 5).
Next gate: Manager implementation-fix gate #5 review, then QA
re-execution of the Stage 29 driver per the existing QA test plan
part-33. The driver should now produce a workload that fits within
the per-slot context (Target=2000 tokens per prompt via -SizeClass '2k'),
so Phase 1 output equivalence can complete and Phase 2/3 cycle evidence
can be produced. After QA re-run PASS: Developer test-results review.
After Developer review PASS: Manager closure per D-CLOSURE-29-NN.
