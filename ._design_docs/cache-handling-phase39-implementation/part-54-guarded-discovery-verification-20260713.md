# Part 54: guarded discovery verification

Date: 2026-07-13
Status: PARTIAL - GUARDED DRIVER SHAPE BLOCKED
Scope: final verification and direct corrections for Part 53

## Corrections

- TP-39-02 now sets the cold budget to 320 bytes, the measured serialized
  incoming size. The incoming object fits while both existing 192-byte and
  128-byte victims must be removed. Its transaction assertion compares exact
  before/after deltas instead of aggregate counters that include setup.
- Route fixtures use a 32 MiB hot budget so model-backed requests create real
  hot and cold inventories. Apply requests deep-copy discovery state before
  negative mutations. The idle race uses a valid long-running completion, the
  terminal check reads state from the HTTP error envelope, and the non-loopback
  check requires failed startup without token disclosure.
- The checkpoint exact-set route case removes a discovered checkpoint when the
  fixture produces one. Qwen3-0.6B produces no runtime checkpoints, so its
  executed branch adds an extra checkpoint row and proves exact-set rejection
  without changing the saved discovery baseline.
- Guarded driver discovery now retries the retryable `idle slots` response for
  up to 10 seconds. This closes the response-before-slot-release race.

## Verification

| Check | Exit/result | Artifact |
| --- | --- | --- |
| ON Release `test-cache-controller` and `llama-server` build | 0 | `._test_output/stage39-dev-part54/build-on.log` |
| OFF Release `server-context` build | 0 | `._test_output/stage39-dev-part54/build-off.log` |
| Full controller suite | 0, all tests passed | `._test_output/stage39-dev-part54/controller-final.log` |
| Model-backed guarded route suite | 0, 13 passed | `._test_output/stage39-dev-part54/route-final2.log` |
| PowerShell 5 parse and metric self-test | 0 / 0 | `ps5-parse-final.log`, `ps5-selftest-final.log` |
| PowerShell 7 parse and metric self-test | 0 / 0 | `ps7-parse-final.log`, `ps7-selftest-final.log` |
| Guarded TP-39-02 driver smoke | 1 | `driver-smoke2.log` and `driver-multi-victim2/` |

One controller run after the TP-39-02 fix passed all Stage 39 rows, then hit
the previously disclosed Stage 23 access violation (`0xC0000005`). The
immediate clean rerun passed the full suite. Both artifacts are retained as
`controller-fix3.log` and `controller-final.log`.

## Remaining blocker

The bounded guarded smoke used six Qwen3-0.6B requests, 20 MiB apply hot
budget, and 10 MiB apply cold budget. Discovery succeeded after the new idle
retry. Apply then produced two `retained_cold/cold_room_made` decisions and two
commit deltas because the workload left three hot candidates. TP-39-02 requires
exactly one final decision and one transaction delta. The driver correctly
failed that mismatch.

This is a workload-shaping blocker, not a production or parser failure. The
canonical driver must admit two smaller cold victims and one larger hot
incoming pair before discovery, as test-plan Part 43 requires. Current prompts
produce nearly equal 8.1-8.3 MiB pairs, so lowering the guarded hot budget
pressures two candidates.

## Handoff

F39-GDIR-01 and controller/route portions of F39-GDIR-03 have fresh executable
evidence. F39-GDIR-04 is not ready for Architect closure because guarded driver
smoke remains red. Coverage stays with QA. Fresh Architect re-review should
wait for a corrected model-backed TP-39-02 workload and green guarded smoke.
