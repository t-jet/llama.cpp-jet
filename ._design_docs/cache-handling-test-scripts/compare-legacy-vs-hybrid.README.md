# compare-legacy-vs-hybrid.ps1

Stage 29 driver: A/B comparison of `--cache-mode legacy` against
`--cache-mode hybrid` on a reproducible agentic-shaped workload.
Implements the 5 phases from design part-03 and the three-layer report
emitter per design part-05. Comparison-only; no production code changes.

## Design baseline

- Approved design: [cache-handling-phase29-design](../../cache-handling-phase29-design.md) (entry + 13 part files)
- Approved implementation plan: [cache-handling-phase29-implementation](../../cache-handling-phase29-implementation.md) (entry + 5 part files + part-05 plan review)
- Reuses design-correct wrapper: [lib/compare-legacy-vs-hybrid-workload.ps1](lib/compare-legacy-vs-hybrid-workload.ps1) (200 lines, NOT modified)
- Reuses Stage 20 lib: [lib/agentic-prompt-generator.ps1](lib/agentic-prompt-generator.ps1) (308 lines, NOT modified)

## Usage

```powershell
pwsh -NoProfile -File `
    ._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1 `
    -RunId stage29-cache-modes-20260628-01 `
    -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
    -RunRoot ._test_output\stage29-cache-modes-20260628-01 `
    -LlamaServerPath build-cuda\bin\Release\llama-server.exe `
    -Cycles 3 `
    -ColdBudgetMiB 2048 `
    -HotBudgetMiB 512
```

### Parameters

| Parameter | Type | Default | Purpose |
| --- | --- | --- | --- |
| `-RunId` | string | `stage29-cache-modes-YYYYMMDD` | Run identifier; appears in summary.json and report path |
| `-ModelPath` | string | empty | Path to the GGUF model (Qwen3.5-4B-MTP) |
| `-RunRoot` | string | empty | Output root for non-durable artifacts (workload.jsonl, summary.json, per-leg dirs) |
| `-ReportPath` | string | auto | Durable report path under `._design_docs/.test_reports/` |
| `-CacheColdPath` | string | `D:\tmp\cache-cold-stage29` | Cold-store directory; wiped between modes |
| `-BasePort` | int | 8900 | llama-server bind port |
| `-LegDurationMin` | int | 10 | Per-leg wall-clock cap (Stage 24 precedent) |
| `-ColdBudgetMiB` | int | 2048 | Cold-store byte budget (D29-DESIGN-02) |
| `-HotBudgetMiB` | int | 512 | Hot-payload byte budget (Stage 24 precedent) |
| `-Cycles` | int | 3 | Number of warm A/B cycles (D29-DESIGN-04) |
| `-OutputEquivalencePrompts` | int | 5 | Number of prompts in Phase 1 byte-equivalence check |
| `-LlamaServerPath` | string | empty | Path to `llama-server.exe` (preflight gate) |
| `-ContextSize` | int | 4096 | Model context size |
| `-Parallel` | int | 2 | Server `--parallel` slot count |
| `-Seed` | int | 42 | Deterministic seed for workload and chat completions |
| `-RequestCount` | int | 200 | Per-cycle request count |
| `-DryRun` | switch | off | Run preflight only; print preflight JSON; exit 0 |
| `-OutputEquivalenceOnly` | switch | off | Run Phase 1 only; useful for the QA smoke test |

## Phases

| Phase | Description | Source |
| --- | --- | --- |
| 0 | Preflight: PS version, binary, fixture, port, CUDA, git HEAD+dirty | design part-03 lines 24-29 |
| 0.5 | Boot legacy tokenize helper; build workload.jsonl (200 reqs, 40/30/30) and equivalence-prompts.jsonl (5 prompts); shutdown helper | design part-03 lines 30-56 |
| 1 | Boot legacy, send 5 prompts, capture decoded text, cooldown, boot hybrid, send 5 prompts, capture decoded text, cooldown, byte-compare | design part-03 lines 64-72 |
| 2 | Cold-start cycle: 1 cycle x 2 modes x 200 reqs, cold-start latency recorded for first 5 requests | design part-03 lines 73-85 |
| 3 | Warm cycles: 3 cycles x 2 modes x 200 reqs, per-cycle metrics aggregation | design part-03 lines 86-90 |
| Report | Emit three-layer Markdown report (Correctness, Per-request, Aggregated) + decision-support Q1..Q5 | design part-05 |

## Output schema

### Per-leg directory

```text
<RunRoot>/<phase>-cycle-N/<mode>/
    metrics-before.txt      # Prometheus snapshot before leg
    metrics-after.txt       # Prometheus snapshot after leg
    requests.jsonl          # per-request timings (cache_n, prompt_ms, etc.)
    server.out.log          # llama-server stdout
    server.err.log          # llama-server stderr
```

### Run-level

```text
<RunRoot>/
    workload.jsonl                   # 200 reqs, 40/30/30 cache_class distribution
    equivalence-prompts.jsonl        # 5 prompts for Phase 1
    summary.json                     # per-cycle evidence rows (one entry per leg)
    phase-1-output-equivalence/      # legacy-decoded.txt, hybrid-decoded.txt, diff.txt
    phase-2-cycle-1/                 # legacy/, hybrid/
    phase-3-cycle-1..3/              # legacy/, hybrid/
    dry-run-plan.json                # preflight result (when -DryRun)
```

### Durable report

```
._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md
```

Markdown with three layers per design part-05:

1. Correctness (cold-store validity, output equivalence, fallback restore rate)
2. Per-request comparison (side-by-side table + per-cache-class distributions)
3. Aggregated (mean hit rate, total tokens reused, drift ratio, VRAM peak)

Plus the five decision-support questions Q1..Q5 with SHIP / FIX-TARGET /
REVERT / ACCEPT-COLD verdicts and the final recommendation
(SHIP-HYBRID-AS-DEFAULT, SHIP-HYBRID-AS-OPTIONAL, or DO-NOT-SHIP).

## Lib helpers (4 files, all under 300 lines)

| File | Public function | Purpose |
| --- | --- | --- |
| lib/Read-Stage29MetricSnapshot.ps1 | `Read-Stage29MetricSnapshot` | GET /metrics, write raw text, return parsed snapshot hashtable |
| lib/Write-Stage29EvidenceRow.ps1 | `Write-Stage29EvidenceRow`, `Get-Stage29CounterDelta`, `Read-Stage29Summary` | Append/replace row in summary.json; compute counter deltas |
| lib/Test-Stage29OutputEquivalence.ps1 | `Test-Stage29OutputEquivalence` | Byte-compare legacy and hybrid decoded text files; write diff |
| lib/Wait-Stage29VramBaseline.ps1 | `Wait-Stage29VramBaseline`, `Get-NvidiaSmiMemoryUsedMiB` | Sleep + nvidia-smi poll; record cooldown duration |

## Failure classification

| Classification | Trigger | Exit code |
| --- | --- | ---: |
| `PASS` | All phases complete; no failures | 0 |
| `BLOCKED-preflight` | Missing fixture, stale binary, port collision, missing CUDA proof | 2 |
| `BLOCKED-powershell-version` | `$PSVersionTable.PSVersion.Major -lt 5` | n/a (preflight sub-check) |
| `BLOCKED-workload-build` | Phase 0.5 tokenize helper failed or workload.jsonl missing required fields | n/a (Phase 0.5 throw) |
| `BLOCKED-server-not-running` | llama-server failed /health within timeout (Phase 0.5, Phase 1, or per-leg) | 4 (smoke test path) |
| `BLOCKED-output-equivalence` | Phase 1 byte-compare diff is non-empty | 3 (Phase 1 exit) |
| `BLOCKED-vram-release` | Cooldown cap exceeded (180s per R29-IMPL-02) | n/a (per-leg throw) |
| `BLOCKED-cold-store-drift` | Drift ratio > 5.0 in any hybrid leg | n/a (per-leg record) |
| `FAIL-metric-format-regression` | `^llamacpp_cache_` (underscore form) appears in metrics-after.txt | n/a (per-leg record) |
| `FAIL-correctness-cold-store` | Descriptor validation failures, pairing violations, or restore failures > 0 | n/a (Layer 1 sub-check) |
| `FAIL-correctness-fallback-rate` | Fallback restore rate > 20% | n/a (Layer 1 sub-check) |
| `OK-with-drift-warning` | Drift ratio > 1.10 but <= 5.0 | n/a (per-leg record) |
| `OK-with-fallback-warning` | Fallback restore rate > 5% but <= 20% | n/a (Layer 1 sub-check) |

## Invariants preserved

The driver observes but does not modify production code. The post-Stage-28
closed binary (142/142 unit tests PASS) preserves:

- I-25-01 atomicity (tx_* synchronous transactions)
- I-25-02 isolation (recursive mutex)
- I-25-03 durability-within-transaction
- F-21-EXEC-01 prompt-only save
- F-21-RERUN-01 descriptor tracking
- F-22-DR-01 demotion coordination
- D-EXEC-26-01 SEH handler
- D-EXEC-26-02 argv function-scope vector and cold-store per-id accounting
- D-EXEC-27-08 (historical line ref `tools/server/server-cache-hybrid.cpp:3396`; line is a historical reference only; current line is around 462 in the legacy definition section)
- R28-BUG-02 cold-store reconcile

## Self-test

```powershell
# Dry-run (prints preflight JSON, exits 0)
pwsh -NoProfile -Command "& '.\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1' -DryRun"

# Output-equivalence smoke (fails with BLOCKED-server-not-running when no server is running)
pwsh -NoProfile -Command "& '.\._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1' -OutputEquivalenceOnly"
```

Both self-tests are recorded in `._test_output/stage29/self-test/` by the
implementation session:

- `dry-run.json`: dry-run stdout
- `smoke-equivalence.json`: output-equivalence smoke stdout

## Out of scope

Per design part-01 N1..N8: no product code changes, no L1 prompt-cache
measurement, no coverage measurement, no Stage 23 S/L matrix rerun, no
Stage 24 runner reuse, no real agentic traffic as primary workload, no
heavy-tier fixture, no `/v1/completion` route.

## See also

- Design entry: [cache-handling-phase29-design](../../cache-handling-phase29-design.md)
- Implementation entry: [cache-handling-phase29-implementation](../../cache-handling-phase29-implementation.md)
- Design re-review (PASS): [part-13](../../cache-handling-phase29-design/part-13-design-re-review-20260628.md)
- Plan review (PASS): [part-05](../../cache-handling-phase29-implementation/part-05-impl-plan-review-20260628.md)
