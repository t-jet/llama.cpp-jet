# Developer review: Stage 39 D39-QA-03

Date: 2026-07-17
Verdict: REWORK REQUIRED
Source: `test-report-20260717-03.md`

## Classification

| Item | Classification | Owner | Next action |
| --- | --- | --- | --- |
| TP-39-03 | QA harness gap | Developer | Correct the canonical driver's startup proof, then obtain Architect and Manager gates for one fresh canonical rerun. |
| Coverage | Deliberate fail-fast deferral | QA after Manager authorization | Run the four Part 149 blocks only after TP-39-03 passes. |

No Stage 39 product invariant was reached or violated. The clean build, both
shell parser checks, and both pure self-tests passed. Coverage correctly stayed
unopened after the first verdict-fixing blocker.

## Root cause

The driver requires the literal text `speculative decoding will use
checkpoints`. `server-context.cpp` emits that warning only when
`common_context_can_seq_rm(ctx_tgt)` returns
`COMMON_CONTEXT_SEQ_RM_TYPE_FULL`. It is not the success record for speculative
initialization and is not required for explicit context-checkpoint operation.

The fresh process instead emitted the current success record `speculative
decoding context initialized`. It also emitted the exact configured checkpoint
record `context checkpoints enabled, max = 32, min spacing = 0`, created live
context checkpoints, and logged two `tx_save` attempts with nonzero target and
draft sizes. The report diagnosis records all four facts and confirms that
`Assert-Tp3903` was not reached.

## Required correction

Developer owns a driver-only correction. Replace the obsolete
`speculative decoding will use checkpoints` predicate with a case-sensitive
literal check for `speculative decoding context initialized`. Keep the exact
checkpoint configuration predicate and the existing operational checkpoint
creation predicate. Preserve the target-plus-draft save evidence and all
Part 43 proof-component checks.

Use fixed literal checks, not an alternation such as `speculative decoding.*`,
a warning/success fallback, or a timed wait. The old warning must not remain an
accepted alternative because it proves a sequence-removal category, not a
successfully initialized speculative context. Do not change product logging,
fixture, argv, workload, caps, seam, test plan, or thresholds.

Extend the PowerShell 7 and Windows PowerShell 5 pure self-test matrix with the
fresh exact success marker as PASS and the old warning alone as FAIL. Preserve
the startup-log artifact before validation.

## Retest gate

After fresh Architect review and Manager authorization, QA must run the cheap
PowerShell 7/5 parser and pure checks, then exactly one bounded canonical
TP-39-03 node. TP-39-03 passes only if `Assert-Tp3903` completes with all Part
43 artifacts. Only that PASS opens the four ordered Part 149 coverage blocks,
including both forced exit-23 negatives and the 80 percent requirements.

No fix, test, build, model, or coverage command ran during this review.
