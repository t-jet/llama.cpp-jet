# Stage 13 implementation - Part 8: implementation evidence

Source: [../cache-handling-phase13-implementation.md](../cache-handling-phase13-implementation.md)

Date: 2026-06-09

## Status

VERDICT: READY FOR IMPLEMENTATION REVIEW.

Code, focused tests, and implementation docs are updated for the Stage 13
endpoint compatibility corrections. QA planning and real endpoint
execution remain closed until implementation review accepts this change.

## Changed files

| File | Change |
| --- | --- |
| `tools/server/server-context.cpp` | Added a small internal metadata builder input, route-neutral preparation IDs, bounded degraded diagnostics, route-family diagnostic labels, safe refusal/reasoning text extraction, and an explicit embedding metadata exclusion comment. |
| `tools/server/server-context.h` | Added the optional diagnostic-source argument to `handle_completions_impl`. |
| `tests/test-cache-controller.cpp` | Added Stage 13 regression coverage for route-neutral preparation identity and embedding metadata exclusion. Updated one old rendered-text fixture to the new route-neutral method ID. |
| `._design_docs/cache-handling-phase13-implementation.md` | Updated Stage 13 implementation status and linked this evidence part. |
| `._design_docs/cache-handling-phase13-implementation/part-01-status-gates-and-route-inventory.md` | Updated planned-step status after implementation. |
| `._design_docs/document-index.md` | Updated Stage 13 implementation index text. |

## Implementation summary

The completion task path now builds prompt metadata through
`cache_metadata_for_request(cache_metadata_build_input)`. Endpoint
adapters pass facts: prepared request data, tokens, optional converted
chat messages, and a diagnostic source label. The helper owns the
metadata method selection.

Structured content extraction remains conservative. Text and
`media_marker` parts use their `text` field, `refusal` parts use their
`refusal` field, and top-level `reasoning_content` is included only as
rendered text metadata. Unsupported media parts are not treated as text.

`preparation_id` now uses route-neutral method names:

- `rendered-text-boundary-inference` for chat-style rendered text mapping
- `token-position-fallback` for flat prompt or token-position fallback

Endpoint names such as native completion, OpenAI chat, Responses,
transcription, and Anthropic messages are passed only as diagnostic
labels. They are not stored in `prepared_prompt_metadata`, so they do
not affect `hybrid_cache_controller::compute_namespace_id`.

Degraded diagnostics use bounded debug output:

```text
cache metadata: source=<route-family> method=<method> degraded=<reason> tokens=<n> boundaries=<n>
```

The log line does not include prompt text, chat content, tool arguments,
or raw media.

Embedding routes remain public-schema stable and metadata-excluded for
Stage 13. Current scheduler behavior sends embedding results and releases
the slot; hybrid cache save happens only for completion tasks after
generation. Attaching prompt metadata to embedding tasks would imply
cache eligibility that does not exist in the current implementation.

## Route-family impact

| Route family | Impact |
| --- | --- |
| Native completion | Uses shared metadata helper and `token-position-fallback` for flat prompts. |
| OpenAI completions | Same shared helper and fallback method as native completion. |
| OpenAI chat completions | Passes original messages to the shared helper; rendered-text inference uses route-neutral method ID. |
| OpenAI Responses | Converted chat messages pass through the same helper. Diagnostic label is `openai-responses` only. |
| OpenAI audio transcriptions | Converted chat prompt state passes through the same helper. Diagnostic label is `openai-transcription` only. Audio build or fixture availability remains QA evidence work. |
| Anthropic messages | Converted chat messages pass through the same helper. Diagnostic label is `anthropic-messages` only. |
| Embeddings | No cache metadata attached; exclusion rationale recorded above. |
| Metrics | Existing metrics surface unchanged; bounded debug diagnostics added for degraded metadata. |
| Slots | No code changes and no semantic changes. |

## Public schema and marker checks

- No request fields were added.
- No response fields were added.
- No public cache-control route was added.
- `/slots` code was not changed.
- Fork-only Jinja markers were not exposed or modified.
- No prompt text or raw media was added to diagnostics.

## Tests run

| Command | Result |
| --- | --- |
| `cmake --build build --config Release --target test-cache-controller` | PASS, exit 0. |
| `build\bin\Release\test-cache-controller.exe` | PASS, exit 0. Output reports all tests passed, total 87 tests. |
| `ctest --test-dir build -C Release -R test-cache-controller --output-on-failure` | PASS, exit 0. 1/1 test passed, `test-cache-controller`, 1.63 sec. |

## Not run

Long endpoint suites, model-backed public endpoint parity tests, Stage 12
synthetic V2/V3/non-MTP expansion, and audio-transcription fixture tests
were not run. The user explicitly limited this session to focused build
and unit/regression evidence.

## Watch items for review and QA

- Implementation review should verify that diagnostic labels cannot enter
  namespace inputs.
- QA should still run real endpoint parity rows E13-01 through E13-12
  after implementation review accepts the code.
- Audio transcription routes need real availability evidence or a precise
  blocked/unavailable record from QA.
- Embeddings need public schema smoke evidence, but current cache
  eligibility is excluded unless future code adds a real embedding
  save/restore path.

## Bug-fix addendum 2026-06-10

Developer fixed the three product bugs from
[test-report-20260610-02-developer-review.md](../.test_reports/test-report-20260610-02-developer-review.md).
The detailed fix record is
[test-report-20260610-02-fixes.md](../.test_reports/test-report-20260610-02-fixes.md).

The server now keeps MTMD placeholders available to hybrid cache identity
helpers through `server_tokens::cache_token_ids()`, while inference-only
callers still use `get_tokens()` and keep the no-MTMD assertion. Hybrid
restore copies cached `server_tokens` directly and truncates with
`keep_first()`, so restored MTMD prompts keep their media chunk map instead of
being rebuilt from scalar token IDs.

Native MTMD prompt tokenization now accepts the documented default marker
`<__media__>` by translating it to the server runtime marker before calling
`mtmd_tokenize`, but only when the runtime marker is absent from the prompt.
Degraded cache metadata diagnostics now use info logging for the bounded
`cache metadata:` line required by E13-14.

Focused evidence:

- `cmake --build build --config Release --target test-cache-controller` passed.
- `build\bin\Release\test-cache-controller.exe` passed and included
  `Stage 13 MTMD cache token ids... PASSED` with total `88 tests`.
- `ctest --test-dir build -C Release -R test-cache-controller --output-on-failure`
  passed.
- `cmake --build build --config Release --target llama-server` passed.

CUDA endpoint retest was not run in this Developer loop. QA still needs to
rerun E13-01c, E13-07, E13-08, E13-14, and E13-16 after Architect review.

## Bug-fix rework addendum 2026-06-10

Developer corrected
[Part 10 S13-BUGFIX-REVIEW-01](part-10-bugfix-review-20260610.md).
`server-cache-hybrid.cpp` no longer calls the MTMD-asserting
`server_tokens::get_tokens()` in cache identity helpers. The hybrid
controller now uses `cache_token_ids()` for cache token vector conversion,
token-span checksums, exact-match lookup, namespace validation comparisons,
and prefix-index keys. Scalar inference callers keep using `get_tokens()`.

Focused regression coverage now includes live `hybrid_cache_controller`
admission and lookup with MTMD placeholder tokens. The test covers the path
that previously asserted before admission/index lookup could complete.

Rework evidence:

- `cmake --build build --config Release --target test-cache-controller` passed.
- `build\bin\Release\test-cache-controller.exe` passed and included
  `Stage 13 hybrid MTMD admission and lookup... PASSED` with total `89 tests`.
- `ctest --test-dir build -C Release -R test-cache-controller --output-on-failure`
  passed.
- `cmake --build build --config Release --target llama-server` passed.

Architect re-review
[Part 11](part-11-bugfix-re-review-20260610.md) passed on 2026-06-10
with zero open findings. QA owns the focused rerun for E13-01c, E13-07,
E13-08, E13-14, and E13-16.

## Report 03 bug-fix addendum 2026-06-10

Developer fixed S13-BUG-20260610-03-01 from
[test-report-20260610-03-developer-review.md](../.test_reports/test-report-20260610-03-developer-review.md).
The detailed fix record is
[test-report-20260610-03-fixes.md](../.test_reports/test-report-20260610-03-fixes.md).

The server now carries the bounded route diagnostic label in internal
`prepared_prompt_metadata` and emits the degraded `cache metadata:` info line
when the completion task launches. This keeps the log tied to actual task
metadata instead of relying only on request-side helper construction. The
diagnostic source is not part of cache namespace computation and is not exposed
in public request or response schemas.

Focused evidence:

- `cmake --build build --config Release --target test-cache-controller` passed.
- `build\bin\Release\test-cache-controller.exe` passed and included
  `Stage 13 route-neutral preparation identity... PASSED` with total
  `89 tests`.
- `ctest --test-dir build -C Release -R test-cache-controller --output-on-failure`
  passed.
- `cmake --build build --config Release --target llama-server` passed.
- Scoped `git diff --check` on touched paths passed.

Next owner: Architect review of the report 03 fix. After review passes, QA
should rerun E13-14 and E13-16.
