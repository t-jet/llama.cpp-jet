# Cache handling test plan - Part 23: Stage 13 endpoint compatibility

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)

## Scope

Stage 13 QA planning starts after Architect implementation review PASS in
[part-09](../cache-handling-phase13-implementation/part-09-architect-implementation-review.md).
This part is reusable planning only. It is not execution evidence.

Stage 13 proves that public routes keep their schemas while hybrid cache
behavior is selected by command-line flags and route-neutral internal
metadata. Real endpoint execution must use a fresh clean build and a fresh
report under `._design_docs/.test_reports/`.

## Setup and evidence rules

Before any E13 execution session:

- start from a clean Release build, including `llama-server` and any focused
  regression binary named by the execution report; stale binaries invalidate
  the run
- create a fresh `test-report-YYYYMMDD-NN.md` and record git status, build
  command, binary timestamp, server flags, route inventory, fixtures, request
  bodies, responses, `/metrics` snapshots, and bounded log excerpts
- run endpoint rows with `--cache-mode hybrid`, a stated cache budget,
  deterministic sampling, and any required `--embeddings`, multimodal,
  projector, or audio flags
- record unavailable route or fixture support as `BLOCKED` with the exact
  missing build feature, route, tool, or fixture
- classify schema drift, cache request fields, cache response fields, `/slots`
  behavior changes, public marker exposure, or endpoint names entering
  namespace inputs as `FAIL`

A `PASS` row needs endpoint behavior evidence, not only a 200 response. Compare
positive hybrid behavior with a negative control when practical.

## Stage 13 matrix

| ID | Route or contract | Positive coverage | Negative or blocking coverage | Required evidence |
| --- | --- | --- | --- | --- |
| E13-01a | Native `/completion` plain string prompt | Plain string prompt creates miss then hit or restore under the same hybrid CLI settings. | Legacy or cache-disabled control shows no hybrid hit claim. | Request, response, cache counters, `timings.cache_n` if exposed, bounded logs. |
| E13-01b | Native `/completion` token-array prompt | Token-array prompt creates miss then hit or restore under the same hybrid CLI settings. | Token-array parsing, token boundaries, and route selection must not alter public schema or cache namespace. | Request with token array, response, cache counters, `timings.cache_n` if exposed, bounded logs. |
| E13-01c | Native `/completion` multimodal prompt shape | Any supported multimodal prompt shape available in local fixtures creates miss then hit or restore under the same hybrid CLI settings. Keep this row visible even when it cannot run. | Missing multimodal build support, projector, media, tool, or fixture is `BLOCKED` with exact prerequisite evidence. Use `SKIP` only with design or Manager evidence that the shape is out of Stage 13 scope. | Multimodal fixture inventory, startup flags, request, response, cache counters, `timings.cache_n` if exposed, exact blocked or skip prerequisite evidence, bounded logs. |
| E13-01d | Native `/completions` alias | Alias keeps the same behavior as `/completion` for the runnable plain string prompt fixture. | Alias name must not affect namespace, response schema, or hybrid hit claim. | Request, response, cache counters, alias route evidence, bounded logs. |
| E13-02 | OpenAI `/v1/completions` | Equivalent prompt follows the same metadata method as native flat completion. | Endpoint family name must not affect namespace or response schema. | Request/response pair, metrics, route-neutral `method=<method>` log if degraded. |
| E13-03 | OpenAI `/v1/chat/completions` and `/chat/completions` | System/user/assistant messages keep schema and use safe rendered-text metadata. | Route-specific `preparation_id` or cache fields in request/response are `FAIL`. | Chat request/response, metrics, namespace/preparation evidence. |
| E13-04 | OpenAI `/v1/responses` and `/responses` | If route exists, string input and item-list input keep Responses schema and route through shared completion metadata. | If route is absent, record availability probe as `BLOCKED`; conversion loss must degrade without schema drift. | Route probe, request/response or blocked evidence, metrics, bounded diagnostic. |
| E13-05 | Anthropic `/v1/messages` | If route exists, system/messages/tool-use shape preserves Anthropic schema and safe metadata after conversion. | If route is absent, record availability probe as `BLOCKED`; unsafe media/tool data degrades. | Route probe, request/response or blocked evidence, conversion diagnostic, metrics. |
| E13-06 | Anthropic token-count or completion-style route inventory | If route exists but does not create completion state, prove no cache state is introduced. | If absent, record availability probe as `BLOCKED`. | Route inventory, request/response or blocked evidence, no cache-hit or restore claim. |
| E13-07 | `/v1/audio/transcriptions` | If audio support and fixture exist, converted prompt state uses route-neutral preparation identity. | Missing audio build support, `allow_audio`, mtmd, projector, or fixture is `BLOCKED` with exact reason. | Startup flags, route probe, audio fixture or missing prerequisite, response/log evidence. |
| E13-08 | `/audio/transcriptions` | Same contract as E13-07 for the non-`/v1` alias when registered. | Missing route or fixture is `BLOCKED` with exact prerequisite; row is not dropped. | Route probe, request/response or blocked evidence, metadata diagnostic if run. |
| E13-09 | Native and OpenAI embeddings | `/embedding`, `/embeddings`, and `/v1/embeddings` keep normal response schemas. | Current Stage 13 cache eligibility is excluded; no cache metadata, hit, restore, or checkpoint claim is allowed. | `--embeddings` startup, request/response, proof metadata and cache-hit claims are absent. |
| E13-10 | `/slots` save/restore/erase | Save, restore, and erase semantics and schemas are unchanged by Stage 13. | Any schema change, cache-control field, or behavior change is `FAIL`. | `/slots` sequence, before/after responses, no hybrid-cache control additions. |
| E13-11 | Marker schema stability | Fork-only markers remain test input only and are stripped before tokenization/inference. | New public marker fields, response fields, or documented marker contract are `FAIL`. | Request fixtures, response schema check, log scan for marker leakage. |
| E13-12 | Command-line selected hybrid behavior | `--cache-mode hybrid` plus existing cache flags control behavior across routes. | Per-endpoint cache flags or cache fields in request bodies are `FAIL`. | Startup command, route requests, schema diff, flags list. |
| E13-13 | Route-neutral `preparation_id` | Equivalent prompt state uses `rendered-text-boundary-inference` or `token-position-fallback` independent of route family. | `native`, `openai`, `responses`, `transcription`, or `anthropic` in namespace-affecting `preparation_id` is `FAIL`. | Focused helper evidence plus endpoint logs/metrics where available. |
| E13-14 | Degraded fallback diagnostics | Boundary-missing requests fall back safely and emit bounded existing diagnostics. | Prompt text, marker text, tool args, paths, checksums, payload bytes, or raw media in logs/metrics are `FAIL`. | Degraded request, log excerpt, `/metrics`, leakage scan. |
| E13-15 | Public response schema stability | Each public route in E13-01 through E13-10 keeps its documented response shape. | Added cache fields, removed required fields, or incompatible error shape are `FAIL`. | Captured JSON responses and schema comparison notes per route. |
| E13-16 | Clean build and fresh report gate | Later execution starts with clean build and fresh report before endpoint probes. | Incremental build, stale binary, or reused report invalidates endpoint verdicts. | Build commands, timestamps, git status, report filename. |

## Reusable automation guidance

Automation can extend the existing PowerShell harness or add a Stage 13 driver,
but it must keep row verdicts honest:

- capture route inventory first and write unavailable rows with exact
  prerequisites
- use one endpoint helper so equivalent prompt fixtures can run through native,
  OpenAI, Anthropic, and transcription routes when shapes are compatible
- store per-row requests, responses, metrics, and logs under the session
  artifact directory and link them from the report
- keep schema assertions explicit: no cache fields in public requests or
  responses, no public cache-control route, and no public marker contract
- keep embedding rows separate from completion rows because Stage 13 excludes
  embedding cache metadata in the current implementation

Do not resume synthetic Stage 12 V2, V3, or non-MTP matrix expansion as
substitute evidence for these endpoint rows.
