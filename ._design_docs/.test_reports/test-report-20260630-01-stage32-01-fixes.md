# Stage 32 fixes for test-report-20260630-01

Status: QA focused retest PASS; awaiting Manager decision on full comparison rerun
Date: 2026-06-30
Owner: Developer

## Trigger

QA report:

- `._design_docs/.test_reports/test-report-20260630-01-stage32-01.md`

Developer review:

- `._design_docs/.test_reports/test-report-20260630-01-stage32-01-developer-review.md`

Stage 32 failed with two acceptance findings:

- zero live hybrid reuse on completed exact-repeat `/v1/chat/completions`
  traffic as recorded by the Stage 29/32 driver;
- remaining public cache metric rows that used `namespace="all"` instead of
  accepted aggregate `scope="all"` labels.

The 180 minute run budget left later warm rows not-run, but those rows are not
needed for the bug verdict.

Developer follow-up found that the first finding was an evidence extraction
bug, not a save/restore product bug. `/v1/chat/completions` reports restored
prompt tokens at `usage.prompt_tokens_details.cached_tokens`; the driver only
read `timings.cache_n`, so it wrote `cache_n=0` even when server metrics and a
focused probe showed cache hits.

## Fix plan

F32-FIX-01: live exact-repeat restore parity.

- Keep product restore code unchanged unless new evidence shows a real
  save/restore mismatch.
- Change the Stage 29/32 driver to extract chat cached tokens from
  `usage.prompt_tokens_details.cached_tokens`.
- Keep `timings.cache_n` as fallback for non-chat responses or older shapes.
- Use `usage.prompt_tokens` and `usage.completion_tokens` for prompt and
  predicted token counts when present.
- Treat a row as `cache_hit=true` when the effective extracted `cache_n` is
  greater than zero.

F32-FIX-02: public metric label shape.

- Replace remaining aggregate cache metric labels named `namespace` with the
  accepted `scope` label.
- Keep raw namespace IDs out of Prometheus.
- Extend focused metric-shape coverage so the Stage 8/10 row families cannot
  regress.

## Retest plan

Use shorter evidence before another full comparison:

1. Clean Release CUDA build.
2. Direct `test-cache-controller` and `ctest -R cache`.
3. Short live hybrid exact-repeat `/v1/chat/completions` probe.
4. `/metrics` scrape after the probe.

Required focused PASS signals:

- at least one duplicate exact request reports `cache_hit=true` or
  `cache_n > 0`;
- `llamacpp:cache_hits_total{mode="hybrid"}` increases;
- namespace count stays bounded;
- no public cache metric uses a `namespace` label;
- HELP/TYPE remains unique per scrape;
- no server crash or request error.

After focused PASS, Manager can decide whether to rerun the longer comparison.

## Progress log

2026-06-30:

- Developer test-results review classified both Stage 32 failures as product
  bugs and opened this fix loop.
- Workload audit confirmed the Stage 32 exact class contains real duplicates:
  78 exact rows, 41 unique exact message bodies, 22 duplicate groups, 59 rows
  in duplicate groups, and largest duplicate group size 6. The largest group's
  repeated request IDs all had identical `prompt_n=1915` and `cache_n=0`.
- Focused probe corrected the F32-FIX-01 classification: chat completions do
  not expose restored prompt tokens through the field read by the driver. The
  driver now reads `usage.prompt_tokens_details.cached_tokens`, with
  `timings.cache_n` kept as fallback. No product restore code changed for
  F32-FIX-01.
- F32-FIX-02 changed remaining aggregate public cache metric rows from
  `namespace="all"` to `scope="all"` in production emission and test-only
  metric row generation.
- Regression coverage was extended in `tests/test-cache-controller.cpp` for
  the aggregate Stage 8/10 row families that caused the Stage 32 scan failure.
- Verification:
  - PowerShell parse of `compare-legacy-vs-hybrid.ps1`: PASS.
  - AST-extracted `Get-Stage29ResponseStats` probe with chat-shaped response:
    PASS, returned `cache_n=42`, `prompt_n=100`, `predicted_n=7`,
    `prompt_ms=12.5`.
  - Scoped grep for `namespace="all"` in touched code/tests/script: PASS, no
    matches.
  - Scoped `git diff --check`: PASS.
  - `cmake --build build-cuda --config Release --target test-cache-controller
    -j 4`: PASS.
  - `build-cuda\bin\Release\test-cache-controller.exe`: PASS, 142/142.
  - `ctest --test-dir build-cuda -C Release -R cache -V`: PASS, 1/1.
  - `cmake --build build-cuda --config Release --target llama-server -j 4`:
    PASS.
- Architect fix review found that this evidence did not close the independent
  Stage 32 `hit_delta=0` row. Developer ran a short live duplicate chat probe
  against current `build-cuda\bin\Release\llama-server.exe` using the Stage 32
  Qwen3.5 MTP fixture and the known duplicate exact request group
  `r-0051,r-0059,r-0080,r-0109,r-0162,r-0187` from
  `_test_output/stage32-cache-modes-20260630-01/workload.jsonl`.
- Live probe command shape:
  `llama-server.exe -m ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf --cache-mode hybrid --port 8932 -c 4096 --parallel 2 --cache-ram 512 --metrics --seed 42 --cache-cold-max-mib 2048 --cache-cold-path D:\tmp\cache-cold-stage32-fix-live-20260630-01`, then six identical `/v1/chat/completions` requests using `r-0051` request body.
- Live probe artifacts:
  `_test_output/stage32-fix-live-duplicate-chat-20260630-01/probe-summary.json`,
  `requests.jsonl`, `metrics-before.txt`, `metrics-after.txt`,
  `source-request.json`, `server-command.txt`, `server.out.log`,
  `server.err.log`, and `responses/response-1.json` through
  `responses/response-6.json`.
- Live probe result: PASS. Request-row reuse through the fixed chat extraction
  path reported `cache_n` values `0,1911,1911,1911,1911,1911`,
  `prompt_n=1915` for all six rows, and 5/6 `cache_hit=true` rows.
  `llamacpp:cache_hits_total{mode="hybrid"}` increased from `0` to `5`,
  so `hit_delta=5`.
- Conclusion for F32-FIX-01: product save/restore path is not the remaining
  root cause for the duplicate chat case. The failed Stage 32 request-row
  `cache_n=0` values were a driver extraction bug, while the original metric
  `hit_delta=0` rows need rerun with focused live evidence. Current live
  evidence proves duplicate chat traffic increments the hybrid hit counter.

## Handoff

Architect fix re-review passed in
`._design_docs/cache-handling-phase32-implementation/part-05-architect-fix-re-review-20260630.md`.

QA focused retest passed in
`._design_docs/.test_reports/test-report-20260630-02-stage32-focused-retest.md`.
Evidence after F32-FIX-01 is non-zero `cache_n` in repeated exact chat
`requests.jsonl` rows and positive
`llamacpp:cache_hits_total{mode="hybrid"}` delta on the same run. Evidence
after F32-FIX-02 is no public cache metric row with label name `namespace`.

Focused retest values:

- Clean Release CUDA configure/build: PASS.
- Direct `test-cache-controller`: PASS.
- `ctest --test-dir build-cuda -C Release -R cache -V`: PASS.
- Live duplicate chat `cache_n`: `0,1911,1911,1911,1911,1911`.
- Hybrid hit delta: `5`.
- Namespace count: `1`.
- Public cache `namespace` label findings: `0`.
- HELP/TYPE duplicate findings: `0`.
- Forbidden server-log findings: `0`.

Full comparison rerun remains a Manager decision after focused PASS.
