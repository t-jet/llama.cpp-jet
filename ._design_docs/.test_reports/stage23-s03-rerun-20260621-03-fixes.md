# Stage 23 S03 startup crash fix

Status: fix ready for review
Date: 2026-06-21
Owner: Developer
Trigger report: `stage23-s03-rerun-20260621-03.md`
Scope: focused S03 CUDA startup crash after the accepted S03 product fix.

## Classification

The startup crash was a split harness and product issue.

Harness issue: the focused S03 wrapper passed `--cache-cold-path`, but the
cold directory did not exist. The failing side log recorded `coldItems=-1`.
Direct isolation with the same missing cold path reproduced exit
`-1073740791` before `/health`.

Product issue: missing cold-store root caused `hybrid_cache_controller`
construction to throw after model load. The server did not catch that exception,
so Windows reported a fail-fast exit (`0xc0000409`) instead of a bounded startup
failure.

This is not a CUDA environment failure. CUDA stayed enabled. A direct launch
with the same S03 flags and an existing cold path reached `/health`, and
`nvidia-smi` showed `llama-server.exe` using both RTX 5060 Ti devices.

## Root cause

`kickoff-stage20-stress-longrun.ps1` checked the cold path but did not create
it. When the path was absent, `server_cache_store_cold::configure()` returned
false, `hybrid_cache_controller` threw `std::runtime_error`, and
`server_context::init()` had no catch around `create_cache_controller()`.

## Fix scope

Changed files:

- `._design_docs/cache-handling-test-scripts/kickoff-stage20-stress-longrun.ps1`
- `tools/server/server-context.cpp`
- `tests/test-cache-controller.cpp`
- `._design_docs/.test_reports/stage23-s03-rerun-20260621-03-fixes.md`
- `._design_docs/cache-handling-phase23-implementation.md`
- `._design_docs/cache-handling-phase23-implementation/part-15-s03-startup-crash-fix.md`
- `._design_docs/document-index.md`

Behavior changes:

- The S/L wrapper now creates `CacheColdPath` and `CachePromptEvidenceDir`
  before dry-run or live row gates.
- Server startup catches cache-controller init exceptions and returns a bounded
  model-load failure instead of letting the process abort.
- `test-cache-controller` has a focused Stage 23 regression for missing cold
  path controller init.

## Evidence

- `cmake --build build-cov --config Release --target test-cache-controller -j 4`
  passed, exit 0.
- `.\build-cov\bin\Release\test-cache-controller.exe` passed, exit 0.
  Summary: 119 tests; Stage 23 focused tests: 7 PASS.
- `cmake --build build-cov --config Release --target llama-server -j 4`
  passed, exit 0.
- Binary freshness after build:
  - `llama-server.exe`: 2026-06-21 10:53:43
  - `llama-server-impl.dll`: 2026-06-21 10:53:43
  - `test-cache-controller.exe`: 2026-06-21 10:53:30

Direct CUDA startup evidence:

- Output root: `._test_output/stage23-s03-direct-postfix-20260621-01`
- Missing cold path case: `ready=False`, `exited=True`, `exitCode=1`.
  Log includes `cold store: configure failed: root path does not exist` and
  `cache: failed to initialize controller: cold store configuration failed`.
- Existing cold path case: `ready=True`, `exited=False`.
  Log includes CUDA0/CUDA1 RTX 5060 Ti, cold store configured, model loaded,
  and server listening on `http://127.0.0.1:8931`.
- `nvidia-smi.txt` for the existing cold path case shows `llama-server.exe`
  on both GPUs, with 1407 MiB on GPU0 and 1849 MiB on GPU1.

Wrapper evidence:

- Output root: `._test_output/stage23-s03-wrapper-postfix-20260621-01`
- Dry-run command for S03 exited 0.
- `coldPathCreated=True` for
  `D:\tmp\cache-cold-stage23-wrapper-postfix-20260621-01`.
- Side log shows S03 flags include `--n-gpu-layers all`, `--fit off`,
  `--cache-cold-path`, and redacted prompt evidence.

## Handoff

Next gate: Architect review of this focused startup-crash fix. If accepted,
Manager can authorize QA to rerun S03 only with the same CUDA-gated Stage 23
shape and a fresh output suffix. S04..S08 and L01..L03 remain stopped until
S03 has accepted evidence.
