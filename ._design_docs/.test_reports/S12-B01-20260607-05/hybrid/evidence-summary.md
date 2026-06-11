# Benchmark evidence summary: S12-B01 (hybrid)

Date: 2026-06-07 19:27:52
Stub data flag: MEASURED
Tuning report link: row 1

## Scenario identity

| Field | Value |
| --- | --- |
| Scenario ID | S12-B01 |
| Variant | hybrid |
| Model fixture | Qwen3-0.6B-Q8_0.gguf |
| Build type | Release |
| Server flags | `--cache-mode hybrid --parallel 1 --cache-ram 100 --metrics --ctx-size 512 --temp 0 --seed 42` |

## Evidence artifacts

| Artifact | Path |
| --- | --- |
| baseline.json | D:\source\llama.cpp-jet\._design_docs\.test_reports\S12-B01-20260607-05\hybrid\baseline.json |
| legacy-baseline.json | D:\source\llama.cpp-jet\._design_docs\.test_reports\S12-B01-20260607-05\hybrid\legacy-baseline.json |
| k6-results.json | D:\source\llama.cpp-jet\._design_docs\.test_reports\S12-B01-20260607-05\hybrid\k6-results.json |
| load-tool-output.txt | (none) |
| metrics-before | D:\source\llama.cpp-jet\._design_docs\.test_reports\S12-B01-20260607-05\hybrid\metrics-before.txt |
| metrics-during | D:\source\llama.cpp-jet\._design_docs\.test_reports\S12-B01-20260607-05\hybrid\metrics-during.txt |
| metrics-after  | D:\source\llama.cpp-jet\._design_docs\.test_reports\S12-B01-20260607-05\hybrid\metrics-after.txt |

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

Notes: Live run; QA evaluates k6 exit
