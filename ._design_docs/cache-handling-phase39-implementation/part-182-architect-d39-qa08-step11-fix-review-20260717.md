# Part 182: Architect D39-QA-08 Step 11 fix review

Date: 2026-07-17
Status: PASS
Scope: D39-QA-08 Step 11 stale async test correction

## Verdict

PASS. Part 181 and `test-report-20260717-08-fixes.md` correctly port
`tests/test-step11-test-hooks-fault-injection.cpp` to the current synchronous
transaction controller. The correction is test-only and does not change product
code, TP-39-03 workload, fixtures, budgets, thresholds, seams, or coverage
scripts.

The repair matches the Stage 25/28 API model:

- Demotion coverage uses `hybrid_cache_controller::tx_demote_payload`.
- Promotion coverage uses `hybrid_cache_controller::tx_promote_payload`.
- Residency assertions occur after the transaction returns.
- Cold read validation faults are exercised by corrupting committed `.cold`
  bytes before synchronous promotion.
- Demotion write failure still uses the current cold-store write-failure hook.

## Review checks

| Check | Result | Evidence |
| --- | --- | --- |
| Step 11 port is test-only | PASS | Reviewed diff scope: `tests/test-step11-test-hooks-fault-injection.cpp`, Part 181, and fix report. No product-code edit is part of this correction. |
| Sync transaction model | PASS | Current `server-cache-io-worker.h` exposes only inline execution helpers; `server-cache-hybrid.h` removes `process_completions` and names `tx_demote_payload` / `tx_promote_payload` as the synchronous demotion/promotion surface. |
| Meaningful fault coverage retained | PASS | Step 11 still covers residency query, promotion failure injection, cold-store wiring, inline demote/promote success, target checksum, header read failure, payload id, pair state, format, demotion write failure, draft checksum, magic, and header checksum failures. |
| Async-only rows retired with rationale | PASS | Delay, queue-capacity, queue-full demotion, queue-full promotion, and shutdown-race rows now state that no worker queue or background worker exists, then assert stable sync behavior and zero queue-pressure counters where applicable. |
| No product/design mismatch masked | PASS | The current product implementation and Stage 25 migration contract agree: demote/promote work executes inline in `tx_demote_payload` / `tx_promote_payload`; no compatibility shim or restored async queue is needed. |
| Retired async active-call audit | PASS | D39-QA target-set search found no active calls to `debug_set_completion_delay_for_tests`, `debug_set_io_worker_queue_capacity_for_tests`, `process_completions`, `debug_start_io_worker_for_tests`, or `debug_stop_io_worker_for_tests`. Remaining matches in target files are comments documenting retired paths. |

## Retired symbol audit

Target set audited from the D39-QA-08 build command:

- `test-cache-controller`
- `test-step1-state-machine`
- `test-step2-cold-store`
- `test-step3-4-cold-store-write-read`
- `test-step9-startup-validation`
- `test-step10-metrics`
- `test-step6-demotion-protocol`
- `test-step7-promotion-protocol`
- `test-step11-test-hooks-fault-injection`
- `test-stage10-policy-lru`
- `test-stage10-cold-store-hardening`
- `test-step12-branch-graph`
- `test-step13-stage8`

Audit command:

```powershell
rg -n "debug_set_completion_delay_for_tests|debug_set_io_worker_queue_capacity_for_tests|process_completions|debug_start_io_worker_for_tests|debug_stop_io_worker_for_tests" <D39-QA target files>
```

Result: no active calls. The matches are comments in
`tests/test-cache-controller.cpp` that explain the Stage 28 retirement of the
async hooks or record historical pre-fix context. `tests/test-step11-test-hooks-fault-injection.cpp`
has no matches.

## Evidence accepted

Part 181 records the required focused repair evidence:

- Fresh seam-ON Release configure: PASS.
- Focused `test-step11-test-hooks-fault-injection` build: PASS.
- Repaired executable: PASS, all 17 Step 11 rows passed.
- Retired-symbol search in the repaired Step 11 file: PASS, no matches.

I did not rerun the executable in this review. The accepted gate evidence is the
Developer-recorded focused build and run in Part 181 plus source review against
the current headers and target-set symbol audit.

## Handoff

State: ready for QA rerun gate.

Manager may authorize QA to repeat the D39-QA-08 order from Part 179: clean
seam-ON Release full target build, PowerShell 7/5 parser and pure checks, one
canonical TP-39-03 node, then the four coverage blocks only after full
`Assert-Tp3903` PASS. Coverage remains blocked until canonical TP-39-03 passes.
