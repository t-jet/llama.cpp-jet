# Phase 5 implementation: BUG-001 startup fix review

Source: [../cache-handling-phase5-implementation.md](../cache-handling-phase5-implementation.md)

## Review scope

Review date: May 28, 2026

This review covers the BUG-001 fix and blocker classification from [test-report-20260528-06-fixes.md](../.test_reports/test-report-20260528-06-fixes.md).

Reviewed files and evidence:

- `tools/server/server-context.cpp`
- `._design_docs/.test_reports/test-report-20260528-06.md`
- `._design_docs/.test_reports/test-report-20260528-06-fixes.md`
- `._design_docs/.test_reports/test-report-20260528-06-artifacts/`
- `._design_docs/.test_reports/test-report-20260528-06-developer-artifacts/`
- [Architecture Part 6](../cache-handling-architecture/part-06-stage-5-draft-context-modes-and-pairing.md)

## Verdict

PASS.

The BUG-001 code change is narrow and correct. The separate draft-model startup path now checks `ctx_dft == nullptr` immediately after `llama_init_from_model(model_dft.get(), cparams)` and returns the existing model-loading failure path before calling `common_context_can_seq_rm(ctx_dft.get())`.

The fix does not change legacy cache behavior, hybrid save or restore behavior, target-derived MTP startup, or speculative decoding policy. It only converts an unsupported draft MTP context creation failure from a null dereference into a normal startup error.

## Findings

No blocking findings.

The target-derived MTP row is correctly blocked for this local Qwen3-8B target. The logs show `LLAMA_CONTEXT_TYPE_MTP` context creation fails because the model does not contain MTP layers. The server exits before `/health`, before any public completion request, and before hybrid cache save or restore can run.

The separate-model MTP row is also blocked for this local Qwen3 target/draft pair. Before the fix, the draft model path reached the same unsupported MTP-layer condition and then dereferenced a null draft context. After the fix, the developer artifacts show exit code `1` with `failed to create draft context for model ... Qwen3-0.6B-Q8_0.gguf`, not the prior Windows access violation.

The evidence does not overclaim cache coverage. The accepted public coverage remains target-only hybrid and normal separate draft-model hybrid. Public MTP save and restore rows must stay `BLOCKED` for this local model suite until QA has an MTP-capable target model or draft pair.

## Required corrections

None.

## Handoff

State: Stage 5 remains closed.

Next owner: QA may rerun BUG-001 to confirm the clean startup failure for H54. Public MTP cache save/restore coverage remains blocked for the local Qwen3 models because startup cannot create the requested MTP context.
