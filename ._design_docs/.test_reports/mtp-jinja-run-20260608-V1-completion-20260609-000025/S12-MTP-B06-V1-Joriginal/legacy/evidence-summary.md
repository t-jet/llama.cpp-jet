# Benchmark evidence summary: S12-B06 (legacy)

Date: 2026-06-09 00:13:41
Stub data flag: MEASURED
Tuning report link: row 1

## Scenario identity

| Field | Value |
| --- | --- |
| Scenario ID | S12-B06 |
| Variant | legacy |
| Model fixture | Qwen3-0.6B-Q8_0.gguf |
| Build type | Release |
| Server flags | `--cache-mode legacy --parallel 1 --cache-ram 100 --metrics --ctx-size 512 --temp 0 --seed 42 --chat-template-file D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\chat_template.jinja` |

## Evidence artifacts

| Artifact | Path |
| --- | --- |
| baseline.json | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260608-V1-completion-20260609-000025\S12-MTP-B06-V1-Joriginal\legacy\baseline.json |
| legacy-baseline.json | N/A |
| k6-results.json | D:\source\llama.cpp-jet\._design_docs\.test_reports\mtp-jinja-run-20260608-V1-completion-20260609-000025\S12-MTP-B06-V1-Joriginal\legacy\k6-results.json |
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

Notes: Live run; QA evaluates storm counters
