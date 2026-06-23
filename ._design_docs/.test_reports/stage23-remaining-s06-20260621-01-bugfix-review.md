# Stage 23 S06 runner-contract bugfix review

Status: PASS
Date: 2026-06-21
Owner: Architect
Scope: review of the S06 runner-contract fix from
`stage23-remaining-s06-20260621-01-fixes.md`. No live S06 row was run.

## Scope and gate status

Verdict: PASS

The fix matches the Stage 23 runner contract for S06. QA may run a focused S06
rerun only, with a fresh suffix, after Manager accepts this review. S07..S08
and L01..L03 remain stopped.

## Reviewed files

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase23-design.md`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/.test_reports/stage23-remaining-s06-20260621-01.md`
- `._design_docs/.test_reports/stage23-remaining-s06-20260621-01-fixes.md`
- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s06_cold_queue_pressure.ps1`

## Findings

| ID | Severity | Verdict | Notes |
| --- | --- | --- | --- |
| F-23-S06-RC-01 | Blocking | Closed | Root cause confirmed: wrapper Stage 17 args appended `--cache-ram 512` after S06 local `--cache-ram 16`, so the live row used 512 MiB and did not exercise cold pressure. |
| F-23-S06-RC-02 | Blocking | Closed | Fix confirmed: S06 wrapper args omit wrapper `--cache-ram`, the child receives `-HotBudgetMiB 16`, and dry-run/live side logs expose `effective_cache_ram_mib=16`. |
| F-23-S06-RC-03 | Blocking | Closed | S06 still carries required Stage 23 flags: hybrid mode, cold max 512, CUDA all, fit off, cold path, redacted prompt evidence, evidence dir, model, and run root. |
| F-23-S06-RC-04 | Blocking | Closed | Non-S06 rows still receive wrapper `--cache-ram 512`; checked with S04 dry-run. |
| F-23-S06-RC-05 | Blocking | Closed | No product code, public metrics, public flags, tests, fixtures, commits, or pushes are part of the reviewed S06 runner fix. |

## Evidence checked

- Parser checks passed for the wrapper and S06 script.
- S06 dry-run passed with Stage 23 command shape.
- S06 side log showed no wrapper `--cache-ram 512` and did show:
  `effective_cache_ram_mib=16 source=S06-HotBudgetMiB wrapper_cache_ram_mib=512 stage17_cache_ram_appended=false`.
- S06 dry-run flags included `--cache-mode hybrid`, `--cache-cold-max-mib 512`,
  `--n-gpu-layers all`, `--fit off`, `--cache-cold-path`,
  `--cache-prompt-evidence redacted`, and `--cache-prompt-evidence-dir`.
- S04 dry-run passed and still included `--cache-ram 512`.
- Current workspace has unrelated dirty product files from earlier work; this
  review did not modify or approve them.

## Risk notes

- The Developer fix report's changed-files list omits the S06 child script, but
  this review inspected that script directly. The omission does not change the
  runner contract verdict.
- Dry-run proves argument construction. It does not prove live cold pressure.
  QA must confirm the live S06 server startup limit is 16 MiB and that demotion,
  skip, or eviction evidence appears before classifying S06.

## Next owner

Next owner: QA, after Manager accepts the review.

Allowed retest: focused S06 rerun only, fresh durable report suffix, fresh
`._test_output` root, and fresh cold root. S07..S08 and L01..L03 remain stopped.
