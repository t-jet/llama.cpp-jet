# Part 9: Risk register with mitigation

Status: design in progress (Architect session)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison - legacy vs hybrid)
Source: [../cache-handling-phase29-design.md](../cache-handling-phase29-design.md)

## Risk register

| ID | Risk | Trigger | Impact | Mitigation | Mitigation before approval |
| --- | --- | --- | --- | --- | --- |
| R29-01 | Synthetic workload may not represent real agentic behavior | After Phase 2 cold-start cycle, `cache_n_ratio` for hybrid is below legacy on the same `cache_class` | Comparison evidence is misleading; recommendation invalid | Reuse Stage 20 lib calibrated against Stage 16 model-log analysis; document workload shape in report; per-cache-class columns surface asymmetry | Driver records per-cache-class `cache_class` field in `requests.jsonl`; report includes workload shape summary table |
| R29-02 | VRAM release delay between legs | Cooldown exits 120s timeout with VRAM > baseline + 100 MiB | Leg 2's prompt processing latency is contaminated by Leg 1's residual VRAM | Hard nvidia-smi gate with 120s timeout; classify as BLOCKED-vram-release if exceeded | Driver checks VRAM after every cooldown; report records cooldown durations |
| R29-03 | Output equivalence diff caused by model nondeterminism, not cache | Phase 1 byte-comparison fails on one or more of the 5 prompts | Pre-workload gate blocks the comparison; the cause may be cache or model | Same-prompt replay in both modes independently; record diff text in `phase-1-output-equivalence/diff.txt`; if same-prompt replay also differs, classify as model-nondeterminism and report | Driver writes decoded text per prompt per mode; the diff file is durable for post-mortem |
| R29-04 | Cold-store drift still observed after Stage 28 R28-BUG-02 reconcile | `cold_store_drift_ratio` > 1.10 in any hybrid leg | Hybrid metric is not a reliable cold-store utilization signal | Record drift ratio per leg; cite Stage 28 R28-BUG-02 baseline; classify as `OK-with-drift-warning`; if ratio > 5.0, classify as `BLOCKED-cold-store-drift` | Driver writes `cold_store_drift_ratio` per leg; report's Layer 3 includes drift summary |
| R29-05 | 4 cycles x 2 modes x 10 minutes exceeds session budget | Wall-clock exceeds 80 minutes | Comparison does not complete in one session; partial evidence only | 80-minute budget documented; Manager may approve 2-cycle warm run (40 minutes); partial evidence is preserved and the report records the cycle count actually completed | Driver tracks elapsed time per phase and exits early if total exceeds 90 minutes (10-minute buffer); report records "cycles completed" field |
| R29-06 | Stage 29 scope creep into product code | Developer or QA identifies a hybrid-cache bug during the comparison | Stage 29 implementation plan or test plan must include a bug-fix loop, violating scope | Scope explicitly excludes product code changes; if a bug is found, route to a separate future stage (e.g., Stage 30 hybrid-cache tuning) | Entry doc lists exclusions; part-01 lists non-goals; Manager gate review checks scope alignment |
| R29-07 | Port collision between proxy capture (optional) and main legs | Optional proxy uses port 8900 while main leg tries port 8900 | Server fails to bind; leg classified BLOCKED | Optional proxy uses port 8910 if enabled; default is OFF | Driver checks port 8900 and 8910 are free at preflight |
| R29-08 | Metric format regression (underscore form reappears) | Stage 26 alignment reverted by accident in some future stage; comparison binary emits `llamacpp_cache_X` | Driver's metrics-format grep fails; all legs classified `FAIL-metric-format-regression` | Driver greps each `metrics-after.txt` for `^llamacpp_cache_` and fails the leg | Driver runs the grep per leg; report records the grep result |
| R29-09 | Hot cache state contamination between cycles | Hot cache from prior hybrid leg affects next hybrid leg | Latency comparison is not budget-stable; cycle 2+ is not cold | Driver wipes cold dir and resets hot budget between cycles by default; `--Cycles` parameter documents this | Driver records hot-budget reset in `summary.json` per cycle |
| R29-10 | Qwen3.5-4B-MTP fixture cannot load under `--parallel 2` | Server fails to bind or model fails to load | Comparison aborts on first leg | Record the failure as `BLOCKED-host-capacity`; do not lower parallelism without Manager approval | Driver records `parallel` and `ctx_size` in `summary.json` per leg |
| R29-11 | Cold-path write fails during a hybrid leg | `tx_save` to cold store returns error or times out | Hybrid leg incomplete; cold-store utilization cannot be measured | Driver records the error in `summary.json`; report classifies as `FAIL-cold-write` if no bounded handling | Driver wraps cold-write calls in try/catch and logs exceptions |
| R29-12 | Driver invocation does not match the lib API (review findings B-01, B-02, B-03, B-04; B-05 added per rework list in `part-12-design-review-20260628.md`) | Implementation plan discovers documented driver invocation does not match the Stage 20 lib parameter set (the Stage 20 lib is single-prompt per call, requires `/tokenize`, and emits one JSON file per call) | Blocking defect; the comparison cannot start | Rework per review findings B-01, B-02, B-03, B-04 (option a chosen: new wrapper `lib/compare-legacy-vs-hybrid-workload.ps1` plus Phase 0.5 tokenize helper sub-phase plus per-request JSONL output matching part-04) | Corrected invocation verified against the actual Stage 20 lib by the implementation plan before code is written |

## Risks NOT in this register (deferred)

- Real agentic workload mismatch (deferred to a future stage that combines
  proxy capture + synthetic).

- Heavy-tier comparison with Qwen3.6-27B-MTP (deferred to a future stage).
- L1 prompt-cache measurement (deferred to a future stage).

## Mitigation summary

All eleven risks have a concrete mitigation BEFORE approval (i.e., before
the driver runs). The mitigations are driver-level (script-side checks),
report-level (classification rules), or process-level (Manager gate review).

The most important mitigation is R29-05 (session budget): the 80-minute
budget is documented and Manager may approve a 2-cycle warm run to fit
tight sessions.

The most consequential mitigation is R29-06 (scope creep): Stage 29 must
remain comparison-only. Any product bug found during the comparison is
routed to a future stage (likely Stage 30 hybrid-cache tuning), not fixed
in this stage.

## Handoff

Part 9 reviewable. Part 10 covers traceability.
