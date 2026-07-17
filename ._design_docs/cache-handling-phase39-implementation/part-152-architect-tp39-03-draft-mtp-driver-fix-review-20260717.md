# Part 152: Architect TP-39-03 draft-MTP driver fix review

Date: 2026-07-17
Verdict: REWORK REQUIRED
Scope: Part 151 and the D39-QA-02 driver fix

## Review

The canonical `both-filled` argv inserts one adjacent
`--spec-type draft-mtp` pair after `--chat-template-file` and excludes it from
the other six scenarios. The driver writes all four linked and explicit proof
request/response artifacts before component validation. Recursive redaction
removes snapshot tokens, proof tokens, and terminal HMACs. The deliberate zero
draft-component case preserves the four files and reaches the expected
`SKIP-preflight-tp39-03-proof-component` failure.

PowerShell 7 and Windows PowerShell 5 parser checks report zero errors. Both
pure self-tests exit 0. No model, build, coverage, product, fixture, seam, or
test-plan work ran in this review.

## Blocking findings

| ID | Finding | Required correction |
| --- | --- | --- |
| F152-01 | `common/arg.cpp` registers `-md` as an alias of `--spec-draft-model`, but `Assert-Stage39FinalSpecArgsS39` rejects only the two long forms. Canonical argv containing `-md <file>` therefore passes the guard beside the required draft-MTP selector. This violates Part 46's no-separate-draft-model rule and Part 150's alias rejection requirement. | Reject `-md` and add an isolated pure negative. Require the chat-template option and exact selector placement instead of accepting a selector when the template option is absent. |
| F152-02 | The live path rejects `LLAMA_ARG_SPEC_TYPE`, but the pure self-test exits before that check and does not test an environment override. It also permits `LLAMA_ARG_SPEC_DRAFT_MODEL`, which can inject the separate draft model that Part 46 forbids. | Put both canonical environment checks in a pure helper, reject both variables for `both-filled`, and add save/set/assert/restore negatives in both shells. Leave other scenarios unchanged. |

## Handoff

Developer owns the two driver-only corrections and updated pure evidence. Fresh
Architect re-review follows. Canonical TP-39-03 and coverage remain blocked.
