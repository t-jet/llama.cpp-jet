# Stage 23 part 11: S03 Architect rework corrections

Status: Architect re-review PASS
Date: 2026-06-21
Owner: Developer
Scope: correction of F-23-S03-AR-01 and F-23-S03-AR-02 from part 10.

## Inputs

- `cache-handling-phase23-implementation/part-10-architect-s03-fix-review-gate-01.md`
- `cache-handling-phase23-implementation/part-09-s03-product-fix-handoff.md`
- `._design_docs/.test_reports/stage23-sl-matrix-20260621-01-fixes.md`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- `tests/test-cache-controller.cpp`

## Corrections

F-23-S03-AR-01 is corrected. Successful checkpoint admission still admits only
the latest checkpoint payload into descriptor-owned hot storage, but the
retained checkpoint list is now metadata only. `data_tgt` and `data_dft` are
cleared before `entry.checkpoints` stores the list.

This keeps restore semantics on the descriptor-owned checkpoint payload and
prevents raw checkpoint vectors from accumulating outside hot-payload pressure.

F-23-S03-AR-02 is corrected with two focused regressions:

- `Stage 23 successful checkpoint admission keeps metadata-only list` admits a
  two-checkpoint list, verifies both retained checkpoints have empty raw
  vectors, and verifies the latest raw target/draft bytes remain in the hot
  payload record.
- `Stage 23 target+draft demotion pressure counts both payloads` sets a
  tight hot budget and proves the demotion guard accounts target plus draft
  bytes before enqueueing another cold write.

The prior Stage 23 tests remain:

- `Stage 23 demotion queue pressure falls back to eviction`
- `Stage 23 skipped checkpoint admission drops checkpoint list`

## Evidence

- `cmake --build build-cov --config Release --target test-cache-controller -j 4`
  - PASS, exit code 0.
- `.\build-cov\bin\Release\test-cache-controller.exe`
  - PASS, exit code 0.
  - Summary: 116 tests.
  - Stage 23 focused tests: 4 PASS.
- `cmake --build build-cov --config Release --target llama-server -j 4`
  - PASS, exit code 0.

No full matrix was run. No S03 live rerun was run in this correction pass.

## Handoff

Architect re-review passed in [part 12](part-12-architect-s03-fix-re-review-gate-02.md).

QA should rerun S03 only with the same CUDA-gated Stage 23 command shape and a
fresh output suffix.
