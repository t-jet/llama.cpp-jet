# Stage 29 implementation plan part 1A: ordered steps 1-5

Source: [../cache-handling-phase29-implementation.md](../cache-handling-phase29-implementation.md)
Companion: [part-01b-steps-6-10.md](./part-01b-steps-6-10.md), [part-02-affected-files.md](./part-02-affected-files.md), [part-03-evidence-plan.md](./part-03-evidence-plan.md), [part-04-risks-and-oq-resolutions.md](./part-04-risks-and-oq-resolutions.md)

This part specifies the first half of the 10 ordered implementation
steps for Stage 29. Reading order: this part (steps 1-5) followed by
part-01b (steps 6-10). The order is binding: each step assumes the
prior step's preconditions. The implementation session executes one
step at a time and updates the part file with the actual evidence
at the end of each step.

## Step ordering rule

Each step starts with the prior step's postcondition. The
implementation session does not start a step until that precondition
is verified. The implementation session does not skip steps. If a
step fails, the implementation session reports the failure and stops
(per the developer skill "Handle one developer activity per session"
constraint).

## Iteration boundary

Steps 1-2 are scaffolding (wrapper smoke test plus the driver and
lib helper skeletons). Steps 3-5 add the runtime Phase 0 preflight,
Phase 0.5 tokenize helper, and Phase 1 output equivalence
pre-check. Steps 6-10 (in part-01b) add the main A/B cycle loop,
cooldown gate, metric scraping, three-layer report emission, and
the pre-execution self-test.

## Step 01: S29-IMPL-01 wrapper script smoke test

Description: verify the existing wrapper script
`._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`
runs as a no-op without producing a JSONL output. The script is
design-correct (Architect re-review PASS 2026-06-28) and the
implementation session does NOT modify it. The smoke test confirms
PowerShell 5+ loads it cleanly and exposes the
`New-ComparisonWorkload` function.

Affected files: none. Step 01 is read-only verification.

Pre-conditions:

- PowerShell 5+ available on the runner
  (`$PSVersionTable.PSVersion.Major -ge 5`).
- The wrapper script exists at
  `._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`
  (200 lines, 7786 bytes, LF-only, no BOM, last byte 0x0A per
  re-review section 3).
- The Stage 20 lib
  `._design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1`
  is on disk and unchanged (mtime 2026-06-27, before wrapper mtime
  2026-06-28).

Post-conditions:

- `Get-Command New-ComparisonWorkload` returns the function after
  dot-sourcing the wrapper.
- `Get-Command New-AgenticChatPrompt` returns the function after
  dot-sourcing the Stage 20 lib.
- Wrapper parameter validation: calling with `RequestCount = 0`
  throws (the wrapper's own `if ($RequestCount -le 0)` guard
  fires).
- Wrapper distribution validation: calling with a distribution
  that does not sum to 1.0 throws.

Evidence to collect:

- Capture the smoke-test output to
  `._test_output/stage29/s29-impl-01-wrapper-smoke.log`.
- Record: PSVersionTable.PSVersion.Major output,
  New-ComparisonWorkload function signature (Get-Command output),
  New-AgenticChatPrompt function signature, the four expected
  throws (RequestCount=0, MaxTokens=0, Distribution sum != 1.0,
  missing key 'exact').

Estimated wall-clock: 5 minutes.

## Step 02: S29-IMPL-02 author lib helpers and driver skeleton

Description: author the four new lib helpers plus the
`compare-legacy-vs-hybrid.ps1` driver skeleton with parameter
validation and the `-DryRun` switch. The four lib helpers per
[part-08](../cache-handling-phase29-design/part-08-reuse-vs-new-artefacts.md)
new-artefacts table are: `metric-delta.ps1`, `cold-store-drift.ps1`,
`output-equivalence.ps1`, `workload-classify.ps1`. The driver
skeleton has the parameter set from part-03 line 145 plus the
`-DryRun` switch.

Affected files:

- `._design_docs/cache-handling-test-scripts/lib/metric-delta.ps1` (new, ~60 lines)
- `._design_docs/cache-handling-test-scripts/lib/cold-store-drift.ps1` (new, ~40 lines)
- `._design_docs/cache-handling-test-scripts/lib/output-equivalence.ps1` (new, ~60 lines)
- `._design_docs/cache-handling-test-scripts/lib/workload-classify.ps1` (new, ~80 lines, used by the optional proxy capture path)
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` (new, ~600 lines total across the session; the Step 02 portion is ~150 lines for parameter set plus helper calls)

Pre-conditions: S29-IMPL-01 PASS.

Post-conditions:

- Each lib helper has a public function with `[CmdletBinding()]`
  and the named parameters from the design.
- The driver parameter set matches the part-03 interface
  (RunId, ModelPath, RunRoot, ReportPath, CacheColdPath, BasePort,
  LegDurationMin, ColdBudgetMiB, HotBudgetMiB, Cycles,
  ColdStartEnabled, OutputEquivalencePrompts, LlamaServerPath,
  ContextSize, Parallel, Seed, DryRun).
- The driver has a `Main` dispatcher that prints the planned
  command family and exits cleanly under `-DryRun`.
- All five files are LF-only UTF-8 no BOM, no trailing whitespace,
  no non-ASCII, last byte LF.

Evidence to collect:

- Byte-level audit of the five new files (LF, CR, BOM, non-ASCII,
  trailing whitespace).
- `pwsh -NoProfile -File ._design_docs\cache-handling-test-scripts\compare-legacy-vs-hybrid.ps1 -DryRun`
  exits 0 and prints the planned command family.
- `Get-Command -Module` (or equivalent) lists the four new public
  functions.
- Capture to
  `._test_output/stage29/s29-impl-02-scaffold.log`.

Estimated wall-clock: 35 minutes.

## Step 03: S29-IMPL-03 add Phase 0 preflight gate

Description: add the Phase 0 preflight per part-03 lines 24-29:
clean build check, fixture check, port check, disk check, CUDA
build proof (binary mtime > source mtime and `GGML_CUDA:BOOL=ON`
in `build-cuda/CMakeCache.txt`), git commit hash and dirty
working-tree status, nvidia-smi callability. The preflight writes
`dry-run-plan.json` to `RunRoot`.

Affected files:

- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` (add ~80 lines for Phase 0 preflight)

Pre-conditions: S29-IMPL-02 PASS.

Post-conditions:

- Preflight runs the seven sub-checks in order and writes
  `dry-run-plan.json` with the results.
- A missing fixture, stale binary, port collision after one setup
  retry, disk shortage, missing `GGML_CUDA:BOOL=ON`, missing
  runtime CUDA/NVIDIA proof, or uncallable nvidia-smi classifies
  the run as `BLOCKED-preflight` and exits with code 2.

Evidence to collect:

- `dry-run-plan.json` in the test-run root.
- Per-check pass/fail log lines in
  `._test_output/stage29/<run-id>/phase-0-preflight.log`.

Estimated wall-clock: 10 minutes.

## Step 04: S29-IMPL-04 add Phase 0.5 tokenize helper sub-phase

Description: add the Phase 0.5 sub-phase per part-03 lines 30-56:
boot llama-server on port 8900 with `--cache-mode legacy` and
`--n-gpu-layers 0` for the `/tokenize` endpoint, wait for
`/health`, call `New-ComparisonWorkload` via the wrapper to emit
`workload.jsonl` (200 reqs, 40/30/30 distribution) and
`equivalence-prompts.jsonl` (5 prompts), shut down the helper
server, apply the cooldown. The helper is NOT reused for Phase 1
or later phases.

Affected files:

- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` (add ~70 lines for Phase 0.5)

Pre-conditions: S29-IMPL-03 PASS; the tokenize helper server
boots and serves `/tokenize` within 30 seconds of `/health`.

Post-conditions:

- `workload.jsonl` exists at the run root with 200 requests, each
  having the six part-04 metric fields (request_id, cache_class,
  messages, max_tokens, temperature, seed).
- `equivalence-prompts.jsonl` exists at the run root with 5
  prompts.
- The empirical `cache_class` counts in `workload.jsonl` are
  within +/- 5 of the 80/60/60 expected split (per re-review C-01
  observation; recorded in `summary.json`).
- If the helper fails to boot, `New-ComparisonWorkload` throws,
  or the workload.jsonl is missing required fields, classify as
  `BLOCKED-workload-build` and stop.

Evidence to collect:

- `workload.jsonl` line count and per-cache-class count
  distribution.
- `equivalence-prompts.jsonl` line count (5).
- Helper server launch.log, server.out.log, server.err.log.
- Capture to
  `._test_output/stage29/<run-id>/phase-0-5-workload-build.log`.

Estimated wall-clock: 15 minutes (includes 1-2 minutes of server
boot plus workload emission).

## Step 05: S29-IMPL-05 add Phase 1 output equivalence pre-check

Description: add the Phase 1 output equivalence pre-check per
part-03 lines 64-72 and part-05 Layer 1 sub-check 1.2: boot
legacy, send 5 prompts, capture decoded text, shut down legacy,
cooldown, boot hybrid, send same 5 prompts, capture decoded text,
shut down hybrid, cooldown, byte-compare decoded text per prompt.
The 5 prompts come from `equivalence-prompts.jsonl`.

Affected files:

- `._design_docs/cache-handling-test-scripts/lib/output-equivalence.ps1` (extend with the public `Test-OutputEquivalence` function)
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` (add ~60 lines for Phase 1)

Pre-conditions: S29-IMPL-04 PASS; `equivalence-prompts.jsonl`
exists with 5 prompts; both legacy and hybrid can boot and serve
`/v1/chat/completions` with `max_tokens=8` and `seed=42` within
the leg duration.

Post-conditions:

- `phase-1-output-equivalence/legacy-decoded.txt` and
  `hybrid-decoded.txt` exist with 5 lines each (one line per
  prompt).
- `phase-1-output-equivalence/diff.txt` is empty on PASS.
- A non-empty diff classifies the run as
  `BLOCKED-output-equivalence` and the main workload does not
  start.
- The cooldown gate runs between legacy and hybrid boots.

Evidence to collect:

- `phase-1-output-equivalence/legacy-decoded.txt`,
  `hybrid-decoded.txt`, `diff.txt`.
- Per-prompt HTTP status and per-prompt ttft_ms in
  `phase-1-output-equivalence/requests.jsonl`.
- Capture to
  `._test_output/stage29/<run-id>/phase-1-output-equivalence.log`.

Estimated wall-clock: 10 minutes.

## Reading order

Continue with
[part-01b-steps-6-10.md](./part-01b-steps-6-10.md) for steps
6-10 (Phase 2 cold-start cycle, Phase 3 warm cycles, VRAM cooldown
gate, metric scraping, three-layer report emission, pre-execution
self-test) plus the total step wall-clock summary.
