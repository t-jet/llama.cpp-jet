# Stage 39 D39-QA-02 driver fixes

Date: 2026-07-17
Status: ARCHITECT PASS; READY FOR QA RERUN
Source: `test-report-20260717-02-developer-review.md`

## Scope

Correct only the canonical TP-39-03 PowerShell driver and its pure self-test.
The fixture, requests, budgets, caps, proof schema, product code, seam, test
plan, coverage runner, and threshold do not change.

## Plan

1. Add the exact `--spec-type draft-mtp` pair only to `both-filled` server
   argv, reject duplicate selectors and aliases, and cover every scenario.
2. Save redacted linked and explicit proof requests and responses before proof
   component validation. Add a deliberate component-failure test that checks
   artifact survival and secret redaction.
3. Run PowerShell 7 and Windows PowerShell 5 parser checks and pure self-tests.
   Record exact results here and in implementation Part 151.

## Gate

No model, build, coverage, product, fixture, seam, test-plan, threshold, commit,
push, or PR action is authorized. Fresh Architect review follows this fix.

## Implementation

`stage39-two-layer-pressure.ps1` now binds `--spec-type draft-mtp` exactly once
and only for `both-filled`. Final argv validation rejects duplicates, aliases,
wrong placement, cross-scenario use, and a selector environment override.

The driver saves redacted linked and explicit proof requests and responses
before component validation. The artifact writer redacts snapshot tokens, proof
tokens, and terminal HMACs recursively, then scans the serialized result for
the original secrets. Explicit pair-ID derivation no longer requires positive
component sizes, so all four artifacts exist when the deliberate component
negative throws.

## Pure test evidence

| Command class | Result |
| --- | --- |
| PowerShell 7 parser API | PASS, 0 errors |
| Windows PowerShell 5 parser API | PASS, 0 errors |
| PowerShell 7 `-MetricValidationSelfTest` | PASS, exit 0 |
| Windows PowerShell 5 `-MetricValidationSelfTest` | PASS, exit 0 |

The self-test covers all seven scenarios, duplicate and alias negatives, wrong
selector placement, cross-scenario leakage, artifact survival after
`SKIP-preflight-tp39-03-proof-component`, and token/HMAC redaction.

No model, build, coverage, product, fixture, seam, test-plan, threshold, commit,
push, or PR action ran in the Developer correction.

## Architect fix review

Part 152 verdict: REWORK REQUIRED.

The argv guard misses the parser-supported `-md` alias and accepts the selector
when the required chat-template option is absent. The live environment check is
not reachable from the pure self-test and checks `LLAMA_ARG_SPEC_TYPE` only;
`LLAMA_ARG_SPEC_DRAFT_MODEL` can still inject a separate draft model. Developer
must close those driver-only gaps and rerun the two parser and pure shell checks.
Canonical TP-39-03 and coverage remain blocked.

## Part 152 rework

Status: ARCHITECT PASS; READY FOR QA RERUN

The final argv guard now rejects all parser-supported separate draft-model
spellings: `--spec-draft-model`, `-md`, and `--model-draft`, including equals
forms. `both-filled` also requires exactly one `--chat-template-file` argument,
a nonempty template value, and the adjacent `--spec-type draft-mtp` pair after
that value. A missing or duplicate template anchor fails closed.

A pure environment helper now rejects both speculative parser environment
sources for `both-filled`: `LLAMA_ARG_SPEC_TYPE` and
`LLAMA_ARG_SPEC_DRAFT_MODEL`. The live path uses the same helper. The self-test
saves both process variables, clears them, sets and rejects each override in
isolation, confirms other scenarios remain unchanged, and restores the original
presence and value in `finally`.

| Check | Result |
| --- | --- |
| PowerShell 7 parser API | PASS, 0 errors |
| Windows PowerShell 5 parser API | PASS, 0 errors |
| PowerShell 7 pure self-test | PASS, exit 0 |
| Windows PowerShell 5 pure self-test | PASS, exit 0 |

The existing proof-artifact and redaction code did not change. No model, build,
coverage, product, fixture, seam, test-plan, threshold, commit, push, or PR
action ran. Implementation Part 153 records the correction. Fresh Architect
re-review is next; canonical TP-39-03 and coverage remain blocked.

## Architect re-review

Part 154 verdict: PASS. F152-01 and F152-02 are closed. All supported separate
draft-model spellings and forms fail closed; the unique chat-template anchor
immediately precedes the exact selector. Both speculative environment sources
are rejected for `both-filled`, tests restore process environment, and other
scenarios remain clean. Proof artifact ordering and redaction are unchanged.

Fresh PowerShell 7/5 parser checks returned zero errors; both pure self-tests
returned PASS and exit 0. QA owns the bounded canonical TP-39-03 and coverage
rerun. No prohibited action ran.
