# Part 116: D39-EXEC-29 Release-safe controller test evidence

Date: 2026-07-14
Status: BLOCKED; STAGE 23 EXPECTATION FAILED
Authority: Manager Part 115

## Test-only change

Only
`test_stage23_demotion_budget_fallback_stale_completion_checkpoint_attach` in
`tests/test-cache-controller.cpp` changed. Its 12 `assert` calls are now
Release-active `require_or_abort` checks. A separate check requires exactly two
entries before `front()` and `next()` access. The rejected checkpoint admit and
nonempty failure checks are unchanged.

The test source SHA-256 stayed
`8C80FD414C45D9E278D24F2CAAEC1BB26269CF6B025CD599E468935A3EF553BD`
through the build and run window.

## Authorized execution

The sole incremental command was:

```text
cmake --build build-stage39-seam-on --config Release \
  --target test-cache-controller --parallel 2
```

It rebuilt `test-cache-controller.cpp`, linked the executable, and exited zero
in 7.253 seconds. The executable SHA-256 is
`44B29DE9B70C699EF3C1ED130404CCFA795DA40D41E6DCDF8D0DF0CB93EB0147`.
The build log is
`._test_output/stage39-d39-exec29-build.log`.

The sole full controller run exited `-1073740791` (`0xC0000409`) in 1.681
seconds. Before stopping, the seven Stage 39 observed forbidden-effect probes,
midpoint common-epilogue fault, and step-2 common-epilogue fault passed.

The repaired Stage 23 test executed both attach and eviction calls. The second
eviction recorded `retained_cold reason=cold_room_made payload_id=2`, then the
required check failed with:

```text
FAIL: Stage 23 second payload did not become evicted
```

The Stage 23 verdict and suite completion line were not reached. The controller
log is `._test_output/stage39-d39-exec29-controller.log`. No rerun occurred.

## Handoff

D39-EXEC-29 does not meet its controller exit-zero acceptance check. The
Release-only missing-side-effect crash is closed, but the now-active test
exposes a stale or incorrect second-eviction expectation against current
`cold_room_made` behavior. This evidence does not classify the behavior as a
product defect. Fresh review must decide the next bounded correction.

Route faults, server/product changes, pure/model/default/canonical tests,
coverage, and full QA remain blocked.
