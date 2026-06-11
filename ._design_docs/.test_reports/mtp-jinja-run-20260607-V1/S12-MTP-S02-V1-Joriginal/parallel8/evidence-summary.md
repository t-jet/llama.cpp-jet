# Stress evidence summary: S12-S02 (parallel8)

Date: 2026-06-08 02:50:20
Stub data flag: STUB

## Scenario identity

| Field | Value |
| --- | --- |
| Scenario ID | S12-S02 |
| Variant | parallel8 |
| Model fixture | Qwen3.5-4B-Q4_K_M.gguf |
| Build type | Release |
| Server flags | `--cache-mode hybrid --parallel 8 --metrics --ctx-size 512 --temp 0 --seed 42 --cache-ram 100 --chat-template-file D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\chat_template.jinja` |
| Request count | 0 |
| Prompt generator seed | 42 |
| Duration seconds | 1800 |

## Evidence artifacts

| Artifact | Path |
| --- | --- |
| metrics-before | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\S12-MTP-S02-V1-Joriginal\parallel8\metrics-before.txt |
| metrics-during | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\S12-MTP-S02-V1-Joriginal\parallel8\metrics-during.txt |
| metrics-after  | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\S12-MTP-S02-V1-Joriginal\parallel8\metrics-after.txt |
| resource-samples | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\S12-MTP-S02-V1-Joriginal\parallel8\resource-samples.csv |
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

Result: BLOCKED

Notes: Server failed to start at parallel=8 (host limit)
