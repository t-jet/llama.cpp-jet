# Stage 23 execution plan review gate 01

Status: REWORK
Date: 2026-06-20
Stage: 23 (Full S/L Matrix Execution)
Reviewer: QA
Reviewed document: [../cache-handling-phase23-implementation.md](../cache-handling-phase23-implementation.md)
Scope: independent execution-plan review only. No matrix execution, product edits, or script edits.

## Verdict

REWORK.

QA execution may not start. The plan depends on wrapper behavior that does not
match the current scripts closely enough to prove the Stage 23 evidence
contract.

## Review inputs

- [Stage 23 implementation plan](../cache-handling-phase23-implementation.md)
- [Stage 23 design](../cache-handling-phase23-design.md)
- [Stage 23 design review gate 01](../cache-handling-phase23-design/part-01-design-review-gate-01.md)
- [Document index](../document-index.md)
- `AGENTS.md`
- `.agents/skills/qa/SKILL.md`
- High-level wrapper check:
  `../cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- S/L script interface spot checks:
  `stress/stress_s12_s01_budget_exhaustion.ps1`
  and `longrun/longrun_s12_l03_2h_mixed_workload.ps1`

## Findings

### F-23-PLAN-01: live wrapper launches do not pass the Stage 17 hook flags

Severity: BLOCKING

The plan accepts wrapper dry-run only if every row includes
`--cache-mode hybrid`, `--cache-cold-max-mib 512`,
`--cache-prompt-evidence redacted`, and `--cache-prompt-evidence-dir`
(implementation plan lines 159-179). The wrapper builds those strings for
dry-run logging, but the live child `Start-Process` argument list only passes
`-BuildDir`, `-OutDir`, `-Port`, `-MtpVariant`, `-JinjaVariant`, and duration
fields to the row scripts (wrapper lines 205-218). It does not append the
computed Stage 20 flags to the child command.

The row scripts also do not expose parameters for `CachePromptEvidence`,
`CachePromptEvidenceDir`, or `CacheColdMaxMib`. The S01 spot check shows only
`BuildDir`, `ModelPath`, `OutDir`, `Port`, duration, hot budget, parallelism,
seed, cold toggle, MTP, jinja, and dry-run parameters (S01 lines 8-20), and its
server flags lack prompt evidence and cold max fields (S01 lines 55-58). A repo
search found no `cache-prompt-evidence` or `cache-cold-max-mib` strings in the
S/L row scripts.

Impact: the planned dry-run can pass while live rows do not run with redacted
prompt evidence or the bounded cold budget required by Stage 23 design lines
183-192 and 201-221. That would make later execution evidence unusable.

Required correction: either revise the execution plan to include a reviewed
wrapper/script readiness fix before execution, or document a Manager-approved
alternate evidence contract that does not rely on those flags.

### F-23-PLAN-02: the required Qwen3.5-4B-MTP fixture is verified but not used

Severity: BLOCKING

The Stage 23 design requires the Qwen3.5-4B-MTP fixture before execution
(design lines 45-47). The plan verifies
`._test_models/Qwen3.5-4B-MTP-GGUF/` in preflight (implementation plan lines
98-109), but the live wrapper command does not pass a model path into child row
scripts (wrapper lines 205-218).

The S01 row script defaults to
`._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf` when `ModelPath` is not
provided (S01 lines 38-42). L03 has the same default pattern (L03 lines 41-45).

Impact: the plan can satisfy preflight while executing against a different
fixture than the one required by Stage 23.

Required correction: the plan must show how the accepted MTP fixture reaches
every live row, or it must record a Manager-approved fixture change before QA
execution.

### F-23-PLAN-03: row evidence is written under the durable report tree

Severity: BLOCKING

The Stage 23 design separates the durable report from non-durable row output:
the durable report belongs in `._design_docs/.test_reports/`, while row output
belongs under `._test_output/` (design lines 172-192). The plan also declares a
non-durable root under `._test_output/stage23-sl-matrix-YYYYMMDD-NN/`
(implementation plan lines 56-75).

The current wrapper hard-codes its row root as
`._design_docs\.test_reports\stage20-stress-$dateTag` (wrapper lines 47-49),
then writes each row directory under that root (wrapper lines 190-193). The plan
notes that the wrapper creates its own timestamped roots, but it does not turn
that into a gating correction. It only says the execution owner must copy or
reference the wrapper-created evidence (implementation plan lines 69-71).

Impact: a multi-hour run would put large non-durable row artifacts in the
durable report directory and would not follow the Stage 23 evidence layout.

Required correction: the plan needs a reviewed artifact-routing decision before
execution. Copying or referencing the wrong root after the run does not fix the
durable/non-durable split.

### F-23-PLAN-04: per-batch and per-row gates are underspecified

Severity: BLOCKING

The design requires pre-batch checks for stale `llama-server` processes, port
availability, cold/evidence writability, disk space, and wrapper dry-run
evidence for selected rows (design lines 143-149). It also requires cleanup
after every row: terminate child processes, wait and record exit code, capture
final metrics when responsive, preserve row evidence, and clear cold path
unless resuming (design lines 164-170).

The plan records one preflight check before execution and says disk must be
checked before each batch (implementation plan lines 124-137), but it does not
provide a repeatable per-batch command/checklist or a per-row cleanup evidence
check. Its live commands launch all stress rows in one wrapper invocation and
all longrun rows in another (implementation plan lines 181-209), which leaves
the design's before-every-batch and after-every-row gates to operator memory.

Impact: if a later row inherits a stale process, dirty cold path, missing final
metrics, or insufficient disk space, the execution report may not be able to
separate setup failure from product behavior.

Required correction: add explicit per-batch and per-row evidence gates to the
plan, or cite wrapper-side evidence that proves those gates already run and are
reported.

## Non-blocking notes

- The fixed two-row batching rule itself is present in the wrapper:
  `$batchSize = 2` and batch iteration appear at wrapper lines 178-188.
- The plan correctly keeps execution blocked until Manager accepts it.
- The plan correctly carries the stress 1000 hits+misses threshold and longrun
  stated-intent rule from the Stage 23 design.

## QA execution gate

QA execution may start: NO.

Needed before execution:

- Resolve all blocking findings above.
- Re-review the revised execution plan.
- Obtain Manager acceptance after the plan review passes.

This review used plain ASCII text and stays under the 300-line durable-doc cap.
