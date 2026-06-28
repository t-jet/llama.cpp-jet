# Part 1: Goals, scope, and exclusions

Status: design in progress (Architect session)
Date: 2026-06-28
Stage: 29 (Cache Modes Comparison - legacy vs hybrid)
Source: [../cache-handling-phase29-design.md](../cache-handling-phase29-design.md)
Source brief: [../.manager-inputs/manager-input-20260628-stage29-cache-modes-comparison.md](../.manager-inputs/manager-input-20260628-stage29-cache-modes-comparison.md)

## Goals

G1. Run an apples-to-apples A/B comparison of `--cache-mode legacy` against
`--cache-mode hybrid` on a reproducible agentic-shaped workload.

G2. Produce a three-layer report (Correctness, Per-request, Aggregated) plus a
decision-support section that names concrete improvement targets for the
hybrid path.

G3. Use post-Stage-26 metrics (`llamacpp:cache_X`) so the report is
forward-compatible with future cache changes and scrapes cleanly.

G4. Reconcile with Stage 24 closure: S03 hybrid was BLOCKED-structural-not-
infra due to D-EXEC-24-03 (heap corruption). Stage 27 closed D-EXEC-24-03 and
Stage 28 closed the cold-store reconcile (R28-BUG-02). Stage 29 starts from a
known-clean baseline and the new S03 hybrid evidence is no longer blocked by
the prior crash. Stage 27 closure evidence (per review finding N-04): S03
hybrid reached 687 requests on Stage 24 -07 (vs the 258-request crash
threshold, 2.65x past the failure point), per
`test-report-20260626-07.md` and D-CLOSURE-27-01.

G5. Detect silent cache-blob substitution early via a mandatory
output-equivalence pre-check (see part-06 D29-DESIGN-03).

G6. Detect metric-vs-filesystem drift via ground-truth cross-checks
(`du -sb` on cold dir, file count via `find`) so any future cold-store
accounting regression surfaces in the comparison report.

G7. Produce evidence sufficient for Manager to decide whether to ship hybrid
mode as the default cache mode in a future stage.

## Non-goals

N1. Product code changes to hybrid cache. Stage 29 is comparison-only.

N2. Coverage measurement (implementation-level, not runtime behavior).

N3. L1 prompt-cache measurement (no upstream proxy in this design).

N4. Stage 23 S01..S08 or L01..L03 matrix rerun.

N5. Stage 24 runner reuse. Stage 29 has a different output contract
(three-layer comparison vs per-row comparison).

N6. Real agentic traffic as primary workload source. Optional one-shot proxy
capture is allowed as supplementary ground truth (see part-02), but the
primary workload is synthetic-but-representative.

N7. Heavy-tier fixture Qwen3.6-27B-MTP. Deferred to a future stage.

N8. `/v1/completion` route. Chat-completion only, matching Stage 24 precedent.

## Scope

In scope:

- A new focused driver `compare-legacy-vs-hybrid.ps1` under
  `_design_docs/cache-handling-test-scripts/`.

- Synthetic workload generation via
  `_design_docs/cache-handling-test-scripts/lib/agentic-prompt-generator.ps1`
  (Stage 20 lib).

- Per-leg metrics captured before and after each request from response
  timings, public Prometheus `/metrics` deltas, and filesystem ground truth.

- Hybrid-only redacted prompt evidence and cold-store metrics.
- Optional one-shot proxy capture for ground-truth comparison (see part-02).
- A durable Markdown report at
  `._design_docs/.test_reports/test-report-YYYYMMDD-NN.md` per the test-output
  folder convention (see test plan part-24).

- Non-durable artifacts under `._test_output/stage29-cache-modes-YYYYMMDD-NN/`.

Out of scope:

- L1 prompt-cache measurement.
- Product code changes.
- Coverage measurement.
- Stage 23 S/L matrix rerun.
- Stage 24 runner reuse.
- Real agentic traffic as primary workload.
- Heavy-tier fixture.
- `/v1/completion` route.

## Boundary conditions

B1. The comparison binary is the post-Stage-28 closed binary with all 142/142
unit tests PASS. Any change to the binary between iterations invalidates the
comparison and the report must record the exact git commit hash and dirty
working-tree state.

B2. The cold-path directory is wiped between iterations of the same cache
mode. The hot payload budget (`--cache-ram`) is fixed at 512 MiB for all
legs to match Stage 24 precedent and ensure the comparison is budget-stable.

B3. The wall-clock budget is 80 minutes for the full 4-cycle A/B plus
cooldowns. Manager may lower to 2 cycles (40 minutes) if the session budget
is tight.

B4. The output equivalence pre-check runs before the main workload and is
gated on byte-identical decoded text for the 5 seed-42 prompts. If the pre-
check fails, the main workload does not start and the report classifies the
comparison as `BLOCKED-output-equivalence`.

B5. Per-leg wall-clock cap is 10 minutes, matching Stage 24 precedent.
Smoke cap (60 seconds) is allowed for runner development but cannot satisfy
final acceptance.

## Handoff

Part 1 reviewable. Subsequent parts (2 through 11) cover workload capture,
driver design, metric list, three-layer report, binding decisions, open
questions, reuse, risks, traceability, and reconciliation.
