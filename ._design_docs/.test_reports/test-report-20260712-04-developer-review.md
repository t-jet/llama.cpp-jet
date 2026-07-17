# Stage 39 Developer results review

Date: 2026-07-13
Reviewed report: `test-report-20260712-04.md`
Verdict: REWORK REQUIRED

## Gate decision

The two corrected product findings pass. F39-QA3-01 has one public `mode`
label per Stage 39 sample, and F39-QA3-02 passes with the serialized cold-file
size assertion. No product defect is established by this run.

Stage 39 cannot close. The accepted plan requires TP-39-01 through TP-39-15 to
pass and changed-line coverage to reach at least 80 percent. TP-39-02,
TP-39-03, and TP-39-04 remain blocked. Coverage is unavailable. The canonical
live driver also fails its valid zero-row scenarios before writing summaries.

The report aggregate is wrong. Its row table contains 12 PASS, 0 FAIL, 3
BLOCKED, and 0 SKIP rows, not 10 PASS and 5 BLOCKED. Coverage and the driver
defect are separate gate blockers; they must not be counted as TP rows.

## Row classification

| ID | Review | Classification and owner |
| --- | --- | --- |
| TP-39-01 | PASS | Product evidence. Standard live state records a 71-token cold restore, one promotion, zero payload-eviction delta, zero pruning delta, and byte reconciliation. |
| TP-39-02 | BLOCKED | QA workload/calibration gap. Focused multi-victim evidence passes, but no required live equal-rank payload-ID tie-break, committed incoming object, or victim inventory exists. QA owns calibration; Manager must approve a diagnostic seam if fixtures cannot reach the precondition. |
| TP-39-03 | BLOCKED | QA workload/calibration gap. Runs emit `retained_cold/cold_room_made`; none proves no eligible cold victim or emits `evicted/both_filled`. QA owns calibration; Manager owns any plan or seam change. |
| TP-39-04 | BLOCKED | QA workload/calibration gap. The 7/7 MiB run is rejected by the hot admission guard before Stage 39 pressure, so it cannot prove `evicted/oversized_both`. QA owns a pair-bound workload; Manager owns any required seam change. |
| TP-39-05 | PASS | Product evidence. Cold-disabled emits `bypassed/cold_disabled`; hot-zero logs that prompt cache is disabled and both Stage 39 families are absent. Driver completion defect is tracked separately. |
| TP-39-06 | PASS | Focused rollback and transaction-fault evidence passed. No contrary product evidence appears. |
| TP-39-07 | PASS | Named target/draft lifecycle test passed. |
| TP-39-08 | PASS | Named same-entry independent-descriptor pressure test passed. |
| TP-39-09 | PASS | Named protected-root/live-descendant pressure test passed. |
| TP-39-10 | PASS | Named concurrent production-pressure test passed with the accepted one-decision-per-candidate contract. |
| TP-39-11 | PASS | Product evidence. Legacy startup and workload completed, response artifacts exist, and both Stage 39 families are absent. Driver completion defect is tracked separately. |
| TP-39-12 | PASS | Product evidence. Standard live run contains 25 production save attempts, two `retained_cold/cold_room` decisions, two committed transactions, and a later cold restore. |
| TP-39-13 | PASS | Focused exact-fit, one-byte-over, overhead, and overflow evidence passed. |
| TP-39-14 | PASS | Focused mutation-position and restart-idempotence matrix passed. |
| TP-39-15 | PASS | Targeted product fix closed. Focused exporter regression passed; live decision and transaction samples each contain one `mode` label. |

## Independent evidence checks

Raw artifacts support the main product claims:

- `live-standard/state.json` records hot budget 8,388,608 bytes, cold budget
  16,777,216 bytes, restore cache tokens 71, promotion delta 1, and payload
  eviction and pruning deltas 0.
- `live-standard/metrics-after.txt` contains one decision series with value 2
  and one transaction series with value 2. Each sample has exactly one `mode`
  label. `live-standard/server.err.log` contains 25 production `tx_save`
  saving lines and two `retained_cold/cold_room` decisions.
- `live-oversized-both/server.err.log` contains 24 save attempts and 24 hot
  admission rejections. It contains no Stage 39 decision; the final candidate
  is 11,011,896 bytes against a 7,340,032-byte hot budget.
- `coverage/cache-controller-cobertura.xml` reports `lines-valid="0"` and
  `lines-covered="0"`. Its `line-rate="1"` is a vacuous 0/0, not coverage.

## Harness and tooling findings

### F39-QA4-01: zero-row driver failure

Classification: test harness defect. Owner: Developer.

`stage39-two-layer-pressure.ps1` validates `$decisions + $transactions` before
the `hot-zero` and `legacy` zero-row branch. When both collections are null,
the loop receives a null item and throws `Malformed Stage 39 metric row`.
Both runs therefore lack `summary.json`, although their metrics and logs show
the expected product behavior. Move the zero-row branch before row validation,
or filter null values, then add dry-run or focused regression coverage for both
valid zero-row scenarios.

### F39-QA4-02: coverage procedure bypassed

Classification: QA execution/tool invocation gap. Owner: QA first.

The accepted `run_coverage.ps1` already has a mandatory Phase 2
`llama-server.exe` HTTP probe, adds its `.cov` file to the Phase 3
`--input_coverage` merge, and rejects `-SkipServerProbe` unless incomplete
coverage is explicitly allowed. Report artifacts instead show ad hoc
`run-coverage-smoke.ps1` and `run-coverage-hybrid.ps1` runs against only
`test-cache-controller.exe`. There is no server-probe `.cov`, merged report,
or canonical runner log. The empty focused Cobertura file does not establish
an infrastructure limitation. QA must run the canonical fail-closed command
with the existing Qwen3-0.6B fixture. A real canonical failure may then be
triaged as tooling.

### F39-QA4-03: calibration claim is incomplete

Classification: QA workload evidence gap. Owner: QA, then Manager if blocked.

The report calls Qwen3-0.6B the only available generative fixture. Disk also
contains Qwen3-8B, Qwen3.5-4B, Qwen3.5-4B-MTP, Qwen3.6-27B-MTP, and Qwen2.5
GGUF model files. Their presence does not prove that host resources can run
all of them, but the report does not record attempts or exclusions. QA must
either calibrate with viable fixtures or record concrete resource/precondition
failures. If no live workload can reach TP-39-02 through TP-39-04, Manager must
choose a reviewed diagnostic seam or revise the plan; QA cannot reclassify the
rows as product PASS.

## Required next gate

1. Developer fixes F39-QA4-01 in the canonical Stage 39 driver and adds
   zero-row regression evidence. No product-code change is authorized.
2. Architect reviews that harness correction.
3. QA corrects the report totals, reruns hot-zero and legacy through the fixed
   driver, runs the existing canonical coverage script including Phase 2 and
   Phase 3, and recalibrates TP-39-02 through TP-39-04.
4. If calibration remains unreachable with recorded fixture/resource evidence,
   Manager decides whether to authorize a diagnostic seam or plan change.

Stage 39 returns to Developer for F39-QA4-01. It is not ready for Manager
closure.
