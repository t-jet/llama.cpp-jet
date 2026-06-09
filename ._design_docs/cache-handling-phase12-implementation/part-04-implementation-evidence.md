# Stage 12 implementation - Part 4: implementation evidence

Source: [../cache-handling-phase12-implementation.md](../cache-handling-phase12-implementation.md)

## Status

- Plan state: implemented 2026-06-07.
- Syntax check: all 25 PowerShell scripts pass parser tokenize with 0 errors.
- Dry-run mode: all 19 scenario scripts (8 stress + 8 bench + 3 longrun) complete with no errors.
- Live mode: not opened (separate QA execution gate).

## Verification commands

The user instruction was to verify with `pwsh -NoProfile -Command
"Get-Command -Syntax <path>"` (or parse-only with
`[System.Management.Automation.PSParser]::Tokenize`). The parse-only
check used the modern equivalent
`[System.Management.Automation.Language.Parser]::ParseInput` which
returns the same parse error set the legacy PSParser tokenize exposed
on PowerShell 5.1.

## Syntax check log

Full syntax check log is at
`._design_docs/.test_reports/build-impl-20260607-01.log` (131 lines).

Summary table from that log:

| Group | Files | crlf | lf | err |
| --- | --- | --- | --- | --- |
| lib | 5 | 48..130 | 48..130 | 0 |
| stress | 8 | 138..163 | 138..163 | 0 |
| bench | 8 | 156..212 | 156..212 | 0 |
| longrun | 3 | 138..152 | 138..152 | 0 |
| root | 1 | 86 | 86 | 0 |
| sum | 25 | 0 mismatched | 0 mismatched | 0 |

All scripts use CRLF line endings to match the existing
`run_benchmark_k6.ps1`, `stress_tests.ps1`, and the rest of the
tracked PowerShell scripts in
`._design_docs/cache-handling-test-scripts/`. No script uses Unicode
em-dashes or non-ASCII characters.

## Dry-run mode log

The build-impl log also captures the output of running each of the
19 scenario scripts with `-DryRun`. Each script prints its planned
server flags, fixture path, port, and duration; none attempt a
server start, none write STUB artifacts, none call k6 or the focused
fault-injection binary. The dry-run path proves the param parsing,
the fixture existence checks, and the planned flag shape.

## Fix history captured in build-impl log

Two issues were found and fixed during verification, both recorded
in the build-impl log under `## 3. fix history`:

1. `Export-ModuleMember` outside a module emitted non-terminating
   errors on every dot-source of `lib/*.ps1`. Removed
   `Export-ModuleMember` from all 5 lib helpers; dot-sourcing does
   not need module export.
2. `bench_s12_b01_exact_blob_hit_rate.ps1` line 51 mixed a pipeline
   with `+ @(...)`, which the parser bound as a positional
   argument. Rewrote `$legacyFlags` as a direct array literal
   matching `$hybridFlags` with `hybrid` replaced by `legacy`.

Both fixes are reflected in the round 2 syntax and dry-run checks
recorded in the build-impl log.

## Script inventory

- Total PowerShell scripts created: 25
- 5 lib helpers (Write-StressEvidence, Write-BenchEvidence,
  Write-LongrunEvidence, Read-BaselineJson, Write-TuningReport)
- 8 stress drivers under `stress/`
- 8 benchmark drivers under `bench/`
- 3 long-run drivers under `longrun/`
- 1 config matrix helper at the test-scripts dir root
- 3 evidence dir template READMEs under `._design_docs/.test_reports/`
- 1 README update at `._design_docs/cache-handling-test-scripts/README.md`

## Handoff to next gate

- Architect implementation review of part-03 and part-04.
- QA test planning reads part-05 (fixture requirements) and the
  build-impl log to plan the first execution session.
