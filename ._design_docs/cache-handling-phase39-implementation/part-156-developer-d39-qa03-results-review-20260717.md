# Part 156: Developer D39-QA-03 results review

Date: 2026-07-17
Status: REWORK REQUIRED
Scope: QA report 20260717-03, TP-39-03, and deferred coverage

## Verdict

Full review:
`../.test_reports/test-report-20260717-03-developer-review.md`

TP-39-03 is blocked by a QA harness gap. The driver requires `speculative
decoding will use checkpoints`, but that source record is conditional on
`COMMON_CONTEXT_SEQ_RM_TYPE_FULL`; it is not the speculative-init success
record. The fresh server emitted `speculative decoding context initialized`,
the exact checkpoint configuration, live checkpoint creation, and two
target-plus-draft saves with nonzero draft bytes. No product invariant was
reached or violated.

Coverage is an accepted fail-fast deferral. Part 155 required the session to
stop at this first blocker, so no coverage defect or percentage exists.

## Correction and retest

Developer owns one driver-only correction: replace the stale predicate with a
case-sensitive literal check for `speculative decoding context initialized`.
Keep the exact checkpoint configuration, operational creation, target/draft,
proof, fixture, cap, seam, and threshold requirements. Add PowerShell 7/5 pure
negatives proving that the old warning alone cannot pass. Do not use a broad
regex, an either-marker fallback, or timing-based acceptance.

Fresh Architect review follows. Manager must then authorize one canonical
TP-39-03 rerun. Only a complete `Assert-Tp3903` PASS opens the four Part 149
coverage blocks. No fix, test, build, model, or coverage command ran here.
