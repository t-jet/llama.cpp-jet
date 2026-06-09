# Stage 12 implementation - Part 5: fixture requirements

Source: [../cache-handling-phase12-implementation.md](../cache-handling-phase12-implementation.md)

## Status

- Plan state: implemented 2026-06-07.
- Fixture audit date: 2026-06-07.
- Build configuration baseline: `build-cov` with `BUILD_SHARED_LIBS=OFF`,
  `/Zi /Ob1 /O2 /EHsc`, `/DEBUG:FULL`, `GGML_CUDA=OFF` per
  [part-29](../cache-handling-phase11-implementation/part-29-cap-fix-closure-decision.md).

## Required fixtures

The Stage 12 plan lists three fixture categories. Each scenario
references one or more of them:

- Plain-transformer small fixture: `Qwen3-0.6B-Q8_0.gguf`
- Larger fixture: `Qwen3-8B-Q6_K.gguf`
- Separate draft model: `Qwen3-0.6B-Q8_0.gguf` reused
- MTP-capable fixture: not required for the in-scope rows

## Local fixture state

Audited from `._test_models/`:

| Fixture | Path | Present | Size class | Used by |
| --- | --- | --- | --- | --- |
| Qwen3-0.6B | `._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf` | yes | small | S12-S01..S04, S12-S06..S08, all S12-B0x except B02, S12-L01..L03 |
| Qwen3-8B | `._test_models\Qwen3-8B-GGUF\Qwen3-8B-Q6_K.gguf` | yes | larger | S12-S05, S12-B02, S12-B07 (target) |
| Qwen3.5-4B | `._test_models\Qwen3.5-4B-GGUF\Qwen3.5-4B-Q4_K_M.gguf` | yes | medium | not in plan scope |
| Qwen3.5-4B-MTP | `._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf` | yes | MTP-capable | not in plan scope; cap-fix closure PASS 2026-06-07, draft/MTP rows held out of scope by plan choice |
| Qwen2.5-VL-3B | `._test_models\Qwen2.5-VL-3B-Instruct-GGUF\Qwen2.5-VL-3B-Instruct-Q6_K.gguf` | yes | medium | not in plan scope |

The required `Qwen3-0.6B` and `Qwen3-8B` fixtures are present locally.
The MTP-capable fixture is present but not used in any in-scope row
of the Stage 12 plan.

## Scenario fixture gating

| ID | Required fixture | Current local state | Driver behavior |
| --- | --- | --- | --- |
| S12-S01..S04, S12-S06..S08 | Qwen3-0.6B | present | live path runs |
| S12-S05 plain-transformer | Qwen3-0.6B | present | live path runs |
| S12-S05 target-plus-draft | Qwen3-8B + Qwen3-0.6B | both present | live path runs |
| S12-S05 checkpoint-dependent | Qwen3-8B | present but checkpoint support not yet proven by fixture | driver BLOCKED on server start if checkpoint admission fails |
| S12-B01, B03..B06, B08 | Qwen3-0.6B | present | live path runs |
| S12-B02 | Qwen3-8B + draft Qwen3-0.6B | both present | live path runs |
| S12-B07 plain-transformer | Qwen3-0.6B | present | live path runs |
| S12-B07 target-plus-draft | Qwen3-8B + Qwen3-0.6B | both present | live path runs |
| S12-B07 checkpoint-dependent | Qwen3-8B | present but checkpoint support not yet proven | driver BLOCKED on server start |
| S12-L01..L03 | Qwen3-0.6B | present | live path runs |

## Tool requirements

- k6 at `D:\app\k6\k6.exe`: used by S12-B01 and S12-B06. Driver falls
  back to STUB if k6 is missing.
- OpenCppCoverage at `D:\app\OpenCppCoverage\OpenCppCoverage.exe`:
  not consumed by Stage 12 stress or benchmark scripts; used only by
  the existing `run_coverage.ps1` for T114 and T114a refresh.
- Focused fault-injection binary
  `build/bin/Release/test-step11-test-hooks-fault-injection.exe`:
  used by S12-S08 to set up the precondition. Driver falls back to
  STUB and records BLOCKED if missing.

## Disk and host requirements

- Scratch root for cold store: at least 5 GB free under `%TEMP%`.
  Drivers create a `s12-s06-cold-<guid>` or `s12-b03-cold-<guid>`
  directory and verify write before counting requests.
- Evidence directory: at least 20 GB free for the 6-hour long-run
  resource samples and partial-snapshot copies.
- Host: local Windows MSVC. The drivers do not require CUDA.
- Build: `build-cov` Release binary only; Debug is not used for
  stress or benchmark runs.

## Fixture gaps the QA plan owns

- S12-S05 checkpoint-dependent profile: the driver BLOCKS if the
  server fails to start with the Qwen3-8B fixture at the in-scope
  `--ctx-size`. The QA plan may tune the ctx size or open a separate
  Manager scope decision.
- S12-B07 checkpoint-dependent profile: same BLOCKED rule as
  S12-S05. Same QA plan ownership.
- S12-B05 and S12-B08 legacy rows are recorded as N/A per design
  part-03. The QA test plan may add a "nearest legacy throughput
  and latency" row per review observation S12-PLAN-01.

## Handoff to next gate

QA test planning consumes this part and the build-impl log to plan
fixture-gated execution. Manager scope decision may be needed if
checkpoint-dependent rows remain BLOCKED after the first live run.
