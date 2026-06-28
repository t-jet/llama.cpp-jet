# Part 3: Comparison driver design

Status: design in progress (Architect session)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison - legacy vs hybrid)
Source: [../cache-handling-phase29-design.md](../cache-handling-phase29-design.md)

## Driver name and location

`compare-legacy-vs-hybrid.ps1` under
`_design_docs/cache-handling-test-scripts/`. The driver is a new script, NOT
an extension of `stage24-chat-s02-s03-comparison.ps1`, because the output
contract differs (three-layer comparison vs per-row comparison).

## Sequencing

The driver runs five phases in order:

```text
Phase 0: preflight

  - clean build check
  - fixture check
  - port check
  - disk check
  - CUDA build proof (CMakeCache.txt GGML_CUDA:BOOL=ON)
  - binary mtime > source mtime
  - git commit hash + dirty status recorded

Phase 0.5: boot tokenize helper + workload build

  - boot llama-server on port 8900 with --cache-mode legacy
    (no GPU load needed for /tokenize; --n-gpu-layers 0 is acceptable)
  - wait for /health to return ok (max 30s)
  - call New-ComparisonWorkload via
    ._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1
    to emit workload.jsonl (200 reqs, 40/30/30 exact/near_prefix/new_branch)
  - also call New-ComparisonWorkload -RequestCount 5 -OutPath
    equivalence-prompts.jsonl for the Phase 1 equivalence check
  - shut down the helper server gracefully
  - apply the standard cooldown (VRAM back-to-baseline, max 120s)
  - the helper is NOT reused for Phase 1 or later phases; each phase boots
    its own server per the per-mode cooldown rule

Why this sub-phase exists: per review finding B-02, the Stage 20 lib's
New-AgenticChatPrompt calls /tokenize on every iteration to drive
adaptive chunking. The driver cannot call the lib at Phase 0 because no
server is running yet. Booting a brief legacy-mode helper just for
/tokenize isolates the helper cost from the comparison legs and keeps
the Phase 0 preflight fast.

Failure classification: if the tokenize helper fails to come up, if
New-ComparisonWorkload throws, or if the workload.jsonl is missing
required fields (request_id, cache_class, messages, max_tokens,
temperature, seed), the driver classifies the run as
BLOCKED-workload-build and stops.

Phase 1: output equivalence pre-check (5 prompts with seed=42, max_tokens=8)

  - boot legacy, send 5 prompts, capture decoded text
  - shut down legacy, cooldown
  - boot hybrid, send same 5 prompts, capture decoded text
  - shut down hybrid, cooldown
  - byte-compare decoded text per prompt
  - PASS requires byte-identical. FAIL or DIFF recorded as BLOCKED-output-equivalence.

Phase 2: cold-start cycle (1 cycle)

  - boot legacy, cold (empty hot budget, empty cold dir)
  - replay 200-request workload
  - record cold-start latency for first 5 requests (separate metric)
  - shut down legacy, cooldown
  - boot hybrid, cold (empty hot budget, empty cold dir)
  - replay 200-request workload
  - record cold-start latency for first 5 requests
  - shut down hybrid, cooldown

Phase 3: warm cycles (3 cycles)

  - for cycle = 1..3:
    - boot legacy, hot (warm cache state from prior legacy leg OR fresh if cycle=1)
    - replay 200-request workload
    - shut down legacy, cooldown
    - boot hybrid, hot (warm cache state from prior hybrid leg OR fresh if cycle=1)
    - replay 200-request workload
    - shut down hybrid, cooldown
    - aggregate per-cycle metrics
```text

Total wall-clock budget: 80 minutes.

```text
Phase 0:                  ~2 minutes
Phase 1 (5 prompts x 2):  ~5 minutes
Phase 2 (200 req x 2):   ~20 minutes
Phase 3 (3 cycles x 200 req x 2): ~50 minutes
Cooldowns: ~3 minutes
Total: ~80 minutes
```text

Manager may approve a reduced 2-cycle warm run (drops Phase 3 to 2 cycles,
~30 minutes) if the session budget is tight.

## Port allocation

Both modes use the same base port (default 8900) since they are not
concurrent. The driver uses port 8900 for legacy and 8900 for hybrid at
different times. If a future Manager approves running both modes
concurrently for overlap checks, port 8900 for legacy and 8901 for hybrid.

This matches Stage 24 precedent: "Use base port 8900 by default. Each
logical row runs serially with one server process at a time."

## Cooldown between runs

Cooldown is mandatory between every mode-switch and every cycle.

```text

1. Send SIGTERM to llama-server PID (graceful shutdown)
2. Wait for process exit (max 30s)
3. Verify port 8900 is free
4. Sleep 30s (file handle release, cold-store unmount)
5. nvidia-smi --query-gpu=memory.used --format=csv,noheader
   - record VRAM used (MiB) at this point
6. If VRAM used > (baseline + 100 MiB), wait up to 120s total, polling
   nvidia-smi every 5s

7. If VRAM still not at baseline after 120s, classify as BLOCKED-vram-release
   and stop the comparison

8. Wipe cold dir: rm -rf <cold-dir>/<mode>/<cycle>
9. Hot cache budget reset: do NOT carry hot cache state between cycles
   unless explicitly configured (default: do not carry; each cycle starts cold
   on hot side, except for cycle 1 which is the warm cycle after cold-start)
```text

The cooldown logic is binding. The runner aborts if VRAM does not return to
baseline within 120s.

## Contention analysis

The original proposal identified VRAM, CPU, RAM, disk, and /metrics scrape
contention as reasons to run legs sequentially. The driver follows that rule.

Specifically:

- VRAM: both modes load the same model weights (~3 GiB for Qwen3.5-4B-MTP).
  Sequential runs avoid double-loading.

- CPU: prompt processing is CPU-bound on small batches. Sequential runs
  avoid CPU contention that would skew latency comparison.

- Disk: cold store writes can hit disk bandwidth on hybrid mode. Sequential
  runs isolate this.

- /metrics scrape: each scrape takes ~50ms. Sequential runs avoid scrape
  contention.

The driver does NOT run any background workload (no k6, no bench-cache-
correctness.js) during the comparison legs. The optional k6 sanity check at
leg start runs ONCE per mode, not per cycle, and only on the first cycle.

## Driver interface

```powershell
& ._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1 `
    -RunId stage29-cache-modes-YYYYMMDD-NN `
    -ModelPath ._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf `
    -RunRoot ._test_output\stage29-cache-modes-YYYYMMDD-NN `
    -ReportPath ._design_docs\.test_reports\test-report-YYYYMMDD-NN.md `
    -CacheColdPath D:\tmp\cache-cold-stage29 `
    -BasePort 8900 `
    -LegDurationMin 10 `
    -ColdBudgetMiB 2048 `
    -HotBudgetMiB 512 `
    -Cycles 3 `
    -ColdStartEnabled `
    -OutputEquivalencePrompts 5 `
    -LlamaServerPath build-cuda\bin\Release\llama-server.exe `
    -ContextSize 4096 `
    -Parallel 2 `
    -Seed 42 `
    -DryRun
```text

The `-DryRun` switch prints the planned command family, workload summary,
port allocation, cooldown schedule, and exits without starting servers.

## Artifacts produced

Per-cycle:

- `phase-2-cycle-N/legacy/launch.log`, `server.out.log`, `server.err.log`,
  `metrics-before.txt`, `metrics-after.txt`, `requests.jsonl`, `summary.json`

- Same set under `phase-2-cycle-N/hybrid/`

Per-phase:

- `phase-1-output-equivalence/legacy-decoded.txt`,
  `hybrid-decoded.txt`, `diff.txt` (empty on PASS)

Per-run:

- `dry-run-plan.json`
- `comparison.json` (per-cycle, per-mode, per-cache-class)
- `aggregate.json` (across cycles, per-mode, per-cache-class)
- `final-leak-scan.json`
- Durable report at `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md`

## Failure classification

PASS:

- All phases complete without abort
- Phase 1 output equivalence PASS (byte-identical)
- Phase 2 cold-start cycle both modes complete
- Phase 3 warm cycles both modes complete for the configured cycle count
- All required artifacts exist
- No VRAM release failure
- No cold-store drift > 1.10 (Stage 26 part-04 target)

FAIL:

- Valid-setup product crash
- Repeated HTTP 500 after health established
- Phase 1 output equivalence DIFF (silent cache-blob substitution detected)
- Hybrid checkpoint admission counted as success when bounded failure label
  says it failed (Stage 17 carry-over)

- Cold write failure without bounded handling
- VRAM release failure after 120s

BLOCKED:

- Missing fixture, stale binary, port collision after one setup retry
- Disk shortage, server never healthy
- Missing required evidence, missing required metric with no substitute
- Runner contract violation
- Missing CUDA configure proof, missing runtime CUDA/NVIDIA proof
- Optional proxy capture failed (if Manager approved; not blocking primary)

## Handoff

Part 3 reviewable. Part 4 covers the per-request metric list.
