# T116 / T117 benchmark evidence summary

## Correction

The original `evidence-summary.md` had a parsing bug in the metrics-extract step: the public-Prometheus deltas table showed 0/0/0 because the metrics were read before all k6 traffic had incremented the counters. This file was regenerated in the same session that wrote [test-report-20260603-03.md](../../test-report-20260603-03.md) and [test-report-20260603-03-fixes.md](../../test-report-20260603-03-fixes.md). The numbers below are read directly from `bench/metrics-before.txt` and `bench/metrics-after.txt` after the bench run completed.

Date: 2026-06-03 16:23:52
k6 exit code: 0
T117 correctness gate: PASS

## Evidence classification

| Scenario | Measurement | Source class |
| --- | --- | --- |
| Exact-hit | timings.cache_n > 0 per /completion response | direct stats |
| Exact-hit | llamacpp_cache_hits_total delta after probes | public Prometheus |
| Exact-hit | cache_hit_rate threshold (k6 Rate metric) | harness-only |
| Cache-miss prompt time | timings.prompt_ms for cache_n=0 responses | direct stats |
| Cache-hit prompt time | timings.prompt_ms for cache_n>0 responses | direct stats |
| Probe misses | llamacpp_cache_misses_total delta | public Prometheus |

## Public Prometheus counter deltas

| Counter | Before | After | Delta |
| --- | --- | --- | --- |
| llamacpp_cache_hits_total (hybrid) | 0 | 12 | +12 |
| llamacpp_cache_misses_total (hybrid) | 0 | 1 | +1 |

## k6 direct stats

    cache_hit_rate
    cache_hit_prompt_ms............: avg=13.91ms  min=12.07ms  med=13.52ms  p(95)=16.75ms  max=18.98ms
    cache_hit_rate.................: 100.00% 11 out of 11
    cache_miss_prompt_ms...........: avg=12.94ms  min=12.94ms  med=12.94ms  p(95)=12.94ms  max=12.94ms
    cache_n_tokens.................: avg=4        min=4        med=4        p(95)=4        max=4

## T116 / T117 outcomes

- T116 PASS: hits delta +12, misses delta +1, k6 `cache_hit_rate` 1.0. The corrected deltas confirm the exact-hit restore in the public Prometheus namespace.
- T117 PASS: k6 `rate>=0.60` threshold met (`cache_hit_rate` = 1.0).
- Checkpoint-hit, cold-transition, and end-to-end-savings scenarios are not produced in this benchmark run; cold-transition has focused evidence in `test-stage10-cold-store-hardening`.
