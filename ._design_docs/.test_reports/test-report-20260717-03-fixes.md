# Stage 39 D39-QA-03 fixes

Date: 2026-07-17
Status: ARCHITECT PASS; MANAGER RERUN GATE NEXT
Source: `test-report-20260717-03-developer-review.md`

## Plan

1. Replace the stale startup warning predicate with an ordinal check for
   `speculative decoding context initialized`.
2. Keep the exact checkpoint configuration, live checkpoint creation, and two
   nonzero target-plus-draft proof rows.
3. Add pure positive and negative checks, then run only the PowerShell 7 and 5
   parser APIs and self-tests.

## Correction

`stage39-two-layer-pressure.ps1` now uses one startup-proof helper for the live
gate and pure tests. It requires these case-sensitive literals:

- `speculative decoding context initialized`
- `context checkpoints enabled, max = 32, min spacing = 0`
- `created context checkpoint`

The old warning is not an alternative. Pure negatives reject the old warning
alone, a broad-regex-shaped substitute, an old/new fallback with wrong case,
timing-only readiness, missing checkpoint configuration, and missing live
checkpoint creation. Existing prepared-proof validation still requires two
rows with nonzero target and draft sizes.

## Evidence

| Check | Result |
| --- | --- |
| PowerShell 7 parser API | PASS, zero errors |
| Windows PowerShell 5 parser API | PASS, zero errors |
| PowerShell 7 `-MetricValidationSelfTest` | PASS, exit 0 |
| Windows PowerShell 5 `-MetricValidationSelfTest` | PASS, exit 0 |

No model, build, coverage, product, fixture, seam, plan, or threshold command
ran during the correction. Part 158 records Architect PASS; Manager
authorization remains required before a canonical rerun.

## Architect fix review

Part 158 verdict: PASS. The live gate uses one ordinal helper for the exact
speculative-init, checkpoint-config, and checkpoint-creation literals. The old
warning is not accepted. Existing prepared-binding checks still require two
ordered same-owner records with nonzero target and draft bytes.

The old-only, broad-regex-shaped, wrong-case fallback, timing-only,
missing-config, and missing-creation negatives each omit or corrupt a required
literal and therefore fail closed. Fresh PowerShell 7/5 parser checks returned
zero errors; both pure self-tests returned PASS and exit 0. Manager owns the
bounded canonical TP-39-03 rerun gate. Coverage remains closed until that node
passes. No prohibited action ran.
