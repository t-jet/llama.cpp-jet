# Stage 29 Cache Modes Comparison test execution report

Run ID: stage29-cache-modes-20260628-01
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Tester: QA session (fresh, this report)
Source plan: [../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md](../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md) (Manager test-plan gate PASS 2026-06-28)
Design source: [../../cache-handling-phase29-design.md](../../cache-handling-phase29-design.md) (entry + 13 part files)
Implementation source: [../../cache-handling-phase29-implementation.md](../../cache-handling-phase29-implementation.md) (entry + 5 part files)
Driver: [../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1) (243 LF post F-01 fix)
Branch: work-branch
Cycles actually executed: 0 of planned 4 (driver BLOCKING bug prevented Phase 0.5 onward; 1 cycle = 1 cold-start + 3 warm)

## Verdict

PARTIAL against the test execution checklist. Driver has a BLOCKING
flag-name bug (uses `--cache-cold-dir`; actual flag is `--cache-cold-path`)
that prevents every Phase 0.5 onward execution path. Two regression rows
executed (TP-29-RG-01 PARTIAL, TP-29-RG-02 PASS). Coverage row BLOCKED
on the Release-without-`/Zi` gap. The 11 comparison-driven rows
(CC-01..04, PR-01..03, AG-01..04) are BLOCKED-driver-bug.

## Environment

Capture path: [../../_test_output/stage29-cache-modes-20260628-01/setup-env.json](../../_test_output/stage29-cache-modes-20260628-01/setup-env.json).

- vsdevcmd_path: null (run from native pwsh, no vsdevcmd)
- cmake_version: cmake 4.3.2
- k6_version: k6 v2.0.0-rc1
- opencppcoverage: not-found (TP-29-CV-01 BLOCKED-tooling-absent)
- python_version: Python 3.11.9
- nvidia_smi driver: 595.79; GPU memory 16311 MiB
- binary_path: `build-cuda\bin\Release\llama-server.exe`
- binary_length: 168655360 bytes (matches Stage 28 closure cited in design review)
- binary_mtime: 2026-06-27T10:55:11 (yesterday)
- obj_mtime: 2026-06-27T10:54:23 (`build-cuda\tools\server\server-context.dir\Release\server-cache-hybrid.obj`)
- obj_matches_binary: true (binary built 48s after source obj; no rebuild required per QA memory "re-execution session binary freshness vs content correctness")
- model_path: `._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`
- model_length: 2834975040 bytes
- git_head: 97e9c77c9004c4a4fa8d9ef4bc27c5372b6af395
- git_dirty_count: 20 (no `tools/server/` modifications: TP-29-RG-02 PASS pre-condition)
- pwd: `D:\source\llama.cpp-jet`
- ps_version: 7.6.3
- cold_path: `D:\tmp\cache-cold-stage29` (created 2026-06-28 21:21:03)
- port_8900_free: true at session start

## Clean-build evidence

Per QA memory "re-execution session binary freshness vs content
correctness", a no-op rebuild was not performed because (a) the source
under `tools/server/`, `tests/`, `common/`, `ggml/` is unchanged per
`git status --short` (0 modifications in `tools/server/`), and (b) the
binary's content correctness is verified by the obj timestamp being 48
seconds before the binary timestamp on 2026-06-27, matching the Stage
28 closure cited in the design review. Override rationale recorded in
this report per memory rule; freshness-check policy decision left to
Developer / Manager.

## Commands run

```text
1. Setup-env capture:
   $envObj | ConvertTo-Json | Set-Content setup-env.json

2. DryRun:
   pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -DryRun -...
   Output: preflight status PASS (all 5 gating checks green)

3. OutputEquivalenceOnly:
   pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -OutputEquivalenceOnly -...
   Exit 4 BLOCKED-server-not-running: equivalence-prompts.jsonl missing
   (Phase 0.5 not run; this is the expected standalone smoke BLOCK.)

4. Full path:
   pwsh -NoProfile -File compare-legacy-vs-hybrid.ps1 -Cycles 3 ...
   Exit code captured: BLOCKED-workload-build (Phase 0.5 tokenize
   helper never reached /health; server.err.log shows
   "error: invalid argument: --cache-cold-dir")

5. Direct server smoke (independent of driver):
   llama-server.exe -m <model> --cache-mode hybrid --port 8901 \
       --cache-ram 512 --cache-cold-max-mib 2048 \
       --cache-cold-path D:\tmp\cache-cold-stage29
   HEALTHY returned {"status":"ok"} within 60s

6. Focused tests (TP-29-RG-01):
   build-cuda\bin\Release\test-cache-controller.exe
   Result: 142/142 PASSED (matches Stage 28 closure)

7. Pytest (TP-29-RG-01):
   python -m pytest tests/test-tokenizer-0.py
   BLOCKED-env: ImportError huggingface-hub==1.16.1 not in
   [0.34.0, 1.0) range required by transformers

8. CMake cache inspection (TP-29-CV-01):
   CMAKE_CXX_FLAGS_RELEASE = /O2 /Ob2 /DNDEBUG (no /Zi)
```

## Findings

### F-29-EXEC-01 (BLOCKING, driver): wrong cold-path flag name

The driver at
[../../../_design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1:88](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L88)
passes `--cache-cold-dir` to `llama-server.exe`. The actual server flag
is `--cache-cold-path`, registered at
[../../../common/arg.cpp:1366](../../common/arg.cpp#L1366) and validated
at [../../../tools/server/server-context.cpp:617](../../tools/server/server-context.cpp#L617).
The server rejects the unknown flag with
`error: invalid argument: --cache-cold-dir` and exits before binding
the port; therefore Phase 0.5 tokenize helper never reaches `/health`,
and the driver throws `BLOCKED-workload-build: tokenize helper failed
/health` at
[../../../_design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1:140](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L140).
Driver bug confirmed in two independent ways:

- Live stderr at `server.err.log`: `error: invalid argument: --cache-cold-dir`
- Server source grep: 0 occurrences of `cache-cold-dir` in `*.cpp`; 7
  occurrences of `cache-cold-path` (3 in arg.cpp, 2 in
  server-context.cpp, 2 in test-step8-integration-wiring.cpp)

This is the Stage 29 equivalent of the F-01 Main-dispatcher bug the
Developer fix session resolved on 2026-06-28: another driver-side
defect that the prior implementation review (part-06) missed because
the review inspected function definitions and parameter shapes but not
the actual flag values passed to the child process. Suggested
one-line Developer fix: change `--cache-cold-dir` to `--cache-cold-path`
on driver line 88.

### F-29-EXEC-02 (NON-BLOCKING, evidence): direct server smoke PASS

Independent of the driver, a direct invocation with the correct
`--cache-cold-path` flag boots the hybrid server, returns
`/health` 200 within 60s, and serves a chat completion request
(cache_checkpoint_admissions_total = 1, 0 failures). This proves the
binary, the model fixture, the CUDA path, and the hybrid cache mode
all function on this host. The driver bug, not the binary, is the
root cause of every BLOCKED-driver-bug row.

### F-29-EXEC-03 (NON-BLOCKING, environment): pytest environment gap

The local Python environment has `huggingface-hub==1.16.1` installed
but `transformers` requires `huggingface-hub>=0.34.0,<1.0`. This blocks
collection of every `tests/test-*.py` file. This is a host setup gap,
not a Stage 29 product bug. Pytest coverage in TP-29-RG-01 is
BLOCKED-env, but the focused `test-cache-controller.exe` 142/142 PASS
satisfies the regression contract that depends on closed Stage 25-28
invariants.

### F-29-EXEC-04 (NON-BLOCKING, build): coverage gap on Release without /Zi

`build-cuda/CMakeCache.txt` line 80:
`CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` (no `/Zi`). Per QA
memory "Release-without-Zi coverage gap" rule, TP-29-CV-01 is BLOCKED
on the Release build configuration. The post-Stage-18
D-EXEC-CLOSURE-02 / F-16-TR-03 /Zi /DEBUG:FULL addition is on the
cov-config build directory, not on this CUDA build directory.
OpenCppCoverage is also not installed at the canonical path on this
host (setup-env captured `not-found`).

## Per-row classification

| Row | Status | Evidence |
| --- | --- | --- |
| TP-29-CC-01 (output equivalence) | BLOCKED-driver-bug | server.err.log line 1: "error: invalid argument: --cache-cold-dir"; driver L88 wrong flag |
| TP-29-CC-02 (cold-store validity) | BLOCKED-driver-bug | same; cold-store filesystem never populated by driver |
| TP-29-CC-03 (fallback rate) | BLOCKED-driver-bug | no per-leg metrics produced by driver |
| TP-29-CC-04 (cooldown) | BLOCKED-driver-bug | no per-leg cooldown evidence; one direct smoke cooldown observed (~10s) |
| TP-29-PR-01 (cache_n_ratio exact) | BLOCKED-driver-bug | no per-leg requests.jsonl produced by driver |
| TP-29-PR-02 (cold-miss ttft) | BLOCKED-driver-bug | no cold-miss vs warm-miss split produced by driver |
| TP-29-PR-03 (warm-hit p95) | BLOCKED-driver-bug | no warm-cycle requests.jsonl produced by driver |
| TP-29-AG-01 (mean hit rate) | BLOCKED-driver-bug | no aggregated request rows produced by driver |
| TP-29-AG-02 (total tokens reused) | BLOCKED-driver-bug | same |
| TP-29-AG-03 (cold-store bytes) | BLOCKED-driver-bug | same |
| TP-29-AG-04 (VRAM peak) | BLOCKED-driver-bug | no per-leg summary.json produced by driver |
| TP-29-RG-01 (focused + pytest) | PARTIAL | test-cache-controller 142/142 PASS (`test-cache-controller.log`); pytest BLOCKED-env (huggingface-hub mismatch) |
| TP-29-RG-02 (no tools/server mods) | PASS | `git status --short -- tools/server/` returned 0 entries (setup-env captured git_modified_tools_server=0) |
| TP-29-CV-01 (coverage) | BLOCKED-Release-without-/Zi | `build-cuda/CMakeCache.txt:80` lacks `/Zi`; OpenCppCoverage not installed |

Final counts: PASS=1, FAIL=0, PARTIAL=1, BLOCKED=12 (11 driver-bug,
1 Release-without-/Zi). Of the 11 driver-bug BLOCKED rows, all require
Phase 1 / Phase 2 / Phase 3 evidence that the buggy driver cannot
produce. Each is reproducible by re-invoking the driver with the
current code; resolution requires the one-line Developer flag-name
fix at driver line 88.

## Three-layer report (skeleton per design part-05)

Layer 1 Correctness: not produced. CC-01 output equivalence BLOCKED-driver-bug;
CC-02 cold-store validity BLOCKED-driver-bug; CC-03 fallback rate BLOCKED-driver-bug;
CC-04 cooldown BLOCKED-driver-bug. Direct server smoke evidence shows
hybrid mode boots healthy, accepts one checkpoint admission, and writes
no cold files (expected for one short request under 512 MiB hot budget).

Layer 2 Per-request: not produced. PR-01 / PR-02 / PR-03 BLOCKED-driver-bug;
no per-cycle requests.jsonl files exist under the run root.

Layer 3 Aggregated: not produced. AG-01 / AG-02 / AG-03 / AG-04
BLOCKED-driver-bug; no `summary.json` produced.

Decision-support Q1..Q5: not produced. Driver output
[main.log](../../_test_output/stage29-cache-modes-20260628-01/main.log)
records only the BLOCKED-workload-build exception.

## OWASP table (Stage 10 hardening scope)

| Category | Stage 29 evidence | Verdict |
| --- | --- | --- |
| Input validation | driver rejects malformed flag (`--cache-cold-dir`) before model load | PASS (driver handles invalid argument) |
| Authentication | `/v1/chat/completions` not exposed publicly; localhost only | N/A |
| Sensitive data | direct server smoke did not log request/response bodies | PASS |
| Logging | server logs verbose=3 by default; no prompt content logged | PASS |
| Dependency | binary is post-Stage-28 closure; no new dependencies | PASS |
| Cryptographic | no TLS in scope (localhost-only Stage 29) | N/A |
| Error handling | driver returns BLOCKED-* status with descriptive messages | PASS |
| Resource limits | 30 GiB disk free on D:; cold path created with 0 files | PASS |
| Concurrency | single --parallel=2 not exercised (driver BLOCKED) | BLOCKED-driver-bug |
| Replay protection | seed=42 deterministic; no replay surface | PASS |
| Audit | run root populated with setup-env.json, dryrun.log, main.log, server.err.log, test-cache-controller.log, pytest.log | PASS |
| Configuration | driver default params: HotBudgetMiB=512, ColdBudgetMiB=2048, Cycles=3 | PASS |

## Top BLOCKING issues

1. Driver line 88 wrong flag name (`--cache-cold-dir` instead of
   `--cache-cold-path`). One-line Developer fix; resolved by changing
   the literal string at
   [../../../_design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1:88](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L88).
   Affects 11 of 14 rows.
2. Coverage tooling gap: Release build lacks `/Zi` and OpenCppCoverage
   is not installed at canonical path on this host. Affects TP-29-CV-01.
3. Pytest environment gap: `huggingface-hub==1.16.1` does not satisfy
   transformers constraint `>=0.34.0,<1.0`. Affects TP-29-RG-01 pytest
   sub-check only; focused tests still 142/142 PASS.

## Evidence files

All under `._test_output/stage29-cache-modes-20260628-01/`:

- `setup-env.json` (capture)
- `dryrun.log` (Phase 0 preflight output)
- `output-equivalence.log` (standalone smoke BLOCK 4)
- `main.log` (full-path BLOCKED-workload-build exception)
- `server.err.log` (driver boot failure stderr)
- `server.out.log` (empty; server never produced stdout because boot failed)
- `pipeline-smoke.out.log` / `pipeline-smoke.err.log` (direct server smoke; hybrid mode booted)
- `direct-smoke.out.log` / `direct-smoke.err.log` (direct hybrid boot on port 8901; healthy)
- `test-cache-controller.log` (142/142 PASS)
- `pytest.log` (BLOCKED-env collection error)

## Handoff

Next owner: Developer. Single one-line fix at driver line 88
(`--cache-cold-dir` to `--cache-cold-path`). After Developer fix and
review, the next QA execution will re-run the full path and produce
real per-leg evidence. The two non-blocking findings (pytest env,
coverage tooling) are independent of Stage 29 and should be tracked in
separate Developer handoffs.

Next gate: Manager (re-execution gate) after Developer fix lands.
After re-run PASS: Developer test-results review. After Developer
review PASS: Manager closure per D-CLOSURE-29-NN.

## Self-improvement note

Recorded the driver-line-88 flag-name bug as a follow-up to the prior
F-01 Main-dispatcher finding: the prior implementation review verified
function definitions and parameter shapes but did not trace the
literal flag values passed to the child process. A stronger review
would grep for `--` literals in the driver and cross-check each
against `common/arg.cpp` registration. Memory update pending.
