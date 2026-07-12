# Stage 38 implementation evidence

Source: [../cache-handling-phase38-implementation.md](../cache-handling-phase38-implementation.md)

Date: 2026-07-11
Owner: Developer

## Scope

This implementation covers the two Manager-approved Stage 38 fixes:

- chat strict-prefix restore is accepted only when the request is
  `openai-chat`, the cached entry is a strict token prefix, both request and
  entry carry a matching `[0, prefix)` `MESSAGE_END` boundary, and the prefix
  checksum matches;
- `llamacpp:cache_cold_budget_bytes` now reads the stats value as `int64_t`, so
  `2048` MiB prints as `2147483648` instead of narrowing through `int`.

`/completion` prefix restore remains rejected. Public prompt-token totals were
not changed. Generated output replay was not added.

## Code changes

Changed files:

- `tools/server/server-cache-hybrid.h`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`

Implementation notes:

- Added `validate_strict_prefix_candidate(...)` in the hybrid controller.
- `tx_restore` still chooses exact candidates first. When the selected
  candidate is shorter than the request, it now validates the strict-prefix
  chat contract instead of rejecting all prefixes.
- Accepted prefixes record
  `cache_prefix_candidates_by_shape{result="accepted",reason="accepted_strict_prefix"}`.
  Rejected prefixes keep the bounded miss path.
- Pair-state mismatch still fails through descriptor validation before apply.
- The cold-budget Prometheus writer now calls
  `json_value(cache_stats, "cache_cold_budget_bytes", int64_t(-1))`.

## Tests added

`tests/test-cache-controller.cpp` now covers:

- chat strict-prefix restore plan acceptance and hit finalization;
- `/completion` strict-prefix recompute through `unsafe_prefix_rejected`;
- prefix boundary checksum rejection;
- target/draft pair mismatch rejection before restore apply;
- cold-budget boundary math for `0`, `1`, `2047`, `2048`, `4096`, and `-1`.

## Evidence

The requested default build directory was missing:

```powershell
cmake --build build --config Release --target test-cache-controller
```

Result: `Error: D:/source/llama.cpp-jet/build is not a directory`.

Fallback evidence used `build-cuda`, an existing Release CUDA MSVC tree:

```powershell
cmake --build build-cuda --config Release --target test-cache-controller
```

Result: PASS. MSVC reported existing `%zu` warnings in
`tests/test-cache-controller.cpp`; no Stage 38 compile errors.

```powershell
.\build-cuda\bin\Release\test-cache-controller.exe
```

Result: PASS. The binary reported all 152 tests passed, including the five new
Stage 38 focused tests.

```powershell
ctest --test-dir build-cuda -C Release -R cache --output-on-failure
```

Result: PASS. `test-cache-controller` passed in 0.27 seconds.

```powershell
git diff --check -- tools/server/server-cache-hybrid.h tools/server/server-cache-hybrid.cpp tools/server/server-context.cpp tests/test-cache-controller.cpp .\._design_docs\cache-handling-phase38-implementation.md
```

Result: PASS with no output.

Manual checks for the new untracked part file found LF endings, no trailing
whitespace, no non-ASCII text, and 101 lines.

## Unresolved items

Live model-backed `/v1/chat/completions` evidence was not run in this session.
The remaining gate should still collect public response evidence for
`usage.prompt_tokens_details.cached_tokens`, full `usage.prompt_tokens`,
`timings.cache_n`, positive hybrid hit delta, prefix metrics, and public
Prometheus output for `2147483648`.
