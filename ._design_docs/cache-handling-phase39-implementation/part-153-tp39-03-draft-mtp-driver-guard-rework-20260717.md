# Part 153: TP-39-03 draft-MTP driver guard rework

Date: 2026-07-17
Status: READY FOR ARCHITECT RE-REVIEW
Source: Part 152 and `../.test_reports/test-report-20260717-02-fixes.md`

## Correction

The final `both-filled` argv guard now rejects every separate draft-model alias
registered by `common/arg.cpp`: `--spec-draft-model`, `-md`, and
`--model-draft`. It rejects separated and equals forms. The existing `--mtp`
and `--spec-type=<value>` rejection remains.

The guard requires exactly one `--chat-template-file`, a nonempty value, and
one adjacent `--spec-type draft-mtp` pair after that value. Missing, duplicate,
or misplaced chat-template anchors fail closed. The canonical final argv can
therefore select local MTP only, without a separate draft model.

`Assert-Stage39SpecEnvironmentS39` rejects both parser environment sources for
`both-filled`: `LLAMA_ARG_SPEC_TYPE` and `LLAMA_ARG_SPEC_DRAFT_MODEL`. The live
path and pure self-test use the same helper. Other scenarios return unchanged.

## Pure regression evidence

The self-test covers all registered separate draft-model aliases, equals forms,
missing and duplicate template anchors, wrong placement, selector duplication,
and cross-scenario leakage. It saves both environment variables, tests each
override in isolation, checks the non-TP-39-03 path, and restores original
process values in `finally`.

| Check | Result |
| --- | --- |
| PowerShell 7 parser API | PASS, 0 errors |
| Windows PowerShell 5 parser API | PASS, 0 errors |
| PowerShell 7 pure self-test | PASS, exit 0 |
| Windows PowerShell 5 pure self-test | PASS, exit 0 |

Proof artifact ordering and recursive redaction remain unchanged. No model,
build, coverage, product, fixture, seam, test-plan, threshold, commit, push, or
PR action ran.

## Handoff

Fresh Architect re-review is next. Canonical TP-39-03 and coverage remain
blocked.
