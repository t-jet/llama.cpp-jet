# Stage 23 L02 runner-contract bugfix review

Verdict: PASS
Owner: Architect
Date: 2026-06-22
Scope: Review of the L02 runner-contract fix before focused QA rerun. L03
remains stopped.

## Scope and gate status

Reviewed:

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-stage-tracker.md`
- `._design_docs/cache-handling-phase23-design.md`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/cache-handling-test-plan.md`
- `._design_docs/cache-handling-test-scripts/README.md`
- `._design_docs/.test_reports/stage23-remaining-l02-20260622-01.md`
- `._design_docs/.test_reports/stage23-remaining-l02-20260622-01-fixes.md`
- `._design_docs/cache-handling-test-scripts/longrun/longrun_s12_l02_30m_legacy_comparison.ps1`
- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `._design_docs/cache-handling-test-scripts/lib/Write-LongrunEvidence.ps1`

Gate result: PASS for Manager to open a focused L02 rerun. This review does
not open L03.

## Decisions

1. L02 legacy-comparison contract is satisfied for rerun.

   The child runner now creates two bounded legs, `legacy-control` and
   `hybrid-stage23`, and writes root `l02-comparison.json` plus root
   `evidence-summary.md`. The comparison status becomes `PASS` only when both
   legs make requests; otherwise the child exits non-zero.

2. The 30 minute cap intent is preserved.

   The default Stage 23 L02 cap resolves to 1800 seconds, split as 900 seconds
   for legacy control and 900 seconds for the hybrid leg. This is enough to
   compare mode behavior inside the same row budget. Server startup overhead may
   still add wall-clock minutes, as with the previous single-leg L02 run, but
   the request windows stay bounded.

3. Legacy flag filtering is correct.

   The legacy leg removes hybrid-only Stage 23 flags:
   `--cache-mode hybrid`, `--cache-cold-max-mib`, `--cache-cold-path`,
   `--cache-prompt-evidence`, and `--cache-prompt-evidence-dir`. It keeps
   neutral execution flags such as CUDA, fit mode, model template, metrics, and
   cache RAM. The hybrid leg keeps the Stage 23 cold-budget and redacted
   evidence flags, so hybrid evidence is not hidden.

4. Dry-run evidence is enough for the focused L02 gate.

   Wrapper dry-run now prints the row cap split, both modes, comparison artifact,
   and filtered legacy flag classes. Direct child dry-run prints the same paired
   plan. Syntax checks passed for the child and wrapper.

5. Row gate checks the right artifacts.

   `Write-RowGate` still requires the common server logs and metrics for every
   row. It adds `l02-comparison.json` and `evidence-summary.md` only for L02, so
   S01..S08, L01, and L03 are not given L02-only artifact requirements.

6. Regression risk is bounded for this handoff.

   The L02 child uses `Port` and `Port + 1` for its two sequential legs. Focused
   L02 rerun with `BatchSize 1` is safe. L03 remains stopped and should not be
   batched with L02 in this focused rerun.

## Evidence checked

- Parser checks:
  - `longrun_s12_l02_30m_legacy_comparison.ps1`: PASS
  - `kickoff-stage20-stress-longrun.ps1`: PASS
- L02-only wrapper dry-run:
  - `DryRun OK; 1 rows; per-row flags present`
  - Side log includes `DryRun L02 comparison_plan rowCapSeconds=1800 legacy_control_seconds=900 hybrid_stage23_seconds=900 legacy_mode=legacy hybrid_mode=hybrid comparison_artifact=l02-comparison.json`.
- L02/L03 dry-run probe:
  - Confirms L02 and L03 are both still selectable by the wrapper.
  - Confirms L03 does not receive L02 artifact requirements.
  - Confirms focused rerun must stay L02-only, as requested.
- Developer smoke artifact:
  - `._test_output/stage23-l02-dev-smoke-child6/l02-comparison.json`
  - Status `PASS`, with `legacy-control` mode `legacy` and `hybrid-stage23`
    mode `hybrid`.
  - Root `evidence-summary.md` ended with `Result: PASS`.

## Required corrections

None for the focused L02 rerun.

## Handoff

Next owner: Manager.

Manager may open a focused L02 rerun with a fresh suffix, `RowsToRun @('L02')`,
and `BatchSize 1`. L03 remains stopped until L02 has a QA disposition.
