# Stage 23 S03 fix report for matrix 20260621-01

Status: Architect re-review PASS; ready for focused S03 QA rerun
Date: 2026-06-21
Owner: Developer
Trigger report: [stage23-sl-matrix-20260621-01.md](stage23-sl-matrix-20260621-01.md)
Scope: S03 `FAIL-server-exited-before-final-evidence` triage and focused fix.

## Classification

Verdict: product bug.

S03 reached request-phase traffic under CUDA, then `llama-server.exe` exited
before final `/metrics`. This is not setup: preflight, build, fixture, ports,
CUDA smoke, wrapper dry-run, S01, and S02 passed. It is not a pure harness bug:
the final `launch.err` refusal happens after the product process disappeared.

## Evidence reviewed

- `._test_output/stage23-sl-matrix-20260621-01/S03-Jnew/server.err.log`
- `._test_output/stage23-sl-matrix-20260621-01/S03-Jnew/launch.err`
- `._test_output/stage23-sl-matrix-20260621-01/S03-Jnew/resource-samples.csv`
- `._design_docs/cache-handling-test-scripts/stress/stress_s12_s03_large_branch_forests.ps1`
- `tools/server/server-cache-hybrid.cpp`
- `tools/server/server-cache-io-worker.cpp`
- `tests/test-cache-controller.cpp`

## Root cause

The S03 request pattern admits many distinct branch entries. Each saved payload
is about 50 MiB. With `--cache-ram 512` and a configured cold store, hot-budget
eviction tries to demote old payloads to cold storage before evicting them.

Demotion is asynchronous. While a payload is `demoting`, the hot bytes remain
resident and the worker queue also owns a copied payload for the write. The
eviction path removed demoting entries from LRU visibility, so new requests
could keep enqueueing demotions until the 32-item queue filled. S03 reached
about 1.7 GiB of resident hot payload under a 512 MiB hot budget, plus queued
copies, then the server process disappeared before final evidence.

The intended bounded-pressure behavior is to fall back to immediate eviction
when demotion pressure itself is over budget.

## Changes

- `tools/server/server-cache-hybrid.cpp`
  - Added a demoting-byte guard before enqueueing another demotion.
  - When queued/demoting hot bytes plus the next payload would exceed the hot
    budget, demotion returns false and the existing immediate-eviction fallback
    path runs.
  - After checkpoint payload admission succeeds, retained checkpoint entries
    keep metadata only. Raw `data_tgt` and `data_dft` vectors are cleared before
    the list is stored on the cache entry.
- `tools/server/server-cache-hybrid.h`
  - Added private helper declarations for demoting-byte accounting and
    checkpoint metadata storage after admission.
- `tools/server/server-context.cpp`
  - Changed hybrid save so full checkpoint lists are retained only after
    checkpoint payload admission succeeds.
  - If checkpoint admission is skipped, the entry keeps no raw checkpoint list.
    This prevents unbudgeted 50 MiB checkpoint copies from accumulating in S03.
- `tests/test-cache-controller.cpp`
  - Added a Stage 23 focused regression for delayed demotion completion. The
    test verifies that resident hot bytes stay within the hot budget and that
    payload eviction occurs instead of accumulating queued demotions.
  - Added a Stage 23 focused regression proving skipped checkpoint admission
    does not retain the checkpoint list.
  - Added a Stage 23 focused regression proving successful checkpoint admission
    with two checkpoints stores only metadata and leaves raw checkpoint bytes
    in the descriptor-owned hot payload.
  - Added a Stage 23 focused regression proving the demotion pressure guard
    accounts target and draft bytes together at the budget boundary.

## Evidence

- Correction run for F-23-S03-AR-01/F-23-S03-AR-02:
  `cmake --build build-cov --config Release --target test-cache-controller -j 4`
  - PASS.
- Correction run for F-23-S03-AR-01/F-23-S03-AR-02:
  `.\build-cov\bin\Release\test-cache-controller.exe`
  - PASS: 116 tests.
  - Stage 23 PASS lines:
    `Stage 23 demotion queue pressure falls back to eviction`,
    `Stage 23 target+draft demotion pressure counts both payloads`,
    `Stage 23 skipped checkpoint admission drops checkpoint list`, and
    `Stage 23 successful checkpoint admission keeps metadata-only list`.
- Correction run for F-23-S03-AR-01/F-23-S03-AR-02:
  `cmake --build build-cov --config Release --target llama-server -j 4`
  - PASS.
- Short S03 live smoke, 1 minute, CUDA, Qwen3.5 MTP, `--cache-ram 512`,
  `--cache-cold-max-mib 512`, redacted evidence.
  - PASS: script exit 0, `metrics-after.txt` present, `evidence-summary.md`
    present.
  - Output:
    `._test_output/stage23-s03-fix2-smoke-20260621-01/S03-Jnew/`.
  - Tail showed payload and total cache size bounded near the 512 MiB hot
    budget, e.g. `510.638 MiB payload, 510.641 MiB total`.

Non-passing diagnostic attempt:

- The first short S03 smoke after only the demotion guard still hit the same
  Windows application error as the original S03:
  `0xc0000005` in `llama-server-impl.dll` at fault offset `0x00000000000fbbed`.
  `llvm-symbolizer` mapped `0x1800fbbed` to
  `std::list<common_prompt_checkpoint>::operator=`.
- That mapped the remaining crash to checkpoint-list copying, which the second
  fix addresses.

## Progress

- 2026-06-21: S03 classified as product bug from request-phase server exit and
  over-budget demotion pressure.
- 2026-06-21: Narrow code fix and focused regression added.
- 2026-06-21: First short S03 smoke still crashed in checkpoint-list assignment,
  proving the demotion fix alone was incomplete.
- 2026-06-21: Checkpoint-list retention fix and regression added.
- 2026-06-21: Focused builds, controller suite, and 1-minute S03 smoke passed.
- 2026-06-21: Architect re-review PASS for F-23-S03-AR-01/F-23-S03-AR-02.
  Successful checkpoint admission now stores metadata-only checkpoint entries,
  and focused tests cover successful multi-checkpoint admission plus
  target-and-draft demotion pressure.

## Rerun scope

Required QA rerun after Architect PASS:

- Rerun S03 only first, using the same CUDA-gated Stage 23 command shape,
  Qwen3.5 MTP fixture, `--cache-ram 512`, `--cache-cold-max-mib 512`, redacted
  evidence, and a fresh output suffix.
- Acceptance check for S03 rerun: complete final evidence, no server exit,
  `metrics-after.txt` present, `evidence-summary.md` present, no raw prompt
  leak, no unbounded hot payload or checkpoint-list growth.
- If S03 passes, Manager may authorize continuing S04..S08 and L01..L03.
- Do not rerun S01/S02 unless Manager wants confirmation; their current CUDA
  evidence remains valid context.
