# Stage 12 closure decision

- Date: 2026-06-07
- Manager decision: Stage 12 CLOSED
- Evidence: test-report-20260607-04.md, test-report-20260607-05.md, paired -fixes.md, paired -developer-review.md
- Final counts: 18 PASS, 9 BLOCKED-infrastructure-limited, 2 cap-fix BLOCKED, 0 product bugs
- Script bugs: 2 fixed (S07 invalid --cache-protected-prompt flag; S08 same-file Start-Process redirect)
- test-stage10-policy-lru: pre-existing semantic bug, out of scope, separate session
- Follow-up tasks: (1) re-run 9 time-budget rows with longer wall-clock; (2) re-evaluate MTP rows when fixture available; (3) fix test-stage10-policy-lru
- Configuration baseline: build-cov BUILD_SHARED_LIBS=OFF /Zi /Ob1 /O2 /EHsc /DEBUG:FULL GGML_CUDA=OFF

## Manager plan-change decision D12 (2026-06-07)

Lift cap-fix closure's MTP hold. New scope: 3 MTP variants x 19
base scenarios x 2 jinja variants + 19 non-MTP x 2 jinja = 152
scenarios, multi-session execution per part-21 section 8. The
2026-06-07 closure PASS is preserved. part-21 is the only
follow-up scope for this lift. H53/H54 status moves from
BLOCKED-by-cap-fix to live in part-21. part-10 item A
classification flips from REMAINS-BLOCKER to CAN-DESIGN-OUT.
part-18a section 11 removes MTP-capable rows from the held-out
list. part-19 section 7.1 records the new -MtpVariant and
-JinjaVariant parameters on the 19 base drivers.

## Post-closure follow-ups (2026-06-07 cosmetic and operational)

The 2026-06-07 closure PASS records 18 PASS and 0 product bugs.
Eight small cosmetic and operational items remained after closure
and were folded into
[test-report-20260607-06-fixes.md](../.test_reports/test-report-20260607-06-fixes.md).
None is a design or product change. Closure state is unchanged.

1. stress_s12_s02_concurrent_multi_slot.ps1: dry-run port print.
   Live path computes `$portUse = $Port + $n`. Dry-run echo
   printed the base port. Fixed: dry-run now prints the planned
   per-slot port (8214, 8218 for default `Port=8210`,
   `SlotCounts=@(4,8)`).

2. stress_s12_s01_budget_exhaustion.ps1: dry-run evidence dir
   residue. The variant subdir was created before the DryRun
   early-exit. Fixed: subdir creation moved to the live path so
   DryRun leaves no empty dir on disk.

3. stress_s12_s05_mixed_workload_profiles.ps1: redundant
   `--model` in per-profile args. The live path appends
   `@('--model',$p.model)` after `$serverFlags`, so per-profile
   args already included a `--model` that hardcoded `$ModelPath`.
   For `target-plus-draft` and `checkpoint-dependent` profiles
   `$p.model` is `$largerModel`, so the per-profile `--model` was
   also wrong. Decision: removed per-profile `--model` from all
   three profiles. Live path is the single source of truth for
   the model argument.

4. longrun_s12_l01_6h_hybrid_stability.ps1 and
   longrun_s12_l03_2h_mixed_workload.ps1: integer-only duration
   parameter. `-DurationHours` is an int, so 5 min and 30 min
   smoke runs are not expressible without rounding. Fixed: added
   `-DurationMin` parameter. When greater than zero the driver
   uses it; otherwise it falls back to
   `-DurationHours * 3600`.

5. document-index.md: missing row for
   `cache-handling-phase12-implementation.md`. Added a new row
   in the implementation table patterned on the phase 11 row,
   with a 2026-06-07 Stage 12 closure PASS note and a link to
   the cosmetic-fix report.

6. part-19 section 10.1: LLAMA_CACHE_TEST_MODEL env hygiene note
   documents the absolute-path rule, PowerShell env-export scope,
   and quoting requirement for paths that contain spaces.

7. part-19 sections 10.2 and 10.3: PowerShell splat binding,
   Write-Host capture, and future-session timeout-choice notes
   for the next maintainer.

8. part-07 (this file): post-closure follow-ups section records
   the 8 items above so the closure record points to the
   follow-up fix report.
