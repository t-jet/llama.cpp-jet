# Stress evidence summary: S12-S08 (fault-load-50MiB)

Date: 2026-06-08 14:15:26
Stub data flag: MEASURED

## Scenario identity

| Field | Value |
| --- | --- |
| Scenario ID | S12-S08 |
| Variant | fault-load-50MiB |
| Model fixture | Qwen3-0.6B-Q8_0.gguf |
| Build type | Release |
| Server flags | `--cache-mode hybrid --cache-ram 50 --parallel 1 --metrics --ctx-size 512 --temp 0 --seed 42 --chat-template-file D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\chat_template_new.jinja` |
| Request count | 1687 |
| Prompt generator seed | 42 |
| Duration seconds | 1800 |

## Evidence artifacts

| Artifact | Path |
| --- | --- |
| metrics-before | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\S12-MTP-S08-V1-Jmarked\metrics-before.txt |
| metrics-during | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\S12-MTP-S08-V1-Jmarked\metrics-during.txt |
| metrics-after  | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\S12-MTP-S08-V1-Jmarked\metrics-after.txt |
| resource-samples | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\S12-MTP-S08-V1-Jmarked\resource-samples.csv |
| precondition.log | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\S12-MTP-S08-V1-Jmarked\precondition.log |

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

Notes: Live run with fault precondition; QA evaluates
