# Stage 29 Cache Modes Comparison test execution report (re-run #6)

Run ID: stage29-cache-modes-20260629-04
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Tester: QA session (fresh, sixth QA session for Stage 29)
Source plan: [../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md](../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md) (Manager test-plan gate PASS 2026-06-28)

Prior reports:

- [test-report-20260628-01-stage29-01.md](test-report-20260628-01-stage29-01.md) (PARTIAL, BLOCKED-driver-flag-typo)
- [test-report-20260628-02-stage29-02.md](test-report-20260628-02-stage29-02.md) (PARTIAL, BLOCKED-driver-cold-mode)
- [test-report-20260629-01-stage29-03.md](test-report-20260629-01-stage29-03.md) (PARTIAL, BLOCKED-driver-dot-source)
- [test-report-20260629-02-stage29-04.md](test-report-20260629-02-stage29-04.md) (PARTIAL aborted; no durable report written)
- [test-report-20260629-03-stage29-05.md](test-report-20260629-03-stage29-05.md) (PARTIAL, BLOCKED-equivalence-workload-build at driver L149)

Design source: [../../cache-handling-phase29-design.md](../../cache-handling-phase29-design.md) (entry + 13 part files)
Implementation source: [../../cache-handling-phase29-implementation.md](../../cache-handling-phase29-implementation.md) (entry + 16 part files; part-15 = S29-IMPL-FIX-05, part-16 = QA re-exec handoff -05)
Driver: [../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1) (247 LF post S29-IMPL-FIX-06)
Branch: work-branch
Cycles actually executed: 0 of planned 4 (NEW BLOCKING design mismatch at Phase 1; see F-29-EXEC-15)

## Verdict

REWORK against the Test execution checklist. S29-IMPL-FIX-01 (Main dispatcher), S29-IMPL-FIX-02 (cold flag typo), S29-IMPL-FIX-03 (cold-mode coupling), S29-IMPL-FIX-04 (driver dot-source), S29-IMPL-FIX-05 (wrapper MaxIterations plumbing), and S29-IMPL-FIX-06 (driver equivalence MaxIter 50->200) are VERIFIED WORKING: driver preflight prints PASS, server boot succeeds in legacy mode, Phase 0.5 workload build completes with workload.jsonl (200 lines, 78/65/57 cache_class distribution within +/- 5 tolerance of 80/60/60 design target per re-review C-01) and equivalence-prompts.jsonl (5 lines, 302552 bytes). The prior BLOCKING F-29-EXEC-12 (driver L149 MaxIter 50) is RESOLVED.

NEW BLOCKING discovered this session: F-29-EXEC-15 wrapper `SizeClass='12k'` (default at [compare-legacy-vs-hybrid-workload.ps1:64](../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1#L64)) generates prompts with `TargetTokens=12000`. The driver uses `--parallel 2 -c 4096` (default at [compare-legacy-vs-hybrid.ps1:24,31](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L24)) which the server caps to `n_ctx_seq (2048)` per [server.err.log:13](../../_test_output/stage29-cache-modes-20260629-04/server.err.log#L13) (the model n_ctx_seq=2048 is the binding per-slot context when parallel > 1). Phase 1 chat completion for prompt 1 receives `400 Bad Request: request (11480 tokens) exceeds the available context size (2048 tokens)` per [server.err.log:43-44](../../_test_output/stage29-cache-modes-20260629-04/server.err.log#L43). Driver dies at Main L231-234 with `BLOCKED-server-not-running: Response status code does not indicate success: 400 (Bad Request)` per [main.log](../../_test_output/stage29-cache-modes-20260629-04/main.log).

This defect is PRE-EXISTING (not introduced by S29-IMPL-FIX-01..06) and never reached in prior sessions because they died at Phase 0.5 (driver L149 equivalence). It is a Stage 29 test plan / wrapper design mismatch that the test plan part-33 (TP-29-CC-01) and wrapper default both assume a 12k-token chat context that this server+model+parallel combination does not provide.

Two regression rows executed (TP-29-RG-01 PARTIAL, TP-29-RG-02 PASS). Coverage row BLOCKED on the carry-forward Release-without-`/Zi` gap. Manager directive 2026-06-29: "Don't close the stage until all things are resolved." Stage remains at bug handoff.

## Environment

Capture path: [../../_test_output/stage29-cache-modes-20260629-04/setup-env.json](../../_test_output/stage29-cache-modes-20260629-04/setup-env.json).

- session_date: 2026-06-29; session_time: 10:44:24
- pwd: `D:\source\llama.cpp-jet`; ps_version: 7.6.3
- cmake_version: cmake 4.3.2.0; python_version: Python 3.11.9
- k6_version: k6.exe v2.0.0-rc1
- opencppcoverage: `d:\app\OpenCppCoverage\OpenCppCoverage.exe` (installed; not runnable due to Release build lack of `/Zi`)
- nvidia_smi: driver 595.79; GPUs 0/16311 MiB and 0/16311 MiB (RTX 5060 Ti x2, idle at session start)
- binary_path: `build-cuda\bin\Release\llama-server.exe`; binary_length: 168655360 bytes (Stage 28 closure)
- binary_mtime: 2026-06-27T10:55:11; most_recent_obj_mtime: 2026-06-27T10:55:10 (1 second before binary, matches Stage 28 closure)
- model_path: `._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`; model_length: 2834975040 bytes
- git_head: dbf593978b66a0d46a030f80c6e87345e08b3a04; git_dirty_count: 9 (driver, wrapper, impl log, qa memory, stage tracker; no tools/server/, tests/, common/, ggml/ modifications)
- cuda_cxx_flags_release: `/O2 /Ob2 /DNDEBUG` (no `/Zi`)
- ggml_cuda: ON; port_8900_free_at_session_start: true
- cold_path: `D:\tmp\cache-cold-stage29-06` (created session start)
- run_root: `._test_output\stage29-cache-modes-20260629-04`
- report_path: `._design_docs\.test_reports\test-report-20260629-04-stage29-06.md`
- driver_lines_lf: 247 (under 300 cap; post S29-IMPL-FIX-06); wrapper_lines_lf: 203
- test_plan_part_33_lines: 299
- cuda_path: `D:\app\cuda_13_2\bin\x64`; disk_free_gb: 1438.47
- huggingface_hub: 1.16.1; transformers: 4.57.6 (transformers constraint `>=0.34.0,<1.0` not satisfied; pytest collect 0 items)

## Clean-build evidence

Per QA memory "re-execution session binary freshness vs content correctness", no-op rebuild skipped because (a) source under `tools/server/`, `tests/`, `common/`, `ggml/` is unchanged per `git diff --stat` returning 0 modifications, and (b) binary content correctness verified by most recent obj mtime (2026-06-27T10:55:10) being 1 second before binary mtime (2026-06-27T10:55:11), matching Stage 28 closure. Driver and wrapper are tracked-modified per `git status --short` (M prefix on both); S29-IMPL-FIX-04 dot-source fix at L44 verified by `Select-String`; S29-IMPL-FIX-05/06 MaxIterations plumbing verified at wrapper L66 (signature default 200), L114 (anchor pool call site), L150 (per-request call site); driver L147 and L149 both pass `-MaxIterations 200`. Override rationale recorded per memory rule.

## Commands run

1. Setup-env capture: setup-env.json written via UTF8Encoding($false); 1554 bytes.
2. Preflight gate: verified GGML_CUDA:BOOL=ON at [build-cuda/CMakeCache.txt](../../build-cuda/CMakeCache.txt), binary exists at 168655360 bytes, fixture exists, port 8900 free.
3. DryRun preflight: pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -DryRun ... ; exit 0; preflight status PASS (ps_version_ok, binary_exists, fixture_exists, port_free, cuda_proof=PASS).
4. Main path attempt 1: exit 1 BLOCKED-Invoke-WebRequest at agentic-prompt-generator.ps1:239 "Only one usage of each socket address (protocol/network address/port) is normally permitted." Cause: PowerShell ephemeral port backlog in TIME_WAIT (3258 sockets) from prior session.
5. Waited 60 seconds for TIME_WAIT decay (3258 -> 12).
6. Main path attempt 2: exit 1 BLOCKED-context-mismatch at Phase 1 prompt 1, server returns 400 "request (11480 tokens) exceeds the available context size (2048 tokens)" (see F-29-EXEC-15).
7. Diagnostic 1: standalone server with `--parallel 1 -c 4096` -> n_ctx_seq=4096 confirmed.
8. Diagnostic 2: standalone server with `--parallel 2 -c 4096` -> n_ctx_seq=2048 confirmed; this matches the driver default.
9. TP-29-RG-01 focused tests: build-cuda\bin\Release\test-cache-controller.exe -> 142/142 PASSED (19392 bytes log).
10. TP-29-RG-01 pytest: python -m pytest tests/ -> 0 items collected, exit 5 (BLOCKED-env carry-forward).
11. TP-29-RG-02 git status tools/server tests common ggml gguf-py: empty output (PASS).
12. TP-29-RG-02 git diff --stat server-cache-hybrid.cpp: empty output (PASS).

## Findings

### F-29-EXEC-15 (BLOCKING, design): wrapper SizeClass='12k' exceeds available context

Wrapper [compare-legacy-vs-hybrid-workload.ps1:64](../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1#L64) declares `[string] $SizeClass = '12k'`. The SizeClassMap at L56-60 maps '12k' to `Target=12000`. `New-ComparisonWorkload` (the wrapper's main entry at L53) then calls `New-AgenticChatPrompt` (Stage 20 lib) with `TargetTokens=12000`, producing messages of approximately 12000 tokens (empirical: 11480 tokens for prompt 1 per [server.err.log:41](../../_test_output/stage29-cache-modes-20260629-04/server.err.log#L41)).

The driver [compare-legacy-vs-hybrid.ps1:24,31](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L24) defaults `--parallel 2` and `-c 4096`. The server starts with both and caps `n_ctx_seq` to 2048 per [server.err.log:13](../../_test_output/stage29-cache-modes-20260629-04/server.err.log#L13) ("n_ctx_seq (2048) < n_ctx_train (262144)"). Per-slot context with parallel=2 is `n_ctx / n_parallel = 4096/2 = 2048`.

Phase 1 [Invoke-Phase1OutputEquivalence at compare-legacy-vs-hybrid.ps1:113-139](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L113) boots legacy and hybrid in turn, sends each of the 5 equivalence prompts as chat completion. The first prompt at 11480 tokens exceeds the 2048-token context and the server returns 400 with `request (11480 tokens) exceeds the available context size (2048 tokens), try increasing it` per [server.err.log:42-44](../../_test_output/stage29-cache-modes-20260629-04/server.err.log#L42). Send-Stage29ChatPrompt at [compare-legacy-vs-hybrid.ps1:157-161](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L157) propagates this as a PowerShell error which the Main dispatcher at L231-234 catches and exits with code 1 as `BLOCKED-server-not-running: Response status code does not indicate success: 400 (Bad Request)` per [main.log](../../_test_output/stage29-cache-modes-20260629-04/main.log).

This defect is PRE-EXISTING (not introduced by S29-IMPL-FIX-01..06) and was never reached in prior QA sessions because they died earlier:

- Sessions -01..-02 died at Phase 0.5 (driver L149 equivalence or flag typo)
- Session -03 died at Phase 0.5 (driver dot-source missing for agentic-prompt-generator.ps1)
- Session -04 was aborted before live run
- Session -05 died at Phase 0.5 (driver L149 MaxIter 50 exhausted, F-29-EXEC-12)

The test plan part-33 TP-29-CC-01 ("output equivalence") does not pre-validate the 12k prompt size against the actual server context. Per re-review F-29-EXEC-15 only surfaced when a live run reached Phase 1.

Evidence files:

- [main.log](../../_test_output/stage29-cache-modes-20260629-04/main.log): Main L231-234 400 error
- [server.err.log](../../_test_output/stage29-cache-modes-20260629-04/server.err.log): L13 n_ctx_seq cap; L41-44 400 send_error
- [equivalence-prompts.jsonl](../../_test_output/stage29-cache-modes-20260629-04/equivalence-prompts.jsonl): 5 lines, 302552 bytes; first prompt r-1 has 60198 chars (~12k tokens)
- [workload.jsonl](../../_test_output/stage29-cache-modes-20260629-04/workload.jsonl): 200 lines, 12060034 bytes; cache_class 78/65/57 distribution proves Phase 0.5 main workload build converged with both call sites at -MaxIterations 200
- [diag-server.err.log](../../_test_output/stage29-cache-modes-20260629-04/diag-server.err.log): diagnostic with --parallel 1 -c 4096 shows n_ctx_seq=4096 honored
- [diag2-server.err.log](../../_test_output/stage29-cache-modes-20260629-04/diag2-server.err.log): diagnostic with --parallel 2 -c 4096 (driver default) shows n_ctx_seq=2048 cap confirmed

Suggested Developer fix (one of three):

(a) Wrapper SizeClassMap: add '2k' entry at [compare-legacy-vs-hybrid-workload.ps1:56-60](../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1#L56) with `Target=2000`; verify Stage 20 lib's `New-AgenticChatPrompt` accepts the '2k' size class (the [ValidateSet at agentic-prompt-generator.ps1:87](../../cache-handling-test-scripts/lib/agentic-prompt-generator.ps1#L87) only allows '12k', '24k', '60k', so a 2k entry requires adding '2k' to the ValidateSet and confirming convergence); driver passes `-SizeClass '2k'` at L147/L149.

(b) Driver -Parallel 1: change [compare-legacy-vs-hybrid.ps1:32](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L32) to `[int] $Parallel = 1` so -c 4096 is honored as 4096 per slot. Tradeoff: halves throughput, increases wall-clock budget.

(c) Driver -ContextSize 24576: change [compare-legacy-vs-hybrid.ps1:31](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L31) to `[int] $ContextSize = 24576` so per-slot context is 12288 (24576/2) which fits 12k prompts with headroom. Tradeoff: doubles KV cache memory; verify VRAM budget still fits both modes (hot 512 MiB + cold 2048 MiB + KV 12288*2*hidden_size bytes per slot). May require HotBudgetMiB or ColdBudgetMiB reduction.

The simplest fix is (a): add '2k' SizeClass and call with it. The wrapper's anchor tests at 2k converge at 2000->1969 per F-29-EXEC-09 evidence, so the agentic generator works at smaller sizes.

### F-29-EXEC-12 (RESOLVED, design/driver): equivalence workload MaxIter insufficient

Resolved by S29-IMPL-FIX-06 (Developer session 2026-06-29). Driver L149 changed from `-MaxIterations 50` to `-MaxIterations 200`. This session confirms: workload.jsonl (200 lines) and equivalence-prompts.jsonl (5 lines) both built successfully with the wrapper default SizeClass=12k. No F-29-EXEC-12 exception observed.

### F-29-EXEC-13 (NON-BLOCKING, build): coverage gap on Release without /Zi (carry-forward)

Same as prior F-29-EXEC-04, F-29-EXEC-07, F-29-EXEC-11. `build-cuda/CMakeCache.txt:80` carries `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` (no `/Zi`). OpenCppCoverage at `D:\app\OpenCppCoverage\OpenCppCoverage.exe` exists but cannot produce meaningful coverage on a Release build without debug symbols. TP-29-CV-01 remains BLOCKED-Release-without-/Zi.

### F-29-EXEC-14 (NON-BLOCKING, environment): pytest environment gap (carry-forward)

Same as prior F-29-EXEC-03, F-29-EXEC-06, F-29-EXEC-10. Local Python has `huggingface-hub==1.16.1`; transformers requires `>=0.34.0,<1.0`. Pytest silently collects 0 items when run as `pytest tests/`. Evidence in [pytest.log](../../_test_output/stage29-cache-modes-20260629-04/pytest.log). Focused `test-cache-controller.exe` 142/142 PASS satisfies the regression contract that depends on closed Stage 25-28 invariants.

### F-29-EXEC-16 (NON-BLOCKING, environment): Windows ephemeral port exhaustion on rapid tokenize calls (transient)

First main-path attempt (10:48:43) failed with `Only one usage of each socket address (protocol/network address/port) is normally permitted` at [agentic-prompt-generator.ps1:239](../../cache-handling-test-scripts/lib/agentic-prompt-generator.ps1#L239) when calling `Invoke-WebRequest` to `/tokenize`. Root cause: PowerShell's `Invoke-WebRequest` opens a new TCP connection per call and does not recycle efficiently, leading to TIME_WAIT accumulation. After waiting 60 seconds for TIME_WAIT decay (3258 -> 12 sockets per `Get-NetTCPConnection -State TimeWait`), the second attempt succeeded at Phase 0.5 build. Non-blocking because it was a transient state, not a driver or product bug. Documented for the next QA session to wait for TIME_WAIT decay before launching Phase 0.5 if the system has been recently active.

## Per-row classification

| Row | Status | Evidence |
| --- | --- | --- |
| TP-29-CC-01 (output equivalence) | BLOCKED-context-mismatch | [server.err.log:42-44](../../_test_output/stage29-cache-modes-20260629-04/server.err.log#L42): 400 "request (11480 tokens) exceeds the available context size (2048 tokens)"; [main.log](../../_test_output/stage29-cache-modes-20260629-04/main.log): Main L231-234 BLOCKED-server-not-running 400 |
| TP-29-CC-02 (cold-store validity) | BLOCKED-no-cycles | [main.log](../../_test_output/stage29-cache-modes-20260629-04/main.log): Main died at L231 before Invoke-CycleLeg at L237; no per-leg cold-store evidence produced |
| TP-29-CC-03 (fallback rate) | BLOCKED-no-cycles | same; no per-leg hybrid legs |
| TP-29-CC-04 (cooldown) | BLOCKED-no-cycles | same; no cooldown artifacts |
| TP-29-PR-01 (cache_n_ratio exact) | BLOCKED-no-cycles | no per-leg requests.jsonl produced |
| TP-29-PR-02 (cold-miss ttft) | BLOCKED-no-cycles | no cold-start requests.jsonl produced |
| TP-29-PR-03 (warm-hit p95) | BLOCKED-no-cycles | no warm-cycle requests.jsonl produced |
| TP-29-AG-01 (mean hit rate) | BLOCKED-no-cycles | no per-mode leg evidence |
| TP-29-AG-02 (total tokens reused) | BLOCKED-no-cycles | same |
| TP-29-AG-03 (cold-store bytes) | BLOCKED-no-cycles | same |
| TP-29-AG-04 (VRAM peak) | BLOCKED-no-cycles | no per-leg summary.json produced |
| TP-29-RG-01 (focused + pytest) | PARTIAL | [test-cache-controller.log](../../_test_output/stage29-cache-modes-20260629-04/test-cache-controller.log): 142/142 PASSED; [pytest.log](../../_test_output/stage29-cache-modes-20260629-04/pytest.log): 0 items collected BLOCKED-env |
| TP-29-RG-02 (no tools/server mods) | PASS | [git-status-tools-server.log](../../_test_output/stage29-cache-modes-20260629-04/git-status-tools-server.log) zero-byte; [git-diff-hybrid.log](../../_test_output/stage29-cache-modes-20260629-04/git-diff-hybrid.log) zero-byte |
| TP-29-CV-01 (coverage) | BLOCKED-Release-without-/Zi | [build-cuda/CMakeCache.txt](../../build-cuda/CMakeCache.txt):80 lacks /Zi; OpenCppCoverage installed but unusable |

Final counts: PASS=1, FAIL=0, PARTIAL=1, BLOCKED=12 (11 context-mismatch / no-cycles, 1 Release-without-/Zi). Each BLOCKED-context-mismatch / BLOCKED-no-cycles row is reproducible by re-invoking the driver with the current code; resolution requires the one-line Developer fix from F-29-EXEC-15 (option a: add '2k' SizeClass to wrapper; option b: set --parallel 1; option c: increase -c to 24576).

## Three-layer report (skeleton per design part-05)

Layer 1 Correctness: not produced. CC-01..04 all BLOCKED-context-mismatch / BLOCKED-no-cycles.

Layer 2 Per-request: not produced. PR-01..03 BLOCKED-no-cycles. Workload.jsonl emits 200 lines with 78/65/57 distribution (close to 80/60/60 design target within +/- 5 tolerance per re-review C-01), proving the main workload build path is unblocked once Phase 1+ can run.

Layer 3 Aggregated: not produced. AG-01..04 BLOCKED-no-cycles.

Decision-support Q1..Q5: not produced. Driver output [main.log](../../_test_output/stage29-cache-modes-20260629-04/main.log) shows Main L231-234 BLOCKED-server-not-running 400.

## OWASP table (Stage 10 hardening scope)

| Category | Stage 29 evidence | Verdict |
| --- | --- | --- |
| Input validation | server validates --cache-cold-* flags against --cache-mode hybrid; driver S29-IMPL-FIX-03 verified; server boot succeeded this session; prompt token count vs context is server-side validated (400 returned correctly) | PASS |
| Authentication | /v1/chat/completions not exposed publicly; localhost only | N/A |
| Sensitive data | driver and direct server boot did not log request/response bodies | PASS |
| Logging | server logs verbose=3 by default; no prompt content logged; /tokenize calls at verbosity 3 do not emit log lines | PASS |
| Dependency | binary is post-Stage-28 closure; no new dependencies | PASS |
| Cryptographic | no TLS in scope (localhost-only Stage 29) | N/A |
| Error handling | driver returns exit 1 with descriptive exception in main.log; preflight gate correctly classifies PASS vs BLOCKED; Phase 1 400 properly caught and reported | PASS |
| Resource limits | 1.4 TB disk free on D:; cold path created; ephemeral port transient managed via TIME_WAIT decay wait | PASS |
| Concurrency | --parallel 2 caused per-slot context cap to 2048, surfacing 12k prompt oversize; F-29-EXEC-15 records the design issue | BLOCKED-context-mismatch |
| Replay protection | seed=42 deterministic; no replay surface | PASS |
| Audit | run root populated with setup-env.json, dryrun.log, output-equiv.log, main.log, server.err.log, server.out.log, workload.jsonl, equivalence-prompts.jsonl, test-cache-controller.log, pytest.log, git-status-tools-server.log, git-diff-hybrid.log, diag-server.out.log, diag-server.err.log, diag2-server.out.log, diag2-server.err.log | PASS |
| Configuration | driver default params: HotBudgetMiB=512, ColdBudgetMiB=2048, Cycles=3, ContextSize=4096, Parallel=2, Seed=42; SizeClass default '12k' in wrapper; MaxIterations default 200 in wrapper | PASS |

## Top BLOCKING issues

1. Wrapper SizeClass='12k' prompt exceeds per-slot context (F-29-EXEC-15). Suggested Developer fix: add '2k' entry to SizeClassMap at [compare-legacy-vs-hybrid-workload.ps1:56-60](../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1#L56) and add '2k' to ValidateSet at [agentic-prompt-generator.ps1:87](../../cache-handling-test-scripts/lib/agentic-prompt-generator.ps1#L87), then driver passes `-SizeClass '2k'` at L147/L149. Affects 11 of 14 rows.
2. Coverage tooling gap (carry-forward F-29-EXEC-13): Release build lacks /Zi and OpenCppCoverage cannot produce meaningful coverage. Affects TP-29-CV-01.
3. Pytest environment gap (carry-forward F-29-EXEC-14): huggingface-hub==1.16.1 does not satisfy transformers constraint >=0.34.0,<1.0. Affects TP-29-RG-01 pytest sub-check only; focused tests still 142/142 PASS.
4. Transient ephemeral port exhaustion (F-29-EXEC-16, NON-BLOCKING): wait for TIME_WAIT decay before launching Phase 0.5 if system has been recently active.

## Resolution status of prior BLOCKING

F-29-EXEC-01 (prior session -01): driver flag typo. RESOLVED 2026-06-28 by S29-IMPL-FIX-02. Driver L88 verified to use --cache-cold-path.

F-29-EXEC-04 (prior session -02): driver cold-mode flag coupling. RESOLVED 2026-06-29 by S29-IMPL-FIX-03. Driver L86-93 verified to branch the ArgumentList on `$Mode -eq 'hybrid'`.

F-29-EXEC-08 (prior session -03): driver dot-source missing for agentic-prompt-generator.ps1. RESOLVED 2026-06-29 by S29-IMPL-FIX-04. Driver L44 verified to dot-source `agentic-prompt-generator.ps1` before `compare-legacy-vs-hybrid-workload.ps1`.

F-29-EXEC-09 (prior session -03): wrapper MaxIterations default 50. RESOLVED 2026-06-29 by S29-IMPL-FIX-05. Wrapper default now 200; main workload L147 fixed; equivalence workload L149 subsequently fixed by S29-IMPL-FIX-06.

F-29-EXEC-12 (prior session -05): driver equivalence MaxIter 50 insufficient. RESOLVED 2026-06-29 by S29-IMPL-FIX-06. Driver L149 changed to -MaxIterations 200. Workload.jsonl (200 lines) and equivalence-prompts.jsonl (5 lines) both build successfully this session.

NEW F-29-EXEC-15 (this session -06): wrapper SizeClass='12k' prompts exceed per-slot context. Status: BLOCKING, requires Developer fix.

## Evidence files

All under `_test_output/stage29-cache-modes-20260629-04/`:

- `setup-env.json` (capture, 1554 bytes)
- `dryrun.log` (Phase 0 preflight PASS, 206 bytes)
- `output-equiv.log` (Phase 1 OutputEquivalenceOnly diagnostic, 83 bytes)
- `main.log` (Main L231-234 BLOCKED-server-not-running 400, 331 bytes)
- `server.err.log` (L13 n_ctx_seq cap; L41-44 send_error 400; 3963 bytes)
- `server.out.log` (empty)
- `workload.jsonl` (200 lines, 12060034 bytes; 78/65/57 cache_class distribution; proves Phase 0.5 main workload path is unblocked)
- `equivalence-prompts.jsonl` (5 lines, 302552 bytes; first prompt has 60198 chars / ~12k tokens)
- `phase-1-output-equivalence/` (empty; Phase 1 died before any chat completion)
- `test-cache-controller.log` (142/142 PASS, 19392 bytes)
- `pytest.log` (BLOCKED-env silent collect 0 items)
- `git-status-tools-server.log` (zero-byte; PASS)
- `git-diff-hybrid.log` (zero-byte; PASS)
- `diag-server.out.log` (empty)
- `diag-server.err.log` (--parallel 1 -c 4096 -> n_ctx_seq=4096 confirmed)
- `diag2-server.out.log` (empty)
- `diag2-server.err.log` (--parallel 2 -c 4096 -> n_ctx_seq=2048 confirmed)

## Handoff

Next owner: Developer. The new F-29-EXEC-15 BLOCKING is the single new finding. Suggested fix per memory: add '2k' SizeClass to wrapper SizeClassMap, add '2k' to agentic-prompt-generator ValidateSet, and driver passes `-SizeClass '2k'` at L147 and L149. After Developer fix and review, the next QA execution will re-run the full path and produce real per-leg evidence.

The two non-blocking findings F-29-EXEC-13 (coverage env) and F-29-EXEC-14 (pytest env) are independent of Stage 29 and should be tracked in separate Developer handoffs. F-29-EXEC-16 is a transient observation recorded for the next session.

Next gate: Manager (re-execution gate #6) after Developer fix lands. After re-run PASS: Developer test-results review. After Developer review PASS: Manager closure per D-CLOSURE-29-NN.

This file uses LF line endings, plain ASCII status labels, no BOM, no trailing whitespace, and stays under the 300-line durable-doc cap.
