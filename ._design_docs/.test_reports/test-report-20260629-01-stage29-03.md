# Stage 29 Cache Modes Comparison test execution report (re-run #3)

Run ID: stage29-cache-modes-20260629-01
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Tester: QA session (fresh, third QA session for Stage 29)
Source plan: [../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md](../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md) (Manager test-plan gate PASS 2026-06-28)

Prior reports:

- [test-report-20260628-01-stage29-01.md](test-report-20260628-01-stage29-01.md) (PARTIAL, 11 BLOCKED-driver-flag-typo)
- [test-report-20260628-02-stage29-02.md](test-report-20260628-02-stage29-02.md) (PARTIAL, 11 BLOCKED-driver-cold-mode)
- [test-report-20260628-02-stage29-02-developer-review.md](test-report-20260628-02-stage29-02-developer-review.md) (Developer review REWORK, 0 product bugs)

Design source: [../../cache-handling-phase29-design.md](../../cache-handling-phase29-design.md) (entry + 13 part files)
Implementation source: [../../cache-handling-phase29-implementation.md](../../cache-handling-phase29-implementation.md) (entry + 12 part files; part-12 = S29-IMPL-FIX-03)
Driver: [../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1) (246 LF post S29-IMPL-FIX-03)
Branch: work-branch
Cycles actually executed: 0 of planned 4 (NEW BLOCKING driver dot-source defect at Phase 0.5 L146)

## Verdict

PARTIAL against the Test execution checklist. S29-IMPL-FIX-03 is
VERIFIED WORKING: server.err.log shows a complete healthy legacy boot
(`server is listening on http://127.0.0.1:8900`, `all slots are idle`)
with no `--cache-cold-max-mib requires --cache-mode hybrid` error. The
cold-mode flag coupling defect from the prior session is RESOLVED.

NEW BLOCKING discovered this session: driver
[compare-legacy-vs-hybrid.ps1:42-46](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L42)
dots five lib helpers but does NOT dot-source
[lib/agentic-prompt-generator.ps1](../../cache-handling-test-scripts/lib/agentic-prompt-generator.ps1).
The Stage 29 wrapper
[lib/compare-legacy-vs-hybrid-workload.ps1:106](../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1#L106)
and L142 calls `New-AgenticChatPrompt`, defined only in
`agentic-prompt-generator.ps1:82`. Driver throws `The term
'New-AgenticChatPrompt' is not recognized` at L146 inside
`Invoke-Phase05WorkloadBuild` and exits with code 1 before Phase 0.5
produces any workload. Same scope as the two prior sessions: 11 of 14
rows BLOCKED on the same Phase 0.5 path. Driver contract gap. Single
one-line Developer fix required.

Two regression rows executed (TP-29-RG-01 PARTIAL, TP-29-RG-02 PASS).
Coverage row BLOCKED on the carry-forward Release-without-`/Zi` gap.

## Environment

Capture path: [../../_test_output/stage29-cache-modes-20260629-01/setup-env.json](../../_test_output/stage29-cache-modes-20260629-01/setup-env.json).

- vsdevcmd_path: null (native pwsh); cmake_version: cmake 4.3.2
- k6_version: k6 v2.0.0-rc1; opencppcoverage: null (TP-29-CV-01 BLOCKED-tooling-absent)
- python_version: Python 3.11.9; nvidia_smi driver: 595.79; GPU 16311 MiB (RTX 5060 Ti x2)
- binary_path: `build-cuda\bin\Release\llama-server.exe`; binary_length: 168655360 bytes (Stage 28 closure)
- binary_mtime: 2026-06-27T10:55:11; obj_mtime: 2026-06-27T10:54:23 (48s before binary)
- obj_matches_binary: true per QA memory "re-execution session binary freshness vs content correctness"
- model_path: `._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`; model_length: 2834975040 bytes
- git_head: 97e9c77c9004c4a4fa8d9ef4bc27c5372b6af395; git_dirty_count: 23
- git_modified_tools_server: 0 (TP-29-RG-02 PASS pre-condition)
- pwd: `D:\source\llama.cpp-jet`; ps_version: 7.6.3
- cold_path: `D:\tmp\cache-cold-stage29-03` (created session start)
- run_root: `._test_output\stage29-cache-modes-20260629-01`
- report_path: `._design_docs\.test_reports\test-report-20260629-01-stage29-03.md`
- driver_lines_lf: 246 (under 300 cap; post S29-IMPL-FIX-03)
- cuda_cxx_flags_release: `/O2 /Ob2 /DNDEBUG` (no `/Zi`)
- port_8900_free_at_session_start: true

## Clean-build evidence

Per QA memory "re-execution session binary freshness vs content
correctness", no-op rebuild skipped because (a) source under
`tools/server/`, `tests/`, `common/`, `ggml/` is unchanged per
`git status --short -- tools/server/` returning 0 modifications, and
(b) binary content correctness verified by obj mtime 48s before
binary mtime on 2026-06-27, matching Stage 28 closure. Driver itself
is untracked (`??` prefix); S29-IMPL-FIX-03 fix is on disk at L86-93
and verified by `Select-String -Pattern 'cache-cold'` returning only
L23 (param default) and L90 (conditional branch). Override rationale
recorded per memory rule.

## Commands run

1. Setup-env capture: setup-env.json written via UTF8Encoding($false); driver on disk 14339 bytes, LF=246, CR=0, no BOM, last byte 0x0A.
2. DryRun: pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -DryRun ... ; exit 0; preflight status PASS (ps_version_ok, binary_exists, fixture_exists, port_free, cuda_proof=PASS).
3. OutputEquivalenceOnly (standalone smoke): exit 4 BLOCKED-server-not-running (equivalence-prompts.jsonl missing; expected standalone smoke BLOCK).
4. Full path: pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -Cycles 3 ... ; exit 1 BLOCKED-driver-dot-source (Phase 0.5 workload build at L146 throws "The term 'New-AgenticChatPrompt' is not recognized").
5. TP-29-RG-01 focused tests: build-cuda\bin\Release\test-cache-controller.exe -> 142/142 PASSED (19392 bytes log).
6. TP-29-RG-01 pytest: python -m pytest tests/ -> BLOCKED-env (ImportError huggingface-hub>=0.34.0,<1.0 required, found huggingface-hub==1.16.1).
7. TP-29-RG-02 git status tools/server: empty output, exit 0 (PASS).
8. TP-29-CV-01 CMake cache: build-cuda/CMakeCache.txt:80 CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG (no /Zi).
9. TP-29-CV-01 OpenCppCoverage: not installed at canonical path.

## Findings

### F-29-EXEC-08 (BLOCKING, driver): missing dot-source for agentic-prompt-generator.ps1

The driver at
[compare-legacy-vs-hybrid.ps1:42-46](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L42)
dots five lib helpers but does NOT dot-source
[lib/agentic-prompt-generator.ps1](../../cache-handling-test-scripts/lib/agentic-prompt-generator.ps1).
The Stage 29 wrapper
[compare-legacy-vs-hybrid-workload.ps1:106](../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1#L106)
and L142 calls `New-AgenticChatPrompt`, defined only in
[agentic-prompt-generator.ps1:82](../../cache-handling-test-scripts/lib/agentic-prompt-generator.ps1#L82).
The wrapper's own header at L18-19 documents the expected dot-source
order (`agentic-prompt-generator.ps1` first, then the wrapper), but
the driver does not honour it.

When the driver reaches Phase 0.5 workload build at
[compare-legacy-vs-hybrid.ps1:146](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L146),
`New-ComparisonWorkload` (defined in the wrapper) tries to call
`New-AgenticChatPrompt`, PowerShell cannot resolve the function name,
the inner try-block fails, the server is correctly stopped in the
finally block (port 8900 free after the run), and the exception
propagates with `The term 'New-AgenticChatPrompt' is not recognized`.
The full exception trace is captured in
[main.err.log](../../_test_output/stage29-cache-modes-20260629-01/main.err.log).
Driver exit code: 1.

This is a NEW defect introduced by the Stage 29 implementation: the
prior QA session (-02) never exercised this path because the
cold-mode flag coupling bug short-circuited the run at server boot
before Phase 0.5 ever started. The wrapper has called
`New-AgenticChatPrompt` since its design-correction authoring (per
the wrapper header), so the bug has been latent since the wrapper
existed but was hidden behind the prior BLOCKING failures.

Suggested one-line Developer fix: insert a new dot-source line at
driver L42 (before the wrapper dot-source) so
`agentic-prompt-generator.ps1` loads first. After the fix, the
driver's `Invoke-Phase05WorkloadBuild` can resolve
`New-AgenticChatPrompt` and proceed to Phase 0.5 success. No other
code or test changes required.

### F-29-EXEC-09 (NON-BLOCKING, evidence): S29-IMPL-FIX-03 verified working

The server.err.log from this session
[../../_test_output/stage29-cache-modes-20260629-01/server.err.log](../../_test_output/stage29-cache-modes-20260629-01/server.err.log)
shows a complete healthy legacy boot, no cold-path rejection. Last
three boot lines: `I srv  llama_server: model loaded`,
`I srv  llama_server: server is listening on http://127.0.0.1:8900`,
`I srv  update_slots: all slots are idle`. This proves the
S29-IMPL-FIX-03 driver fix (cold-path flags gated on `$Mode -eq 'hybrid'`
at driver L86-93) is correctly applied: the legacy boot succeeds
without the `--cache-cold-max-mib requires --cache-mode hybrid`
rejection. The prior session's BLOCKING driver-cold-mode finding is
fully resolved.

### F-29-EXEC-10 (NON-BLOCKING, environment): pytest environment gap (carry-forward)

Same as prior F-29-EXEC-03 and F-29-EXEC-06. Local Python has
`huggingface-hub==1.16.1`; transformers requires `>=0.34.0,<1.0`.
Pytest silently collects 0 items when run as `pytest tests/` and
explicitly fails to import `tests/test-tokenizer-0.py` when targeted
directly. Evidence in
[pytest.log](../../_test_output/stage29-cache-modes-20260629-01/pytest.log)
and
[pytest-collect-error.log](../../_test_output/stage29-cache-modes-20260629-01/pytest-collect-error.log).
Focused `test-cache-controller.exe` 142/142 PASS satisfies the
regression contract that depends on closed Stage 25-28 invariants.

### F-29-EXEC-11 (NON-BLOCKING, build): coverage gap on Release without /Zi (carry-forward)

Same as prior F-29-EXEC-04 and F-29-EXEC-07.
`build-cuda/CMakeCache.txt:80` carries `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG`
(no `/Zi`). OpenCppCoverage not installed at canonical path on this
host. TP-29-CV-01 remains BLOCKED-Release-without-/Zi.

## Per-row classification

| Row | Status | Evidence |
| --- | --- | --- |
| TP-29-CC-01 (output equivalence) | BLOCKED-driver-dot-source | [main.err.log](../../_test_output/stage29-cache-modes-20260629-01/main.err.log): New-AgenticChatPrompt not recognized at L146; driver L42 missing dot-source |
| TP-29-CC-02 (cold-store validity) | BLOCKED-driver-dot-source | same; cold-store never populated by driver |
| TP-29-CC-03 (fallback rate) | BLOCKED-driver-dot-source | no per-leg metrics produced |
| TP-29-CC-04 (cooldown) | BLOCKED-driver-dot-source | no per-leg cooldown evidence |
| TP-29-PR-01 (cache_n_ratio exact) | BLOCKED-driver-dot-source | no per-leg requests.jsonl produced |
| TP-29-PR-02 (cold-miss ttft) | BLOCKED-driver-dot-source | no cold-miss vs warm-miss split |
| TP-29-PR-03 (warm-hit p95) | BLOCKED-driver-dot-source | no warm-cycle requests.jsonl produced |
| TP-29-AG-01 (mean hit rate) | BLOCKED-driver-dot-source | no aggregated request rows produced |
| TP-29-AG-02 (total tokens reused) | BLOCKED-driver-dot-source | same |
| TP-29-AG-03 (cold-store bytes) | BLOCKED-driver-dot-source | same |
| TP-29-AG-04 (VRAM peak) | BLOCKED-driver-dot-source | no per-leg summary.json produced |
| TP-29-RG-01 (focused + pytest) | PARTIAL | test-cache-controller 142/142 PASS ([test-cache-controller.log](../../_test_output/stage29-cache-modes-20260629-01/test-cache-controller.log)); pytest BLOCKED-env ([pytest.log](../../_test_output/stage29-cache-modes-20260629-01/pytest.log)) |
| TP-29-RG-02 (no tools/server mods) | PASS | `git status --short -- tools/server/` returned 0 entries ([git-status-tools-server.log](../../_test_output/stage29-cache-modes-20260629-01/git-status-tools-server.log)) |
| TP-29-CV-01 (coverage) | BLOCKED-Release-without-/Zi | `build-cuda/CMakeCache.txt:80` lacks `/Zi`; OpenCppCoverage not installed |

Final counts: PASS=1, FAIL=0, PARTIAL=1, BLOCKED=12 (11 driver-dot-source,
1 Release-without-/Zi). Each BLOCKED-driver-dot-source row is
reproducible by re-invoking the driver with the current code;
resolution requires the one-line Developer fix at driver L42 to dot
`agentic-prompt-generator.ps1` before `compare-legacy-vs-hybrid-workload.ps1`.

## Three-layer report (skeleton per design part-05)

Layer 1 Correctness: not produced. CC-01..04 all BLOCKED-driver-dot-source.
Direct server boot evidence shows the legacy mode boot succeeds
(server.err.log: `server is listening on http://127.0.0.1:8900`,
`all slots are idle`) with no cold-path rejection, proving the
S29-IMPL-FIX-03 fix is applied.

Layer 2 Per-request: not produced. PR-01..03 BLOCKED-driver-dot-source;
no per-cycle requests.jsonl files exist under the run root.

Layer 3 Aggregated: not produced. AG-01..04 BLOCKED-driver-dot-source;
no `summary.json` produced.

Decision-support Q1..Q5: not produced. Driver output
[main.log](../../_test_output/stage29-cache-modes-20260629-01/main.log)
is empty; the exception is in
[main.err.log](../../_test_output/stage29-cache-modes-20260629-01/main.err.log).

## OWASP table (Stage 10 hardening scope)

| Category | Stage 29 evidence | Verdict |
| --- | --- | --- |
| Input validation | server validates `--cache-cold-*` flags against `--cache-mode hybrid` (server-context.cpp:611-622); driver S29-IMPL-FIX-03 verified | PASS |
| Authentication | `/v1/chat/completions` not exposed publicly; localhost only | N/A |
| Sensitive data | driver and direct server boot did not log request/response bodies | PASS |
| Logging | server logs verbose=3 by default; no prompt content logged | PASS |
| Dependency | binary is post-Stage-28 closure; no new dependencies | PASS |
| Cryptographic | no TLS in scope (localhost-only Stage 29) | N/A |
| Error handling | driver returns exit 1 with descriptive exception in main.err.log | PASS |
| Resource limits | 1.4 TB disk free on D:; cold path created | PASS |
| Concurrency | single --parallel=2 not exercised (driver BLOCKED at Phase 0.5) | BLOCKED-driver-dot-source |
| Replay protection | seed=42 deterministic; no replay surface | PASS |
| Audit | run root populated with setup-env.json, dryrun.log, output-equivalence-standalone.log, main.log, main.err.log, server.err.log, server.out.log, test-cache-controller.log, pytest.log, pytest-collect-error.log, pip-huggingface-hub.log, git-status-tools-server.log, git-diff-driver.log, git-status-driver.log | PASS |
| Configuration | driver default params: HotBudgetMiB=512, ColdBudgetMiB=2048, Cycles=3, ContextSize=4096, Parallel=2, Seed=42 | PASS |

## Top BLOCKING issues

1. Driver dot-source missing for `agentic-prompt-generator.ps1` (driver L42).
   One-line Developer fix: add `. (Join-Path $libDir 'agentic-prompt-generator.ps1')`
   before the wrapper dot-source at L43. Wrapper calls
   `New-AgenticChatPrompt` (wrapper L106, L142) defined only in
   `agentic-prompt-generator.ps1:82`. Driver throws at L146 in
   `Invoke-Phase05WorkloadBuild` with `The term 'New-AgenticChatPrompt'
   is not recognized`. Affects 11 of 14 rows.
2. Coverage tooling gap (carry-forward): Release build lacks `/Zi` and
   OpenCppCoverage not installed at canonical path. Affects TP-29-CV-01.
3. Pytest environment gap (carry-forward): `huggingface-hub==1.16.1` does
   not satisfy transformers constraint `>=0.34.0,<1.0`. Affects TP-29-RG-01
   pytest sub-check only; focused tests still 142/142 PASS.

## Resolution status of prior BLOCKING

F-29-EXEC-01 (prior session -01): driver flag typo `--cache-cold-dir` to
`--cache-cold-path`. RESOLVED 2026-06-28 by S29-IMPL-FIX-02. Driver L88
verified to use `--cache-cold-path`. Grep across
`._design_docs/cache-handling-test-scripts/` returned 0 remaining
`--cache-cold-dir` occurrences.

F-29-EXEC-04 (prior session -02): driver cold-mode flag coupling
(cold-path flags passed to legacy mode). RESOLVED 2026-06-29 by
S29-IMPL-FIX-03. Driver L86-93 verified to branch the ArgumentList on
`$Mode -eq 'hybrid'`. Server.err.log this session shows a healthy
legacy boot with no cold-path rejection (full boot sequence at
server-context.cpp:611-622 succeeds). The cold-mode coupling is no
longer an issue; the new BLOCKING (F-29-EXEC-08) is a separate driver
contract defect.

## Evidence files

All under `._test_output/stage29-cache-modes-20260629-01/`:

- `setup-env.json` (capture)
- `dryrun.log` (Phase 0 preflight PASS, 207 bytes)
- `output-equivalence-standalone.log` (standalone smoke BLOCK 4, 83 bytes)
- `main.log` (empty; driver wrote exception to main.err.log)
- `main.err.log` (driver exception: BLOCKED-driver-dot-source at L146)
- `server.err.log` (Phase 0.5 server stderr; healthy legacy boot, 2952 bytes)
- `server.out.log` (empty)
- `test-cache-controller.log` (142/142 PASS, 19392 bytes)
- `pytest.log` (BLOCKED-env silent collect 0 items)
- `pytest-collect-error.log` (BLOCKED-env explicit collect error showing huggingface-hub==1.16.1 mismatch)
- `pip-huggingface-hub.log` (huggingface-hub==1.16.1)
- `git-status-tools-server.log` (0 modifications)
- `git-diff-driver.log` (empty; driver untracked, no diff)
- `git-status-driver.log` (driver `??` prefix, no modifications since prior)

## Handoff

Next owner: Developer. Single one-line fix at driver L42 to insert
`. (Join-Path $libDir 'agentic-prompt-generator.ps1')` before the
wrapper dot-source at L43, restoring the wrapper's documented
dot-source order from `compare-legacy-vs-hybrid-workload.ps1:18-19`.
After Developer fix and review, the next QA execution will re-run
the full path and produce real per-leg evidence.

The two non-blocking findings F-29-EXEC-10 (pytest env) and
F-29-EXEC-11 (coverage tooling) are independent of Stage 29 and
should be tracked in separate Developer handoffs.

Next gate: Manager (re-execution gate #4) after Developer fix lands.
After re-run PASS: Developer test-results review. After Developer
review PASS: Manager closure per D-CLOSURE-29-NN.

This file uses LF line endings, plain ASCII status labels, no BOM,
no trailing whitespace.
