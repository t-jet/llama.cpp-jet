# Stage 39 QA report 20260712-03 fixes

Date: 2026-07-12
Status: READY FOR ARCHITECT REVIEW; QA RETEST REQUIRED

## Corrective actions

| Finding | Result | Evidence |
| --- | --- | --- |
| F39-QA3-01 | Fixed | Exporter omits row `mode`; focused decision and transaction rendering proves one `mode` label per sample; live script rejects duplicate label names. |
| F39-QA3-02 | Fixed | Stage 10 gauge uses committed file size and verifies header plus payload size. |
| F39-QA3-03 | Open, QA workload | Live equal-rank tuple, payload order, and victim inventory still required. |
| F39-QA3-04 | Open, QA workload | No-eligible-victim production precondition still required. |
| F39-QA3-05 | Open, QA workload | Measured pair must be bound to pressured candidate. |
| F39-QA3-06 | Open, infrastructure | OpenCppCoverage must produce a real smoke `.cov`; 80% threshold remains binding. |

## Focused retest

Release builds and direct runs passed for `test-step10-metrics`,
`test-cache-controller`, and `test-chat-peg-parser`. The Step 10 run includes the
new exporter regression. No live model run or coverage run was claimed.

## Handoff

Architect reviews code and focused tests next. QA then reruns TP-39-02,
TP-39-03, TP-39-04, TP-39-15, the full focused pack, `ctest -R cache`, and real
changed-line coverage. Stage 39 remains open.
