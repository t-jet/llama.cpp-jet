# Part 59: generation proof and driver precondition rework

Date: 2026-07-13
Status: PARTIAL; TP-39-03 workload blocker
Scope: F39-GDIR-01 and F39-GDIR-04 from Architect Part 58

## Changes

F39-GDIR-01 corrections:

- The normal cleanup test now checks the payload-derived file `9862.cold` for
  decimal payload ID 39010.
- Each named test captures a discovery generation and token before its normal
  mutation, submits the captured apply afterward, and requires
  `stale_snapshot` without consumption.
- Test-only observers record committed reconstruction and replay-cleanup
  generations separately. They observe production constructor work; they do
  not replace recovery or cleanup.

F39-GDIR-04 corrections:

- TP-39-03 preflight requires the measured pair to fit both positive lowered
  budgets. Its live assertion requires the incoming pair to fit hot alone,
  aggregate hot candidates to exceed lowered hot, occupied cold bytes plus the
  serialized pair to exceed lowered cold, and zero production-eligible cold
  victims. Exact `evicted/both_filled` and transaction-family delta zero remain
  mandatory.
- TP-39-04 checks both positive startup budgets against the measured pair
  before launch and checks discovery budgets again after admission. Both
  lowered budgets must be smaller than the pair. Exact
  `evicted/oversized_both` and transaction-family delta zero remain mandatory.
- All guarded rows now use the isolated slot-save directory and erase the idle
  slot reference before discovery.

## Generation evidence

`._test_output/stage39-part59-controller-final.log` records:

| Test | Before | Reconstruction | Cleanup | After | Token stale |
| --- | ---: | ---: | ---: | ---: | --- |
| normal cold cleanup | 12 | n/a | n/a | 13 | yes; apply rejected stale |
| committed recovery | 1 | 3 | 4 | 4 | yes; apply rejected stale |
| committed replay cleanup | 1 | 3 | 4 | 4 | yes; apply rejected stale |

The full Release controller suite passed. The corrected cleanup assertion
verified that `9862.cold` was absent after `tx_update()`.

## Driver execution

TP-39-04 passed in `._test_output/stage39-part59-tp3904-02/`:

- measured pair: 8,947,296 resident bytes and 8,947,360 serialized bytes;
- startup budgets: 14,680,064 hot and 14,680,064 cold bytes;
- lowered budgets: 7,340,032 hot and 7,340,032 cold bytes;
- discovered incoming payload 3: 8,488,496 resident bytes;
- exact decision delta: one `evicted/oversized_both`;
- cold transaction-family delta: zero;
- tombstone delta +1, payload-eviction delta +1, hot-descriptor delta -1,
  cold-count delta 0;
- before/after generation: 51 to 63; zero retained incoming hot or cold part.

TP-39-03 stopped after one measured attempt, as directed. Preserved discovery
in `._test_output/stage39-part59-tp3903/` proved:

- startup budgets: 18,874,368 hot and 18,874,368 cold bytes;
- lowered budgets: 9,437,184 hot and 9,437,184 cold bytes;
- incoming payload 2: 8,373,796 resident bytes, so it fits lowered hot;
- aggregate hot bytes: 16,862,292, so lowered hot is under pressure;
- occupied cold payload 1: 8,259,160 serialized bytes; adding the measured
  8,947,360-byte pair exceeds lowered cold;
- payload 1 remained a production-eligible cold victim.

The controller rejected apply with `invalid_tp39_03_setup`, so no decision or
transaction tuple was emitted. The corrected driver now fails instead of
calling this `both_filled`. Normal completion admissions do not establish the
required occupied-cold/no-eligible-victim combination. Do not weaken exact-set
validation or mutate ownership without reviewed Manager and Architect
direction.

## Verification

| Check | Result | Artifact |
| --- | --- | --- |
| Seam-ON Release controller build | PASS | `stage39-part59-build-final.log` |
| Full Release controller suite | PASS | `stage39-part59-controller-final.log` |
| Seam-ON Release server build | PASS | `stage39-part59-server-build-final.log` |
| Guarded route suite | PASS, 13 tests | `stage39-part59-route-tests-final.log` |
| PowerShell 7 self-test | PASS | `stage39-part59-selftest-pwsh7-final.log` |
| Windows PowerShell 5 self-test | PASS | `stage39-part59-selftest-powershell5-final.log` |
| Model-backed TP-39-04 | PASS | `stage39-part59-tp3904-02/` |
| Model-backed TP-39-03 | BLOCKED at exact setup | `stage39-part59-tp3903/` |

Coverage remains QA-owned and was not run.

## Handoff

F39-GDIR-01 is ready for Architect re-review. TP-39-04's F39-GDIR-04 evidence
is ready. TP-39-03 needs a reviewed, reachable production workload for occupied
cold capacity with no eligible victim. Manager disposition is required before
more implementation or model attempts.
