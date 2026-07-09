# Stage 35 QA report developer review

Report reviewed: [test-report-20260708-01.md](test-report-20260708-01.md)
Date: 2026-07-08
Reviewer: Developer
Verdict: REWORK

## Scope

This is a test-results review for the Stage 35 upstream-merge regression run.
No code fix, merge abort, commit, push, PR, reviewer response, or broad test
rerun was performed.

Inputs reviewed:

- Stage 35 design and implementation handoff.
- Stage 35 regression plan Part 40 and Manager test-plan gate.
- QA report `test-report-20260708-01.md`.
- Coverage target build log:
  `_test_output/stage35-upstream-merge-20260708-01/coverage/coverage-target-build.log`.
- Narrow source inspection of `hybrid_cache_controller`,
  `tests/test-step10-metrics.cpp`, `tests/test-cache-controller.cpp`,
  `tests/CMakeLists.txt`, and `run_coverage.ps1`.

## Verdict

REWORK. QA's FAIL verdict is valid because required row TP-35-COV-01 did not
execute: the focused coverage target build failed before OpenCppCoverage could
run.

This is not a product bug in the Stage 35 merged runtime path. The clean build,
direct cache controller, cache `ctest`, route probes, router smoke, stream
smoke, metrics checks, and Stage 34 synthetic dry-run all passed in the QA
report. The only failing evidence is a compile failure in a coverage-only test
target.

This is test and coverage-target drift. `tests/test-step10-metrics.cpp` still
calls `hybrid_cache_controller::process_completions()` at lines 101, 103, 189,
and 253. The current controller API intentionally removed that method: the
header says the async completion drain was removed and demotion/promotion now
execute synchronously through `tx_demote_payload` and `tx_promote_payload`.
`tests/test-cache-controller.cpp` also has Stage 25 regression coverage for
"no async completion drain".

Classification:

| Finding | Classification | Owner | Decision |
| --- | --- | --- | --- |
| F35-QA-01 / TP-35-COV-01: `test-step10-metrics.cpp` calls removed `process_completions` API. | Test/coverage target drift. | Developer. | REWORK. Update the stale coverage test or coverage target set, then rerun TP-35-COV-01. |

It is not a harness issue: OpenCppCoverage was present, and the row failed
before coverage execution because MSVC could not compile `test-step10-metrics`.
It is not an accepted blocker: Part 40 requires focused coverage when
feature-mode source files changed, and no Manager-approved coverage blocker is
recorded for this run.

## Root cause

Stage 25/28 moved cache demotion and promotion completion handling from an async
drain model to synchronous transactional operations. The production header and
main cache-controller regression tests were updated for that contract, but the
older Stage 10 metrics coverage test was left on the retired async API. Because
`run_coverage.ps1` still includes `tests/test-step10-metrics.cpp` and target
`test-step10-metrics`, the Stage 35 coverage package now fails at compile time.

Evidence:

- `tools/server/server-cache-hybrid.h:332-359`: documents removal of
  `process_completions`, synchronous `tx_demote_payload` /
  `tx_promote_payload`, and no completion drain in `tx_update`.
- `tests/test-cache-controller.cpp:5354-5358`: regression comment records that
  `process_completions` was removed and there is no queued completion to drain.
- `tests/test-step10-metrics.cpp:101`, `:103`, `:189`, `:253`: stale calls to
  the removed method.
- `tests/CMakeLists.txt:300-305` and
  `._design_docs/cache-handling-test-scripts/run_coverage.ps1`: the stale test
  remains part of the coverage target set.

## Required fix scope

Developer should update the coverage test path, not production cache behavior.
Acceptable fixes:

- Preferred: update `tests/test-step10-metrics.cpp` so it drives the current
  synchronous cache API and asserts the same Stage 10 metrics/diagnostic
  contract without `process_completions`.
- Alternative, only if the test is obsolete: replace the coverage target entry
  with current tests that cover the same metrics rows, and document why the old
  Stage 10 target is no longer binding.

Do not reintroduce `hybrid_cache_controller::process_completions()` just to
make the old test compile. That would conflict with the Stage 25/28 no-drain
contract unless a fresh design change explicitly reopens that behavior.

## Retest scope

After the test/coverage fix:

1. Rebuild the focused coverage target set that failed:

```powershell
cmake --build build-stage35-qa --config Release --target llama-server test-cache-controller test-step10-metrics test-stage10-cold-store-hardening test-step6-demotion-protocol test-step7-promotion-protocol test-step11-test-hooks-fault-injection test-step12-branch-graph test-step13-stage8 -j 8
```

2. Run TP-35-COV-01 through the Stage 35 coverage command:

```powershell
pwsh -NoProfile -File ._design_docs\cache-handling-test-scripts\run_coverage.ps1 `
  -BuildDir build-stage35-qa `
  -OutDir _test_output\stage35-upstream-merge-20260708-01\coverage-rerun
```

3. Record markdown combined, product-only, and per-file coverage blocks from
   the rerun, not XML root attributes.
4. Repeat the Stage 35 source-ref/open-merge proof around the rerun.

If the fix touches only tests or coverage scripts, the prior QA PASS rows do
not need a full rerun for this Developer review. Manager may still request a
broader retest before closure. If production cache code changes, rerun the
affected Stage 35 rows at minimum: TP-35-CORE-01, TP-35-CORE-02, TP-35-MET-01,
TP-35-MET-02, TP-35-AG-01, and TP-35-COV-01.

## Handoff

Next owner: Developer.

Next action: fix the stale Stage 10 metrics coverage test or its coverage
target mapping, then run the focused TP-35-COV-01 retest. Stage 35 remains open
with QA report verdict FAIL until coverage evidence passes or Manager accepts a
documented blocker.
