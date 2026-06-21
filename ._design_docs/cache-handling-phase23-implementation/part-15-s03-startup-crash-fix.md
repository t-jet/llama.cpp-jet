# Stage 23 part 15: S03 startup crash fix

Status: fix ready for review
Date: 2026-06-21
Owner: Developer
Scope: focused S03 startup crash after Manager gate D23-S03-RERUN-01.

## Inputs

- `cache-handling-phase23-implementation/part-14-manager-s03-rerun-gate-01.md`
- `._design_docs/.test_reports/stage23-s03-rerun-20260621-03.md`
- `._test_output/stage23-s03-rerun-20260621-03/`
- `._test_output/stage23-s03-direct-isolation-20260621-01/`

## Classification

The S03 startup crash was both a harness setup bug and a product robustness bug.

The harness passed `--cache-cold-path` without creating the directory. The
rerun side log recorded `coldItems=-1`, and direct isolation reproduced the
same startup exit with a missing cold path.

The product let the cold-store configuration exception escape from cache
controller creation. Windows then reported `0xc0000409` instead of a bounded
server startup failure.

CUDA is not the cause. The post-fix direct launch with an existing cold path
reached `/health` with CUDA logs and `nvidia-smi` process evidence on both
RTX 5060 Ti GPUs.

## Changes

`kickoff-stage20-stress-longrun.ps1` now creates `CacheColdPath` and
`CachePromptEvidenceDir` before dry-run and live gates. The path must exist as a
directory before rows launch.

`server-context.cpp` now catches `std::exception` from
`create_cache_controller()` and returns false from model load with a bounded
error line.

`tests/test-cache-controller.cpp` adds
`test_stage23_missing_cold_path_fails_bounded_controller_init()` and updates the
summary to 119 tests, with 7 Stage 23 focused tests.

## Evidence

- Build `test-cache-controller`: PASS, exit 0.
- Run `test-cache-controller`: PASS, exit 0, 119 tests.
- Build `llama-server`: PASS, exit 0.
- Direct missing cold path:
  `._test_output/stage23-s03-direct-postfix-20260621-01/missing-cold-path/`
  exited 1 with bounded cold-store configuration errors.
- Direct existing cold path:
  `._test_output/stage23-s03-direct-postfix-20260621-01/existing-cold-path/`
  reached health. CUDA0 and CUDA1 were logged, and `nvidia-smi` showed
  `llama-server.exe` on both GPUs.
- Wrapper dry-run:
  `._test_output/stage23-s03-wrapper-postfix-20260621-01/` exited 0 and
  created the cold path before logging S03 flags.

## Handoff

Next owner: Architect. Review the harness setup change, product bounded-failure
change, focused unit regression, and direct CUDA evidence. If the fix passes,
Manager should authorize QA to rerun S03 only with a fresh output suffix before
the matrix resumes.
