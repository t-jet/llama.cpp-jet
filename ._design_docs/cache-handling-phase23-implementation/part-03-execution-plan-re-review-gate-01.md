# Stage 23 execution plan re-review gate 01

Status: REWORK
Date: 2026-06-20
Stage: 23 (Full S/L Matrix Execution)
Reviewer: QA
Reviewed documents: [../cache-handling-phase23-implementation.md](../cache-handling-phase23-implementation.md), [part 2](part-02-execution-plan-rework-corrections.md)
Scope: independent execution-plan re-review only. No full matrix execution or product code edits.

## Verdict

REWORK.

The original four QA review findings are resolved by the corrected wrapper,
row-script interface, plan commands, and dry-run evidence. QA execution still
must not start because L01..L03 have a known evidence contract gap: the Stage
23 plan and wrapper row gate require `metrics-before.txt`, but the three
longrun row scripts do not create that file.

## Review inputs

- [Document index](../document-index.md)
- [Stage 23 design](../cache-handling-phase23-design.md)
- [Stage 23 design review gate 01](../cache-handling-phase23-design/part-01-design-review-gate-01.md)
- [Stage 23 implementation plan](../cache-handling-phase23-implementation.md)
- [Stage 23 execution plan review gate 01](part-01-execution-plan-review-gate-01.md)
- [Stage 23 REWORK corrections](part-02-execution-plan-rework-corrections.md)
- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `._design_docs/cache-handling-test-scripts/lib/Get-Stage17ServerArgs.ps1`
- all 8 scripts under `._design_docs/cache-handling-test-scripts/stress/`
- all 3 scripts under `._design_docs/cache-handling-test-scripts/longrun/`

## Checks performed

- Syntax parse: wrapper, helper, 8 stress scripts, and 3 longrun scripts all
  parsed successfully.
- Wrapper dry-run: all 11 rows exited dry-run with code 0 and printed
  `DryRun OK; 11 rows; per-row flags present`.
- Child dry-runs: S01..S08 and L01..L03 all exited 0 when called with
  `-Stage17ServerArgsBase64`, Qwen3.5 MTP model path, `._test_output` output
  roots, ports 8800..8810, MTP variant 1, and marked jinja.
- Static row-script check: all 11 row scripts accept `Stage17ServerArgsBase64`,
  import `Get-Stage17ServerArgs.ps1`, append decoded args to server flags, and
  accept `ModelPath`, `OutDir`, and `Port`.
- Document cap check: Stage 23 design is 269 lines, implementation entry is
  290 lines, part 01 is 152 lines, and part 02 is 151 lines.

## Original findings

| Finding | Re-review result | Evidence |
| --- | --- | --- |
| F-23-PLAN-01 live wrapper launches do not pass Stage 17 hook flags | RESOLVED | Wrapper builds reviewed flags, encodes them, passes `-Stage17ServerArgsBase64`, and every row script appends decoded args to live server flags. Wrapper dry-run showed `--cache-mode hybrid`, `--cache-cold-max-mib 512`, `--cache-ram 512`, `--cache-cold-path`, `--cache-prompt-evidence redacted`, and `--cache-prompt-evidence-dir` for all 11 rows. |
| F-23-PLAN-02 Qwen3.5 MTP fixture verified but not used | RESOLVED | Wrapper now accepts `-ModelPath`, defaults to the Qwen3.5 MTP fixture when unset, and passes `-ModelPath` to every row. Dry-run side log showed the Qwen3.5 path for all rows. |
| F-23-PLAN-03 row evidence under durable report tree | RESOLVED | Wrapper now accepts `-RunRoot`, defaults to `._test_output`, and dry-run side log showed all row output under `._test_output/stage23-sl-matrix-qa-rereview-dryrun/<ROW>-Jnew/`. Plan keeps durable Markdown under `._design_docs/.test_reports/`. |
| F-23-PLAN-04 per-batch and per-row gates underspecified | RESOLVED for gating shape | Wrapper now writes `batch_gate`, `launched`, and `row_gate` side-log records. Plan requires `-BatchSize 1`, cites side-log gates, and treats missing row gates or non-zero child exits as runner-contract blocks unless product evidence proves a failure. |

## Blocking finding

### F-23-REREVIEW-01: longrun rows cannot produce required before-metrics evidence

Severity: BLOCKING

The Stage 23 design and implementation plan both require per-row
`metrics-before.txt` and `metrics-after.txt` evidence. The corrected wrapper
also treats `metrics-before.txt` as a required row-gate file.

Static inspection shows all 8 stress scripts mention both `metrics-before.txt`
and `metrics-after.txt`, but all 3 longrun scripts mention only
`metrics-after.txt`:

- `longrun_s12_l01_6h_hybrid_stability.ps1`
- `longrun_s12_l02_30m_legacy_comparison.ps1`
- `longrun_s12_l03_2h_mixed_workload.ps1`

Impact: if QA starts Stage 23 now, L01..L03 are expected to fail the wrapper
row gate for missing before-metrics evidence after long execution time. That is
a known harness/evidence contract gap, not useful matrix evidence.

Required correction: before Manager opens QA execution, either update L01..L03
to capture `metrics-before.txt` before their workload starts, or revise the
Stage 23 evidence contract and wrapper row gate with a Manager-approved
longrun-specific substitute. The first option is preferred because the design
already requires before/after metrics for every row.

## Dry-run evidence assessment

Wrapper dry-run evidence is adequate for the corrected routing and flag
contract: all 11 rows, Qwen3.5 model path, `._test_output` row roots, redacted
prompt evidence flags, cold budget flags, and ports 8800..8810 are visible.

Child dry-run evidence is adequate for parameter binding: all 11 rows accepted
the corrected wrapper inputs and exited 0. It is not adequate to clear
F-23-REREVIEW-01 because dry-run does not create live metrics files.

## Execution gate decision

QA execution may start: NO.

Needed before execution:

- Fix or explicitly re-scope longrun before-metrics evidence.
- Re-run syntax parse and wrapper dry-run.
- Re-review the corrected plan or correction note.
- Obtain Manager acceptance after the re-review passes.

This review uses plain ASCII text and stays under the 300-line durable-doc cap.
