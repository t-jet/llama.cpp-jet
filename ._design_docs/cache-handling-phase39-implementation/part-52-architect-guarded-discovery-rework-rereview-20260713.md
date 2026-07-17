VERDICT: REWORK

# Part 52: Architect guarded discovery rework re-review

Date: 2026-07-13
Scope: Part 51 corrections against Part 50 findings, design Part 15,
implementation Parts 45-48, test-plan Part 43, current code, and saved evidence

## Result

F39-GDIR-02 and F39-GDIR-05 are closed. F39-GDIR-01, F39-GDIR-03, and
F39-GDIR-04 remain open. Coverage and model-backed driver execution are missing
execution evidence, but the current review found no separate coverage-runner
implementation defect.

## Finding status

| Finding | Status | Review evidence |
| --- | --- | --- |
| F39-GDIR-01 | OPEN | Generation calls now cover several entry, descriptor, residency, index, completion, budget, and guarded setup paths. Ownership is still incomplete. `update()` erases cold-byte map rows and descriptors at `server-cache-hybrid.cpp:1250-1266` and prunes forest metadata at `server-cache-hybrid.cpp:1274-1281` without advancing generation. `acquire_branch_node_ref_for_slot()` mutates forest slot refs directly at `server-context.cpp:5995-6007` without the controller generation owner. The six-step test at `test-cache-controller.cpp:4692-4718` does not exercise recovery, cleanup, metadata pruning, normal slot acquisition, or each rollback family. |
| F39-GDIR-02 | CLOSED | Apply now strictly validates complete `desired_hot_orders` and selected-set `desired_cold_ranks` before consumption. It applies hot order, equal-rank setup, and both budgets under lock, calls normal `tx_update()`, and restores pre-transaction setup through monotonic generation advances on injected failure at `server-cache-hybrid.cpp:5611-5748`. |
| F39-GDIR-03 | OPEN | All 15 controller names, TP-39-02/03/04 names, and 13 Python route names exist and the recorded binaries pass. Several bodies do not prove their named contracts. Route integrity retry only performs healthy discovery; omitted-checkpoint removes a hot row; idle race is sequential; non-loopback coverage only sends a wrong token; terminal failure performs a successful apply then checks `consumed`. Controller idle race bypasses server admission dispatch, and TP-39-02/03/04 assert only a small response subset. Registered names and a suite footer are not the Part 43 assertion map. |
| F39-GDIR-04 | OPEN | `Assert-Tp3902`, `Assert-Tp3903`, and `Assert-Tp3904` still only call `Assert-ControlResponseS39` at `stage39-two-layer-pressure.ps1:99-114`. No row-specific code checks victim order, mixed-kind completeness, exact metric and transaction deltas, fixed logs, measured size predicates, tombstones, byte/file accounting, retained topology, zero pruning, or pair atomicity. This is missing implementation, not only missing QA execution. No guarded driver smoke was run. |
| F39-GDIR-05 | CLOSED | `fill_process_nonce()` now uses `BCryptGenRandom` with the system-preferred RNG on Windows, `arc4random_buf` on Apple platforms, and a complete EINTR-safe `getrandom` loop on Linux. Construction fails closed. Nonce serialization or logging was not found. |

## Evidence classification

- `stage39-gdir-build9.log`, `stage39-gdir-controller8.log`, and
  `stage39-gdir-route6.log` support successful build and suite execution.
- The disclosed transient controller access violation remains an execution
  stability risk. Immediate and clean reruns passed, so it is not a new guarded
  discovery defect without a reproducible Stage 39 signature. QA must retain
  the failing exit and rerun artifacts.
- The canonical PowerShell 5 and 7 coverage success and forced-failure probes
  were not run after Part 51. `run_coverage.ps1` names the required final
  `coverage-merged.xml` and `coverage-report.md` artifacts and fails merge on a
  nonzero exit. Missing four-run artifacts and the 80 percent result are QA
  execution gaps, not proof of a new runner defect. They remain blocking before
  Stage 39 closure.

## Required rework

1. Route every remaining cleanup, recovery, forest, slot-reference, and rollback
   mutation through the locked generation owner. Expand the matrix so each Part
   15 family, including changed-then-restored cases, executes independently.
2. Replace the weak controller and route bodies with the exact Part 43 state,
   security, admission-race, retry, terminal-failure, and transaction assertions.
3. Implement each TP-39-02/03/04 PowerShell assertion against saved requests,
   responses, metrics, logs, cold inventories, accounting, and topology.

## Handoff

REWORK. Next owner: Developer for F39-GDIR-01, F39-GDIR-03, and F39-GDIR-04.
Then return to a fresh Architect implementation re-review. After implementation
PASS, QA owns guarded driver execution and all four canonical coverage probes.
Manager gate and Stage 39 closure remain blocked.
