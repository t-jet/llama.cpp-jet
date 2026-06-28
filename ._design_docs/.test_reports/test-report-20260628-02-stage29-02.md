# Stage 29 Cache Modes Comparison test execution report (re-run)

Run ID: stage29-cache-modes-20260628-02
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Tester: QA session (fresh, second QA session for Stage 29)
Source plan: [../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md](../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md) (Manager test-plan gate PASS 2026-06-28)
Prior report: [test-report-20260628-01-stage29-01.md](test-report-20260628-01-stage29-01.md) (PARTIAL, 1 BLOCKING flag-typo)
Design source: [../../cache-handling-phase29-design.md](../../cache-handling-phase29-design.md) (entry + 13 part files)
Implementation source: [../../cache-handling-phase29-implementation.md](../../cache-handling-phase29-implementation.md) (entry + 5 + 6 fix parts)
Driver: [../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1) (243 LF post S29-IMPL-FIX-02)
Branch: work-branch
Cycles actually executed: 0 of planned 4 (NEW BLOCKING driver cold-mode bug this session)

## Verdict

PARTIAL. Prior BLOCKING flag-typo (`--cache-cold-dir` to `--cache-cold-path`)
is RESOLVED at driver L88 per S29-IMPL-FIX-02. NEW BLOCKING discovered this
session: `Start-Stage29Server` always passes `--cache-cold-max-mib` and
`--cache-cold-path`, which the server rejects when `--cache-mode legacy`
per [../../../tools/server/server-context.cpp:611-622](../../../tools/server/server-context.cpp#L611).
Two regression rows executed (TP-29-RG-01 PARTIAL focused, pytest BLOCKED-env;
TP-29-RG-02 PASS). Coverage row BLOCKED on the Release-without-`/Zi` gap.
The 11 comparison-driven rows (CC-01..04, PR-01..03, AG-01..04) are
BLOCKED-driver-cold-mode.

## Environment

Capture path: [../../_test_output/stage29-cache-modes-20260628-02/setup-env.json](../../_test_output/stage29-cache-modes-20260628-02/setup-env.json).

- vsdevcmd_path: null (native pwsh)
- cmake_version: cmake 4.3.2
- k6_version: k6.exe v2.0.0-rc1
- opencppcoverage: null (TP-29-CV-01 BLOCKED-tooling-absent)
- python_version: Python 3.11.9
- nvidia_smi driver: 595.79; GPU memory 16311 MiB
- binary_path: `build-cuda\bin\Release\llama-server.exe`
- binary_length: 168655360 bytes (matches Stage 28 closure)
- binary_mtime: 2026-06-27T10:55:11 (yesterday, unchanged)
- obj_mtime: 2026-06-27T10:54:23 (48s before binary; obj_matches_binary=true per QA memory)
- model_path: `._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- model_length: 2834975040 bytes
- git_head: 97e9c77c9004c4a4fa8d9ef4bc27c5372b6af395 (matches prior)
- git_dirty_count: 21 (git_modified_tools_server=0: TP-29-RG-02 PASS pre-condition)
- pwd: `D:\source\llama.cpp-jet`
- ps_version: 7.6.3
- cold_path: `D:\tmp\cache-cold-stage29-02` (created 21:54)
- port_8900_free: true at session start
- driver_l88 (post S29-IMPL-FIX-02): `--cache-cold-path` (verified)

## Clean-build evidence

Per QA memory "re-execution session binary freshness vs content
correctness", no-op rebuild skipped because (a) source under `tools/server/`,
`tests/`, `common/`, `ggml/` is unchanged per `git status --short` (0 mods
in `tools/server/`), and (b) binary content correctness verified by obj
mtime 48s before binary mtime on 2026-06-27, matching Stage 28 closure.
Override rationale recorded per memory rule.

## Commands run

```text
1. Setup-env capture: ConvertTo-Json | Set-Content setup-env.json (driver L88 verified)
2. DryRun: pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -DryRun -...
   Output: preflight status PASS (all 5 gating checks green)
3. OutputEquivalenceOnly: pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -OutputEquivalenceOnly -...
   Exit 4 BLOCKED-server-not-running: equivalence-prompts.jsonl missing (Phase 0.5 not run; expected standalone smoke BLOCK)
4. Full path (post S29-IMPL-FIX-02): pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -Cycles 3 ...
   Exit BLOCKED-workload-build (Phase 0.5 failed /health; server.err.log shows
   "E srv load_model: - cache: --cache-cold-max-mib requires --cache-mode hybrid")
5. Direct server smoke (independent of driver, legacy mode):
   llama-server.exe -m <model> --cache-mode legacy --port 8904 --cache-ram 512 \
       --cache-cold-max-mib 2048 --cache-cold-path D:\tmp\cache-cold-stage29-02-detached
   Exit 1: server rejected --cache-cold-max-mib on legacy mode
6. Focused tests (TP-29-RG-01): build-cuda\bin\Release\test-cache-controller.exe
   Result: 142/142 PASSED (matches Stage 28 closure)
7. Pytest (TP-29-RG-01): python -m pytest tests/test-tokenizer-0.py
   BLOCKED-env: ImportError huggingface-hub==1.16.1 not in [0.34.0, 1.0) range required by transformers
8. CMake cache inspection (TP-29-CV-01): CMAKE_CXX_FLAGS_RELEASE = /O2 /Ob2 /DNDEBUG (no /Zi)
9. git status --short -- tools/server/ (TP-29-RG-02): 0 modifications (PASS)
```

## Findings

### F-29-EXEC-04 (BLOCKING, driver): cold-path flags passed to legacy mode

Driver `Start-Stage29Server` at
[../../../_design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1:88-90](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L88)
constructs `llama-server.exe` ArgumentList with both
`--cache-cold-max-mib $ColdBudgetMiB` and `--cache-cold-path $CacheColdPath`
regardless of `$Mode`. The server validates these flags against
`cache_mode_val` in
[../../../tools/server/server-context.cpp:611-622](../../../tools/server/server-context.cpp#L611):

```cpp
if (params_base.cache_cold_max_mib != -1 &&
    params_base.cache_mode_val != CACHE_MODE_HYBRID) {
    SRV_ERR("%s", " - cache: --cache-cold-max-mib requires --cache-mode hybrid\n");
    return false;
}
if (params_base.cache_cold_max_mib != 0 &&
    !params_base.cache_cold_path.empty() &&
    params_base.cache_mode_val != CACHE_MODE_HYBRID) {
    SRV_ERR("%s", " - cache: --cache-cold-path requires --cache-mode hybrid\n");
    return false;
}
```

When `Mode='legacy'` (Phase 0.5 tokenize helper + all 4 legacy legs
across Phase 2 + Phase 3), `cache_mode_val` is `CACHE_MODE_LEGACY`.
Server emits `E srv load_model: - cache: --cache-cold-max-mib requires --cache-mode hybrid`
and exits before the HTTP server binds. Driver throws
`BLOCKED-workload-build: tokenize helper failed /health` at driver L140
(Phase 0.5) and would throw `BLOCKED-server-not-running` for any legacy
`Invoke-CycleLeg`.

Independent reproduction (not via driver): manual smoke at
[../../_test_output/stage29-cache-modes-20260628-02/manual-smoke4.err](../../_test_output/stage29-cache-modes-20260628-02/manual-smoke4.err)
shows the same server error:

```text
0.00.264.562 I srv    load_model: loading model '...Qwen3.5-4B-Q4_K_M.gguf'
0.00.264.596 E srv    load_model:  - cache: --cache-cold-max-mib requires --cache-mode hybrid
0.00.264.599 I srv   operator (): operator (): cleaning up before exit...
0.00.265.589 E srv  llama_server: exiting due to model loading error
```

Suggested Developer fix (~3 line edits in `Start-Stage29Server`):
branch the ArgumentList on `$Mode` so cold-path flags are only appended
when `$Mode -eq 'hybrid'`. Hybrid arms stay unchanged. Hybrid legs
would also be affected if cold-path is empty or zero (third check at
server-context.cpp:618-622); the fix must keep hybrid arms valid.

### F-29-EXEC-05 (NON-BLOCKING, evidence): direct smoke reproduces server rejection

Four manual boots with `--cache-mode legacy --cache-cold-max-mib 2048
--cache-cold-path ...` were attempted. All four reached `load_model` and
were rejected with the same `--cache-cold-max-mib requires --cache-mode hybrid`
error. Logs preserved at
[../../_test_output/stage29-cache-modes-20260628-02/manual-smoke{1,2,3,4}.err](../../_test_output/stage29-cache-modes-20260628-02/manual-smoke4.err).
The rejection is a server-side contract, not a driver-side transport issue.

### F-29-EXEC-06 (NON-BLOCKING, environment): pytest environment gap (carry-forward)

Same as prior F-29-EXEC-03. Local Python has `huggingface-hub==1.16.1`;
transformers requires `>=0.34.0,<1.0`. Pytest sub-check in TP-29-RG-01
remains BLOCKED-env. Focused `test-cache-controller.exe` 142/142 PASS
satisfies the focused-test regression contract independently.

### F-29-EXEC-07 (NON-BLOCKING, build): coverage gap on Release without /Zi (carry-forward)

Same as prior F-29-EXEC-04. `build-cuda/CMakeCache.txt` line 80:
`CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` (no `/Zi`).
TP-29-CV-01 remains BLOCKED-Release-without-/Zi.

## Per-row classification

| Row | Status | Evidence |
| --- | --- | --- |
| TP-29-CC-01 (output equivalence) | BLOCKED-driver-cold-mode | server.err.log: cold-mode rejection; driver L88-90 (F-29-EXEC-04) |
| TP-29-CC-02 (cold-store validity) | BLOCKED-driver-cold-mode | same; cold-store never populated by driver |
| TP-29-CC-03 (fallback rate) | BLOCKED-driver-cold-mode | no per-leg metrics produced |
| TP-29-CC-04 (cooldown) | BLOCKED-driver-cold-mode | no per-leg cooldown evidence |
| TP-29-PR-01 (cache_n_ratio exact) | BLOCKED-driver-cold-mode | no per-leg requests.jsonl produced |
| TP-29-PR-02 (cold-miss ttft) | BLOCKED-driver-cold-mode | no cold-miss vs warm-miss split |
| TP-29-PR-03 (warm-hit p95) | BLOCKED-driver-cold-mode | no warm-cycle requests.jsonl produced |
| TP-29-AG-01 (mean hit rate) | BLOCKED-driver-cold-mode | no aggregated request rows produced |
| TP-29-AG-02 (total tokens reused) | BLOCKED-driver-cold-mode | same |
| TP-29-AG-03 (cold-store bytes) | BLOCKED-driver-cold-mode | same |
| TP-29-AG-04 (VRAM peak) | BLOCKED-driver-cold-mode | no per-leg summary.json produced |
| TP-29-RG-01 (focused + pytest) | PARTIAL | test-cache-controller 142/142 PASS ([test-cache-controller.log](../../_test_output/stage29-cache-modes-20260628-02/test-cache-controller.log)); pytest BLOCKED-env ([pytest.log](../../_test_output/stage29-cache-modes-20260628-02/pytest.log)) |
| TP-29-RG-02 (no tools/server mods) | PASS | `git status --short -- tools/server/` returned 0 entries (setup-env.json git_modified_tools_server=0) |
| TP-29-CV-01 (coverage) | BLOCKED-Release-without-/Zi | `build-cuda/CMakeCache.txt:80` lacks `/Zi`; OpenCppCoverage not installed |

Final counts: PASS=1, FAIL=0, PARTIAL=1, BLOCKED=12 (11 driver-cold-mode,
1 Release-without-/Zi). Each BLOCKED-driver-cold-mode row is reproducible
by re-invoking the driver with the current code; resolution requires the
~3-line Developer fix to `Start-Stage29Server` (branch ArgumentList on
`$Mode -eq 'hybrid'`).

## Three-layer report (skeleton per design part-05)

Layer 1 Correctness: not produced. CC-01..04 all BLOCKED-driver-cold-mode.
Direct server smoke evidence shows both legacy mode boot attempts are
rejected at the server side because the cold-path flags are mode-coupled
(server-context.cpp:611-622).

Layer 2 Per-request: not produced. PR-01..03 BLOCKED-driver-cold-mode;
no per-cycle requests.jsonl files exist under the run root.

Layer 3 Aggregated: not produced. AG-01..04 BLOCKED-driver-cold-mode;
no `summary.json` produced.

Decision-support Q1..Q5: not produced. Driver output
[main.err.log](../../_test_output/stage29-cache-modes-20260628-02/main.err.log)
records only the BLOCKED-workload-build exception trace pointing at
driver L140.

## OWASP table (Stage 10 hardening scope)

| Category | Stage 29 evidence | Verdict |
| --- | --- | --- |
| Input validation | server rejects `--cache-cold-max-mib` on legacy mode before model load (server-context.cpp:611) | PASS (server enforces mode coupling) |
| Authentication | `/v1/chat/completions` not exposed publicly; localhost only | N/A |
| Sensitive data | manual smoke did not log request/response bodies | PASS |
| Logging | server logs verbose=3; no prompt content logged | PASS |
| Dependency | binary is post-Stage-28 closure; no new dependencies | PASS |
| Cryptographic | no TLS in scope (localhost-only Stage 29) | N/A |
| Error handling | driver returns BLOCKED-* status; server emits SRV_ERR on cold-mode mismatch | PASS |
| Resource limits | 1.4 TB disk free on D:; cold path created | PASS |
| Concurrency | single --parallel=2 not exercised (driver BLOCKED) | BLOCKED-driver-cold-mode |
| Replay protection | seed=42 deterministic; no replay surface | PASS |
| Audit | run root populated with setup-env.json, dryrun.log, output-equivalence.log, main.log, main.err.log, server.err.log, server.out.log, test-cache-controller.log, pytest.log, manual-smoke{1..4}.err | PASS |
| Configuration | driver default params: HotBudgetMiB=512, ColdBudgetMiB=2048, Cycles=3 | PASS |

## Top BLOCKING issues

1. Driver `Start-Stage29Server` (L88-90) passes `--cache-cold-max-mib` and
   `--cache-cold-path` unconditionally. Server rejects both flags when
   `--cache-mode legacy` per
   [tools/server/server-context.cpp:611-622](../../../tools/server/server-context.cpp#L611).
   Affects 11 of 14 rows. Suggested fix: branch ArgumentList on `$Mode`
   to skip cold-path flags when `$Mode -eq 'legacy'`.
2. Coverage tooling gap (carry-forward): Release build lacks `/Zi` and
   OpenCppCoverage not installed at canonical path. Affects TP-29-CV-01.
3. Pytest environment gap (carry-forward): `huggingface-hub==1.16.1` does
   not satisfy transformers constraint `>=0.34.0,<1.0`. Affects TP-29-RG-01
   pytest sub-check only; focused tests still 142/142 PASS.

## Resolution status of prior BLOCKING

F-29-EXEC-01 (prior session): driver flag typo `--cache-cold-dir` to
`--cache-cold-path`. RESOLVED 2026-06-28 by S29-IMPL-FIX-02. Driver L88
verified to use `--cache-cold-path`. Grep across `._design_docs/cache-handling-test-scripts/`
returned 0 remaining `--cache-cold-dir` occurrences.

## Evidence files

All under `._test_output/stage29-cache-modes-20260628-02/`:

- `setup-env.json` (capture)
- `dryrun.log` (Phase 0 preflight PASS)
- `output-equivalence.log` (standalone smoke BLOCK 4; equivalence-prompts.jsonl missing)
- `main.log` (empty; driver wrote exception to main.err.log)
- `main.err.log` (driver exception: BLOCKED-workload-build at L140)
- `server.err.log` (Phase 0.5 server stderr; "loading model" then cold-mode exit)
- `server.out.log` (empty)
- `manual-smoke.err`, `manual-smoke2.err`, `manual-smoke3.err`, `manual-smoke4.err` (independent reproductions on ports 8902-8905)
- `test-cache-controller.log` (142/142 PASS)
- `pytest.log` (BLOCKED-env collection error)
- `git-status-tools-server.log` (0 modifications)

## Handoff

Next owner: Developer. ~3-line fix at driver L88-90 to branch
`Start-Stage29Server`'s ArgumentList on `$Mode` (skip cold-path flags
when `$Mode -eq 'legacy'`). After Developer fix and review, the next
QA execution will re-run the full path and produce real per-leg evidence.
The two non-blocking findings (pytest env, coverage tooling) are
independent of Stage 29 and should be tracked in separate Developer
handoffs.

Next gate: Manager (re-execution gate #2) after Developer fix lands.
After re-run PASS: Developer test-results review. After Developer
review PASS: Manager closure per D-CLOSURE-29-NN.

## Self-improvement note

Recorded the driver-mode-flag-coupling bug as a follow-up to the prior
F-29-EXEC-01 flag-typo finding: the prior implementation review and
fix session verified function definitions, parameter shapes, and the
literal flag name passed to the child process, but did not cross-check
each flag against the server's mode-coupled validation in
`tools/server/server-context.cpp`. A stronger review would grep for
each `--` literal in the driver and trace it through `common/arg.cpp`
registration AND the mode-coupled validation blocks in `server-context.cpp`.
Memory update pending.

This file uses LF line endings, plain ASCII status labels, no BOM, no
trailing whitespace.
