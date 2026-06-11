# Stress evidence summary: S12-S01 (cold-off)

Date: 2026-06-07 19:06:15
Stub data flag: MEASURED

## Scenario identity

| Field | Value |
| --- | --- |
| Scenario ID | S12-S01 |
| Variant | cold-off |
| Model fixture | Qwen3-0.6B-Q8_0.gguf |
| Build type | Release |
| Server flags | `--cache-mode hybrid --cache-ram 2 --parallel 2 --metrics --ctx-size 512 --temp 0 --seed 42 --model D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf` |
| Request count | 56 |
| Prompt generator seed | 42 |
| Duration seconds | 60 |

## Evidence artifacts

| Artifact | Path |
| --- | --- |
| metrics-before | D:\source\llama.cpp-jet\._design_docs\.test_reports\stress-s12-S01-20260607-05\cold-off\metrics-before.txt |
| metrics-during | D:\source\llama.cpp-jet\._design_docs\.test_reports\stress-s12-S01-20260607-05\cold-off\metrics-during.txt |
| metrics-after  | D:\source\llama.cpp-jet\._design_docs\.test_reports\stress-s12-S01-20260607-05\cold-off\metrics-after.txt |
| resource-samples | D:\source\llama.cpp-jet\._design_docs\.test_reports\stress-s12-S01-20260607-05\cold-off\resource-samples.csv |
| precondition.log | (none) |

## Evidence source classification

| Group | Source class |
| --- | --- |
| Cache outcomes | public Prometheus |
| Payload residency | public Prometheus |
| Eviction and protection | public Prometheus |
| Branch graph | public Prometheus where exposed, structured log otherwise |
| Checkpoint behavior | public Prometheus where exposed, structured log otherwise |
| Security and leakage | structured log |
| Resource stability | harness-only |

## Verdict

Result: PENDING

Notes: Live run; QA evaluates
