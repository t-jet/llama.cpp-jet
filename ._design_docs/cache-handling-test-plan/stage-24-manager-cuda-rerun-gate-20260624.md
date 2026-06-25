# Stage 24 Manager CUDA rerun gate 2026-06-24

Status: PASS
Date: 2026-06-24
Owner: Manager
Stage: 24 (Chat-Completion S02/S03 Cache Comparison)
Activity: CUDA rerun gate

## Inputs checked

- [Stage 24 test plan part](./part-29-stage24-chat-s02-s03-comparison.md)
- [Stage 24 test-plan re-review](./stage-24-test-plan-re-review-20260624.md)
- [Architect correction review](../cache-handling-phase24-implementation/part-11-implementation-correction-review-20260624.md)
- [CUDA correction](../cache-handling-phase24-implementation/part-09-cuda-requirement-correction-20260624.md)
- [Pre-rerun fixes](../cache-handling-phase24-implementation/part-10-pre-rerun-fixes-20260624.md)
- [Invalid CPU-only report](../.test_reports/test-report-20260623-03.md)

## Gate decision

PASS.

QA may run the fresh Stage 24 CUDA comparison. The previous report
`test-report-20260623-03.md` remains invalid for Stage 24 closure because it
used `GGML_CUDA=OFF`.

## Required execution contract

1. Configure and build a clean CUDA `build-cov` before the runner:

   ```powershell
   cmake -B build-cov -S . -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON -DGGML_NATIVE=OFF
   cmake --build build-cov --config Release --target llama-server
   ```

2. Use the next fresh run id and durable report suffix. Do not overwrite
   `test-report-20260623-03.md` or reuse its row verdicts.

3. Run only the Stage 24 chat comparison through
   `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`.

4. Every live leg must launch with `--n-gpu-layers all` and `--fit off`.

5. The report must prove `build-cov/CMakeCache.txt` contains
   `GGML_CUDA:BOOL=ON` and every leg has runtime CUDA/NVIDIA proof before any
   request evidence is accepted.

6. If S02 reproduces request errors after a valid CUDA startup, preserve logs,
   summaries, request counts, and the `aborted-server-unreachable-after-health`
   state. Do not continue request amplification after server loss.

7. For S03, treat hybrid near-prefix nonzero `cache_n` as
   `FAIL-unsafe-prefix-restore`. Treat native near-prefix `cache_n` and low
   hybrid exact-repeat or overall hit rate as diagnostic unless the runner finds
   another explicit failure condition.

8. Preserve cleanup proof, leak scan, summaries, comparisons, and the durable
   Markdown report for Developer test-results review.

## Handoff

Next owner: QA.

Current gate: test execution. QA should produce a fresh
`._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` and matching
`._test_output/stage24-chat-s02-s03-YYYYMMDD-NN/` run root from the CUDA run.
