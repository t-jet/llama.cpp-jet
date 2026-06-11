# Stress evidence summary: S12-S05 (plain-transformer)

Date: 2026-06-09 17:39:07
Stub data flag: MEASURED

## Scenario identity

| Field | Value |
| --- | --- |
| Scenario ID | S12-S05 |
| Variant | plain-transformer |
| Model fixture | Qwen3-8B-Q6_K.gguf |
| Build type | Release |
| Server flags | `--cache-mode hybrid --parallel 1 --metrics --cache-ram 50 --chat-template-file D:\source\llama.cpp-jet\._test_models\Qwen3-8B-GGUF\chat_template.jinja` |
| Request count | 1359 |
| Prompt generator seed | 42 |
| Duration seconds | 1800 |

## Evidence artifacts

| Artifact | Path |
| --- | --- |
| metrics-before | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260609-V2\S12-MTP-S05-V2-Joriginal\plain-transformer\metrics-before.txt |
| metrics-during | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260609-V2\S12-MTP-S05-V2-Joriginal\plain-transformer\metrics-during.txt |
| metrics-after  | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260609-V2\S12-MTP-S05-V2-Joriginal\plain-transformer\metrics-after.txt |
| resource-samples | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260609-V2\S12-MTP-S05-V2-Joriginal\plain-transformer\resource-samples.csv |
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
