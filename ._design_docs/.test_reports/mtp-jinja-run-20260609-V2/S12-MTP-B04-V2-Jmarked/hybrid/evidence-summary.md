# Benchmark evidence summary: S12-B04 (hybrid)

Date: 2026-06-09 11:58:20
Stub data flag: MEASURED
Tuning report link: row 3

## Scenario identity

| Field | Value |
| --- | --- |
| Scenario ID | S12-B04 |
| Variant | hybrid |
| Model fixture | Qwen3-8B-Q6_K.gguf |
| Build type | Release |
| Server flags | `--cache-mode hybrid --parallel 1 --cache-ram 100 --metrics --ctx-size 512 --temp 0 --seed 42 --chat-template-file D:\source\llama.cpp-jet\._test_models\Qwen3-8B-GGUF\chat_template_new.jinja` |

## Evidence artifacts

| Artifact | Path |
| --- | --- |
| baseline.json | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260609-V2\S12-MTP-B04-V2-Jmarked\hybrid\baseline.json |
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

Notes: Live run; QA evaluates throughput and latency
