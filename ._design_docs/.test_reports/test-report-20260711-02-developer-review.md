# Stage 38 Developer corrected-retest review

Date: 2026-07-12
Owner: Developer
Source report: [test-report-20260711-02.md](test-report-20260711-02.md)
Verdict: FAIL, product bug opened

## Scope

This review classifies the corrected Stage 38 QA retest. No code was changed.
No commit, push, staging, or revert was performed.

Reviewed sources:

- `._design_docs/document-index.md`
- `._design_docs/.test_reports/test-report-20260711-02.md`
- `._design_docs/.test_reports/test-report-20260711-01-developer-review.md`
- `._design_docs/cache-handling-phase38-implementation.md`
- `._design_docs/cache-handling-phase38-design.md`
- `._design_docs/cache-handling-phase38-design/part-01-prefix-checkpoint-partial-restore.md`
- `._design_docs/cache-handling-phase38-design/part-03-observability-and-tests.md`
- `._design_docs/cache-handling-test-plan/part-42-stage38-prefix-restore-cold-budget.md`
- `._test_output/stage38-prefix-restore-20260711-02-attempt5/turn1-request.json`
- `._test_output/stage38-prefix-restore-20260711-02-attempt5/turn1.json`
- `._test_output/stage38-prefix-restore-20260711-02-attempt5/turn1-tokenize.json`
- `._test_output/stage38-prefix-restore-20260711-02-attempt5/turn2-request.json`
- `._test_output/stage38-prefix-restore-20260711-02-attempt5/turn2.json`
- `._test_output/stage38-prefix-restore-20260711-02-attempt5/turn2-tokenize.json`
- `._test_output/stage38-prefix-restore-20260711-02-attempt5/metrics-pre.txt`
- `._test_output/stage38-prefix-restore-20260711-02-attempt5/metrics-post.txt`
- `._test_output/stage38-prefix-restore-20260711-02-attempt5/server.err.log`
- Live code anchors in `tools/server/server-cache-hybrid.cpp` and
  `tools/server/server-cache-hybrid.h` for restore selection, checkpoint
  payload choice, and strict-prefix validation.

## Summary

The corrected QA retest closes the prior script/workload gap. The raw token
artifacts show turn 1 is a strict rendered-token prefix of turn 2:

- turn 1 request token count: `35`
- turn 1 response total token count: `43`
- turn 2 rendered request token count: `63`
- first mismatch for both prefix checks: `-1`

The live server still returns no cache reuse for the suffix turn:

- `usage.prompt_tokens_details.cached_tokens=0`
- `timings.cache_n=0`
- `usage.prompt_tokens=63`
- `llamacpp:cache_hits_total{mode="hybrid"}` delta `0`
- `cache_prefix_candidates_total{result="rejected",reason="prefix_restore_deferred"} 1`
- `cache_restore_misses_total{reason="unsafe_prefix_rejected",profile="checkpoint_dependent",pair_state="target_only"} 1`

This is now a product bug in the Stage 38 live chat prefix restore path, not a
QA workload issue.

## Failure classification

| Finding | QA row or subcheck | Evidence | Classification | Owner | Likely root cause | Exact fix scope | Exact retest scope |
| --- | --- | --- | --- | --- | --- | --- | --- |
| F38-QA-04 | TP-38-PR-02-prefix-proof | `turn1-tokenize.json` has 35 tokens; `turn2-tokenize.json` starts with the same 35 tokens and extends to 63 tokens. QA report also records assistant-replay prefix proof at 43/63 with mismatch `-1`. | PASS, accepted prerequisite. | None. | Prior report -01 workload bug is closed. The corrected run replays actual turn 1 assistant output and uses a stable ChatML template. | No fix. Preserve this proof shape for retest. | Include the same raw request, response, apply-template, tokenize, and prefix mismatch artifacts in the fix retest. |
| F38-QA-05 | TP-38-PR-02-live | `turn2.json` reports `cached_tokens=0`, `timings.cache_n=0`, `prompt_tokens=63`, `prompt_n=63`. `server.err.log` shows first turn saved, second turn selected the prior slot by LCP similarity, then rejected restore as `unsafe_prefix_rejected`. | Product bug, gate blocking. | Developer. | The live model is classified `checkpoint_dependent`; the selected strict-prefix candidate appears to be an exact-blob/live-slot prefix rather than a checkpoint payload. The Stage 38 safety gate correctly rejects non-checkpoint prefixes for checkpoint-dependent profiles, but the live positive row needs a checkpoint-safe payload to be admitted and selected for the proven chat prefix. Likely fault is checkpoint payload admission, checkpoint metadata snapshotting from the live chat save path, or restore selection choosing/reaching only the exact payload for a prefix candidate. | Open `._design_docs/.test_reports/test-report-20260711-02-fixes.md`. Diagnose `tx_save` checkpoint capture/admission (`slot.prompt.checkpoints`, `admit_latest_checkpoint_and_store_metadata`), branch metadata sync, `select_restore_candidate`, `find_prefix_candidate`, `select_restore_payload_kind`, and `validate_strict_prefix_candidate`. Fix so checkpoint-dependent chat strict-prefix candidates restore from checkpoint-safe payloads when one is available, while arbitrary exact-blob prefixes still recompute. Add focused regression coverage that drives the production restore transaction, not only the validator hook. | Rebuild focused targets, run `test-cache-controller.exe`, `ctest -R cache`, and the corrected Stage 38 live script. The live suffix row must show `cached_tokens > 0`, `timings.cache_n == cached_tokens`, `prompt_tokens == 63`, positive hybrid hit delta, and accepted prefix metric row. Preserve `server.err.log` and full metrics snapshots. |
| F38-QA-06 | TP-38-PR-02-hit | Metrics stay `llamacpp:cache_hits_total{mode="hybrid"} 0` before and after turn 2. | Dependent product failure from F38-QA-05. | Developer. | No restore was applied because F38-QA-05 rejected the prefix before payload apply. | Same fix as F38-QA-05. Do not patch hit accounting in isolation unless a later retest shows an accepted restore with zero hit delta. | Same corrected live script retest. Assert positive `cache_hits_total{mode="hybrid"}` delta after turn 2. |
| F38-QA-07 | TP-38-PR-02-prefix-metric | Metrics have rejected row `cache_prefix_candidates_total{mode="hybrid",result="rejected",reason="prefix_restore_deferred"} 1`; no accepted row. | Dependent product failure from F38-QA-05. | Developer. | Product selected a prefix candidate but rejected it as unsafe for the checkpoint-dependent path. Observability is bounded and useful; the failure is the missing accepted checkpoint-safe restore, not metric absence. | Same fix as F38-QA-05. Keep rejected metric behavior for unsafe candidates. Add/assert accepted metric on successful checkpoint-safe prefix restore. | Same corrected live script retest. Require `cache_prefix_candidates_total{result="accepted",reason="accepted_strict_prefix"}` or equivalent accepted Stage 38 row after suffix turn. |

## Accepted passing rows

These rows stay accepted and should not be rerun unless the fix touches their
covered code or Manager asks for a broader gate:

- Clean Release configure/build evidence from report -02.
- Corrected setup and cleanup rows.
- TP-38-PR-02 prefix-proof prerequisite.
- TP-38-MET-01 live cold-budget gauge: `2147483648`.
- Prior focused controller, `ctest -R cache`, Python schema, TP-38-PR-01, and
  TP-38-PR-03 through TP-38-PR-10 rows from report -01 remain accepted except
  where the fix changes shared restore selection or checkpoint admission.

## Bug-fix loop

Developer bug-fix loop is now open.

Fix report path:
`._design_docs/.test_reports/test-report-20260711-02-fixes.md`

Minimum fix-report content:

- root cause in live chat checkpoint-dependent prefix restore;
- code and test changes with file anchors;
- regression coverage proving checkpoint-safe prefix restore and exact-blob
  unsafe-prefix recompute both still hold;
- focused build/test evidence;
- corrected live script retest evidence using the same strict-prefix proof
  shape as attempt5.

## Gate recommendation

Current gate: FAIL, product bug opened.

Next owner: Developer.

Next gate: Developer bug-fix loop, then Architect or Developer fix review per
Manager routing, then focused QA retest of TP-38-PR-02 live/hit/prefix-metric
plus any rows touched by the fix.
