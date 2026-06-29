# MANAGER INPUTS - NOT AN APPROVED DESIGN

## Stage 30 intake brief: Cache Modes Comparison Full Re-Execution

This is a Manager intake brief, not an approved design. The Stage 30 design will reuse the Stage 29 design as-is unless the Architect identifies a gap.

## User directive (verbatim)

> "Open next stage to run full comparison and get comparison report."

Date: 2026-06-29
Time: ~14:45 (immediately after Stage 29 closure at D29-CLOSURE-29-02)

## Stage goal

Re-execute the cache modes comparison (legacy vs hybrid) on a synthetic-but-representative agentic-shaped workload with a 60-90 minute wall-clock budget to resolve the 9 BLOCKED rows from Stage 29 and produce the complete comparison report the user originally requested.

The Stage 29 closure notes recorded: "Test plan and driver are reusable for the follow-up stage with a 60-90 minute wall-clock budget."

## Source documents (all approved, reusable as-is)

- Design: `cache-handling-phase29-design.md` (entry) + 11 part files under `cache-handling-phase29-design/`
- Implementation: `cache-handling-phase29-implementation.md` (entry) + 25 part files under `cache-handling-phase29-implementation/`
- Test plan: `cache-handling-test-plan.md` (generic, no changes needed)
- Driver: `cache-handling-test-scripts/compare-legacy-vs-hybrid.ps1` (with `.TrimStart()` fix at L230-231 per S29-IMPL-FIX-08)
- Wrapper: `cache-handling-test-scripts/lib/compare-legacy-vs-hybrid-workload.ps1` (with `MaxIterations=200` and `SizeClass='2k'` per S29-IMPL-FIX-05/06)
- Tracker: row 29 records CLOSED status; row 30 will be created for this stage

## Reference binary and model (unchanged from Stage 29)

- Binary: `D:\source\llama.cpp-jet\build-cuda\bin\Release\llama-server.exe` (168655360 bytes, mtime 2026-06-27T10:55:11)
- Model: `D:\source\llama.cpp-jet\._test_models\Qwen3.5-4B-MTP-GGUF\Qwen3.5-4B-Q4_K_M.gguf` (2834975040 bytes)
- Cold path: `D:\tmp\cache-cold-stage30-NN` (per cycle, fresh)
- Run root: `D:\source\llama.cpp-jet\_test_output\stage30-cache-modes-YYYYMMDD-NN\`

## Test execution parameters

- Cycles: 4 per the Stage 29 test plan (1 cold-start cycle + 3 warm cycles)
- Request count: 60 per cycle (matches Stage 29 for direct comparison)
- Context size: 4096 (matches Stage 29)
- Cold budget: 2048 MiB (matches Stage 29)
- Hot budget: 512 MiB (matches Stage 29)
- Parallel: 2 (matches Stage 29)
- Seed: 42 (matches Stage 29, deterministic)
- Base port: 8900 (matches Stage 29)
- Leg duration: default (no per-leg timeout cap; allow full cycle to complete)

## Wall-clock budget

- Target: 60-90 minutes total for the full 4-cycle run (8 legs)
- Driver: not killed mid-cycle this time; QA runs to natural completion
- Cycle 1 cold legacy expected: ~25-30 min (was 32 min before killed at 14:34)
- Cycle 1 cold hybrid expected: ~25-30 min
- Cycles 2-4 warm expected: ~5-10 min each (warm cache reduces time)
- Total: ~80-100 min for all 4 cycles

## Expected deliverable

- New test report: `._design_docs/.test_reports/test-report-YYYYMMDD-NN-stage30-01.md`
- Resolves 9 BLOCKED rows from Stage 29 (CC-03..04, PR-01..03, AG-01, AG-02, AG-04)
- Produces the comparison target the user requested
- Three-layer report (Correctness, Per-request, Aggregated) per Stage 29 design part-05
- Five decision-support questions per Stage 29 design part-05
- All 14 row verdicts should be CLASSIFIED (PASS / PARTIAL / FAIL), not BLOCKED

## Gate plan

1. **Stage intake**: Manager (current gate)
2. **Design**: SKIP - reuse Stage 29 design as-is (already passed 2 Architect review cycles with 0 BLOCKING)
3. **Implementation planning**: SKIP - reuse Stage 29 plan as-is (already passed Architect review with 0 BLOCKING)
4. **Implementation**: SKIP - reuse Stage 29 driver as-is (post-S29-IMPL-FIX-08 byte-verified working)
5. **Test planning**: SKIP - reuse Stage 29 test plan as-is (generic, no changes needed)
6. **Test execution**: QA - delegate to QA in a fresh session with 60-90 min budget
7. **Test results review**: Developer - review the report in a fresh session
8. **Bug-fix loop**: as needed
9. **Closure**: Manager - close Stage 30 at D30-CLOSURE-30-01

## Current gate

Test execution (gate 6 in the workflow, but the prior 5 gates are SKIP with documented evidence)

## Open blockers

None at intake. The driver has been byte-verified working. The test plan is generic and reusable. The reference binary and model are unchanged from Stage 29.

## Carry-forward from Stage 29

- 8 implementation fix iterations (S29-IMPL-FIX-01..08) all durable
- F-29-EXEC-17 (driver hashtable property whitespace) RESOLVED by S29-IMPL-FIX-08
- F-29-EXEC-13 (Release-without-/Zi) and F-29-EXEC-14 (pytest env) NOT expected to surface in Stage 30 since they were orthogonal to driver
- 142/142 focused tests PASS (carry-forward from Stage 28)
- Phase 0 PASS, Phase 0.5 SUCCEEDED, Phase 1 PASSED byte-identical
- Only Phase 2 cold-start cycle 1 legacy was started but not completed (wall-clock-limited)

## Risks for Stage 30

- R30-01: Driver may hit new wall-clock limit even at 60-90 min budget if MTP model + 4096 ctx + 60 requests is heavier than expected. Mitigation: monitor cycle 1 cold timing; if cycle 1 takes >35 min, reduce Cycles to 2 (1 cold + 1 warm) for the rerun.
- R30-02: New implementation bugs may surface in driver after running longer. Mitigation: byte-verify all key driver outputs (workload.jsonl, equivalence-prompts.jsonl, diff.txt) before declaring PASS.
- R30-03: Cold-path write may block the main thread for long enough that the next phase's cooldown does not fully release VRAM. Mitigation: 30s sleep + nvidia-smi check between legs (already in driver).

## Current owner

QA (next delegation)

## Expected handoff

After QA test execution, handoff to Developer for test-results review, then back to Manager for closure.
