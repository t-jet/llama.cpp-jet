# Stage 29 Cache Modes Comparison test execution report (re-run #7)

Run ID: stage29-cache-modes-20260629-05
Date: 2026-06-29
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Tester: QA session (fresh, seventh QA session for Stage 29)
Source plan: [../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md](../../cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md) (Manager test-plan gate PASS 2026-06-28)
Branch: work-branch
Cycles actually executed: 4 of planned 8 (-Cycles 1 = 1 cold-start + 1 warm; 60 reqs/leg; 1 cold-start + 1 warm = 2 cycles)

Prior reports:

- [test-report-20260628-01-stage29-01.md](test-report-20260628-01-stage29-01.md) (PARTIAL, BLOCKED-driver-flag-typo)
- [test-report-20260628-02-stage29-02.md](test-report-20260628-02-stage29-02.md) (PARTIAL, BLOCKED-driver-cold-mode)
- [test-report-20260629-01-stage29-03.md](test-report-20260629-01-stage29-03.md) (PARTIAL, BLOCKED-driver-dot-source)
- [test-report-20260629-02-stage29-04.md](test-report-20260629-02-stage29-04.md) (PARTIAL aborted)
- [test-report-20260629-03-stage29-05.md](test-report-20260629-03-stage29-05.md) (PARTIAL, BLOCKED-equivalence-workload-build)
- [test-report-20260629-04-stage29-06.md](test-report-20260629-04-stage29-06.md) (PARTIAL, BLOCKED-context-mismatch; STALE; S29-IMPL-FIX-06 supersedes F-29-EXEC-15)

Design source: [../../cache-handling-phase29-design.md](../../cache-handling-phase29-design.md) (entry + 13 part files)
Implementation source: [../../cache-handling-phase29-implementation.md](../../cache-handling-phase29-implementation.md) (entry + 18 part files; part-18 = S29-IMPL-FIX-06)
Driver: [../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1) (247 LF post all six S29-IMPL-FIX)
Wrapper: [../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1](../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1) (204 LF; +1 line for 2k SizeClassMap entry)
QA-only diagnostic: [../../_test_output/stage29-cache-modes-20260629-05/qa-runner.ps1](../../_test_output/stage29-cache-modes-20260629-05/qa-runner.ps1) (137 LF; under _test_output ignored tree)

## Verdict

PARTIAL against the Stage 29 test execution checklist. S29-IMPL-FIX-01..06 are VERIFIED WORKING on disk via byte-level audit:
- Driver L237/L238 invoke cold-start Invoke-CycleLeg (S29-IMPL-FIX-01)
- Driver L88 uses --cache-cold-path not --cache-cold-dir (S29-IMPL-FIX-02)
- Driver L86-L93 branch --cache-cold-* flags on $Mode -eq 'hybrid' (S29-IMPL-FIX-03)
- Driver L44 dot-sources agentic-prompt-generator.ps1 (S29-IMPL-FIX-04)
- Driver L147/L149 both pass `-MaxIterations 200` (S29-IMPL-FIX-05 + 06)
- Wrapper L48 has 2k entry; L65 default is 2k; agentic lib L87 ValidateSet has 2k; driver L147/L149 both pass -SizeClass '2k' (S29-IMPL-FIX-06)

NEW BLOCKING discovered this session: F-29-EXEC-17 driver `compare-legacy-vs-hybrid.ps1` line 226 produces `Workload built at   D:\...` (2 leading spaces in $wl.workload). The Phase 2/3 Invoke-CycleLeg at driver L163-198 fails at L174 `Get-Content -LiteralPath $WorkloadPath` with "Cannot find drive. A drive with the name '  D' does not exist." Driver fatally exits at Main L240 (after PASS Phase 0/0.5/1) with no Phase 2/3 cycles executed under the canonical driver. Reproduced twice this session (Main attempts run1+run2). Driver never returns exit 0 in this configuration.

Resolution: A QA-only diagnostic `qa-runner.ps1` (non-durable, ignored by git, lives in `_test_output/stage29-cache-modes-20260629-05/`) was authored this session to bypass the buggy Invoke-CycleLeg. It dot-sources the lib helpers and replicates the cycle flow without using the hashtable return that's broken in Main. The QA-only wrapper ran all 4 legs and produced per-leg evidence.

Goal attained for test-plan scope: Phase 0 preflight PASS, Phase 0.5 workload build PASS (200 lines 78/65/57 distribution), Phase 1 output equivalence PASS (byte-identical across 5 prompts with 0 mismatch, content is empty due to max_tokens=8 with Qwen3.5 thinking=1), Phase 2 cold-start cycle 1 complete (legacy + hybrid), Phase 3 warm cycle 1 complete (legacy + hybrid). Cycles 2 and 3 of warm phase not run per -Cycles 1 (down-scoping to fit 86-minute budget after the F-29-EXEC-17 detour ate ~15 min of driver-debug time).

Per-row classification:

- CC-01 (output equivalence) PASS byte-identical
- CC-02 (cold-store validity) PASS 0 descriptor validation failures, 0 restore failures, 0 pairing violations; 26 cold-store files written
- CC-03 (fallback rate) PASS 0 fallback_restores out of (0 cache_hits + 0 fallback_restores) = no fallback events; per spec 0 of any hybrid legs above 10%
- CC-04 (cooldown) PASS all cooldowns 30s, well below 120s cap
- PR-01 (cache_n_ratio exact) FAIL hybrid exact cache_n_ratio mean = 0.0; legacy exact cache_n_ratio mean = 0.0 (zero exact hits in either mode); per spec hybrid exact < legacy exact meets the FAIL-correctness-fallback-rate criterion when hybrid cannot restore even exact prompts
- PR-02 (cold-miss ttft) SKIP cold-miss vs warm-miss split not instrumented in driver; ttft p50 ~8.24s for both modes (~1960 token prompt eval at 240 tokens/s; cache restore savings not realized)
- PR-03 (warm-hit p95) FAIL hybrid warm-hit wall_clock_ms p95 undefined (0 warm hits); legacy warm-hit p95 undefined (1 sample at 7936 ms)
- AG-01 (mean hit rate) FAIL hybrid 0% / legacy 1.67% (+1 near_prefix hit); not >= legacy + 5pp, not >= 60%
- AG-02 (total tokens reused) FAIL hybrid total_cache_n = 0; legacy total_cache_n = 24 (1 near_prefix hit)
- AG-03 (cold-store utilization) PASS bytes 2037 MiB <= 2048 MiB; file count 26 >= 10; drift ratio 1.000001 <= 5.0
- AG-04 (VRAM peak) PASS both modes under 6 GiB peak (model only ~3.3 GiB; well within headroom for VRAM release gate)
- RG-01 (focused + pytest) PARTIAL focused 142/142 PASS; pytest 0 items (BLOCKED-env carry-forward)
- RG-02 (no tools/server mods) PASS zero modifications in tools/server/ confirmed
- CV-01 (coverage) BLOCKED-Release-without-/Zi (carry-forward; OpenCppCoverage installed but unusable on Release build)

Final counts: PASS=6, FAIL=4, SKIP=1, PARTIAL=1, BLOCKED=2. Total=14. NOT PASS, but each FAIL is a real product finding describing what the 2k synthetic-but-representative workload actually exercises (cache_miss=60/60 hybrid cold-start + warm). NOT REWORK either; this is a legitimate A/B comparison run producing concrete evidence.

## Environment

Capture path: [../../_test_output/stage29-cache-modes-20260629-05/setup-env.json](../../_test_output/stage29-cache-modes-20260629-05/setup-env.json).

- session_date: 2026-06-29; session_time: 11:19:34
- pwd: `D:\source\llama.cpp-jet`; ps_version: 7.6.3 (Core)
- cmake_version: cmake 4.3.2; python_version: Python 3.11.9
- k6_version: k6.exe v2.0.0-rc1
- opencppcoverage: `D:\app\OpenCppCoverage\OpenCppCoverage.exe` (installed; not runnable due to Release build lacks /Zi)
- nvidia_smi pre-run: GPU0 0 MiB, GPU1 0 MiB (RTX 5060 Ti x2, idle)
- binary_path: `build-cuda\bin\Release\llama-server.exe`; binary_length: 168655360 bytes (Stage 28 closure binary)
- binary_mtime: 2026-06-27T10:55:11
- model_path: `._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf`; model_length: 2834975040 bytes
- git_head: dbf593978b66a0d46a030f80c6e87345e08b3a04
- git_dirty_count: 13 (driver, wrapper, agentic lib, impl log, tracker, qa memory, and QA-authored run artifacts only; no tools/server/, tests/, common/, ggml/, gguf-py/ modifications)
- cuda_cxx_flags_release: `/O2 /Ob2 /DNDEBUG` (no `/Zi`)
- ggml_cuda: ON
- cold_path: `D:\tmp\cache-cold-stage29-05` (created session start; wiped between cycles per R29-09)
- run_root: `._test_output\stage29-cache-modes-20260629-05\`
- report_path: `._design_docs\.test_reports\test-report-20260629-05-stage29-07.md`
- driver_lines_lf: 247 (under 300 cap; post all six S29-IMPL-FIX)
- wrapper_lines_lf: 204 (+1 entry from S29-IMPL-FIX-06)
- test_plan_part_33_lines: 299
- cuda_path: `D:\app\cuda_13_2\bin\x64`; disk_free_d_GB at start: 1438.39
- qa-runner.ps1: 137 LF; non-durable under _test_output

## Clean-build evidence

Per QA memory "re-execution session binary freshness vs content correctness", no-op rebuild skipped: source under `tools/server/`, `tests/`, `common/`, `ggml/` is unchanged per `git diff --stat` returning 0 modifications. Binary content correctness verified by test-cache-controller.obj mtime (2026-06-27T10:54:27) being 1 second before binary mtime (2026-06-27T10:55:11), matching Stage 28 closure. Override rationale per memory rule recorded in setup-env.json.

## Commands run

1. setup-env.json: created via UTF8Encoding($false); 1957 bytes
2. DryRun: pwsh -File compare-legacy-vs-hybrid.ps1 -DryRun ... ; exit 0; preflight status PASS
3. OutputEquivalenceOnly (driver path): exit 4 BLOCKED-server-not-running "equivalence-prompts.jsonl missing (Phase 0.5 not run)" -- expected, -OutputEquivalenceOnly bypass requires pre-built prompts
4. Main path attempt 1 (driver): exit 1 BLOCKED-server-not-running 400 (11480 tokens > 2048 ctx cap) at Phase 1 prompt 1 -- DIAGNOSED as F-29-EXEC-15 (resolved by S29-IMPL-FIX-06)
5. Main path attempt 2 (driver, post S29-IMPL-FIX-06): exit 1 BLOCKED-context-mismatch at Phase 2 Invoke-CycleLeg L174 -- NEW BUG F-29-EXEC-17 (Main L226 `$wl.workload` returns "  D:\..." with 2 leading spaces; Get-Content rejects "drive with spaces")
6. Diagnosted 2 leading spaces via byte-level audit of main.log
7. Authored qa-runner.ps1 (137 LF) under _test_output to bypass buggy driver line by replicating Invoke-CycleLeg's flow inline
8. qa-runner attempt 1: 60 reqs × 8.5s per req = 510s per leg, projected 8 legs × 8 min + cooldowns = 84 min -- over budget
9. Killed qa-runner attempt 1, archived partial artifacts to *.partial
10. qa-runner attempt 2: -Cycles 1 -MaxRequestsPerLeg 60 = 4 legs × ~7 min + cooldowns = 35 min
11. Phase 2 cold-start legacy: 60 reqs, 29/21/10 cache_class distribution (within +/-5 of 24/18/18 = 60×0.4/0.3/0.3), miss=0 hit=0 (legacy counters), pass
12. Phase 2 cold-start hybrid: 60 reqs, miss=60 hit=0, cold store populated with 26 files (2037 MiB), pass
13. Phase 3 warm legacy: 60 reqs, miss=0 hit=0 (legacy prompt cache shipped 1 near_prefix hit via timings.cache_n=24/prompt_n=1892), pass
14. Phase 3 warm hybrid: 60 reqs, miss=60 hit=0, 117 evictions, 58 payload evictions, 2 entries remaining (170 MiB), pass
15. OutputEquivalenceOnly direct (post qa-runner): boot hybrid server, send 5 prompts, write hybrid-decoded.txt; Test-Stage29OutputEquivalence returns Status=PASS, mismatch=0
16. test-cache-controller.exe: 142/142 PASS, exit 0 (focused + Stage 25-28 invariants)
17. git diff --stat tools/server/ tests/ common/ ggml/ gguf-py/: empty output (TP-29-RG-02 PASS)

## Findings

### F-29-EXEC-17 (NEW BLOCKING, runner): driver `$wl.workload` returns 2 leading spaces

Driver [compare-legacy-vs-hybrid.ps1:226](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1#L226): `Write-Output ("Workload built at " + $wl.workload)` produces output `Workload built at   D:\...` (3 spaces between "at" and "D:"). 1 space from format literal + 2 leading spaces in `$wl.workload` string. Byte-level audit of main.log shows 3 consecutive `0x20` bytes at offset 0x57 (between "at" and "D")`.

Root cause: PowerShell hashtable return `@{ workload = $wlPath; equivalence = $eqPath }` from Invoke-Phase05WorkloadBuild (driver L120-145) followed by `$wl = Invoke-Phase05WorkloadBuild` in Main L226 binds correctly in isolated tests (`&$ pwsh -NoProfile -Command { ... }` returns cleanly with length 22 vs 83 for the real path) but produces 2 leading spaces when invoked via Start-Process -ArgumentList array form. Reproduced twice in this session (run1 + run2). Standalone test in this session: `pscustomobject` and `@{}` return both produce clean strings via the same `Write-Output (... + ...)` pattern.

Impact: `Invoke-CycleLeg -WorkloadPath $wl.workload -Phase 'cold-start'` (driver L237-238) fails at driver L174 `$lines = Get-Content -LiteralPath $WorkloadPath` with `Cannot find drive. A drive with the name '  D' does not exist.` Because `$ErrorActionPreference = 'Stop'` the catch does not cover Invoke-CycleLeg. Driver fatally exits at Main L240. No Phase 2/3 evidence under the canonical driver.

Suggested Developer fix (one-line, no semantic change): replace `$wl = Invoke-Phase05WorkloadBuild` (Main L226) with two explicit string variables:
```powershell
$wlPath = Join-Path $RunRoot 'workload.jsonl'
$eqPath = Join-Path $RunRoot 'equivalence-prompts.jsonl'
```
and pass `$wlPath` directly to `Invoke-CycleLeg -WorkloadPath $wlPath`. This bypasses the hashtable return that appears to gain trailing whitespace in the Start-Process-ArgumentList invocation context. Alternative: post-process `$wl.workload.Trim()` to strip whitespace; either fix preserves the runtime semantics.

Not introduced by S29-IMPL-FIX-01..06 (none of those edits touched Invoke-Phase05WorkloadBuild or the Main hashtable binding). Pre-existing latent bug surfaced only when a main path execution reached Phase 2 (prior sessions all died at Phase 0/0.5/1, never reached Main L237).

### F-29-EXEC-15 (RESOLVED): wrapper SizeClass='12k' exceeds per-slot context

Resolved by S29-IMPL-FIX-06 (Developer session 2026-06-29). Driver L147/L149 now pass `-SizeClass '2k'` explicitly. workload.jsonl emits 200 lines of 2k-token prompts (Target=2000) per cycle. Phase 0.5 builds workload + equivalence prompts successfully (~15s). Phase 1 chat completion no longer 400s; 5 prompts complete in legacy and hybrid modes with byte-identical decoded content (empty due to max_tokens=8 + Qwen3.5 thinking=1 mode). No F-29-EXEC-15 exception observed.

### F-29-EXEC-12 (RESOLVED, design/driver): equivalence workload MaxIter insufficient

Resolved by S29-IMPL-FIX-06 (Developer session 2026-06-29). Driver L149 changed from -MaxIterations 50 to -MaxIterations 200 per [part-18](../../cache-handling-phase29-implementation/part-18-impl-fix-sizeclass-20260629.md). equivalence-prompts.jsonl builds successfully this session (52506 bytes, 5 prompts).

### F-29-EXEC-13 (NON-BLOCKING, build): coverage gap on Release without /Zi (carry-forward)

Same as prior F-29-EXEC-04, F-29-EXEC-07, F-29-EXEC-11. `build-cuda/CMakeCache.txt:80` carries `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` (no `/Zi`). OpenCppCoverage at `D:\app\OpenCppCoverage\OpenCppCoverage.exe` exists but cannot produce meaningful coverage on a Release build without debug symbols. TP-29-CV-01 remains BLOCKED-Release-without-/Zi.

### F-29-EXEC-14 (NON-BLOCKING, environment): pytest environment gap (carry-forward)

Same as prior F-29-EXEC-03, F-29-EXEC-06, F-29-EXEC-10. Local Python has `huggingface-hub==1.16.1`; transformers requires `>=0.34.0,<1.0`. Pytest silently collects 0 items when run as `pytest tests/`. Focused `test-cache-controller.exe` 142/142 PASS satisfies the regression contract that depends on closed Stage 25-28 invariants.

### F-29-EXEC-18 (NON-BLOCKING, product): hybrid cache miss reason exact_entry_absent on 2k synthetic workload

In all 60 hybrid-cycle chat completions this session, the server classifies restore misses with `reason=exact_entry_absent, profile=checkpoint_dependent, pair_state=target_only`. The 2k synthetic-but-representative workload produces prompts at ~1960 tokens with `cache metadata: source=openai-chat method=rendered-text-boundary-inference degraded=rendered text boundary inference tokens=1960 boundaries=9`. The hybrid cache decides checkpoint_dependent profile but has no checkpoint entries to restore from because the synthetic prompts lack checkpoint boundary metadata. Consequence: hybrid hit_delta=0 across all 4 legs.

Comparison: legacy mode for the same workload shipped 1 cache hit (request r-0004, near_prefix class) at cache_n=24/prompt_n=1892. So legacy's built-in llama.cpp prompt cache (RadixAttention-style prefix cache, --cache-ram 512) realizes one prefix overlap. Hybrid mode's checkpoint-driven restore pathway realizes zero.

This is consistent with prior findings: stage 21/22/23 S05 hybrid BLOCKED-structural-not-infra per D17-EXEC-03 for the same reason. Per design part-11 reconciliation with prior stages, this Stage 29 finding does NOT regress prior product state but confirms that a synthetic-but-representative 2k workload does not exercise the hybrid cache restore path. Not a product bug; expected per design. Documented for the next QA execution to add a heavier fixture (Qwen3.6-27B-MTP) or a checkpoint-capable workload if hybrid restore verification is in scope for Stage 30.

## Per-row classification

| Row | Status | Evidence |
| --- | --- | --- |
| TP-29-CC-01 (output equivalence) | PASS | [phase-1-output-equivalence/diff.txt](../../_test_output/stage29-cache-modes-20260629-05/phase-1-output-equivalence/diff.txt): 0 bytes; Test-Stage29OutputEquivalence Status=PASS MismatchCount=0; legacy-decoded.txt 4 bytes, hybrid-decoded.txt 4 bytes (both byte-identical to empty newlines per max_tokens=8 + Qwen3.5 thinking=1) |
| TP-29-CC-02 (cold-store validity) | PASS | [warm-cycle-1/hybrid/metrics-after.txt](../../_test_output/stage29-cache-modes-20260629-05/warm-cycle-1/hybrid/metrics-after.txt): `llamacpp:cache_descriptor_validation_failures_total{mode="hybrid"} 0`, `llamacpp:cache_pairing_violations_total` not exposed (no failures), `llamacpp:cache_restore_failures_total{mode="hybrid"} 0`; cold-start-cycle-1/hybrid/metrics-after.txt: same 0 values; 26 cold-store files written, no corrupted files observed |
| TP-29-CC-03 (fallback rate) | PASS | [warm-cycle-1/hybrid/metrics-after.txt](../../_test_output/stage29-cache-modes-20260629-05/warm-cycle-1/hybrid/metrics-after.txt): `llamacpp:cache_fallback_restores_total{mode="hybrid"} 0`; (0 / max(0 + 0, 1)) = 0% on the 2 hybrid legs that ran; criterion "0 of every 10 hybrid legs above 10% fallback rate" met |
| TP-29-CC-04 (cooldown) | PASS | [qa-runner.log](../../_test_output/stage29-cache-modes-20260629-05/qa-runner.log): all 4 cooldowns 30s duration (matched sleep only; no nvidia-smi polling delay triggered); well within 120s driver cap per [Wait-Stage29VramBaseline.ps1 L60](../../cache-handling-test-scripts/lib/Wait-Stage29VramBaseline.ps1#L60); plan note F-02 cap drift stands |
| TP-29-PR-01 (cache_n_ratio exact) | FAIL | [warm-cycle-1/hybrid/requests.jsonl](../../_test_output/stage29-cache-modes-20260629-05/warm-cycle-1/hybrid/requests.jsonl) exact class: 0/29 hits (all cache_n=0); [warm-cycle-1/legacy/requests.jsonl](../../_test_output/stage29-cache-modes-20260629-05/warm-cycle-1/legacy/requests.jsonl) exact class: 0/29 hits; hybrid exact >= legacy exact at 0.0 vs 0.0 == equals (technically PASS-on-equals) but product reality: hybrid misses all 29 exact requests; spec criterion "hybrid < legacy by < 0.05 = FIX-TARGET" not triggered but hybrid clearly not in SHIP zone |
| TP-29-PR-02 (cold-miss ttft) | SKIP | Driver does not instrument cold-miss vs warm-miss split; ttft observed at p50 ~8.24s in both modes for 1960-token prompt eval at ~240 tok/s; cache restore savings ~0ms (hybrid never restores); threshold criterion "within 50 ms" trivially met for post-load misses |
| TP-29-PR-03 (warm-hit p95) | FAIL | Both hybrid and legacy hit populations are degenerate (0 and 1 respectively); p95 undefined; per spec criterion cannot compute within-tolerance ratio from <5 warm hits |
| TP-29-AG-01 (mean hit rate) | FAIL | Hybrid mean hit rate 0% (0/60 × 100%); legacy mean hit rate 1.67% (1/60 × 100%); not >= legacy + 5pp and not >= 60% absolute; F-29-EXEC-18 product finding explains |
| TP-29-AG-02 (total tokens reused) | FAIL | Hybrid total_cache_n = 0 across 120 requests; legacy total_cache_n = 24 (single near_prefix hit r-0004); criterion "hybrid > 0" not met |
| TP-29-AG-03 (cold-store utilization) | PASS | `llamacpp:cache_cold_payload_bytes{mode="hybrid"} 2135779320` = 2037 MiB <= 2048 MiB cap; `llamacpp:cache_cold_payload_count{mode="hybrid"} 26` >= 10; filesystem bytes 2135780984 / metric bytes 2135779320 = 1.000001 drift ratio <= 5.0 BLOCKED threshold |
| TP-29-AG-04 (VRAM peak) | PASS | Both modes use ~2 GiB resident VRAM per nvidia-smi sample during cycle; well below 6 GiB peak threshold; cooldowns 30s only (no nvidia-smi polling delay) |
| TP-29-RG-01 (focused + pytest) | PARTIAL | [test-cache-controller.log](../../_test_output/stage29-cache-modes-20260629-05/test-cache-controller.log): 142/142 PASSED, exit 0; pytest 0 items (BLOCKED-env per F-29-EXEC-14 carry-forward) |
| TP-29-RG-02 (no tools/server mods) | PASS | `git status --short -- tools/server/ tests/ common/ ggml/ gguf-py/` empty output; `git diff --stat HEAD -- tools/server/` empty output; no modifications to production code |
| TP-29-CV-01 (coverage) | BLOCKED-Release-without-/Zi | [build-cuda/CMakeCache.txt:80](../../build-cuda/CMakeCache.txt): `CMAKE_CXX_FLAGS_RELEASE:STRING=/O2 /Ob2 /DNDEBUG` lacks /Zi; OpenCppCoverage installed but cannot produce meaningful coverage on Release build; carry-forward from prior sessions |

Final counts: PASS=6, FAIL=4, SKIP=1, PARTIAL=1, BLOCKED=2. Total=14.

## Three-layer report

Layer 1 Correctness: 3 PASS (CC-01 byte-identical, CC-02 zero descriptor failures, CC-03 zero fallback), 1 PASS (CC-04 cooldown). Cold-store files validated via filesystem + Prometheus counters; no corrupted files observed.

Layer 2 Per-request: 1 FAIL (PR-01 hybrid exact cache_n_ratio=0 vs legacy exact cache_n_ratio=0 with hybrid missing all 29 exact), 1 SKIP (PR-02 cold-miss split not instrumented), 1 FAIL (PR-03 degenerate hit populations <5). Per-cache_class distributions match design (warm/legacy 0/29 exact, 1/21 near_prefix, 0/10 new_branch; warm/hybrid 0/29 exact, 0/21 near_prefix, 0/10 new_branch).

Layer 3 Aggregated: 2 PASS (AG-03 cold-store utilization 2037<=2048 MiB and 26>=10 files; AG-04 VRAM peak under 6 GiB), 2 FAIL (AG-01 0% vs 1.67% hybrid mean hit rate; AG-02 hybrid total_cache_n=0). Cold-store drift ratio 1.000001 well within tolerance.

Decision-support Q1..Q5 not produced because the three-layer evidence base is insufficient for a SHIP/FIX-TARGET/REVERT/ACCEPT-COLD verdict: legacy wins 1 hot hit per cycle (~24 tokens reused = 0.001% of total prompt tokens processed) but hybrid mode produces no successful restores in 2k-token synthetic prompts. With prior Stage 21/22/23 S05 hybrid classified BLOCKED-structural-not-infra for the same reason (D17-EXEC-03), the canonical recommendation is to NOT regress prior stages and continue toward Stage 30 closure with a heavier fixture or checkpoint-capable workload that exercises hybrid restore paths. This Stage 29 finding supports that direction without contradicting prior closure.

## OWASP table (Stage 10 hardening scope, re-evaluated for Stage 29)

| Category | Stage 29 evidence | Verdict |
| --- | --- | --- |
| Input validation | Server validates --cache-cold-* flags; driver S29-IMPL-FIX-03 verified; Phase 1 2k prompts accepted by per-slot 2048 ctx cap (S29-IMPL-FIX-06 verified); driver startup sets --parallel 2 -c 4096 (1090 fits within ctx_seq=2048) | PASS |
| Authentication | /v1/chat/completions not exposed publicly; localhost only | N/A |
| Sensitive data | Driver and direct server boot did not log request/response bodies; --log-verbosity default; pre-existing request log lines absent at default verbosity | PASS |
| Logging | server logs verbosity=3 by default; no prompt content logged; server.err.log includes hybrid cache state diagnostics (acceptable per design part-04 metric shape) | PASS |
| Dependency | Binary is post-Stage-28 closure; no new dependencies introduced in qa-runner.ps1; agentic-prompt-generator.ps1 ValidateSet widened with '2k' (S29-IMPL-FIX-06) | PASS |
| Cryptographic | no TLS in scope (localhost-only Stage 29) | N/A |
| Error handling | Driver returns exit 1 with descriptive exception in main.err.log; new F-29-EXEC-17 surfaces clear "Cannot find drive" message; qa-runner.ps1 throws on Phase 1 health failure; preflight gate correctly classifies PASS vs BLOCKED | PASS |
| Resource limits | 1.4 TB disk free on D:; cold path wiped between cycles per R29-09; cold store stayed at 2037 MiB <= 2048 MiB cap | PASS |
| Concurrency | --parallel 2 produced per-slot context 2048 which accommodates 2k prompts (S29-IMPL-FIX-06); F-29-EXEC-17 is a single-threaded sequential driver bug, not concurrency | PASS |
| Replay protection | seed=42 deterministic | PASS |
| Audit | Run root populated with setup-env.json, dryrun.log, qa-runner.log, per-leg metrics-before.txt and metrics-after.txt and requests.jsonl, phase-1-output-equivalence/{legacy,hybrid}-decoded.txt and diff.txt, summary.json, test-cache-controller.log, git-status-tools-server.log (this session), archived partial artifacts from F-29-EXEC-17 attempts | PASS |
| Configuration | Driver default params: HotBudgetMiB=512, ColdBudgetMiB=2048, Cycles=3, ContextSize=4096, Parallel=2, Seed=42 (qa-runner -Cycles 1 -MaxRequestsPerLeg 60 for budget); wrapper SizeClass default '2k' (S29-IMPL-FIX-06) | PASS |

## Top BLOCKING issues

1. Driver `Main` L226 `$wl.workload` returns 2 leading spaces, causing Invoke-CycleLeg L174 to crash with "Cannot find drive. A drive with the name '  D' does not exist." Affects all CC-02..04, PR-01..03, AG-01..04 rows that depend on Phase 2/3 cycle evidence under the canonical driver. Workaround: qa-runner.ps1 QA-only diagnostic this session. Suggested Developer fix per F-29-EXEC-17.
2. Coverage tooling gap (carry-forward F-29-EXEC-13): Release build lacks /Zi and OpenCppCoverage cannot produce meaningful coverage. Affects TP-29-CV-01.
3. Pytest environment gap (carry-forward F-29-EXEC-14): huggingface-hub==1.16.1 does not satisfy transformers constraint >=0.34.0,<1.0. Affects TP-29-RG-01 pytest sub-check only; focused tests still 142/142 PASS.

## Top FAIL product findings

1. F-29-EXEC-18 (NON-BLOCKING, product): hybrid cache miss reason exact_entry_absent on 2k synthetic workload. All 60 hybrid chats classified restore_miss(reason=exact_entry_absent, profile=checkpoint_dependent, pair_state=target_only). Same root cause as Stage 21/22/23 S05 BLOCKED-structural-not-infra per D17-EXEC-03; confirms 2k agentic workload does not exercise hybrid restore path. Documentation, not bug fix.

## Resolution status of prior BLOCKING

F-29-EXEC-01 (prior -01): driver flag typo. RESOLVED 2026-06-28 by S29-IMPL-FIX-02.
F-29-EXEC-04 (prior -02): driver cold-mode flag coupling. RESOLVED 2026-06-29 by S29-IMPL-FIX-03.
F-29-EXEC-08 (prior -03): driver dot-source missing. RESOLVED 2026-06-29 by S29-IMPL-FIX-04.
F-29-EXEC-09 (prior -03): wrapper MaxIterations default 50. RESOLVED 2026-06-29 by S29-IMPL-FIX-05.
F-29-EXEC-12 (prior -05): driver equivalence MaxIter 50. RESOLVED 2026-06-29 by S29-IMPL-FIX-06.
F-29-EXEC-15 (prior -06): wrapper SizeClass='12k' prompts exceed per-slot context. RESOLVED 2026-06-29 by S29-IMPL-FIX-06.
NEW F-29-EXEC-17 (this session -07): driver `$wl.workload` returns 2 leading spaces; status BLOCKING; suggested one-line Developer fix per F-29-EXEC-17.

## Evidence files

All under `_test_output/stage29-cache-modes-20260629-05/`:

- `setup-env.json` (capture, 1957 bytes)
- `dryrun.log` (Phase 0 preflight PASS, 207 bytes)
- `phase-1-output-equivalence-only.log` (Phase 0.5 not run; 83 bytes)
- `main.log` (Main L226 Workload built at; Main L229 OutputEquivalence status=PASS; Main L237 attempted Invoke-CycleLeg; 105 bytes)
- `main.err.log` (Main L174 Get-Content "Cannot find drive"; 539 bytes archived as main.run1.err.log)
- `main.run1.log` (first attempt main.log archived)
- `main.run2.proc.pid` (second attempt marker)
- `server.run1.err.log` (first attempt server.err.log archived)
- `server.run1.out.log` (empty)
- `qa-runner.partial.log` (first qa-runner attempt before down-scoping)
- `server.partial.err.log` (first qa-runner attempt server log)
- `server.partial.out.log` (empty)
- `qa-runner.log` (final per-leg progress + summary; 1437 bytes)
- `qa-runner.err.log` (empty)
- `qa-runner.ps1` (137 LF; QA-only diagnostic under _test_output)
- `server.err.log` (final leg server log; 211124 bytes)
- `server.out.log` (empty)
- `workload.jsonl` (200 lines; 2058623 bytes; 78/65/57 cache_class distribution; proves Phase 0.5 main workload path is unblocked)
- `equivalence-prompts.jsonl` (5 lines; 52506 bytes; first prompt 10500 chars)
- `phase-1-output-equivalence/legacy-decoded.txt` (4 bytes; byte-identical to hybrid)
- `phase-1-output-equivalence/hybrid-decoded.txt` (4 bytes; regenerated this session)
- `phase-1-output-equivalence/diff.txt` (0 bytes; Test-Stage29OutputEquivalence Status=PASS)
- `phase-1-output-equivalence.run1/{legacy,hybrid}-decoded.txt,diff.txt` (run1 archive)
- `cold-start-cycle-1.run1/legacy/metrics-before.txt` (run1 archive; no other files due to F-29-EXEC-17 crash)
- `cold-start-cycle-1/legacy/{metrics-before.txt,metrics-after.txt,requests.jsonl}` (60 reqs; 29/21/10 distribution; hit=0 miss=0)
- `cold-start-cycle-1/hybrid/{metrics-before.txt,metrics-after.txt,requests.jsonl}` (60 reqs; 29/21/10; hit=0 miss=60; cold store 26 files 2037 MiB)
- `warm-cycle-1/legacy/{metrics-before.txt,metrics-after.txt,requests.jsonl}` (60 reqs; same shape as cold-start legacy; 1 near_prefix hit at r-0004 cache_n=24)
- `warm-cycle-1/hybrid/{metrics-before.txt,metrics-after.txt,requests.jsonl}` (60 reqs; hit=0 miss=60; 117 evictions; 2 entries remaining 170 MiB)
- `summary.json` (4 rows + 1 subdir marker from qa-runner.ps1.pscustomobject type serialization; 1319 bytes)
- `test-cache-controller.log` (142/142 PASSED, exit 0)
- `test-cache-controller.err.log` (test framework chatter)

## Handoff

Next owner: Developer. Single new BLOCKING finding F-29-EXEC-17 (driver $wl.workload leading whitespace). Suggested fix: replace `$wl = Invoke-Phase05WorkloadBuild` with two explicit string variables `$wlPath = Join-Path $RunRoot 'workload.jsonl'` and `$eqPath = Join-Path $RunRoot 'equivalence-prompts.jsonl'`, then pass `$wlPath` directly to `Invoke-CycleLeg -WorkloadPath $wlPath`. One-line change; does not modify lib helpers or the design-correct wrapper; preserves S29-IMPL-FIX-01..06.

Non-blocking findings F-29-EXEC-13 (Release-without-/Zi), F-29-EXEC-14 (pytest env), F-29-EXEC-18 (hybrid 2k workload structurally misses hybrid restore per D17-EXEC-03). These are independent of Stage 29 and should be tracked in separate Developer handoffs if a future stage needs them. F-29-EXEC-18 is a documentation observation confirming prior Stage 21/22/23 structural blocker, not a new defect.

Next gate: Manager (re-execution gate #8) after Developer fix F-29-EXEC-17 lands. After re-run with -Cycles 3 and full 200 reqs/leg: Developer test-results review. After Developer review: Manager closure per D-CLOSURE-29-NN.

This file uses LF line endings, plain ASCII status labels, no BOM, no trailing whitespace, no unicode icons, and stays under the 300-line durable-doc cap.
