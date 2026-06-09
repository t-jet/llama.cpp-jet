# Test report 20260607-01 fixes

Source report: [test-report-20260607-01.md](test-report-20260607-01.md)
Date: 2026-06-07
Owner: Developer

## Scope

Fix the current-head `test-cache-controller` blocker that prevents QA
from rerunning T114 and T114a coverage.

## Root cause

- Two calls to `debug_admit_checkpoint_for_tests(..., 2)` and
  `debug_admit_checkpoint_for_tests(..., 3)` became ambiguous after the
  helper gained both `bool` and `int64_t` three-argument overloads.
- The Stage 10 payload debug fault test referenced
  `payload_debug_fault::evicted_residency`, but current HEAD does not
  define that enum value. The same file already has a public test hook
  for evicting the first payload.
- After the compile fix, the focused binary exposed stale helper and test
  assumptions:
  - `debug_add_entry_for_tests(tokens)` created no valid descriptor-era
    payload and stored the base namespace, while lookup uses the
    empty-metadata namespace.
  - Budget eviction removed payload bytes but left evicted entries in the
    entry list, so token counts and payload-bearing entry counts did not
    drop under token or byte pressure.
  - Empty-token lookup could enter branch lookup and find a zero-length
    candidate.
  - No-context checkpoint tests produced an `unsupported` workload profile
    even when the test was exercising checkpoint-specific behavior.
  - Several Stage 10 focused assertions did not match current async
    promotion, failure-helper return, descriptor-counter, metric-shape,
    and checkpoint-boundary validation behavior.

## Fix plan

- Cast the two token-span arguments to `int64_t` so the intended overload
  is selected.
- Replace the missing `evicted_residency` fault injection with
  `debug_evict_first_payload_for_tests()` in the evicted residency block.
- Make the test helper create a valid one-byte exact-blob payload and use
  the empty-metadata namespace for default add/refresh paths.
- Preserve the Stage 3 full cached-entry prefix restore contract: reject
  divergent partial blob matches and allow cached full-state blobs that
  are complete prefixes of the query.
- Keep Stage 8 branch metadata after budget eviction, but remove evicted
  entries from the payload-bearing entry list so token and payload-budget
  tests observe reduced entry/token counts.
- Drain I/O completions after worker stop so async demotion/promotion
  results are not stranded in tests.
- Align stale focused tests with current contracts for namespace matching,
  checkpoint boundary spans, async promotion failures, descriptor counters,
  metric-shape privacy checks, and failure-helper return values.
- Build `test-cache-controller` in `build-cov`, then run the focused
  binary.

## Evidence

- Code patch applied:
  - `tests/test-cache-controller.cpp`: token-span overload calls now use
    `int64_t{2}` and `int64_t{3}`.
  - `tests/test-cache-controller.cpp`: evicted-residency block now uses
    `debug_evict_first_payload_for_tests()`, matching the current test
    hook surface.
  - `tools/server/server-cache-hybrid.cpp`: default debug entries now
    carry a valid target payload and the same empty-metadata namespace
    used by lookup; empty-token lookup returns miss; budget eviction
    removes evicted entries while leaving branch metadata; stopped I/O
    workers can still drain queued completions; test-only checkpoint
    descriptors use a checkpoint-capable profile without a llama context;
    multimodal dynamic-token mode participates in compatibility-key
    hashing; debug payload eviction updates payload eviction counters.
  - `tools/server/server-cache-hybrid.h`: declares the entry-removal helper
    used by the budget eviction path.
  - `tests/test-cache-controller.cpp`: stale namespace setup, checkpoint
    boundary span, async promotion-failure expectations, failure-helper
    assertions, descriptor-counter expectations, metric-shape assertions,
    metadata-only conversion setup, and inline size expectation now match
    current behavior.
- Build command:
  `cmake --build build-cov --config Release -j --target test-cache-controller`
  PASS, exit code 0. Evidence from terminal:
  `test-cache-controller.vcxproj -> D:\source\llama.cpp-jet\build-cov\bin\Release\test-cache-controller.exe`.
- Focused binary command:
  `build-cov\bin\Release\test-cache-controller.exe` with
  `build-cov\bin\Release` prepended to `PATH`. Result: PASS, exit code 0.
  Evidence from terminal: `All tests passed successfully!` and `Total: 87 tests`.

## Handoff

The compile and focused runtime blockers are fixed. QA can rerun the
T114/T114a coverage flow from `build-cov`.
