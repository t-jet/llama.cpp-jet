# Part 64: TP-39-03 owner-reassignment implementation evidence

Date: 2026-07-13
Status: PARTIAL; MODEL-BACKED REACHABILITY BLOCKED
Authority: D39-EXEC-05, design Part 19, implementation Parts 60-63

## Implemented scope

The guarded apply request accepts
`tp39_03_cold_owner_setup: "selected_incoming_owner"` only for TP-39-03.
TP-39-03 requires the complete nonempty cold set, no cold ranks, the incoming
owner as the first hot-pressure candidate, and the four budget inequalities.

Apply validates candidate identity, kind links, forest parity, active
references, namespace, pair shape, cold header and store identity, sizes and
checksums, token and position spans, metadata identity, boundary metadata, and
workload profile before consumption. It moves the checkpoint under the cache
lock, advances generation for each write, verifies normal cold selection returns
zero candidates, and calls normal `tx_update()` once. Responses contain bounded
owner-link rows and exclude tokens, nonce, paths, payloads, prompts, and journal
data.

The rollback journal covers descriptors, entry links and accounting, and branch
node mirrors. Injected failures after seven setup write positions restore the
pre-setup inventories, advance generation, leave the seam consumed, and start no
pressure or cold transaction.

Focused success exposed a mixed-kind eviction defect. Evicting a hot exact
payload also evicted its already-cold checkpoint sibling, leaving tracked cold
bytes without a cold descriptor. The eviction path now retains an already-cold
kind and still counts the exact payload eviction. The focused TP-39-03 path then
produces one `evicted/both_filled`, zero cold transactions, one exact tombstone,
a retained checkpoint file and descriptor, retained topology, zero pruning, and
reconciled accounting.

The driver implements Part 62's ten-message Qwen3.5-4B MTP bodies, exact lengths,
source/incoming/source/incoming order, property order, fixed server flags,
checkpoint-only preflight, owner tag, and pass caps. Measurement mode never
sends apply.

## Verification

| Check | Result | Evidence |
| --- | --- | --- |
| Seam-ON Release controller and server build | PASS | `._test_output/stage39-tp03-build-on.log` |
| Full Release controller suite | PASS | `._test_output/stage39-tp03-controller.log` |
| TP-39-03 tag, success, and seven-position rollback tests | PASS | Full controller log |
| Guarded Python route suite | PASS | `._test_output/stage39-tp03-route.log`; 14 passed in 26.69 seconds |
| PowerShell 5 and 7 self-tests | PASS | `._test_output/stage39-tp03-ps5-selftest.log`, `stage39-tp03-ps7-selftest.log` |
| Seam-OFF Release controller and server build | PASS | `._test_output/stage39-tp03-build-off.log` |
| Model-backed measurement | BLOCKED | `._test_output/stage39-tp03-measurement-fresh-20260713/` |
| Fresh canonical apply | NOT RUN | Invalid measurement discovery forbade apply |

Coverage remains QA-owned and was not run.

## Model-backed blocker

The fresh measurement completed all four literal requests in 12 minutes 14
seconds. Source and incoming rendered to 3,631 and 3,632 tokens. Both created
real 50.251 MiB checkpoints. The fixed context also sets the controller token
limit to 4,096:

```text
3631 + 3632 = 7263 > 4096
```

The two required owners cannot coexist. After every alternating save the log
reported `entries: 1`; token-budget enforcement removed the prior cold owner.
After request four the cold root contained no `.cold` payload and discovery
returned `inventory_integrity_error`. Four requests and responses were
preserved. No apply was sent and the seam was not consumed.

An earlier diagnostic attempt stopped during request one at the old 120-second
HTTP timeout. It also sent no apply. The fresh run used a 300-second request
timeout while retaining the binding 15-minute pass cap.

Part 62 fixes context 4,096 and these bodies while requiring a distinct cold
source and hot incoming owner. That preflight is unreachable. This is a reviewed
workload defect, not a passing SKIP. Do not change context, bodies, fillers, or
selection without a new design correction.

## Handoff

Focused implementation is ready for Architect review. Live TP-39-03 and Stage
39 closure remain blocked pending an approved workload correction.
