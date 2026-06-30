# Stage 32 Architect fix re-review 2026-06-30

VERDICT: PASS

## Scope and gate status

Review subject:

- `._design_docs/cache-handling-phase32-implementation/part-04-architect-fix-review-20260630.md`
- `._design_docs/.test_reports/test-report-20260630-01-stage32-01-fixes.md`
- `._design_docs/cache-handling-phase32-implementation.md`
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`
- `tools/server/tests/unit/test_cache_modes.py`
- `_test_output/stage32-fix-live-duplicate-chat-20260630-01/`

Gate status: PASS. The part 04 REWORK finding is addressed by durable
Developer evidence and raw run artifacts. QA focused retest may open.

## Findings

No blocking findings.

No non-blocking findings.

## Decisions

| Check | Decision |
| --- | --- |
| Part 04 F32-ARCH-FIX-01 | PASS. Developer supplied the missing live duplicate chat evidence and metric hit-delta proof. |
| F32-FIX-01 request-row extraction | PASS. The driver reads chat cached tokens from `usage.prompt_tokens_details.cached_tokens` and keeps `timings.cache_n` fallback. |
| F32-FIX-01 product save/restore status | PASS for focused retest gate. No product restore code change is required before QA because live duplicate chat traffic restored five of five duplicates and increased the hybrid hit counter. |
| F32-FIX-02 aggregate metric labels | PASS. The remaining aggregate Stage 8/10 public metric rows use `scope="all"` instead of `namespace="all"`, with focused coverage in controller and Python metric-shape tests. |
| QA gate | OPEN for focused retest only. Full comparison rerun remains a Manager decision after focused PASS. |

## Evidence review

F32-ARCH-FIX-01 in part 04 required a focused live duplicate chat probe showing
both request-row reuse and a positive `llamacpp:cache_hits_total{mode="hybrid"}`
delta.

Developer evidence satisfies that requirement:

- `_test_output/stage32-fix-live-duplicate-chat-20260630-01/probe-summary.json:1`
  records `status: PASS`, duplicate group
  `r-0051,r-0059,r-0080,r-0109,r-0162,r-0187`, `hit_delta=5`,
  `cache_hit_rows=5`, and `max_cache_n=1911`.
- `_test_output/stage32-fix-live-duplicate-chat-20260630-01/requests.jsonl:1`
  through `:6` record `cache_n` values
  `0,1911,1911,1911,1911,1911`, `prompt_n=1915` for all six rows, and
  `cache_hit=true` on rows 2 through 6.
- `_test_output/stage32-fix-live-duplicate-chat-20260630-01/metrics-before.txt:45`
  records `llamacpp:cache_hits_total{mode="hybrid"} 0`.
- `_test_output/stage32-fix-live-duplicate-chat-20260630-01/metrics-after.txt:45`
  records `llamacpp:cache_hits_total{mode="hybrid"} 5`.
- `_test_output/stage32-fix-live-duplicate-chat-20260630-01/responses/response-2.json:21`
  through `:22` records the chat response field
  `prompt_tokens_details.cached_tokens: 1911`, matching the driver fix.
- A targeted scan of `server.err.log` found no `error`, `fail`, `fatal`,
  `checksum_mismatch`, `token_count_mismatch`, `exception`, or `crash` lines.

Code and docs checked for the gate:

- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1:166`
  defines `Get-Stage29ResponseStats`.
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1:179`
  reads `usage.prompt_tokens_details.cached_tokens`.
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1:204`
  writes `cache_hit` from the extracted `cache_n`.
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1:210`
  still derives `hit_delta` from `llamacpp:cache_hits_total`, preserving the
  independent metric channel that part 04 required.
- `tools/server/server-context.cpp:4803` and following aggregate Stage 8/10
  metric rows now emit `scope="all"`.
- `tests/test-cache-controller.cpp:1669` asserts `namespace="all"` is absent
  from the focused Stage 31/32 metric-shape helper output.
- `tools/server/tests/unit/test_cache_modes.py:70` through `:86` expect
  aggregate public rows with `scope="all"`.
- `._design_docs/.test_reports/test-report-20260630-01-stage32-01-fixes.md:111`
  through `:133` records the rework probe, values, and conclusion.

## QA focused retest scope

QA may open focused retest with this exact scope:

- clean Release CUDA configure and build proof;
- build `llama-server` and `test-cache-controller`;
- run direct `test-cache-controller.exe`;
- run `ctest --test-dir build-cuda -C Release -R cache -V`;
- run a short live hybrid `/v1/chat/completions` duplicate probe using the
  Stage 32 fixture and duplicate exact request group
  `r-0051,r-0059,r-0080,r-0109,r-0162,r-0187`;
- scrape `/metrics` before and after the probe;
- assert at least one duplicate row has `cache_n > 0` or `cache_hit=true`;
- assert `llamacpp:cache_hits_total{mode="hybrid"}` delta is positive;
- assert namespace count remains bounded;
- assert no public cache metric row uses a `namespace` label for aggregate
  Stage 8/10 rows;
- assert HELP/TYPE remains unique per scrape;
- preserve server stdout/stderr and fail on crash, repeated request error,
  `token_count_mismatch`, or `checksum_mismatch`.

After focused PASS, Manager may decide whether to run the longer Stage 32
comparison again. This re-review does not open the full comparison by itself.

## Handoff

State: ready for QA focused retest.

Next owner: QA.

Next gate: QA focused retest execution using the scope above.
