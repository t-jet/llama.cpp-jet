# Stage 32 Architect fix review 2026-06-30

VERDICT: REWORK

## Scope and gate status

Review subject:

- `._design_docs/.test_reports/test-report-20260630-01-stage32-01.md`
- `._design_docs/.test_reports/test-report-20260630-01-stage32-01-developer-review.md`
- `._design_docs/.test_reports/test-report-20260630-01-stage32-01-fixes.md`
- `._design_docs/cache-handling-phase32-design.md`
- `._design_docs/cache-handling-phase32-implementation.md`
- `._design_docs/cache-handling-phase32-implementation/part-03-implementation-plan-re-review-20260630.md`
- `._design_docs/cache-handling-test-plan/part-36-stage32-live-comparison-rerun.md`
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`

Gate status: REWORK. QA focused retest must not open yet because F32-FIX-01
does not close the independent hit-delta evidence requirement from the approved
Stage 32 plan and failed report.

## Findings

### BLOCKING F32-ARCH-FIX-01: F32-FIX-01 reclassifies the zero-reuse failure without closing metric hit-delta evidence

Files and lines:

- `._design_docs/.test_reports/test-report-20260630-01-stage32-01.md:92-100`
- `._design_docs/.test_reports/test-report-20260630-01-stage32-01.md:114-118`
- `._design_docs/.test_reports/test-report-20260630-01-stage32-01-developer-review.md:27-31`
- `._design_docs/.test_reports/test-report-20260630-01-stage32-01-developer-review.md:39-48`
- `._design_docs/.test_reports/test-report-20260630-01-stage32-01-fixes.md:27-31`
- `._design_docs/.test_reports/test-report-20260630-01-stage32-01-fixes.md:96-109`
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1:208-213`
- `._design_docs/cache-handling-phase32-implementation/part-02-plan-corrections-20260630.md:165-171`
- `._design_docs/cache-handling-test-plan/part-36-stage32-live-comparison-rerun.md:176-178`

The driver patch correctly adds chat `usage.prompt_tokens_details.cached_tokens`
extraction for request rows. That can explain false `cache_n=0` and
`cache_hit=false` values written to `requests.jsonl`.

It does not explain the failed report's independent `hit_delta=0` evidence. The
driver still computes `hit_delta` from `llamacpp:cache_hits_total` before and
after each leg, then writes that value into `summary.json`. The Stage 32
extractor copies those summary rows into `hybrid-hit-deltas.json`. The approved
QA plan requires at least one positive hit delta, not only non-zero request-row
`cache_n`.

The fix report says server metrics and a focused probe showed hits, but the
listed verification only includes an AST-extracted function probe for
`Get-Stage29ResponseStats`. That proves the parser can read a synthetic
chat-shaped response. It does not prove a live duplicate `/v1/chat/completions`
request increments `llamacpp:cache_hits_total`, and it does not resolve the
server-log evidence cited by the Developer review: later restores missed with
`token_count_mismatch` or `checksum_mismatch` after prior saves.

Required correction:

- Add live or preserved-artifact evidence showing that the original zero
  `hit_delta` rows were caused by a measurement bug, or fix the product path so
  `llamacpp:cache_hits_total` increases on duplicate chat traffic.
- Keep the request-row parser fix, but do not use it alone to close the
  zero-reuse product finding.
- Update the fix report with the exact command, artifact paths, and observed
  hit-delta values.

Acceptance check:

- A focused live duplicate chat probe shows at least one duplicate request with
  `cache_n > 0` or `cache_hit=true`, and the same run shows
  `llamacpp:cache_hits_total{mode="hybrid"}` increasing.

## Decisions

| Check | Decision |
| --- | --- |
| F32-FIX-01 request-row parser | PASS as a narrow script fix. `Get-Stage29ResponseStats` reads chat `usage.prompt_tokens_details.cached_tokens` and falls back to `timings`. |
| F32-FIX-01 gate closure | REWORK. Metric hit-delta and server restore-miss evidence remain unclosed. |
| F32-FIX-02 public aggregate labels | PASS for review scope. The production rows now use `scope="all"` for the Stage 8/10 aggregate families, and the C++ test helper covers the same families with an explicit negative assertion for the old label. |
| Focused tests | PASS as supporting evidence only. The controller build, direct run, `ctest -R cache`, and server build do not replace the missing live duplicate chat hit-delta proof. |

## Required corrections

Developer must update `test-report-20260630-01-stage32-01-fixes.md` and, if
needed, code:

- Reconcile the prior `hit_delta=0` evidence with the new driver parser root
  cause.
- Provide focused live chat evidence with both request-row reuse and metric hit
  delta, or fix the remaining save/restore path.
- Keep F32-FIX-02 as implemented unless QA finds a remaining `namespace` label
  in public cache metrics.

## QA scope

QA focused retest may not open from this review.

After Developer rework and Architect re-review PASS, QA scope should be:

- clean Release CUDA build;
- direct `test-cache-controller` and `ctest -R cache`;
- short live hybrid `/v1/chat/completions` duplicate probe;
- `/metrics` scrape before and after the probe;
- assert non-zero request-row reuse and positive
  `llamacpp:cache_hits_total{mode="hybrid"}` delta;
- assert namespace count remains bounded, no public cache metric uses a
  `namespace` label, HELP/TYPE remains unique per scrape, and no server crash
  or repeated request error appears.

## Handoff

State: rework required.

Next owner: Developer.

Next gate: Architect fix re-review after Developer supplies live metric
hit-delta evidence or product correction evidence.
