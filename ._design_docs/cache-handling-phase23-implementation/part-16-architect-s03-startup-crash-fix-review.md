# Stage 23 part 16: Architect S03 startup-crash fix review

Status: PASS
Date: 2026-06-21
Owner: Architect
Scope: focused review of the S03 startup-crash fix after Manager gate
D23-S03-RERUN-01. No product code, harness code, or tests were changed by this
review.

## Verdict

PASS.

The startup-crash classification is supported by the evidence: the focused S03
rerun used a missing cold path, direct isolation reproduced startup exit before
health with that missing path, and the post-fix existing-cold-path launch
reached health with CUDA enabled. The wrapper now creates the cold and prompt
evidence directories before dry-run and live gates. Product startup now catches
cache-controller construction exceptions and returns a bounded model-load
failure. The focused controller regression covers the missing-cold-path
exception path.

## Reviewed files

- `._design_docs/cache-handling-phase23-implementation/part-14-manager-s03-rerun-gate-01.md`
- `._design_docs/cache-handling-phase23-implementation/part-15-s03-startup-crash-fix.md`
- `._design_docs/.test_reports/stage23-s03-rerun-20260621-03.md`
- `._design_docs/.test_reports/stage23-s03-rerun-20260621-03-fixes.md`
- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`

## Evidence checked

- Failing rerun evidence: `._test_output/stage23-s03-rerun-20260621-03/`.
  Side log recorded `coldItems=-1`, S03 CUDA flags, missing metrics, and row
  failure. Launch stderr recorded `Server did not start`.
- Direct missing-cold-path post-fix evidence:
  `._test_output/stage23-s03-direct-postfix-20260621-01/missing-cold-path/`.
  Server stderr records `cold store: configure failed: root path does not
  exist` and `cache: failed to initialize controller: cold store configuration
  failed`; summary records exit code 1.
- Direct existing-cold-path CUDA health evidence:
  `._test_output/stage23-s03-direct-postfix-20260621-01/existing-cold-path/`.
  Server stderr records CUDA0/CUDA1 RTX 5060 Ti, cold-store configuration, and
  listening on `http://127.0.0.1:8931`; `nvidia-smi.txt` records
  `llama-server.exe` on both GPUs.
- Wrapper dry-run evidence:
  `._test_output/stage23-s03-wrapper-postfix-20260621-01/batch-summary.log.side`.
  Dry-run exits OK with S03 flags, `--cache-cold-path`,
  `--cache-prompt-evidence-dir`, `--n-gpu-layers all`, and `--fit off`.

## Findings

| ID | Severity | Result | Notes |
| --- | --- | --- | --- |
| F-23-S03-SC-01 | Blocking | Closed | Root cause is correctly classified as missing cold-path harness setup plus unbounded product startup exception. Evidence refutes CUDA environment as primary cause. |
| F-23-S03-SC-02 | Blocking | Closed | Wrapper creates `CacheColdPath` and `CachePromptEvidenceDir` before dry-run and live gates, with directory-type validation. |
| F-23-S03-SC-03 | Blocking | Closed | `server_context::init()` catches `std::exception` from `create_cache_controller()` and returns false with a bounded cache init error. |
| F-23-S03-SC-04 | Blocking | Closed | Focused regression constructs a hybrid controller with a missing cold path and asserts the bounded `cold store configuration failed` exception. |
| F-23-S03-SC-05 | Documentation | Closed | Fix evidence text had stale `117 tests / 5 Stage 23` counts; current source summary is `119 tests / 7 Stage 23`. The durable fix note and fixes report were corrected before this PASS. |

## Risk notes

- This review does not prove S03 workload PASS. It only clears the startup-crash
  fix for focused rerun.
- The missing-cold-path product path now exits bounded with code 1. That is
  acceptable for invalid startup configuration and should remain classified as
  setup failure, not S03 workload failure.
- Existing dirty Stage 21/22/23 changes remain outside this review except where
  they touch the listed focused files.

## Checks run

- `git diff --check -- ._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1 tools/server/server-context.cpp tests/test-cache-controller.cpp`
- Targeted text search for wrapper directory creation, bounded cache-controller
  exception handling, focused regression, and evidence log markers.
- Direct file existence and log-marker checks under the three S03 evidence
  roots listed above.

## Next owner

QA owns a focused S03 rerun only, using the same CUDA-gated Stage 23 shape and
a fresh output suffix. S04..S08 and L01..L03 remain stopped until S03 passes
with accepted evidence.
