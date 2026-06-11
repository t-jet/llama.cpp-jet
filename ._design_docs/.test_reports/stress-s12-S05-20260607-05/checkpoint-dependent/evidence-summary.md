# Stress evidence summary: S12-S05 (checkpoint-dependent)

Date: 2026-06-07 19:10:46
Stub data flag: MEASURED

## Scenario identity

| Field | Value |
| --- | --- |
| Scenario ID | S12-S05 |
| Variant | checkpoint-dependent |
| Model fixture | Qwen3-8B-Q6_K.gguf |
| Build type | Release |
| Server flags | `--cache-mode hybrid --parallel 1 --metrics --cache-ram 200 --model D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf` |
| Request count | 45 |
| Prompt generator seed | 42 |
| Duration seconds | 60 |

## Evidence artifacts

| Artifact | Path |
| --- | --- |
| metrics-before | D:\source\llama.cpp-jet\._design_docs\.test_reports\stress-s12-S05-20260607-05\checkpoint-dependent\metrics-before.txt |
| metrics-during | D:\source\llama.cpp-jet\._design_docs\.test_reports\stress-s12-S05-20260607-05\checkpoint-dependent\metrics-during.txt |
| metrics-after  | D:\source\llama.cpp-jet\._design_docs\.test_reports\stress-s12-S05-20260607-05\checkpoint-dependent\metrics-after.txt |
| resource-samples | D:\source\llama.cpp-jet\._design_docs\.test_reports\stress-s12-S05-20260607-05\checkpoint-dependent\resource-samples.csv |
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
