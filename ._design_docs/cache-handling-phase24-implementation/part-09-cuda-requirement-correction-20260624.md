# Part 9: CUDA requirement correction 2026-06-24

Status: correction reviewed PASS
Date: 2026-06-24
Owner: Developer
Scope: runner and documentation correction only. No product code changed.

## Trigger

Manager found that final report
`._design_docs/.test_reports/test-report-20260623-03.md` is not valid Stage 24
closure evidence. The report records `GGML_CUDA=OFF`, and the runner flags did
not include `--n-gpu-layers all` or `--fit off`.

Stage 24 and every other stage must run on an Nvidia CUDA GPU.

## Runner correction

Updated
`._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`:

- Every Stage 24 leg now includes `--n-gpu-layers all` and `--fit off`.
- Dry-run `dry-run-plan.json` exposes those flags for `S02-chat` and
  `S03-chat`, for both `native-legacy` and `hybrid-stage24`.
- Dry-run and live plans include CUDA build proof from the server build root's
  `CMakeCache.txt`.
- Live execution blocks before row classification if the CMake cache does not
  contain `GGML_CUDA:BOOL=ON`.
- Live execution checks startup logs after `/health` and before requests. If a
  leg lacks CUDA/NVIDIA runtime proof, the leg becomes
  `BLOCKED-cuda-runtime-missing`.
- `summary.json`, `comparison.json`, and the durable report now expose runtime
  CUDA proof state.

Runtime proof accepts startup log lines such as `CUDA0 : NVIDIA ...`,
`CUDA1 : NVIDIA ...`, `system_info: ... CUDA`, or `ggml_cuda` lines.

## Test-plan correction

Updated
`._design_docs/cache-handling-test-plan/part-29-stage24-chat-s02-s03-comparison.md`:

- Stage 24 clean build now configures with `-DGGML_CUDA=ON` and
  `-DGGML_NATIVE=OFF`.
- Preflight requires CMake cache proof: `GGML_CUDA:BOOL=ON`.
- Every leg requires runtime proof from `server.err.log` or `server.out.log`.
- Missing CUDA configure proof or runtime proof is a setup/runner-contract
  blocker before S02/S03 row classification.
- `test-report-20260623-03.md` is marked invalid for Stage 24 closure because it
  used `GGML_CUDA=OFF`.

## Evidence

Verification run after this correction:

```text
Parser check: PASS
Route scan: PASS, only /v1/chat/completions is used
Dry-run CUDA flags: PASS, all four planned legs include --n-gpu-layers all and --fit off
git diff --check: PASS
Document caps: PASS, all touched Stage 24 docs stay below 300 lines
```

No full final Stage 24 live run was executed in this correction session.

## Handoff

Architect review passed this correction in Part 11. Manager may move the stage
to QA test-plan re-review / CUDA rerun gate. QA must rerun with a fresh CUDA
build and a fresh report suffix.
