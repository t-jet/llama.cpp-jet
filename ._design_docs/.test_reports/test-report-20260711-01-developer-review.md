# Stage 38 Developer test-results review

Date: 2026-07-11
Owner: Developer
Source report: [test-report-20260711-01.md](test-report-20260711-01.md)
Verdict: REWORK

## Scope

This review classifies the Stage 38 QA execution failure. No code was changed.
No commit, push, staging, or revert was performed.

Reviewed sources:

- `._design_docs/document-index.md`
- `._design_docs/cache-handling-phase38-implementation.md`
- `._design_docs/cache-handling-phase38-implementation/part-11-manager-test-plan-gate-20260711.md`
- `._design_docs/cache-handling-test-plan/part-42-stage38-prefix-restore-cold-budget.md`
- `._design_docs/.test_reports/test-report-20260711-01.md`
- `._test_output/stage38-prefix-restore-20260711-01/turn1-request.json`
- `._test_output/stage38-prefix-restore-20260711-01/turn1.json`
- `._test_output/stage38-prefix-restore-20260711-01/turn2-request.json`
- `._test_output/stage38-prefix-restore-20260711-01/turn2.json`
- `._test_output/stage38-prefix-restore-20260711-01/turn2-apply-template.json`
- `._test_output/stage38-prefix-restore-20260711-01/turn2-tokenize.json`
- `._test_output/stage38-prefix-restore-20260711-01/metrics-pre.txt`
- `._test_output/stage38-prefix-restore-20260711-01/metrics-post.txt`
- `._test_output/stage38-prefix-restore-20260711-01/server.err.log`

## Summary

The required live Stage 38 row did not pass, but the current evidence does not
prove a product restore bug. The live driver did not prove that turn 1 was a
strict rendered-token prefix of turn 2. Turn 2 inserts a synthetic assistant
message, `ok.`, instead of the actual turn 1 assistant output. With the Qwen
chat template, that changes the rendered prompt shape at the assistant turn.

The next action is a QA-owned script correction and focused live retest. If the
corrected workload proves strict rendered-token prefix compatibility and still
gets `cached_tokens=0`, the failure should return to Developer as a product bug
in live chat prefix selection or checkpoint-safe candidate handling.

## Failure classification

| Finding | QA row or subcheck | Evidence | Classification | Owner | Root-cause hypothesis | Exact retest scope |
| --- | --- | --- | --- | --- | --- | --- |
| F38-QA-01 | TP-38-PR-02 live suffix turn | `turn2.json` reports `usage.prompt_tokens_details.cached_tokens=0`, `timings.cache_n=0`, `prompt_tokens=59`; `server.err.log` records `record_restore_miss: reason=token_count_mismatch` after turn 1 saved 44 tokens. | Test bug / inconclusive product signal. Not acceptable as PASS, but not enough to assign product bug. | QA for script correction; Developer only if corrected retest still fails. | The script uses `assistant: "ok."` in `turn2-request.json` instead of replaying the actual turn 1 assistant message. The rendered `turn2-apply-template.json` therefore is not proven to contain turn 1's rendered prompt as a strict token prefix. Product correctly falls back when strict-prefix proof is absent. | Re-run only the Stage 38 live script after fixing the workload. The corrected evidence must include turn1 rendered prompt/token proof, turn2 rendered prompt/token proof, a machine check that turn1 prompt tokens are a strict prefix of turn2 request tokens, `usage.prompt_tokens_details.cached_tokens > 0`, `timings.cache_n == cached_tokens`, full `usage.prompt_tokens == rendered_request_tokens`, positive `llamacpp:cache_hits_total{mode="hybrid"}` delta, and prefix candidate metric rows. |
| F38-QA-02 | TP-38-PR-02-hit | `metrics-pre.txt` and `metrics-post.txt` keep `llamacpp:cache_hits_total{mode="hybrid"} 0`. | Dependent failure from F38-QA-01. | QA first; Developer if corrected strict-prefix workload still has zero hit delta. | No accepted restore occurred because the live workload did not prove a valid strict-prefix candidate. | Same focused live retest as F38-QA-01; no separate broad suite needed unless corrected retest exposes a product hit-accounting mismatch after a nonzero cached-token response. |
| F38-QA-03 | TP-38-PR-02-prefix-metric | `metrics-post.txt` has only `cache_prefix_candidates_total{mode="hybrid",result="none",reason="none"} 0`; no accepted or bounded rejected prefix row. | Dependent observability failure from F38-QA-01, with one follow-up check. | QA first; Developer if corrected workload still records no prefix candidate row. | Because the request was not proven to be a valid strict-prefix workload, the missing accepted row follows from no accepted restore. If a corrected strict-prefix workload still produces only `token_count_mismatch` and no prefix candidate row, suspect product prefix-selection or bounded-observability routing after exact restore misses. | Same focused live retest as F38-QA-01. Preserve `server.err.log` and full `/metrics` before and after turn 2. |

## Passing rows

The following QA rows remain accepted as PASS and do not need rerun unless the
fix changes their covered code or Manager asks for a full gate rerun:

- Clean Release configure/build.
- Direct focused controller binary.
- `ctest -R cache`.
- Python cache-mode metric/schema regression.
- TP-38-PR-01.
- TP-38-PR-03 through TP-38-PR-10.
- TP-38-MET-01 and TP-38-MET-02.
- Script cleanup.

Cold-budget gauge evidence is accepted. `metrics-post.txt` reports
`llamacpp:cache_cold_budget_bytes{mode="hybrid"} 2147483648`, and the focused
controller boundary tests passed.

## Next action

QA should correct `stage38-prefix-restore-and-cold-budget.ps1` so the live
request pair proves strict rendered-token prefix compatibility. The retest can
be narrow:

1. Fresh Release `llama-server` binary or stale-binary proof satisfying the
   active Stage 38 plan.
2. Corrected model-backed Stage 38 script only.
3. Preserve raw turn1 and turn2 requests, responses, rendered templates,
   tokenization outputs, metrics snapshots, script report, console log, and
   `server.err.log`.

Developer should not change product code from this report alone. Product-code
investigation starts only if the corrected strict-prefix live retest still
fails.

## Gate recommendation

Current gate: REWORK.

Next owner: QA.

Next gate: focused Stage 38 live retest after script/workload correction.
