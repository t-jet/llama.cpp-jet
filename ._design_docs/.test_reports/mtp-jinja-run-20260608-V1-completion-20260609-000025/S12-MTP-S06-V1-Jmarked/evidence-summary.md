# Stress evidence summary: S12-S06 (cold-queue-16MiB)

Date: 2026-06-09 00:58:32
Stub data flag: MEASURED

## Scenario identity

| Field | Value |
| --- | --- |
| Scenario ID | S12-S06 |
| Variant | cold-queue-16MiB |
| Model fixture | Qwen3-0.6B-Q8_0.gguf |
| Build type | Release |
| Server flags | `--cache-mode hybrid --cache-ram 16 --parallel 2 --metrics --cache-cold-path t:\tmp\s12-s06-cold-e18810f5 --ctx-size 512 --temp 0 --seed 42 --chat-template-file D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\chat_template_new.jinja` |
| Request count | 1713 |
| Prompt generator seed | 42 |
| Duration seconds | 1800 |

## Evidence artifacts

| Artifact | Path |
| --- | --- |
| metrics-before | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260608-V1-completion-20260609-000025\S12-MTP-S06-V1-Jmarked\metrics-before.txt |
| metrics-during | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260608-V1-completion-20260609-000025\S12-MTP-S06-V1-Jmarked\metrics-during.txt |
| metrics-after  | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260608-V1-completion-20260609-000025\S12-MTP-S06-V1-Jmarked\metrics-after.txt |
| resource-samples | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260608-V1-completion-20260609-000025\S12-MTP-S06-V1-Jmarked\resource-samples.csv |
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
