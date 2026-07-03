# Stage 34 implementation evidence 2026-06-30

Status: implementation complete; implementation review open

## Scope implemented

Implemented the approved Stage 34 first pass:

- replay parser for generic JSONL plus the real `._analysis/chat_log.jsonl`
  fixture;
- chat-completion request renderer with `metadata.stage34` sidecar fields;
- expected-hit analyzer with exact-message duplicate detection and budget
  residency classification;
- dry-run runner that writes events, requests, expected hits, and summary
  artifacts;
- result analyzer extraction that prefers
  `usage.prompt_tokens_details.cached_tokens` over `timings.cache_n`;
- synthetic generic agentic fixture;
- C++ regressions for replay identity namespace exclusion and restore-plan
  deep-copy lifetime;
- pure Python regression for cached-token extraction.

No production diagnostic fields were added. Existing `tx_restore` deep-copy
behavior was sufficient for this stage. Safe prefix restore was not added.

## Files changed

Harness:

- `._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1`
- `._design_docs/cache-handling-test-scripts/analyze-stage34-expected-hits.ps1`
- `._design_docs/cache-handling-test-scripts/lib/stage34-replay-parser.ps1`
- `._design_docs/cache-handling-test-scripts/lib/stage34-request-renderer.ps1`
- `._design_docs/cache-handling-test-scripts/lib/stage34-result-analyzer.ps1`
- `._design_docs/cache-handling-test-scripts/_fixtures/stage34/synthetic-agentic.jsonl`

Tests:

- `tests/test-cache-controller.cpp`
- `tests/test-stage34-result-analyzer.py`

Docs:

- `._design_docs/cache-handling-phase34-implementation.md`
- this part file
- `._design_docs/document-index.md`
- `._design_docs/cache-handling-stage-tracker.md`

## Behavior notes

Branch, session, transcript row, request id, agent id, and parent branch data
stay in harness sidecars and `metadata.stage34` request metadata. They do not
enter `prepared_prompt_metadata.compatibility_key` and do not affect production
namespace computation.

The C++ deep-copy regression captures a restore plan for a target-only payload,
evicts the source payload, proves the source descriptor no longer validates,
and then proves the captured target bytes still apply through
`tx_apply_restore`. Draft-byte lifetime follows the same `cache_response`
copy path in production, but the current no-context test hook can only exercise
target-only restore without a draft runtime context.

The parser treats `chat_log.jsonl` as one fixture. It scans generic JSON keys,
emits captured events when messages or prompt text exist, and emits blocked
reconstructed request rows when only provider request ids are available.

## Evidence

| Command | Result |
| --- | --- |
| `pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1 -TranscriptPath ._design_docs/cache-handling-test-scripts/_fixtures/stage34/synthetic-agentic.jsonl -OutputDir _test_output/stage34-synthetic-dry-run -Mode dry-run` | PASS. 5 transcript rows, 5 replay events, 5 captured, 0 blocked, expected-hit rows = 1. |
| `pwsh -NoProfile -File ._design_docs/cache-handling-test-scripts/replay-agentic-transcript.ps1 -TranscriptPath ._analysis/chat_log.jsonl -OutputDir _test_output/stage34-chatlog-dry-run -Mode dry-run` | PASS. 354 transcript rows, 56 replay events, 46 captured, 10 reconstructed, 10 blocked, expected-hit rows = 23. |
| `python -m pytest tests/test-stage34-result-analyzer.py -q` | PASS. 1 passed. |
| `cmake --build build --config Release --target test-cache-controller -j 4` | PASS. Target built. MSVC repeated three pre-existing `%zu` format warnings in `tests/test-cache-controller.cpp` unrelated to Stage 34 edits. |
| `.\build\bin\Release\test-cache-controller.exe` | PASS. 144/144 tests. |
| `ctest --test-dir build -C Release -R cache -V` | PASS. 1/1 test passed, `test-cache-controller`. |

## Deferred evidence

No long live Qwen replay was started. Sequential and concurrent live replay
remain QA execution work after implementation review and test-plan gates.

## Path correction note (added 2026-06-30 by Developer rework)

The output paths cited in the table above were moved out of
`._design_docs/cache-handling-test-scripts/._test_output/` (the original wrong
location that violated the durable-vs-non-durable separation in
`cache-handling-test-plan.md`) to the project-root `_test_output/` tree that
all prior stages use. The dry-run commands above still hold; only the
`-OutputDir` value changed. F34-PATH-01 evidence and the regeneration at the
correct path are recorded in
[part 05](part-05-rework-path-and-event-model-20260630.md).

## Review recommendation

Recommend implementation review PASS if hygiene checks pass. QA should next add
test-plan coverage for server-backed sequential and concurrent replay using the
new dry-run artifacts as preflight input.
