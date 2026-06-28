# Stage 29 implementation: cache modes comparison driver

Status: implementation plan in progress (Developer session, 2026-06-28)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison: legacy vs hybrid on a representative agentic-shaped workload)
Owner: Developer (implementation plan)
Source design: [cache-handling-phase29-design.md](./cache-handling-phase29-design.md) (entry doc) plus 11 part files in `./cache-handling-phase29-design/`
Design gate: Manager design gate PASS 2026-06-28 (D29-DESIGN-GATE-PASS)
Implementation gate: pending Manager review of this plan
Current gate: implementation plan authoring
Branch: work-branch

## Approved baseline

The Manager design gate accepted the Stage 29 design on 2026-06-28. The
Architect authored 12 design files (entry + 11 part files plus
`.manager-inputs/manager-input-20260628-stage29-cache-modes-comparison.md`
preserved as the original proposal input). The independent Architect
review ([part-12](./cache-handling-phase29-design/part-12-design-review-20260628.md))
returned REWORK with 5 BLOCKING findings (B-01..B-05) and 4 INFO
findings (N-01..N-04). The Architect correction session addressed all 9
findings; the independent re-review
([part-13](./cache-handling-phase29-design/part-13-design-re-review-20260628.md))
returned PASS with 0 BLOCKING and 3 INFO observations (C-01..C-03).
The corrected design introduced the new wrapper script
`._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`
(200 lines) as design-correction option (a) for B-01.

This plan is derived from the corrected and re-reviewed design. The
plan does not modify any of the 12 design files. The plan does not
modify production code, test code, runner scripts, or the test plan.

## Goal of this implementation

Produce a working `compare-legacy-vs-hybrid.ps1` driver that runs the
A/B comparison per the corrected design, plus a three-layer report
(Correctness, Per-request, Aggregated) per part-05, plus the five
decision-support questions per part-05. The implementation session
verifies the design-correct wrapper script as a smoke test (no
modifications to the wrapper).

## Scope and exclusions

In scope for the implementation session (post-plan approval):

- The new driver `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`.
- Four new lib helpers under `._design_docs/cache-handling-test-scripts/lib/`:
  `metric-delta.ps1`, `cold-store-drift.ps1`, `output-equivalence.ps1`,
  `workload-classify.ps1` (per part-08).
- Smoke-test verification of the existing wrapper
  `._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`.
- A new durable report naming pattern for QA evidence:
  `._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md`
  (whitelist-allowed; see part-04 evidence plan).
- A new non-durable artifact root `._test_output/stage29/` per test run
  (already part of the ignored `_test_output` folder).

Out of scope (binding from part-01 non-goals and Stage 25-28 closure):

- Product code changes to hybrid cache (comparison-only stage).
- L1 prompt-cache measurement, coverage measurement, real agentic
  traffic as primary workload source, heavy-tier fixture, `/v1/completion`
  route, Stage 24 runner reuse.
- Modifications to the approved design (12 files) or the design-correct
  wrapper script (200 lines). Wrapper smoke-test verifies the script
  runs but does not modify its content.
- The test plan. The test plan is authored by QA in a fresh session
  after this plan PASS.
- Document-index and tracker updates: post-closure per developer skill.

## Invariants preserved

The driver MUST preserve all Stage 25-28 invariants by reading from
the post-Stage-28 closed binary and by NOT modifying any source under
`tools/server/`, `tests/`, `common/`, `ggml/`, or `gguf-py/`:

- I-25-01 atomicity, I-25-02 isolation, I-25-03 durability-within-transaction.
- F-21-EXEC-01 prompt-only save; F-21-RERUN-01 descriptor tracking.
- F-22-DR-01 demotion coordination.
- D-EXEC-26-01 SEH handler; D-EXEC-26-02 argv function-scope vector and
  cold-store per-id accounting.
- D-EXEC-27-08 tx_demote_payload (historical line reference
  `tools/server/server-cache-hybrid.cpp:3396`; line is a historical
  reference only per part-10 traceability; the file is now ~5400 lines
  and the legacy definition sits around line 462).
- R28-BUG-02 cold-store reconcile.
- Stage 28 closure: 142/142 unit tests PASS.

The driver observes these invariants through the public Prometheus
counters (`llamacpp:cache_X` post-Stage-26 namespace) and the cold-store
filesystem ground truth; it does not modify the production code that
enforces them.

## Contents

| Part | Title | Status |
| --- | --- | --- |
| [part-01a](./cache-handling-phase29-implementation/part-01a-steps-1-5.md) | Ordered implementation steps S29-IMPL-01..05 with per-step detail (smoke test, scaffolding, Phase 0 preflight, Phase 0.5 tokenize helper, Phase 1 output equivalence) | this draft |
| [part-01b](./cache-handling-phase29-implementation/part-01b-steps-6-10.md) | Ordered implementation steps S29-IMPL-06..10 with per-step detail (Phase 2 cold-start cycle, Phase 3 warm cycles, VRAM cooldown gate, metric scraping, three-layer report emission, pre-execution self-test) plus total step wall-clock | this draft |
| [part-02](./cache-handling-phase29-implementation/part-02-affected-files.md) | Per-step affected files and line estimates | this draft |
| [part-03](./cache-handling-phase29-implementation/part-03-evidence-plan.md) | Per-step evidence plan and wall-clock breakdown | this draft |
| [part-04](./cache-handling-phase29-implementation/part-04-risks-and-oq-resolutions.md) | Design risks (R29-01..12) plus impl-specific risks (R29-IMPL-01..02) plus OQ-29-01..03 resolutions | this draft |
| [part-07](./cache-handling-phase29-implementation/part-07-impl-fix-main-dispatcher-20260628.md) | Implementation fix log: Main dispatcher F-01 fix, F-02 cooldown cap alignment, F-04 param count correction; F-03 deferred | this fix session |

Reading order: entry doc -> part-01a -> part-01b -> part-02 -> part-03 -> part-04 -> part-07.

## Ordered steps (summary)

The implementation session executes 10 ordered steps. The full detail
(preconditions, postconditions, evidence paths, est. wall-clock per
step) is in [part-01a](./cache-handling-phase29-implementation/part-01a-steps-1-5.md) (steps 1-5) and [part-01b](./cache-handling-phase29-implementation/part-01b-steps-6-10.md) (steps 6-10 plus the total step wall-clock summary).

| Step | Description | Est. minutes |
| --- | --- | ---: |
| S29-IMPL-01 | Smoke-test the existing wrapper script | 5 |
| S29-IMPL-02 | Author the 4 lib helpers and the driver skeleton | 35 |
| S29-IMPL-03 | Add the Phase 0 preflight gate | 10 |
| S29-IMPL-04 | Add the Phase 0.5 tokenize helper sub-phase | 15 |
| S29-IMPL-05 | Add the Phase 1 output equivalence pre-check | 10 |
| S29-IMPL-06 | Add the Phase 2 cold-start cycle and Phase 3 warm-cycle loop | 25 |
| S29-IMPL-07 | Add the VRAM cooldown gate | 10 |
| S29-IMPL-08 | Add the per-leg metric scraping and ground-truth cross-checks | 20 |
| S29-IMPL-09 | Add the three-layer report emitter and decision-support section | 20 |
| S29-IMPL-10 | Pre-execution self-test: dry-run gate, path checks, GPU proof | 10 |

Total authoring and verification: ~160 minutes of focused work spread
across 1-2 implementation sessions.

## Total session wall-clock estimate

Per the design part-03 sequencing budget (80 minutes of A/B execution)
plus the implementation session time above (~160 minutes of authoring
plus ~10 minutes per cycle cooldown waiting), the implementation
session is bounded by the 80-minute execution budget plus a 90-minute
buffer (per design part-09 R29-05). The 80-minute execution budget
includes 2 minutes for Phase 0 preflight, 5 minutes for Phase 1
output equivalence, 20 minutes for Phase 2 cold-start cycle, 50 minutes
for Phase 3 three warm cycles, and 3 minutes of cooldown. Manager may
approve a reduced 2-cycle warm run (40 minutes) if session budget is
tight. Per-cycle breakdown: ~10 minutes for each legacy leg and ~10
minutes for each hybrid leg; 4 cycles x 2 modes = 8 legs total.

## Known risks and mitigations

Part 04 lists all 12 design risks (R29-01..R29-12 from
[part-09](./cache-handling-phase29-design/part-09-risk-register.md))
plus two implementation-specific risks:

- R29-IMPL-01: the wrapper script requires PowerShell 5+ on the
  runner. Mitigation: check `$PSVersionTable.PSVersion.Major -ge 5` at
  the start of the driver; if not, classify as `BLOCKED-powershell-version`.
- R29-IMPL-02: VRAM cooldown may need more than 120 seconds on heavily
  loaded hosts. Mitigation: extend the cooldown polling timeout to 180
  seconds as the binding cap; record actual cooldown duration per leg
  in `summary.json`.

The re-reviewer INFO observations C-01..C-03 are resolved in the
plan: C-01 (record actual cache_class counts in `summary.json`) is
covered by S29-IMPL-08 evidence; C-02 (Stage 20 lib default 30s
timeout) is covered by the driver passing `TokenizeTimeoutSec=60`
through the wrapper; C-03 (per-cycle cache_class counts in
`summary.json`) is covered by S29-IMPL-08 evidence. The
implementation session records the per-cycle counts in
`summary.json` so any distribution drift surfaces in the QA report.

## Test plan handoff inputs (binding)

The QA test plan (to be authored in a fresh QA session after this
plan PASS) consumes the following Stage 29 design inputs:

- **Per-request metric list**: [part-04](./cache-handling-phase29-design/part-04-per-request-metric-list.md)
  defines 13 per-request direct stats, 12 per-leg Prometheus counter
  deltas, 4 gauge snapshots, 4 filesystem ground-truth cross-checks,
  and 4 process/GPU samples. All metric names use the post-Stage-26
  `llamacpp:cache_X` colon-prefix namespace.
- **Three-layer report schema**: [part-05](./cache-handling-phase29-design/part-05-three-layer-report-and-decision-support.md)
  defines the three layers (Correctness, Per-request, Aggregated) and
  the five decision-support questions Q1..Q5 with concrete metric
  thresholds. The report file is
  `._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md`.
- **Binding decisions**: [part-06](./cache-handling-phase29-design/part-06-binding-decisions-resolved.md)
  defines D29-DESIGN-01..06 (workload capture, cold-path volume,
  output equivalence in scope, 3+1 iterations, Qwen3.5-4B-MTP fixture,
  30s sleep plus nvidia-smi gate).
- **Open questions resolved**: [part-07](./cache-handling-phase29-design/part-07-open-questions-resolved.md)
  resolves D29-OQ-01..03 (cache_n_tokens parity, cold-path write
  thread blocking, legacy-wins-by-design workload classes).
- **Driver contract**: [part-03](./cache-handling-phase29-design/part-03-comparison-driver-design.md)
  defines the 4 phases (Phase 0 preflight, Phase 0.5 tokenize helper,
  Phase 1 output equivalence, Phase 2 cold-start cycle, Phase 3 warm
  cycles) and the artifact paths under
  `._test_output/stage29-cache-modes-YYYYMMDD-NN/`.
- **Reuse vs new artefacts**: [part-08](./cache-handling-phase29-design/part-08-reuse-vs-new-artefacts.md)
  defines the 4 new lib helpers and the 1 new driver plus the
  ~990-line total new code estimate.

The implementation session writes the four-row table from part-10
(test plan mapping TP-29-PRE-01, TP-29-OEQ-01, TP-29-CS-01,
TP-29-WARM-01..03, TP-29-METRIC-01, TP-29-DRIFT-01, TP-29-COOLDOWN-01,
TP-29-DECISION-01..05) into the QA test plan as a one-line reference
table. The QA test plan part-number for Stage 29 is `part-32` (next
after `part-31-stage26-metrics-alignment.md`); the QA session writes
that file.

## Hard constraints (binding)

- DO NOT modify production code, test code, runner scripts, or the
  test plan in the implementation session (this plan only).
- DO NOT modify any of the 12 Stage 29 design files.
- DO NOT modify the wrapper script
  `._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`
  (200 lines, design-correct). Step 01 smoke-tests it as a no-op.
- DO NOT commit or push per AGENTS.md.
- ASCII only, LF line endings, no BOM, no trailing whitespace.
- Each part file under 300 lines.
- `git diff --check` clean on every file at close.

## Handoff

Next owner: Manager (implementation-plan gate review). After gate PASS:
Developer (implementation session in a fresh session). After
implementation PASS: QA (test plan). After test plan PASS: Manager
(execution gate). After execution: Developer (test-results review).
After Developer review PASS: Manager (closure per D-CLOSURE-29-NN).

This entry doc is the implementation log entry point for Stage 29.

## Implementation log (Developer session, 2026-06-28)

5 durable files authored plus this log entry. No production code, test code, or runner script was modified.

### Per-step status

| Step | Status | Notes |
| --- | --- | --- |
| S29-IMPL-01 | DONE | Wrapper smoke-test PASS; `New-ComparisonWorkload` exposed; wrapper NOT modified. |
| S29-IMPL-02 | DONE | 4 lib helpers + driver skeleton (18-param set per impl-review N-02: 16 strings/ints + `-DryRun` + `-OutputEquivalenceOnly`). |
| S29-IMPL-03 | DONE | Phase 0 preflight 7 fields with 5 gating sub-checks (ps_version_ok, binary_exists, fixture_exists, port_free, cuda_proof); 2 informational (git_head, git_dirty); printed by `-DryRun`. |
| S29-IMPL-04 | DONE | Phase 0.5 tokenize helper emits workload.jsonl (200 reqs, 40/30/30) + equivalence-prompts.jsonl (5 prompts). |
| S29-IMPL-05 | DONE | Phase 1 output equivalence: legacy send, cooldown, hybrid send, cooldown, byte-compare. |
| S29-IMPL-06 | DONE | Phase 2 cold-start + Phase 3 warm cycles in `Invoke-CycleLeg`; per-leg artifacts. |
| S29-IMPL-07 | DONE | VRAM cooldown via `Wait-Stage29VramBaseline` (30s sleep + nvidia-smi poll, 120s cap per design D29-DESIGN-06). |
| S29-IMPL-08 | DONE | Per-leg metric scrape + counter deltas + format grep + summary row. |
| S29-IMPL-09 | DONE | Three-layer report emitter (Correctness/Per-request/Aggregated) + decision-support stub. |
| S29-IMPL-10 | DONE | `-DryRun` and `-OutputEquivalenceOnly` self-tests; outputs captured to `._test_output/stage29/self-test/`. |

### Artifact paths

Durable (LF-only UTF-8 no BOM, under 300 lines):

- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` (228)
- `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.README.md` (176)
- `._design_docs/cache-handling-test-scripts/lib/Read-Stage29MetricSnapshot.ps1` (81)
- `._design_docs/cache-handling-test-scripts/lib/Write-Stage29EvidenceRow.ps1` (101)
- `._design_docs/cache-handling-test-scripts/lib/Test-Stage29OutputEquivalence.ps1` (88)
- `._design_docs/cache-handling-test-scripts/lib/Wait-Stage29VramBaseline.ps1` (90)

Non-durable (`._test_output/stage29/self-test/`): `dry-run.json`, `setup-env.json`, `smoke-equivalence.json`.

### Divergence from approved plan (N-INFO, non-blocking)

Plan names 4 lib helpers with short names (`metric-delta.ps1`,
`cold-store-drift.ps1`, `output-equivalence.ps1`,
`workload-classify.ps1`); this implementation uses PowerShell
Verb-Noun names per Manager brief (`Read-Stage29MetricSnapshot.ps1`,
`Write-Stage29EvidenceRow.ps1`, `Test-Stage29OutputEquivalence.ps1`,
`Wait-Stage29VramBaseline.ps1`). Plan's `workload-classify.ps1`
(OQ-29-01 DEFER) not authored; `cold-store-drift.ps1` folded into
`Write-Stage29EvidenceRow.ps1`. Manager brief is binding.

### Plan review N-03 resolution (cooldown dependency)

Resolved via option (c): basic sleep gate is in `Invoke-CycleLeg`'s
finally block; Step 07's full `Wait-Stage29VramBaseline` (nvidia-smi
poll, 120s cap) hardens it.

### Evidence

- `git diff --check -- <each file>`: clean (exit 0).
- Byte-level audit: LF=line count, CR=0, no BOM, last 0x0A,
  no trailing whitespace, no non-ASCII for all 6 durable files.
- Dot-source smoke: all 7 helper functions exposed.
- `-DryRun` self-test: exit 0, prints preflight JSON.
- `-OutputEquivalenceOnly` self-test: exit 4, classification
  `BLOCKED-server-not-running` (Phase 0.5 not run, no server).
- Wrapper `lib/compare-legacy-vs-hybrid-workload.ps1` byte-level
  verified at 200 LF, no BOM, no CR (per re-review).

### Implementation handoff

Next: Manager implementation-gate review. Then QA test plan
part-32. Then Manager execution gate. Then Developer test-results
review. Then Manager closure per D-CLOSURE-29-NN.

## Implementation fix log

See [part-07](./cache-handling-phase29-implementation/part-07-impl-fix-main-dispatcher-20260628.md) (S29-IMPL-FIX-01), [part-11](./cache-handling-phase29-implementation/part-11-impl-fix-driver-cache-cold-flag-pointer-20260628.md) (S29-IMPL-FIX-02), [part-12](./cache-handling-phase29-implementation/part-12-impl-fix-driver-cold-mode-flag-coupling-20260628.md) (S29-IMPL-FIX-03), and [part-14](./cache-handling-phase29-implementation/part-14-impl-fix-driver-dot-source-20260629.md) (S29-IMPL-FIX-04). QA execution handoff after S29-IMPL-FIX-03: see [part-13](./cache-handling-phase29-implementation/part-13-qa-execution-handoff-20260629.md). F-29-EXEC-08 (NEW BLOCKING, driver dot-source missing for `agentic-prompt-generator.ps1`) discovered 2026-06-29; S29-IMPL-FIX-04 DONE (one-line dot-source at driver L83). Next owner: Manager (implementation-fix gate review, iteration 3), then QA re-execution per test plan part-33.
