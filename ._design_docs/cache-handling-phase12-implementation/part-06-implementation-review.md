# Stage 12 implementation review

- Review ID: ST12-IMPL-RV-01
- Date: 2026-06-07
- Reviewer: Architect agent
- Source impl refs:
  - [part-01-implementation-plan.md](part-01-implementation-plan.md)
  - [part-03-implementation.md](part-03-implementation.md)
  - [part-04-implementation-evidence.md](part-04-implementation-evidence.md)
  - [part-05-fixture-requirements.md](part-05-fixture-requirements.md)
  - build-impl-20260607-01.log
  - cache-handling-test-scripts/README.md update

## 1. Scope

In scope for this review:
- Stress driver family (8 scripts, S12-S01..S12-S08)
- Benchmark driver family (8 scripts, S12-B01..S12-B08)
- Long-run driver family (3 scripts, S12-L01..S12-L03)
- 5 lib helpers
- 1 root config matrix helper (apply_config_matrix.ps1)
- 1 README update documenting new stress/bench/longrun dirs
- 3 evidence dir templates under ._design_docs/.test_reports/

Out of scope for this impl (not delivered):
- Real stress or benchmark live runs (only dry-run path proven)
- Test cases, pass/fail criteria, baseline numbers, tuning report values
- Source code or C++ changes
- Test plan edits
- Commits

## 2. Script inventory

| Dir                                          | Expected | Actual | Status |
|----------------------------------------------|----------|--------|--------|
| stress/                                      | 8        | 8      | PASS   |
| bench/                                       | 8        | 8      | PASS   |
| longrun/                                     | 3        | 3      | PASS   |
| lib/                                         | 5        | 5      | PASS   |
| root apply_config_matrix.ps1                 | 1        | 1      | PASS   |
| .test_reports/stress-s12-template/README.md  | 1        | 1      | PASS   |
| .test_reports/bench-s12-template/README.md   | 1        | 1      | PASS   |
| .test_reports/longrun-s12-template/README.md | 1        | 1      | PASS   |

## 3. Plan conformance

| Plan item                                  | Impl item                                    | Status |
|--------------------------------------------|----------------------------------------------|--------|
| 8 stress drivers keyed S12-S0x            | 8 files in stress/                           | PASS   |
| 8 bench drivers keyed S12-B0x             | 8 files in bench/                            | PASS   |
| 3 longrun drivers keyed S12-L0x           | 3 files in longrun/                          | PASS   |
| 5 lib helpers (Write-StressEvidence etc.) | 5 files in lib/                              | PASS   |
| 1 config matrix helper at root             | apply_config_matrix.ps1                      | PASS   |
| 3 evidence dir templates                   | stress/bench/longrun -s12-template READMEs   | PASS   |
| README update documenting new dirs         | README adds Stage 12 section                 | PASS   |
| No source code changes                     | git status shows no .cpp/.h/.hpp/.cu changes | PASS   |
| No test plan edits                         | part-04 confirms plan untouched              | PASS   |
| No pass/fail verdicts                      | part-04 hands verdicts to QA                 | PASS   |
| No live stress or benchmark runs           | part-04 status "Live mode: not opened"       | PASS   |

## 4. Build evidence

Source: build-impl-20260607-01.log (PowerShell 7.6.2 on Windows).

- 25 scripts (5 lib + 8 stress + 8 bench + 3 longrun + 1 root) all PASS `Parser::ParseInput` with 0 parse errors.
- 19 scenario scripts (8 stress + 8 bench + 3 longrun) all complete `-DryRun` with exit 0 and produce no positional parameter errors.
- Round 1 vs round 2 fix history (build-impl log section 3):
  1. Export-ModuleMember emitted non-terminating errors on every dot-source of lib/*.ps1. Fix: removed from all 5 lib helpers (dot-sourcing does not need module export).
  2. bench_s12_b01 line 51 mixed pipeline with `+ @(...)` causing parser to bind as positional argument. Fix: rewrote `$legacyFlags` as direct array literal matching `$hybridFlags` with `hybrid` replaced by `legacy`.
- Both fixes reflected in round 2 parse and dry-run checks. Round 2 clean.
- CRLF cleanliness spot-check (raw byte inspection):
  - S01, S02, S05, B01, B07, L01, Write-StressEvidence.ps1, apply_config_matrix.ps1: CR count equals LF count in every file, no UTF-8 BOM.
  - Matches build-impl log table (0 mismatched lines).
- Fixture existence checks did not run in dry-run (per dry-run output: stub=False for all 19). Drivers short-circuit on the DryRun switch before fixture probe.

## 5. Fixture status

| Fixture                | Path                                              | Status                  | Used by (per part-05)                                                    |
|------------------------|---------------------------------------------------|-------------------------|--------------------------------------------------------------------------|
| Qwen3-0.6B-Q8_0        | ._test_models/Qwen3-0.6B-GGUF/                    | present (small)         | S12-S01..S04, S06..S08; S12-B01, B03..B06, B08; S12-L01..L03             |
| Qwen3-8B-Q6_K          | ._test_models/Qwen3-8B-GGUF/                      | present (larger)        | S12-S05 (target-plus-draft and checkpoint profiles), S12-B02, S12-B07    |
| Qwen3.5-4B-MTP         | ._test_models/Qwen3.5-4B-MTP-GGUF/                | present, out of scope   | not used; cap-fix closure PASS 2026-06-07 keeps draft/MTP rows out       |

BLOCKED rules (per part-05):
- S12-S05 checkpoint-dependent profile BLOCKS on server start if Qwen3-8B checkpoint admission fails at the in-scope --ctx-size.
- S12-B07 checkpoint-dependent profile carries the same BLOCKED rule.
- Drivers write STUB markers and `Verdict: BLOCKED` when fixture or required tool is missing. STUB rows are not counted as PASS for closure.

Legacy N/A rows (per part-03 design baseline):
- S12-B05 legacy row: N/A (legacy has no hybrid restore path).
- S12-B08 legacy row: N/A (legacy has no forest lookup path).

Tool requirements:
- k6 at D:\app\k6\k6.exe: used by S12-B01 and S12-B06. Driver falls back to STUB if missing.
- Focused fault-injection binary at build/bin/Release/test-step11-test-hooks-fault-injection.exe: used by S12-S08. Driver falls back to STUB and records BLOCKED if missing.
- OpenCppCoverage: not consumed by Stage 12 stress or benchmark scripts.

## 6. Scope discipline

| Plan exclusion                              | Verified                                                        | Status |
|---------------------------------------------|-----------------------------------------------------------------|--------|
| No real stress or benchmark live runs       | part-04 status line: "Live mode: not opened (separate QA gate)" | PASS   |
| No test cases added                         | no test/ tree changes in git status                             | PASS   |
| No pass/fail criteria authored              | part-04 hands verdicts and thresholds to QA                    | PASS   |
| No source code changes                      | git status shows only design, impl docs, scripts, README, log   | PASS   |
| No test plan edits                          | part-04: "This plan does not change ... the test plan"          | PASS   |
| No commit                                   | part-04: "Commit: not committed"; part-03: "Commit: not committed" | PASS |
| No new behavior or public surface           | part-01: "Stage 12 is operational validation"                   | PASS   |

## 7. Verdict

PASS

Reasoning:
- Script inventory matches plan counts across all four directories and the root helper.
- All 25 scripts parse cleanly and all 19 scenario dry-runs exit 0 with no positional parameter errors.
- Two round-1 issues were fixed in round 2 with no remaining errors; fixes documented in build-impl log section 3.
- Required Qwen3-0.6B and Qwen3-8B fixtures are present locally; MTP fixture held out of scope per cap-fix closure PASS.
- README documents the new stress, bench, and longrun directories and the apply_config_matrix helper.
- Scope discipline holds: no code, no test plan edits, no live runs, no commits.

## 8. Manager handoff

Next gate: Manager implementation gate, then QA test planning.

QA test planning should consume:
- part-03 (impl log) for scenario scripts and stub data contract.
- part-04 (impl evidence) for parse and dry-run proof and the parse-tokenize approach.
- part-05 (fixture requirements) for BLOCKED rules, disk and host requirements, and the N/A legacy rows.
- build-impl-20260607-01.log for evidence-source classification per row.
- README update for harness, clean-build requirement, and Stage 12 driver invocation.

Open follow-ups (non-blocking):
- S02 dry-run print line shows the base port 8210 for both sub-runs; live code computes `$portUse = $Port + $n` at line 83, so the two sub-runs bind 8214 and 8218. Cosmetic print only; not a functional bug. Worth tightening in a follow-up.
- DryRun path creates the evidence subdir before the early-exit (S01 line 47 vs line 52). Empty dir residue remains on disk. Cleanup recommended before live run; not a defect.
- S12-S05 and S12-B07 checkpoint-dependent profiles may BLOCK on the first live run if Qwen3-8B does not admit a checkpoint at the in-scope --ctx-size. QA plan owns tuning or surfaces a Manager scope decision.
- S12-B05 and S12-B08 legacy rows are recorded as N/A. Part-05 observation S12-PLAN-01 suggests QA test plan may add a "nearest legacy throughput and latency" row; not required for this gate.

`git diff --check` results:
- Tracked file `._design_docs/cache-handling-test-scripts/README.md`: exit 0, no whitespace errors reported.
- Untracked files (25 scripts, 3 templates, part-03/part-04/part-05, apply_config_matrix.ps1): not covered by `git diff --check`. Verified clean via raw byte inspection on a sample of 8 files: CR count equals LF count in every file, no UTF-8 BOM. This file (part-06-implementation-review.md) was authored LF-only via `UTF8Encoding($false)` write and verified post-write.
