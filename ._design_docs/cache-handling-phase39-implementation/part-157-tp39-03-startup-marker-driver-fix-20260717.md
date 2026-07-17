# Part 157: TP-39-03 startup-marker driver fix

Date: 2026-07-17
Status: READY FOR ARCHITECT REVIEW

## Change

The canonical driver now accepts only the case-sensitive success literal
`speculative decoding context initialized`. The obsolete
`speculative decoding will use checkpoints` warning no longer satisfies the
startup gate.

The same ordinal helper also retains the exact checkpoint configuration and
live checkpoint creation requirements. Existing prepared-proof checks still
require exactly two same-owner payload rows and reject zero target or draft
sizes. No broad regex, old/new fallback, or timing-only path can satisfy the
startup proof.

## Pure regression evidence

PowerShell 7 and Windows PowerShell 5 parser APIs returned zero errors. Both
`-MetricValidationSelfTest` runs returned PASS. Their matrix covers the exact
positive record plus old-warning-only, broad-regex-shaped, wrong-case fallback,
timing-only, missing-config, and missing-creation negatives.

No model, build, coverage, product, fixture, seam, plan, or threshold command
ran. Architect review is next. A live rerun remains blocked on a later Manager
gate.
