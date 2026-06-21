# Stage 23 part 9: S03 product fix handoff

Status: fix ready for review
Date: 2026-06-21
Owner: Developer
Trigger report: [../.test_reports/stage23-sl-matrix-20260621-01.md](../.test_reports/stage23-sl-matrix-20260621-01.md)
Fix report: [../.test_reports/stage23-sl-matrix-20260621-01-fixes.md](../.test_reports/stage23-sl-matrix-20260621-01-fixes.md)

## Classification

S03 is a product bug. The row reached request-phase traffic under CUDA, then
`llama-server.exe` exited before final `/metrics`. Preflight, build, fixture,
ports, CUDA smoke, wrapper dry-run, S01, and S02 had already passed.

## Root cause

Two cache-pressure paths combined:

- Demotion queue pressure could keep too many hot payload bytes in `demoting`
  state while the worker queue also held copied payload bytes.
- Hybrid save retained full raw checkpoint lists even when checkpoint payload
  admission was skipped because boundary metadata was missing. S03 then copied
  repeated 50 MiB checkpoint lists that were not governed by the hot payload
  budget.

The Windows crash record for the intermediate run mapped fault offset
`0x00000000000fbbed` in `llama-server-impl.dll` to
`std::list<common_prompt_checkpoint>::operator=`, matching the checkpoint-list
retention path.

## Fix scope

Changed files:

- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-hybrid.h`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`
- `._design_docs/.test_reports/stage23-sl-matrix-20260621-01-fixes.md`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/document-index.md`

Behavior changes:

- Demotion enqueue now refuses a new demotion when outstanding demoting bytes
  plus the next payload would exceed the hot payload budget. The existing
  immediate-eviction fallback handles that payload.
- Hybrid save stores checkpoint lists only after checkpoint payload admission
  succeeds. Skipped checkpoint admission leaves the entry checkpoint list empty.

## Evidence

- `cmake --build build-cov --config Release --target test-cache-controller -j 4`
  passed.
- `.\build-cov\bin\Release\test-cache-controller.exe` passed 114 tests,
  including both Stage 23 focused regressions.
- `cmake --build build-cov --config Release --target llama-server -j 4` passed.
- 1-minute S03 smoke passed with Qwen3.5 MTP, CUDA, `--cache-ram 512`,
  `--cache-cold-max-mib 512`, and redacted evidence. Output:
  `._test_output/stage23-s03-fix2-smoke-20260621-01/S03-Jnew/`.

## Rerun scope

Next QA action after review: rerun S03 only with the same CUDA-gated Stage 23
command shape and a fresh output suffix. If S03 passes with complete final
evidence, Manager can authorize continuing S04..S08 and L01..L03. S01/S02 do
not need rerun unless Manager requests confirmation.

This file uses LF line endings, plain ASCII text, and stays under the 300-line
durable-doc cap.
