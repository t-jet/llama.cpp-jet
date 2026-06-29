# Stage 29 implementation log pointer: S29-IMPL-FIX-06 QA re-execution handoff (session 2026-06-29 -04)

Status: pointer part for QA re-execution handoff (QA session 2026-06-29-04)
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Owner: QA (re-execution session 2026-06-29-04)
Triggering gate: Manager re-execution gate #6 opened after S29-IMPL-FIX-06 (driver L149 -MaxIterations 50 -> 200) landed
Triggering report: [../../.test_reports/test-report-20260629-04-stage29-06.md](../../.test_reports/test-report-20260629-04-stage29-06.md)
Branch: work-branch

## Summary

QA re-execution session 2026-06-29-04 re-ran the Stage 29 test plan part-33 with all six implementation fixes applied (S29-IMPL-FIX-01..06). Verdict REWORK. F-29-EXEC-12 (driver L149 MaxIter 50) is RESOLVED. NEW BLOCKING F-29-EXEC-15 discovered: wrapper default SizeClass='12k' (TargetTokens=12000) generates prompts that exceed the server's per-slot context cap (n_ctx_seq=2048 when --parallel 2 -c 4096). Phase 1 chat completion for prompt 1 receives 400 Bad Request "request (11480 tokens) exceeds the available context size (2048 tokens)". Driver dies at Main L231-234 as BLOCKED-server-not-running 400 before any per-cycle evidence is produced. 11 of 14 rows BLOCKED-context-mismatch or BLOCKED-no-cycles. TP-29-RG-01 PARTIAL (focused 142/142 PASS, pytest 0 items collected BLOCKED-env), TP-29-RG-02 PASS (zero diff), TP-29-CV-01 BLOCKED-Release-without-/Zi.

## F-29-EXEC-15 (NEW BLOCKING, design): wrapper SizeClass='12k' exceeds per-slot context

Wrapper
[compare-legacy-vs-hybrid-workload.ps1:64](../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1#L64)
declares `[string] $SizeClass = '12k'`. The SizeClassMap at L56-60 maps '12k' to `Target=12000`. `New-ComparisonWorkload` then calls `New-AgenticChatPrompt` (Stage 20 lib) with `TargetTokens=12000`, producing messages of approximately 12000 tokens (empirical: 11480 tokens for prompt 1 per
[server.err.log:41](../../_test_output/stage29-cache-modes-20260629-04/server.err.log#L41)).

The driver
[compare-legacy-vs-hybrid.ps1:24,31](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L24)
defaults `--parallel 2` and `-c 4096`. The server starts with both and caps `n_ctx_seq` to 2048 per
[server.err.log:13](../../_test_output/stage29-cache-modes-20260629-04/server.err.log#L13)
("n_ctx_seq (2048) < n_ctx_train (262144)"). Per-slot context with parallel=2 is `n_ctx / n_parallel = 4096/2 = 2048`.

Phase 1
[Invoke-Phase1OutputEquivalence at compare-legacy-vs-hybrid.ps1:113-139](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L113)
boots legacy and hybrid in turn, sends each of the 5 equivalence prompts as chat completion. The first prompt at 11480 tokens exceeds the 2048-token context and the server returns 400 with
`request (11480 tokens) exceeds the available context size (2048 tokens), try increasing it` per
[server.err.log:42-44](../../_test_output/stage29-cache-modes-20260629-04/server.err.log#L42).

This defect is PRE-EXISTING (not introduced by S29-IMPL-FIX-01..06) and was never reached in prior QA sessions because they died earlier:

- Sessions -01..-02 died at Phase 0.5 (driver L149 equivalence or flag typo)
- Session -03 died at Phase 0.5 (driver dot-source missing for agentic-prompt-generator.ps1)
- Session -04 was aborted before live run
- Session -05 died at Phase 0.5 (driver L149 MaxIter 50 exhausted, F-29-EXEC-12)

The test plan part-33 TP-29-CC-01 ("output equivalence") does not pre-validate the 12k prompt size against the actual server context. F-29-EXEC-15 only surfaced when a live run reached Phase 1.

## Resolution status of prior BLOCKING

F-29-EXEC-01 (prior session -01): driver flag typo. RESOLVED 2026-06-28 by S29-IMPL-FIX-02.

F-29-EXEC-04 (prior session -02): driver cold-mode flag coupling. RESOLVED 2026-06-29 by S29-IMPL-FIX-03.

F-29-EXEC-08 (prior session -03): driver dot-source missing for agentic-prompt-generator.ps1. RESOLVED 2026-06-29 by S29-IMPL-FIX-04.

F-29-EXEC-09 (prior session -03): wrapper MaxIterations default 50. RESOLVED 2026-06-29 by S29-IMPL-FIX-05 (wrapper default 200; main workload L147 fixed).

F-29-EXEC-12 (prior session -05): driver equivalence MaxIter 50. RESOLVED 2026-06-29 by S29-IMPL-FIX-06 (driver L149 -MaxIterations 200).

F-29-EXEC-13 (carry-forward): Release build lacks /Zi; OpenCppCoverage unusable. Affects TP-29-CV-01.

F-29-EXEC-14 (carry-forward): huggingface-hub==1.16.1 does not satisfy transformers constraint. Affects TP-29-RG-01 pytest sub-check only.

F-29-EXEC-15 (NEW this session): wrapper SizeClass='12k' prompts exceed per-slot context. Affects 11 of 14 rows.

F-29-EXEC-16 (NON-BLOCKING, transient): Windows ephemeral port exhaustion on rapid tokenize calls. Wait for TIME_WAIT decay before Phase 0.5 if system has been recently active.

## Suggested Developer fix for F-29-EXEC-15 (one of three)

(a) Wrapper SizeClassMap: add '2k' entry at
[compare-legacy-vs-hybrid-workload.ps1:56-60](../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1#L56)
with `Target=2000`; verify Stage 20 lib's `New-AgenticChatPrompt` accepts the '2k' size class (the
[ValidateSet at agentic-prompt-generator.ps1:87](../../cache-handling-test-scripts/lib/agentic-prompt-generator.ps1#L87)
only allows '12k', '24k', '60k', so a 2k entry requires adding '2k' to the ValidateSet and confirming convergence); driver passes `-SizeClass '2k'` at L147/L149.

(b) Driver -Parallel 1: change
[compare-legacy-vs-hybrid.ps1:32](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L32)
to `[int] $Parallel = 1` so -c 4096 is honored as 4096 per slot. Tradeoff: halves throughput, increases wall-clock budget.

(c) Driver -ContextSize 24576: change
[compare-legacy-vs-hybrid.ps1:31](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L31)
to `[int] $ContextSize = 24576` so per-slot context is 12288 (24576/2) which fits 12k prompts with headroom. Tradeoff: doubles KV cache memory; verify VRAM budget still fits both modes.

The simplest fix is (a): add '2k' SizeClass and call with it. The wrapper's anchor tests at 2k converge at 2000->1969 per F-29-EXEC-09 evidence, so the agentic generator works at smaller sizes.

## Self-test

Setup-env capture written. DryRun preflight PASS. Main path attempt 1: BLOCKED-Invoke-WebRequest (TIME_WAIT exhaustion). Waited 60s. Main path attempt 2: BLOCKED-context-mismatch (F-29-EXEC-15). Diagnostic: standalone server with --parallel 1 -c 4096 -> n_ctx_seq=4096 (proves cap is parallel-induced). Diagnostic 2: standalone server with --parallel 2 -c 4096 -> n_ctx_seq=2048 (proves driver default hits cap). Focused tests 142/142 PASS. Pytest 0 items collected. Git status zero diff.

## Handoff

Next owner: Developer (F-29-EXEC-15). After Developer fix and review, the next QA execution will re-run the full path and produce real per-leg evidence. F-29-EXEC-13 (coverage env) and F-29-EXEC-14 (pytest env) tracked in separate Developer handoffs. F-29-EXEC-16 transient observation recorded for next session.

Next gate: Manager (re-execution gate #6) after Developer fix lands. After re-run PASS: Developer test-results review. After Developer review PASS: Manager closure per D-CLOSURE-29-NN.

This file uses LF line endings, plain ASCII status labels, no BOM, no trailing whitespace, and stays under the 300-line durable-doc cap.
