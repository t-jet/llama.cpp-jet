# Cache handling test plan - Part 18a: Stage 12 operational details

Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)
Source matrix: [part-18](part-18-stage12-stress-benchmarks.md)

## 8. Long-run details

Monitor list (per long-run row):

- process working set (MiB)
- Windows handle count
- server liveness ping (HTTP `/health`)
- `/metrics` sample (cache, payload, branch, checkpoint rows)
- cold-store file count (S12-L01 only)
- process CPU percent
- disk I/O rate

Assertion list (per long-run row, default thresholds from design
part 02; QA may tune before first run and must record final values):

- working-set growth after warmup: less than 10% over the run
- handle growth after warmup: less than 5%
- cold-store file count after cooldown: no orphan growth outside
  expected resident cold descriptors (S12-L01)
- metric counters monotonic where expected, never reset while alive
- p95 restore or generation latency drift: no more than 20% after
  warmup without a recorded workload cause
- no crash, hang, deadlock, data corruption, unsafe restore,
  unbounded log growth, or unbounded metric label growth

Partial-snapshot markers: each driver writes a snapshot copy every
30 min (S12-L01, S12-L03) or 10 min (S12-L02) under
`longrun-run-YYYYMMDD-NN/S12-L0X/snapshots/`. The driver logs the
sample index and a checksum in `snapshots.csv` so QA can resume
evidence collection after an interruption.

S12-L02 reproducibility run pairs with one of the benchmark rows
(B01 or B04). Use the same fixture, seed, and request mix. Confirm
metric and latency shape repeats within the recorded tolerance.

S12-L03 legacy control run uses `--cache-mode legacy` (default) and
must not activate any hybrid metric rows. Cold-store side effects
must be absent.

## 9. Observability

Public Prometheus metrics captured per scenario class. No new
metric names in scope. If a precondition is internal-only, the
report names the focused source that proves it and the public row
that proves the operator-visible result.

| Scenario class | Public Prometheus rows |
| --- | --- |
| Stress (all 8) | `llamacpp_cache_hits_total`, `llamacpp_cache_misses_total`, `llamacpp_cache_restore_*`, `llamacpp_cache_payload_evictions_total`, `llamacpp_cache_protected_root_decisions_total`, `llamacpp_cache_fallback_restores_total`, payload transition rows, diagnostic rows |
| Cold rows (S06, B03, B05) | `llamacpp_cache_cold_payload_bytes`, `llamacpp_cache_cold_payload_count`, `llamacpp_cache_hot_payload_count`, demotion and promotion counters, cold restore latency |
| Branch rows (S03, S08, B08) | branch lookup, namespace validation, metadata budget, metadata-only retention, rematerialization, mismatch, deduplication, pruning, cleanup ownership rows |
| Checkpoint rows (B02, S05, B07) | checkpoint hit, restore, admission, admission failure rows for capable fixtures |
| Long-run (L01, L02, L03) | same as stress; monotonic counter checks over multi-hour window |
| Resource stability | working set, handle count, CPU, disk I/O, cold-store file count, liveness (recorded by resource sampler, not in `/metrics`) |

Leakage check (T109 carry-forward): no prompt text, marker text,
local paths, checksums, payload bytes, model paths, or serialized
state in public metrics or bounded diagnostics.

## 10. Regression

Stage 4-11 focused tests re-run alongside Stage 12 preflight to
prove the cap-fix closure baseline remains valid:

- `test-cache-controller` (Stage 4-5)
- `test-step10-metrics` (Stage 10)
- `test-stage10-cold-store-hardening` (Stage 10)
- `test-step6-demotion-protocol` (Stage 6)
- `test-step7-promotion-protocol` (Stage 6)
- `test-step11-test-hooks-fault-injection` (Stage 6/9)
- `test-step12-branch-graph` (Stage 7)
- `test-step13-stage8` (Stage 8)

Plus Stage 4-9 public HTTP regression rows from
[part-12](part-12-stage10-observability-security-hardening.md)
(T118-T121) when a live server can serve them without extending
the Stage 12 wall-clock budget.

Preflight command:

```powershell
ctest --test-dir build-cov -C Release `
  -R "test-(cache-controller|step10-metrics|stage10-cold-store-hardening|step6-demotion-protocol|step7-promotion-protocol|step11-test-hooks-fault-injection|step12-branch-graph|step13-stage8)" `
  --output-on-failure
```

A preflight failure blocks the Stage 12 run; classify the failure
as product bug, test bug, or coverage infrastructure gap and open a
Developer handoff.

## 11. Out of scope

- `test-stage10-policy-lru.cpp:105` pre-existing semantic bug. The
  assertion is not a build-flag artifact; the test expectation
  conflicts with the LRU policy implementation under the current
  data setup. Resolving it requires a separate session and either
  a code change to `server-cache-policy-lru.cpp:42-43` or removal
  of the `protected_budget_pressure` assert at the test line. This
  plan does not include the fix; Stage 12 does not gate on
  `test-stage10-policy-lru`.
- MTP follow-up. MTP-capable rows (V1, V2, V3) plus the jinja
  marking variant are out of scope for the original Stage 12
  matrix in this part. They are reopened under the post-closure
  follow-up part-21 per Manager D12 (2026-06-07) and executed
  in a separate multi-session run, not in the original Stage 12
  19-scenario execution. H53/H54 status moves from BLOCKED-by-
  cap-fix to live in part-21.
- New cache algorithms, public cache inspection endpoints, CLI
  flags, or public metric or diagnostic schema changes.
- Coverage denominator changes. T114 and T114a stay current on
  the Stage 12 commit when code or tests change; the Stage 12
  scope does not alter the 19-file or 11-file denominator lists.
- k6 or model fixture absence as durable skips. Missing tools or
  fixtures are setup blockers that need Manager narrowing or
  resolution before closure.

## 12. Fixture status

| Fixture | Path | Present | Size class | Used by |
| --- | --- | --- | --- | --- |
| Qwen3-0.6B | `._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf` | yes | small | S12-S01..S04, S06..S08; S12-B01, B03..B06, B08; S12-L01..L03 |
| Qwen3-8B | `._test_models\Qwen3-8B-GGUF\Qwen3-8B-Q6_K.gguf` | yes | larger | S12-S05 (target-plus-draft and checkpoint), S12-B02, S12-B07 (target); part-21 V2 separate-draft target |
| Qwen3.5-4B-MTP | `._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf` | yes | MTP-capable | part-21 V1 (built-in MTP path) |
| Qwen3.6-27B-MTP | `._test_models\Qwen3.6-27B-MTP-GGUF\` | no (copy from lmstudio if not present) | MTP-capable | part-21 V3 (built-in MTP path) |
| Qwen2.5-VL-3B | `._test_models\Qwen2.5-VL-3B-Instruct-GGUF\Qwen2.5-VL-3B-Instruct-Q6_K.gguf` | yes | medium | not used; multimodal not in plan scope |
| Qwen3.5-4B | `._test_models\Qwen3.5-4B-GGUF\Qwen3.5-4B-Q4_K_M.gguf` | yes | medium | not used; no in-scope row references it |

The required Qwen3-0.6B and Qwen3-8B fixtures are present. S12-S05
and S12-B07 checkpoint-dependent profiles are BLOCKED if the server
fails to start with Qwen3-8B at the in-scope `--ctx-size`. Manager
scope decision may be needed if these remain BLOCKED after the
first live run.

## 13. S12-PLAN-01 observation

The Architect implementation review recorded S12-PLAN-01 in
[part-06](../cache-handling-phase12-implementation/part-06-implementation-review.md):
S12-B05 and S12-B08 are hybrid-only and the design records their
legacy rows as `N/A`. To keep legacy mode visible in the report, QA
adds a "nearest legacy throughput and latency" row for each:

- S12-B05-NL: legacy mode at the same slot, ctx, prompt mix, and
  request count as S12-B05. Records legacy p50/p95/p99 request
  latency and tokens per second. Does not claim a hybrid restore
  latency equivalent.
- S12-B08-NL: legacy mode at the same slot, ctx, and forest-of-
  prefixes prompt mix. Records legacy p50/p95/p99 request latency
  and tokens per second. Does not claim a forest lookup equivalent.

The two NL rows reuse the S12-B05 and S12-B08 evidence dirs and
add a `legacy-nearest.json` file alongside `baseline.json`. They
are not closure contracts; they exist so the legacy control
visibility from design part 03 is preserved for hybrid-only
benchmark families.

## 14. Handoff

This part opens the next gate: QA test plan review. The review
checks that the per-scenario pass criteria, BLOCKED rules, evidence
format, observability rows, regression set, fixture gating, and
S12-PLAN-01 nearest-legacy rows are complete, consistent with the
design and implementation parts, and ready for the first execution
session to consume. Run results are stored only in a fresh
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` after the
execution session opens.

Stage 12 matrix and clean build rules: see
[part-18](part-18-stage12-stress-benchmarks.md).
Test automation setup and scripts inventory: see
[part-19](part-19-stage12-test-automation.md).
