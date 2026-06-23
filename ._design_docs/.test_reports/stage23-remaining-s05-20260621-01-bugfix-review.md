# Stage 23 S05 runner-contract bugfix review

Status: PASS
Date: 2026-06-21
Owner: Architect
Subject: [stage23-remaining-s05-20260621-01-fixes.md](stage23-remaining-s05-20260621-01-fixes.md)
Trigger report: [stage23-remaining-s05-20260621-01.md](stage23-remaining-s05-20260621-01.md)

## Scope and gate status

Reviewed the S05 runner-contract fix from report `20260621-01`. Scope was
limited to runner/script contract behavior, persistent Stage 23 gate wording,
and lightweight parser/dry-run evidence. No product code, public server metrics,
public CLI flags, tests, fixtures, or model assets were reviewed as changed.

Verdict: PASS. The fix is acceptable for a focused S05 QA rerun only. S06..S08
and L01..L03 remain stopped until S05 disposition is accepted.

## Reviewed files

- `._design_docs/.test_reports/stage23-remaining-s05-20260621-01.md`
- `._design_docs/.test_reports/stage23-remaining-s05-20260621-01-fixes.md`
- `._design_docs/cache-handling-phase23-design.md`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s05_mixed_workload_profiles.ps1`

## Findings

| ID | Severity | Verdict | Notes |
| --- | --- | --- | --- |
| F-23-S05-AR-01 | Blocking | PASS | Root cause is confirmed: S05 treated `DurationMin=30` as a per-profile cap, so one Stage 23 S05 row could run about 90 minutes and miss wrapper `row_gate`/`batch_end`. |
| F-23-S05-AR-02 | Blocking | PASS | Fix now treats `DurationMin` as the whole row cap and splits it across three profiles. For 30 minutes it allocates 600/600/600 seconds. The last profile receives any integer remainder. |
| F-23-S05-AR-03 | Blocking | PASS | Mixed workload intent is preserved for rerun: all three profiles still execute, with equal time under the Stage 23 row cap and per-profile evidence. |
| F-23-S05-AR-04 | Blocking | PASS | Wrapper dry-run and live paths expose `S05 profile_allocation` in the side log before execution evidence is judged. QA can verify allocation before live rerun. |
| F-23-S05-AR-05 | Blocking | PASS | Parser and whitespace checks found no blocking issue. Manager's trailing-whitespace/LF cleanup is treated as mechanical formatting recovery, not behavior change. |

## Evidence checked

- Stage 23 design requires stress rows to use a 30 minute per-row cap.
- QA report `stage23-remaining-s05-20260621-01.md` shows three 1800 second S05
  profile summaries and missing wrapper `row_gate`/`batch_end`.
- S05 script dry-run:

```text
DRY-RUN: S12-S05 row cap 30 min (1800 sec); profiles=3
DRY-RUN: would run profile plain-transformer for 600 sec
DRY-RUN: would run profile target-plus-draft for 600 sec
DRY-RUN: would run profile checkpoint-dependent for 600 sec
```

- Wrapper dry-run side log:

```text
DryRun S05 profile_allocation rowCapSeconds=1800 allocations=plain-transformer=600,target-plus-draft=600,checkpoint-dependent=600
```

- PowerShell parser check passed for both changed scripts.
- `git diff --check` returned clean for the reviewed script and Stage 23 entry
  document paths.
- Byte hygiene checked on the fix report and changed scripts: LF-only, no BOM,
  ASCII-only.

## Risk notes

- No live S05 rerun was run by Architect. QA must provide the live evidence.
- The fix is validated for the Stage 23 30 minute cap. Tiny synthetic caps under
  three seconds are not part of Stage 23 acceptance.
- S05 runtime can still exceed 30 minutes by normal startup, health wait, and
  cleanup overhead. QA should judge the workload loop allocation against the
  side-log allocation and row evidence, not wall-clock startup overhead alone.

## Next owner

Next owner: QA.

Run a focused S05 rerun only, with a fresh suffix and the existing CUDA
preflight rules. QA must verify wrapper dry-run allocation, live side-log
allocation, `row_gate`, `batch_end`, three profile evidence directories, redacted
prompt evidence, cold budget, and S05 row verdict. S06..S08 and L01..L03 remain
stopped until S05 disposition is accepted.
