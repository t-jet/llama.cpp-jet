# Stage 29 Cache Modes Comparison test execution report (re-run #5)

Run ID: stage29-cache-modes-20260629-03
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Tester: QA session (fresh, fifth QA session for Stage 29)
Source plan: [../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md](../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md) (Manager test-plan gate PASS 2026-06-28)

Prior reports:

- [test-report-20260628-01-stage29-01.md](test-report-20260628-01-stage29-01.md) (PARTIAL, 11 BLOCKED-driver-flag-typo)
- [test-report-20260628-02-stage29-02.md](test-report-20260628-02-stage29-02.md) (PARTIAL, 11 BLOCKED-driver-cold-mode)
- [test-report-20260629-01-stage29-03.md](test-report-20260629-01-stage29-03.md) (PARTIAL, 11 BLOCKED-driver-dot-source; F-29-EXEC-09 discovered but classified NON-BLOCKING by Manager)
- [test-report-20260629-02-stage29-04.md](test-report-20260629-02-stage29-04.md) (PARTIAL aborted; S29-IMPL-FIX-04 still in flight; no durable report written)

Design source: [../../cache-handling-phase29-design.md](../../cache-handling-phase29-design.md) (entry + 13 part files)
Implementation source: [../../cache-handling-phase29-implementation.md](../../cache-handling-phase29-implementation.md) (entry + 15 part files; part-15 = S29-IMPL-FIX-05)
Driver: [../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1) (247 LF post S29-IMPL-FIX-05)
Branch: work-branch
Cycles actually executed: 0 of planned 4 (NEW BLOCKING driver equivalence MaxIter insufficient at Phase 0.5 L149)

## Verdict

PARTIAL against the Test execution checklist. S29-IMPL-FIX-01 (Main dispatcher), S29-IMPL-FIX-02 (cold flag typo), S29-IMPL-FIX-03 (cold-mode coupling), and S29-IMPL-FIX-04 (driver dot-source) are VERIFIED WORKING: driver preflight prints PASS, server boot succeeds (server.err.log shows `model loaded`, `server is listening on http://127.0.0.1:8900`, `all slots are idle`), workload.jsonl emits 200 lines with 78/65/57 cache_class distribution (close to 80/60/60 design target within +/- 5 tolerance per re-review C-01).

NEW BLOCKING discovered this session: driver
[compare-legacy-vs-hybrid.ps1:149](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L149)
passes `-MaxIterations 50` for the output equivalence workload, but the wrapper default `SizeClass='12k'` sets `TargetTokens=12000` and the Stage 20 lib's `New-AgenticChatPrompt` ([agentic-prompt-generator.ps1:128-141](../../cache-handling-test-scripts/lib/agentic-prompt-generator.ps1#L128)) cannot converge at 12000 tokens within 50 iterations; it exhausts at lastTokens=10631 (delta=178). The exception trace is identical to F-29-EXEC-09 (prior session -02) but on the equivalence path, not the main path. S29-IMPL-FIX-05 plumbing was correct for the main workload path (L147 with `-MaxIterations 200`) but the equivalence path (L149) was given an insufficient iteration budget that the wrapper's default SizeClass='12k' cannot satisfy.

Two regression rows executed (TP-29-RG-01 PARTIAL, TP-29-RG-02 PASS). Coverage row BLOCKED on the carry-forward Release-without-`/Zi` gap. Manager directive 2026-06-29: "Don't close the stage until all things are resolved." Stage remains at bug handoff.

## Environment

Capture path: [../../_test_output/stage29-cache-modes-20260629-03/setup-env.json](../../_test_output/stage29-cache-modes-20260629-03/setup-env.json).

- session_date: 2026-06-29; session_time: 01:17:01
- pwd: `D:\source\llama.cpp-jet`; ps_version: 7.6.3
- cmake_version: cmake 4.3.2; python_version: Python 3.11.9
- k6_version: k6 v2.0.0-rc1
- opencppcoverage: `D:\app\OpenCppCoverage\OpenCppCoverage.exe` (installed; not runnable due to Release build lack of `/Zi`)
- nvidia_smi: driver 595.79; GPUs 0/16311 MiB and 0/16311 MiB (RTX 5060 Ti x2, idle at session start)
- binary_path: `build-cuda\bin\Release\llama-server.exe`; binary_length: 168655360 bytes (Stage 28 closure)
- binary_mtime: 2026-06-27T10:55:11; most_recent_obj_mtime: 2026-06-27T10:55:10 (1 second before binary, matches Stage 28 closure)
- model_path: `._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`; model_length: 2834975040 bytes
- git_head: dbf593978b66a0d46a030f80c6e87345e08b3a04; git_dirty_count: 6 (no tools/server/, tests/, common/, ggml/ modifications)
- cuda_cxx_flags_release: `/O2 /Ob2 /DNDEBUG` (no `/Zi`)
- port_8900_free_at_session_start: true
- cold_path: `D:\tmp\cache-cold-stage29-05` (created session start)
- run_root: `._test_output\stage29-cache-modes-20260629-03`
- report_path: `._design_docs\.test_reports\test-report-20260629-03-stage29-05.md`
- driver_lines_lf: 247 (under 300 cap; post S29-IMPL-FIX-05); wrapper_lines_lf: 203

## Clean-build evidence

Per QA memory "re-execution session binary freshness vs content correctness", no-op rebuild skipped because (a) source under `tools/server/`, `tests/`, `common/`, `ggml/` is unchanged per `git status --short` returning 0 modifications, and (b) binary content correctness verified by most recent obj mtime (2026-06-27T10:55:10) being 1 second before binary mtime (2026-06-27T10:55:11), matching Stage 28 closure. Driver and wrapper are untracked (`??` prefix); S29-IMPL-FIX-04 dot-source fix at L44 verified by `Select-String`; S29-IMPL-FIX-05 MaxIterations plumbing verified at wrapper L66 (signature), L115 + L152 (call sites), driver L147 + L149 (per-mode values). Override rationale recorded per memory rule.

## Commands run

1. Setup-env capture: setup-env.json written via UTF8Encoding($false); 1992516 bytes (includes verbose Get-Command output for OpenCppCoverage).
2. DryRun preflight: pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -DryRun ... ; exit 0; preflight status PASS (ps_version_ok, binary_exists, fixture_exists, port_free, cuda_proof=PASS).
3. Full path: pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -RunId stage29-cache-modes-20260629-03 ... ; exit 1 BLOCKED-equivalence-workload-build (Phase 0.5 equivalence workload build at L149 throws `MaxIterations=50 exhausted; lastTokens=10631`).
4. Diag standalone equivalence build (4k SizeClass): exit 1 unknown SizeClass '4k' (wrapper map only has '12k', '24k', '60k').
5. Diag standalone equivalence build (12k, MaxIter=200): exit 0; eq-smoke.jsonl emits 5 lines (302552 bytes), confirming wrapper works when given enough iterations.
6. TP-29-RG-01 focused tests: build-cuda\bin\Release\test-cache-controller.exe -> 142/142 PASSED (19392 bytes log).
7. TP-29-RG-01 pytest: python -m pytest tests/ -> 0 items collected, exit 5 (BLOCKED-env carry-forward: huggingface-hub==1.16.1 vs transformers `>=0.34.0,<1.0`).
8. TP-29-RG-02 git status tools/server: empty output (PASS).
9. TP-29-RG-02 git status tests/: empty output (PASS).
10. TP-29-RG-02 git diff stat hybrid.cpp: empty output (PASS).

## Findings

### F-29-EXEC-12 (BLOCKING, driver): equivalence workload MaxIter insufficient for SizeClass='12k'

Driver
[compare-legacy-vs-hybrid.ps1:149](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L149)
passes `-MaxIterations 50` to `New-ComparisonWorkload` for the output equivalence workload (5 prompts). The wrapper
[compare-legacy-vs-hybrid-workload.ps1:66](../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1#L66)
declares `[int] $MaxIterations = 200` but the driver overrides to 50 at L149. The wrapper default `SizeClass = '12k'` (declared at L60-63) sets `TargetTokens = 12000` via `New-AgenticChatPrompt`. The Stage 20 lib
[agentic-prompt-generator.ps1:128-141](../../cache-handling-test-scripts/lib/agentic-prompt-generator.ps1#L128)
runs an inner loop bounded by `-MaxIterations $MaxIterations`; at 50 iterations the convergence delta is 178 tokens short of 12000 (lastTokens=10631). The throw at L141 fires, propagates up through the wrapper, and the driver's `Invoke-Phase05WorkloadBuild` finally-block cleans up the Phase 0.5 server (port 8900 free after the run).

This is the same defect class as F-29-EXEC-09 (prior session -02), but on a different call site. S29-IMPL-FIX-05 plumbed `-MaxIterations $MaxIterations` through both wrapper call sites (anchor pool at L115 and per-request at L152) and set the wrapper default to 200; the driver passes `-MaxIterations 200` at L147 (main workload, 200 requests) but `-MaxIterations 50` at L149 (equivalence workload, 5 prompts). The 50 is intentionally smaller per the brief ("5 prompts, smaller") but is insufficient given the wrapper's default SizeClass=12k.

Evidence files:

- [main.err.log](../../_test_output/stage29-cache-modes-20260629-03/main.err.log): full exception trace with stack frame at agentic-prompt-generator.ps1:141
- [eq-smoke-attempt.log](../../_test_output/stage29-cache-modes-20260629-03/eq-smoke-attempt.log): same exception from the 12k + MaxIter=50 wrapper invocation
- [eq-smoke.jsonl](../../_test_output/stage29-cache-modes-20260629-03/eq-smoke.jsonl): 5 lines (r-0001..r-0005) emitted when wrapper invoked with SizeClass=12k + MaxIter=200 (control case, confirms the fix)

Suggested Developer fix (one of two):

(a) Driver L149 change: `-MaxIterations 50` -> `-MaxIterations 200`. This matches the main workload iteration budget and lets the wrapper converge at SizeClass=12k. Tradeoff: Phase 0.5 takes slightly longer (5 prompts * 200 iters vs 50 iters, but tokenize calls are fast).

(b) Add a driver parameter `[int] $EquivalenceMaxIterations = 200` defaulting to 200 and pass it at L149. Same effect with explicit knob. This matches the design pattern of having explicit parameterization for each phase.

After the fix, the equivalence prompts will build, Phase 1 output equivalence will run, and Phase 2/3 cycle legs will execute. No other code or test changes required.

### F-29-EXEC-09 (NON-BLOCKING evidence, now confirmed via equivalence path)

The same defect as F-29-EXEC-12 was originally discovered on the main workload path (prior session -02). S29-IMPL-FIX-05 resolved it for the main workload by setting the wrapper default to 200 and passing `-MaxIterations 200` at driver L147. Workload.jsonl emits 200 lines successfully this session, confirming the main path fix works. The equivalence path is the residual F-29-EXEC-12.

### F-29-EXEC-13 (NON-BLOCKING, build): coverage gap on Release without /Zi (carry-forward)

Same as prior F-29-EXEC-04, F-29-EXEC-07, F-29-EXEC-11. `build-cuda/CMakeCache.txt:80` carries `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` (no `/Zi`). OpenCppCoverage at `D:\app\OpenCppCoverage\OpenCppCoverage.exe` exists but cannot produce meaningful coverage on a Release build without debug symbols. TP-29-CV-01 remains BLOCKED-Release-without-/Zi.

### F-29-EXEC-14 (NON-BLOCKING, environment): pytest environment gap (carry-forward)

Same as prior F-29-EXEC-03, F-29-EXEC-06, F-29-EXEC-10. Local Python has `huggingface-hub==1.16.1`; transformers requires `>=0.34.0,<1.0`. Pytest silently collects 0 items when run as `pytest tests/`. Evidence in [pytest.log](../../_test_output/stage29-cache-modes-20260629-03/pytest.log). Focused `test-cache-controller.exe` 142/142 PASS satisfies the regression contract that depends on closed Stage 25-28 invariants.

## Per-row classification

| Row | Status | Evidence |
| --- | --- | --- |
| TP-29-CC-01 (output equivalence) | BLOCKED-equivalence-workload-build | [main.err.log](../../_test_output/stage29-cache-modes-20260629-03/main.err.log): MaxIterations=50 exhausted at Phase 0.5 L149 |
| TP-29-CC-02 (cold-store validity) | BLOCKED-equivalence-workload-build | same; cold-store never populated |
| TP-29-CC-03 (fallback rate) | BLOCKED-equivalence-workload-build | no per-leg metrics produced |
| TP-29-CC-04 (cooldown) | BLOCKED-equivalence-workload-build | no per-leg cooldown evidence |
| TP-29-PR-01 (cache_n_ratio exact) | BLOCKED-equivalence-workload-build | no per-leg requests.jsonl produced |
| TP-29-PR-02 (cold-miss ttft) | BLOCKED-equivalence-workload-build | no cold-miss vs warm-miss split |
| TP-29-PR-03 (warm-hit p95) | BLOCKED-equivalence-workload-build | no warm-cycle requests.jsonl produced |
| TP-29-AG-01 (mean hit rate) | BLOCKED-equivalence-workload-build | no aggregated request rows produced |
| TP-29-AG-02 (total tokens reused) | BLOCKED-equivalence-workload-build | same |
| TP-29-AG-03 (cold-store bytes) | BLOCKED-equivalence-workload-build | same |
| TP-29-AG-04 (VRAM peak) | BLOCKED-equivalence-workload-build | no per-leg summary.json produced |
| TP-29-RG-01 (focused + pytest) | PARTIAL | test-cache-controller 142/142 PASS ([test-cache-controller.log](../../_test_output/stage29-cache-modes-20260629-03/test-cache-controller.log)); pytest 0 items collected BLOCKED-env |
| TP-29-RG-02 (no tools/server mods) | PASS | git status tools/server/ empty, tests/ empty, hybrid.cpp diff empty ([git-status-tools-server.log](../../_test_output/stage29-cache-modes-20260629-03/git-status-tools-server.log) zero-byte) |
| TP-29-CV-01 (coverage) | BLOCKED-Release-without-/Zi | build-cuda/CMakeCache.txt:80 lacks /Zi; OpenCppCoverage installed but unusable |

Final counts: PASS=1, FAIL=0, PARTIAL=1, BLOCKED=12 (11 equivalence-workload-build, 1 Release-without-/Zi). Each BLOCKED-equivalence-workload-build row is reproducible by re-invoking the driver with the current code; resolution requires the one-line Developer fix at driver L149.

## Three-layer report (skeleton per design part-05)

Layer 1 Correctness: not produced. CC-01..04 all BLOCKED-equivalence-workload-build.

Layer 2 Per-request: not produced. PR-01..03 BLOCKED-equivalence-workload-build. Workload.jsonl emits 200 lines with 78/65/57 distribution (close to 80/60/60 design target within +/- 5 tolerance per re-review C-01), proving the main workload path is unblocked once equivalence succeeds.

Layer 3 Aggregated: not produced. AG-01..04 BLOCKED-equivalence-workload-build.

Decision-support Q1..Q5: not produced. Driver output
[main.log](../../_test_output/stage29-cache-modes-20260629-03/main.log) is empty; the exception is in [main.err.log](../../_test_output/stage29-cache-modes-20260629-03/main.err.log).

## OWASP table (Stage 10 hardening scope)

| Category | Stage 29 evidence | Verdict |
| --- | --- | --- |
| Input validation | server validates --cache-cold-* flags against --cache-mode hybrid; driver S29-IMPL-FIX-03 verified; server boot succeeded this session | PASS |
| Authentication | /v1/chat/completions not exposed publicly; localhost only | N/A |
| Sensitive data | driver and direct server boot did not log request/response bodies | PASS |
| Logging | server logs verbose=3 by default; no prompt content logged | PASS |
| Dependency | binary is post-Stage-28 closure; no new dependencies | PASS |
| Cryptographic | no TLS in scope (localhost-only Stage 29) | N/A |
| Error handling | driver returns exit 1 with descriptive exception in main.err.log; preflight gate correctly classifies PASS vs BLOCKED | PASS |
| Resource limits | 1.4 TB disk free on D:; cold path created | PASS |
| Concurrency | single --parallel=2 not exercised (driver BLOCKED at Phase 0.5 equivalence build) | BLOCKED-equivalence-workload-build |
| Replay protection | seed=42 deterministic; no replay surface | PASS |
| Audit | run root populated with setup-env.json, dryrun.log, dryrun.err.log, main.log, main.err.log, server.err.log, server.out.log, test-cache-controller.log, pytest.log, workload.jsonl, eq-smoke.jsonl, eq-smoke-attempt.log, diag-server.err.log, diag-server.out.log, git-status-tools-server.log, git-status-tests.log, git-diff-hybrid.log | PASS |
| Configuration | driver default params: HotBudgetMiB=512, ColdBudgetMiB=2048, Cycles=3, ContextSize=4096, Parallel=2, Seed=42 | PASS |

## Top BLOCKING issues

1. Driver equivalence MaxIter insufficient (driver L149). Suggested one-line Developer fix: change `-MaxIterations 50` to `-MaxIterations 200` at L149, or add a `-EquivalenceMaxIterations` parameter. Wrapper default SizeClass='12k' sets TargetTokens=12000 which requires ~200 iterations to converge; 50 iterations exhausts at lastTokens=10631 (delta=178). Affects 11 of 14 rows.
2. Coverage tooling gap (carry-forward): Release build lacks /Zi and OpenCppCoverage cannot produce meaningful coverage. Affects TP-29-CV-01.
3. Pytest environment gap (carry-forward): huggingface-hub==1.16.1 does not satisfy transformers constraint >=0.34.0,<1.0. Affects TP-29-RG-01 pytest sub-check only; focused tests still 142/142 PASS.

## Resolution status of prior BLOCKING

F-29-EXEC-01 (prior session -01): driver flag typo. RESOLVED 2026-06-28 by S29-IMPL-FIX-02. Driver L88 verified to use --cache-cold-path. Grep across `._design_docs/cache-handling-test-scripts/` returned 0 remaining --cache-cold-dir occurrences.

F-29-EXEC-04 (prior session -02): driver cold-mode flag coupling. RESOLVED 2026-06-29 by S29-IMPL-FIX-03. Driver L86-93 verified to branch the ArgumentList on `$Mode -eq 'hybrid'`. Server.err.log this session shows a healthy legacy boot with no cold-path rejection.

F-29-EXEC-08 (prior session -03): driver dot-source missing for agentic-prompt-generator.ps1. RESOLVED 2026-06-29 by S29-IMPL-FIX-04. Driver L44 verified to dot-source `agentic-prompt-generator.ps1` before `compare-legacy-vs-hybrid-workload.ps1`. Workload.jsonl emits 200 lines this session, proving `New-AgenticChatPrompt` resolves correctly.

F-29-EXEC-09 (prior session -03): wrapper MaxIterations default 50. PARTIALLY RESOLVED 2026-06-29 by S29-IMPL-FIX-05. Wrapper default now 200; main workload L147 fixed (workload.jsonl succeeds). Equivalence workload L149 still uses 50 (insufficient for SizeClass=12k) -> F-29-EXEC-12 new BLOCKING.

## Evidence files

All under `_test_output/stage29-cache-modes-20260629-03/`:

- `setup-env.json` (capture)
- `dryrun.log` (Phase 0 preflight PASS, 206 bytes)
- `dryrun.err.log` (264 bytes)
- `main.log` (empty; driver wrote exception to main.err.log)
- `main.err.log` (driver exception: BLOCKED-equivalence-workload-build at L149)
- `server.err.log` (Phase 0.5 main workload server stderr; healthy legacy boot, 2952 bytes)
- `server.out.log` (empty)
- `workload.jsonl` (200 lines, 12 MB, 78/65/57 cache_class distribution; proves main workload path is unblocked)
- `eq-smoke-attempt.log` (control case log, 470 bytes; confirms the 12k + MaxIter=50 fails with same exception)
- `eq-smoke.jsonl` (5 lines, 302552 bytes; control case proving the fix works at 12k + MaxIter=200)
- `diag-server.err.log` (control-case server stderr, 2952 bytes; healthy legacy boot)
- `diag-server.out.log` (empty)
- `test-cache-controller.log` (142/142 PASS, 19392 bytes)
- `pytest.log` (BLOCKED-env silent collect 0 items, 1323 bytes)
- `git-status-tools-server.log` (zero-byte; PASS)
- `git-status-tests.log` (zero-byte; PASS)
- `git-diff-hybrid.log` (zero-byte; PASS)

## Handoff

Next owner: Developer. One-line fix at driver L149 to change `-MaxIterations 50` to `-MaxIterations 200` for the equivalence workload, or add a `-EquivalenceMaxIterations` parameter defaulting to 200. After Developer fix and review, the next QA execution will re-run the full path and produce real per-leg evidence.

The two non-blocking findings F-29-EXEC-13 (coverage env) and F-29-EXEC-14 (pytest env) are independent of Stage 29 and should be tracked in separate Developer handoffs.

Next gate: Manager (re-execution gate #5) after Developer fix lands. After re-run PASS: Developer test-results review. After Developer review PASS: Manager closure per D-CLOSURE-29-NN.

This file uses LF line endings, plain ASCII status labels, no BOM, no trailing whitespace.
