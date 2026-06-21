# Stage 23 part 12: Architect S03 fix re-review gate 02

Status: PASS
Date: 2026-06-21
Owner: Architect
Scope: re-review of F-23-S03-AR-01 and F-23-S03-AR-02 corrections only. Product code was not edited in this review.

## Inputs

- `cache-handling-phase23-implementation/part-10-architect-s03-fix-review-gate-01.md`
- `cache-handling-phase23-implementation/part-11-s03-architect-rework-corrections.md`
- `._design_docs/.test_reports/stage23-sl-matrix-20260621-01-fixes.md`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`

## Verdict

VERDICT: PASS.

The Developer correction closes F-23-S03-AR-01 and F-23-S03-AR-02. The S03 fix is ready for focused QA rerun of S03 only, using the same CUDA-gated Stage 23 command shape and a fresh output suffix.

## Decisions

F-23-S03-AR-01 is closed. `admit_latest_checkpoint_and_store_metadata` clears `entry.checkpoints`, admits only the latest checkpoint payload into descriptor-owned hot storage, then stores a checkpoint list with `data_tgt` and `data_dft` cleared on every retained checkpoint. The successful admission path no longer keeps raw target or draft checkpoint vectors outside resident-payload accounting.

The save path now calls the metadata-storing helper for both re-materialized and new entries. If admission is skipped, the entry keeps no checkpoint list. If admission succeeds, restore semantics remain on the descriptor-owned checkpoint payload, while retained checkpoint records carry metadata only.

F-23-S03-AR-02 is closed. Demotion pressure uses `record.target.size() + record.draft.size()` for the next payload and `calculate_demoting_payload_bytes()` for outstanding demotions, whose resident bytes include target plus draft for paired descriptors.

The focused tests now cover both boundaries:

- `Stage 23 successful checkpoint admission keeps metadata-only list` admits two checkpoints, verifies retained raw vectors are empty, and verifies the latest target and draft bytes remain in the hot payload record.
- `Stage 23 target+draft demotion pressure counts both payloads` uses a tight budget where target-only accounting would allow the second demotion, but target-plus-draft accounting forces eviction fallback.

## Evidence

- `cmake --build build-cov --config Release --target test-cache-controller -j 4`
  - PASS, exit code 0.
- `.\build-cov\bin\Release\test-cache-controller.exe`
  - PASS, exit code 0.
  - Summary: 116 tests.
  - Stage 23 focused tests: 4 PASS.

No full matrix or S03 live rerun was run in this review.

## Handoff

Gate state: PASS.

Next owner: QA. Rerun S03 only with the same CUDA-gated Stage 23 command shape, Qwen3.5 MTP fixture, `--cache-ram 512`, `--cache-cold-max-mib 512`, redacted evidence, and a fresh output suffix. If S03 passes, Manager may decide whether to continue S04..S08 and L01..L03.

This file uses plain ASCII text and stays under the 300-line durable-doc cap.
