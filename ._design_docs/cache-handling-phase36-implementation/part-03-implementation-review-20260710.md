# Part 03: Implementation review

Date: 2026-07-10
Stage: 36
Reviewer: Architect
Verdict: REWORK

## Scope

Reviewed Stage 36 implementation against the approved design and implementation
plan.

## Finding

F36-IMPL-01: The touched script README carried conflicting public metric names.

Stage 36 design and the comparison driver require current colon-form metrics
such as `llamacpp:cache_hits_total{mode="hybrid"}`. The README's new Stage 36
section used that form, but older rows in the same touched file still listed
underscore-form metrics such as `llamacpp_cache_hits_total`. That left QA with
two incompatible metric contracts.

## Required correction

Update README metric references so current public evidence uses colon-form
`llamacpp:cache_*` names, or clearly mark underscore-form rows as historical
and not current QA evidence for this driver.

## Non-blocking note

`FillerCount` accepted any non-negative value while the design bounds optional
filler at 0 to 48. Tightening the cap is recommended.
