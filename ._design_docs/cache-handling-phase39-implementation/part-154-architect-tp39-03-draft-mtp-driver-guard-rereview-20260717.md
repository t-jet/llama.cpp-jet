# Part 154: Architect TP-39-03 draft-MTP driver guard re-review

Date: 2026-07-17
Verdict: PASS
Scope: Part 153 closure of F152-01 and F152-02

## Review

F152-01 is closed. The guard rejects `--spec-draft-model`, `-md`, and
`--model-draft` in separated and equals forms. It requires one nonempty
`--chat-template-file` value immediately followed by the sole exact
`--spec-type draft-mtp` selector. Missing, duplicate, misplaced, aliased, and
cross-scenario forms fail in the pure negative matrix.

F152-02 is closed. One helper rejects `LLAMA_ARG_SPEC_TYPE` and
`LLAMA_ARG_SPEC_DRAFT_MODEL` for `both-filled`; live and pure paths use it.
Tests isolate both variables, keep other scenarios unchanged, and restore
original process presence and values in `finally`.

Proof artifact ordering and recursive token/HMAC redaction remain unchanged.
PowerShell 7 and Windows PowerShell 5 parser APIs returned zero errors. Both
pure self-tests returned PASS and exit 0. No model, build, coverage, product,
fixture, seam, test-plan, threshold, commit, push, or PR action ran.

## Handoff

PASS. QA may run the authorized bounded canonical TP-39-03 and coverage rerun.
