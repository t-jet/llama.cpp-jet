# Stage 38 implementation log: prefix/checkpoint partial restore and cold-budget gauge fix

Status: CLOSED PASS
Date: 2026-07-12
Stage: 38
Owner: Manager
Design baseline: [cache-handling-phase38-design.md](cache-handling-phase38-design.md)

## Scope

This log tracks Stage 38 implementation for the approved chat strict-prefix
partial restore and cold-budget gauge fix. The planning session did not touch
code. The implementation evidence session edited production code, focused
controller tests, and this implementation log only.

## Review status

- [Part 1: implementation-plan review 2026-07-11](cache-handling-phase38-implementation/part-01-implementation-plan-review-20260711.md)
  records PASS with no required corrections.
- [Part 2: Manager implementation-plan gate 2026-07-11](cache-handling-phase38-implementation/part-02-manager-implementation-plan-gate-20260711.md)
  records PASS and authorizes implementation without commits or pushes.
- [Part 3: implementation evidence 2026-07-11](cache-handling-phase38-implementation/part-03-implementation-evidence-20260711.md)
  records the code changes, focused controller tests, build evidence, direct
  test evidence, ctest evidence, and unresolved live/model-backed gaps.
- [Part 4: implementation review 2026-07-11](cache-handling-phase38-implementation/part-04-implementation-review-20260711.md)
  records REWORK for the first implementation review.
- [Part 5: implementation rework evidence 2026-07-11](cache-handling-phase38-implementation/part-05-implementation-rework-evidence-20260711.md)
  records the Developer rework.
- [Part 6: implementation re-review 2026-07-11](cache-handling-phase38-implementation/part-06-implementation-re-review-20260711.md)
  records PASS.
- [Part 7: Manager implementation gate 2026-07-11](cache-handling-phase38-implementation/part-07-manager-implementation-gate-20260711.md)
  records PASS and opens test planning.
- [Part 8: QA test-plan handoff 2026-07-11](cache-handling-phase38-implementation/part-08-qa-test-plan-20260711.md)
  records the test-plan and automation additions plus the QA correction for
  F38-TP-01 through F38-TP-03 after the REWORK review.
- [Part 9: test-plan review 2026-07-11](cache-handling-phase38-implementation/part-09-test-plan-review-20260711.md)
  records REWORK for missing live `timings.cache_n`, weak full prompt-token
  proof, and stale README metadata.
- [Part 10: test-plan re-review 2026-07-11](cache-handling-phase38-implementation/part-10-test-plan-re-review-20260711.md)
  records PASS after QA correction closed F38-TP-01 through F38-TP-03.
- [Part 11: Manager test-plan gate 2026-07-11](cache-handling-phase38-implementation/part-11-manager-test-plan-gate-20260711.md)
  records PASS and opens QA execution.
- QA report [test-report-20260711-01.md](.test_reports/test-report-20260711-01.md)
  records FAIL for the live TP-38-PR-02 suffix-turn row.
- Developer review [test-report-20260711-01-developer-review.md](.test_reports/test-report-20260711-01-developer-review.md)
  records REWORK: the live driver did not prove a strict rendered-token prefix,
  so QA owns a script/workload correction and focused live retest before any
  product-code fix.
- QA report [test-report-20260711-02.md](.test_reports/test-report-20260711-02.md)
  records the focused correction and retest. The corrected workload proves
  strict rendered-token prefix compatibility, but live chat prefix restore still
  returns zero cached tokens and is classified as a product-bug candidate.
- Developer review [test-report-20260711-02-developer-review.md](.test_reports/test-report-20260711-02-developer-review.md)
  records FAIL and opens the product bug-fix loop. Developer owns
  `._design_docs/.test_reports/test-report-20260711-02-fixes.md`, focused on
  checkpoint-dependent live chat strict-prefix restore selecting or admitting a
  checkpoint-safe payload instead of rejecting the proven prefix as
  `unsafe_prefix_rejected`.
- Developer fix report
  [test-report-20260711-02-fixes.md](.test_reports/test-report-20260711-02-fixes.md)
  records the checkpoint-span validator fix, controller regression, script
  metric-label-order correction, focused build/controller/ctest evidence, and
  live fix4 PASS with `cached_tokens=11`, `timings.cache_n=11`, full
  `prompt_tokens=63`, hybrid hit delta `1`, accepted prefix metric, checkpoint
  hit metrics, and cold-budget gauge `2147483648`.
- Architect fix re-review
  [test-report-20260711-02-fix-re-review.md](.test_reports/test-report-20260711-02-fix-re-review.md)
  records PASS for the checkpoint-span prefix validator fix.
- QA post-fix retest
  [test-report-20260712-01.md](.test_reports/test-report-20260712-01.md)
  records PASS from a clean Release configure/build, direct
  `test-cache-controller`, `ctest -R cache`, and the Stage 38 live script.
  The live suffix turn reports `cached_tokens=11`, `timings.cache_n=11`,
  full `prompt_tokens=63`, hybrid hit delta `1`, accepted prefix metric,
  checkpoint restore/hit metrics, cold-budget gauge `2147483648`, and cleanup
  with port free.
- Developer test-results review
  [test-report-20260712-01-developer-review.md](.test_reports/test-report-20260712-01-developer-review.md)
  records PASS: the QA report is fresh relative to the Architect fix re-review,
  cited artifacts exist, raw values match the Stage 38 gate, and no product bug
  or execution blocker remains.
- [Part 12: Manager closure 2026-07-12](cache-handling-phase38-implementation/part-12-manager-closure-20260712.md)
  records PASS and closes Stage 38.

## Approved baseline

Manager design gate part 07 approved two fixes:

- safe strict-prefix/checkpoint partial restore for `/v1/chat/completions` and
  shared hybrid cache-controller paths used by that route;
- the D36-FU-01 cold-budget metric fix so `--cache-cold-max-mib 2048` reports
  `2147483648` bytes.

Binding constraints from the gate:

- `/completion` prefix restore is out of scope. Any `/completion` strict-prefix
  candidate must recompute with a bounded unsafe or fallback reason.
- Public prompt-token totals stay at full request prompt length.
- Only cache-specific fields report restored prefix length:
  `slot.n_prompt_tokens_cache`, `timings.cache_n`, and
  `usage.prompt_tokens_details.cached_tokens`.
- Checkpoint-dependent, SWA, recurrent, RS-limited, target-plus-draft, and MTP
  paths restore only from checkpoint-safe points.

Correctness wins over hit rate. Any validation gap falls back to recompute.

## Source anchors

| File | Anchors | Planned use |
| --- | --- | --- |
| `tools/server/server-cache-hybrid.h` | `cache_restore_miss_reason` lines 90-98, `cache_response` lines 370-388, `cold_budget_bytes` line 798 | Add any needed bounded reason or plan fields without changing public API. |
| `tools/server/server-cache-hybrid.cpp` | constructor lines 357-361, stats lines 1268-1270, `select_restore_candidate` lines 1961-1999, `find_prefix_candidate` lines 2002-2028, `record_prefix_candidate` lines 2067-2069, `record_restore_miss` lines 2142-2158, `tx_restore` lines 5248-5380, `tx_apply_restore` lines 5383-5422 | Implement selection, validation, cold promotion, metric counters, and 64-bit stats plumbing. |
| `tools/server/server-context.cpp` | metric helpers lines 4431-4496, cold-budget metric line 4601, assignment restore call lines 1303-1326, prompt loop lines 2823-3022 and 3128-3155, apply path lines 5857-6003 | Keep apply outside cache lock, preserve suffix prefill, and fix metric emission without duplicate HELP/TYPE rows. |
| `tools/server/server-slot.h` | cache fields lines 72-74, timings lines 526-533, slot metrics lines 657-659 | Confirm restored prefix appears only in cache-specific fields. |
| `tools/server/server-task.cpp` | OpenAI usage lines 389-395 | Confirm `prompt_tokens` remains full prompt length and `cached_tokens` receives prefix length. |
| `tests/test-cache-controller.cpp` | Stage 21 prefix tests lines 3247-3334, Stage 17 bounded miss tests lines 5109-5280, Stage 25 restore split tests lines 5452-5565, Stage 35 sync restore tests lines 5972-6053, main list lines 6650-6695 | Add focused unit regressions beside current cache-controller coverage. |

## Implementation steps

1. Trace cold-budget value end to end before editing code.
   Confirm constructor storage, `get_stats()` JSON type, `json_value(...)`
   extraction, and Prometheus formatting for `2048`, `4096`, `0`, and `-1`.
   Current constructor already uses 64-bit arithmetic; likely risk is typed JSON
   extraction or metric writer narrowing.

2. Fix cold-budget metric with the smallest numeric-type change.
   Preserve `cold_budget_bytes` as `int64_t`, keep `-1` unlimited and `0`
   disabled, and make `llamacpp:cache_cold_budget_bytes` print signed 64-bit
   values. Do not change cold demotion or eviction accounting.

3. Add restore-plan metadata for partial restore if needed.
   `cache_response.restored_token_count` already exists. Add route/profile or
   acceptance metadata only if `tx_restore` needs it to distinguish exact,
   checkpoint prefix, and rejected prefix outcomes.

4. Extend candidate selection after exact restore.
   Keep exact restore first. If exact selection fails, choose the deepest
   strict-prefix candidate in the same namespace. Validate token equality,
   prefix checksum over `[0, candidate_tokens)`, payload descriptor integrity,
   pair state, semantic boundary, and workload profile. Reuse existing
   checkpoint ranking for checkpoint-dependent profiles.

5. Enforce checkpoint and route constraints.
   For checkpoint-dependent, SWA, recurrent, RS-limited, target-plus-draft, and
   MTP paths, accept only checkpoint-safe candidates. Reject arbitrary LCP
   matches with `prefix_not_checkpoint_safe` or the nearest existing bounded
   reason. Reject `/completion` prefix candidates before payload apply.

6. Preserve transaction boundaries and cold promotion behavior.
   Keep restore planning and cold promotion under `cache_state_mutex_` in
   `tx_restore`. Keep live `llama_context` mutation in
   `try_restore_from_cache()` outside the lock. Finalize hits only through
   `tx_apply_restore()` after apply succeeds.

7. Apply restored prefix and process suffix normally.
   After apply, set `slot.prompt.tokens` to the restored prefix and set
   `slot.n_prompt_tokens_cache` / `slot.n_prompt_tokens_processed` to the
   restored prefix length. The prompt loop must start from that prefix and add
   only suffix tokens to the batch. It must not inject logits, sampled tokens,
   or prior assistant output.

8. Record bounded observability.
   Accepted prefix restores increment `cache_prefix_candidates_total` with an
   accepted reason and count as `cache_hits_total` only after apply succeeds.
   Rejections increment bounded miss/prefix rows. Logs include reason, profile,
   pair state, restored token count, request token count, and residency; no
   prompt text, raw namespace ids, raw descriptor ids, or new filesystem paths.

9. Update tests with Stage 38 rows.
   Add focused controller tests for TP-38-PR-01 through TP-38-PR-10 and
   TP-38-MET-01/02. Add at least one model-backed `/v1/chat/completions`
   regression for public `usage.prompt_tokens_details.cached_tokens`,
   full-length `usage.prompt_tokens`, `timings.cache_n`, and metrics.

## Test and regression plan

Unit and focused tests to add or update:

- TP-38-PR-01 exact repeat still wins and does not route through prefix logic.
- TP-38-PR-02 chat strict prefix plus new user turn restores prefix, processes
  suffix, and reports cached tokens equal to prefix length.
- TP-38-PR-03 checksum mismatch rejects with bounded reason.
- TP-38-PR-04 namespace, template, or tool drift rejects before apply.
- TP-38-PR-05 pair-state mismatch rejects without partial target/draft restore.
- TP-38-PR-06 checkpoint-dependent/MTP paths accept only checkpoint-safe points.
- TP-38-PR-07 cold prefix payload promotes inline or falls back safely.
- TP-38-PR-08 protected prefix metadata survives pressure while budgets hold.
- TP-38-PR-09 generated output is never replayed from cache.
- TP-38-PR-10 `/completion` strict-prefix candidate recomputes.
- TP-38-MET-01 `2048` MiB gauge prints `2147483648`.
- TP-38-MET-02 `0`, `1`, `2047`, `2048`, `4096`, and `-1` preserve meanings.

Focused commands for implementation evidence:

```powershell
cmake --build build --config Release --target test-cache-controller
.\build\bin\Release\test-cache-controller.exe
ctest --test-dir build -C Release -R cache --output-on-failure
$env:LLAMA_SERVER_BIN_PATH=(Resolve-Path .\build\bin\Release\llama-server.exe); pytest tools/server/tests/unit/test_cache_modes.py -q
```

Live evidence must include one `/v1/chat/completions` duplicate-plus-suffix run
showing nonzero `usage.prompt_tokens_details.cached_tokens`, full public
`usage.prompt_tokens`, positive `llamacpp:cache_hits_total{mode="hybrid"}`
delta, and prefix rows in `/metrics`. The cold-budget run must show both
internal JSON stats and public Prometheus output agree at `2147483648`.

Clean build rule: before QA handoff, run a clean Release configure/build for the
required server/test targets unless Manager explicitly narrows the evidence.

## Risk controls

- Fall back to recompute on any validation uncertainty.
- Keep exact restore behavior ahead of prefix restore.
- Count hits only after apply succeeds.
- Keep public usage totals full length.
- Do not change legacy cache behavior.
- Do not rename metric families except fixing numeric output for the approved
  cold-budget gauge.
- Keep changes easy to roll back by isolating prefix selection/validation and
  metric formatting from unrelated cache policy code.

## Status

Implementation evidence is recorded in part 3. Implementation re-review PASS is
recorded in part 6, and Manager implementation gate PASS is recorded in part 7.
QA test-plan handoff is recorded in part 8.

Test-plan review REWORK is recorded in part 9. QA correction for the Stage 38
standalone script, README, test-plan part, and handoff is recorded in part 8.
Architect test-plan re-review PASS is recorded in part 10.
Manager test-plan gate PASS is recorded in part 11. QA execution report -01
failed the live TP-38-PR-02 row. Developer review classifies it as a QA-owned
test/workload correction first, because the raw turn2 request inserts a
synthetic assistant message instead of proving that turn1 rendered tokens are a
strict prefix of turn2 rendered tokens.

QA correction report -02 fixed the live workload and proved strict rendered-token
prefix compatibility. The focused live retest still failed with
`cached_tokens=0`, `timings.cache_n=0`, hit delta `0`, rejected prefix metric
`prefix_restore_deferred`, and restore miss `unsafe_prefix_rejected`.

Developer fix report
`._design_docs/.test_reports/test-report-20260711-02-fixes.md` closes the
product-side root cause: checkpoint-dependent strict-prefix validation was using
the full cache entry length and a `MESSAGE_END`-only boundary rule instead of
the selected checkpoint descriptor span and checksum. The fix keeps
`/completion` prefix restore out of scope, keeps public prompt-token totals at
full length, and accepts checkpoint-dependent chat prefix restore only from the
checkpoint-safe descriptor.

Focused QA evidence now passes in
`._design_docs/.test_reports/test-report-20260712-01.md`: clean Release
configure/build, `test-cache-controller`, `ctest -R cache`, and the Stage 38
live script all exited `0`. The live suffix turn reports `cached_tokens=11`,
`timings.cache_n=11`, full `prompt_tokens=63`, hybrid hit delta `1`, accepted
prefix metric, checkpoint restore/hit metrics, and cold-budget gauge
`2147483648`.

Developer test-results review
`._design_docs/.test_reports/test-report-20260712-01-developer-review.md`
records PASS and confirms Manager may proceed to closure.

Manager closure part 12 records PASS. Stage 38 is closed with final
classification PASS 11, FAIL 0, BLOCKED 0.

Next owner is user. Terminal state for Stage 38 unless a follow-up stage is
opened or commit preparation is requested.

No commits, pushes, staging, or reverts were performed.
