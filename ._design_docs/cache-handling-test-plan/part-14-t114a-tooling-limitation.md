# Cache handling test plan - Part 14: T114a tooling limitation addendum

Source:
[part-13-t114-product-only-coverage.md](part-13-t114-product-only-coverage.md)

- Date: 2026-06-04
- Owner: Architect
- Source of action: Stage 11 closure record
  [part-09-stage11-closure.md](../cache-handling-phase11-implementation/part-09-stage11-closure.md).

This addendum records a known tooling limitation that
prevented the T114a lift attempt on the Stage 11 cycle
from reaching the 70% floor. The 70% floor and the 11-file
product-only denominator in
[part-13-t114-product-only-coverage.md](part-13-t114-product-only-coverage.md)
are unchanged. This is a documentation addendum, not a
relaxation of the contract.

## What happened

The Stage 11 T114a lift attempt commit `023fe967d` added 3
focused test functions to `tests/test-cache-controller.cpp`
to exercise the uncovered .h inline method bodies called
out in the rerun-fixes handoff:

| New test function | Targeted header surface |
| --- | --- |
| `T114a_test_hybrid_entry_inline_via_fn_ptr` | `server-cache-hybrid.h` lines 213-246 (`hybrid_cache_entry` inline methods) |
| `T114a_test_hybrid_cold_store_hooks_via_fn_ptr` | `server-cache-hybrid.h` lines 355-365 (test hooks open/start/stop triad) |
| `T114a_test_hybrid_remaining_test_hooks_via_fn_ptr` | `server-cache-hybrid.h` lines 366-389 (queue capacity, validation/read failure, residency query, promotion failure inject/clear, cold-store/io-worker accessors) |

The 83-test build passed cleanly. The full `build-cov/`
rebuild and coverage rerun produced a product-only rate
that is unchanged from the pre-attempt value:

| Metric | Pre-attempt | Post-attempt |
| --- | --- | --- |
| `Product-only line rate` | 0.6974 | 0.6974 |
| `Product-only covered` | 2077 / 2978 | 2077 / 2978 |
| `70% threshold` | FAIL | FAIL |
| `server-cache-hybrid.h` | 83 / 140 | 83 / 140 |
| `server-cache-controller.h` | 2 / 5 | 2 / 5 |
| `server-cache-legacy.h` | 0 / 1 | 0 / 1 |

The T114a row is FAIL by 0.0026 (0.6974 < 0.70, 2077 / 2978
lines).

## Root cause: MSVC `/Ob2` inlining

The 0-line lift is caused by OpenCppCoverage on this MSVC
host tracking the .h line as the executed source line only
when the inline method body is emitted as a real function
call. The default `/Ob2` inlining inlines the .h inline
method bodies into the test call site, and the .h source
line is lost in the debug info. The same issue affects the
.cpp lambda bodies in `server-cache-policy-lru.cpp` (lines
18, 19, 21, 24, 27, 28, 31, 32): the prior T114 tests call
`plan_evictions` with 3 candidates, but the lambda body
lines are not credited because the lambda is inlined into
`plan_evictions`.

The new test functions do call the inline method bodies at
runtime, but the test call site is the only place the .h
source line is mapped, and the inline methods are inlined
into that call site. The coverage tool credits the call
site, not the original .h line.

## Follow-up plan

The follow-up owner is the next Developer who opens a
T114a fix session under a future stage. The plan has four
options, in order of preference:

- Disable `/Ob2` inlining for the `test-cache-controller`
  target so the .h inline method bodies are emitted as
  real function calls. Suggested change: add `/Ob1` to
  the `CMAKE_CXX_FLAGS_RELEASE` for the test target only,
  or scope a
  `target_compile_options(test-cache-controller PRIVATE /Ob1)`
  override into `tests/CMakeLists.txt`. Single-line config
  change with no source-level edit and a fast
  rebuild-and-rerun cycle.
- Mark the affected .h inline methods with
  `__declspec(noinline)` so the compiler does not inline
  them. Suggested scope: the inline methods in
  `server-cache-hybrid.h` lines 213-246, 355-365, and
  366-389, plus the lambda bodies in
  `server-cache-policy-lru.cpp` lines 18-32.
- Replace the OpenCppCoverage harness with a coverage
  tool that tracks inlined .h bodies (for example, a
  clang-based source-based coverage tool).
- Accept the gap as a permanent tooling limitation and
  document it in the test plan. The Manager chose a
  hybrid of this option plus the first option: the
  limitation is recorded in the closure record now, and a
  future stage applies the `/Ob1` change to verify the
  rate can be lifted.

Lift condition: the next Developer fix session applies
option 1 first, performs a full `build-cov/` rebuild, and
runs a fresh coverage rerun. If the product-only rate is
at or above 0.70, the T114a row is reclassified to PASS
in the next test report and the T114a tooling limitation
addendum is retired. If the rate is still below 0.70, the
session escalates to option 2.

## What this addendum does not change

- The 70% T114a floor is unchanged.
- The 11-file product-only denominator is unchanged.
- The T114 combined 80% floor is unchanged.
- The T114 evidence-source rule (cite the `## Combined
  result` block, not the Cobertura XML root attributes) is
  unchanged.
- The T114a evidence-source rule (cite the `## Product-only
  result` block) is unchanged.
