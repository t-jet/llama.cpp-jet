# Stress evidence summary: S12-S03 (forest-50MiB)

Date: 2026-06-07 19:19:18
Stub data flag: MEASURED

## Scenario identity

| Field | Value |
| --- | --- |
| Scenario ID | S12-S03 |
| Variant | forest-50MiB |
| Model fixture | Qwen3-0.6B-Q8_0.gguf |
| Build type | Release |
| Server flags | `--cache-mode hybrid --cache-ram 50 --parallel 2 --metrics --ctx-size 512 --temp 0 --seed 42` |
| Request count | 320 |
| Prompt generator seed | 42 |
| Duration seconds | 60 |

## Evidence artifacts

| Artifact | Path |
| --- | --- |
| metrics-before | D:\source\llama.cpp-jet\._design_docs\.test_reports\S12-S03-20260607-05\metrics-before.txt |
| metrics-during | D:\source\llama.cpp-jet\._design_docs\.test_reports\S12-S03-20260607-05\metrics-during.txt |
| metrics-after  | D:\source\llama.cpp-jet\._design_docs\.test_reports\S12-S03-20260607-05\metrics-after.txt |
| resource-samples | D:\source\llama.cpp-jet\._design_docs\.test_reports\S12-S03-20260607-05\resource-samples.csv |
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
