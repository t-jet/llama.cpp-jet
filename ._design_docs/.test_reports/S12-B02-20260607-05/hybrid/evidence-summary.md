# Benchmark evidence summary: S12-B02 (hybrid)

Date: 2026-06-07 19:33:03
Stub data flag: MEASURED
Tuning report link: row 6

## Scenario identity

| Field | Value |
| --- | --- |
| Scenario ID | S12-B02 |
| Variant | hybrid |
| Model fixture | Qwen3-8B-Q6_K.gguf |
| Build type | Release |
| Server flags | `--cache-mode hybrid --parallel 1 --cache-ram 200 --metrics --ctx-size 512 --temp 0 --seed 42 --model-draft D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf` |

## Evidence artifacts

| Artifact | Path |
| --- | --- |
| baseline.json | D:\source\llama.cpp-jet\._design_docs\.test_reports\S12-B02-20260607-05\hybrid\baseline.json |
| legacy-baseline.json | N/A |
| k6-results.json | (none) |
| load-tool-output.txt | (none) |
| metrics-before |  |
| metrics-during |  |
| metrics-after  |  |

## Evidence source classification

| Group | Source class |
| --- | --- |
| Cache outcomes | public Prometheus |
| Payload residency | public Prometheus |
| Eviction and protection | public Prometheus |
| Branch graph | public Prometheus where exposed |
| Checkpoint behavior | public Prometheus where exposed |
| Security and leakage | structured log |
| Resource stability | harness-only |
| Load tool latency | load-tool output |

## Verdict

Result: PENDING

Notes: Live run; QA evaluates checkpoint counters
