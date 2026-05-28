# BUG-001 fix note for test-report-20260528-06

Date: 2026-05-28  
Owner: Developer agent  
Trigger: [test-report-20260528-06.md](test-report-20260528-06.md)

## Scope

This note covers the two public MTP startup rows from QA report `test-report-20260528-06`.

- H53: `--spec-type draft-mtp` with the Qwen3-8B target only.
- H54: `--spec-type draft-mtp --model-draft <Qwen3-0.6B>`.

The compatibility-key work is already accepted. This triage only checks whether the public MTP startup failures are cache regressions, model/support limitations, or a narrow startup bug.

## Plan

1. Read the QA report, its MTP artifact summaries and logs, Stage 5 architecture Part 6, and the speculative startup paths.
2. Reproduce the target-derived and separate-model MTP startup failures with the local Qwen3 target and draft models.
3. Compare hybrid startup with legacy startup where useful, so cache-mode behavior is not conflated with speculative startup.
4. Apply only a small startup fix if the crash cause is clear.
5. Record the blocker classification and retest evidence.

## Findings

H53 is not a cache bug. The target-derived MTP startup reaches the explicit MTP context creation path and fails because the local Qwen3-8B GGUF does not contain MTP layers:

```text
llama_init_from_model: context type MTP requested but model doesn't contain MTP layers
srv load_model: failed to create MTP context
```

That row needs an MTP-capable target model before public save/restore coverage can run.

H54 exposed a narrow startup bug outside the hybrid cache controller. In the separate draft-model path, `llama_init_from_model(model_dft.get(), cparams)` can return `nullptr` when `LLAMA_CONTEXT_TYPE_MTP` is requested for a draft model without MTP layers. The server then called `common_context_can_seq_rm(ctx_dft.get())` without checking `ctx_dft`, which caused the Windows access violation reported by QA.

## Code change

Changed [tools/server/server-context.cpp](../../tools/server/server-context.cpp) to check `ctx_dft == nullptr` after draft-context creation in the separate draft-model branch. Startup now returns a normal model-loading error instead of dereferencing a null draft context.

This does not change speculative decoding semantics. It only makes an unsupported draft-context creation failure use the existing startup error path.

## Reproduction evidence before the fix

Developer repro artifacts are in [test-report-20260528-06-developer-artifacts/](test-report-20260528-06-developer-artifacts/).

Commands used the same local models as QA with ports outside the Windows excluded range:

```powershell
.\build\bin\Release\llama-server.exe `
  --model D:\source\llama.cpp-jet\._test_models\Qwen3-8B-GGUF\Qwen3-8B-Q6_K.gguf `
  --host 127.0.0.1 --port 54014 --ctx-size 512 --parallel 1 `
  --cache-ram 100 --temp 0 --seed 42 --metrics --log-verbosity 5 `
  --cache-mode hybrid --spec-type draft-mtp
```

Result: exit code `1`; clean unsupported-MTP error for the target model.

```powershell
.\build\bin\Release\llama-server.exe `
  --model D:\source\llama.cpp-jet\._test_models\Qwen3-8B-GGUF\Qwen3-8B-Q6_K.gguf `
  --model-draft D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf `
  --host 127.0.0.1 --port 54019 --ctx-size 512 --parallel 1 `
  --cache-ram 100 --temp 0 --seed 42 --metrics --log-verbosity 5 `
  --cache-mode hybrid --spec-type draft-mtp
```

Result before the fix: exit code `-1073741819`; stderr ended after the unsupported-MTP warning for the draft model.

## Classification

- H53 target-derived MTP: BLOCKED by model capability. The local Qwen3-8B target does not provide MTP layers.
- H54 separate-model MTP: fixed startup error handling. The selected Qwen3-0.6B draft model also lacks MTP layers, so the row remains BLOCKED for public cache coverage until QA uses an MTP-capable draft model or pair.
- Hybrid cache status: not reopened. The failures happen before cache setup, `/health`, or any save/restore path.

## Verification after the fix

Build:

```powershell
cmake --build build --config Release --target llama-server -j 4
ctest --test-dir build -C Release -R test-cache-controller --output-on-failure
```

Result: PASS. `server-context.cpp` rebuilt, `build\bin\Release\llama-server.exe` linked, and the focused cache controller test passed.

Focused startup checks:

```powershell
.\build\bin\Release\llama-server.exe ... --cache-mode hybrid --spec-type draft-mtp
```

Target-derived MTP result: exit code `1`; same explicit unsupported-model error:

```text
context type MTP requested but model doesn't contain MTP layers
failed to create MTP context
```

```powershell
.\build\bin\Release\llama-server.exe ... --cache-mode hybrid --spec-type draft-mtp --model-draft <Qwen3-0.6B>
```

Separate-model MTP result: exit code `1`; no access violation. The server now reports:

```text
context type MTP requested but model doesn't contain MTP layers
failed to create draft context for model 'D:\source\llama.cpp-jet\._test_models\Qwen3-0.6B-GGUF\Qwen3-0.6B-Q8_0.gguf'
```

Legacy comparison:

```powershell
.\build\bin\Release\llama-server.exe ... --cache-mode legacy --spec-type draft-mtp --model-draft <Qwen3-0.6B> --fit off
```

Result: exit code `1` with the same unsupported draft-context error. This confirms the blocker is speculative/model startup, not hybrid cache mode.

Regression smoke for old behavior:

```powershell
.\build\bin\Release\llama-server.exe ... --cache-mode hybrid --model-draft <Qwen3-0.6B>
Invoke-RestMethod http://127.0.0.1:54049/health
```

Result: PASS. The normal separate draft-model path, without `--spec-type draft-mtp`, reached `/health` with `status = ok`.

## QA handoff

QA should keep the public MTP rows BLOCKED for this local Qwen3 model suite. The H54 process crash is fixed, so a rerun with the same models should now see a clean startup failure instead of exit code `-1073741819`. Public MTP cache save/restore evidence still requires an MTP-capable target or draft pair.
