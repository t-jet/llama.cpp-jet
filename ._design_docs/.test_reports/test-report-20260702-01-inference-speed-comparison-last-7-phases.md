# Inference speed comparison across the last twelve stages

Date: 2026-07-02
Owner: QA
Scope: Stage 23 through Stage 34, using available QA evidence.

## Method

This report compares prompt throughput in tokens per second per model and run. `llama-server` timing logs are preferred when they contain complete `slot print_timing` rows:

```text
sum(prompt eval tokens) / sum(prompt eval ms / 1000)
```

Those log rows measure tokens actually evaluated by the server. On cache-hit runs, that is not the same as total request prompt tokens. If a run lacks complete server timing logs, the report falls back to runner timing artifacts and marks the row source as `runner`.

This is not a clean model benchmark. It includes server request handling, cache mode, cache hits, context reuse, and run shape. Compare values within the same model and workload first.

Decode TPS is not consistent enough for a full table. Stage 30 reports decode throughput explicitly. Stage 34 generated one token per request with near-zero decode timing, so decode TPS from that run is not useful.

## Stage coverage

| Stage | Main QA evidence | Model-backed inference run | TPS evidence |
| --- | --- | --- | --- |
| 23 | `stage23-*.md`, `._test_output/stage23-*` | Yes | No direct TPS row: L02 has timing medians, but no prompt token totals tied to those timings. |
| 24 | `test-report-20260624-06.md`, `._test_output/stage24-chat-s02-s03-20260624-06/` | Yes | `llama-server` prompt eval TPS measured for S02/S03 chat legs. S03 hybrid ended early after server loss. |
| 25 | `test-report-20260625-01.md`, `._test_output/stage25-atomic-20260625-01/` | Yes | `llama-server` prompt eval TPS measured for S02/S03 chat legs. |
| 26 | `test-report-20260626-03.md`, `._test_output/stage26-rerun-20260626-01/` | Yes | `llama-server` prompt eval TPS measured for S02/S03 chat legs. |
| 27 | `test-report-20260626-07-fixes.md`, `._test_output/stage24-chat-s02-s03-20260626-07/` | Yes | `llama-server` prompt eval TPS measured for Stage 27 fix verification. |
| 28 | `test-report-20260627-stage28-*.md` | No | No model-backed traffic; build and controller regression work only. |
| 29 | `test-report-20260629-05-stage29-07.md`, `_test_output/stage29-cache-modes-20260629-05/` | Yes | Runner prompt TPS measured for 4 legs. Server log only retained one complete 60-request timing set. |
| 30 | `test-report-20260629-12-stage30-01.md`, `_test_output/stage30-cache-modes-20260629-01/` | Yes | Runner prompt TPS and decode TPS reported for cold-start cycle 1. Server log is partial. |
| 31 | `test-report-20260629-13-stage31-01.md` | No | Focused controller validation only; no model-backed Stage 30 comparison traffic ran. |
| 32 | `test-report-20260630-01-stage32-01.md`, `_test_output/stage32-cache-modes-20260630-01/stage32-proof/performance-by-leg.json` | Yes | Runner prompt TPS measured for 5 completed legs. Server log is partial. |
| 33 | `test-report-20260630-03-stage33-01.md`, `_test_output/stage33-cache-modes-20260630-01/` | Yes | Runner prompt TPS measured for 6 completed legs. Server log lacks prompt timing rows. |
| 34 | `test-report-20260701-01-stage34-reopen-live-small-cache4g.md`, `_test_output/stage34-reopen-live-small-cache4g/` | Yes | `llama-server` prompt eval TPS measured for sequential and concurrent live replay. |

## Prompt TPS by run

| Stage | Run | Model | Workload | Mode | Requests | Prompt tokens | Prompt seconds | Prompt TPS | Source |
| --- | --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| 24 | stage24-chat-s02-s03-20260624-06 | Qwen3.5-4B-Q4_K_M.gguf | S02-chat | native-legacy | 2768 | 74804 | 564.932 | 132.412 | llama-server |
| 24 | stage24-chat-s02-s03-20260624-06 | Qwen3.5-4B-Q4_K_M.gguf | S02-chat | hybrid-stage24 | 876 | 27562 | 384.717 | 71.642 | llama-server |
| 24 | stage24-chat-s02-s03-20260624-06 | Qwen3.5-4B-Q4_K_M.gguf | S03-chat | native-legacy | 1318 | 63944 | 290.922 | 219.798 | llama-server |
| 24 | stage24-chat-s02-s03-20260624-06 | Qwen3.5-4B-Q4_K_M.gguf | S03-chat | hybrid-stage24 | 280 | 16806 | 78.510 | 214.061 | llama-server |
| 25 | stage25-atomic-20260625-01 | Qwen3.5-4B-Q4_K_M.gguf | S02-chat | native-legacy | 2532 | 68432 | 376.764 | 181.631 | llama-server |
| 25 | stage25-atomic-20260625-01 | Qwen3.5-4B-Q4_K_M.gguf | S02-chat | hybrid-stage24 | 47 | 1813 | 13.544 | 133.861 | llama-server |
| 25 | stage25-atomic-20260625-01 | Qwen3.5-4B-Q4_K_M.gguf | S03-chat | native-legacy | 1519 | 73717 | 334.824 | 220.167 | llama-server |
| 25 | stage25-atomic-20260625-01 | Qwen3.5-4B-Q4_K_M.gguf | S03-chat | hybrid-stage24 | 257 | 16240 | 75.374 | 215.458 | llama-server |
| 26 | stage26-rerun-20260626-01 | Qwen3.5-4B-Q4_K_M.gguf | S02-chat | native-legacy | 2516 | 68000 | 386.489 | 175.943 | llama-server |
| 26 | stage26-rerun-20260626-01 | Qwen3.5-4B-Q4_K_M.gguf | S02-chat | hybrid-stage24 | 1420 | 61936 | 381.667 | 162.277 | llama-server |
| 26 | stage26-rerun-20260626-01 | Qwen3.5-4B-Q4_K_M.gguf | S03-chat | native-legacy | 1523 | 73911 | 335.296 | 220.435 | llama-server |
| 26 | stage26-rerun-20260626-01 | Qwen3.5-4B-Q4_K_M.gguf | S03-chat | hybrid-stage24 | 257 | 16240 | 75.840 | 214.135 | llama-server |
| 27 | stage27-fix-verification-20260626-07 | Qwen3.5-4B-Q4_K_M.gguf | S02-chat | native-legacy | 2464 | 66596 | 365.027 | 182.441 | llama-server |
| 27 | stage27-fix-verification-20260626-07 | Qwen3.5-4B-Q4_K_M.gguf | S02-chat | hybrid-stage24 | 740 | 21816 | 319.632 | 68.254 | llama-server |
| 27 | stage27-fix-verification-20260626-07 | Qwen3.5-4B-Q4_K_M.gguf | S03-chat | native-legacy | 1513 | 73423 | 333.510 | 220.153 | llama-server |
| 27 | stage27-fix-verification-20260626-07 | Qwen3.5-4B-Q4_K_M.gguf | S03-chat | hybrid-stage24 | 687 | 41045 | 189.207 | 216.932 | llama-server |
| 29 | stage29-cache-modes-20260629-05 cold-start cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 60 req/leg | legacy | 60 | 116621 | 490.226 | 237.892 | runner |
| 29 | stage29-cache-modes-20260629-05 cold-start cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 60 req/leg | hybrid | 60 | 116645 | 489.307 | 238.388 | runner |
| 29 | stage29-cache-modes-20260629-05 warm cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 60 req/leg | legacy | 60 | 116621 | 490.300 | 237.856 | runner |
| 29 | stage29-cache-modes-20260629-05 warm cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 60 req/leg | hybrid | 60 | 116645 | 490.146 | 237.980 | runner |
| 30 | stage30-cache-modes-20260629-01 cold-start cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 200 req/leg | legacy | 200 | 388493 | 1635.747 | 237.502 | runner |
| 30 | stage30-cache-modes-20260629-01 cold-start cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 200 req/leg | hybrid | 200 | 388541 | 1634.245 | 237.749 | runner |
| 32 | stage32-cache-modes-20260630-01 cold-start cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 200 req/leg | legacy | 200 | 388493 | n/a | 237.890 | runner |
| 32 | stage32-cache-modes-20260630-01 cold-start cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 200 req/leg | hybrid | 200 | 388541 | n/a | 238.498 | runner |
| 32 | stage32-cache-modes-20260630-01 warm cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 200 req/leg | legacy | 200 | 388493 | n/a | 238.455 | runner |
| 32 | stage32-cache-modes-20260630-01 warm cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 200 req/leg | hybrid | 200 | 388541 | n/a | 238.211 | runner |
| 32 | stage32-cache-modes-20260630-01 warm cycle 2 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 200 req/leg | legacy | 200 | 388493 | n/a | 238.318 | runner |
| 33 | stage33-cache-modes-20260630-01 cold-start cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 200 req/leg | legacy | 200 | 388541 | 1635.602 | 237.552 | runner |
| 33 | stage33-cache-modes-20260630-01 cold-start cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 200 req/leg | hybrid | 200 | 388541 | 1635.439 | 237.576 | runner |
| 33 | stage33-cache-modes-20260630-01 warm cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 200 req/leg | legacy | 200 | 388541 | 1652.477 | 235.126 | runner |
| 33 | stage33-cache-modes-20260630-01 warm cycle 1 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 200 req/leg | hybrid | 200 | 388541 | 1669.388 | 232.745 | runner |
| 33 | stage33-cache-modes-20260630-01 warm cycle 2 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 200 req/leg | legacy | 200 | 388541 | 1636.564 | 237.413 | runner |
| 33 | stage33-cache-modes-20260630-01 warm cycle 2 | Qwen3.5-4B-Q4_K_M.gguf | synthetic agentic-shaped 2k, 200 req/leg | hybrid | 200 | 388541 | 1640.907 | 236.784 | runner |
| 34 | stage34-reopen-live-small-cache4g sequential | Qwen3-0.6B-Q8_0.gguf | real chat log replay, 56 req | hybrid | 56 | 57562 | 49.360 | 1166.157 | llama-server |
| 34 | stage34-reopen-live-small-cache4g concurrent warm | Qwen3-0.6B-Q8_0.gguf | real chat log replay, 56 req | hybrid | 56 | 96159 | 295.198 | 325.744 | llama-server |

## Per-model summary

| Model | Stages with measured prompt TPS | Min TPS | Max TPS | Notes |
| --- | --- | ---: | ---: | --- |
| Qwen3.5-4B-Q4_K_M.gguf | 24, 25, 26, 27, 29, 30, 32, 33 | 68.254 | 238.498 | Stages 24-27 use server-evaluated tokens and are not directly comparable with runner total-prompt rows from Stages 29-33. |
| Qwen3-0.6B-Q8_0.gguf | 34 | 325.744 | 1166.157 | Different model and real replay workload. Sequential replay is much faster than concurrent warm replay because prompt mix and cache behavior differ. |

## Mode comparison on Qwen3.5-4B

| Stage/run | Workload | Legacy prompt TPS | Hybrid prompt TPS | Hybrid delta |
| --- | --- | ---: | ---: | ---: |
| Stage 24 | S02-chat | 132.412 | 71.642 | -45.89% |
| Stage 24 | S03-chat | 219.798 | 214.061 | -2.61% |
| Stage 25 | S02-chat | 181.631 | 133.861 | -26.30% |
| Stage 25 | S03-chat | 220.167 | 215.458 | -2.14% |
| Stage 26 | S02-chat | 175.943 | 162.277 | -7.77% |
| Stage 26 | S03-chat | 220.435 | 214.135 | -2.86% |
| Stage 27 | S02-chat | 182.441 | 68.254 | -62.59% |
| Stage 27 | S03-chat | 220.153 | 216.932 | -1.46% |
| Stage 29 cold-start cycle 1 | synthetic 2k | 237.892 | 238.388 | +0.21% |
| Stage 29 warm cycle 1 | synthetic 2k | 237.856 | 237.980 | +0.05% |
| Stage 30 cold-start cycle 1 | synthetic 2k | 237.502 | 237.749 | +0.10% |
| Stage 32 cold-start cycle 1 | synthetic 2k | 237.890 | 238.498 | +0.26% |
| Stage 32 warm cycle 1 | synthetic 2k | 238.455 | 238.211 | -0.10% |
| Stage 33 cold-start cycle 1 | synthetic 2k | 237.552 | 237.576 | +0.01% |
| Stage 33 warm cycle 1 | synthetic 2k | 235.126 | 232.745 | -1.01% |
| Stage 33 warm cycle 2 | synthetic 2k | 237.413 | 236.784 | -0.26% |

The early chat legs show larger hybrid swings because the server log counts evaluated prompt tokens after cache behavior, not total request prompt tokens. S02 hybrid legs also had fewer completed requests in several runs. The later synthetic A/B rows stay near 237-238 TPS because those runner rows are total prompt token throughput for a controlled synthetic shape.

Stage 30 is the only report with decode TPS:

| Stage/run | Legacy decode TPS | Hybrid decode TPS | Hybrid delta |
| --- | ---: | ---: | ---: |
| Stage 30 cold-start cycle 1 | 108.306 | 108.881 | +0.53% |

## Gaps and cautions

- Stage 23 has model-backed timing evidence but lacks prompt token totals, so it stays out of the TPS table.
- Stage 28 and Stage 31 provide no inference-speed measurement.
- Stages 24-27 use `llama-server` prompt eval rows. These count evaluated prompt tokens and expose cache effects directly.
- Stages 29, 30, 32, and 33 use runner artifacts because the saved server logs are partial or lack prompt timing rows.
- Stage 34 uses `llama-server` timing rows, but it ran Qwen3-0.6B because the planned Qwen3.5-4B MTP fixture was unavailable for reopened live work.
- No clean build was run for this comparison report. This is an evidence rollup from existing reports and artifacts, not a new execution session.
