# Stage 29 implementation plan part 2: affected files

Source: [../cache-handling-phase29-implementation.md](../cache-handling-phase29-implementation.md)
Companion: [part-01a-steps-1-5.md](./part-01a-steps-1-5.md), [part-01b-steps-6-10.md](./part-01b-steps-6-10.md), [part-03-evidence-plan.md](./part-03-evidence-plan.md), [part-04-risks-and-oq-resolutions.md](./part-04-risks-and-oq-resolutions.md)

This part lists, per implementation step, the files modified, the
estimated line-count change, and the test impact. Line counts are
estimates from part-08 new-artefacts table; final counts come from
the implementation log.

## Step 01: S29-IMPL-01 wrapper script smoke test

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| (none) | read-only verification of the existing wrapper | 0 | none |

No file is created or modified in Step 01. The wrapper script
`._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`
is design-correct per the Architect re-review (200 lines, 7786 bytes,
LF-only, no BOM) and is NOT modified by the implementation session.

## Step 02: S29-IMPL-02 author lib helpers and driver skeleton

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `._design_docs/cache-handling-test-scripts/lib/metric-delta.ps1` | new lib helper: compute Prometheus counter deltas from before/after metrics text files | +60 / -0 | none directly; per-leg metric delta evidence |
| `._design_docs/cache-handling-test-scripts/lib/cold-store-drift.ps1` | new lib helper: compute cold_store_drift_ratio from filesystem bytes and metric bytes | +40 / -0 | none directly; per-leg drift evidence |
| `._design_docs/cache-handling-test-scripts/lib/output-equivalence.ps1` | new lib helper: byte-compare legacy and hybrid decoded text for the 5 seed-42 prompts | +60 / -0 | none directly; Phase 1 output equivalence gate |
| `._design_docs/cache-handling-test-scripts/lib/workload-classify.ps1` | new lib helper: tag each request with cache_class based on prefix match against prior requests (used by the optional proxy capture path only) | +80 / -0 | none directly; optional supplementary path |
| `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` | new driver skeleton: parameter set, helper calls, -DryRun switch | +150 / -0 | dry-run gate for QA preflight |

Step 02 total: +390 lines across 5 new files. No production file
touched. No test file touched. No runner file (other than the new
driver) touched.

## Step 03: S29-IMPL-03 add Phase 0 preflight gate

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` | add Phase 0 preflight: clean build check, fixture check, port check, disk check, CUDA build proof, git hash + dirty status, nvidia-smi callability | +80 / -0 | dry-run-plan.json written; BLOCKED-preflight on missing prereq |

## Step 04: S29-IMPL-04 add Phase 0.5 tokenize helper sub-phase

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` | add Phase 0.5: boot legacy tokenize helper, call New-ComparisonWorkload, shut down, cooldown | +70 / -0 | workload.jsonl + equivalence-prompts.jsonl; BLOCKED-workload-build on helper failure |

## Step 05: S29-IMPL-05 add Phase 1 output equivalence pre-check

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `._design_docs/cache-handling-test-scripts/lib/output-equivalence.ps1` | extend with public `Test-OutputEquivalence` function: 5-prompt byte-compare | +30 / -0 | Phase 1 pre-workload gate |
| `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` | add Phase 1: boot legacy, send 5 prompts, capture decoded text, cooldown, boot hybrid, send same 5 prompts, capture decoded text, cooldown, byte-compare | +60 / -0 | BLOCKED-output-equivalence on non-byte-identical |

## Step 06: S29-IMPL-06 add Phase 2 cold-start cycle and Phase 3 warm-cycle loop

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` | add Phase 2 cold-start cycle (1 cycle x 2 modes) and Phase 3 warm-cycle loop (3 cycles x 2 modes) | +120 / -0 | per-cycle artifact tree; cold-start latency recorded separately |

## Step 07: S29-IMPL-07 add VRAM cooldown gate

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` | add VRAM cooldown gate: 30s sleep + nvidia-smi poll every 5s, max 180s wait (extended per R29-IMPL-02) | +40 / -0 | BLOCKED-vram-release on timeout |

## Step 08: S29-IMPL-08 add per-leg metric scraping and ground-truth cross-checks

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `._design_docs/cache-handling-test-scripts/lib/metric-delta.ps1` | extend with public `Get-CounterDelta` function | +20 / -0 | per-leg counter deltas |
| `._design_docs/cache-handling-test-scripts/lib/cold-store-drift.ps1` | extend with public `Get-ColdStoreDrift` function | +20 / -0 | per-leg drift ratio |
| `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` | add per-leg metric scraping (before/after), 12 counter deltas, 4 gauge snapshots, 4 filesystem metrics, 4 process/GPU samples, metrics-format grep | +100 / -0 | FAIL-metric-format-regression on underscore form; OK-with-drift-warning or BLOCKED-cold-store-drift per ratio |

## Step 09: S29-IMPL-09 add three-layer report emitter and decision-support section

| Path | Action | Lines | Test impact |
| --- | --- | ---: | --- |
| `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` | add three-layer report emitter (Correctness, Per-request, Aggregated) plus the five decision-support questions Q1..Q5 with concrete metric thresholds | +150 / -0 | durable report at .test_reports/test-report-YYYYMMDD-NN-stage29-01.md; final SHIP/FIX-TARGET/REVERT/ACCEPT-COLD verdict |

## Step 10: S29-IMPL-10 pre-execution self-test

| Path | Action | Lines | Test impact |
| --- | --- | --- | --- |
| `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` | add pre-execution self-test: dry-run path, all required paths, CUDA proof, nvidia-smi callability, wrapper smoke | +30 / -0 | self-test log at ._test_output/stage29/s29-impl-10-self-test.log |

## Total line estimates

| File | Total new lines |
| --- | ---: |
| `compare-legacy-vs-hybrid.ps1` | ~800 (across steps 02-10) |
| `lib/metric-delta.ps1` | ~80 |
| `lib/cold-store-drift.ps1` | ~60 |
| `lib/output-equivalence.ps1` | ~90 |
| `lib/workload-classify.ps1` | ~80 |
| (total) | ~1110 |

The design part-08 estimated ~990 lines of new script code. The
actual total is ~1110 lines after the per-step refinements
(per-cache-class summary, 180s cooldown cap, three-layer report
sections). The increase is within the 10% tolerance; the
implementation session reports the final counts in the
implementation log.

## Files NOT touched (binding)

- `tools/server/*.cpp`, `tools/server/*.h`: NO change. The comparison
  binary is the post-Stage-28 closed binary.
- `tests/*.cpp`: NO change. Stage 29 has no new unit tests; the
  test plan is authored by QA in a fresh session.
- `CMakeLists.txt`, `cmake/*.cmake`, `ggml/`, `gguf-py/`: NO change.
- `._design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1`
  (Stage 20 lib, 308 lines): NO change. The wrapper dot-sources it
  per the Stage 20 lib mtime 2026-06-27.
- `._design_docs/cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1`
  (Stage 29 design-correction wrapper, 200 lines): NO change.
  Step 01 smoke-tests it as a no-op.
- `._design_docs/cache-handling-phase29-design.md` and 11 part
  files: NO change. This plan cites them; it does not modify them.
- `document-index.md`, `cache-handling-stage-tracker.md`: NO change
  in this planning session. The implementation session updates
  these at close per the developer skill procedure.
