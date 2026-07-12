# Stage 38 implementation rework evidence

Source: [../cache-handling-phase38-implementation.md](../cache-handling-phase38-implementation.md)
Review source: [part-04-implementation-review-20260711.md](part-04-implementation-review-20260711.md)

Date: 2026-07-11
Owner: Developer

## Scope

This part closes the two blocking findings (F38-IMPL-01, F38-IMPL-02) and the
non-blocking test-footer cleanup from the Stage 38 implementation review
(part 04). No commits, pushes, staging, or reverts were performed.

Only production code already present in the working tree was reviewed for
correctness; the production fix for F38-IMPL-01 was already applied in the
working tree before this rework session. This session added focused tests and
fixed the test footer.

## F38-IMPL-01: target-plus-draft/MTP prefix restore checkpoint gate

### Root cause

`validate_strict_prefix_candidate` originally gated prefix restore only on the
model-surface `profile == checkpoint_dependent` field.
`detect_workload_profile` maps SWA, recurrent, and hybrid models to
`checkpoint_dependent`, but it does not classify a runtime target-plus-draft or
MTP runtime on its own. A plain-transformer target-plus-draft runtime with a
matching target-and-draft descriptor, openai-chat metadata, a strict token
prefix, and a matching `[0, prefix)` boundary could therefore pass the validator
as a plain strict-prefix restore, violating the Manager design gate.

### Fix mechanism

The working-tree code threads the runtime pair state into the validator and
checkpoint-gates it:

- `tools/server/server-cache-hybrid.h:1038-1044` declares
  `validate_strict_prefix_candidate` with a `payload_pair_state pair_state`
  parameter and a `payload_kind selected_payload_kind` parameter.
- `tools/server/server-cache-hybrid.cpp:2093-2155` implements the validator.
  The checkpoint-or-recompute gate at lines 2147-2151 reads:

  ```cpp
  const bool checkpoint_safe = selected_payload_kind == payload_kind::checkpoint;
  if ((profile == cache_workload_profile::checkpoint_dependent ||
       pair_state == payload_pair_state::target_and_draft) &&
      !checkpoint_safe) {
      return cache_restore_miss_reason::unsafe_prefix_rejected;
  }
  ```

- `tools/server/server-cache-hybrid.cpp:5340-5341` computes the runtime pair
  state in `tx_restore`:

  ```cpp
  const bool runtime_has_draft = ctx_dft != nullptr;
  const payload_pair_state pair_state = runtime_has_draft ?
      payload_pair_state::target_and_draft :
      payload_pair_state::target_only;
  ```

  `ctx_dft` is non-null for both speculative-decoding draft runtimes and MTP
  runtimes, so this single check covers both target-plus-draft and MTP paths.
- `tools/server/server-cache-hybrid.cpp:5393-5403` calls the validator with
  `pair_state` and `selected_payload_kind` whenever the selected candidate is
  shorter than the request, and rejects with `unsafe_prefix_rejected` when the
  gate fails.
- `tools/server/server-cache-hybrid.cpp:1476-1501` exposes
  `debug_validate_strict_prefix_for_tests`, which forces `runtime_has_draft`
  into a `pair_state` value and a `selected_payload_kind` value so the gate can
  be exercised directly without a live draft context.

### Why the gate now holds

Any runtime target-plus-draft (`ctx_dft != nullptr`) or checkpoint-dependent
model profile restores a strict prefix only when the selected payload is a
checkpoint payload. Any exact-blob prefix candidate for those runtimes returns
`unsafe_prefix_rejected` and recomputes. Plain target-only transformers are
unaffected and still accept matching strict prefixes.

### Test added

`test_stage38_target_draft_prefix_requires_checkpoint_safe` (TP-38-PR-06) in
`tests/test-cache-controller.cpp`. It forces four cases through
`debug_validate_strict_prefix_for_tests`:

1. plain-transformer profile, target-plus-draft pair state, exact-blob payload:
   expect `unsafe_prefix_rejected` (must recompute).
2. plain-transformer profile, target-plus-draft pair state, checkpoint payload:
   expect `exact_entry_absent` (accepted).
3. checkpoint-dependent profile, target-only pair state, exact-blob payload:
   expect `unsafe_prefix_rejected` (must recompute).
4. plain-transformer profile, target-only pair state, exact-blob payload: expect
   `exact_entry_absent` (accepted, no regression).

F38-IMPL-01 is closed.

## F38-IMPL-02: focused controller tests for missing gate-critical TP-38 rows

Seven focused tests added to `tests/test-cache-controller.cpp`. All use
`require_or_abort` (explicit `if (!cond) { fprintf(stderr,...); std::abort(); }`),
not `assert`, so they hold in Release builds where `NDEBUG` may be defined.

| TP-38 row | Test function | Coverage gap closed |
| --- | --- | --- |
| TP-38-PR-01 | `test_stage38_exact_repeat_wins_over_prefix` | Exact repeat restore wins and does not route through prefix logic; asserts `accepted_strict_prefix` counter absent after exact restore. |
| TP-38-PR-04 | `test_stage38_namespace_template_tool_drift_rejects` | Template/tool compatibility-key drift splits the namespace and rejects before apply; asserts zero restore hits. |
| TP-38-PR-06 | `test_stage38_target_draft_prefix_requires_checkpoint_safe` | Target-plus-draft and checkpoint-dependent arbitrary-prefix rejection unless checkpoint-safe (ties to F38-IMPL-01). |
| TP-38-PR-07 | `test_stage38_cold_prefix_payload_promotes_or_falls_back` | Cold prefix payload promotes inline or falls back through a bounded restore path with bounded failure count. |
| TP-38-PR-08 | `test_stage38_protected_prefix_metadata_survives_pressure` | Protected prefix metadata survives churn under tight payload budget and still matches a strict-prefix request. |
| TP-38-PR-09 | `test_stage38_generated_output_never_replayed` | A generated-output-only entry is never replayed as a prefix restore for a fresh prompt request. |
| TP-38-MET-01 | `test_stage38_cold_budget_prometheus_gauge_output` | Cold-budget gauge source value is `2147483648` for `2048` MiB, exceeds `INT_MAX` (no narrowing regression), and streams as `2147483648` in the Prometheus gauge line shape. |

The Prometheus gauge test exercises the exact value-feeding expression the
server-context.cpp writer uses (`json_value(stats, "cache_cold_budget_bytes",
int64_t(-1))`) and confirms the streamed `int64_t` output contains
`2147483648`. The Prometheus writer itself is a server-internal lambda and is
not directly callable from the controller unit test; the value-source and
stream-shape evidence here closes the narrowing risk the review called out.

F38-IMPL-02 is closed.

## Non-blocking cleanup: test footer

`tests/test-cache-controller.cpp` previously printed a hard-coded
`Total: 152 tests(...)` footer. A direct count of `test_*();` calls in `main()`
was 163 before this session and is 170 after adding the seven Stage 38 rows.
The footer was historically inaccurate and remains inaccurate, so the
hard-coded exact count was replaced with wording that does not claim an exact
total. The success message and separator lines are unchanged. No product
behavior is affected.

## Code changes by file

| File | Change |
| --- | --- |
| `tests/test-cache-controller.cpp` | Added `#include <limits>`, seven Stage 38 test functions, seven `main()` calls, and replaced the hard-coded footer total with non-exact wording. |

Production code in `tools/server/server-cache-hybrid.h`,
`tools/server/server-cache-hybrid.cpp`, and `tools/server/server-context.cpp`
was already present in the working tree from the prior implementation session
and was reviewed for correctness, not edited in this session.

## Evidence

### Pre-existing dirty state (captured before edits)

```powershell
git -C d:\source\llama.cpp-jet status --short -- tools/ tests/ ._design_docs/cache-handling-phase38-implementation/
```

```text
 M tests/test-cache-controller.cpp
 M tools/server/server-cache-hybrid.cpp
 M tools/server/server-cache-hybrid.h
 M tools/server/server-context.cpp
?? ._design_docs/cache-handling-phase38-design.md
?? ._design_docs/cache-handling-phase38-implementation.md
?? ._design_docs/cache-handling-phase38-implementation/
```

The same set of files was dirty before this session began. The CRLF conversion
of `tools/server/server-cache-hybrid.cpp` (whole file CRLF, 5704 CRLF lines,
HEAD LF-only) is pre-existing from the prior implementation session and was not
introduced or normalized here. `tests/test-cache-controller.cpp` is LF-only with
zero trailing-whitespace lines, matching HEAD.

### Build tree

`build` was missing; `build-cuda` (existing Release CUDA MSVC MSVC tree) was
used, per the Stage 38 implementation log and part-03 evidence.

```powershell
cmake --build build-cuda --config Release --target test-cache-controller
```

Result: PASS. Only pre-existing `%zu` format-string warnings in
`tests/test-cache-controller.cpp` (lines 6005, 6018, 6126) unrelated to Stage
38. No Stage 38 compile errors.

```powershell
cmake --build build-cuda --config Release --target llama-server
```

Result: PASS. Confirms `server-context.cpp` cold-budget gauge fix compiles.

### Focused test binary

```powershell
.\build-cuda\bin\Release\test-cache-controller.exe
```

Result: PASS. All 12 Stage 38 tests passed (5 original + 7 rework rows), no
FAIL lines, footer prints the new non-exact-total wording.

### ctest

```powershell
ctest --test-dir build-cuda -C Release -R cache --output-on-failure
```

Result: PASS. `test-cache-controller` passed in 0.28 seconds. 1/1 tests passed.

### Whitespace and status

```powershell
git -C d:\source\llama.cpp-jet diff --check -- tools/ tests/
```

Result: `tests/test-cache-controller.cpp` is clean (LF-only, no trailing
whitespace). `tools/server/server-cache-hybrid.cpp` reports trailing-whitespace
on every added line because the whole file is CRLF-converted from the prior
session; this is a pre-existing condition documented above, not introduced by
this rework. No normalization was performed because the constraint requires
isolated, rollback-friendly changes and forbids touching legacy/production
lines unrelated to the fix.

## Cross-checks against binding gate constraints

- `/completion` prefix restore remains rejected: `diagnostic_source !=
  "openai-chat"` returns `unsafe_prefix_rejected` before any apply. Covered by
  the existing `test_stage38_completion_strict_prefix_recomputes`.
- Public prompt-token totals are not changed in this session and were not
  changed in the prior session; restored prefix flows only through
  `slot.n_prompt_tokens_cache`, `timings.cache_n`, and
  `usage.prompt_tokens_details.cached_tokens`.
- Only cache-specific fields report restored prefix length.
- Checkpoint-dependent, SWA, recurrent, RS-limited, target-plus-draft, and MTP
  paths restore only from checkpoint-safe points (F38-IMPL-01 gate).
- Correctness wins over hit rate: any validation gap recomputes.

## F38 items closed

- F38-IMPL-01: closed by the checkpoint-or-recompute gate and the
  TP-38-PR-06 focused test.
- F38-IMPL-02: closed by the seven focused TP-38 tests.
- Non-blocking test-footer cleanup: closed by removing the hard-coded exact
  total.

## Unresolved items

Live model-backed `/v1/chat/completions` evidence was not run in this session.
The remaining gate should still collect public response evidence for
`usage.prompt_tokens_details.cached_tokens`, full `usage.prompt_tokens`,
`timings.cache_n`, positive hybrid hit delta, prefix metric rows, and public
Prometheus output for `2147483648` against a running server.

## Handoff

State: rework corrections applied; focused build, test binary, and ctest
evidence collected.

Next owner: Architect implementation re-review.

Do not hand Stage 38 to QA yet.
