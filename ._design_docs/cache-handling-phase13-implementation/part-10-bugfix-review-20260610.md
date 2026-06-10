VERDICT: REWORK

# Stage 13 bug-fix review 2026-06-10

- Date: 2026-06-10
- Reviewer: Architect
- Scope: bug-fix implementation review for S13-BUG-20260610-02-01 through S13-BUG-20260610-02-03

Source: [../cache-handling-phase13-implementation.md](../cache-handling-phase13-implementation.md)
Fix record: [../.test_reports/test-report-20260610-02-fixes.md](../.test_reports/test-report-20260610-02-fixes.md)
Design baseline: [../cache-handling-phase13-design.md](../cache-handling-phase13-design.md)
Architecture baseline: [../cache-handling-architecture/part-08-stage-13-endpoint-compatibility-corrections.md](../cache-handling-architecture/part-08-stage-13-endpoint-compatibility-corrections.md)

## Verdict

REWORK. The marker-normalization and degraded-diagnostic fixes are acceptable,
and the restore assignment in `server-context.cpp` now preserves cloned
`server_tokens`. The MTMD cache-identity fix is incomplete because the compiled
hybrid controller still uses `server_tokens::get_tokens()` in live cache helper
paths that can receive MTMD prompts.

## Findings

| ID | Severity | Finding | Evidence |
| --- | --- | --- | --- |
| S13-BUGFIX-REVIEW-01 | Blocker | MTMD cache identity is not fixed across the live hybrid controller. `server_tokens::cache_token_ids()` preserves placeholders and keeps the inference-only `get_tokens()` assertion intact, but `server-cache-hybrid.cpp` still calls `get_tokens()` in cache identity helpers and admission/lookup paths. MTMD save, lookup, branch-node creation, prefix indexing, rematerialization, and checkpoint checksum validation can still trip the `GGML_ASSERT(!has_mtmd)` that S13-BUG-20260610-02-01 was meant to remove. | `tools/server/server-cache-hybrid.cpp:12`, `tools/server/server-cache-hybrid.cpp:205`, `tools/server/server-cache-hybrid.cpp:1520`, `tools/server/server-cache-hybrid.cpp:1546`, `tools/server/server-cache-hybrid.cpp:2188`, `tools/server/server-cache-hybrid.cpp:2284`, `tools/server/server-cache-hybrid.cpp:2302`, `tools/server/server-cache-hybrid.cpp:2800`, `tools/server/server-cache-hybrid.cpp:2910`, `tools/server/server-cache-hybrid.cpp:3520`, `tools/server/server-cache-hybrid.cpp:3557`; `tools/server/CMakeLists.txt:27` confirms the file is compiled. |

## Evidence reviewed

- `cache-handling-architecture.md` and Part 8 Stage 13 endpoint compatibility corrections.
- `cache-handling-phase13-design.md` and Parts 1 through 3.
- `cache-handling-phase13-implementation.md`, Part 8 implementation evidence, and Part 9 implementation review.
- Stage 13 QA plan Part 23.
- `test-report-20260610-02.md`, `test-report-20260610-02-developer-review.md`, and `test-report-20260610-02-fixes.md`.
- Code: `tools/server/server-common.h`, `tools/server/server-common.cpp`, `tools/server/server-context.h`, `tools/server/server-context.cpp`, `tools/server/server-cache-hybrid.cpp`, and `tests/test-cache-controller.cpp`.

## Assessment

`server_tokens::cache_token_ids()` itself is correctly scoped. It returns the raw
token vector, including `LLAMA_TOKEN_NULL` MTMD placeholders, while
`get_tokens()` still asserts on MTMD and remains the inference-only accessor.
That part does not weaken inference assertions.

MTMD restore in `server-context.cpp` is directionally correct. Both restore paths
now assign `it_best->tokens.clone()` and call `keep_first()`, so media chunk
metadata is copied instead of rebuilt from scalar token IDs. This avoids the
scalar-token rebuild bug in the reviewed restore assignment.

Default marker normalization is acceptable. `process_mtmd_prompt()` translates
the documented `<__media__>` marker to the runtime marker only when the prompt
does not already contain the runtime marker. It does not add a public request
field, response field, or cache-control surface.

Degraded diagnostic logging now uses the bounded info line:
`source`, `method`, `degraded`, token count, and boundary count. The format does
not include prompt text, media bytes, tool arguments, checksums, request bodies,
or response bodies.

Focused tests are not enough for QA handoff because they cover only the new
accessor. `test_stage13_cache_token_ids_keep_mtmd_placeholders()` does not put
MTMD tokens through `hybrid_cache_controller` admission or lookup, where the
remaining assertion-backed calls live.

## Required corrections

- Replace cache-identity uses of `get_tokens()` in the compiled hybrid
  controller with `cache_token_ids()` where MTMD placeholders are valid cache
  identity input.
- Add focused coverage that runs MTMD placeholder tokens through the live
  hybrid controller path, at least admission plus prefix/index or lookup.
- Keep inference callers on `get_tokens()` so MTMD assertions still protect
  scalar-only inference paths.

## Doc alignment

The new review artifact records the current gate state. The Stage 13
implementation entry and document index point to this REWORK review. The
developer fix report remains input evidence and is superseded by this review
for gate status. Documents reviewed or written are under the 300-line split
limit.

## Next owner and gate

Next owner: Developer bug-fix loop.

Next gate: Architect re-review of S13-BUGFIX-REVIEW-01, then QA rerun of
E13-01c, E13-07, E13-08, E13-14, and E13-16 only after review PASS.
