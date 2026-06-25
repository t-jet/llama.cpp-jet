# Stage 24 test-plan re-review 2026-06-24

Status: PASS
Date: 2026-06-24
Owner: QA
Stage: 24 (Chat-Completion S02/S03 Cache Comparison)
Activity: fresh test-plan re-review

## Inputs reviewed

- [Stage 24 test plan part](./part-29-stage24-chat-s02-s03-comparison.md)
- [Prior QA test-plan review](./stage-24-test-plan-review-20260623.md)
- [Prior Manager test-plan gate](./stage-24-manager-test-plan-gate-20260623.md)
- [CUDA correction](../cache-handling-phase24-implementation/part-09-cuda-requirement-correction-20260624.md)
- [Pre-rerun fixes](../cache-handling-phase24-implementation/part-10-pre-rerun-fixes-20260624.md)
- [Architect correction review](../cache-handling-phase24-implementation/part-11-implementation-correction-review-20260624.md)
- [Stage 24 runner](../cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1)
- [Invalid CPU-only report](../.test_reports/test-report-20260623-03.md)
- [Document index](../document-index.md)

## Test scope and execution status

Review only. I did not run the full comparison, start `llama-server`, change
product code, or change reusable automation.

The re-review scope is the Stage 24 CUDA rerun contract after the 2026-06-24
CUDA requirement correction and S02/S03 pre-rerun runner fixes.

## Verdict

PASS.

Blocking findings: none.

Manager may open fresh Stage 24 CUDA test execution.

## Evidence and failures

1. Clean CUDA build gate: PASS.

   The plan requires a clean `build-cov` configure with `-DGGML_CUDA=ON` and
   `-DGGML_NATIVE=OFF`, then a `llama-server` build
   (`part-29-stage24-chat-s02-s03-comparison.md:70`,
   `part-29-stage24-chat-s02-s03-comparison.md:74`). It requires report proof
   that `build-cov/CMakeCache.txt` contains `GGML_CUDA:BOOL=ON`
   (`part-29-stage24-chat-s02-s03-comparison.md:78`,
   `part-29-stage24-chat-s02-s03-comparison.md:85`). PASS closure also requires
   that CMake cache proof (`part-29-stage24-chat-s02-s03-comparison.md:227`,
   `part-29-stage24-chat-s02-s03-comparison.md:230`).

2. Live CUDA path: PASS.

   The plan requires every leg to launch with `--n-gpu-layers all` and
   `--fit off` (`part-29-stage24-chat-s02-s03-comparison.md:118`,
   `part-29-stage24-chat-s02-s03-comparison.md:153`). It requires per-leg
   runtime CUDA/NVIDIA proof before closure (`part-29-stage24-chat-s02-s03-comparison.md:86`,
   `part-29-stage24-chat-s02-s03-comparison.md:167`,
   `part-29-stage24-chat-s02-s03-comparison.md:230`,
   `part-29-stage24-chat-s02-s03-comparison.md:231`). The runner adds the GPU
   flags in `Get-ServerFlags` and checks startup logs after `/health` before
   requests (`stage24-chat-s02-s03-comparison.ps1:331`,
   `stage24-chat-s02-s03-comparison.ps1:895`,
   `stage24-chat-s02-s03-comparison.ps1:898`).

3. Prior CPU-only report handling: PASS.

   The invalid report records `GGML_CUDA=OFF`
   (`test-report-20260623-03.md:58`). The plan says
   `test-report-20260623-03.md` is invalid for Stage 24 closure and its S02/S03
   verdicts cannot be used until a corrected CUDA rerun
   (`part-29-stage24-chat-s02-s03-comparison.md:256`). The implementation
   correction keeps that report as investigation input only
   (`part-10-pre-rerun-fixes-20260624.md:15`,
   `part-10-pre-rerun-fixes-20260624.md:16`).

4. S02 request-error risk: PASS.

   The plan preserves the S02 hybrid `FAIL-http-request` risk and requires
   evidence preservation if it reproduces (`part-29-stage24-chat-s02-s03-comparison.md:36`,
   `part-29-stage24-chat-s02-s03-comparison.md:254`,
   `part-29-stage24-chat-s02-s03-comparison.md:282`). The runner stops retry
   amplification when transport loss follows a previously healthy server and the
   port is free (`stage24-chat-s02-s03-comparison.ps1:723`,
   `stage24-chat-s02-s03-comparison.ps1:731`). It still records
   `aborted-server-unreachable-after-health` and classifies request errors as
   `FAIL-http-request` (`stage24-chat-s02-s03-comparison.ps1:740`,
   `stage24-chat-s02-s03-comparison.ps1:918`,
   `stage24-chat-s02-s03-comparison.ps1:921`). Startup-only failures stay
   separate as `BLOCKED-server-not-healthy`
   (`stage24-chat-s02-s03-comparison.ps1:895`,
   `stage24-chat-s02-s03-comparison.ps1:896`).

5. S03 policy: PASS.

   The plan now states that only hybrid near-prefix nonzero `cache_n` fails
   unsafe-prefix restore; native near-prefix `cache_n` is diagnostic
   (`part-29-stage24-chat-s02-s03-comparison.md:36`,
   `part-29-stage24-chat-s02-s03-comparison.md:283`). The runner applies the
   same policy (`stage24-chat-s02-s03-comparison.ps1:477`,
   `stage24-chat-s02-s03-comparison.ps1:490`,
   `stage24-chat-s02-s03-comparison.ps1:497`). Low hybrid exact-repeat or
   overall hit rate alone is diagnostic when misses are bounded and near-prefix
   remains safe (`part-29-stage24-chat-s02-s03-comparison.md:285`).

6. Execution contract and handoff evidence: PASS.

   The plan is generic enough for a fresh QA run. It uses `YYYYMMDD-NN`
   placeholders and next chronological suffix rules
   (`part-29-stage24-chat-s02-s03-comparison.md:56`,
   `part-29-stage24-chat-s02-s03-comparison.md:68`). It defines preflight,
   dry-run, route-only, final command, row matrix, required artifacts, evidence
   schema, leak scan, redaction, classification, cleanup proof, and Developer
   review inputs (`part-29-stage24-chat-s02-s03-comparison.md:54`,
   `part-29-stage24-chat-s02-s03-comparison.md:99`,
   `part-29-stage24-chat-s02-s03-comparison.md:128`,
   `part-29-stage24-chat-s02-s03-comparison.md:146`,
   `part-29-stage24-chat-s02-s03-comparison.md:155`,
   `part-29-stage24-chat-s02-s03-comparison.md:186`,
   `part-29-stage24-chat-s02-s03-comparison.md:212`,
   `part-29-stage24-chat-s02-s03-comparison.md:225`,
   `part-29-stage24-chat-s02-s03-comparison.md:258`).

7. Hygiene and index alignment: PASS.

   Reviewed Markdown docs are under the 300-line cap where the rule applies:
   Part 29 is 290 lines, prior QA review is 79, prior Manager gate is 46,
   Part 9 is 70, Part 10 is 144, Part 11 is 122, and the invalid report is 251.
   Labels use ASCII status words. No stale Stage 23 reopening requirement was
   found. This report and the parent discovery links were added to the test plan
   entry and document index.

## Plan or automation changes made

No plan wording or automation behavior changed in this review. I added this
durable QA re-review report and discovery links only.

## Handoff

Status: ready.

Next owner: Manager.

Manager may open fresh Stage 24 CUDA test execution. QA execution must start
from a clean `build-cov` CUDA build, use a fresh durable report suffix, prove
CUDA/NVIDIA runtime startup for every leg before requests, and preserve any
S02/S03 failure evidence for Developer test-results review.
