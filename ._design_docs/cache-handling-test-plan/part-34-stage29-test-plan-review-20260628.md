# Test plan review part 34: Stage 29 cache modes comparison

VERDICT: PASS

## Reviewer session metadata

- Date: 2026-06-28
- Role: QA test-plan review
- Session: NEW fresh session. Distinct from the test-plan authoring session,
  the Manager implementation-fix gate session, the Architect implementation-fix
  reviewer, the design author, design reviewer, design correction author,
  design re-reviewer, and implementation plan and review sessions. No prior
  QA state was loaded; every source document was read from disk in this
  session.
- Method: byte-level inspection of the test plan (LF, CR, BOM, ASCII,
  trailing whitespace, line count); byte-level verification of the driver
  `Main` dispatcher after the impl-fix; line-citation verification of every
  cited design part, lib helper, and review file; cross-check of the 14-row
  table against design part-05 (three-layer structure) and the binding
  decisions in part-06.

## Subject under review

- Test plan: `._design_docs/cache-handling-test-plan/part-33-stage29-cache-modes-comparison.md`
  (299 LF, 14 rows: 4 CC + 3 PR + 4 AG + 2 RG + 1 CV)
- Driver (post-fix state verified): `._design_docs/cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1`
  (243 LF, `Main` at L203-241 now invokes `Invoke-Phase1OutputEquivalence`
  at L225 and `Invoke-CycleLeg` at L233-237, confirmed in this session)
- Manager implementation-fix gate: PASS 2026-06-28 per
  `._design_docs/cache-handling-phase29-implementation/part-08-impl-fix-review-20260628.md`
  (F-01 BLOCKING driver contract defect resolved; F-02, F-04 corrected; F-03
  deferred per impl-review N-03)

## Scope alignment

The test plan covers the design's three-layer report structure from design
part-05:

- Layer 1 Correctness (TP-29-CC-01..04): output equivalence, cold-store
  validity, fallback rate, VRAM cooldown. Each row's PASS criterion is
  concrete and ties back to a design sub-check (1.1, 1.2, 1.3) plus
  D29-DESIGN-06 cooldown gate.
- Layer 2 Per-request (TP-29-PR-01..03): cache-class grouped distributions
  over `cache_n_ratio`, `ttft_ms`, and `wall_clock_ms`. Each row's PASS
  criterion is concrete (exact vs near_prefix vs new_branch groups;
  thresholds in PR-02, PR-03).
- Layer 3 Aggregated (TP-29-AG-01..04): mean hit rate, total tokens
  reused, cold-store utilization (D29-DESIGN-02 2048 MiB), VRAM peak
  headroom. Each row's PASS criterion is concrete.

Regression rows (TP-29-RG-01..02) and the coverage row (TP-29-CV-01) are
tied to prior-stage contracts (Stage 10 closure, Stage 28 closure) and
do not duplicate the three layers.

## Per-row classification rules

For each of the 14 rows, the PASS criterion is concrete and measurable.

| Row | PASS criterion (quoted from the plan) |
| --- | --- |
| TP-29-CC-01 | "byte-identical for all 5 prompts" (Phase 1 output equivalence) |
| TP-29-CC-02 | "0 mismatches" across descriptor / pairing / restore deltas |
| TP-29-CC-03 | "at most 20% of hybrid legs above 10% fallback" rate |
| TP-29-CC-04 | "all cooldowns <= 120s" (matches actual driver default) |
| TP-29-PR-01 | "hybrid exact >= legacy exact" mean cache_n_ratio |
| TP-29-PR-02 | "hybrid cold-miss p50 within 50 ms of legacy cold-miss p50" |
| TP-29-PR-03 | "hybrid warm-hit p95 within 10% of legacy warm-hit p95" |
| TP-29-AG-01 | hybrid mean hit rate >= legacy + 5 pp OR >= 60% absolute |
| TP-29-AG-02 | hybrid total_tokens_reused > 0 across all 4 cycles |
| TP-29-AG-03 | hybrid cold-store bytes <= 2048 MiB AND file count >= 10 |
| TP-29-AG-04 | both modes vram_peak_mib < 6144 |
| TP-29-RG-01 | 8/8 focused tests PASS + 3 PASS + 1 xfail pytest |
| TP-29-RG-02 | zero modifications in `tools/server/` |
| TP-29-CV-01 | rate reported (not blocking per Stage 10 closure contract) |

All 14 PASS criteria are concrete, measurable, and have an explicit
verdict class (PASS, FAIL-correctness-X, FIX-TARGET, REVERT, BLOCKED-X,
or rate-reported).

## Evidence rules

The test plan specifies evidence paths under two roots:

- Per-leg (non-durable): `._test_output/stage29-cache-modes-YYYYMMDD-NN/`
  with `launch.log`, `server.out.log`, `server.err.log`, `metrics-before.txt`,
  `metrics-after.txt`, `requests.jsonl`, `summary.json`, `cold-store-evidence.json`,
  `cooldown-evidence.json`. Matches part-24 folder convention.
- Durable report: `._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md`.
  Matches part-24 naming convention.

Both paths are written in the plan's "Preflight and build gate" section
(L105-106) and reinforced in the "Evidence paths and classification"
section (L207-225). Each row's "Evidence" column cites the specific
per-leg artifact or summary file that satisfies the row.

## Clean-build rule

Section "Preflight and build gate" (L88-108) is explicit:

- "Clean CUDA build is mandatory. Stale builds are invalid evidence."
- Required command: `cmake --build build-cuda --config Release -j --target llama-server`
- Freshness gate: "mtime within 10 minutes of session start"
- Required environment list: build dir, fixture path, port 8900 free,
  30 GiB free on cold-path and output volumes, nvidia-smi parseable,
  `GGML_CUDA:BOOL=ON` in `build-cuda/CMakeCache.txt`, writable workload
  emit path, writable report path.
- BLOCKED-preflight classification on any gate failure.

The clean-build rule is consistent with the QA shared-plan rule and with
the post-Stage-28 closed-binary precondition.

## Reuse vs new automation

The test plan references the existing driver and lib helpers; no parallel
test scripts are introduced:

- Driver: `compare-legacy-vs-hybrid.ps1` (new, 243 LF, post-fix state
  verified in this session)
- Lib helpers (new for Stage 29):
  - `lib/Read-Stage29MetricSnapshot.ps1`
  - `lib/Write-Stage29EvidenceRow.ps1`
  - `lib/Test-Stage29OutputEquivalence.ps1`
  - `lib/Wait-Stage29VramBaseline.ps1`
  - `lib/compare-legacy-vs-hybrid-workload.ps1` (wraps Stage 20 lib)
- Stage 20 lib reused unchanged: `lib/agentic-prompt-generator.ps1`
- Stage 24 runner: reference only, no modification (per test plan L84)

The wrapper dot-sources the Stage 20 lib and emits the per-request JSONL
with the 40/30/30 distribution and the six required fields
(`request_id`, `cache_class`, `messages`, `max_tokens`, `temperature`,
`seed`), verified at wrapper L29-33 (distribution) and L154-162 (fields).

## Format compliance

Byte-level inspection of the test plan:

- LF byte count: 299 (matches line cap and matches .NET `ReadAllLines` count)
- CR byte count: 0
- BOM: false
- Last byte: 0x0A (LF terminator)
- Non-ASCII byte count: 0 (pure ASCII)
- Trailing whitespace line count: 0
- Tab byte count: 0
- `git diff --check` exit code: 0

The test plan uses ASCII status labels (PASS, FAIL, SKIP, BLOCKED) per
the shared-plan rule. No unicode status icons.

## Document size

299 LF, under the 300-line durable-doc cap.

## Findings table

| ID | Severity | File | Line | Finding | Suggested resolution |
| --- | --- | --- | --- | --- | --- |
| F-RP-01 | NON-BLOCKING | `part-33-stage29-cache-modes-comparison.md` | L277 | The "Findings from prior review" section documents the pre-fix state (F-01 BLOCKING driver contract defect; F-02, F-04 documentation drifts; F-03 preflight sub-checks skipped). After the Manager implementation-fix gate PASS 2026-06-28, the underlying defects have been resolved. The section's substance (F-01 described a real prior BLOCKING) is correct historical documentation, but a future reader may mis-read F-01 as "current BLOCKING" without consulting part-08. | At next durable-doc touch, append a short "Resolution" line under each finding pointing to part-08 verification. No change needed for current PASS verdict. |
| F-RP-02 | NON-BLOCKING | `part-33-stage29-cache-modes-comparison.md` | L277 (F-04 row) | F-04 cites `cache-handling-phase29-implementation.md` L244 for "17-param set". L244 is S29-IMPL-09 (three-layer report emitter), not the param-count row. The actual param-count claim is at L237 of the current impl log ("18-param set per impl-review N-02: 16 strings/ints + `-DryRun` + `-OutputEquivalenceOnly`"). Line-number drift inherited from the prior pre-fix state. Substance (driver declares 18 typed parameters) is verifiable at driver L18-36 and matches the current impl log. | At next durable-doc touch, update the F-04 line citation to L237 of the impl log. No change needed for current PASS verdict. |
| F-RP-03 | NON-BLOCKING | `part-33-stage29-cache-modes-comparison.md` | L273 (F-02 row) | F-02 cites `part-04-risks-and-oq-resolutions.md` L116-122 for "180s cap per R29-IMPL-02". L116-122 of part-04 is the R29-03 risk mitigation (cache_class_counts), not the 180s cap. The 180s content is at L24 (risk table) and L68-74 (mitigation body). Substance (180s claim exists in part-04; driver uses 120s default) is correct. | At next durable-doc touch, update the F-02 part-04 line citation to L24 / L68-74. No change needed for current PASS verdict. |
| F-RP-04 | NON-BLOCKING | `part-33-stage29-cache-modes-comparison.md` | L159 (TP-29-CC-04) | The "Source design" cell cites "design part-03 L95-110" for the VRAM cooldown gate. L95-110 of part-03 is the wall-clock budget block ("Phase 2 (200 req x 2): ~20 minutes" etc.). The actual cooldown section ("## Cooldown between runs") is at L114-139. The PASS criterion itself ("all cooldowns <= 120s") is correct and matches the actual driver default (L189). | At next durable-doc touch, update the part-03 line citation to L114-139. No change needed for current PASS verdict. |
| F-RP-05 | INFO | `part-33-stage29-cache-modes-comparison.md` | L52, L273 | F-02 cites a helper docstring at `Wait-Stage29VramBaseline.ps1` L36 saying "binding cap of 180s". The current file has been updated to L19-23 docstring saying "polling cap is 120s (MaxWaitSec default)" and the L36 row is now blank. The F-02 finding reflects pre-fix state. The test plan's TP-29-CC-04 PASS criterion correctly uses 120s. | At next durable-doc touch, update the F-02 docstring citation to reflect the current L19-23 wording. No change needed for current PASS verdict. |

## Concrete rework list

None. All findings are NON-BLOCKING or INFO. The test plan is reviewable
as authored and the 14 rows are executable post-impl-fix.

## Next owner and next gate

Manager test-plan gate review. After Manager gate PASS: QA execution
session opens under `._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage29-01.md`,
following the part-24 folder convention.

This review report uses LF line endings, plain ASCII status labels, no
BOM, no trailing whitespace, and stays under the 300-line durable-doc
cap.
