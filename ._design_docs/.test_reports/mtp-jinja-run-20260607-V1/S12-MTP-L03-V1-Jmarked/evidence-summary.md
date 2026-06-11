# Long-run evidence summary: S12-L03 (legacy-2h)

Date: 2026-06-08 22:18:09
Stub data flag: MEASURED

## Scenario identity

| Field | Value |
| --- | --- |
| Scenario ID | S12-L03 |
| Variant | legacy-2h |
| Model fixture | Qwen3-0.6B-Q8_0.gguf |
| Build type | Release |
| Server flags | `--cache-mode legacy --parallel 1 --cache-ram 100 --metrics --ctx-size 512 --temp 0 --seed 42 --chat-template-file D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\chat_template_new.jinja` |
| Duration seconds | 7200 |
| Sampler interval seconds | 60 |

## Resource stability thresholds

| Threshold | Value |
| --- | --- |
| Working set growth after warmup | 10 % |
| Handle or FD growth after warmup | 5 % |
| Latency drift p95 | 20 % |

## Sampler and monitor list

| Monitor | Source |
| --- | --- |
| Process working set | harness-only |
| Windows handle count | harness-only |
| Server liveness ping | public HTTP |
| /metrics sample | public Prometheus |
| Cold-store file count | harness-only |

## Evidence artifacts

| Artifact | Path |
| --- | --- |
| resource-samples.csv | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\S12-MTP-L03-V1-Jmarked\resource-samples.csv |

| snapshot | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\S12-MTP-L03-V1-Jmarked\snapshot-30m.csv |
| snapshot | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\S12-MTP-L03-V1-Jmarked\snapshot-60m.csv |
| snapshot | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260607-V1\S12-MTP-L03-V1-Jmarked\snapshot-90m.csv |

## Evidence source classification

| Group | Source class |
| --- | --- |
| Cache outcomes | public Prometheus |
| Resource stability | harness-only |
| Latency drift | direct stats and harness |
| Server liveness | public HTTP |

## Verdict

Result: PENDING

Notes: Live run; QA verifies legacy path is stable with no hybrid rows
