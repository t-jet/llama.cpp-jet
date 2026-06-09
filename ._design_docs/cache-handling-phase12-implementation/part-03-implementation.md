# Stage 12 implementation - Part 3: implementation log

Source: [../cache-handling-phase12-implementation.md](../cache-handling-phase12-implementation.md)

## Status

- Plan state: implemented 2026-06-07.
- Plan review: PASS per [part-02-implementation-plan-review.md](part-02-implementation-plan-review.md).
- Cap-fix closure: PASS per [part-29-cap-fix-closure-decision.md](../cache-handling-phase11-implementation/part-29-cap-fix-closure-decision.md).
- Implementation: complete.
- QA execution: not opened (separate gate).
- Commit: not committed.

## Files created (25 scripts, 1 helper, 3 templates, 1 entry)

Helper library under `._design_docs/cache-handling-test-scripts/lib/`:

- `Write-StressEvidence.ps1`
- `Write-BenchEvidence.ps1`
- `Write-LongrunEvidence.ps1`
- `Read-BaselineJson.ps1`
- `Write-TuningReport.ps1`

Stress scripts (8) under `._design_docs/cache-handling-test-scripts/stress/`:

- `stress_s12_s01_budget_exhaustion.ps1`
- `stress_s12_s02_concurrent_multi_slot.ps1`
- `stress_s12_s03_large_branch_forests.ps1`
- `stress_s12_s04_prompt_storms.ps1`
- `stress_s12_s05_mixed_workload_profiles.ps1`
- `stress_s12_s06_cold_queue_pressure.ps1`
- `stress_s12_s07_protected_root_pressure.ps1`
- `stress_s12_s08_integrity_failure_under_load.ps1`

Benchmark scripts (8) under `._design_docs/cache-handling-test-scripts/bench/`:

- `bench_s12_b01_exact_blob_hit_rate.ps1`
- `bench_s12_b02_checkpoint_hit_rate.ps1`
- `bench_s12_b03_cold_transition_frequency.ps1`
- `bench_s12_b04_end_to_end_token_throughput.ps1`
- `bench_s12_b05_restore_latency.ps1`
- `bench_s12_b06_prompt_storm_efficiency.ps1`
- `bench_s12_b07_mixed_profile_comparison.ps1`
- `bench_s12_b08_large_forest_lookup_cost.ps1`

Long-run scripts (3) under `._design_docs/cache-handling-test-scripts/longrun/`:

- `longrun_s12_l01_6h_hybrid_stability.ps1`
- `longrun_s12_l02_30m_legacy_comparison.ps1`
- `longrun_s12_l03_2h_mixed_workload.ps1`

Config matrix helper at `._design_docs/cache-handling-test-scripts/apply_config_matrix.ps1`.

Test-scripts README updated under `._design_docs/cache-handling-test-scripts/README.md`.

Evidence dir templates (3) under `._design_docs/.test_reports/`:

- `stress-s12-template/README.md`
- `bench-s12-template/README.md`
- `longrun-s12-template/README.md`

## Per-scenario implementation summary

| ID | Script | Stub path | Live path |
| --- | --- | --- | --- |
| S12-S01 | stress_s12_s01_budget_exhaustion.ps1 | STUB evidence with BLOCKED verdict | Server start, prompt loop, three metrics snapshots, resource CSV, evidence summary |
| S12-S02 | stress_s12_s02_concurrent_multi_slot.ps1 | Per-parallel subdir STUB | Two sub-runs at parallel 4 and 8 with concurrent jobs |
| S12-S03 | stress_s12_s03_large_branch_forests.ps1 | STUB | Fixed-seed prefix generator, prompt loop, resource CSV |
| S12-S04 | stress_s12_s04_prompt_storms.ps1 | STUB | Near-dup and exact-repeat loop, resource CSV |
| S12-S05 | stress_s12_s05_mixed_workload_profiles.ps1 | Per-profile subdir STUB | Three profile sub-runs (plain, target-plus-draft, checkpoint) with fixture gating |
| S12-S06 | stress_s12_s06_cold_queue_pressure.ps1 | STUB | Cold path under %TEMP%, resource CSV with cold_files column |
| S12-S07 | stress_s12_s07_protected_root_pressure.ps1 | STUB | Two protected root prompts plus non-protected pressure, resource CSV |
| S12-S08 | stress_s12_s08_integrity_failure_under_load.ps1 | STUB | Focused fault-injection binary precondition, live prompt loop, precondition.log |
| S12-B01 | bench_s12_b01_exact_blob_hit_rate.ps1 | Per-row STUB baseline.json | k6 hybrid then legacy, both rows mandatory |
| S12-B02 | bench_s12_b02_checkpoint_hit_rate.ps1 | Qwen3-8B STUB | Qwen3-8B + draft Qwen3-0.6B |
| S12-B03 | bench_s12_b03_cold_transition_frequency.ps1 | Per-row STUB | Hybrid with cold-path then legacy without |
| S12-B04 | bench_s12_b04_end_to_end_token_throughput.ps1 | Per-row STUB | Hybrid and legacy at matched slot and ctx |
| S12-B05 | bench_s12_b05_restore_latency.ps1 | STUB | Hybrid only, restore p50/p95/p99 captured |
| S12-B06 | bench_s12_b06_prompt_storm_efficiency.ps1 | Per-row STUB | k6 hybrid then legacy |
| S12-B07 | bench_s12_b07_mixed_profile_comparison.ps1 | Per-profile STUB | Three profiles (plain, target-plus-draft, checkpoint) |
| S12-B08 | bench_s12_b08_large_forest_lookup_cost.ps1 | STUB | Hybrid only, forest of fixed-seed prefixes |
| S12-L01 | longrun_s12_l01_6h_hybrid_stability.ps1 | STUB | 6h, 60s sampler, 30m snapshot |
| S12-L02 | longrun_s12_l02_30m_legacy_comparison.ps1 | STUB | 30m, 30s sampler, 10m snapshot |
| S12-L03 | longrun_s12_l03_2h_mixed_workload.ps1 | STUB | 2h, 60s sampler, 30m snapshot |

## Stub data contract

When a fixture or required tool is missing, the driver writes STUB
markers to each artifact and records `Verdict: BLOCKED` in the
per-scenario evidence summary. STUB rows are not counted as PASS for
closure; they preserve planned flags, slot count, ctx size, and
duration so QA can record fixture absence rather than skipping
silently.

## Handoff to next gate

- Architect implementation review of this part and part-04.
- QA test planning reads the implementation, evidence, and fixture
  status (part-05) and produces the test plan with tuned thresholds.
- QA execution runs the dry-run path first, then the live path with
  fixture gating.
