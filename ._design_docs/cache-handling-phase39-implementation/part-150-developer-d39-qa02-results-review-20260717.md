# Part 150: Developer D39-QA-02 results review

Date: 2026-07-17
Status: REWORK REQUIRED
Scope: QA report 20260717-02, TP-39-03, and deferred coverage

## Verdict

Full review:
`../.test_reports/test-report-20260717-02-developer-review.md`

The canonical driver starts the MTP-capable GGUF without
`--spec-type draft-mtp`. Runtime therefore creates target-context checkpoints
and a linked checkpoint descriptor, but no MTP draft context. Both ordered
proof rows are target-only with `runtime_has_draft=false` and zero draft bytes.
This exactly triggers `SKIP-preflight-tp39-03-proof-component`.

Product proof expansion, request fields, response fields, and the driver's
positive component validator match Part 43. No product invariant was tested or
violated. Coverage remains an acceptable Part 149 fail-fast deferral.

## Correction

Developer owns a bounded canonical-driver correction:

1. Add exactly one adjacent `--spec-type`, `draft-mtp` pair to the both-filled
   server argv and assert the final command contains it.
2. Keep the fixture, requests, budgets, caps, proof schema, validator, seam,
   product code, test plan, and coverage threshold unchanged.
3. Preserve redacted bootstrap and explicit proof requests and responses before
   validation, including on preflight failure.
4. Extend pure self-tests for selector presence and proof-artifact preservation
   on a deliberate component failure.

## Next gate

Fresh Architect review follows the driver correction. Manager then authorizes
one bounded canonical TP-39-03 rerun. Only a PASS opens the four Part 149
coverage blocks. No fix, test, model, build, or coverage command ran here.
