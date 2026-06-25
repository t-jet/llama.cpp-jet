# Part 11: implementation correction review 2026-06-24

Status: PASS
Date: 2026-06-24
Owner: Architect
Scope: fresh implementation re-review gate for the Stage 24 CUDA correction and
pre-rerun S02/S03 fixes. Review only; no full comparison rerun and no product
code changes.

## Inputs reviewed

- `._design_docs/cache-handling-test-scripts/stage24-chat-s02-s03-comparison.ps1`
- `._design_docs/cache-handling-phase24-implementation.md`
- `._design_docs/cache-handling-phase24-implementation/part-09-cuda-requirement-correction-20260624.md`
- `._design_docs/cache-handling-phase24-implementation/part-10-pre-rerun-fixes-20260624.md`
- `._design_docs/cache-handling-test-plan/part-29-stage24-chat-s02-s03-comparison.md`
- `._design_docs/.test_reports/test-report-20260623-03.md`
- Stage 24 design and the chat-path prompt-boundary architecture invariant

## Verdict

PASS.

No blocking architectural or runner-contract findings remain for this correction
set. Manager may move Stage 24 to QA test-plan re-review / CUDA rerun gate, as
appropriate. The next closure-capable execution must be a clean Nvidia CUDA run.

## Decisions

1. CUDA requirement: PASS.

   The runner adds `--n-gpu-layers all` and `--fit off` to every planned leg in
   `Get-ServerFlags` (`stage24-chat-s02-s03-comparison.ps1:328`). Dry-run plans
   include `cuda_build_proof` (`stage24-chat-s02-s03-comparison.ps1:1050`).
   Live execution blocks before any row classification unless the selected
   server build root's `CMakeCache.txt` reports `GGML_CUDA:BOOL=ON`
   (`stage24-chat-s02-s03-comparison.ps1:1056`). The test plan binds that build
   root to `build-cov` and requires the same cache proof
   (`part-29-stage24-chat-s02-s03-comparison.md:74`,
   `part-29-stage24-chat-s02-s03-comparison.md:85`).

   Each live leg waits for runtime CUDA/NVIDIA proof after `/health` and before
   requests (`stage24-chat-s02-s03-comparison.ps1:898`). Summaries expose
   runtime proof (`stage24-chat-s02-s03-comparison.ps1:817`), comparisons copy
   it (`stage24-chat-s02-s03-comparison.ps1:995`), and the durable report table
   prints native and hybrid CUDA states (`stage24-chat-s02-s03-comparison.ps1:1018`).

2. S02 previous request error: PASS.

   Requests only run after health and CUDA runtime proof, so the abort path
   applies to a previously healthy, valid CUDA-started leg
   (`stage24-chat-s02-s03-comparison.ps1:895`, `stage24-chat-s02-s03-comparison.ps1:898`).
   The active request loop stops when a transport-loss request error is followed
   by a free port (`stage24-chat-s02-s03-comparison.ps1:723`,
   `stage24-chat-s02-s03-comparison.ps1:731`). It records
   `aborted-server-unreachable-after-health` in `request_counts.request_run`
   (`stage24-chat-s02-s03-comparison.ps1:740`, `stage24-chat-s02-s03-comparison.ps1:802`).
   The leg still fails because any observed request error produces
   `FAIL-http-request` (`stage24-chat-s02-s03-comparison.ps1:918`).

   This does not hide server crashes. It shortens retry noise after the server
   has already become unreachable and leaves the failure in the leg summary,
   metrics gap, request JSONL, logs, comparison, and report.

3. S03 low hybrid cache hits and unsafe-prefix policy: PASS.

   Part 10 correctly separates native default-cache `cache_n` from hybrid
   checkpoint restore proof. The CPU-only artifact showed hybrid near-prefix
   requests at zero nonzero `cache_n`; only native near-prefix had nonzero
   values (`part-10-pre-rerun-fixes-20260624.md:75`,
   `part-10-pre-rerun-fixes-20260624.md:82`). That matches the Stage 24 design:
   near-prefix requests are safe misses unless exact chat-boundary identity
   proves the hit (`cache-handling-phase24-design.md:154`), and exact-hit
   absence alone is not a failure (`cache-handling-phase24-design.md:253`).

   The runner now fails only on hybrid near-prefix nonzero `cache_n`
   (`stage24-chat-s02-s03-comparison.ps1:486`, `stage24-chat-s02-s03-comparison.ps1:490`).
   Native near-prefix counts remain in a diagnostic object
   (`stage24-chat-s02-s03-comparison.ps1:497`). The test plan agrees:
   native near-prefix is diagnostic only, while hybrid near-prefix nonzero
   `cache_n` remains `FAIL-unsafe-prefix-restore`
   (`part-29-stage24-chat-s02-s03-comparison.md:36`,
   `part-29-stage24-chat-s02-s03-comparison.md:283`).

4. Documentation alignment: PASS.

   The prior report records `GGML_CUDA=OFF`
   (`test-report-20260623-03.md:58`). Implementation Part 9 marks it invalid
   for closure (`part-09-cuda-requirement-correction-20260624.md:11`).
   Part 10 keeps it invalid while using its raw artifacts only to remove runner
   defects before rerun (`part-10-pre-rerun-fixes-20260624.md:15`). The test
   plan says the row verdicts cannot be used until QA reruns with corrected CUDA
   setup (`part-29-stage24-chat-s02-s03-comparison.md:256`).

5. Product-code scope: PASS.

   The reviewed corrections are runner and documentation changes. Part 10's
   product-bug decision is sound: the available S02 evidence is CPU-only and
   lacks CUDA runtime proof, so it cannot isolate a CUDA product defect
   (`part-10-pre-rerun-fixes-20260624.md:46`). No Stage 24 product code change
   is required by this review.

## Hygiene

- Line caps: implementation entry 290 lines before this update; Part 9 70
  lines; Part 10 144 lines; test-plan Part 29 290 lines; invalid prior report
  251 lines. This new report is below 300 lines.
- Byte hygiene: reviewed Stage 24 docs, script, and invalid prior report are
  LF-only, ASCII, and have no BOM.
- Whitespace: no trailing whitespace found in reviewed files before this report
  was added.
- Git hygiene: reviewed Stage 24 files are untracked or dirty in the current
  worktree. No commits, pushes, product files, or Stage 23 closed artifacts were
  changed during this review.

## Handoff

State: ready for Manager handoff.

Manager may move to QA test-plan re-review / CUDA rerun gate. The next run must
use a fresh `build-cov` configured with `-DGGML_CUDA=ON`, must prove per-leg
runtime CUDA/NVIDIA startup, and must write a fresh whitelisted durable report.
