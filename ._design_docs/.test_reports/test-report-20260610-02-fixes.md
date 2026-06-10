# Stage 13 bug-fix loop for test-report-20260610-02

Date: 2026-06-10
Owner: Developer bug-fix loop
Input reports:

- [test-report-20260610-02.md](test-report-20260610-02.md)
- [test-report-20260610-02-developer-review.md](test-report-20260610-02-developer-review.md)

Evidence root: [test-report-20260610-02-artifacts/](test-report-20260610-02-artifacts/)

## Scope

This fixes the three product bugs from the Developer review:

| Bug ID | Rows | Status |
| --- | --- | --- |
| S13-BUG-20260610-02-01 | E13-01c, E13-07, E13-08 | Rework corrected in code; ready for Architect re-review, then CUDA endpoint rerun. |
| S13-BUG-20260610-02-02 | E13-01c | Fixed in code; needs CUDA endpoint rerun. |
| S13-BUG-20260610-02-03 | E13-14 | Fixed in code; needs endpoint log check rerun. |

No full QA rerun was performed in this session. That remains the next gate
after Architect review.

## Root cause

S13-BUG-20260610-02-01 had two cache-path assumptions that were false for
MTMD requests. Hybrid cache lookup and checksum helpers called
`server_tokens::get_tokens()`, which asserts when the token list contains MTMD
media placeholders. Restore code rebuilt slot prompts by pushing scalar token
IDs, which cannot represent MTMD chunks.

S13-BUG-20260610-02-02 came from marker handling before `mtmd_tokenize`.
llama-server uses a runtime media marker from `get_media_marker()`, while the
documented native prompt shape may still send the MTMD default marker
`<__media__>`. When the runtime marker differed, MTMD tokenization could not
match prompt markers to supplied media.

S13-BUG-20260610-02-03 came from degraded diagnostics using debug logging.
The request could complete and still leave QA without the required bounded
`cache metadata:` line in the captured server log.

## Fix scope

| File | Change |
| --- | --- |
| `tools/server/server-common.h` | Added `server_tokens::cache_token_ids()` for cache identity code that must preserve MTMD placeholders. |
| `tools/server/server-common.cpp` | Implemented `cache_token_ids()` and normalized default MTMD media markers to the runtime marker before tokenization. |
| `tools/server/server-context.cpp` | Switched cache checksum and branch token-vector helpers to `cache_token_ids()`, restored cached prompt tokens through `server_tokens::clone()` plus `keep_first()`, and promoted bounded degraded metadata diagnostics from debug to info logging. |
| `tests/test-cache-controller.cpp` | Added a focused Stage 13 regression for placeholder-preserving cache token ids. |
| `._design_docs/cache-handling-phase13-implementation.md` | Updated current gate and handoff after this bug-fix loop. |
| `._design_docs/cache-handling-phase13-implementation/part-08-implementation-evidence.md` | Added the 2026-06-10 bug-fix addendum. |
| `._design_docs/document-index.md` | Added this fix report to the Stage 13 report index. |

## Focused evidence

| Command | Result |
| --- | --- |
| `cmake --build build --config Release --target test-cache-controller` | PASS, exit 0. |
| `build\bin\Release\test-cache-controller.exe` | PASS, exit 0. Output includes `Stage 13 MTMD cache token ids... PASSED` and `All tests passed successfully! Total: 88 tests`. |
| `ctest --test-dir build -C Release -R test-cache-controller --output-on-failure` | PASS, exit 0. `1/1 Test #28: test-cache-controller ............ Passed`. |
| `cmake --build build --config Release --target llama-server` | PASS, exit 0. Built `build\bin\Release\llama-server.exe`. |

## Remaining risk

The focused unit test covers the cache-token representation and the build
covers the server route/runtime objects. It does not prove CUDA Qwen2.5 VL,
Qwen2.5 Omni, audio transcription, or endpoint miss/hit/restore behavior.

The MTMD restore path now preserves token placeholders and copied media chunk
metadata in slot prompts, but real restore semantics still need the model-backed
CUDA endpoint rerun because state payloads and media chunk processing are not
exercised by `test-cache-controller`.

## Retest scope

QA should rerun the failed rows from `test-report-20260610-02.md`:

- E13-01c with CUDA Qwen2.5 VL or Omni multimodal fixture, proving successful
  native `/completion` behavior and cache miss then hit or restore evidence.
- E13-07 and E13-08 with the CUDA Omni audio fixture, proving no process abort
  or connection reset.
- E13-14 native and chat degraded probes, proving the bounded `cache metadata:`
  diagnostic line is present and leakage scans still pass.
- E13-16 clean build and fresh report gate for the rerun.

## Rework correction 2026-06-10

Architect review
[S13-BUGFIX-REVIEW-01](../cache-handling-phase13-implementation/part-10-bugfix-review-20260610.md)
found that `server-cache-hybrid.cpp` still used
`server_tokens::get_tokens()` in compiled hybrid-controller cache identity
paths. That accessor asserts on MTMD prompts, so the first fix did not cover
live admission and lookup.

Correction:

- `tools/server/server-cache-hybrid.cpp` now uses
  `server_tokens::cache_token_ids()` for cache identity, token-span checksum,
  exact-match lookup, namespace validation, and prefix indexing.
- The scalar-only assertion remains on `get_tokens()` for inference callers.
- `tests/test-cache-controller.cpp` adds
  `test_stage13_hybrid_admits_and_finds_mtmd_placeholders()`, which pushes
  MTMD placeholder tokens through live `hybrid_cache_controller` admission and
  lookup. This test would hit the old `get_tokens()` assertion before the
  correction.

Rework evidence:

| Command | Result |
| --- | --- |
| `cmake --build build --config Release --target test-cache-controller` | PASS, exit 0. |
| `build\bin\Release\test-cache-controller.exe` | PASS, exit 0. Output includes `Stage 13 hybrid MTMD admission and lookup... PASSED` and total `89 tests`. |
| `ctest --test-dir build -C Release -R test-cache-controller --output-on-failure` | PASS, exit 0. `1/1 Test #28: test-cache-controller ............ Passed`. |
| `cmake --build build --config Release --target llama-server` | PASS, exit 0. Built `build\bin\Release\llama-server.exe`. |

Architect re-review
[part-11-bugfix-re-review-20260610.md](../cache-handling-phase13-implementation/part-11-bugfix-re-review-20260610.md)
passed with zero open findings.

Next owner: QA focused rerun for E13-01c, E13-07, E13-08, E13-14, and E13-16.
