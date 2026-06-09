# Test report 20260607-06 fixes (simple cosmetic/operational)

Source: Stage 12 closure decision part-07 cosmetic/operational items
Date: 2026-06-07
Owner: Developer

## Scope

Eight small cosmetic and operational fixes applied after the
2026-06-07 Stage 12 closure PASS. No design change. No product
bug. Closure state is unchanged.

## Per-fix summary

1. stress_s12_s02_concurrent_multi_slot.ps1: dry-run port print.
   Live code at line 83 computes `$portUse = $Port + $n`. Dry-run
   echo printed the base port 8210 for both sub-runs. Fixed:
   dry-run now computes `$plannedPort = $Port + $n` and prints
   the planned per-slot port (8214 and 8218 for the default
   `Port=8210`, `SlotCounts=@(4,8)`).

2. stress_s12_s01_budget_exhaustion.ps1: dry-run evidence dir
   residue. The variant subdir was created before the DryRun
   early-exit, leaving an empty dir on disk. Fixed: moved the
   `New-Item` subdir creation to the live path so DryRun leaves
   no residue. The dir is still printed in the dry-run echo so
   the plan output is unchanged.

3. stress_s12_s05_mixed_workload_profiles.ps1: redundant
   `--model` in per-profile args. Decision: removed
   `--model` from all three per-profile args blocks. The live
   path appends `@('--model',$p.model)` after `$serverFlags` and
   is the single source of truth. The previous per-profile
   `--model` hardcoded `$ModelPath`, which was wrong for
   `target-plus-draft` and `checkpoint-dependent` profiles where
   `$p.model` is `$largerModel`. Removal makes the model argument
   consistent across all three profiles.

4. longrun_s12_l01_6h_hybrid_stability.ps1 and
   longrun_s12_l03_2h_mixed_workload.ps1: integer-only
   `-DurationHours` made sub-hour wall-clock runs unreachable.
   Fixed: added `-DurationMin` (int, default 0). When greater
   than zero the driver converts to seconds; otherwise it falls
   back to `-DurationHours * 3600`. Dry-run plan print updated
   to reflect the active unit.

5. document-index.md: missing implementation-table row for
   `cache-handling-phase12-implementation.md`. Added a new row
   in the implementation table patterned on the phase 11 row,
   with a 2026-06-07 Stage 12 closure PASS note and a link to
   this fixes report.

6. part-19-stage12-test-automation.md section 10.1:
   LLAMA_CACHE_TEST_MODEL env hygiene note. Documents the
   absolute-path rule, PowerShell env-export scope across
   separate `pwsh -File` invocations, and the quoting
   requirement for paths with spaces.

7. part-19-stage12-test-automation.md sections 10.2 and 10.3:
   PowerShell splat binding rule, Write-Host capture note, and
   future-session timeout-choice note. The splat note warns
   against mixing a pipeline result with `+ @(...)` on the same
   assignment (parser binds `+` as positional arg). The capture
   note explains why the harness uses `Write-Host` for dry-run
   plan prints. The timeout note documents the
   `-DurationMin` / `-DurationHours` precedence.

8. part-07-stage12-closure-decision.md: post-closure follow-ups
   section listing the 8 items above so the closure record
   points to this fixes report.

## Evidence

Files modified (8):

- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s01_budget_exhaustion.ps1`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s02_concurrent_multi_slot.ps1`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s05_mixed_workload_profiles.ps1`
- `._design_docs/cache-handling-test-scripts/longrun/longrun_s12_l01_6h_hybrid_stability.ps1`
- `._design_docs/cache-handling-test-scripts/longrun/longrun_s12_l03_2h_mixed_workload.ps1`
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-test-plan/part-19-stage12-test-automation.md`
- `._design_docs/cache-handling-phase12-implementation/part-07-stage12-closure-decision.md`

No build, test, or model-backed run was executed. No coverage
run dir was touched. No 4 self-improvement assets, no manager
agent, and no 3 cap-fix source files were modified.

## Handoff

Closure state on part-07 remains 2026-06-07 PASS. The 8 items
above are post-closure follow-ups and do not require a Manager
decision. The next maintainer who extends the Stage 12 harness
should read part-19 section 10 before editing the driver
scripts.
