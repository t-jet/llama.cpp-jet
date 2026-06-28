# Test plan part 33: Stage 29 cache modes comparison

Status: authored; pending QA test-plan review (Manager test-plan gate)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Branch: work-branch
Owner: QA (test plan authoring, fresh session)
Source: [../cache-handling-test-plan.md](../cache-handling-test-plan.md)
Scope: Stage 29 test plan only. Not re-review of design, implementation, or any other stage.

## References

Design:

- [Stage 29 design](../../cache-handling-phase29-design.md) (entry + 13 part files)
- [Design re-review PASS](../../cache-handling-phase29-design/part-13-design-re-review-20260628.md)
- [Part 3 driver design](../../cache-handling-phase29-design/part-03-comparison-driver-design.md)
- [Part 4 per-request metric list](../../cache-handling-phase29-design/part-04-per-request-metric-list.md)
- [Part 5 three-layer report](../../cache-handling-phase29-design/part-05-three-layer-report-and-decision-support.md)
- [Part 6 binding decisions](../../cache-handling-phase29-design/part-06-binding-decisions-resolved.md)
- [Part 7 open questions resolved](../../cache-handling-phase29-design/part-07-open-questions-resolved.md)
- [Part 10 traceability](../../cache-handling-phase29-design/part-10-traceability.md)
- [Part 11 reconciliation with prior stages](../../cache-handling-phase29-design/part-11-reconciliation-with-prior-stages.md)

Implementation:

- [Stage 29 implementation](../../cache-handling-phase29-implementation.md) (entry + 5 part files + part-05 plan review)
- [Implementation review PASS](../../cache-handling-phase29-implementation/part-06-impl-review-20260628.md)
- [Part 3 evidence plan](../../cache-handling-phase29-implementation/part-03-evidence-plan.md)
- [Driver](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1)
- [Driver README](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.README.md)
- [Lib helper: Read-Stage29MetricSnapshot.ps1](../../cache-handling-test-scripts/lib/Read-Stage29MetricSnapshot.ps1)
- [Lib helper: Write-Stage29EvidenceRow.ps1](../../cache-handling-test-scripts/lib/Write-Stage29EvidenceRow.ps1)
- [Lib helper: Test-Stage29OutputEquivalence.ps1](../../cache-handling-test-scripts/lib/Test-Stage29OutputEquivalence.ps1)
- [Lib helper: Wait-Stage29VramBaseline.ps1](../../cache-handling-test-scripts/lib/Wait-Stage29VramBaseline.ps1)
- [Lib helper: compare-legacy-vs-hybrid-workload.ps1](../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1) (design-correct wrapper; NOT modified)
- [Stage 20 lib: agentic-prompt-generator.ps1](../../cache-handling-test-scripts/lib/agentic-prompt-generator.ps1) (reused unchanged)

Prior test plan parts:

- [Part 7: test report quality and templates](./part-07-test-report-quality-and-templates.md)
- [Part 24: test output folder convention](./part-24-test-output-folder-convention.md)
- [Part 29: Stage 24 chat S02/S03 comparison](./part-29-stage24-chat-s02-s03-comparison.md)

## Binding decisions (cited from design part-06 and entry doc)

- D29-DESIGN-01: synthetic-but-representative workload via Stage 20 lib, deterministic seed, optional one-shot proxy capture deferred.
- D29-DESIGN-02: cold-path volume = 2048 MiB (`-ColdBudgetMiB 2048`).
- D29-DESIGN-03: output equivalence check IN SCOPE, 5 prompts with seed=42, byte-identical expected.
- D29-DESIGN-04: iterations = 3 warm A/B cycles plus 1 cold-start cycle (4 cycles total).
- D29-DESIGN-05: reference model = `._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf`.
- D29-DESIGN-06: cooldown = 30s sleep plus nvidia-smi VRAM back-to-baseline gate, cap at 180s per R29-IMPL-02 (actual driver uses 120s default per [Wait-Stage29VramBaseline.ps1](../../cache-handling-test-scripts/lib/Wait-Stage29VramBaseline.ps1) L60; see INFO finding F-02 below).

Open questions resolved (cited from design part-07):

- D29-OQ-01: both modes emit `timings.cache_n`; if missing or always zero on hybrid, the row is BLOCKED-metric-unavailable and falls back to Prometheus deltas.
- D29-OQ-02: cold-path write is synchronous (post-Stage-25 tx_*); cold-path load is synchronous on first cold-hit.
- D29-OQ-03: per-cache-class analysis surfaces the new_branch namespace-validation overhead.

Driver contract (design part-03):

- Five phases: Phase 0 preflight, Phase 0.5 tokenize helper, Phase 1 output equivalence, Phase 2 cold-start cycle, Phase 3 warm cycles.
- Five-gate preflight: ps_version_ok, binary_exists, fixture_exists, port_free, cuda_proof (impl-review N-03 notes two design sub-checks are not separately gated).
- Per-leg artifacts under `<RunRoot>/<phase>-cycle-N/<mode>/`; durable report at `._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md`.

## Scope and exclusions

In scope:

- Three-layer test plan: Correctness (TP-29-CC-*), Per-request (TP-29-PR-*), Aggregated (TP-29-AG-*).
- Regression rows (TP-29-RG-*): Stage 4-9 invariants plus the historical line reference for D-EXEC-27-08.
- Coverage row (TP-29-CV-01): hybrid-mode coverage rate from the post-Stage-28 closed binary.
- Clean build, fresh per-session report, environment capture, run evidence, and reproducible failure handoff.
- Phase 0 preflight + Phase 0.5 workload build + Phase 1 output equivalence + Phase 2 cold-start + Phase 3 warm cycles.
- Q1..Q5 decision-support row evidence collection (covered by the Aggregated layer).

Out of scope:

- Product code changes to hybrid cache (comparison-only stage).
- L1 prompt-cache measurement (no upstream proxy).
- Real agentic traffic as primary workload source (deferred per D29-OQ-01 and OQ-29-01).
- Heavy-tier fixture Qwen3.6-27B-MTP (deferred).
- `/v1/completion` route (chat-completion only).
- Stage 24 runner reuse (different driver, different output contract).
- Stage 12 stress S01..S08 / L01..L03 matrix rerun.
- Implementation log updates; document-index updates; tracker updates (those happen after closure).

## Preflight and build gate

Clean CUDA build is mandatory. Stale builds are invalid evidence.

```powershell
cmake --build build-cuda --config Release -j --target llama-server
```

Required environment:

- `build-cuda/bin/Release/llama-server.exe` exists and is fresh (mtime within 10 minutes of session start).
- `._test_models/Qwen3.5-4B-MTP-GGUF/Qwen3.5-4B-Q4_K_M.gguf` exists (Stage 24 fixture).
- Port 8900 is free.
- `D:\tmp\cache-cold-stage29` has at least 30 GiB free.
- Output volume has at least 30 GiB free.
- `nvidia-smi` returns a parseable `memory.used` value.
- `GGML_CUDA:BOOL=ON` in `build-cuda/CMakeCache.txt`.
- Workload emit path writable: `._test_output/stage29-cache-modes-YYYYMMDD-NN/`.
- Report path writable: `._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md`.

Missing fixture, stale binary, port collision after one retry, disk shortage, missing CUDA proof, or uncallable nvidia-smi classifies as BLOCKED-preflight.

Driver interface used by this plan:

```powershell
pwsh -NoProfile -File `
    ._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1 `
    -RunId stage29-cache-modes-YYYYMMDD-NN `
    -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
    -RunRoot ._test_output\stage29-cache-modes-YYYYMMDD-NN `
    -ReportPath ._design_docs\.test_reports\test-report-YYYYMMDD-NN-stage29-01.md `
    -CacheColdPath D:\tmp\cache-cold-stage29 `
    -BasePort 8900 `
    -LegDurationMin 10 `
    -ColdBudgetMiB 2048 `
    -HotBudgetMiB 512 `
    -Cycles 3 `
    -OutputEquivalencePrompts 5 `
    -LlamaServerPath build-cuda\bin\Release\llama-server.exe `
    -ContextSize 4096 `
    -Parallel 2 `
    -Seed 42
```

## Workload contract

Per design part-02 and D29-DESIGN-01, the driver invokes the wrapper
[compare-legacy-vs-hybrid-workload.ps1](../../cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1)
via `New-ComparisonWorkload`. The wrapper:

- Allocates 200 requests per cycle, deterministic seed 42.
- Applies the 40/30/30 distribution: 80 exact, 60 near_prefix, 60 new_branch (per wrapper L29-33).
- Emits per-request lines with the six required fields: `request_id`, `cache_class`, `messages`, `max_tokens`, `temperature`, `seed` (per wrapper L154-162; matches design part-04 metric table).
- Writes `workload.jsonl` and `equivalence-prompts.jsonl` with LF-only UTF-8 no BOM.
- Empirical counts are tolerated within +/- 5 of the expected split per re-review C-01.

The driver wipes the cold directory between modes of the same cycle (R29-09 mitigation per driver code in `Invoke-CycleLeg`).

## Test rows

### Correctness layer (TP-29-CC-*)

Pre-conditions: Phase 0 preflight PASS; Phase 0.5 workload build PASS;
workload.jsonl has 200 requests with 40/30/30 distribution; equivalence-prompts.jsonl
has 5 prompts.

| ID | Source design | Preconditions | Command / observation | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- |
| TP-29-CC-01 | design part-03 L57-65; part-05 Layer 1 sub-check 1.2; D29-DESIGN-03 | Phase 1 booted in legacy mode, then hybrid mode, with cooldowns between | `Test-Stage29OutputEquivalence -LegacyDecodedPath <RunRoot>/phase-1-output-equivalence/legacy-decoded.txt -HybridDecodedPath .../hybrid-decoded.txt -DiffOutPath .../diff.txt` | `diff.txt` is empty; 5 lines per file; byte-identical content | `phase-1-output-equivalence/{legacy,hybrid}-decoded.txt`, `diff.txt` | PASS = byte-identical for all 5 prompts; FAIL = any prompt diff (records silent cache-blob substitution); BLOCKED = server failed /health in either mode |
| TP-29-CC-02 | design part-05 Layer 1 sub-check 1.1; part-04 ground-truth | Phase 2 cold-start complete; per-leg cold dir present | read `cold_store_file_count` from summary; verify every cold file passes magic + format + version + payload-id + pair-state + size + checksum validation per Stage 6 design part-02; verify `llamacpp:cache_descriptor_validation_failures_total` delta = 0, `llamacpp:cache_pairing_violations_total` delta = 0, `llamacpp:cache_restore_failures_total` delta = 0 | zero validation mismatches across all hybrid legs | `summary.json` per leg + `cold-store-evidence.json` per leg | PASS = 0 mismatches; FAIL-correctness-cold-store = any mismatch > 0 |
| TP-29-CC-03 | design part-05 Layer 1 sub-check 1.3; D29-DESIGN-06 | Phase 2 + Phase 3 complete for both modes | per-hybrid-leg, compute `cache_fallback_restores_total_delta / max(cache_hits_total_delta + cache_fallback_restores_total_delta, 1)`; record per-leg ratio | at least 8 of every 10 hybrid legs below 10% fallback rate | `summary.json` per leg | PASS = at most 20% of hybrid legs above 10% fallback; OK-with-fallback-warning = at most 20% above 10% but none above 20%; FAIL-correctness-fallback-rate = any leg above 20% |
| TP-29-CC-04 | design part-03 L95-110; D29-DESIGN-06; impl-review N-04 | per-mode and per-cycle cooldown records in `summary.json` | read `cooldown_duration_seconds` from each leg summary; verify VRAM back to baseline within 120s (current driver cap per Wait-Stage29VramBaseline.ps1 L60 default) for every cooldown | every cooldown <= 120s | `summary.json` per leg; `cooldown-evidence.json` per leg | PASS = all cooldowns <= 120s; BLOCKED-vram-release = any cooldown > 120s (note: plan claims 180s cap per R29-IMPL-02; actual driver default is 120s; see INFO F-02) |

### Per-request layer (TP-29-PR-*)

Pre-conditions: Phase 1 PASS; Phase 2 cold-start complete for both modes;
Phase 3 three warm cycles complete for both modes; per-cycle summary.json
present with cache_class_counts and per-leg metric snapshots.

| ID | Source design | Preconditions | Command / observation | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- |
| TP-29-PR-01 | design part-05 Layer 2; part-07 D29-OQ-03; part-04 | per-leg requests.jsonl with cache_n, prompt_n, cache_class; per-cycle summary cache_class_counts | group requests.jsonl by `(cycle, mode, cache_class)`; compute mean `cache_n_ratio = cache_n / prompt_n` per group | hybrid `exact` cache_n_ratio mean >= legacy `exact` cache_n_ratio mean | `requests.jsonl` per leg | PASS = hybrid exact >= legacy exact; FIX-TARGET row in Q1 verdict if hybrid exact < legacy exact by < 0.05; REVERT row in Q1 verdict if hybrid exact < legacy exact by >= 0.05 |
| TP-29-PR-02 | design part-05 Layer 2 + decision-support Q3; D29-OQ-02 cold-load asymmetry | per-leg requests.jsonl; cold-start cycle distinguishes cold-miss vs warm-miss | for cold-start cycle only, group by `(mode, miss_type)`; compute p50, p95, p99 of `ttft_ms` | hybrid cold-miss `ttft_ms` p50 <= legacy cold-miss `ttft_ms` p50 + 50 ms threshold | `requests.jsonl` per leg + cold-start latency recorded in summary.json | PASS = hybrid cold-miss p50 within 50 ms of legacy cold-miss p50; ACCEPT-COLD if within threshold; FIX-TARGET if above threshold |
| TP-29-PR-03 | design part-05 Layer 2 + decision-support Q2 | warm cycles complete; per-leg requests.jsonl | group warm cycles by `(mode, cache_class)`; compute p50, p95, p99 of `wall_clock_ms` per `(mode, cache_class)` | hybrid `exact` warm-hit `wall_clock_ms` p95 <= legacy `exact` warm-hit `wall_clock_ms` p95 * 1.10 (10% tolerance) | `requests.jsonl` per leg | PASS = hybrid warm-hit p95 within 10% of legacy warm-hit p95; SHIP-Q2 if within; FIX-TARGET if above |

### Aggregated layer (TP-29-AG-*)

Pre-conditions: all per-cycle summaries present; cold-store evidence
present; VRAM peak recorded per leg.

| ID | Source design | Preconditions | Command / observation | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- |
| TP-29-AG-01 | design part-05 Layer 3 + decision-support Q1 | Phase 2 + Phase 3 summaries | compute mean cache hit rate per mode using `cache_n > 0` count / total request count across all cycles | hybrid mean hit rate >= legacy mean hit rate + 5 percentage points OR hybrid mean hit rate >= 60% absolute | `requests.jsonl` per leg aggregated | PASS = either condition holds; FIX-TARGET if hybrid within 5 pp of legacy; REVERT if hybrid < legacy |
| TP-29-AG-02 | design part-04 + part-05 Layer 3 | all phases complete | sum `cache_n` across all cycles per mode; record as `total_tokens_reused` | hybrid total_tokens_reused > 0 across all 4 cycles; legacy total_tokens_reused reported as comparison data | `requests.jsonl` per leg aggregated | PASS = hybrid > 0 and legacy reported; not blocking if legacy total is 0 (legacy prompt-cache hits are different semantics; report comparison data) |
| TP-29-AG-03 | design part-06 D29-DESIGN-02 + part-05 Layer 3 | Phase 2 + Phase 3 hybrid legs complete | read `cold_store_bytes_on_disk` and `cold_store_file_count` from final hybrid leg summary; verify bytes <= 2048 MiB and file count >= 10 | hybrid cold-store bytes <= 2048 MiB; hybrid cold-store file count >= 10 (proxy for write activity) | `summary.json` per leg + `cold-store-evidence.json` | PASS = both conditions hold; FAIL = bytes > 2048 MiB (budget exceeded); BLOCKED-cold-store-drift = drift ratio > 5.0 (per design part-04) |
| TP-29-AG-04 | design part-03 VRAM release gate + part-05 Layer 3 | per-leg summary with VRAM peak recorded | read `vram_peak_mib` from each leg summary; verify both modes under 6 GiB peak | legacy vram_peak_mib < 6144 AND hybrid vram_peak_mib < 6144 | `summary.json` per leg + `cooldown-evidence.json` | PASS = both modes under 6 GiB; BLOCKED-host-capacity = any leg >= 6 GiB (insufficient headroom for VRAM release gate) |

### Regression rows (TP-29-RG-*)

Pre-conditions: post-Stage-28 closed binary (142/142 unit tests PASS);
no product code modifications in working tree.

| ID | Source | Preconditions | Command / observation | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- |
| TP-29-RG-01 | Stage 10 closure contract | build-cuda clean build | `cmake --build build-cuda --config Release -j --target test-cache-controller`; run `build-cuda/bin/Release/test-cache-controller.exe`; run `pytest tests/` | focused tests 8/8 PASS; pytest 3 PASS + 1 xfail | `build-cuda/bin/Release/test-cache-controller.exe` output + `pytest` output | PASS = 8/8 focused tests PASS and 3+1xfail pytest; FAIL or REPRODUCED on any focused failure; this row is BLOCKED if the focused test binary cannot be built from the post-Stage-28 binary |
| TP-29-RG-02 | impl-review N-02; part-10 traceability; Stage 27 closure D-EXEC-27-08 | working tree clean before authoring this plan | `git status --short -- tools/server/`; `git diff --stat HEAD -- tools/server/server-cache-hybrid.cpp` | no modifications to `tools/server/`; historical line reference `tools/server/server-cache-hybrid.cpp:3396` (now around line 462 per part-10 N-02) NOT modified | `git status` + `git diff --stat` output | PASS = zero modifications in tools/server/; FAIL = any modification in tools/server/ (scope creep per R29-06) |

### Coverage row (TP-29-CV-01)

Pre-conditions: post-Stage-28 closed binary with debug symbols
(/Zi per Stage 18 D18-IMPL-01); OpenCppCoverage at canonical path;
focused comparison binary rebuildable.

| ID | Source | Preconditions | Command / observation | Expected outcome | Evidence | Pass/fail criteria |
| --- | --- | --- | --- | --- | --- | --- |
| TP-29-CV-01 | Stage 28 closure; Stage 10 coverage contract T114 | focused binary rebuilt cleanly; OpenCppCoverage available | `OpenCppCoverage.exe --export_type binary:<path> --modules build-cuda/bin/Release/test-cache-controller.exe -- <run args>`; union Cobertura XML per [run_coverage.ps1](../../cache-handling-test-scripts/run_coverage.ps1) Phase 1 | hybrid-mode coverage rate matches Stage 28 closure (0.8521 PASS at Stage 10 closure; 142/142 PASS at Stage 28 closure); rate reported in report, not blocking | coverage-merged.xml + per-test `.cov` files | PASS if rate reported (not blocking per Stage 10 closure contract); BLOCKED if Release build lacks `/Zi` (per self-improvement memory Release-without-Zi coverage gap) |

## Evidence paths and classification

Per-leg artifacts (non-durable, under `._test_output/stage29-cache-modes-YYYYMMDD-NN/`):

- `<phase>-cycle-N/<mode>/launch.log`, `server.out.log`, `server.err.log`
- `<phase>-cycle-N/<mode>/metrics-before.txt`, `metrics-after.txt`
- `<phase>-cycle-N/<mode>/requests.jsonl` (per-request direct stats)
- `<phase>-cycle-N/<mode>/summary.json` (cache_class_counts, hit_delta, miss_delta, vram_peak_mib, cooldown_duration_seconds)
- `cold-store-evidence.json` (per-leg hybrid only)
- `cooldown-evidence.json` (per-leg VRAM polling history)

Run-root artifacts:

- `workload.jsonl` (200 requests, 40/30/30 distribution)
- `equivalence-prompts.jsonl` (5 prompts)
- `phase-1-output-equivalence/{legacy,hybrid}-decoded.txt`, `diff.txt`
- `dry-run-plan.json` (when -DryRun)

Durable report (per test plan part-24):

- `._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md`

Three-layer report sections per design part-05:

- Layer 1 Correctness: cold-store validity, output equivalence verdict, fallback rate
- Layer 2 Per-request: side-by-side per-cache_class table + p50/p95/p99 distributions
- Layer 3 Aggregated: mean hit rate, total tokens reused, cold-store utilization, VRAM peak, drift ratio
- Decision-support: Q1..Q5 with SHIP / FIX-TARGET / REVERT / ACCEPT-COLD verdict per question and final recommendation

Evidence classification per design part-04:

- Public Prometheus: counter deltas and gauge snapshots (hybrid counter set is larger; legacy counters that do not exist are recorded as NOT-APPLICABLE-legacy not BLOCKED-metric-unavailable).
- Structured log: restore strategy, fallback reason, degraded metadata.
- Direct stats: per-request timings, filesystem bytes, process samples.
- Harness-only: cold-miss vs warm-miss split (driver computes).

## Classification rules

PASS requires:

- All 4 correctness rows PASS (CC-01..04).
- All 3 per-request rows PASS or meet the documented FIX-TARGET / ACCEPT-COLD criteria (PR-01..03).
- All 4 aggregated rows PASS (AG-01..04).
- Both regression rows PASS (RG-01..02).
- Coverage row reports a rate (CV-01 not blocking per Stage 10 closure).

FAIL:

- Valid-setup product crash during any phase.
- Repeated HTTP 500 after health established.
- Phase 1 output equivalence DIFF (silent cache-blob substitution).
- Cold-store validation failure (descriptor / pairing / restore failures > 0).
- Drift ratio > 5.0 in any hybrid leg.
- Modifications to production code under `tools/server/` (TP-29-RG-02 FAIL = scope creep).

BLOCKED:

- Missing fixture, stale binary, port collision after one retry, disk shortage.
- Server never healthy within timeout.
- Missing required metric with no substitute (counter delta missing on hybrid-only metrics is NOT blocking; counter missing on legacy-applicable metrics IS blocking).
- Missing CUDA configure proof, missing runtime CUDA/NVIDIA proof.
- Driver contract violation (see INFO finding F-01 below).
- VRAM release failure after the driver cap (120s default; plan claims 180s per R29-IMPL-02; see INFO F-02).

## Findings from prior review

F-01 (BLOCKING, pre-existing): driver `Main` dispatcher at [compare-legacy-vs-hybrid.ps1](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1) L204-225 does NOT call `Invoke-Phase1OutputEquivalence` (Phase 1) or `Invoke-CycleLeg` (Phase 2 cold-start + Phase 3 warm cycles) when invoked without `-DryRun` or `-OutputEquivalenceOnly`. Without those switches, `Main` runs only Phase 0 preflight, Phase 0.5 workload build, and `Write-Stage29Report`; the latter writes a per-leg table from `summary.json` that has no rows. The implementation review [part-06-impl-review-20260628.md](../../cache-handling-phase29-implementation/part-06-impl-review-20260628.md) section 1 row S29-IMPL-06 marks this DONE because `Invoke-CycleLeg` is implemented, but it is not invoked from `Main`. Verified by byte-level read of `Main` L204-225 (no `Invoke-CycleLeg` call, no `Invoke-Phase1OutputEquivalence` call). Driver contract gap. Without a Developer fix to `Main`, this test plan cannot run end-to-end and every CC / PR / AG row that depends on Phase 1 / Phase 2 / Phase 3 evidence is BLOCKED-driver-contract at execution. Suggested Developer fix: extend `Main` to call `Invoke-Phase1OutputEquivalence` after Phase 0.5, then loop `Invoke-CycleLeg` for Phase 2 (cycle=1, phase=cold-start) and Phase 3 (cycle=1..3, phase=warm), populating `summary.json` before `Write-Stage29Report`.

F-02 (INFO, pre-existing): driver VRAM cooldown cap drift. The plan and impl log claim 180s cap per R29-IMPL-02 ([Wait-Stage29VramBaseline.ps1](../../cache-handling-test-scripts/lib/Wait-Stage29VramBaseline.ps1) docstring, [part-04-risks-and-oq-resolutions.md](../../cache-handling-phase29-implementation/part-04-risks-and-oq-resolutions.md) L116-122). The actual helper default is `MaxWaitSec = 120` ([Wait-Stage29VramBaseline.ps1](../../cache-handling-test-scripts/lib/Wait-Stage29VramBaseline.ps1) L60); the driver `Invoke-CycleLeg` calls it with `-MaxWaitSec 120` ([compare-legacy-vs-hybrid.ps1](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1) L189); the helper docstring at L36 says "binding cap of 180s" but the parameter default contradicts it. This test plan records the actual cap of 120s in TP-29-CC-04. Non-blocking; the cap is a per-host load characteristic, not a correctness gate. The QA test report should preserve the discrepancy and request Developer alignment of docstring / impl log / helper default if a future stage needs the 180s ceiling.

F-03 (INFO, pre-existing): preflight is missing 2 of 7 design sub-checks per impl-review N-03. The driver `Invoke-Preflight` at [compare-legacy-vs-hybrid.ps1](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1) L71-83 records 7 fields but only 5 gate the result; design part-03 L22-28 lists 7 sub-checks (clean build, fixture, port, disk, CUDA proof, binary mtime, git HEAD+dirty). The "disk check" and "binary mtime > source mtime" sub-checks are missing. Non-blocking: the 5 gating fields cover the safety-critical checks and the preflight correctly classifies BLOCKED-preflight when expected. The QA test report preserves the preflight field set in `dry-run-plan.json` and requests Developer add the two missing sub-checks in a future correction.

F-04 (INFO, pre-existing): driver parameter count drift. Impl log says "17-param set" at [cache-handling-phase29-implementation.md](../../cache-handling-phase29-implementation.md) L244 but the driver declares 18 typed parameters ([compare-legacy-vs-hybrid.ps1](../../cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1) L18-36: 16 strings/ints + 2 switches). Plan entry doc lists 17 design params + adds `-RequestCount` and `-OutputEquivalenceOnly` for QA smoke. Non-blocking: all parameters are reasonable and named. Wording drift only.

## Risks

| ID | Risk | Mitigation |
| --- | --- | --- |
| R-29-TP-01 | Driver `Main` does not invoke Phase 1 / Phase 2 / Phase 3 (finding F-01). | Test plan marks the affected rows as BLOCKED-driver-contract at execution until Developer fixes `Main`. Recorded in finding F-01 with the suggested one-line fix to invoke `Invoke-CycleLeg` from `Main`. |
| R-29-TP-02 | Stale CUDA Release binary masks Stage 25-27 fixes. | Clean `build-cuda` build mandatory before execution; record binary mtime and size in report. |
| R-29-TP-03 | Synthetic workload does not represent real agentic behavior. | Wrapper enforces 40/30/30 distribution; report records empirical cache_class counts per cycle (re-review C-03). |
| R-29-TP-04 | VRAM release delay between legs. | Hard nvidia-smi gate with 120s cap (actual driver default) per cooldown; record cooldown_duration_seconds per leg. |
| R-29-TP-05 | Cold-store drift still observed after Stage 28 R28-BUG-02 reconcile. | Drift ratio per leg recorded; ratio > 1.10 classifies as OK-with-drift-warning, > 5.0 classifies as BLOCKED-cold-store-drift. |
| R-29-TP-06 | 4 cycles x 2 modes exceeds session budget. | 80-minute execution budget documented; Manager may approve reduced 2-cycle warm run. |
| R-29-TP-07 | Scope creep into production code. | TP-29-RG-02 verifies zero modifications to `tools/server/`; FAIL on any modification. |

## Handoff

Status: test plan authored. Pending Manager test-plan gate review. After
gate PASS: Manager opens QA execution. After execution: Developer
test-results review. After Developer review PASS: Manager closure per
D-CLOSURE-29-NN.

This file uses LF line endings, plain ASCII status labels, no BOM, no
trailing whitespace, and stays under the 300-line durable-doc cap.
